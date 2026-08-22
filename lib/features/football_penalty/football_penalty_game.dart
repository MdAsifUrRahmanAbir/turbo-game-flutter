import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'football_penalty_config.dart';
import 'football_penalty_state.dart';

class FootballPenaltyGame extends FlameGame with KeyboardEvents {
  FootballPenaltyGame({required this.onHudChanged, required this.onShotResult});

  final void Function(int score, int shots, int goals, int streak, PenaltyResult result)
  onHudChanged;
  final void Function(PenaltyResult result, int points) onShotResult;

  final math.Random _random = math.Random(12);
  final List<_Spark> _sparks = [];
  final List<_BallTrail> _trail = [];
  bool _aiming = false;
  bool _busy = false;
  bool _paused = false;
  bool _ended = false;
  double _aimX = 0.5;
  double _aimY = 0.35;
  double _power = 0.72;
  double _ballX = 0.5;
  double _ballY = FootballPenaltyConfig.ballStartY;
  double _ballScale = 1;
  double _shotT = 0;
  double _pauseTimer = 0;
  double _keeperX = 0.5;
  double _keeperTargetX = 0.5;
  double _keeperT = 0;
  double _shake = 0;
  int _score = 0;
  int _shots = 0;
  int _goals = 0;
  int _streak = 0;
  PenaltyResult _result = PenaltyResult.none;

  bool get isBusy => _busy;
  bool get isPaused => _paused;
  bool get isEnded => _ended;
  bool get isAiming => _aiming;
  double get power => _power;
  double get aimX => _aimX;
  double get aimY => _aimY;

  @override
  Color backgroundColor() => FootballPenaltyConfig.navy;

  @override
  Future<void> onLoad() async {}

  void reset() {
    _aiming = false;
    _busy = false;
    _paused = false;
    _ended = false;
    _aimX = 0.5;
    _aimY = 0.35;
    _power = 0.72;
    _ballX = 0.5;
    _ballY = FootballPenaltyConfig.ballStartY;
    _keeperX = 0.5;
    _keeperTargetX = 0.5;
    _score = 0;
    _shots = 0;
    _goals = 0;
    _streak = 0;
    _result = PenaltyResult.none;
    _sparks.clear();
    _trail.clear();
    _shake = 0;
  }

  void pauseGame() => _paused = true;
  void resumeGame() => _paused = false;

  void beginAim() {
    if (_busy || _ended || _paused) return;
    _aiming = true;
  }

  void updateAim(Offset localPosition) {
    if (!_aiming || _busy || size.x <= 0 || size.y <= 0) return;
    _aimX = (localPosition.dx / size.x).clamp(0.08, 0.92);
    _aimY = (localPosition.dy / size.y).clamp(0.17, 0.53);
    final dx = (_aimX - 0.5).abs() / FootballPenaltyConfig.maxAimOffset;
    final height = (FootballPenaltyConfig.ballStartY - _aimY).clamp(0.1, 0.7);
    _power = (0.45 + dx * 0.22 + height * 0.6).clamp(
      FootballPenaltyConfig.minShotPower,
      FootballPenaltyConfig.maxShotPower,
    );
  }

  void releaseShot() {
    if (!_aiming || _busy || _ended || _paused) return;
    _aiming = false;
    _busy = true;
    _shotT = 0;
    _keeperT = 0;
    _keeperTargetX = _random.nextDouble() * 0.56 + 0.22;
    _result = PenaltyResult.none;
  }

  void shootAt(Offset point) {
    beginAim();
    updateAim(point);
    releaseShot();
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent || _busy || _ended || _paused) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      releaseShot();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _aimX = (_aimX - 0.05).clamp(0.08, 0.92);
      _aiming = true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _aimX = (_aimX + 0.05).clamp(0.08, 0.92);
      _aiming = true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _aimY = (_aimY - 0.04).clamp(0.17, 0.53);
      _aiming = true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _aimY = (_aimY + 0.04).clamp(0.17, 0.53);
      _aiming = true;
    }
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateSparks(dt);
    for (final trail in _trail) trail.update(dt);
    _trail.removeWhere((trail) => trail.life <= 0);
    _shake = math.max(0, _shake - dt);
    if (_paused || _ended) return;

    if (_busy) {
      _shotT += dt / FootballPenaltyConfig.shotDuration;
      _keeperT += dt / FootballPenaltyConfig.keeperDiveDuration;
      final t = Curves.easeOut.transform(_shotT.clamp(0.0, 1.0));
      _ballX = 0.5 + (_aimX - 0.5) * t;
      _ballY = FootballPenaltyConfig.ballStartY + (_aimY - FootballPenaltyConfig.ballStartY) * t;
      _ballScale = 1 - t * 0.63;
      _trail.add(_BallTrail(_ballX, _ballY, FootballPenaltyConfig.cyan));
      _keeperX += (_keeperTargetX - _keeperX) * math.min(1, dt * 6);
      if (_shotT >= 1) {
        _finishShot();
      }
    } else if (_pauseTimer > 0) {
      _pauseTimer -= dt;
      if (_pauseTimer <= 0 && _shots < FootballPenaltyConfig.totalShots) {
        _ballX = 0.5;
        _ballY = FootballPenaltyConfig.ballStartY;
        _result = PenaltyResult.none;
        _notify();
      }
    }
  }

  void _finishShot() {
    _busy = false;
    _shots++;
    final keeperReach = 0.105 + (1 - _power) * 0.04;
    final keeperDistance = (_aimX - _keeperTargetX).abs();
    final insideGoal = _aimX > FootballPenaltyConfig.goalLeft + 0.025 &&
        _aimX < FootballPenaltyConfig.goalRight - 0.025 &&
        _aimY > FootballPenaltyConfig.goalTop + 0.025 &&
        _aimY < FootballPenaltyConfig.goalBottom - 0.025;
    final saved = insideGoal && keeperDistance < keeperReach;
    final goal = insideGoal && !saved;
    if (goal) {
      _result = PenaltyResult.goal;
      _goals++;
      _streak++;
      final cornerDistance = math.min(
        (_aimX - FootballPenaltyConfig.goalLeft).abs(),
        (_aimX - FootballPenaltyConfig.goalRight).abs(),
      );
      final topBin = _aimY < FootballPenaltyConfig.goalTop + .085;
      final precision = cornerDistance < .10 && topBin;
      final points = FootballPenaltyConfig.baseGoalPoints +
          (_streak - 1) * FootballPenaltyConfig.streakBonus +
          (_power * 40).round() +
          (precision ? FootballPenaltyConfig.perfectBonus : FootballPenaltyConfig.cornerBonus);
      _score += points;
      _spawnBurst(_ballX, _ballY, precision ? FootballPenaltyConfig.gold : FootballPenaltyConfig.lime, precision ? 38 : 26);
      _shake = FootballPenaltyConfig.cameraShakeDuration;
      onShotResult(_result, points);
    } else if (saved) {
      _result = PenaltyResult.saved;
      _streak = 0;
      _spawnBurst(_keeperX, FootballPenaltyConfig.keeperY, FootballPenaltyConfig.coral, 20);
      _shake = FootballPenaltyConfig.cameraShakeDuration * .7;
      onShotResult(_result, 0);
    } else {
      _result = PenaltyResult.miss;
      _streak = 0;
      _spawnBurst(_ballX, _ballY, FootballPenaltyConfig.gold, 14);
      onShotResult(_result, 0);
    }
    _notify();
    if (_shots >= FootballPenaltyConfig.totalShots) {
      _ended = true;
    } else {
      _pauseTimer = FootballPenaltyConfig.postShotPause;
    }
  }

  void _notify() => onHudChanged(_score, _shots, _goals, _streak, _result);

  void _spawnBurst(double x, double y, Color color, int count) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 0.08 + _random.nextDouble() * 0.2;
      _sparks.add(_Spark(x, y, math.cos(angle) * speed, math.sin(angle) * speed, color));
    }
  }

  void _updateSparks(double dt) {
    for (final spark in _sparks) spark.update(dt);
    _sparks.removeWhere((spark) => spark.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x, h = size.y;
    if (w <= 0 || h <= 0) return;
    if (_shake > 0) {
      final amount = (_shake / FootballPenaltyConfig.cameraShakeDuration) * FootballPenaltyConfig.cameraShakeMagnitude;
      canvas.save();
      canvas.translate((_random.nextDouble() - .5) * amount, (_random.nextDouble() - .5) * amount);
    }
    _drawStadium(canvas, w, h);
    _drawGoal(canvas, w, h);
    _drawKeeper(canvas, w, h);
    if (_aiming && !_busy) _drawAim(canvas, w, h);
    _drawBall(canvas, w, h);
    _drawTrail(canvas, w, h);
    _drawSparks(canvas, w, h);
    if (_shake > 0) canvas.restore();
    if (_result != PenaltyResult.none && !_busy) _drawResultGlow(canvas, w, h);
  }

  Offset _p(double x, double y, double w, double h) => Offset(x * w, y * h);

  void _drawStadium(Canvas c, double w, double h) {
    c.drawRect(Offset.zero & Size(w, h), Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [FootballPenaltyConfig.night, FootballPenaltyConfig.navy],
    ).createShader(Offset.zero & Size(w, h)));
    final crowd = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (var i = 0; i < 34; i++) {
      final x = (i * 0.071 + 0.02) % 1;
      c.drawCircle(_p(x, 0.14 + (i % 3) * 0.018, w, h), 2.1, crowd);
    }
    final grass = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [FootballPenaltyConfig.pitch, FootballPenaltyConfig.pitchDark],
    ).createShader(Rect.fromLTWH(0, h * .43, w, h * .57));
    c.drawRect(Rect.fromLTWH(0, h * .43, w, h * .57), grass);
    for (var i = 0; i < 8; i++) {
      c.drawRect(Rect.fromLTWH(i * w / 8, h * .43, w / 16, h * .57), Paint()..color = Colors.white.withValues(alpha: .035));
    }
    final line = Paint()..color = Colors.white.withValues(alpha: .72)..style = PaintingStyle.stroke..strokeWidth = 2;
    c.drawArc(Rect.fromCenter(center: _p(.5, .77, w, h), width: w * .42, height: w * .25), math.pi, math.pi, false, line);
    c.drawLine(_p(.08, .94, w, h), _p(.92, .94, w, h), line);
  }

  void _drawGoal(Canvas c, double w, double h) {
    final l = FootballPenaltyConfig.goalLeft * w, r = FootballPenaltyConfig.goalRight * w;
    final t = FootballPenaltyConfig.goalTop * h, b = FootballPenaltyConfig.goalBottom * h;
    final net = Paint()..color = Colors.white.withValues(alpha: .16)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var i = 0; i <= 8; i++) c.drawLine(Offset(l + (r-l)*i/8, t), Offset(l + (r-l)*i/8, b), net);
    for (var i = 0; i <= 5; i++) c.drawLine(Offset(l, t + (b-t)*i/5), Offset(r, t + (b-t)*i/5), net);
    final frame = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    c.drawLine(Offset(l, b), Offset(l, t), frame); c.drawLine(Offset(r, b), Offset(r, t), frame); c.drawLine(Offset(l, t), Offset(r, t), frame);
  }

  void _drawKeeper(Canvas c, double w, double h) {
    final x = _keeperX * w, y = FootballPenaltyConfig.keeperY * h;
    final dive = _busy ? math.sin((_keeperT.clamp(0.0, 1.0)) * math.pi) : 0.0;
    c.save(); c.translate(x, y); c.rotate(((_keeperTargetX - .5) * dive) * .8);
    final shadow = Paint()..color = Colors.black.withValues(alpha: .25); c.drawOval(Rect.fromCenter(center: Offset(0, 34), width: 72, height: 14), shadow);
    final body = Paint()..color = FootballPenaltyConfig.keeper; c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -2, 40, 48), const Radius.circular(14)), body);
    c.drawCircle(const Offset(0, -18), 14, Paint()..color = const Color(0xFFFFC49B));
    final glove = Paint()..color = Colors.white; c.drawCircle(Offset(-27 - dive*26, 3), 7, glove); c.drawCircle(Offset(27 + dive*26, 3), 7, glove);
    c.restore();
  }

  void _drawBall(Canvas c, double w, double h) {
    final pos = _p(_ballX, _ballY, w, h); final radius = 10 * _ballScale;
    c.drawCircle(pos + const Offset(2, 4), radius + 2, Paint()..color = Colors.black.withValues(alpha: .22));
    c.drawCircle(pos, radius, Paint()..color = Colors.white);
    c.drawCircle(pos, radius * .32, Paint()..color = FootballPenaltyConfig.navy);
    for (var i = 0; i < 5; i++) { final a = i * math.pi * 2 / 5; c.drawCircle(pos + Offset(math.cos(a)*radius*.62, math.sin(a)*radius*.62), radius*.12, Paint()..color = FootballPenaltyConfig.navy); }
  }

  void _drawTrail(Canvas c, double w, double h) {
    for (final trail in _trail) {
      c.drawCircle(_p(trail.x, trail.y, w, h), 7 * trail.life, Paint()..color = trail.color.withValues(alpha: trail.life * .25));
    }
  }

  void _drawAim(Canvas c, double w, double h) {
    final start = _p(.5, FootballPenaltyConfig.ballStartY, w, h), end = _p(_aimX, _aimY, w, h);
    final line = Paint()..color = FootballPenaltyConfig.lime.withValues(alpha: .65)..strokeWidth = 3..style = PaintingStyle.stroke;
    c.drawLine(start, end, line);
    c.drawCircle(end, 17 + _power * 5, Paint()..color = FootballPenaltyConfig.lime.withValues(alpha: .12)..style = PaintingStyle.fill);
    c.drawCircle(end, 10, Paint()..color = FootballPenaltyConfig.lime..style = PaintingStyle.stroke..strokeWidth = 2);
    c.drawLine(end + const Offset(-7, 0), end + const Offset(7, 0), Paint()..color = Colors.white.withValues(alpha: .7)..strokeWidth = 1.5);
    c.drawLine(end + const Offset(0, -7), end + const Offset(0, 7), Paint()..color = Colors.white.withValues(alpha: .7)..strokeWidth = 1.5);
  }

  void _drawSparks(Canvas c, double w, double h) { for (final s in _sparks) c.drawCircle(_p(s.x, s.y, w, h), s.size, Paint()..color = s.color.withValues(alpha: s.life.clamp(0.0, 1.0))); }
  void _drawResultGlow(Canvas c, double w, double h) { final color = _result == PenaltyResult.goal ? FootballPenaltyConfig.lime : FootballPenaltyConfig.coral; c.drawCircle(_p(_ballX, _ballY, w, h), 34, Paint()..color = color.withValues(alpha: .08)); }
}

class _BallTrail {
  _BallTrail(this.x, this.y, this.color);
  final double x;
  final double y;
  final Color color;
  double life = 1;
  void update(double dt) => life -= dt * 3.2;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color);
  double x, y, vx, vy, life = 1, size = 2.5;
  final Color color;
  void update(double dt) { x += vx * dt; y += vy * dt; vy += .25 * dt; life -= dt * 1.8; size *= .99; }
}
