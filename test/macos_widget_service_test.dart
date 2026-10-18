import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/macos_widget_service.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProjectTask task(
  String name,
  int day, {
  bool done = false,
  bool archived = false,
  bool running = false,
}) => ProjectTask(
  id: name,
  projectId: 'p',
  name: name,
  details: '',
  attachments: [],
  startDate: DateTime(2026, 10, day),
  cost: 100,
  isCompleted: done,
  isArchived: archived,
  isTimerRunning: running,
);

class _Projects extends ProjectProvider {
  @override
  List<Project> get projects => [
    Project(id: 'p', name: 'Work', description: ''),
  ];
  @override
  List<ProjectTask> getTasks(String projectId) => [task('Upcoming', 20)];
  void refresh() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'disabled and protected snapshots contain no task or financial data',
    () {
      for (final (enabled, protected) in [(false, false), (true, true)]) {
        expect(
          buildMacosWidgetSnapshot(
            enabled: enabled,
            protected: protected,
            tasks: [task('Private', 20)],
          ),
          {'enabled': enabled, 'protected': protected},
        );
      }
    },
  );

  test('snapshot excludes archives and limits upcoming tasks to three', () {
    final snapshot = buildMacosWidgetSnapshot(
      enabled: true,
      protected: false,
      tasks: [
        task('Later', 24),
        task('Second', 21),
        task('Archived', 19, archived: true),
        task('First', 20, running: true),
        task('Third', 22),
        task('Done', 18, done: true),
      ],
    );
    expect(snapshot['total'], 5);
    expect(snapshot['completed'], 1);
    expect(snapshot['running'], 1);
    expect(snapshot['tasks'], [
      {'name': 'First'},
      {'name': 'Second'},
      {'name': 'Third'},
    ]);
    expect(jsonEncode(snapshot), isNot(contains('cost')));
  });

  testWidgets(
    'provider bursts coalesce and disabling clears the shared snapshot',
    (tester) async {
      SharedPreferences.setMockInitialValues({'macosWidgetEnabled': true});
      final settings = SettingsProvider();
      final projects = _Projects();
      const channel = MethodChannel('smart_planner/macos_widget');
      final writes = <Map<String, dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'updateSnapshot') {
          writes.add(
            jsonDecode(call.arguments as String) as Map<String, dynamic>,
          );
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pump();
      final service = MacosWidgetService(
        settings: settings,
        projects: projects,
      );
      addTearDown(service.dispose);
      addTearDown(settings.dispose);
      addTearDown(projects.dispose);
      for (var i = 0; i < 30; i++) {
        projects.refresh();
      }
      await tester.pump(const Duration(milliseconds: 350));
      expect(writes, hasLength(1));
      projects.refresh();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        writes,
        hasLength(1),
        reason: 'Identical data does not reload WidgetKit.',
      );
      await service.setEnabled(false);
      expect(writes.last, {'enabled': false, 'protected': false});
      await service.setEnabled(true);
      await settings.setBiometricEnabled(true);
      await service.syncNow();
      expect(writes.last, {'enabled': true, 'protected': true});
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
