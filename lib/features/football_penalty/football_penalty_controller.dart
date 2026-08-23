import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sfx.dart';
import '../../core/audio/sfx_player.dart';
import '../../core/feedback/haptics.dart';
import '../../core/persistence/game_progress_store.dart';
import '../../core/settings/settings_controller.dart';
import 'football_penalty_state.dart';

final footballPenaltyControllerProvider =
NotifierProvider<FootballPenaltyController, FootballPenaltyState>(
  FootballPenaltyController.new,
);

class FootballPenaltyController extends Notifier<FootballPenaltyState> {
  @override
  FootballPenaltyState build() {
    final store = ref.watch(gameProgressStoreProvider);
    return FootballPenaltyState(
      bestScore: store.getInt(ProgressKeys.penaltyBestScore),
      bestRound: store.getInt(ProgressKeys.penaltyBestRound, fallback: 1),
    );
  }

  bool get _soundOn => ref.read(settingsControllerProvider).soundEnabled;
  bool get _hapticsOn => ref.read(settingsControllerProvider).hapticsEnabled;
  void _play(Sfx sfx) => ref.read(sfxPlayerProvider).play(sfx, enabled: _soundOn);

  void start() {
    _play(Sfx.confirm);
    AppHaptics.light(_hapticsOn);
    state = state.copyWith(
      status: FootballPenaltyStatus.playing,
      score: 0,
      shotsTaken: 0,
      goals: 0,
      saves: 0,
      streak: 0,
      round: 1,
      lastResult: PenaltyResult.none,
      lastCommentary: '',
    );
  }

  void pause() {
    _play(Sfx.tap);
    state = state.copyWith(status: FootballPenaltyStatus.paused);
  }

  void resume() {
    _play(Sfx.tap);
    state = state.copyWith(status: FootballPenaltyStatus.playing);
  }

  void backToMenu() {
    _play(Sfx.back);
    AppHaptics.selection(_hapticsOn);
    state = state.copyWith(status: FootballPenaltyStatus.menu);
  }

  /// Per-shot outcome: sound, haptics and the commentary line to show.
  void updateShot({required PenaltyResult result, required int points, required String commentary}) {
    switch (result) {
      case PenaltyResult.goal:
        _play(Sfx.goal);
        AppHaptics.medium(_hapticsOn);
      case PenaltyResult.saved:
        _play(Sfx.save);
        AppHaptics.light(_hapticsOn);
      case PenaltyResult.miss:
        _play(Sfx.miss);
        AppHaptics.light(_hapticsOn);
      case PenaltyResult.none:
        break;
    }
    state = state.copyWith(lastCommentary: commentary);
  }

  /// Fires after every shot resolves. [ended] is true only when the run is
  /// actually over (round failed) — a successful round-advance keeps
  /// `ended` false and play continues with a tougher keeper.
  void updateHud({
    required int score,
    required int shots,
    required int goals,
    required int streak,
    required int round,
    required PenaltyResult result,
    required bool ended,
  }) {
    final wasRound = state.round;
    state = state.copyWith(
      score: score,
      shotsTaken: shots,
      goals: goals,
      streak: streak,
      round: round,
      lastResult: result,
    );

    if (round > wasRound) {
      _play(Sfx.levelUp);
      AppHaptics.medium(_hapticsOn);
    }

    if (!ended) return;

    final store = ref.read(gameProgressStoreProvider);
    final persistedBestScore = store.getInt(ProgressKeys.penaltyBestScore);
    final persistedBestRound = store.getInt(ProgressKeys.penaltyBestRound, fallback: 1);
    final newBestScore = score > persistedBestScore;
    final newBestRound = round > persistedBestRound;
    if (newBestScore) store.setInt(ProgressKeys.penaltyBestScore, score);
    if (newBestRound) store.setInt(ProgressKeys.penaltyBestRound, round);

    if (newBestScore || newBestRound) {
      _play(Sfx.win);
      AppHaptics.heavy(_hapticsOn);
    } else {
      _play(Sfx.lose);
      AppHaptics.medium(_hapticsOn);
    }

    state = state.copyWith(
      status: FootballPenaltyStatus.complete,
      bestScore: newBestScore ? score : persistedBestScore,
      bestRound: newBestRound ? round : persistedBestRound,
    );
  }
}
