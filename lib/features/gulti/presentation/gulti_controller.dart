import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/persistence/game_progress_store.dart';
import '../../../core/settings/settings_controller.dart';
import 'gulti_levels.dart';
import 'gulti_state.dart';

final gultiControllerProvider = NotifierProvider<GultiController, GultiState>(
  GultiController.new,
);

class GultiController extends Notifier<GultiState> {
  @override
  GultiState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return GultiState(
      unlockedLevels: store.getInt(ProgressKeys.gultiUnlockedLevels, fallback: 1),
      levelStars: store.getIntMap(ProgressKeys.gultiLevelStars),
      totalScore: store.getInt(ProgressKeys.gultiTotalScore),
      bestScore: store.getInt(ProgressKeys.gultiBestScore),
    );
  }

  bool get _sound => ref.read(settingsControllerProvider).soundEnabled;
  bool get _haptics => ref.read(settingsControllerProvider).hapticsEnabled;
  void _play(Sfx sfx) => ref.read(sfxPlayerProvider).play(sfx, enabled: _sound);

  void selectLevel(int index) {
    if (index >= state.unlockedLevels) return;
    _play(Sfx.tap);
    AppHaptics.selection(_haptics);
    state = state.copyWith(currentLevel: index, status: GultiStatus.playing);
  }

  /// Called once a run ends. [won] is true only when every bird in the
  /// level was hit before the stones ran out (or the timer expired).
  void finishLevel({
    required int score,
    required int birdsHit,
    required int totalBirds,
    required int stonesUsed,
    required int stoneCount,
    required bool won,
  }) {
    final store = ref.read(gameProgressStoreProvider);
    final bestScore = score > state.bestScore ? score : state.bestScore;
    if (bestScore != state.bestScore) {
      store.setInt(ProgressKeys.gultiBestScore, bestScore);
    }

    if (!won) {
      _play(Sfx.lose);
      AppHaptics.heavy(_haptics);
      state = state.copyWith(
        status: GultiStatus.gameOver,
        lastScore: score,
        lastBirdsHit: birdsHit,
        lastTotalBirds: totalBirds,
        lastStonesUsed: stonesUsed,
        lastStoneCount: stoneCount,
        bestScore: bestScore,
      );
      return;
    }

    final level = gultiLevels[state.currentLevel];
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

    final nextUnlocked = (state.currentLevel + 2).clamp(1, gultiLevels.length);
    final unlockedLevels =
        nextUnlocked > state.unlockedLevels ? nextUnlocked : state.unlockedLevels;
    final totalScore = state.totalScore + score;

    if (unlockedLevels != state.unlockedLevels) {
      store.setInt(ProgressKeys.gultiUnlockedLevels, unlockedLevels);
    }
    if (!identical(updatedStars, state.levelStars)) {
      store.setIntMap(ProgressKeys.gultiLevelStars, updatedStars);
    }
    store.setInt(ProgressKeys.gultiTotalScore, totalScore);

    state = state.copyWith(
      status: GultiStatus.levelComplete,
      lastScore: score,
      lastStars: stars,
      lastBirdsHit: birdsHit,
      lastTotalBirds: totalBirds,
      lastStonesUsed: stonesUsed,
      lastStoneCount: stoneCount,
      totalScore: totalScore,
      unlockedLevels: unlockedLevels,
      levelStars: updatedStars,
      bestScore: bestScore,
    );
  }

  void retry() {
    _play(Sfx.confirm);
    AppHaptics.light(_haptics);
    state = state.copyWith(status: GultiStatus.playing);
  }

  void nextLevel() {
    _play(Sfx.confirm);
    AppHaptics.light(_haptics);
    final next = state.currentLevel + 1;
    if (next >= gultiLevels.length) {
      state = state.copyWith(status: GultiStatus.menu);
      return;
    }
    state = state.copyWith(currentLevel: next, status: GultiStatus.playing);
  }

  void backToMenu() {
    _play(Sfx.back);
    AppHaptics.selection(_haptics);
    state = state.copyWith(status: GultiStatus.menu);
  }
}
