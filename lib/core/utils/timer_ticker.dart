import 'dart:async';

import 'package:flutter/foundation.dart';

/// A single, app-wide one-second ticker shared by every live task timer.
///
/// Previously each running-timer card owned its own `Timer.periodic`, so N
/// visible timers meant N timers firing every second. This class runs at most
/// one periodic timer, and only while at least one subscriber is active
/// (reference counted). Elapsed time is always derived from the task's
/// timestamps, so the tick is only a repaint signal — a dropped tick can never
/// cause drift.
class TimerTicker {
  TimerTicker._();

  static final TimerTicker instance = TimerTicker._();

  /// Increments once per second while the ticker is running. Widgets listen to
  /// this with a [ValueListenableBuilder] so that only the elapsed-time text
  /// rebuilds, never the surrounding card.
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  Timer? _timer;
  int _subscribers = 0;

  /// Registers a listener. The underlying timer starts on the first subscriber.
  void acquire() {
    _subscribers++;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
  }

  /// Unregisters a listener. The underlying timer stops when the last
  /// subscriber releases (e.g. on pause, complete, archive, delete, or when the
  /// card leaves the viewport and is disposed).
  void release() {
    if (_subscribers > 0) _subscribers--;
    if (_subscribers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
