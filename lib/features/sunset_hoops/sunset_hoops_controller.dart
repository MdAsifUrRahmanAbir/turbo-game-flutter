import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sfx.dart';
import '../../core/audio/sfx_player.dart';
import '../../core/feedback/haptics.dart';
import '../../core/persistence/game_progress_store.dart';
import '../../core/settings/settings_controller.dart';
import 'sunset_hoops_state.dart';

final sunsetHoopsControllerProvider =
NotifierProvider<SunsetHoopsController, SunsetHoopsState>(
  SunsetHoopsController.new,
);

class SunsetHoopsController extends Notifier<SunsetHoopsState> {
  @override
  SunsetHoopsState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return SunsetHoopsState(
      bestScore: store.getInt(ProgressKeys.hoopsBestScore),
      bestStreak: store.getInt(ProgressKeys.hoopsBestStreak),
    );
  }

  bool get _sound => ref.read(settingsControllerProvider).soundEnabled;
  bool get _haptics => ref.read(settingsControllerProvider).hapticsEnabled;
  void _play(Sfx sfx) => ref.read(sfxPlayerProvider).play(sfx, enabled: _sound);

  void start() {
    _play(Sfx.confirm);
    AppHaptics.light(_haptics);
    state = state.copyWith(
      status: SunsetHoopsStatus.playing,
      score: 0,
      makes: 0,
      shotsTaken: 0,
      streak: 0,
      misses: 0,
    );
  }

  void pause() {
    _play(Sfx.tap);
    AppHaptics.selection(_haptics);
    state = state.copyWith(status: SunsetHoopsStatus.paused);
  }

  void resume() {
    _play(Sfx.tap);
    AppHaptics.selection(_haptics);
    state = state.copyWith(status: SunsetHoopsStatus.playing);
  }

  void backToMenu() {
    _play(Sfx.back);
    AppHaptics.selection(_haptics);
    state = state.copyWith(status: SunsetHoopsStatus.menu);
  }

  /// Called on every made basket.
  void registerMake({required int points, required bool banked}) {
    final newStreak = state.streak + 1;
    final bestStreak = newStreak > state.bestStreak ? newStreak : state.bestStreak;
    state = state.copyWith(
      score: state.score + points,
      makes: state.makes + 1,
      shotsTaken: state.shotsTaken + 1,
      streak: newStreak,
      bestStreak: bestStreak,
    );
    _play(banked ? Sfx.score : Sfx.goal);
    AppHaptics.medium(_haptics);
  }

  /// Called on every missed shot. Ends the run once [SunsetHoopsConfig.maxMisses]
  /// is reached.
  void registerMiss() {
    final misses = state.misses + 1;
    state = state.copyWith(
      shotsTaken: state.shotsTaken + 1,
      streak: 0,
      misses: misses,
    );
    _play(Sfx.miss);
    AppHaptics.light(_haptics);
  }

  /// Fired by the screen once the game engine reports the run is over.
  void finish() {
    final store = ref.read(gameProgressStoreProvider);
    final persistedBest = store.getInt(ProgressKeys.hoopsBestScore);
    final persistedBestStreak = store.getInt(ProgressKeys.hoopsBestStreak);
    final newBestScore = state.score > persistedBest;
    final newBestStreak = state.bestStreak > persistedBestStreak;

    if (newBestScore) store.setInt(ProgressKeys.hoopsBestScore, state.score);
    if (newBestStreak) store.setInt(ProgressKeys.hoopsBestStreak, state.bestStreak);

    if (newBestScore) {
      _play(Sfx.win);
      AppHaptics.heavy(_haptics);
    } else {
      _play(Sfx.lose);
      AppHaptics.medium(_haptics);
    }

    state = state.copyWith(
      status: SunsetHoopsStatus.gameOver,
      bestScore: newBestScore ? state.score : persistedBest,
      bestStreak: newBestStreak ? state.bestStreak : persistedBestStreak,
    );
  }
}