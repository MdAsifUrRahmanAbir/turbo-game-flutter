import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'sunset_hoops_config.dart';

enum _BallPhase { idle, flying, settling }

/// A hand-painted, cartoon-styled basketball toss game. Everything is
/// drawn with [Canvas] primitives (no image assets required) so the whole
/// look can be re-themed from [SunsetHoopsConfig].
///
/// Drag the ball, release to shoot — velocity is taken directly from the
/// drag vector (swipe up-and-through, not a mirrored slingshot pull).
/// Input is driven by a [GestureDetector] wrapping the [GameWidget] in the
/// screen file (same pattern as [AngryBirdGame] and [GultiGame]), not by
/// Flame's own drag callbacks.
class SunsetHoopsGame extends FlameGame {
  SunsetHoopsGame({required this.onShotResolved, required this.onGameOver});

  /// Fired once per resolved shot: made (with points + whether it banked
  /// off the backboard first) or missed.
  final void Function({required bool made, required int points, required bool banked}) onShotResolved;

  /// Fired once the run ends (misses hit the cap).
  final VoidCallback onGameOver;

  final math.Random _random = math.Random();
  final List<_Particle> _particles = <_Particle>[];
  final List<_FloatingText> _floatingTexts = <_FloatingText>[];
  final List<Offset> _trail = <Offset>[];

  double _ballX = 0;
  double _ballY = 0;
  double _vx = 0;
  double _vy = 0;
  double _ballRotation = 0;
  double _ballSpin = 0;
  _BallPhase _phase = _BallPhase.idle;

  bool _dragging = false;
  Offset _dragStart = Offset.zero;
  Offset _dragCurrent = Offset.zero;

  double _hoopX = 0.5;
  double _hoopY = 0.26;
  bool _scoredThisFlight = false;
  bool _bankedThisFlight = false;
  bool _throughRimBand = false;

  double _netSwing = 0;
  double _netSwingVel = 0;
  double _shakeTime = 0;

  int _misses = 0;
  bool _running = false;
  bool _paused = false;
  bool _gameOverFired = false;

  bool get isRunning => _running && !_gameOverFired && !_paused;
  bool get isAiming => _phase == _BallPhase.idle && !_gameOverFired && !_paused;
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
    _vx = 0;
    _vy = 0;
    _ballSpin = 0;
    _phase = _BallPhase.idle;
    _dragging = false;
  }

  void _randomizeHoop() {
    _hoopX = SunsetHoopsConfig.hoopXMin +
        _random.nextDouble() * (SunsetHoopsConfig.hoopXMax - SunsetHoopsConfig.hoopXMin);
    _hoopY = SunsetHoopsConfig.hoopYMin +
        _random.nextDouble() * (SunsetHoopsConfig.hoopYMax - SunsetHoopsConfig.hoopYMin);
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
    if (!isAiming) return;
    final dx = screenPos.dx - _ballX;
    final dy = screenPos.dy - _ballY;
    final grabRadius = SunsetHoopsConfig.ballRadius * 2.4;
    if (dx * dx + dy * dy > grabRadius * grabRadius) return;
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
    _launch();
  }

  void onDragCancel() {
    _dragging = false;
  }

  void _launch() {
    final delta = _dragCurrent - _dragStart;
    final distance = delta.distance;
    if (distance < SunsetHoopsConfig.minDragDistance) return;

    final clamped = math.min(distance, SunsetHoopsConfig.maxDragDistance);
    final power = clamped * SunsetHoopsConfig.launchPowerMultiplier;
    final dir = delta / distance;

    _vx = dir.dx * power;
    // A pure horizontal or downward swipe still needs to leave the ground
    // — floor out how flat the shot can be.
    _vy = math.min(dir.dy * power, -power * 0.35);

    _phase = _BallPhase.flying;
    _scoredThisFlight = false;
    _bankedThisFlight = false;
    _throughRimBand = false;
    _ballSpin = (delta.dx / clamped) * 6;
    _trail.clear();
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
    if (_netSwingVel != 0 || _netSwing != 0) {
      _netSwingVel -= _netSwing * 40 * dt;
      _netSwingVel -= _netSwingVel * SunsetHoopsConfig.netSwingDecay * dt;
      _netSwing += _netSwingVel * dt;
    }

    if (!_running || _paused) return;
    if (_phase != _BallPhase.flying) return;

    _vy += SunsetHoopsConfig.gravity * dt;
    _vx *= SunsetHoopsConfig.airDrag;
    _ballX += _vx * dt;
    _ballY += _vy * dt;
    _ballRotation += _ballSpin * dt;

    _trail.add(Offset(_ballX, _ballY));
    if (_trail.length > 16) _trail.removeAt(0);

    _checkBackboard();
    _checkRim();

    final offBottom = _ballY > size.y + 60;
    final offSide = _ballX < -60 || _ballX > size.x + 60;
    if (offBottom || offSide) {
      _resolveMiss();
    }
  }

  void _checkBackboard() {
    if (_bankedThisFlight) return;
    final bx = size.x * _hoopX;
    final by = size.y * _hoopY - SunsetHoopsConfig.backboardHeight * 0.15;
    final boardLeft = bx - SunsetHoopsConfig.backboardWidth / 2;
    final boardRight = bx + SunsetHoopsConfig.backboardWidth / 2;
    final boardTop = by - SunsetHoopsConfig.backboardHeight / 2;
    final boardBottom = by + SunsetHoopsConfig.backboardHeight / 2;

    if (_vy < 0 &&
        _ballX > boardLeft &&
        _ballX < boardRight &&
        _ballY > boardTop &&
        _ballY < boardBottom) {
      _vx = -_vx * 0.55;
      _vy = _vy.abs() * 0.4;
      _bankedThisFlight = true;
      _shake(0.08);
      _spawnBurst(_ballX, _ballY, Colors.white, count: 6);
    }
  }

  void _checkRim() {
    if (_scoredThisFlight || _vy <= 0) return;
    final rx = size.x * _hoopX;
    final ry = size.y * _hoopY;
    final halfRim = SunsetHoopsConfig.rimWidth / 2;

    final withinBand = (_ballY - ry).abs() < SunsetHoopsConfig.rimThickness;
    if (!withinBand) return;

    final withinX = (_ballX - rx).abs() < halfRim * 0.62;
    if (withinX) {
      _resolveMake(rx, ry);
    } else if (!_throughRimBand && (_ballX - rx).abs() < halfRim) {
      // Clipped the rim — knock the shot off course rather than a clean pass.
      _throughRimBand = true;
      _vx += (_ballX - rx).sign * 60;
      _vy *= 0.8;
      _shake(0.06);
    }
  }

  void _resolveMake(double rimX, double rimY) {
    _scoredThisFlight = true;
    _phase = _BallPhase.settling;
    _netSwingVel += 3.2;
    _shake(SunsetHoopsConfig.crashShakeDuration * 0.6);

    final points = SunsetHoopsConfig.baseScore + (_bankedThisFlight ? SunsetHoopsConfig.backboardBankBonus : 0);
    _spawnBurst(rimX, rimY, SunsetHoopsConfig.gold, count: 22);
    _spawnFloatingText(rimX, rimY, _bankedThisFlight ? 'BANK SHOT! +$points' : 'SWISH! +$points', SunsetHoopsConfig.gold);

    onShotResolved(made: true, points: points, banked: _bankedThisFlight);

    _randomizeHoop();
    _resetBallToShooter();
  }

  void _resolveMiss() {
    if (_phase != _BallPhase.flying) return;
    _phase = _BallPhase.settling;
    _misses++;
    _shake(SunsetHoopsConfig.crashShakeDuration);
    _spawnBurst(_ballX.clamp(0, size.x), math.min(_ballY, size.y - 20), SunsetHoopsConfig.coral, count: 10);

    onShotResolved(made: false, points: 0, banked: false);

    if (_misses >= SunsetHoopsConfig.maxMisses) {
      _gameOverFired = true;
      _running = false;
      onGameOver();
    } else {
      _resetBallToShooter();
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
      _particles.add(_Particle.burst(x: x, y: y, color: color, random: _random, speed: 170, life: 0.55, size: 4.5));
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color) {
    _floatingTexts.add(_FloatingText(x: x, y: y, text: text, color: color, life: 1.0, maxLife: 1.0));
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
        (_random.nextDouble() - 0.5) * SunsetHoopsConfig.crashShakeMagnitude * p,
        (_random.nextDouble() - 0.5) * SunsetHoopsConfig.crashShakeMagnitude * p,
      );
    }

    _renderSky(canvas, w, h);
    _renderCourt(canvas, w, h);
    _renderHoop(canvas, w, h);

    if (_dragging) _renderAimGuide(canvas);
    _renderTrail(canvas);
    _renderBall(canvas);

    _renderParticles(canvas);
    _renderFloatingTexts(canvas);

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
          colors: [SunsetHoopsConfig.skyTop, SunsetHoopsConfig.skyMid, SunsetHoopsConfig.skyBottom],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.16), w * 0.12, Paint()..color = SunsetHoopsConfig.sunGlow.withValues(alpha: 0.85));
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
    canvas.drawArc(Rect.fromCenter(center: Offset(w * _hoopX, h * 0.72), width: w * 0.5, height: w * 0.28), 0, math.pi, false, line);
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
    canvas.drawRect(board, Paint()..color = SunsetHoopsConfig.backboard.withValues(alpha: 0.92));
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
    canvas.drawLine(Offset(rx - SunsetHoopsConfig.rimWidth / 2, ry), Offset(rx + SunsetHoopsConfig.rimWidth / 2, ry), rimPaint);

    // Net — a handful of swaying lines from rim to a pinched bottom point.
    final netPaint = Paint()
      ..color = SunsetHoopsConfig.netColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.6;
    const strands = 7;
    final netBottomY = ry + 30;
    for (var i = 0; i < strands; i++) {
      final t = i / (strands - 1);
      final topX = rx - SunsetHoopsConfig.rimWidth / 2 + SunsetHoopsConfig.rimWidth * t;
      final sway = math.sin(_netSwing + t * math.pi) * 5;
      canvas.drawLine(Offset(topX, ry + 2), Offset(rx + sway + _netSwing * 4, netBottomY), netPaint);
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

    for (var i = 0; i < 22; i++) {
      dvy += SunsetHoopsConfig.gravity * 0.03;
      x += vx * 0.03;
      y += dvy * 0.03;
      if (y > size.y) break;
      if (i % 2 == 0) {
        canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = color.withValues(alpha: 0.55 * (1 - i / 22)));
      }
    }

    canvas.drawCircle(_dragCurrent, 18 + fraction * 8, Paint()..color = color.withValues(alpha: 0.14));
  }

  void _renderTrail(Canvas canvas) {
    for (var i = 0; i < _trail.length; i++) {
      final a = (i / _trail.length) * 0.3;
      canvas.drawCircle(_trail[i], SunsetHoopsConfig.ballRadius * 0.3, Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  void _renderBall(Canvas canvas) {
    final pos = Offset(_ballX, _ballY);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_ballX, size.y * 0.985), width: SunsetHoopsConfig.ballRadius * 1.6, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(_ballRotation);

    canvas.drawCircle(Offset.zero, SunsetHoopsConfig.ballRadius, Paint()..color = SunsetHoopsConfig.ballBody);
    final linePaint = Paint()
      ..color = SunsetHoopsConfig.ballLine
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, SunsetHoopsConfig.ballRadius, linePaint);
    canvas.drawLine(Offset(-SunsetHoopsConfig.ballRadius, 0), Offset(SunsetHoopsConfig.ballRadius, 0), linePaint);
    canvas.drawLine(Offset(0, -SunsetHoopsConfig.ballRadius), Offset(0, SunsetHoopsConfig.ballRadius), linePaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: SunsetHoopsConfig.ballRadius),
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
      canvas.drawCircle(Offset(p.x, p.y), p.size * alpha, Paint()..color = p.color.withValues(alpha: alpha));
    }
  }

  void _renderFloatingTexts(Canvas canvas) {
    for (final t in _floatingTexts) {
      final alpha = (t.life / t.maxLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(text: t.text, style: TextStyle(color: t.color.withValues(alpha: alpha), fontWeight: FontWeight.w900, fontSize: 15)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(t.x - tp.width / 2, t.y - tp.height / 2));
    }
  }
}

class _FloatingText {
  _FloatingText({required this.x, required this.y, required this.text, required this.color, required this.life, required this.maxLife});
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