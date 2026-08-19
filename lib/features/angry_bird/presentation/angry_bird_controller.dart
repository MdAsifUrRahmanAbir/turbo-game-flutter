import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'angry_bird_levels.dart';
import 'angry_bird_state.dart';

final angryBirdControllerProvider =
    NotifierProvider<AngryBirdController, AngryBirdState>(
  AngryBirdController.new,
);

class AngryBirdController extends Notifier<AngryBirdState> {
  @override
  AngryBirdState build() => const AngryBirdState();

  void selectLevel(int index) {
    if (index >= state.unlockedLevels) return;
    state = state.copyWith(
      currentLevel: index,
      screen: AngryBirdStatus.playing,
    );
  }

  /// Called once a run ends. [won] is true only when every pig in the
  /// level was destroyed before the bird queue ran out.
  void finishLevel({required int score, required bool won}) {
    if (!won) {
      state = state.copyWith(screen: AngryBirdStatus.gameOver, lastScore: score);
      return;
    }

    final level = angryBirdLevels[state.currentLevel];
    var stars = 1;
    if (score >= level.threeStarScore) {
      stars = 3;
    } else if (score >= level.twoStarScore) {
      stars = 2;
    }

    final prevStars = state.starsFor(state.currentLevel);
    final updatedStars = Map<int, int>.from(state.levelStars);
    if (stars > prevStars) updatedStars[state.currentLevel] = stars;

    final nextUnlocked =
        (state.currentLevel + 2).clamp(1, angryBirdLevels.length);

    state = state.copyWith(
      screen: AngryBirdStatus.levelComplete,
      lastScore: score,
      lastStars: stars,
      totalScore: state.totalScore + score,
      unlockedLevels: nextUnlocked > state.unlockedLevels
          ? nextUnlocked
          : state.unlockedLevels,
      levelStars: updatedStars,
    );
  }

  void retry() {
    state = state.copyWith(screen: AngryBirdStatus.playing);
  }

  void nextLevel() {
    final next = state.currentLevel + 1;
    if (next >= angryBirdLevels.length) {
      state = state.copyWith(screen: AngryBirdStatus.menu);
      return;
    }
    state = state.copyWith(currentLevel: next, screen: AngryBirdStatus.playing);
  }

  void backToMenu() {
    state = state.copyWith(screen: AngryBirdStatus.menu);
  }
}
