enum FootballPenaltyStatus { menu, playing, paused, complete }

enum PenaltyResult { none, goal, saved, miss }

class FootballPenaltyState {
  const FootballPenaltyState({
    this.status = FootballPenaltyStatus.menu,
    this.score = 0,
    this.shotsTaken = 0,
    this.goals = 0,
    this.saves = 0,
    this.streak = 0,
    this.round = 1,
    this.bestScore = 0,
    this.bestRound = 1,
    this.lastResult = PenaltyResult.none,
    this.lastCommentary = '',
  });

  final FootballPenaltyStatus status;
  final int score;
  final int shotsTaken;
  final int goals;
  final int saves;
  final int streak;
  final int round;
  final int bestScore;
  final int bestRound;
  final PenaltyResult lastResult;
  final String lastCommentary;

  int get shotsLeft => 5 - shotsTaken;

  FootballPenaltyState copyWith({
    FootballPenaltyStatus? status,
    int? score,
    int? shotsTaken,
    int? goals,
    int? saves,
    int? streak,
    int? round,
    int? bestScore,
    int? bestRound,
    PenaltyResult? lastResult,
    String? lastCommentary,
  }) => FootballPenaltyState(
        status: status ?? this.status,
        score: score ?? this.score,
        shotsTaken: shotsTaken ?? this.shotsTaken,
        goals: goals ?? this.goals,
        saves: saves ?? this.saves,
        streak: streak ?? this.streak,
        round: round ?? this.round,
        bestScore: bestScore ?? this.bestScore,
        bestRound: bestRound ?? this.bestRound,
        lastResult: lastResult ?? this.lastResult,
        lastCommentary: lastCommentary ?? this.lastCommentary,
      );
}
