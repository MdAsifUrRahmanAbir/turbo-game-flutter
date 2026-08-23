import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/persistence/game_progress_store.dart';
import '../../../core/settings/settings_controller.dart';
import 'angry_bird_levels.dart';
import 'angry_bird_state.dart';

final angryBirdControllerProvider =
    NotifierProvider<AngryBirdController, AngryBirdState>(
  AngryBirdController.new,
);

class AngryBirdController extends Notifier<AngryBirdState> {
  @override
  AngryBirdState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return AngryBirdState(
      unlockedLevels: store.getInt(ProgressKeys.smashUnlockedLevels, fallback: 1),
      levelStars: store.getIntMap(ProgressKeys.smashLevelStars),
      totalScore: store.getInt(ProgressKeys.smashTotalScore),
    );
  }

  bool get _sound => ref.read(settingsControllerProvider).soundEnabled;
  bool get _haptics => ref.read(settingsControllerProvider).hapticsEnabled;
  void _play(Sfx sfx) => ref.read(sfxPlayerProvider).play(sfx, enabled: _sound);

  void selectLevel(int index) {
    if (index >= state.unlockedLevels) return;
    _play(Sfx.tap);
    AppHaptics.selection(_haptics);
    state = state.copyWith(
      currentLevel: index,
      screen: AngryBirdStatus.playing,
    );
  }

  /// Called once a run ends. [won] is true only when every pig in the
  /// level was destroyed before the bird queue ran out.
  void finishLevel({required int score, required bool won}) {
    if (!won) {
      _play(Sfx.lose);
      AppHaptics.heavy(_haptics);
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

    if (stars == 3) {
      _play(Sfx.win);
      AppHaptics.heavy(_haptics);
    } else {
      _play(Sfx.levelUp);
      AppHaptics.medium(_haptics);
    }

    final prevStars = state.starsFor(state.currentLevel);
    final updatedStars = Map<int, int>.from(state.levelStars);
    if (stars > prevStars) updatedStars[state.currentLevel] = stars;

    final nextUnlocked =
        (state.currentLevel + 2).clamp(1, angryBirdLevels.length);
    final unlockedLevels =
        nextUnlocked > state.unlockedLevels ? nextUnlocked : state.unlockedLevels;
    final totalScore = state.totalScore + score;

    final store = ref.read(gameProgressStoreProvider);
    if (unlockedLevels != state.unlockedLevels) {
      store.setInt(ProgressKeys.smashUnlockedLevels, unlockedLevels);
    }
    if (!identical(updatedStars, state.levelStars)) {
      store.setIntMap(ProgressKeys.smashLevelStars, updatedStars);
    }
    store.setInt(ProgressKeys.smashTotalScore, totalScore);

    state = state.copyWith(
      screen: AngryBirdStatus.levelComplete,
      lastScore: score,
      lastStars: stars,
      totalScore: totalScore,
      unlockedLevels: unlockedLevels,
      levelStars: updatedStars,
    );
  }

  void retry() {
    _play(Sfx.confirm);
    AppHaptics.light(_haptics);
    state = state.copyWith(screen: AngryBirdStatus.playing);
  }

  void nextLevel() {
    _play(Sfx.confirm);
    AppHaptics.light(_haptics);
    final next = state.currentLevel + 1;
    if (next >= angryBirdLevels.length) {
      state = state.copyWith(screen: AngryBirdStatus.menu);
      return;
    }
    state = state.copyWith(currentLevel: next, screen: AngryBirdStatus.playing);
  }

  void backToMenu() {
    _play(Sfx.back);
    AppHaptics.selection(_haptics);
    state = state.copyWith(screen: AngryBirdStatus.menu);
  }
}
