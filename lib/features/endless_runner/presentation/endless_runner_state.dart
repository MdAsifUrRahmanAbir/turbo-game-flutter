enum EndlessRunnerStatus { menu, playing, paused, gameOver }

class EndlessRunnerState {
  const EndlessRunnerState({
    this.status = EndlessRunnerStatus.menu,
    this.score = 0,
    this.bestScore = 0,
    this.coins = 0,
    this.totalCoins = 0,
    this.distance = 0,
    this.bestDistance = 0,
    this.shieldCharge = 0,
  });

  final EndlessRunnerStatus status;
  final int score;
  final int bestScore;
  final int coins;
  final int totalCoins;
  final double distance;
  final double bestDistance;

  /// 0..1 — how much of the shield's remaining duration is left. 0 means no
  /// shield is active.
  final double shieldCharge;

  bool get isNewBest => score > 0 && score >= bestScore;

  EndlessRunnerState copyWith({
    EndlessRunnerStatus? screen,
    int? score,
    int? bestScore,
    int? coins,
    int? totalCoins,
    double? distance,
    double? bestDistance,
    double? shieldCharge,
  }) {
    return EndlessRunnerState(
      status: screen ?? status,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      coins: coins ?? this.coins,
      totalCoins: totalCoins ?? this.totalCoins,
      distance: distance ?? this.distance,
      bestDistance: bestDistance ?? this.bestDistance,
      shieldCharge: shieldCharge ?? this.shieldCharge,
    );
  }
}
