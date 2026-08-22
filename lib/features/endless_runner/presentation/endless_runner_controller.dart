import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'endless_runner_state.dart';

final endlessRunnerControllerProvider =
    NotifierProvider<EndlessRunnerController, EndlessRunnerState>(
  EndlessRunnerController.new,
);

class EndlessRunnerController extends Notifier<EndlessRunnerState> {
  @override
  EndlessRunnerState build() => const EndlessRunnerState();

  void start() {
    state = state.copyWith(
      screen: EndlessRunnerStatus.playing,
      score: 0,
      coins: 0,
      distance: 0,
      shieldCharge: 0,
    );
  }

  void pause() => state = state.copyWith(screen: EndlessRunnerStatus.paused);

  void resume() => state = state.copyWith(screen: EndlessRunnerStatus.playing);

  void finish({
    required int score,
    required int coins,
    required double distance,
  }) {
    final bestScore = score > state.bestScore ? score : state.bestScore;
    final bestDistance =
        distance > state.bestDistance ? distance : state.bestDistance;
    state = state.copyWith(
      screen: EndlessRunnerStatus.gameOver,
      score: score,
      bestScore: bestScore,
      coins: coins,
      totalCoins: state.totalCoins + coins,
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

  void backToMenu() => state = state.copyWith(screen: EndlessRunnerStatus.menu);
}
