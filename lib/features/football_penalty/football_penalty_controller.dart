import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'football_penalty_state.dart';

final footballPenaltyControllerProvider =
NotifierProvider<FootballPenaltyController, FootballPenaltyState>(
  FootballPenaltyController.new,
);

class FootballPenaltyController extends Notifier<FootballPenaltyState> {
  @override
  FootballPenaltyState build() => const FootballPenaltyState();

  void start() => state = state.copyWith(
    status: FootballPenaltyStatus.playing,
    score: 0,
    shotsTaken: 0,
    goals: 0,
    saves: 0,
    streak: 0,
    lastResult: PenaltyResult.none,
  );

  void pause() => state = state.copyWith(status: FootballPenaltyStatus.paused);
  void resume() => state = state.copyWith(status: FootballPenaltyStatus.playing);
  void backToMenu() => state = state.copyWith(status: FootballPenaltyStatus.menu);

  void updateHud({required int score, required int shots, required int goals, required int streak, required PenaltyResult result}) {
    state = state.copyWith(score: score, shotsTaken: shots, goals: goals, streak: streak, lastResult: result);
  }

  void updateShot({required PenaltyResult result, required int points}) {
    final shots = state.shotsTaken + 1;
    final goals = state.goals + (result == PenaltyResult.goal ? 1 : 0);
    final saves = state.saves + (result == PenaltyResult.saved ? 1 : 0);
    final streak = result == PenaltyResult.goal ? state.streak + 1 : 0;
    final score = state.score + points;
    state = state.copyWith(
      shotsTaken: shots,
      goals: goals,
      saves: saves,
      streak: streak,
      score: score,
      bestScore: score > state.bestScore ? score : state.bestScore,
      lastResult: result,
      status: shots >= 5 ? FootballPenaltyStatus.complete : FootballPenaltyStatus.playing,
    );
  }
}
