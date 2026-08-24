import 'package:flutter/foundation.dart';

enum GultiStatus { menu, playing, levelComplete, gameOver }

@immutable
class GultiState {
  const GultiState({
    this.status = GultiStatus.menu,
    this.currentLevel = 0,
    this.unlockedLevels = 1,
    this.levelStars = const {},
    this.totalScore = 0,
    this.bestScore = 0,
    this.lastScore = 0,
    this.lastStars = 0,
    this.lastBirdsHit = 0,
    this.lastTotalBirds = 0,
    this.lastStonesUsed = 0,
    this.lastStoneCount = 0,
  });

  final GultiStatus status;
  final int currentLevel;
  final int unlockedLevels;
  final Map<int, int> levelStars;
  final int totalScore;
  final int bestScore;

  final int lastScore;
  final int lastStars;
  final int lastBirdsHit;
  final int lastTotalBirds;
  final int lastStonesUsed;
  final int lastStoneCount;

  int starsFor(int levelIndex) => levelStars[levelIndex] ?? 0;

  double get lastAccuracy =>
      lastStonesUsed == 0 ? 0 : (lastBirdsHit / lastStonesUsed).clamp(0.0, 1.0);

  GultiState copyWith({
    GultiStatus? status,
    int? currentLevel,
    int? unlockedLevels,
    Map<int, int>? levelStars,
    int? totalScore,
    int? bestScore,
    int? lastScore,
    int? lastStars,
    int? lastBirdsHit,
    int? lastTotalBirds,
    int? lastStonesUsed,
    int? lastStoneCount,
  }) {
    return GultiState(
      status: status ?? this.status,
      currentLevel: currentLevel ?? this.currentLevel,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      levelStars: levelStars ?? this.levelStars,
      totalScore: totalScore ?? this.totalScore,
      bestScore: bestScore ?? this.bestScore,
      lastScore: lastScore ?? this.lastScore,
      lastStars: lastStars ?? this.lastStars,
      lastBirdsHit: lastBirdsHit ?? this.lastBirdsHit,
      lastTotalBirds: lastTotalBirds ?? this.lastTotalBirds,
      lastStonesUsed: lastStonesUsed ?? this.lastStonesUsed,
      lastStoneCount: lastStoneCount ?? this.lastStoneCount,
    );
  }
}
