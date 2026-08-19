class FireGameConfig {
  const FireGameConfig({
    this.playerSize = 42,
    this.playerSpeed = 260,
    this.projectileSpeed = 520,
    this.enemySpeed = 90,
    this.spawnInterval = 1.2,
    this.maxHealth = 100,
    this.damagePerHit = 20,
  });

  final double playerSize;
  final double playerSpeed;
  final double projectileSpeed;
  final double enemySpeed;
  final double spawnInterval;
  final int maxHealth;
  final int damagePerHit;
}
