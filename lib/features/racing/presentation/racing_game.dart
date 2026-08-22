import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'racing_config.dart';

/// A hand-painted, cartoon-styled endless racer. Everything is drawn with
/// [Canvas] primitives (no image assets required) so the whole look can be
/// re-themed from [RacingConfig].
///
/// Supports both on-screen touch controls and a physical keyboard (for web):
/// A/D to steer, S to brake, and Enter or Space to trigger nitro.
class RacingGame extends FlameGame with KeyboardEvents {
  RacingGame({required this.onGameOver});

  /// Fired once, with the final score and coins collected, when a run ends.
  final void Function(int score, int coins) onGameOver;

  final math.Random _random = math.Random();
  final List<_RoadCar> _traffic = <_RoadCar>[];
  final List<_Coin> _coinPickups = <_Coin>[];
  final List<_NitroToken> _nitroTokens = <_NitroToken>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_Cloud> _clouds = <_Cloud>[];
  final List<_SceneryProp> _scenery = <_SceneryProp>[];

  double _playerX = 0.5;
  final double _playerY = 0.82;
  double _bobTime = 0;
  double _tiltX = 0;

  double _speed = RacingConfig.baseSpeed;
  double _distance = 0;
  double _spawnTimer = 0;
  double _coinSpawnTimer = 0;
  double _sceneryTimer = 0;
  double _roadOffset = 0;
  double _roadCurve = 0;
  double _roadCurveTarget = 0;
  double _curveChangeTimer = 0;

  int _score = 0;
  int _coinsCollected = 0;
  int _lap = 1;

  bool _running = true;
  bool _paused = false;
  bool _braking = false;
  bool _left = false;
  bool _right = false;
  bool _gameOverFired = false;

  double _nitroTimeLeft = 0;
  double _nitroCooldown = 0;
  double _shakeTime = 0;

  /// Bumped every update tick so a [ValueListenableBuilder] can cheaply
  /// rebuild the HUD without Flame having to know about Flutter widgets.
  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  int get score => _score;
  int get coins => _coinsCollected;
  int get lap => _lap;
  double get speed => _speed;
  bool get isRunning => _running && !_gameOverFired && !_paused;
  bool get isPausedByUser => _paused && !_gameOverFired;
  bool get nitroActive => _nitroTimeLeft > 0;
  bool get nitroReady => _nitroCooldown <= 0 && !nitroActive;
  double get nitroCharge =>
      1 - (_nitroCooldown / RacingConfig.nitroCooldown).clamp(0.0, 1.0);

  @override
  Color backgroundColor() => RacingConfig.skyTop;

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
          y: 0.06 + _random.nextDouble() * 0.28,
          scale: 0.6 + _random.nextDouble() * 0.8,
          speed: 0.01 + _random.nextDouble() * 0.02,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------

  void steerLeft(bool active) => _left = active;
  void steerRight(bool active) => _right = active;
  void brake(bool active) => _braking = active;

  void movePlayer(double delta) {
    _playerX = (_playerX + delta)
        .clamp(RacingConfig.laneMin, RacingConfig.laneMax)
        .toDouble();
    _tiltX = delta.clamp(-1.0, 1.0).toDouble();
  }

  void togglePause() {
    if (_gameOverFired) return;
    _paused = !_paused;
    hudTick.value++;
  }

  void activateNitro() {
    if (!_running || !nitroReady) return;
    _nitroTimeLeft = RacingConfig.nitroDuration;
    _nitroCooldown = RacingConfig.nitroCooldown;
    _shakeTime = math.max(_shakeTime, 0.18);
  }

  // ---------------------------------------------------------------------
  // Keyboard (web/desktop)
  // ---------------------------------------------------------------------

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    steerLeft(keysPressed.contains(LogicalKeyboardKey.keyA));
    steerRight(keysPressed.contains(LogicalKeyboardKey.keyD));
    brake(keysPressed.contains(LogicalKeyboardKey.keyS));

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      activateNitro();
    }

    return KeyEventResult.handled;
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

    _bobTime += dt;
    _tiltX *= math.max(0, 1 - dt * 6);

    if (_left) movePlayer(-dt * RacingConfig.steerRate);
    if (_right) movePlayer(dt * RacingConfig.steerRate);

    final rampT = (_distance / RacingConfig.distanceForFullRamp).clamp(0.0, 1.0);
    final targetSpeed = _braking
        ? RacingConfig.brakeSpeed
        : RacingConfig.baseSpeed + rampT * RacingConfig.speedRampCap;
    final boosted = nitroActive
        ? targetSpeed + RacingConfig.nitroSpeedBoost
        : targetSpeed;
    _speed += (boosted - _speed) * dt * 2.6;

    if (_nitroTimeLeft > 0) {
      _nitroTimeLeft = math.max(0, _nitroTimeLeft - dt);
      if (_random.nextDouble() < 0.6) {
        _spawnTrailParticle();
      }
    }
    if (_nitroCooldown > 0) {
      _nitroCooldown = math.max(0, _nitroCooldown - dt);
    }
    if (_shakeTime > 0) {
      _shakeTime = math.max(0, _shakeTime - dt);
    }

    _distance += _speed * dt * 100;
    _roadOffset = (_roadOffset + _speed * dt * 0.9) % 1;

    _curveChangeTimer -= dt;
    if (_curveChangeTimer <= 0) {
      _curveChangeTimer = 2.2 + _random.nextDouble() * 2.4;
      _roadCurveTarget = (_random.nextDouble() * 2 - 1) * 0.16;
    }
    _roadCurve += (_roadCurveTarget - _roadCurve) * dt * 1.2;

    _updateSpawns(dt);
    _updateTraffic(dt);
    _updateCoins(dt);
    _updateNitroTokens(dt);

    _score = (_distance * 10).round();
    _lap = 1 + (_distance ~/ 900);
    hudTick.value++;
  }

  void _updateClouds(double dt) {
    for (final cloud in _clouds) {
      cloud.x -= cloud.speed * dt;
      if (cloud.x < -0.2) {
        cloud.x = 1.2;
        cloud.y = 0.05 + _random.nextDouble() * 0.28;
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
      _spawnTimer = math.max(0.42, 1.05 - _distance / 3200);
      _spawnTraffic();
    }

    _coinSpawnTimer -= dt;
    if (_coinSpawnTimer <= 0) {
      _coinSpawnTimer = 0.9 + _random.nextDouble() * 0.6;
      if (_random.nextDouble() < RacingConfig.coinSpawnChance) {
        _spawnCoinRow();
      } else if (_random.nextDouble() < RacingConfig.nitroTokenChance) {
        _spawnNitroToken();
      }
    }

    _sceneryTimer -= dt;
    if (_sceneryTimer <= 0) {
      _sceneryTimer = 0.35;
      _scenery.add(
        _SceneryProp(
          leftSide: _random.nextBool(),
          y: -0.08,
          kind: _random.nextInt(3),
        ),
      );
    }
    for (final prop in _scenery) {
      prop.y += _speed * dt * 0.75;
    }
    _scenery.removeWhere((p) => p.y > 1.15);
  }

  void _spawnTraffic() {
    final type = _RivalType.values[_random.nextInt(_RivalType.values.length)];
    _traffic.add(
      _RoadCar(
        x: 0.24 + _random.nextDouble() * 0.52,
        y: -0.14,
        speed: 0.20 + _random.nextDouble() * 0.18,
        color: RacingConfig
            .rivalBodies[_random.nextInt(RacingConfig.rivalBodies.length)],
        type: type,
      ),
    );
  }

  void _spawnCoinRow() {
    final lane = 0.24 + _random.nextDouble() * 0.52;
    final count = 1 + _random.nextInt(3);
    for (var i = 0; i < count; i++) {
      _coinPickups.add(_Coin(x: lane, y: -0.10 - i * 0.09));
    }
  }

  void _spawnNitroToken() {
    _nitroTokens.add(
      _NitroToken(x: 0.24 + _random.nextDouble() * 0.52, y: -0.12),
    );
  }

  void _updateTraffic(double dt) {
    for (final car in _traffic) {
      car.y += (_speed + car.speed) * dt * 0.75;
      car.wobble += dt;
    }
    _traffic.removeWhere((car) => car.y > 1.2);

    for (final car in _traffic) {
      if (_hits(car.x, car.y, 0.10)) {
        _crash();
        return;
      }
    }
  }

  void _updateCoins(double dt) {
    for (final coin in _coinPickups) {
      coin.y += _speed * dt * 0.75;
      coin.spin += dt * 6;
    }
    _coinPickups.removeWhere((coin) => coin.y > 1.15);

    _coinPickups.removeWhere((coin) {
      if (_hits(coin.x, coin.y, 0.075)) {
        _coinsCollected++;
        _score += RacingConfig.coinScoreValue;
        _spawnCoinSparkle(coin.x, coin.y);
        return true;
      }
      return false;
    });
  }

  void _updateNitroTokens(double dt) {
    for (final token in _nitroTokens) {
      token.y += _speed * dt * 0.75;
      token.pulse += dt * 4;
    }
    _nitroTokens.removeWhere((token) => token.y > 1.15);

    _nitroTokens.removeWhere((token) {
      if (_hits(token.x, token.y, 0.08)) {
        activateNitro();
        _spawnBurst(token.x, token.y, RacingConfig.nitroColor, count: 14);
        return true;
      }
      return false;
    });
  }

  bool _hits(double x, double y, double radius) {
    final dx = x - _playerX;
    final dy = y - _playerY;
    return (dx * dx + dy * dy) < radius * radius;
  }

  void _crash() {
    if (_gameOverFired) return;
    _gameOverFired = true;
    _running = false;
    _spawnBurst(_playerX, _playerY, RacingConfig.playerBody, count: 26);
    _spawnBurst(_playerX, _playerY, RacingConfig.gold, count: 14);
    _shakeTime = RacingConfig.crashShakeDuration;
    onGameOver(_score, _coinsCollected);
  }

  void _spawnCoinSparkle(double x, double y) {
    for (var i = 0; i < 8; i++) {
      _particles.add(
        _Particle.burst(
          x: x,
          y: y,
          color: RacingConfig.coinShine,
          random: _random,
          speed: 0.5,
          life: 0.4,
          size: 3,
        ),
      );
    }
  }

  void _spawnTrailParticle() {
    _particles.add(
      _Particle(
        x: _playerX + (_random.nextDouble() - 0.5) * 0.05,
        y: _playerY + 0.06,
        vx: (_random.nextDouble() - 0.5) * 0.05,
        vy: 0.55 + _random.nextDouble() * 0.2,
        color: RacingConfig.nitroGlow,
        life: 0.35,
        maxLife: 0.35,
        size: 5 + _random.nextDouble() * 4,
      ),
    );
  }

  void _spawnBurst(double x, double y, Color color,
      {required int count}) {
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
      final power = _shakeTime / RacingConfig.crashShakeDuration;
      final dx = (_random.nextDouble() - 0.5) * RacingConfig.crashShakeMagnitude * power;
      final dy = (_random.nextDouble() - 0.5) * RacingConfig.crashShakeMagnitude * power;
      canvas.translate(dx, dy);
    }

    _renderSky(canvas, w, h);
    _renderScenery(canvas, w, h);
    _renderRoad(canvas, w, h);
    _renderSceneryProps(canvas, w, h);
    _renderCoins(canvas, w, h);
    _renderNitroTokens(canvas, w, h);
    for (final car in _traffic) {
      final scale = 0.55 + car.y * 0.55;
      _drawCartoonCar(
        canvas,
        w * _roadX(car.x, car.y),
        h * car.y,
        scale,
        car.color,
        type: car.type,
        wobble: math.sin(car.wobble * 6) * 0.03,
      );
    }
    if (!_gameOverFired) {
      _drawCartoonCar(
        canvas,
        w * _roadX(_playerX, _playerY),
        h * _playerY,
        1.0,
        RacingConfig.playerBody,
        type: _RivalType.player,
        wobble: math.sin(_bobTime * 6) * 0.02,
        tilt: _tiltX,
      );
    }
    _renderParticles(canvas, w, h);
    if (nitroActive) _renderNitroVignette(canvas, w, h);

    canvas.restore();
  }

  double _roadX(double x, double y) {
    final curveInfluence = (1 - y).clamp(0.0, 1.0);
    return x + _roadCurve * curveInfluence * 0.5;
  }

  void _renderSky(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          RacingConfig.skyTop,
          RacingConfig.skyMid,
          RacingConfig.skyBottom,
        ],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, gradient);

    canvas.drawCircle(
      Offset(w * 0.78, h * 0.16),
      w * 0.11,
      Paint()..color = RacingConfig.sun.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.16),
      w * 0.16,
      Paint()..color = RacingConfig.sun.withValues(alpha: 0.25),
    );

    for (final cloud in _clouds) {
      _drawCloud(canvas, w * cloud.x, h * cloud.y, w * 0.09 * cloud.scale);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double r) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
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
      Paint()..color = RacingConfig.grassA,
    );
    for (var i = 0; i < 10; i++) {
      final t = ((i / 10) + _roadOffset * 0.6) % 1;
      final y = h * 0.32 + t * h * 0.68;
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, h * 0.02),
        Paint()..color = RacingConfig.grassB.withValues(alpha: 0.55),
      );
    }
  }

  void _renderSceneryProps(Canvas canvas, double w, double h) {
    for (final prop in _scenery) {
      final t = prop.y.clamp(0.0, 1.2);
      final perspective = 0.35 + t * 0.9;
      final roadHalf = _roadHalfWidthAt(t) * w;
      final centerX = w * _roadX(0.5, t);
      final baseX = prop.leftSide ? centerX - roadHalf : centerX + roadHalf;
      final sideOffset = prop.leftSide ? -perspective * w * 0.10 : perspective * w * 0.10;
      final x = baseX + sideOffset;
      final y = h * t;
      _drawSceneryProp(canvas, x, y, perspective, prop.kind);
    }
  }

  void _drawSceneryProp(Canvas canvas, double x, double y, double scale, int kind) {
    switch (kind) {
      case 0:
        final trunkH = 22 * scale;
        final trunkW = 6 * scale;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: trunkW, height: trunkH),
          Paint()..color = RacingConfig.treeTrunk,
        );
        canvas.drawCircle(Offset(x, y - trunkH * 0.7), 16 * scale, Paint()..color = RacingConfig.treeLeaf);
        canvas.drawCircle(
          Offset(x - 6 * scale, y - trunkH * 0.55),
          11 * scale,
          Paint()..color = RacingConfig.treeLeaf.withValues(alpha: 0.85),
        );
        break;
      case 1:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 14 * scale, height: 14 * scale),
            Radius.circular(4 * scale),
          ),
          Paint()..color = RacingConfig.coral.withValues(alpha: 0.8),
        );
        break;
      default:
        canvas.drawCircle(Offset(x, y), 9 * scale, Paint()..color = RacingConfig.teal.withValues(alpha: 0.75));
    }
  }

  double _roadHalfWidthAt(double t) => 0.36 + t * 0.06;

  void _renderRoad(Canvas canvas, double w, double h) {
    final topHalf = 0.34;
    final bottomHalf = 0.42;
    final centerTop = w * _roadX(0.5, 0);
    final centerBottom = w * _roadX(0.5, 1);

    final road = Path()
      ..moveTo(centerTop - w * topHalf, 0)
      ..lineTo(centerTop + w * topHalf, 0)
      ..lineTo(centerBottom + w * bottomHalf, h)
      ..lineTo(centerBottom - w * bottomHalf, h)
      ..close();
    canvas.drawPath(road, Paint()..color = RacingConfig.roadDark);

    final edgePaint = Paint()
      ..color = RacingConfig.roadEdge
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerTop - w * topHalf, 0),
      Offset(centerBottom - w * bottomHalf, h),
      edgePaint,
    );
    canvas.drawLine(
      Offset(centerTop + w * topHalf, 0),
      Offset(centerBottom + w * bottomHalf, h),
      edgePaint,
    );

    for (var i = 0; i < 12; i++) {
      final t = (i / 12 + _roadOffset) % 1;
      final y = t * h;
      final half = _roadHalfWidthAt(t);
      final centerX = w * _roadX(0.5, t);
      final dashW = 4 + t * 6;
      final dashH = 16 + t * 30;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(centerX, y), width: dashW, height: dashH),
          Radius.circular(dashW / 2),
        ),
        Paint()..color = RacingConfig.laneStripe,
      );

      final laneOffset = w * half * 0.36;
      for (final side in [-1, 1]) {
        canvas.drawLine(
          Offset(centerX + side * laneOffset, y),
          Offset(centerX + side * laneOffset, y + dashH * 0.7),
          Paint()
            ..color = RacingConfig.roadLight.withValues(alpha: 0.7)
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _renderCoins(Canvas canvas, double w, double h) {
    for (final coin in _coinPickups) {
      final scale = 0.4 + coin.y * 0.7;
      final x = w * _roadX(coin.x, coin.y);
      final y = h * coin.y;
      final squash = (math.cos(coin.spin)).abs();
      final rx = 9 * scale * (0.4 + squash * 0.6);
      final ry = 9 * scale;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + ry * 0.9), width: rx * 2, height: ry * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.15),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        Paint()..color = RacingConfig.coinColor,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2 * 0.55, height: ry * 2 * 0.55),
        Paint()..color = RacingConfig.coinShine,
      );
    }
  }

  void _renderNitroTokens(Canvas canvas, double w, double h) {
    for (final token in _nitroTokens) {
      final scale = 0.45 + token.y * 0.7;
      final x = w * _roadX(token.x, token.y);
      final y = h * token.y;
      final glow = 0.5 + math.sin(token.pulse).abs() * 0.5;

      canvas.drawCircle(
        Offset(x, y),
        16 * scale * (0.8 + glow * 0.4),
        Paint()..color = RacingConfig.nitroGlow.withValues(alpha: 0.35 * glow),
      );
      canvas.drawCircle(Offset(x, y), 11 * scale, Paint()..color = RacingConfig.nitroColor);

      final bolt = Path()
        ..moveTo(x + 2 * scale, y - 8 * scale)
        ..lineTo(x - 4 * scale, y + 1 * scale)
        ..lineTo(x, y + 1 * scale)
        ..lineTo(x - 2 * scale, y + 8 * scale)
        ..lineTo(x + 5 * scale, y - 1 * scale)
        ..lineTo(x + 1 * scale, y - 1 * scale)
        ..close();
      canvas.drawPath(bolt, Paint()..color = Colors.white);
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

  void _renderNitroVignette(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          RacingConfig.nitroColor.withValues(alpha: 0.18),
        ],
        stops: const [0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawCartoonCar(
    Canvas canvas,
    double x,
    double y,
    double scale,
    Color body, {
    required _RivalType type,
    double wobble = 0,
    double tilt = 0,
  }) {
    final isTruck = type == _RivalType.truck;
    final isTaxi = type == _RivalType.taxi;
    final carW = size.x * (isTruck ? 0.135 : 0.105) * scale;
    final carH = size.y * (isTruck ? 0.15 : 0.13) * scale;
    final cx = x + wobble * carW;

    canvas.save();
    canvas.translate(cx, y);
    canvas.rotate(tilt * 0.12);
    canvas.translate(-cx, -y);

    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y + carH * 0.56), width: carW * 1.05, height: carH * 0.3),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    final darkBody = Color.lerp(body, Colors.black, 0.28)!;
    final outline = Paint()
      ..color = RacingConfig.navyDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, carW * 0.045)
      ..strokeJoin = StrokeJoin.round;

    // Body.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: carW, height: carH),
      Radius.circular(carW * 0.32),
    );
    canvas.drawRRect(bodyRect, Paint()..color = body);
    canvas.drawRRect(bodyRect, outline);

    // Lower shade for cel-shaded depth.
    final shadeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - carW / 2, y + carH * 0.12, carW, carH * 0.4),
      Radius.circular(carW * 0.3),
    );
    canvas.save();
    canvas.clipRRect(bodyRect);
    canvas.drawRRect(shadeRect, Paint()..color = darkBody.withValues(alpha: 0.35));
    canvas.restore();

    // Roof / cabin.
    final roofColor = isTaxi ? RacingConfig.gold : RacingConfig.canopy;
    final roofRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y - carH * 0.12), width: carW * 0.55, height: carH * 0.42),
      Radius.circular(carW * 0.22),
    );
    canvas.drawRRect(roofRect, Paint()..color = roofColor);
    canvas.drawRRect(roofRect, outline..strokeWidth = math.max(1.2, carW * 0.035));

    if (isTaxi) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, y - carH * 0.32), width: carW * 0.24, height: carH * 0.12),
        Paint()..color = Colors.black87,
      );
    }

    // Highlight streak (glossy cartoon shine).
    final highlight = Path()
      ..moveTo(cx - carW * 0.28, y - carH * 0.28)
      ..lineTo(cx - carW * 0.1, y - carH * 0.28)
      ..lineTo(cx - carW * 0.2, y + carH * 0.05)
      ..lineTo(cx - carW * 0.36, y + carH * 0.05)
      ..close();
    canvas.drawPath(highlight, Paint()..color = Colors.white.withValues(alpha: 0.35));

    // Headlights / taillights.
    final lightPaint = Paint()..color = RacingConfig.playerAccent;
    canvas.drawCircle(Offset(cx - carW * 0.28, y - carH * 0.42), carW * 0.07, lightPaint);
    canvas.drawCircle(Offset(cx + carW * 0.28, y - carH * 0.42), carW * 0.07, lightPaint);
    canvas.drawCircle(
      Offset(cx - carW * 0.28, y + carH * 0.42),
      carW * 0.06,
      Paint()..color = const Color(0xFFFF3D3D),
    );
    canvas.drawCircle(
      Offset(cx + carW * 0.28, y + carH * 0.42),
      carW * 0.06,
      Paint()..color = const Color(0xFFFF3D3D),
    );

    // Wheels.
    final wheelPaint = Paint()..color = RacingConfig.navyDeep;
    final wheelHubPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final side in [-1.0, 1.0]) {
      for (final end in [-1.0, 1.0]) {
        final wx = cx + side * carW * 0.48;
        final wy = y + end * carH * 0.34;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(wx, wy), width: carW * 0.16, height: carH * 0.22),
            Radius.circular(carW * 0.06),
          ),
          wheelPaint,
        );
        canvas.drawCircle(Offset(wx, wy), carW * 0.045, wheelHubPaint);
      }
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  void resetGame() {
    _traffic.clear();
    _coinPickups.clear();
    _nitroTokens.clear();
    _particles.clear();
    _scenery.clear();

    _playerX = 0.5;
    _speed = RacingConfig.baseSpeed;
    _distance = 0;
    _spawnTimer = 0;
    _coinSpawnTimer = 0;
    _sceneryTimer = 0;
    _roadOffset = 0;
    _roadCurve = 0;
    _roadCurveTarget = 0;
    _curveChangeTimer = 0;

    _score = 0;
    _coinsCollected = 0;
    _lap = 1;

    _running = true;
    _paused = false;
    _braking = false;
    _left = false;
    _right = false;
    _gameOverFired = false;

    _nitroTimeLeft = 0;
    _nitroCooldown = 0;
    _shakeTime = 0;

    hudTick.value++;
  }

  @override
  void onRemove() {
    hudTick.dispose();
    super.onRemove();
  }
}

enum _RivalType { player, car, taxi, truck }

class _RoadCar {
  _RoadCar({
    required this.x,
    required this.y,
    required this.speed,
    required this.color,
    required this.type,
  });

  double x;
  double y;
  final double speed;
  final Color color;
  final _RivalType type;
  double wobble = 0;
}

class _Coin {
  _Coin({required this.x, required this.y});
  double x;
  double y;
  double spin = 0;
}

class _NitroToken {
  _NitroToken({required this.x, required this.y});
  double x;
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
  _SceneryProp({required this.leftSide, required this.y, required this.kind});
  final bool leftSide;
  double y;
  final int kind;
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
