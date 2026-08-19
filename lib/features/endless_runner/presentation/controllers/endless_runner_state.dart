enum EndlessRunnerStatus { menu, playing, paused, gameOver }

class EndlessRunnerState {
  const EndlessRunnerState({
    this.status = EndlessRunnerStatus.menu,
    this.score = 0,
    this.bestScore = 0,
    this.coins = 0,
    this.distance = 0,
  });

  final EndlessRunnerStatus status;
  final int score;
  final int bestScore;
  final int coins;
  final double distance;

  EndlessRunnerState copyWith({
    EndlessRunnerStatus? screen,
    int? score,
    int? bestScore,
    int? coins,
    double? distance,
  }) {
    return EndlessRunnerState(
      status: screen ?? this.status,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      coins: coins ?? this.coins,
      distance: distance ?? this.distance,
    );
  }
}
