import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sniper_state.dart';

final sniperControllerProvider =
    NotifierProvider.autoDispose<SniperController, SniperState>(
  SniperController.new,
);

class SniperController extends Notifier<SniperState> {
  @override
  SniperState build() => const SniperState();

  void startGame() {
    state = state.copyWith(
      status: SniperStatus.playing,
      score: 0,
      wave: 1,
      strikes: 0,
      combo: 0,
      ammo: state.maxAmmo,
      reloading: false,
      shotsFired: 0,
      shotsHit: 0,
    );
  }

  void pauseGame() {
    if (state.status != SniperStatus.playing) return;
    state = state.copyWith(status: SniperStatus.paused);
  }

  void resumeGame() {
    if (state.status != SniperStatus.paused) return;
    state = state.copyWith(status: SniperStatus.playing);
  }

  void gameOver() {
    final bestScore = state.score > state.bestScore ? state.score : state.bestScore;
    state = state.copyWith(status: SniperStatus.gameOver, bestScore: bestScore);
  }

  void backToMenu() {
    state = state.copyWith(status: SniperStatus.menu);
  }

  void updateHud({
    required int score,
    required int wave,
    required int strikes,
    required int combo,
    required int ammo,
    required bool reloading,
    required int shotsFired,
    required int shotsHit,
  }) {
    state = state.copyWith(
      score: score,
      wave: wave,
      strikes: strikes,
      combo: combo,
      ammo: ammo,
      reloading: reloading,
      shotsFired: shotsFired,
      shotsHit: shotsHit,
    );
  }
}
