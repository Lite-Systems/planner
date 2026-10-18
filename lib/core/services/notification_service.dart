import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  Future<void> init() async {
    await _ensureInitialized();
  }

  Future<bool> _ensureInitialized() async {
    // These are the platforms configured below. Optional reminders must not
    // stop task saves on a platform with no configured notification backend.
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return false;
    }
    final initialization = _initialization ??= _initialize();
    try {
      await initialization;
      return true;
    } catch (error) {
      if (identical(_initialization, initialization)) _initialization = null;
      _logFailure('initialization', error);
      return false;
    }
  }

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          macOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(settings: initializationSettings);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) => _runSafely(
    'show',
    () => _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    ),
  );

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime startDate,
  }) => _runSafely('schedule task reminder', () async {
    await _notificationsPlugin.cancel(id: _idForTask(taskId));
    final when = startDate.add(const Duration(hours: 1));
    if (!when.isAfter(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id: _idForTask(taskId),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  Future<void> cancelTaskReminder(String taskId) => _runSafely(
    'cancel task reminder',
    () => _notificationsPlugin.cancel(id: _idForTask(taskId)),
  );

  Future<void> _runSafely(
    String operation,
    Future<void> Function() action,
  ) async {
    // macOS's native content builder requires presentation defaults written by
    // initialize. Calling it earlier traps in Swift, beyond Dart try/catch.
    if (!await _ensureInitialized()) return;
    try {
      await action();
    } catch (error) {
      // Reminder failures are optional side effects, never database save errors.
      _logFailure(operation, error);
    }
  }

  void _logFailure(String operation, Object error) => developer.log(
    'Local notification $operation failed '
    '(${error is PlatformException ? error.code : error.runtimeType}).',
    name: 'NotificationService',
  );

  int _idForTask(String taskId) => taskId.hashCode.abs() % 2147483647;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'planner_channel',
      'Smart Planner Notifications',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );
}
