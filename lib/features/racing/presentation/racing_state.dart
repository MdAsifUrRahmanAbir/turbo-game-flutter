import 'package:flutter/foundation.dart';

enum RacingScreen { menu, race, gameOver }

@immutable
class RacingState {
  const RacingState({
    this.screen = RacingScreen.menu,
    this.bestScore = 0,
    this.lastScore = 0,
    this.lastCoins = 0,
    this.totalCoins = 0,
  });

  final RacingScreen screen;
  final int bestScore;
  final int lastScore;
  final int lastCoins;
  final int totalCoins;

  bool get isNewBest => lastScore > 0 && lastScore >= bestScore;

  RacingState copyWith({
    RacingScreen? screen,
    int? bestScore,
    int? lastScore,
    int? lastCoins,
    int? totalCoins,
  }) {
    return RacingState(
      screen: screen ?? this.screen,
      bestScore: bestScore ?? this.bestScore,
      lastScore: lastScore ?? this.lastScore,
      lastCoins: lastCoins ?? this.lastCoins,
      totalCoins: totalCoins ?? this.totalCoins,
    );
  }
}
