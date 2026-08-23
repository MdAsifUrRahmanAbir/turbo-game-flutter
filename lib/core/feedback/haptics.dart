import 'package:flutter/services.dart';

/// Tiny wrapper around [HapticFeedback] that never throws — desktop/web
/// targets don't implement the haptics channel, so every call is guarded.
/// Every call site passes the live `settings.hapticsEnabled` flag rather
/// than this class reaching into Riverpod itself, keeping it usable from
/// both widgets and Flame's [Game] classes.
abstract final class AppHaptics {
  static void selection(bool enabled) => _run(enabled, HapticFeedback.selectionClick);

  static void light(bool enabled) => _run(enabled, HapticFeedback.lightImpact);

  static void medium(bool enabled) => _run(enabled, HapticFeedback.mediumImpact);

  static void heavy(bool enabled) => _run(enabled, HapticFeedback.heavyImpact);

  static void _run(bool enabled, Future<void> Function() call) {
    if (!enabled) return;
    call().catchError((_) {});
  }
}
