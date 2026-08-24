import 'package:flutter/foundation.dart';

enum SniperStatus {
  menu,
  levelSelect,
  playing,
  paused,
  missionComplete,
  missionFailed,
}

enum SniperFailReason { none, outOfAmmo, timeUp }

@immutable
class SniperState {
  const SniperState({
    this.status = SniperStatus.menu,
    this.currentLevel = 1,
    this.unlockedLevel = 1,
    this.score = 0,
    this.ammo = 0,
    this.targetsHit = 0,
    this.targetGoal = 0,
    this.timeRemaining,
    this.shotsFired = 0,
    this.shotsHit = 0,
    this.completionBonus = 0,
    this.failReason = SniperFailReason.none,
  });

  final SniperStatus status;
  final int currentLevel;
  final int unlockedLevel;
  final int score;
  final int ammo;
  final int targetsHit;
  final int targetGoal;

  /// Null when the current mission has no timer.
  final double? timeRemaining;

  final int shotsFired;
  final int shotsHit;
  final int completionBonus;
  final SniperFailReason failReason;

  int get accuracyPercent =>
      shotsFired == 0 ? 0 : ((shotsHit / shotsFired) * 100).round();

  SniperState copyWith({
    SniperStatus? status,
    int? currentLevel,
    int? unlockedLevel,
    int? score,
    int? ammo,
    int? targetsHit,
    int? targetGoal,
    double? timeRemaining,
    bool clearTimeRemaining = false,
    int? shotsFired,
    int? shotsHit,
    int? completionBonus,
    SniperFailReason? failReason,
  }) {
    return SniperState(
      status: status ?? this.status,
      currentLevel: currentLevel ?? this.currentLevel,
      unlockedLevel: unlockedLevel ?? this.unlockedLevel,
      score: score ?? this.score,
      ammo: ammo ?? this.ammo,
      targetsHit: targetsHit ?? this.targetsHit,
      targetGoal: targetGoal ?? this.targetGoal,
      timeRemaining: clearTimeRemaining ? null : (timeRemaining ?? this.timeRemaining),
      shotsFired: shotsFired ?? this.shotsFired,
      shotsHit: shotsHit ?? this.shotsHit,
      completionBonus: completionBonus ?? this.completionBonus,
      failReason: failReason ?? this.failReason,
    );
  }
}
