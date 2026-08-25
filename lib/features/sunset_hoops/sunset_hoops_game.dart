import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'sunset_hoops_config.dart';

/// Centralized ball lifecycle — replaces a pile of independent booleans
/// (isShooting/isAiming/isScored/isMissed/isResetting) that could produce
/// contradictory states. Only one of these is ever true at a time.
enum BallFlightState { idle, aiming, flying, resetting }

/// A hand-painted, cartoon-styled basketball toss game. Everything is
/// drawn with [Canvas] primitives (no image assets required) so the whole
/// look can be re-themed from [SunsetHoopsConfig].
///

class SunsetHoopsGame extends FlameGame {
  SunsetHoopsGame({required this.onShotResolved, required this.onGameOver});

  /// Fired once per resolved shot — made (with points + whether it banked
  /// off the backboard first) or missed. Guaranteed to fire exactly once
  /// per shot (see [_shotOutcomeReported]).
  final void Function({
    required bool made,
    required int points,
    required bool banked,
  })
  onShotResolved;

  /// Fired once the run ends (misses hit the cap).
  final VoidCallback onGameOver;

  /// When true, draws collider outlines, the velocity vector, and the
  /// current [BallFlightState] over the scene — useful while tuning
  /// collision behavior. Off by default.
  bool debugCollisions = false;

  final math.Random _random = math.Random();
  final List<_Particle> _particles = <_Particle>[];
  final List<_FloatingText> _floatingTexts = <_FloatingText>[];
  final List<Offset> _trail = <Offset>[];

  BallFlightState _flightState = BallFlightState.idle;

  double _ballX = 0;
  double _ballY = 0;
  double _prevBallX = 0;
  double _prevBallY = 0;
  double _vx = 0;
  double _vy = 0;
  double _ballRotation = 0;
  double _ballSpin = 0;

  bool _dragging = false;
  Offset _dragStart = Offset.zero;
  Offset _dragCurrent = Offset.zero;

  double _hoopX = 0.5;
  double _hoopY = 0.26;
  bool _bankedThisFlight = false;

  /// Guards against a single shot firing [onShotResolved] more than once —
  /// e.g. scoring and then also being reported as a miss once it settles,
  /// or the ball lingering across multiple frames inside the score zone.
  bool _shotOutcomeReported = false;

  double _resetTimer = 0;

  double _netSwing = 0;
  double _netSwingVel = 0;
  double _shakeTime = 0;

  int _misses = 0;
  bool _running = false;
  bool _paused = false;
  bool _gameOverFired = false;

  bool get isRunning => _running && !_gameOverFired && !_paused;
  bool get isAiming => _flightState == BallFlightState.aiming;
  double get dragPowerFraction {
    if (!_dragging) return 0;
    final d = (_dragStart - _dragCurrent).distance;
    return (d / SunsetHoopsConfig.maxDragDistance).clamp(0.0, 1.0);
  }

  @override
  Color backgroundColor() => SunsetHoopsConfig.skyTop;

  @override
  Future<void> onLoad() async {
    _resetBallToShooter();
    _randomizeHoop();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ballX == 0 && _ballY == 0) _resetBallToShooter();
  }

  void _resetBallToShooter() {
    _ballX = size.x * SunsetHoopsConfig.shooterX;
    _ballY = size.y * SunsetHoopsConfig.shooterY;
    _prevBallX = _ballX;
    _prevBallY = _ballY;
    _vx = 0;
    _vy = 0;
    _ballSpin = 0;
    _dragging = false;
    _flightState = BallFlightState.idle;
  }

  void _randomizeHoop() {
    _hoopX =
        SunsetHoopsConfig.hoopXMin +
        _random.nextDouble() *
            (SunsetHoopsConfig.hoopXMax - SunsetHoopsConfig.hoopXMin);
    _hoopY =
        SunsetHoopsConfig.hoopYMin +
        _random.nextDouble() *
            (SunsetHoopsConfig.hoopYMax - SunsetHoopsConfig.hoopYMin);
  }

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  void startGame() {
    _particles.clear();
    _floatingTexts.clear();
    _trail.clear();
    _misses = 0;
    _netSwing = 0;
    _netSwingVel = 0;
    _shakeTime = 0;
    _running = true;
    _paused = false;
    _gameOverFired = false;
    _resetBallToShooter();
    _randomizeHoop();
  }

  void pauseGame() {
    if (!_gameOverFired) _paused = true;
  }

  void resumeGame() {
    if (!_gameOverFired) _paused = false;
  }

  // ---------------------------------------------------------------------
  // Input — driven by a GestureDetector wrapping the GameWidget
  // ---------------------------------------------------------------------

  /// [screenPos] is the local position within the [GameWidget] (i.e. what
  /// a Flutter [GestureDetector]'s pan callbacks give you).
  void onDragStart(Offset screenPos) {
    if (!isRunning || _flightState != BallFlightState.idle) return;
    final dx = screenPos.dx - _ballX;
    final dy = screenPos.dy - _ballY;
    final grabRadius = SunsetHoopsConfig.ballRadius * 2.4;
    if (dx * dx + dy * dy > grabRadius * grabRadius) return;
    _flightState = BallFlightState.aiming;
    _dragging = true;
    _dragStart = Offset(_ballX, _ballY);
    _dragCurrent = screenPos;
  }

  void onDragUpdate(Offset screenPos) {
    if (!_dragging) return;
    _dragCurrent = screenPos;
  }

  void onDragEnd() {
    if (!_dragging) return;
    _dragging = false;

    final delta = _dragCurrent - _dragStart;
    final distance = delta.distance;
    if (distance < SunsetHoopsConfig.minDragDistance) {
      // Too small a pull — cancelled, ball stays put for another try.
      _flightState = BallFlightState.idle;
      return;
    }
    _launch(delta, distance);
  }

  void onDragCancel() {
    _dragging = false;
    if (_flightState == BallFlightState.aiming) {
      _flightState = BallFlightState.idle;
    }
  }

  void _launch(Offset delta, double distance) {
    final clamped = math.min(distance, SunsetHoopsConfig.maxDragDistance);
    final power = clamped * SunsetHoopsConfig.launchPowerMultiplier;
    final dir = delta / distance;

    _vx = dir.dx * power;
    // A pure horizontal or downward swipe still needs to leave the ground
    // — floor out how flat the shot can be.
    _vy = math.min(dir.dy * power, -power * 0.35);
    _ballSpin = (delta.dx / clamped) * 6;

    _prevBallX = _ballX;
    _prevBallY = _ballY;
    _bankedThisFlight = false;
    _shotOutcomeReported = false;
    _trail.clear();

    _flightState = BallFlightState.flying;
  }

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateParticles(dt);
    _updateFloatingTexts(dt);
    if (_shakeTime > 0) _shakeTime = math.max(0, _shakeTime - dt);
    _updateNetSwing(dt);

    if (!_running || _paused) return;

    switch (_flightState) {
      case BallFlightState.flying:
        _stepFlightPhysics(dt);
        break;
      case BallFlightState.resetting:
        _resetTimer -= dt;
        if (_resetTimer <= 0) {
          _resetBallToShooter();
        }
        break;
      case BallFlightState.idle:
      case BallFlightState.aiming:
        break;
    }
  }

  void _updateNetSwing(double dt) {
    if (_netSwingVel == 0 && _netSwing == 0) return;
    _netSwingVel -= _netSwing * 40 * dt;
    _netSwingVel -= _netSwingVel * SunsetHoopsConfig.netSwingDecay * dt;
    _netSwing += _netSwingVel * dt;
  }

  /// Substeps the physics integration when the ball is moving fast enough
  /// that a single frame's movement could tunnel straight through a rim
  /// post collider. Each substep moves the ball no further than half a
  /// ball-radius, which keeps every collision check working against a
  /// position close enough to the previous one that penetration depth
  /// stays small and correctable.
  void _stepFlightPhysics(double dt) {
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    final maxStepDistance = SunsetHoopsConfig.ballRadius * 0.5;
    final distanceThisFrame = speed * dt;

    final substeps = distanceThisFrame <= maxStepDistance
        ? 1
        : math.min(8, (distanceThisFrame / maxStepDistance).ceil());
    final subDt = dt / substeps;

    for (var i = 0; i < substeps; i++) {
      _integrate(subDt);
      if (_flightState != BallFlightState.flying) break; // settled mid-loop
    }
  }

  void _integrate(double subDt) {
    _prevBallX = _ballX;
    _prevBallY = _ballY;

    _vy += SunsetHoopsConfig.gravity * subDt;
    _vx *= SunsetHoopsConfig.airDrag;
    _ballX += _vx * subDt;
    _ballY += _vy * subDt;
    _ballRotation += _ballSpin * subDt;

    _trail.add(Offset(_ballX, _ballY));
    if (_trail.length > 16) _trail.removeAt(0);

    _resolveBackboardCollision();
    _resolveRimCollisions();
    _checkScoreSensor();
    _checkGroundAndBounds();
  }

  // ---------------------------------------------------------------------
  // Collision — backboard (resolved circle-vs-rect)
  // ---------------------------------------------------------------------

  void _resolveBackboardCollision() {
    final bx = size.x * _hoopX;
    final centerY = size.y * _hoopY - SunsetHoopsConfig.backboardHeight * 0.15;
    final halfW = SunsetHoopsConfig.backboardWidth / 2;
    final halfH = SunsetHoopsConfig.backboardHeight / 2;
    final r = SunsetHoopsConfig.ballRadius;

    final closestX = _ballX.clamp(bx - halfW, bx + halfW);
    final closestY = _ballY.clamp(centerY - halfH, centerY + halfH);
    final dx = _ballX - closestX;
    final dy = _ballY - closestY;
    final distSq = dx * dx + dy * dy;
    if (distSq >= r * r) return;

    final dist = math.sqrt(distSq);
    final nx = dist < 0.0001 ? 0.0 : dx / dist;
    final ny = dist < 0.0001 ? -1.0 : dy / dist;
    final penetration = r - dist;

    // Positional correction — push the ball fully outside the collider
    // before touching velocity, so it can never remain embedded.
    _ballX += nx * (penetration + SunsetHoopsConfig.collisionEpsilon);
    _ballY += ny * (penetration + SunsetHoopsConfig.collisionEpsilon);

    final dot = _vx * nx + _vy * ny;
    if (dot >= 0) return; // already moving away — don't re-reflect it.

    _vx -= 2 * dot * nx;
    _vy -= 2 * dot * ny;
    _vx *= SunsetHoopsConfig.backboardRestitution;
    _vy *= SunsetHoopsConfig.backboardRestitution;

    _bankedThisFlight = true;
    _shake(0.08);
    _spawnBurst(_ballX, _ballY, Colors.white, count: 6);
  }

  // ---------------------------------------------------------------------
  // Collision — rim (two circular post colliders, center stays open)
  // ---------------------------------------------------------------------

  void _resolveRimCollisions() {
    final rx = size.x * _hoopX;
    final ry = size.y * _hoopY;
    final halfRim = SunsetHoopsConfig.rimWidth / 2;
    _resolveRimPost(Offset(rx - halfRim, ry));
    _resolveRimPost(Offset(rx + halfRim, ry));
  }

  void _resolveRimPost(Offset post) {
    final dx = _ballX - post.dx;
    final dy = _ballY - post.dy;
    final r = SunsetHoopsConfig.ballRadius + SunsetHoopsConfig.rimPostRadius;
    final distSq = dx * dx + dy * dy;
    if (distSq >= r * r) return;

    final dist = math.sqrt(distSq);
    final nx = dist < 0.0001 ? 0.0 : dx / dist;
    final ny = dist < 0.0001 ? -1.0 : dy / dist;
    final penetration = r - dist;

    _ballX += nx * (penetration + SunsetHoopsConfig.collisionEpsilon);
    _ballY += ny * (penetration + SunsetHoopsConfig.collisionEpsilon);

    final dot = _vx * nx + _vy * ny;
    if (dot >= 0)
      return; // moving away already — no re-reflect (prevents the stuck-loop bug).

    _vx -= 2 * dot * nx;
    _vy -= 2 * dot * ny;
    _vx *= SunsetHoopsConfig.rimRestitution;
    _vy *= SunsetHoopsConfig.rimRestitution;

    _shake(0.05);
    _spawnBurst(_ballX, _ballY, SunsetHoopsConfig.rimColor, count: 8);
  }

  // ---------------------------------------------------------------------
  // Score sensor — NOT a physical collider. Pure trigger logic based on
  // the ball crossing the rim line moving downward, inside the inner
  // opening, exactly once per shot.
  // ---------------------------------------------------------------------

  void _checkScoreSensor() {
    if (_shotOutcomeReported) return;

    final rx = size.x * _hoopX;
    final ry = size.y * _hoopY;
    final halfInner = SunsetHoopsConfig.rimWidth * 0.5 * 0.62;

    final wasAbove = _prevBallY < ry;
    final isAtOrBelow = _ballY >= ry;
    final withinOpening = (_ballX - rx).abs() < halfInner;
    final movingDown = _vy > 0;

    if (wasAbove && isAtOrBelow && withinOpening && movingDown) {
      _registerScore(rx, ry);
    }
  }

  void _registerScore(double rimX, double rimY) {
    _shotOutcomeReported = true;
    _netSwingVel += 3.2;
    _shake(SunsetHoopsConfig.crashShakeDuration * 0.6);

    final points =
        SunsetHoopsConfig.baseScore +
        (_bankedThisFlight ? SunsetHoopsConfig.backboardBankBonus : 0);
    _spawnBurst(rimX, rimY, SunsetHoopsConfig.gold, count: 22);
    _spawnFloatingText(
      rimX,
      rimY,
      _bankedThisFlight ? 'BANK SHOT! +$points' : 'SWISH! +$points',
      SunsetHoopsConfig.gold,
    );

    // Report immediately — the ball keeps falling naturally afterwards,
    // it is never frozen at the hoop.
    onShotResolved(made: true, points: points, banked: _bankedThisFlight);

    _randomizeHoop();
  }

  // ---------------------------------------------------------------------
  // Ground + out-of-bounds — settles the shot and, if it wasn't already
  // scored, reports it as a miss exactly once.
  // ---------------------------------------------------------------------

  void _checkGroundAndBounds() {
    final groundY = size.y * SunsetHoopsConfig.groundYFraction;
    final r = SunsetHoopsConfig.ballRadius;

    if (_ballY + r >= groundY) {
      _ballY = groundY - r;
      if (_vy > 0) {
        _vy = -_vy * SunsetHoopsConfig.groundRestitution;
        _vx *= SunsetHoopsConfig.groundFriction;
        _shake(0.05);
        _spawnBurst(
          _ballX,
          groundY,
          Colors.white.withValues(alpha: 0.4),
          count: 5,
        );
      }
    }

    final offSide = _ballX < -80 || _ballX > size.x + 80;
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    final restingOnGround =
        (_ballY + r >= groundY - 1) && speed < SunsetHoopsConfig.stopThreshold;

    if (offSide || restingOnGround) {
      _finishShot();
    }
  }

  void _finishShot() {
    if (_flightState != BallFlightState.flying) return;

    if (!_shotOutcomeReported) {
      _shotOutcomeReported = true;
      onShotResolved(made: false, points: 0, banked: false);
      _misses++;
    }

    _flightState = BallFlightState.resetting;
    _resetTimer = SunsetHoopsConfig.resetDelay;

    if (_misses >= SunsetHoopsConfig.maxMisses) {
      _gameOverFired = true;
      _running = false;
      onGameOver();
    }
  }

  void _shake(double amount) => _shakeTime = math.max(_shakeTime, amount);

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _updateFloatingTexts(double dt) {
    for (final t in _floatingTexts) {
      t.y -= 34 * dt;
      t.life -= dt;
    }
    _floatingTexts.removeWhere((t) => t.life <= 0);
  }

  void _spawnBurst(double x, double y, Color color, {required int count}) {
    for (var i = 0; i < count; i++) {
      _particles.add(
        _Particle.burst(
          x: x,
          y: y,
          color: color,
          random: _random,
          speed: 170,
          life: 0.55,
          size: 4.5,
        ),
      );
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color) {
    _floatingTexts.add(
      _FloatingText(
        x: x,
        y: y,
        text: text,
        color: color,
        life: 1.0,
        maxLife: 1.0,
      ),
    );
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
      final p = _shakeTime / SunsetHoopsConfig.crashShakeDuration;
      canvas.translate(
        (_random.nextDouble() - 0.5) *
            SunsetHoopsConfig.crashShakeMagnitude *
            p,
        (_random.nextDouble() - 0.5) *
            SunsetHoopsConfig.crashShakeMagnitude *
            p,
      );
    }

    _renderSky(canvas, w, h);
    _renderParkBackdrop(canvas, w, h); // ← new
    _renderCourt(canvas, w, h);
    _renderHoop(canvas, w, h);

    if (_dragging) _renderAimGuide(canvas);
    _renderTrail(canvas);
    _renderBallSunburst(canvas); // ← new
    _renderBall(canvas);

    _renderParticles(canvas);
    _renderFloatingTexts(canvas);
    _renderDebug(canvas);

    canvas.restore();
  }

  void _renderSky(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SunsetHoopsConfig.skyTop,
            SunsetHoopsConfig.skyMid,
            SunsetHoopsConfig.skyBottom,
          ],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.16),
      w * 0.12,
      Paint()..color = SunsetHoopsConfig.sunGlow.withValues(alpha: 0.85),
    );
  }

  void _renderCourt(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, h * 0.72, w, h * 0.28);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SunsetHoopsConfig.courtLight, SunsetHoopsConfig.courtDark],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = SunsetHoopsConfig.courtLine.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * _hoopX, h * 0.72),
        width: w * 0.5,
        height: w * 0.28,
      ),
      0,
      math.pi,
      false,
      line,
    );
  }

  void _renderHoop(Canvas canvas, double w, double h) {
    final rx = w * _hoopX;
    final ry = h * _hoopY;

    // Backboard.
    final board = Rect.fromCenter(
      center: Offset(rx, ry - SunsetHoopsConfig.backboardHeight * 0.15),
      width: SunsetHoopsConfig.backboardWidth,
      height: SunsetHoopsConfig.backboardHeight,
    );
    canvas.drawRect(
      board,
      Paint()..color = SunsetHoopsConfig.backboard.withValues(alpha: 0.92),
    );
    canvas.drawRect(
      board,
      Paint()
        ..color = SunsetHoopsConfig.navyDeep.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(rx, ry - 6), width: 34, height: 26),
      Paint()
        ..color = SunsetHoopsConfig.backboardShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    // Rim.
    final rimPaint = Paint()
      ..color = SunsetHoopsConfig.rimColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rx - SunsetHoopsConfig.rimWidth / 2, ry),
      Offset(rx + SunsetHoopsConfig.rimWidth / 2, ry),
      rimPaint,
    );

    // Net — visual/animated only, never a physical collider, so it can
    // never trap the ball.
    final netPaint = Paint()
      ..color = SunsetHoopsConfig.netColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.6;
    const strands = 7;
    final netBottomY = ry + 30;
    for (var i = 0; i < strands; i++) {
      final t = i / (strands - 1);
      final topX =
          rx - SunsetHoopsConfig.rimWidth / 2 + SunsetHoopsConfig.rimWidth * t;
      final sway = math.sin(_netSwing + t * math.pi) * 5;
      canvas.drawLine(
        Offset(topX, ry + 2),
        Offset(rx + sway + _netSwing * 4, netBottomY),
        netPaint,
      );
    }
  }

  void _renderAimGuide(Canvas canvas) {
    final delta = _dragCurrent - _dragStart;
    final distance = delta.distance;
    if (distance < 4) return;
    final clamped = math.min(distance, SunsetHoopsConfig.maxDragDistance);
    final dir = delta / distance;
    final power = clamped * SunsetHoopsConfig.launchPowerMultiplier;
    final vx = dir.dx * power;
    final vy = math.min(dir.dy * power, -power * 0.35);

    var x = _ballX;
    var y = _ballY;
    var dvy = vy;
    final fraction = dragPowerFraction;
    final color = Color.lerp(SunsetHoopsConfig.teal, SunsetHoopsConfig.coral, fraction)!;

    Offset? apex;
    var wasRising = dvy < 0;

    for (var i = 0; i < 26; i++) {
      dvy += SunsetHoopsConfig.gravity * 0.03;
      x += vx * 0.03;
      y += dvy * 0.03;
      if (y > size.y) break;

      // The instant vertical velocity flips from rising to falling is the
      // trajectory's apex — that's where the reticle belongs.
      if (wasRising && dvy >= 0) {
        apex = Offset(x, y);
        wasRising = false;
      }

      if (i % 2 == 0) {
        canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = color.withValues(alpha: 0.55 * (1 - i / 26)));
      }
    }

    if (apex != null) {
      canvas.drawCircle(apex, 12, Paint()..color = Colors.white.withValues(alpha: 0.16));
      canvas.drawCircle(
        apex,
        9,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(apex, 2, Paint()..color = Colors.white);
    }

    canvas.drawCircle(_dragCurrent, 18 + fraction * 8, Paint()..color = color.withValues(alpha: 0.14));
  }

  void _renderTrail(Canvas canvas) {
    for (var i = 0; i < _trail.length; i++) {
      final a = (i / _trail.length) * 0.3;
      canvas.drawCircle(
        _trail[i],
        SunsetHoopsConfig.ballRadius * 0.3,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  void _renderBall(Canvas canvas) {
    final pos = Offset(_ballX, _ballY);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_ballX, size.y * SunsetHoopsConfig.groundYFraction + 4),
        width: SunsetHoopsConfig.ballRadius * 1.6,
        height: 8,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(_ballRotation);

    canvas.drawCircle(
      Offset.zero,
      SunsetHoopsConfig.ballRadius,
      Paint()..color = SunsetHoopsConfig.ballBody,
    );
    final linePaint = Paint()
      ..color = SunsetHoopsConfig.ballLine
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, SunsetHoopsConfig.ballRadius, linePaint);
    canvas.drawLine(
      Offset(-SunsetHoopsConfig.ballRadius, 0),
      Offset(SunsetHoopsConfig.ballRadius, 0),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, -SunsetHoopsConfig.ballRadius),
      Offset(0, SunsetHoopsConfig.ballRadius),
      linePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset.zero,
        radius: SunsetHoopsConfig.ballRadius,
      ),
      -math.pi / 2.6,
      math.pi / 1.3,
      false,
      linePaint,
    );
    canvas.restore();
  }

  void _renderParticles(Canvas canvas) {
    for (final p in _particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * alpha,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }
  }

  void _renderFloatingTexts(Canvas canvas) {
    for (final t in _floatingTexts) {
      final alpha = (t.life / t.maxLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color.withValues(alpha: alpha),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(t.x - tp.width / 2, t.y - tp.height / 2));
    }
  }

  /// Draws every collider (rim posts, backboard, score sensor, ball) plus
  /// the velocity vector and current [BallFlightState], gated behind
  /// [debugCollisions]. Toggle it from the screen/dev tools while tuning
  /// collision values.
  void _renderDebug(Canvas canvas) {
    if (!debugCollisions) return;
    final rx = size.x * _hoopX;
    final ry = size.y * _hoopY;
    final halfRim = SunsetHoopsConfig.rimWidth / 2;

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.redAccent;
    canvas.drawCircle(
      Offset(rx - halfRim, ry),
      SunsetHoopsConfig.rimPostRadius,
      rimPaint,
    );
    canvas.drawCircle(
      Offset(rx + halfRim, ry),
      SunsetHoopsConfig.rimPostRadius,
      rimPaint,
    );

    final centerY = ry - SunsetHoopsConfig.backboardHeight * 0.15;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(rx, centerY),
        width: SunsetHoopsConfig.backboardWidth,
        height: SunsetHoopsConfig.backboardHeight,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.blueAccent,
    );

    final halfInner = SunsetHoopsConfig.rimWidth * 0.5 * 0.62;
    canvas.drawRect(
      Rect.fromLTWH(rx - halfInner, ry, halfInner * 2, 26),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.greenAccent,
    );

    canvas.drawLine(
      Offset(0, size.y * SunsetHoopsConfig.groundYFraction),
      Offset(size.x, size.y * SunsetHoopsConfig.groundYFraction),
      Paint()
        ..strokeWidth = 1.6
        ..color = Colors.orangeAccent,
    );

    canvas.drawCircle(
      Offset(_ballX, _ballY),
      SunsetHoopsConfig.ballRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.yellowAccent,
    );

    canvas.drawLine(
      Offset(_ballX, _ballY),
      Offset(_ballX + _vx * 0.15, _ballY + _vy * 0.15),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.cyanAccent,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'STATE: ${_flightState.name.toUpperCase()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(10, 10));
  }

  void _renderParkBackdrop(Canvas canvas, double w, double h) {
    // Distant building silhouettes along the horizon.
    final buildingPaint = Paint()
      ..color = SunsetHoopsConfig.navyDeep.withValues(alpha: 0.28);
    final rnd = math.Random(
      7,
    ); // fixed seed — stable skyline, not reshuffled every frame
    var x = -20.0;
    while (x < w + 40) {
      final bw = 46 + rnd.nextDouble() * 40;
      final bh = h * (0.16 + rnd.nextDouble() * 0.12);
      final topY = h * 0.40 - bh;
      canvas.drawRect(Rect.fromLTWH(x, topY, bw, bh), buildingPaint);
      // A few window dots per building for texture.
      final winPaint = Paint()..color = Colors.white.withValues(alpha: 0.10);
      for (var wy = topY + 10; wy < topY + bh - 8; wy += 14) {
        for (var wx = x + 8; wx < x + bw - 8; wx += 14) {
          canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 7), winPaint);
        }
      }
      x += bw + 14;
    }

    // Distant tree clusters sitting in front of the buildings.
    final leafPaint = Paint()
      ..color = SunsetHoopsConfig.teal.withValues(alpha: 0.35);
    for (var i = 0; i < 6; i++) {
      final tx = w * (0.05 + i * 0.17) + math.sin(i * 12.3) * 14;
      final ty = h * 0.40;
      final r = 20 + (i.isEven ? 6 : 0);
      canvas.drawCircle(Offset(tx, ty), r.toDouble(), leafPaint);
      canvas.drawCircle(Offset(tx - r * 0.5, ty + r * 0.3), r * 0.7, leafPaint);
      canvas.drawCircle(
        Offset(tx + r * 0.5, ty + r * 0.25),
        r * 0.65,
        leafPaint,
      );
    }
  }

  /// A soft radiating glow behind the ball while it's idle/aiming — a
  /// cheap cartoon nod to the "hero glow" treatment on the ball in
  /// reference basketball games, done with plain Canvas primitives.
  void _renderBallSunburst(Canvas canvas) {
    if (_flightState == BallFlightState.flying) return;
    final pos = Offset(_ballX, _ballY);
    const rays = 16;
    final paint = Paint()
      ..color = SunsetHoopsConfig.gold.withValues(alpha: 0.22)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * math.pi * 2;
      final inner = SunsetHoopsConfig.ballRadius * 1.5;
      final outer = SunsetHoopsConfig.ballRadius * 2.6;
      canvas.drawLine(
        pos + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        pos + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        paint,
      );
    }
  }
}

class _FloatingText {
  _FloatingText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.life,
    required this.maxLife,
  });
  double x;
  double y;
  final String text;
  final Color color;
  double life;
  final double maxLife;
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
    vy += dt * 60;
    life -= dt;
  }
}
