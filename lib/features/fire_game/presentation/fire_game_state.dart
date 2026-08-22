import 'package:flutter/foundation.dart';

enum FireGameStatus {
  menu,
  playing,
  paused,
  gameOver,
}

@immutable
class FireGameState {
  const FireGameState({
    this.status = FireGameStatus.menu,
    this.score = 0,
    this.health = 100,
    this.maxHealth = 100,
    this.wave = 1,
    this.enemiesDefeated = 0,
    this.bestScore = 0,
    this.combo = 0,
    this.tripleShotCharge = 0,
  });

  final FireGameStatus status;
  final int score;
  final int health;
  final int maxHealth;
  final int wave;
  final int enemiesDefeated;
  final int bestScore;

  /// Consecutive-kill combo stack (0 = no active combo).
  final int combo;

  /// 0..1 — how much of the triple-shot power-up duration is left. 0 means
  /// the power-up isn't active.
  final double tripleShotCharge;

  bool get isNewBest => score > 0 && score >= bestScore;

  FireGameState copyWith({
    FireGameStatus? status,
    int? score,
    int? health,
    int? maxHealth,
    int? wave,
    int? enemiesDefeated,
    int? bestScore,
    int? combo,
    double? tripleShotCharge,
  }) {
    return FireGameState(
      status: status ?? this.status,
      score: score ?? this.score,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      wave: wave ?? this.wave,
      enemiesDefeated: enemiesDefeated ?? this.enemiesDefeated,
      bestScore: bestScore ?? this.bestScore,
      combo: combo ?? this.combo,
      tripleShotCharge: tripleShotCharge ?? this.tripleShotCharge,
    );
  }
}
