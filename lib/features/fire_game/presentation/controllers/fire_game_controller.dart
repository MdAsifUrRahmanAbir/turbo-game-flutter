import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fire_game_state.dart';

final fireGameControllerProvider =
NotifierProvider.autoDispose<FireGameController, FireGameState>(
  FireGameController.new,
);

class FireGameController extends Notifier<FireGameState> {
  @override
  FireGameState build() {
    return const FireGameState();
  }

  void startGame() {
    state = state.copyWith(
      status: FireGameStatus.playing,
      score: 0,
      health: 100,
      wave: 1,
      enemiesDefeated: 0,
    );
  }

  void pauseGame() {
    if (state.status != FireGameStatus.playing) {
      return;
    }

    state = state.copyWith(
      status: FireGameStatus.paused,
    );
  }

  void resumeGame() {
    if (state.status != FireGameStatus.paused) {
      return;
    }

    state = state.copyWith(
      status: FireGameStatus.playing,
    );
  }

  void gameOver() {
    final bestScore =
    state.score > state.bestScore ? state.score : state.bestScore;

    state = state.copyWith(
      status: FireGameStatus.gameOver,
      bestScore: bestScore,
    );
  }

  void backToMenu() {
    state = state.copyWith(
      status: FireGameStatus.menu,
    );
  }

  void updateHud({
    required int score,
    required int health,
    required int wave,
    required int enemiesDefeated,
  }) {
    state = state.copyWith(
      score: score,
      health: health,
      wave: wave,
      enemiesDefeated: enemiesDefeated,
    );
  }
}