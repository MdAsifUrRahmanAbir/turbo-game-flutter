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
    this.wave = 1,
    this.enemiesDefeated = 0,
    this.bestScore = 0,
  });

  final FireGameStatus status;
  final int score;
  final int health;
  final int wave;
  final int enemiesDefeated;
  final int bestScore;

  FireGameState copyWith({
    FireGameStatus? status,
    int? score,
    int? health,
    int? wave,
    int? enemiesDefeated,
    int? bestScore,
  }) {
    return FireGameState(
      status: status ?? this.status,
      score: score ?? this.score,
      health: health ?? this.health,
      wave: wave ?? this.wave,
      enemiesDefeated: enemiesDefeated ?? this.enemiesDefeated,
      bestScore: bestScore ?? this.bestScore,
    );
  }
}
