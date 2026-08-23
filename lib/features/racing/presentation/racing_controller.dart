import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/persistence/game_progress_store.dart';
import '../../../core/settings/settings_controller.dart';
import 'racing_state.dart';

final racingControllerProvider =
    NotifierProvider<RacingController, RacingState>(
  RacingController.new,
);

class RacingController extends Notifier<RacingState> {
  @override
  RacingState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return RacingState(
      bestScore: store.getInt(ProgressKeys.racingBestScore),
      totalCoins: store.getInt(ProgressKeys.racingTotalCoins),
    );
  }

  void startRace() {
    _play(Sfx.confirm);
    AppHaptics.light(ref.read(settingsControllerProvider).hapticsEnabled);
    state = state.copyWith(screen: RacingScreen.race);
  }

  void finishRace({required int score, required int coins}) {
    final previousBest = state.bestScore;
    final best = score > previousBest ? score : previousBest;
    final totalCoins = state.totalCoins + coins;
    state = state.copyWith(
      screen: RacingScreen.gameOver,
      lastScore: score,
      lastCoins: coins,
      bestScore: best,
      totalCoins: totalCoins,
    );

    final store = ref.read(gameProgressStoreProvider);
    if (best > previousBest) {
      store.setInt(ProgressKeys.racingBestScore, best);
    }
    store.setInt(ProgressKeys.racingTotalCoins, totalCoins);

    final haptics = ref.read(settingsControllerProvider).hapticsEnabled;
    if (score >= best && score > 0) {
      _play(Sfx.win);
      AppHaptics.medium(haptics);
    } else {
      _play(Sfx.crash);
      AppHaptics.heavy(haptics);
    }
  }

  void backToMenu() {
    _play(Sfx.back);
    AppHaptics.selection(ref.read(settingsControllerProvider).hapticsEnabled);
    state = state.copyWith(screen: RacingScreen.menu);
  }

  void _play(Sfx sfx) {
    final sound = ref.read(settingsControllerProvider).soundEnabled;
    ref.read(sfxPlayerProvider).play(sfx, enabled: sound);
  }
}
