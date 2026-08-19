import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'racing_state.dart';

final racingControllerProvider =
    NotifierProvider<RacingController, RacingState>(
  RacingController.new,
);

class RacingController extends Notifier<RacingState> {
  @override
  RacingState build() => const RacingState();

  void startRace() {
    state = state.copyWith(screen: RacingScreen.race);
  }

  void finishRace({required int score, required int coins}) {
    final best = score > state.bestScore ? score : state.bestScore;
    state = state.copyWith(
      screen: RacingScreen.gameOver,
      lastScore: score,
      lastCoins: coins,
      bestScore: best,
      totalCoins: state.totalCoins + coins,
    );
  }

  void backToMenu() {
    state = state.copyWith(screen: RacingScreen.menu);
  }
}
