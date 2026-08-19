import 'package:flutter/foundation.dart';

enum AngryBirdStatus { menu, playing, levelComplete, gameOver }

@immutable
class AngryBirdState {
  const AngryBirdState({
    this.screen = AngryBirdStatus.menu,
    this.currentLevel = 0,
    this.unlockedLevels = 1,
    this.levelStars = const {},
    this.lastScore = 0,
    this.lastStars = 0,
    this.totalScore = 0,
  });

  final AngryBirdStatus screen;
  final int currentLevel;
  final int unlockedLevels;
  final Map<int, int> levelStars;
  final int lastScore;
  final int lastStars;
  final int totalScore;

  int starsFor(int levelIndex) => levelStars[levelIndex] ?? 0;

  AngryBirdState copyWith({
    AngryBirdStatus? screen,
    int? currentLevel,
    int? unlockedLevels,
    Map<int, int>? levelStars,
    int? lastScore,
    int? lastStars,
    int? totalScore,
  }) {
    return AngryBirdState(
      screen: screen ?? this.screen,
      currentLevel: currentLevel ?? this.currentLevel,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      levelStars: levelStars ?? this.levelStars,
      lastScore: lastScore ?? this.lastScore,
      lastStars: lastStars ?? this.lastStars,
      totalScore: totalScore ?? this.totalScore,
    );
  }
}
