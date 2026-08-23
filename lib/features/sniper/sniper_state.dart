import 'package:flutter/foundation.dart';

enum SniperStatus { menu, playing, paused, gameOver }

@immutable
class SniperState {
  const SniperState({
    this.status = SniperStatus.menu,
    this.score = 0,
    this.bestScore = 0,
    this.wave = 1,
    this.strikes = 0,
    this.maxStrikes = 3,
    this.combo = 0,
    this.ammo = 6,
    this.maxAmmo = 6,
    this.reloading = false,
    this.shotsFired = 0,
    this.shotsHit = 0,
  });

  final SniperStatus status;
  final int score;
  final int bestScore;
  final int wave;
  final int strikes;
  final int maxStrikes;
  final int combo;
  final int ammo;
  final int maxAmmo;
  final bool reloading;
  final int shotsFired;
  final int shotsHit;

  bool get isNewBest => score > 0 && score >= bestScore;

  int get accuracyPercent =>
      shotsFired == 0 ? 0 : ((shotsHit / shotsFired) * 100).round();

  SniperState copyWith({
    SniperStatus? status,
    int? score,
    int? bestScore,
    int? wave,
    int? strikes,
    int? maxStrikes,
    int? combo,
    int? ammo,
    int? maxAmmo,
    bool? reloading,
    int? shotsFired,
    int? shotsHit,
  }) {
    return SniperState(
      status: status ?? this.status,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      wave: wave ?? this.wave,
      strikes: strikes ?? this.strikes,
      maxStrikes: maxStrikes ?? this.maxStrikes,
      combo: combo ?? this.combo,
      ammo: ammo ?? this.ammo,
      maxAmmo: maxAmmo ?? this.maxAmmo,
      reloading: reloading ?? this.reloading,
      shotsFired: shotsFired ?? this.shotsFired,
      shotsHit: shotsHit ?? this.shotsHit,
    );
  }
}
