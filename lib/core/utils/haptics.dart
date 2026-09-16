import 'package:flutter/services.dart';

/// Light vibration feedback for the player gestures.
///
/// A gesture fires dozens of updates a second, so this throttles: a swipe gives
/// a tick every step rather than a continuous buzz, and the whole thing is off
/// when the user turns haptics off in Settings.
class Haptics {
  const Haptics._();

  static bool enabled = true;

  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minGap = Duration(milliseconds: 45);

  /// One tick as a value crosses a step — volume, brightness, seek.
  static void tick() {
    if (!enabled) return;
    final now = DateTime.now();
    if (now.difference(_last) < _minGap) return;
    _last = now;
    HapticFeedback.selectionClick();
  }

  /// A gesture started or finished, or a control was toggled.
  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Something committed — entering multi-select, marking an A-B point.
  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }
}
