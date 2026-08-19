import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/models/fire_game_config.dart';

class FireGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  FireGame({
    required this.onHudUpdate,
    required this.onGameOver,
  });

  final void Function({
    required int score,
    required int health,
    required int wave,
    required int enemiesDefeated,
  }) onHudUpdate;

  final VoidCallback onGameOver;
  final FireGameConfig config = const FireGameConfig();
  final Random _random = Random();

  late PlayerComponent player;

  double _spawnTimer = 0;
  double _hudTimer = 0;
  int _score = 0;
  int _health = 100;
  int _wave = 1;
  int _enemiesDefeated = 0;
  bool _gameOver = false;

  @override
  Color backgroundColor() => const Color(0xFF080808);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _createPlayer();
  }

  void _createPlayer() {
    player = PlayerComponent(
      position: Vector2(size.x / 2, size.y - 100),
      game: this,
    );
    add(player);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    _spawnTimer += dt;
    final interval = max(0.35, config.spawnInterval - ((_wave - 1) * 0.08));

    if (_spawnTimer >= interval) {
      _spawnTimer = 0;
      _spawnEnemy();
    }

    _hudTimer += dt;
    if (_hudTimer >= 0.1) {
      _hudTimer = 0;
      _sendHudUpdate();
    }
  }

  void _sendHudUpdate() {
    onHudUpdate(
      score: _score,
      health: _health,
      wave: _wave,
      enemiesDefeated: _enemiesDefeated,
    );
  }

  void _spawnEnemy() {
    if (size.x <= 0) return;

    final x = 30 + _random.nextDouble() * max(1, size.x - 60);
    add(
      EnemyComponent(
        position: Vector2(x, -40),
        speed: config.enemySpeed + ((_wave - 1) * 12),
        game: this,
      ),
    );
  }

  void shoot() {
    if (_gameOver || !player.isMounted) return;

    add(
      FireProjectileComponent(
        position: player.position + Vector2(0, -30),
        game: this,
      ),
    );
  }

  void movePlayer(double deltaX) {
    if (_gameOver || !player.isMounted) return;

    player.position.x = (player.position.x + deltaX).clamp(
      config.playerSize / 2,
      max(config.playerSize / 2, size.x - config.playerSize / 2),
    );
  }

  void damagePlayer() {
    if (_gameOver) return;

    _health -= config.damagePerHit;

    if (_health <= 0) {
      _health = 0;
      _gameOver = true;
      pauseEngine();
      onGameOver();
      return;
    }

    _sendHudUpdate();
  }

  void enemyDefeated() {
    _score += 10;
    _enemiesDefeated++;
    _wave = 1 + (_enemiesDefeated ~/ 10);
    _sendHudUpdate();
  }

  void resetGame() {
    _gameOver = false;
    _score = 0;
    _health = config.maxHealth;
    _wave = 1;
    _enemiesDefeated = 0;
    _spawnTimer = 0;
    _hudTimer = 0;

    for (final enemy in children.whereType<EnemyComponent>().toList()) {
      enemy.removeFromParent();
    }
    for (final projectile
        in children.whereType<FireProjectileComponent>().toList()) {
      projectile.removeFromParent();
    }

    player.position = Vector2(size.x / 2, size.y - 100);
    resumeEngine();
    _sendHudUpdate();
  }

  void resumeGame() {
    if (!_gameOver) resumeEngine();
  }

  void pauseGame() => pauseEngine();

  @override
  void onTapDown(TapDownEvent event) => shoot();
}

class PlayerComponent extends PositionComponent {
  PlayerComponent({
    required super.position,
    required FireGame game,
  })  : _game = game,
        super(
          size: Vector2.all(game.config.playerSize),
          anchor: Anchor.center,
        );

  final FireGame _game;

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF2196F3);
    final path = Path()
      ..moveTo(size.x / 2, 0)
      ..lineTo(size.x, size.y)
      ..lineTo(size.x / 2, size.y * 0.75)
      ..lineTo(0, size.y)
      ..close();
    canvas.drawPath(path, paint);

    final firePaint = Paint()..color = const Color(0xFFFF5722);
    final firePath = Path()
      ..moveTo(size.x * 0.35, size.y)
      ..lineTo(size.x * 0.5, size.y * 0.65)
      ..lineTo(size.x * 0.65, size.y)
      ..close();
    canvas.drawPath(firePath, firePaint);
  }

  void move(double deltaX) => _game.movePlayer(deltaX);
}

class FireProjectileComponent extends CircleComponent {
  FireProjectileComponent({
    required super.position,
    required FireGame game,
  })  : _game = game,
        super(
          radius: 8,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFFF9800),
        );

  final FireGame _game;

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= _game.config.projectileSpeed * dt;

    if (position.y < -30) {
      removeFromParent();
      return;
    }

    for (final enemy in _game.children.whereType<EnemyComponent>().toList()) {
      if (!enemy.isMounted) continue;

      if (position.distanceTo(enemy.position) < radius + enemy.size.x / 2) {
        enemy.removeFromParent();
        removeFromParent();
        _game.enemyDefeated();
        break;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final glowPaint = Paint()
      ..color = const Color(0x66FF9800)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset(radius, radius), radius * 1.8, glowPaint);
    super.render(canvas);
  }
}

class EnemyComponent extends RectangleComponent {
  EnemyComponent({
    required super.position,
    required this.speed,
    required FireGame game,
  })  : _game = game,
        super(
          size: Vector2.all(42),
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFE53935),
        );

  final FireGame _game;
  final double speed;

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;

    if (position.y > _game.size.y + 50) {
      _game.damagePlayer();
      removeFromParent();
      return;
    }

    if (position.distanceTo(_game.player.position) <
        (size.x + _game.player.size.x) / 2) {
      _game.damagePlayer();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final flamePaint = Paint()..color = const Color(0xFFFF9800);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x * 0.25,
      flamePaint,
    );
  }
}
