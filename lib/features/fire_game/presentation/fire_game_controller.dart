import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/persistence/game_progress_store.dart';
import '../../../core/settings/settings_controller.dart';
import 'fire_game_state.dart';

final fireGameControllerProvider =
    NotifierProvider.autoDispose<FireGameController, FireGameState>(
  FireGameController.new,
);

class FireGameController extends Notifier<FireGameState> {
  @override
  FireGameState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return FireGameState(bestScore: store.getInt(ProgressKeys.fireBestScore));
  }

  void startGame() {
    state = state.copyWith(
      status: FireGameStatus.playing,
      score: 0,
      health: state.maxHealth,
      wave: 1,
      enemiesDefeated: 0,
      combo: 0,
      tripleShotCharge: 0,
    );
    _playFx(Sfx.confirm);
    _haptic(AppHaptics.light);
  }

  void pauseGame() {
    if (state.status != FireGameStatus.playing) {
      return;
    }
    state = state.copyWith(status: FireGameStatus.paused);
    _playFx(Sfx.tap);
    _haptic(AppHaptics.selection);
  }

  void resumeGame() {
    if (state.status != FireGameStatus.paused) {
      return;
    }
    state = state.copyWith(status: FireGameStatus.playing);
    _playFx(Sfx.tap);
    _haptic(AppHaptics.selection);
  }

  void gameOver() {
    final isNewBest = state.score > 0 && state.score >= state.bestScore;
    final bestScore =
        state.score > state.bestScore ? state.score : state.bestScore;

    state = state.copyWith(
      status: FireGameStatus.gameOver,
      bestScore: bestScore,
    );

    if (isNewBest) {
      ref.read(gameProgressStoreProvider).setInt(ProgressKeys.fireBestScore, bestScore);
      _playFx(Sfx.win);
      _haptic(AppHaptics.medium);
    } else {
      _playFx(Sfx.lose);
      _haptic(AppHaptics.heavy);
    }
  }

  void backToMenu() {
    state = state.copyWith(status: FireGameStatus.menu);
    _playFx(Sfx.back);
    _haptic(AppHaptics.light);
  }

  void updateHud({
    required int score,
    required int health,
    required int wave,
    required int enemiesDefeated,
    int combo = 0,
    double tripleShotCharge = 0,
  }) {
    state = state.copyWith(
      score: score,
      health: health,
      wave: wave,
      enemiesDefeated: enemiesDefeated,
      combo: combo,
      tripleShotCharge: tripleShotCharge,
    );
  }

  void _playFx(Sfx sfx) {
    ref.read(sfxPlayerProvider).play(
          sfx,
          enabled: ref.read(settingsControllerProvider).soundEnabled,
        );
  }

  void _haptic(void Function(bool enabled) call) {
    call(ref.read(settingsControllerProvider).hapticsEnabled);
  }
}
