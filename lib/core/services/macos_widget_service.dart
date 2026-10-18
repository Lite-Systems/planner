import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/project_task.dart';
import '../../providers/project_provider.dart';
import '../../providers/settings_provider.dart';

/// A small, read-only snapshot: widgets never open the application's database.
Map<String, Object> buildMacosWidgetSnapshot({
  required bool enabled,
  required bool protected,
  required Iterable<ProjectTask> tasks,
}) {
  final snapshot = <String, Object>{'enabled': enabled, 'protected': protected};
  // A widget outlives the app, so never export private task names when app lock
  // is enabled, even while the main window is temporarily unlocked.
  if (!enabled || protected) return snapshot;
  var total = 0;
  var completed = 0;
  var running = 0;
  final upcoming = <ProjectTask>[];
  for (final task in tasks) {
    if (task.isArchived) continue;
    total++;
    if (task.isDone) {
      completed++;
    } else {
      if (task.isTimerRunning) running++;
      upcoming.add(task);
      upcoming.sort(
        (a, b) =>
            (a.endDate ?? a.startDate).compareTo(b.endDate ?? b.startDate),
      );
      if (upcoming.length > 3) upcoming.removeLast();
    }
  }
  return {
    ...snapshot,
    'total': total,
    'completed': completed,
    'running': running,
    'tasks': upcoming.map((task) => {'name': task.name}).toList(),
  };
}

class MacosWidgetService {
  MacosWidgetService({
    required this.settings,
    required this.projects,
    this.channel = const MethodChannel('smart_planner/macos_widget'),
  }) {
    if (!isSupported) return;
    settings.addListener(_schedule);
    projects.addListener(_schedule);
    _schedule();
  }

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  final SettingsProvider settings;
  final ProjectProvider projects;
  final MethodChannel channel;
  final ValueNotifier<String?> error = ValueNotifier(null);
  Timer? _debounce;
  String? _lastSnapshot;
  bool _disposed = false;
  bool _pending = false;
  Future<void>? _writing;

  void _schedule() {
    if (_disposed || !settings.areSettingsLoaded) return;
    _debounce?.cancel();
    _debounce = Timer(
      settings.macosWidgetEnabled && !settings.isBiometricEnabled
          ? const Duration(milliseconds: 300)
          : Duration.zero,
      syncNow,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) await channel.invokeMethod<void>('prepare');
    await settings.setMacosWidgetEnabled(enabled);
    await syncNow();
    if (error.value != null) throw StateError(error.value!);
  }

  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');

  Future<void> syncNow() async {
    if (!isSupported || _disposed || !settings.areSettingsLoaded) return;
    _debounce?.cancel();
    _pending = true;
    if (_writing != null) {
      await _writing;
      return;
    }
    final writing = _writePending();
    _writing = writing;
    try {
      await writing;
    } finally {
      _writing = null;
    }
  }

  Future<void> _writePending() async {
    while (_pending && !_disposed) {
      _pending = false;
      final snapshot = jsonEncode(
        buildMacosWidgetSnapshot(
          enabled: settings.macosWidgetEnabled,
          protected: settings.isBiometricEnabled,
          tasks: projects.projects.expand((p) => projects.getTasks(p.id)),
        ),
      );
      if (snapshot == _lastSnapshot) continue;
      try {
        await channel.invokeMethod<void>('updateSnapshot', snapshot);
        _lastSnapshot = snapshot;
        if (!_disposed) error.value = null;
      } on PlatformException catch (failure) {
        if (!_disposed) error.value = failure.message ?? failure.code;
      } on MissingPluginException {
        if (!_disposed) {
          error.value = 'Rebuild the macOS app to enable widgets.';
        }
      }
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    if (isSupported) {
      settings.removeListener(_schedule);
      projects.removeListener(_schedule);
    }
    error.dispose();
  }
}
