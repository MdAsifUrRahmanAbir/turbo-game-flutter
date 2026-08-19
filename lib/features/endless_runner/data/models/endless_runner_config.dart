class EndlessRunnerConfig {
  const EndlessRunnerConfig({
    this.laneCount = 3,
    this.baseSpeed = 280,
    this.maxSpeed = 760,
    this.playerWidth = 52,
    this.playerHeight = 78,
  });

  final int laneCount;
  final double baseSpeed;
  final double maxSpeed;
  final double playerWidth;
  final double playerHeight;
}
