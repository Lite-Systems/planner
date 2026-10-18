import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:planner/core/services/notification_service.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'macOS task saving never schedules before native notification initialization',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      MacOSFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      var initialized = false;
      var initializeCount = 0;
      var scheduled = 0;
      var failReminders = false;
      final initializationEntered = Completer<void>();
      final finishInitialization = Completer<void>();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'initialize') {
              final args = Map<String, dynamic>.from(call.arguments as Map);
              for (final key in [
                'defaultPresentAlert',
                'defaultPresentBadge',
                'defaultPresentSound',
                'defaultPresentBanner',
                'defaultPresentList',
              ]) {
                expect(args[key], isA<bool>());
              }
              initializeCount++;
              initializationEntered.complete();
              await finishInitialization.future;
              initialized = true;
              return true;
            }
            if (call.method == 'zonedSchedule') {
              // The native crash reports trap on a force-unwrapped defaults dictionary
              // in buildUserNotificationContent. Only initialize populates it.
              expect(
                initialized,
                isTrue,
                reason:
                    'macOS buildUserNotificationContent would trap: presentation defaults are missing.',
              );
              scheduled++;
              expect((call.arguments as Map)['platformSpecifics'], isA<Map>());
              if (failReminders) {
                throw PlatformException(code: 'simulated_permission_denied');
              }
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final directory = await Directory.systemTemp.createTemp(
        'planner_save_crash_',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      addTearDown(() async {
        await DatabaseHelper.instance.close();
        await directory.delete(recursive: true);
      });
      final db = DatabaseHelper.instance;
      await db.insertProject(
        Project(id: 'project', name: 'Save test', description: ''),
      );
      final provider = ProjectProvider();
      addTearDown(provider.dispose);
      await provider.loadData();

      // Match startup: initialization runs in the background and may still be
      // waiting on macOS permission when the user saves their first task.
      final startup = NotificationService().init();
      await initializationEntered.future.timeout(const Duration(seconds: 2));
      final concurrentStarts = List.generate(
        5,
        (_) => NotificationService().init(),
      );
      final task = ProjectTask(
        id: 'saved',
        projectId: 'project',
        name: 'Task save regression',
        details: '',
        attachments: [],
        startDate: DateTime.now().add(const Duration(hours: 2)),
        cost: 25,
      );
      final saving = provider.addTask(task);
      expect((await db.getTasks('project')).single.id, task.id);
      expect(
        scheduled,
        0,
        reason: 'Native reminders wait until initialize completes.',
      );
      finishInitialization.complete();
      await Future.wait([startup, saving, ...concurrentStarts]);
      expect(calls.first, 'initialize');
      expect(initializeCount, 1);
      expect(scheduled, 1);
      expect((await db.getTasks('project')).single.name, task.name);
      expect(provider.getTasks('project').single.id, task.id);
      await provider.updateTask(task.copyWith(name: 'Edited task'));
      expect((await db.getTasks('project')).single.name, 'Edited task');
      expect(scheduled, 2);
      failReminders = true;
      await provider.addTask(task.copyWith(id: 'permission-denied'));
      expect(await db.getTasks('project'), hasLength(2));
      expect(provider.totalTasksCount, 2);
      await provider.updateTask(
        task.copyWith(name: 'Saved despite reminder failure'),
      );
      expect(
        (await db.getTasks('project')).first.name,
        'Saved despite reminder failure',
      );
      expect(
        initializeCount,
        1,
        reason: 'Initialization is shared, not repeated per save.',
      );
    },
  );

  test('macOS task speech input has its mandatory privacy descriptions', () {
    final plist = File('macos/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'NSSpeechRecognitionUsageDescription',
      'NSMicrophoneUsageDescription',
    ]) {
      expect(
        plist,
        matches(RegExp('<key>$key</key>\\s*<string>[^<]+</string>')),
        reason:
            'macOS terminates the app when speech input requests this permission without a usage description.',
      );
    }
  });

  test('macOS sandbox permits microphone input in debug and release', () {
    for (final configuration in ['DebugProfile', 'Release']) {
      final entitlements = File(
        'macos/Runner/$configuration.entitlements',
      ).readAsStringSync();
      expect(
        entitlements,
        matches(
          RegExp(
            '<key>com.apple.security.device.audio-input</key>\\s*<true\\s*/>',
          ),
        ),
      );
    }
  });
}
