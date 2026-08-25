import 'package:flutter/foundation.dart';

enum SunsetHoopsStatus { menu, playing, paused, gameOver }

@immutable
class SunsetHoopsState {
  const SunsetHoopsState({
    this.status = SunsetHoopsStatus.menu,
    this.score = 0,
    this.bestScore = 0,
    this.makes = 0,
    this.shotsTaken = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.misses = 0,
  });

  final SunsetHoopsStatus status;
  final int score;
  final int bestScore;
  final int makes;
  final int shotsTaken;
  final int streak;
  final int bestStreak;
  final int misses;

  bool get isNewBest => score > 0 && score >= bestScore;

  int get accuracyPercent =>
      shotsTaken == 0 ? 0 : ((makes / shotsTaken) * 100).round();

  SunsetHoopsState copyWith({
    SunsetHoopsStatus? status,
    int? score,
    int? bestScore,
    int? makes,
    int? shotsTaken,
    int? streak,
    int? bestStreak,
    int? misses,
  }) {
    return SunsetHoopsState(
      status: status ?? this.status,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      makes: makes ?? this.makes,
      shotsTaken: shotsTaken ?? this.shotsTaken,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      misses: misses ?? this.misses,
    );
  }
}