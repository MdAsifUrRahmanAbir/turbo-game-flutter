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
    this.bestScore = 0,
    this.lastResult = PenaltyResult.none,
  });

  final FootballPenaltyStatus status;
  final int score;
  final int shotsTaken;
  final int goals;
  final int saves;
  final int streak;
  final int bestScore;
  final PenaltyResult lastResult;

  int get shotsLeft => 5 - shotsTaken;

  FootballPenaltyState copyWith({
    FootballPenaltyStatus? status,
    int? score,
    int? shotsTaken,
    int? goals,
    int? saves,
    int? streak,
    int? bestScore,
    PenaltyResult? lastResult,
  }) => FootballPenaltyState(
        status: status ?? this.status,
        score: score ?? this.score,
        shotsTaken: shotsTaken ?? this.shotsTaken,
        goals: goals ?? this.goals,
        saves: saves ?? this.saves,
        streak: streak ?? this.streak,
        bestScore: bestScore ?? this.bestScore,
        lastResult: lastResult ?? this.lastResult,
      );
}
