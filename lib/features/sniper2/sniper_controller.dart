import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sniper_config.dart';
import 'sniper_state.dart';

final sniperControllerProvider =
    NotifierProvider<SniperController, SniperState>(SniperController.new);

class SniperController extends Notifier<SniperState> {
  @override
  SniperState build() => const SniperState();

  void openLevelSelect() {
    state = state.copyWith(status: SniperStatus.levelSelect);
  }

  void backToMenu() {
    state = state.copyWith(status: SniperStatus.menu);
  }

  void startLevel(int level) {
    final config = SniperConfig.levels[level - 1];
    state = state.copyWith(
      status: SniperStatus.playing,
      currentLevel: level,
      score: 0,
      ammo: config.ammo,
      targetsHit: 0,
      targetGoal: config.targetGoal,
      timeRemaining: config.timeLimit,
      clearTimeRemaining: config.timeLimit == null,
      shotsFired: 0,
      shotsHit: 0,
      completionBonus: 0,
      failReason: SniperFailReason.none,
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

  void missionComplete({required int score, required int completionBonus}) {
    final unlocked = state.currentLevel >= state.unlockedLevel &&
            state.currentLevel < SniperConfig.levels.length
        ? state.currentLevel + 1
        : state.unlockedLevel;
    state = state.copyWith(
      status: SniperStatus.missionComplete,
      score: score,
      completionBonus: completionBonus,
      unlockedLevel: unlocked,
    );
  }

  void missionFailed({required int score, required SniperFailReason reason}) {
    state = state.copyWith(
      status: SniperStatus.missionFailed,
      score: score,
      failReason: reason,
    );
  }

  void updateHud({
    required int score,
    required int ammo,
    required int targetsHit,
    double? timeRemaining,
    required int shotsFired,
    required int shotsHit,
  }) {
    state = state.copyWith(
      score: score,
      ammo: ammo,
      targetsHit: targetsHit,
      timeRemaining: timeRemaining,
      shotsFired: shotsFired,
      shotsHit: shotsHit,
    );
  }
}
