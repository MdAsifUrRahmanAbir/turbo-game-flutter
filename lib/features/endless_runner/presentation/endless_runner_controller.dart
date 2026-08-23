import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/persistence/game_progress_store.dart';
import '../../../core/settings/settings_controller.dart';
import 'endless_runner_state.dart';

final endlessRunnerControllerProvider =
    NotifierProvider<EndlessRunnerController, EndlessRunnerState>(
  EndlessRunnerController.new,
);

class EndlessRunnerController extends Notifier<EndlessRunnerState> {
  @override
  EndlessRunnerState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return EndlessRunnerState(
      bestScore: store.getInt(ProgressKeys.runnerBestScore),
      bestDistance: store.getDouble(ProgressKeys.runnerBestDistance),
      totalCoins: store.getInt(ProgressKeys.runnerTotalCoins),
    );
  }

  bool get _sound => ref.read(settingsControllerProvider).soundEnabled;
  bool get _haptics => ref.read(settingsControllerProvider).hapticsEnabled;

  void start() {
    ref.read(sfxPlayerProvider).play(Sfx.confirm, enabled: _sound);
    AppHaptics.light(_haptics);
    state = state.copyWith(
      screen: EndlessRunnerStatus.playing,
      score: 0,
      coins: 0,
      distance: 0,
      shieldCharge: 0,
    );
  }

  void pause() {
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: _sound);
    AppHaptics.selection(_haptics);
    state = state.copyWith(screen: EndlessRunnerStatus.paused);
  }

  void resume() {
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: _sound);
    AppHaptics.selection(_haptics);
    state = state.copyWith(screen: EndlessRunnerStatus.playing);
  }

  void finish({
    required int score,
    required int coins,
    required double distance,
  }) {
    final isNewBest = score > 0 && score >= state.bestScore;
    final bestScore = score > state.bestScore ? score : state.bestScore;
    final bestDistance =
        distance > state.bestDistance ? distance : state.bestDistance;
    final totalCoins = state.totalCoins + coins;

    final store = ref.read(gameProgressStoreProvider);
    store.setInt(ProgressKeys.runnerBestScore, bestScore);
    store.setDouble(ProgressKeys.runnerBestDistance, bestDistance);
    store.setInt(ProgressKeys.runnerTotalCoins, totalCoins);

    final sfxPlayer = ref.read(sfxPlayerProvider);
    if (isNewBest) {
      sfxPlayer.play(Sfx.win, enabled: _sound);
      AppHaptics.medium(_haptics);
    } else {
      sfxPlayer.play(Sfx.crash, enabled: _sound);
      AppHaptics.heavy(_haptics);
    }

    state = state.copyWith(
      screen: EndlessRunnerStatus.gameOver,
      score: score,
      bestScore: bestScore,
      coins: coins,
      totalCoins: totalCoins,
      distance: distance,
      bestDistance: bestDistance,
      shieldCharge: 0,
    );
  }

  void updateHud({
    required int score,
    required int coins,
    required double distance,
    double shieldCharge = 0,
  }) {
    state = state.copyWith(
      score: score,
      coins: coins,
      distance: distance,
      shieldCharge: shieldCharge,
    );
  }

  void backToMenu() {
    ref.read(sfxPlayerProvider).play(Sfx.back, enabled: _sound);
    AppHaptics.selection(_haptics);
    state = state.copyWith(screen: EndlessRunnerStatus.menu);
  }
}
