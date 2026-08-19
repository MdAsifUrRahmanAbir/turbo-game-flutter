import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;

import '../../data/models/endless_runner_config.dart';

class EndlessRunnerGame extends FlameGame {
  EndlessRunnerGame({
    required this.onHudChanged,
    required this.onGameOver,
    this.config = const EndlessRunnerConfig(),
  });

  final EndlessRunnerConfig config;
  final void Function(int score, int coins, double distance) onHudChanged;
  final void Function(int score, int coins, double distance) onGameOver;

  final math.Random _random = math.Random();
  final List<_RunnerObstacle> _obstacles = [];
  final List<_RunnerCoin> _coins = [];
  final List<_RunnerParticle> _particles = [];

  late _RunnerPlayer _player;
  double _worldSpeed = 0;
  double _elapsed = 0;
  double _spawnTimer = 0;
  double _coinTimer = 0;
  double _distance = 0;
  double _roadOffset = 0;
  double _hudTimer = 0;
  int _score = 0;
  int _coinsCollected = 0;
  bool _running = false;
  bool _ended = false;

  final Paint _paint = Paint()..isAntiAlias = true;

  int get score => _score;
  int get coinsCollected => _coinsCollected;
  double get distance => _distance;

  @override
  Color backgroundColor() => const Color(0xFF10151D);

  @override
  Future<void> onLoad() async {
    _player = _RunnerPlayer();
    _running = true;
    _ended = false;
  }

  void reset() {
    _obstacles.clear();
    _coins.clear();
    _particles.clear();
    _elapsed = 0;
    _spawnTimer = 0.5;
    _coinTimer = 0.8;
    _distance = 0;
    _roadOffset = 0;
    _hudTimer = 0;
    _score = 0;
    _coinsCollected = 0;
    _worldSpeed = config.baseSpeed;
    _running = true;
    _ended = false;
    _player = _RunnerPlayer();
  }

  void pauseGame() {
    _running = false;
  }

  void resumeGame() {
    if (!_ended) _running = true;
  }

  void moveLeft() => _player.moveLane(-1);
  void moveRight() => _player.moveLane(1);
  void jump() => _player.jump();
  void duck() => _player.duck();

  @override
  void update(double dt) {
    super.update(dt);
    if (!_running || _ended || size.x <= 0 || size.y <= 0) return;

    _elapsed += dt;
    _worldSpeed = math.min(config.maxSpeed, config.baseSpeed + _elapsed * 11);
    _distance += _worldSpeed * dt / 100;
    _roadOffset = (_roadOffset + _worldSpeed * dt) % 90;

    _player.update(dt, size, _elapsed);

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnObstacle();
      final difficulty = math.min(1.0, _elapsed / 80);
      _spawnTimer = 0.65 + _random.nextDouble() * (0.65 - difficulty * 0.28);
    }

    _coinTimer -= dt;
    if (_coinTimer <= 0) {
      _spawnCoinLine();
      _coinTimer = 0.9 + _random.nextDouble() * 1.4;
    }

    for (final obstacle in _obstacles) {
      obstacle.y += _worldSpeed * dt;
    }
    for (final coin in _coins) {
      coin.y += _worldSpeed * dt;
      coin.rotation += dt * 5;
    }

    _obstacles.removeWhere((o) => o.y > size.y + 100);
    _coins.removeWhere((c) => c.y > size.y + 80 || c.collected);

    _particles.removeWhere((p) {
      p.life -= dt;
      p.position += p.velocity * dt;
      return p.life <= 0;
    });

    _checkCollisions();
    _score = (_distance * 3).floor() + _coinsCollected * 25;

    // Do not push HUD state on every Flame frame. Apart from being wasteful,
    // a direct Riverpod update from Flame's update() can happen while Flutter
    // is building/layouting and triggers Riverpod's
    // "Cannot modify providers while building" assertion.
    _hudTimer += dt;
    if (_hudTimer >= 0.1) {
      _hudTimer = 0;
      onHudChanged(_score, _coinsCollected, _distance);
    }
  }

  void _spawnObstacle() {
    final lane = _random.nextInt(config.laneCount);
    final type = _random.nextInt(3);
    _obstacles.add(
      _RunnerObstacle(
        lane: lane,
        y: -100,
        type: type,
      ),
    );
  }

  void _spawnCoinLine() {
    final lane = _random.nextInt(config.laneCount);
    final count = 2 + _random.nextInt(4);
    for (var i = 0; i < count; i++) {
      _coins.add(_RunnerCoin(lane: lane, y: -80.0 - i * 62));
    }
  }

  void _checkCollisions() {
    final playerRect = _player.hitRect(size);

    for (final obstacle in List<_RunnerObstacle>.from(_obstacles)) {
      if (playerRect.overlaps(obstacle.rect(size))) {
        _endGame();
        return;
      }
    }

    for (final coin in _coins) {
      if (!coin.collected && playerRect.overlaps(coin.rect(size))) {
        coin.collected = true;
        _coinsCollected++;
        _emitCoinParticles(coin.center(size));
      }
    }
  }

  void _emitCoinParticles(Offset center) {
    for (var i = 0; i < 8; i++) {
      final angle = i / 8 * math.pi * 2;
      _particles.add(
        _RunnerParticle(
          position: center,
          velocity: Offset(math.cos(angle) * 45, math.sin(angle) * 45),
          life: 0.35,
        ),
      );
    }
  }

  void _endGame() {
    if (_ended) return;
    _ended = true;
    _running = false;
    onGameOver(_score, _coinsCollected, _distance);
  }

  double laneX(int lane, double width) {
    final roadWidth = size.x * 0.72;
    final left = (size.x - roadWidth) / 2;
    final laneWidth = roadWidth / config.laneCount;
    return left + laneWidth * (lane + 0.5) - width / 2;
  }

  Rect roadRect() {
    final roadWidth = size.x * 0.72;
    return Rect.fromLTWH((size.x - roadWidth) / 2, 0, roadWidth, size.y);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBackground(canvas);
    _drawRoad(canvas);
    _drawCoins(canvas);
    _drawObstacles(canvas);
    _player.render(canvas, size);
    _drawParticles(canvas);
  }

  void _drawBackground(Canvas canvas) {
    _paint.color = const Color(0xFF9BD6FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);

    _paint.color = const Color(0xFF76B85C);
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.38, size.x, size.y * 0.62), _paint);

    for (var x = -20.0; x < size.x + 80; x += 70) {
      final treeY = size.y * 0.28 + math.sin(x) * 15;
      _paint.color = const Color(0xFF5C9C4B);
      canvas.drawCircle(Offset(x, treeY), 24, _paint);
      _paint.color = const Color(0xFF6D4C41);
      canvas.drawRect(Rect.fromLTWH(x - 5, treeY, 10, 40), _paint);
    }
  }

  void _drawRoad(Canvas canvas) {
    final road = roadRect();
    _paint.color = const Color(0xFF30343B);
    canvas.drawRect(road, _paint);

    _paint.color = const Color(0xFFFFD54F);
    canvas.drawRect(Rect.fromLTWH(road.left, 0, 7, size.y), _paint);
    canvas.drawRect(Rect.fromLTWH(road.right - 7, 0, 7, size.y), _paint);

    final laneWidth = road.width / config.laneCount;
    _paint.color = const Color(0xFFEBEFF3);
    for (var lane = 1; lane < config.laneCount; lane++) {
      final x = road.left + lane * laneWidth;
      for (var y = -90.0 + _roadOffset; y < size.y; y += 90) {
        canvas.drawRect(Rect.fromLTWH(x - 3, y, 6, 48), _paint);
      }
    }
  }

  void _drawCoins(Canvas canvas) {
    for (final coin in _coins) {
      if (coin.collected) continue;
      final center = coin.center(size);
      _paint.color = const Color(0xFFFFC107);
      canvas.drawCircle(center, 14, _paint);
      _paint.color = const Color(0xFFFFF3A5);
      canvas.drawCircle(center, 9, _paint);
      _paint.color = const Color(0xFFFFC107);
      canvas.drawRect(Rect.fromCenter(center: center, width: 3, height: 12), _paint);
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (final obstacle in _obstacles) {
      final rect = obstacle.rect(size);
      if (obstacle.type == 0) {
        _paint.color = const Color(0xFFE53935);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), _paint);
        _paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(rect.left + 8, rect.top + 12, rect.width - 16, 9), _paint);
      } else if (obstacle.type == 1) {
        _paint.color = const Color(0xFF5D4037);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), _paint);
        _paint.color = const Color(0xFF795548);
        canvas.drawCircle(Offset(rect.center.dx - 8, rect.center.dy - 5), 8, _paint);
        canvas.drawCircle(Offset(rect.center.dx + 8, rect.center.dy + 5), 8, _paint);
      } else {
        _paint.color = const Color(0xFF263238);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), _paint);
        _paint.color = const Color(0xFFFF7043);
        canvas.drawCircle(Offset(rect.center.dx, rect.top + 12), 6, _paint);
      }
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final particle in _particles) {
      _paint.color = const Color(0xFFFFD54F).withValues(alpha: particle.life / 0.35);
      canvas.drawCircle(particle.position, 3, _paint);
    }
  }
}

class _RunnerPlayer {
  int lane = 1;
  double laneProgress = 1;
  double jumpHeight = 0;
  double jumpVelocity = 0;
  double duckTime = 0;
  double runTime = 0;

  void moveLane(int direction) {
    lane = (lane + direction).clamp(0, 2).toInt();
  }

  void jump() {
    if (jumpHeight <= 0.1) jumpVelocity = 760;
  }

  void duck() {
    if (jumpHeight <= 0.1) duckTime = 0.45;
  }

  void update(double dt, Vector2 size, double elapsed) {
    runTime += dt;
    if (jumpVelocity != 0 || jumpHeight > 0) {
      jumpHeight += jumpVelocity * dt;
      jumpVelocity -= 1800 * dt;
      if (jumpHeight <= 0) {
        jumpHeight = 0;
        jumpVelocity = 0;
      }
    }
    duckTime = math.max(0, duckTime - dt);
  }

  Rect hitRect(Vector2 size) {
    final width = 52.0;
    final height = duckTime > 0 ? 46.0 : 78.0;
    final roadWidth = size.x * 0.72;
    final left = (size.x - roadWidth) / 2;
    final laneWidth = roadWidth / 3;
    final x = left + laneWidth * (lane + 0.5) - width / 2;
    final bottom = size.y - 48 - jumpHeight;
    return Rect.fromLTWH(x + 7, bottom - height + 8, width - 14, height - 14);
  }

  void render(Canvas canvas, Vector2 size) {
    final width = 52.0;
    final height = duckTime > 0 ? 46.0 : 78.0;
    final roadWidth = size.x * 0.72;
    final left = (size.x - roadWidth) / 2;
    final laneWidth = roadWidth / 3;
    final x = left + laneWidth * (lane + 0.5) - width / 2;
    final bottom = size.y - 48 - jumpHeight;
    final rect = Rect.fromLTWH(x, bottom - height, width, height);

    final paint = Paint()..isAntiAlias = true;
    paint.color = const Color(0xFF1E88E5);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), paint);

    paint.color = const Color(0xFF90CAF9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 10, rect.top + 9, rect.width - 20, 22),
        const Radius.circular(7),
      ),
      paint,
    );

    paint.color = const Color(0xFF263238);
    canvas.drawCircle(Offset(rect.left + 9, rect.bottom - 8), 7, paint);
    canvas.drawCircle(Offset(rect.right - 9, rect.bottom - 8), 7, paint);

    paint.color = Colors.white;
    final step = (runTime * 12).floor() % 2;
    canvas.drawRect(Rect.fromLTWH(rect.left + 7 + step * 5, rect.bottom - 30, 10, 5), paint);
    canvas.drawRect(Rect.fromLTWH(rect.right - 17 - step * 5, rect.bottom - 30, 10, 5), paint);
  }
}

class _RunnerObstacle {
  _RunnerObstacle({required this.lane, required this.y, required this.type});

  final int lane;
  double y;
  final int type;

  Rect rect(Vector2 size) {
    final width = 58.0;
    final height = type == 2 ? 52.0 : 62.0;
    final roadWidth = size.x * 0.72;
    final left = (size.x - roadWidth) / 2;
    final laneWidth = roadWidth / 3;
    final x = left + laneWidth * (lane + 0.5) - width / 2;
    return Rect.fromLTWH(x, y, width, height);
  }
}

class _RunnerCoin {
  _RunnerCoin({required this.lane, required this.y});

  final int lane;
  double y;
  double rotation = 0;
  bool collected = false;

  Offset center(Vector2 size) {
    final roadWidth = size.x * 0.72;
    final left = (size.x - roadWidth) / 2;
    final laneWidth = roadWidth / 3;
    return Offset(left + laneWidth * (lane + 0.5), y + 16);
  }

  Rect rect(Vector2 size) => Rect.fromCircle(center: center(size), radius: 18);
}

class _RunnerParticle {
  _RunnerParticle({required this.position, required this.velocity, required this.life});

  Offset position;
  final Offset velocity;
  double life;
}

