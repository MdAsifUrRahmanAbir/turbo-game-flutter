import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'endless_runner_config.dart';

enum _ObstacleKind { wall, low, high }

/// A hand-painted, cartoon-styled 3-lane endless runner. Everything is
/// drawn with [Canvas] primitives (no image assets required) so the whole
/// look can be re-themed from [EndlessRunnerConfig].
///
/// Supports both on-screen touch controls and a physical keyboard (for web):
/// A/D to switch lanes, W or Enter or Space to jump, and S to duck.
class EndlessRunnerGame extends FlameGame with KeyboardEvents {
  EndlessRunnerGame({required this.onHudChanged, required this.onGameOver});

  /// Fired several times a second while playing so the HUD can stay in
  /// sync without hammering Riverpod every single frame.
  final void Function(int score, int coins, double distance, double shieldCharge)
      onHudChanged;

  /// Fired once, with the final stats, when a run ends.
  final void Function(int score, int coins, double distance) onGameOver;

  final math.Random _random = math.Random();
  final List<_Obstacle> _obstacles = <_Obstacle>[];
  final List<_Coin> _coinPickups = <_Coin>[];
  final List<_ShieldToken> _shieldTokens = <_ShieldToken>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_Cloud> _clouds = <_Cloud>[];
  final List<_SceneryProp> _scenery = <_SceneryProp>[];

  static const List<double> _laneCenters = [0.26, 0.5, 0.74];
  final double _playerY = 0.82;

  int _lane = 1;
  double _laneX = 0.5;
  double _jumpTimer = 0;
  double _duckTimer = 0;
  double _shieldTimer = 0;
  double _runCycle = 0;

  double _speed = EndlessRunnerConfig.baseSpeed;
  double _distance = 0;
  double _spawnTimer = 0;
  double _coinSpawnTimer = 0;
  double _sceneryTimer = 0;
  double _pathOffset = 0;
  double _hudTimer = 0;

  int _score = 0;
  int _coinsCollected = 0;

  bool _running = true;
  bool _paused = false;
  bool _gameOverFired = false;
  double _shakeTime = 0;

  int get score => _score;
  int get coins => _coinsCollected;
  double get distance => _distance;
  bool get isRunning => _running && !_gameOverFired && !_paused;
  bool get isPausedByUser => _paused && !_gameOverFired;
  bool get shieldActive => _shieldTimer > 0;
  double get shieldCharge =>
      (_shieldTimer / EndlessRunnerConfig.shieldDuration).clamp(0.0, 1.0);

  @override
  Color backgroundColor() => EndlessRunnerConfig.skyTop;

  @override
  Future<void> onLoad() async {
    _seedClouds();
  }

  void _seedClouds() {
    _clouds.clear();
    for (var i = 0; i < 5; i++) {
      _clouds.add(
        _Cloud(
          x: _random.nextDouble(),
          y: 0.05 + _random.nextDouble() * 0.24,
          scale: 0.6 + _random.nextDouble() * 0.8,
          speed: 0.01 + _random.nextDouble() * 0.02,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------

  void moveLeft() {
    if (!isRunning) return;
    _lane = (_lane - 1).clamp(0, EndlessRunnerConfig.laneCount - 1).toInt();
  }

  void moveRight() {
    if (!isRunning) return;
    _lane = (_lane + 1).clamp(0, EndlessRunnerConfig.laneCount - 1).toInt();
  }

  void jump() {
    if (!isRunning) return;
    if (_jumpTimer > 0 || _duckTimer > 0) return;
    _jumpTimer = 0.0001;
  }

  void duck() {
    if (!isRunning) return;
    if (_jumpTimer > 0) return;
    _duckTimer = EndlessRunnerConfig.duckDuration;
  }

  // ---------------------------------------------------------------------
  // Keyboard (web/desktop)
  // ---------------------------------------------------------------------

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Lane switches, jumps and ducks are one-shot actions, so they only
    // fire on the initial key-down — not on the auto-repeat events sent
    // while a key is held.
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyA:
          moveLeft();
          break;
        case LogicalKeyboardKey.keyD:
          moveRight();
          break;
        case LogicalKeyboardKey.keyW:
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.space:
          jump();
          break;
        case LogicalKeyboardKey.keyS:
          duck();
          break;
      }
    }

    return KeyEventResult.handled;
  }

  void togglePause() {
    if (_gameOverFired) return;
    _paused = !_paused;
  }

  void pauseGame() {
    if (_gameOverFired) return;
    _paused = true;
  }

  void resumeGame() {
    if (_gameOverFired) return;
    _paused = false;
  }

  void reset() {
    _obstacles.clear();
    _coinPickups.clear();
    _shieldTokens.clear();
    _particles.clear();
    _scenery.clear();

    _lane = 1;
    _laneX = _laneCenters[1];
    _jumpTimer = 0;
    _duckTimer = 0;
    _shieldTimer = 0;
    _runCycle = 0;

    _speed = EndlessRunnerConfig.baseSpeed;
    _distance = 0;
    _spawnTimer = 0;
    _coinSpawnTimer = 0;
    _sceneryTimer = 0;
    _pathOffset = 0;
    _hudTimer = 0;

    _score = 0;
    _coinsCollected = 0;

    _running = true;
    _paused = false;
    _gameOverFired = false;
    _shakeTime = 0;
  }

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateClouds(dt);
    _updateParticles(dt);

    if (!_running || _paused) return;

    _runCycle += dt * (4 + _speed * 6);

    final targetX = _laneCenters[_lane];
    _laneX += (targetX - _laneX) * math.min(1, dt * EndlessRunnerConfig.laneSlideSpeed);

    if (_jumpTimer > 0) {
      _jumpTimer += dt;
      if (_jumpTimer >= EndlessRunnerConfig.jumpDuration) _jumpTimer = 0;
    }
    if (_duckTimer > 0) {
      _duckTimer = math.max(0, _duckTimer - dt);
    }
    if (_shieldTimer > 0) {
      _shieldTimer = math.max(0, _shieldTimer - dt);
    }
    if (_shakeTime > 0) {
      _shakeTime = math.max(0, _shakeTime - dt);
    }

    final rampT = (_distance / EndlessRunnerConfig.distanceForFullRamp).clamp(0.0, 1.0);
    final targetSpeed = EndlessRunnerConfig.baseSpeed + rampT * EndlessRunnerConfig.speedRampCap;
    _speed += (targetSpeed - _speed) * dt * 2.0;

    _distance += _speed * dt * 100;
    _pathOffset = (_pathOffset + _speed * dt * 0.9) % 1;

    if (_random.nextDouble() < 0.9 && _speed > 0) {
      // Dust puffs behind the runner's feet while grounded.
      if (_jumpTimer == 0 && _random.nextDouble() < 0.12) {
        _spawnDust();
      }
    }

    _updateSpawns(dt);
    _updateObstacles(dt);
    _updateCoins(dt);
    _updateShieldTokens(dt);

    _score = (_distance * 10).round() + _coinsCollected * EndlessRunnerConfig.coinScoreValue;
    _hudTimer += dt;
    if (_hudTimer >= 0.08) {
      _hudTimer = 0;
      onHudChanged(_score, _coinsCollected, _distance, shieldCharge);
    }
  }

  void _updateClouds(double dt) {
    for (final cloud in _clouds) {
      cloud.x -= cloud.speed * dt;
      if (cloud.x < -0.2) {
        cloud.x = 1.2;
        cloud.y = 0.05 + _random.nextDouble() * 0.24;
      }
    }
  }

  void _updateParticles(double dt) {
    for (final particle in _particles) {
      particle.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _updateSpawns(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnTimer = math.max(0.62, 1.15 - _distance / 3600);
      _spawnObstacle();
    }

    _coinSpawnTimer -= dt;
    if (_coinSpawnTimer <= 0) {
      _coinSpawnTimer = 0.9 + _random.nextDouble() * 0.6;
      if (_random.nextDouble() < EndlessRunnerConfig.coinRowChance) {
        _spawnCoinRow();
      } else if (_random.nextDouble() < EndlessRunnerConfig.shieldTokenChance) {
        _spawnShieldToken();
      }
    }

    _sceneryTimer -= dt;
    if (_sceneryTimer <= 0) {
      _sceneryTimer = 0.4;
      _scenery.add(_SceneryProp(leftSide: _random.nextBool(), y: -0.08));
    }
    for (final prop in _scenery) {
      prop.y += _speed * dt * 0.75;
    }
    _scenery.removeWhere((p) => p.y > 1.15);
  }

  void _spawnObstacle() {
    final lane = _random.nextInt(EndlessRunnerConfig.laneCount);
    final kind = _ObstacleKind.values[_random.nextInt(_ObstacleKind.values.length)];
    _obstacles.add(
      _Obstacle(
        lane: lane,
        y: -0.14,
        kind: kind,
        color: EndlessRunnerConfig
            .obstaclePalette[_random.nextInt(EndlessRunnerConfig.obstaclePalette.length)],
      ),
    );
  }

  void _spawnCoinRow() {
    final lane = _random.nextInt(EndlessRunnerConfig.laneCount);
    final count = 2 + _random.nextInt(3);
    for (var i = 0; i < count; i++) {
      _coinPickups.add(_Coin(lane: lane, y: -0.10 - i * 0.09));
    }
  }

  void _spawnShieldToken() {
    if (shieldActive) return;
    final lane = _random.nextInt(EndlessRunnerConfig.laneCount);
    _shieldTokens.add(_ShieldToken(lane: lane, y: -0.12));
  }

  void _updateObstacles(double dt) {
    for (final obstacle in _obstacles) {
      obstacle.y += _speed * dt * 0.75;
    }
    _obstacles.removeWhere((o) => o.y > 1.2);

    for (final obstacle in _obstacles) {
      if (obstacle.resolved) continue;
      if (obstacle.lane != _lane) continue;
      if (!_withinHitZone(obstacle.y)) continue;

      final cleared = switch (obstacle.kind) {
        _ObstacleKind.wall => false,
        _ObstacleKind.low => _jumpTimer > 0,
        _ObstacleKind.high => _duckTimer > 0,
      };

      obstacle.resolved = true;

      if (cleared) continue;

      if (shieldActive) {
        _shieldTimer = 0;
        _spawnBurst(_laneX, _playerY, EndlessRunnerConfig.shieldColor, count: 18);
        continue;
      }

      _crash();
      return;
    }
  }

  bool _withinHitZone(double y) {
    final dy = y - _playerY;
    return dy.abs() < 0.055;
  }

  void _updateCoins(double dt) {
    for (final coin in _coinPickups) {
      coin.y += _speed * dt * 0.75;
      coin.spin += dt * 6;
    }
    _coinPickups.removeWhere((coin) => coin.y > 1.15);

    _coinPickups.removeWhere((coin) {
      if (coin.lane == _lane && _withinHitZone(coin.y)) {
        _coinsCollected++;
        _spawnCoinSparkle(_laneCenters[coin.lane], coin.y);
        return true;
      }
      return false;
    });
  }

  void _updateShieldTokens(double dt) {
    for (final token in _shieldTokens) {
      token.y += _speed * dt * 0.75;
      token.pulse += dt * 4;
    }
    _shieldTokens.removeWhere((token) => token.y > 1.15);

    _shieldTokens.removeWhere((token) {
      if (token.lane == _lane && _withinHitZone(token.y)) {
        _shieldTimer = EndlessRunnerConfig.shieldDuration;
        _spawnBurst(_laneCenters[token.lane], token.y, EndlessRunnerConfig.shieldColor, count: 14);
        return true;
      }
      return false;
    });
  }

  void _crash() {
    if (_gameOverFired) return;
    _gameOverFired = true;
    _running = false;
    _spawnBurst(_laneX, _playerY, EndlessRunnerConfig.playerBody, count: 26);
    _spawnBurst(_laneX, _playerY, EndlessRunnerConfig.gold, count: 14);
    _shakeTime = EndlessRunnerConfig.crashShakeDuration;
    onGameOver(_score, _coinsCollected, _distance);
  }

  void _spawnDust() {
    _particles.add(
      _Particle(
        x: _laneX + (_random.nextDouble() - 0.5) * 0.03,
        y: _playerY + 0.05,
        vx: -_speed * 0.6 + (_random.nextDouble() - 0.5) * 0.05,
        vy: -0.1 - _random.nextDouble() * 0.1,
        color: Colors.white.withValues(alpha: 0.5),
        life: 0.3,
        maxLife: 0.3,
        size: 3 + _random.nextDouble() * 2,
      ),
    );
  }

  void _spawnCoinSparkle(double x, double y) {
    for (var i = 0; i < 8; i++) {
      _particles.add(
        _Particle.burst(
          x: x,
          y: y,
          color: EndlessRunnerConfig.coinShine,
          random: _random,
          speed: 0.5,
          life: 0.4,
          size: 3,
        ),
      );
    }
  }

  void _spawnBurst(double x, double y, Color color, {required int count}) {
    for (var i = 0; i < count; i++) {
      _particles.add(
        _Particle.burst(
          x: x,
          y: y,
          color: color,
          random: _random,
          speed: 1.1,
          life: 0.6,
          size: 5,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    canvas.save();
    if (_shakeTime > 0) {
      final power = _shakeTime / EndlessRunnerConfig.crashShakeDuration;
      final dx = (_random.nextDouble() - 0.5) * EndlessRunnerConfig.crashShakeMagnitude * power;
      final dy = (_random.nextDouble() - 0.5) * EndlessRunnerConfig.crashShakeMagnitude * power;
      canvas.translate(dx, dy);
    }

    _renderSky(canvas, w, h);
    _renderScenery(canvas, w, h);
    _renderPath(canvas, w, h);
    _renderSceneryProps(canvas, w, h);
    _renderCoins(canvas, w, h);
    _renderShieldTokens(canvas, w, h);
    for (final obstacle in _obstacles) {
      _drawObstacle(canvas, w, h, obstacle);
    }
    _renderParticles(canvas, w, h);
    if (!_gameOverFired) {
      _drawPlayer(canvas, w, h);
    }
    if (shieldActive) _renderShieldVignette(canvas, w, h);

    canvas.restore();
  }

  double _perspectiveX(double laneFraction, double y) {
    final pull = (0.5 - laneFraction) * (1 - y) * 0.35;
    return laneFraction + pull;
  }

  void _renderSky(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          EndlessRunnerConfig.skyTop,
          EndlessRunnerConfig.skyMid,
          EndlessRunnerConfig.skyBottom,
        ],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, gradient);

    canvas.drawCircle(
      Offset(w * 0.20, h * 0.14),
      w * 0.10,
      Paint()..color = EndlessRunnerConfig.sun.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      Offset(w * 0.20, h * 0.14),
      w * 0.15,
      Paint()..color = EndlessRunnerConfig.sun.withValues(alpha: 0.25),
    );

    for (final cloud in _clouds) {
      _drawCloud(canvas, w * cloud.x, h * cloud.y, w * 0.09 * cloud.scale);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double r) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(x, y), r * 0.6, paint);
    canvas.drawCircle(Offset(x - r * 0.6, y + r * 0.1), r * 0.45, paint);
    canvas.drawCircle(Offset(x + r * 0.65, y + r * 0.08), r * 0.5, paint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y + r * 0.15), width: r * 2.1, height: r * 0.8),
      paint,
    );
  }

  void _renderScenery(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.32, w, h * 0.68),
      Paint()..color = EndlessRunnerConfig.grassA,
    );
    for (var i = 0; i < 10; i++) {
      final t = ((i / 10) + _pathOffset * 0.6) % 1;
      final y = h * 0.32 + t * h * 0.68;
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, h * 0.02),
        Paint()..color = EndlessRunnerConfig.grassB.withValues(alpha: 0.5),
      );
    }
  }

  void _renderSceneryProps(Canvas canvas, double w, double h) {
    for (final prop in _scenery) {
      final t = prop.y.clamp(0.0, 1.2);
      final perspective = 0.35 + t * 0.9;
      final pathHalf = _pathHalfWidthAt(t) * w;
      final centerX = w * _perspectiveX(0.5, t);
      final baseX = prop.leftSide ? centerX - pathHalf : centerX + pathHalf;
      final sideOffset = prop.leftSide ? -perspective * w * 0.09 : perspective * w * 0.09;
      final x = baseX + sideOffset;
      final y = h * t;
      _drawLollipopTree(canvas, x, y, perspective);
    }
  }

  void _drawLollipopTree(Canvas canvas, double x, double y, double scale) {
    final stickH = 26 * scale;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y), width: 3.4 * scale, height: stickH),
      Paint()..color = EndlessRunnerConfig.treeTrunk,
    );
    final swirl = Paint()..color = EndlessRunnerConfig.coral;
    canvas.drawCircle(Offset(x, y - stickH * 0.72), 14 * scale, swirl);
    canvas.drawCircle(
      Offset(x, y - stickH * 0.72),
      9 * scale,
      Paint()..color = EndlessRunnerConfig.cream,
    );
    canvas.drawCircle(
      Offset(x, y - stickH * 0.72),
      4.5 * scale,
      Paint()..color = EndlessRunnerConfig.coral,
    );
  }

  double _pathHalfWidthAt(double t) => 0.34 + t * 0.08;

  void _renderPath(Canvas canvas, double w, double h) {
    final topHalf = 0.30;
    final bottomHalf = 0.42;

    final path = Path()
      ..moveTo(w * (0.5 - topHalf), 0)
      ..lineTo(w * (0.5 + topHalf), 0)
      ..lineTo(w * (0.5 + bottomHalf), h)
      ..lineTo(w * (0.5 - bottomHalf), h)
      ..close();
    canvas.drawPath(path, Paint()..color = EndlessRunnerConfig.pathLight);

    final edgePaint = Paint()
      ..color = EndlessRunnerConfig.pathEdge
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * (0.5 - topHalf), 0),
      Offset(w * (0.5 - bottomHalf), h),
      edgePaint,
    );
    canvas.drawLine(
      Offset(w * (0.5 + topHalf), 0),
      Offset(w * (0.5 + bottomHalf), h),
      edgePaint,
    );

    // Lane divider stripes (2 dividers for 3 lanes).
    for (final laneFrac in [0.333, 0.667]) {
      for (var i = 0; i < 10; i++) {
        final t = (i / 10 + _pathOffset) % 1;
        final half = _pathHalfWidthAt(t);
        final x = w * (0.5 + (laneFrac - 0.5) * half * 2.4);
        final y = t * h;
        final dashH = 14 + t * 26;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 4 + t * 3, height: dashH),
            const Radius.circular(4),
          ),
          Paint()..color = EndlessRunnerConfig.laneStripe.withValues(alpha: 0.85),
        );
      }
    }

    for (var i = 0; i < 8; i++) {
      final t = (i / 8 + _pathOffset * 1.4) % 1;
      final y = t * h;
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, h * 0.01),
        Paint()..color = EndlessRunnerConfig.pathDark.withValues(alpha: 0.25),
      );
    }
  }

  void _renderCoins(Canvas canvas, double w, double h) {
    for (final coin in _coinPickups) {
      final scale = 0.4 + coin.y * 0.7;
      final x = w * _perspectiveX(_laneCenters[coin.lane], coin.y);
      final y = h * coin.y;
      final squash = (math.cos(coin.spin)).abs();
      final rx = 9 * scale * (0.4 + squash * 0.6);
      final ry = 9 * scale;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + ry * 0.9), width: rx * 2, height: ry * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        Paint()..color = EndlessRunnerConfig.coinColor,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2 * 0.55, height: ry * 2 * 0.55),
        Paint()..color = EndlessRunnerConfig.coinShine,
      );
    }
  }

  void _renderShieldTokens(Canvas canvas, double w, double h) {
    for (final token in _shieldTokens) {
      final scale = 0.45 + token.y * 0.7;
      final x = w * _perspectiveX(_laneCenters[token.lane], token.y);
      final y = h * token.y;
      final glow = 0.5 + math.sin(token.pulse).abs() * 0.5;

      canvas.drawCircle(
        Offset(x, y),
        16 * scale * (0.8 + glow * 0.4),
        Paint()..color = EndlessRunnerConfig.shieldGlow.withValues(alpha: 0.35 * glow),
      );
      canvas.drawCircle(Offset(x, y), 11 * scale, Paint()..color = EndlessRunnerConfig.shieldColor);
      canvas.drawCircle(
        Offset(x, y),
        6 * scale,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  void _drawObstacle(Canvas canvas, double w, double h, _Obstacle obstacle) {
    final scale = 0.5 + obstacle.y * 0.6;
    final x = w * _perspectiveX(_laneCenters[obstacle.lane], obstacle.y);
    final y = h * obstacle.y;
    final laneW = w * _pathHalfWidthAt(obstacle.y) * 0.62 * scale;

    switch (obstacle.kind) {
      case _ObstacleKind.wall:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: laneW, height: 46 * scale),
          Radius.circular(10 * scale),
        );
        canvas.drawRRect(rect, Paint()..color = obstacle.color);
        canvas.drawRRect(
          rect,
          Paint()
            ..color = EndlessRunnerConfig.navyDeep
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * scale,
        );
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(x + i * laneW * 0.28, y - 20 * scale),
            Offset(x + i * laneW * 0.28, y + 20 * scale),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.4)
              ..strokeWidth = 3 * scale,
          );
        }
        break;
      case _ObstacleKind.low:
        final fenceH = 20 * scale;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y + 6 * scale), width: laneW, height: fenceH),
          Radius.circular(6 * scale),
        );
        canvas.drawRRect(rect, Paint()..color = obstacle.color);
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(x + i * laneW * 0.3, y - fenceH * 0.1),
            Offset(x + i * laneW * 0.3, y + fenceH * 0.9),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.55)
              ..strokeWidth = 2.6 * scale,
          );
        }
        break;
      case _ObstacleKind.high:
        final barY = y - 28 * scale;
        canvas.drawLine(
          Offset(x - laneW / 2, y + 22 * scale),
          Offset(x - laneW / 2, barY),
          Paint()
            ..color = EndlessRunnerConfig.navyDeep
            ..strokeWidth = 3.2 * scale,
        );
        canvas.drawLine(
          Offset(x + laneW / 2, y + 22 * scale),
          Offset(x + laneW / 2, barY),
          Paint()
            ..color = EndlessRunnerConfig.navyDeep
            ..strokeWidth = 3.2 * scale,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, barY), width: laneW, height: 12 * scale),
            Radius.circular(6 * scale),
          ),
          Paint()..color = obstacle.color,
        );
        break;
    }
  }

  void _renderParticles(Canvas canvas, double w, double h) {
    for (final particle in _particles) {
      final alpha = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(w * particle.x, h * particle.y),
        particle.size * alpha,
        Paint()..color = particle.color.withValues(alpha: alpha),
      );
    }
  }

  void _renderShieldVignette(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          EndlessRunnerConfig.shieldColor.withValues(alpha: 0.16),
        ],
        stops: const [0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawPlayer(Canvas canvas, double w, double h) {
    final x = w * _laneX;
    final groundY = h * _playerY;

    final jumpT = _jumpTimer > 0 ? (_jumpTimer / EndlessRunnerConfig.jumpDuration).clamp(0.0, 1.0) : 0.0;
    final jumpOffset = math.sin(math.pi * jumpT) * EndlessRunnerConfig.jumpHeight * h;
    final isDucking = _duckTimer > 0;
    final y = groundY - jumpOffset;

    final bodyW = EndlessRunnerConfig.playerWidth * (h / 700).clamp(0.7, 1.4);
    final bodyH = (isDucking ? EndlessRunnerConfig.playerHeight * 0.62 : EndlessRunnerConfig.playerHeight) *
        (h / 700).clamp(0.7, 1.4);

    // Shadow shrinks while airborne.
    final shadowScale = 1 - jumpT * 0.35;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY + bodyH * 0.42), width: bodyW * 1.1 * shadowScale, height: bodyW * 0.32 * shadowScale),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    if (shieldActive) {
      final pulse = 0.6 + math.sin(_runCycle * 2) * 0.4;
      canvas.drawCircle(
        Offset(x, y - bodyH * 0.1),
        bodyW * 0.85 + pulse * 4,
        Paint()..color = EndlessRunnerConfig.shieldGlow.withValues(alpha: 0.35),
      );
    }

    // Legs (simple running cycle) — hidden while airborne for a tucked pose.
    final legSwing = _jumpTimer > 0 ? 0.0 : math.sin(_runCycle) * bodyH * 0.16;
    final legPaint = Paint()..color = EndlessRunnerConfig.playerBodyDark;
    if (!isDucking) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x - bodyW * 0.18, y + bodyH * 0.42 + legSwing), width: bodyW * 0.22, height: bodyH * 0.3),
          Radius.circular(bodyW * 0.1),
        ),
        legPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + bodyW * 0.18, y + bodyH * 0.42 - legSwing), width: bodyW * 0.22, height: bodyH * 0.3),
          Radius.circular(bodyW * 0.1),
        ),
        legPaint,
      );
    }

    // Body (rounded cartoon bean).
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: bodyW, height: bodyH),
      Radius.circular(bodyW * 0.5),
    );
    canvas.drawRRect(bodyRect, Paint()..color = EndlessRunnerConfig.playerBody);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = EndlessRunnerConfig.navyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, bodyW * 0.045),
    );

    // Belly shine.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y - bodyH * 0.05), width: bodyW * 0.5, height: bodyH * 0.4),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // Cheeks.
    canvas.drawCircle(Offset(x - bodyW * 0.28, y - bodyH * 0.02), bodyW * 0.09, Paint()..color = EndlessRunnerConfig.playerCheeks);
    canvas.drawCircle(Offset(x + bodyW * 0.28, y - bodyH * 0.02), bodyW * 0.09, Paint()..color = EndlessRunnerConfig.playerCheeks);

    // Eyes.
    final eyeY = y - bodyH * 0.18;
    canvas.drawCircle(Offset(x - bodyW * 0.16, eyeY), bodyW * 0.11, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x + bodyW * 0.16, eyeY), bodyW * 0.11, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x - bodyW * 0.14, eyeY + bodyH * 0.01), bodyW * 0.055, Paint()..color = EndlessRunnerConfig.navyDeep);
    canvas.drawCircle(Offset(x + bodyW * 0.18, eyeY + bodyH * 0.01), bodyW * 0.055, Paint()..color = EndlessRunnerConfig.navyDeep);

    // Little scarf / accent stripe for the "hero" touch.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y + bodyH * 0.05), width: bodyW * 0.9, height: bodyH * 0.14),
        Radius.circular(bodyW * 0.1),
      ),
      Paint()..color = EndlessRunnerConfig.playerAccent,
    );

    // Arms.
    final armSwing = _jumpTimer > 0 ? -bodyH * 0.1 : math.sin(_runCycle + math.pi) * bodyH * 0.1;
    final armPaint = Paint()..color = EndlessRunnerConfig.playerBody;
    canvas.drawCircle(Offset(x - bodyW * 0.52, y + armSwing), bodyW * 0.13, armPaint);
    canvas.drawCircle(Offset(x + bodyW * 0.52, y - armSwing), bodyW * 0.13, armPaint);
  }

}

class _Obstacle {
  _Obstacle({required this.lane, required this.y, required this.kind, required this.color});
  final int lane;
  double y;
  final _ObstacleKind kind;
  final Color color;
  bool resolved = false;
}

class _Coin {
  _Coin({required this.lane, required this.y});
  final int lane;
  double y;
  double spin = 0;
}

class _ShieldToken {
  _ShieldToken({required this.lane, required this.y});
  final int lane;
  double y;
  double pulse = 0;
}

class _Cloud {
  _Cloud({required this.x, required this.y, required this.scale, required this.speed});
  double x;
  double y;
  final double scale;
  final double speed;
}

class _SceneryProp {
  _SceneryProp({required this.leftSide, required this.y});
  final bool leftSide;
  double y;
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
    required this.maxLife,
    required this.size,
  });

  factory _Particle.burst({
    required double x,
    required double y,
    required Color color,
    required math.Random random,
    required double speed,
    required double life,
    required double size,
  }) {
    final angle = random.nextDouble() * math.pi * 2;
    final magnitude = speed * (0.4 + random.nextDouble() * 0.8);
    return _Particle(
      x: x,
      y: y,
      vx: math.cos(angle) * magnitude,
      vy: math.sin(angle) * magnitude,
      color: color,
      life: life,
      maxLife: life,
      size: size * (0.6 + random.nextDouble() * 0.8),
    );
  }

  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  double life;
  final double maxLife;
  final double size;

  bool get isDead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += dt * 0.4;
    life -= dt;
  }
}
