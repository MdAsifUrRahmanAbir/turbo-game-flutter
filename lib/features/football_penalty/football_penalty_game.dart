import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'football_penalty_config.dart';
import 'football_penalty_state.dart';

class FootballPenaltyGame extends FlameGame with KeyboardEvents {
  FootballPenaltyGame({required this.onHudChanged, required this.onShotResult});

  final void Function({
  required int score,
  required int shots,
  required int goals,
  required int streak,
  required int round,
  required PenaltyResult result,
  required bool ended,
  }) onHudChanged;
  final void Function(PenaltyResult result, int points, String commentary) onShotResult;

  final math.Random _random = math.Random();
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
  double _diveDuration = FootballPenaltyConfig.keeperDiveDuration;
  double _shake = 0;
  int _score = 0;
  int _shots = 0;
  int _goals = 0;
  int _streak = 0;
  int _round = 1;
  PenaltyResult _result = PenaltyResult.none;

  // General-purpose clock used for idle character animation (breathing,
  // pull-boundary pulse, etc). Only ticks while gameplay is actually live.
  double _time = 0;

  // Penalty taker animation: 0 = mid run-up/kick sequence just started,
  // 1 = finished and back to an idle ready stance behind the ball. Reset
  // to 0 the instant a shot is struck so the character actually shows the
  // run-up + kick rather than the ball just teleporting off screen.
  double _strikerT = 1;

  // Goalkeeper "tell": picked fresh before each shot and revealed as a slow
  // idle sway while the player aims. Reading it and shooting the other way
  // is the core skill loop — see [releaseShot].
  double _keeperLean = 0;
  double _keeperIdleT = 0;

  // Lateral drag speed sampled during aiming, purely to bend the ball's
  // rendered flight path — cosmetic only, never changes where it lands.
  double _prevAimX = 0.5;
  double _dragVelX = 0;
  double _curve = 0;

  // The shot's full outcome is decided the instant it's released (aim +
  // keeper target are both fixed then). Precomputing it lets the flight
  // animation — including slow-mo on the way in — play towards a known
  // ending instead of guessing.
  PenaltyResult _pendingResult = PenaltyResult.none;
  int _pendingPoints = 0;
  String _pendingCommentary = '';
  bool _pendingPrecision = false;
  bool _pendingNearMiss = false;

  double _impactPunch = 0;

  // Recomputed every frame from the actual canvas width so the hand-drawn
  // characters scale sensibly across phones, tablets and desktop windows
  // instead of staying a fixed pixel size everywhere.
  double _worldScale = 1;

  bool get isBusy => _busy;
  bool get isPaused => _paused;
  bool get isEnded => _ended;
  bool get isAiming => _aiming;
  double get power => _power;
  double get aimX => _aimX;
  double get aimY => _aimY;
  int get round => _round;

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
    _keeperT = 0;
    _score = 0;
    _shots = 0;
    _goals = 0;
    _streak = 0;
    _round = 1;
    _result = PenaltyResult.none;
    _sparks.clear();
    _trail.clear();
    _shake = 0;
    _impactPunch = 0;
    _dragVelX = 0;
    _prevAimX = 0.5;
    _keeperIdleT = 0;
    _keeperLean = _pickLean();
    _strikerT = 1;
    _time = 0;
  }

  void pauseGame() => _paused = true;
  void resumeGame() => _paused = false;

  void beginAim() {
    if (_busy || _ended || _paused) return;
    _aiming = true;
    _prevAimX = _aimX;
    _dragVelX = 0;
  }

  void updateAim(Offset localPosition) {
    if (!_aiming || _busy || size.x <= 0 || size.y <= 0) return;
    _aimX = (localPosition.dx / size.x).clamp(0.08, 0.92);
    _aimY = (localPosition.dy / size.y).clamp(0.17, 0.53);
    _dragVelX = (_dragVelX * 0.6 + (_aimX - _prevAimX) * 8).clamp(-1.0, 1.0);
    _prevAimX = _aimX;
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
    _strikerT = 0;
    _curve = _dragVelX * FootballPenaltyConfig.curveStrength;

    final reliability = (FootballPenaltyConfig.keeperReadBase -
        (_round - 1) * FootballPenaltyConfig.keeperReadPerRound)
        .clamp(FootballPenaltyConfig.keeperReadMin, FootballPenaltyConfig.keeperReadBase);
    final readsLean = _keeperLean != 0 && _random.nextDouble() < reliability;
    if (readsLean) {
      final side = _keeperLean > 0 ? 1 : -1;
      _keeperTargetX = (0.5 + side * (0.14 + _random.nextDouble() * 0.20)).clamp(0.22, 0.78);
    } else {
      _keeperTargetX = _random.nextDouble() * 0.56 + 0.22;
    }
    _diveDuration = (FootballPenaltyConfig.keeperDiveDuration -
        (_round - 1) * FootballPenaltyConfig.keeperDiveDurationPerRound)
        .clamp(FootballPenaltyConfig.keeperDiveDurationMin, FootballPenaltyConfig.keeperDiveDuration);

    _resolveShot();
    _result = PenaltyResult.none;
  }

  void shootAt(Offset point) {
    beginAim();
    updateAim(point);
    releaseShot();
  }

  double _pickLean() {
    if (_random.nextDouble() > 0.7) return 0;
    return _random.nextBool() ? 1.0 : -1.0;
  }

  T _pick<T>(List<T> options) => options[_random.nextInt(options.length)];

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
    for (final trail in _trail) {
      trail.update(dt);
    }
    _trail.removeWhere((trail) => trail.life <= 0);
    _shake = math.max(0, _shake - dt);
    _impactPunch = math.max(0, _impactPunch - dt * FootballPenaltyConfig.impactPunchDecay);
    if (_paused || _ended) return;
    _time += dt;
    if (!_busy) _keeperIdleT = math.min(_keeperIdleT + dt, 1.2);

    if (_busy) {
      final dramatic = _pendingResult == PenaltyResult.goal || _pendingResult == PenaltyResult.saved;
      final timeScale =
      (dramatic && _shotT > FootballPenaltyConfig.slowMoThreshold) ? FootballPenaltyConfig.slowMoScale : 1.0;
      _shotT += (dt * timeScale) / FootballPenaltyConfig.shotDuration;
      _keeperT += (dt * timeScale) / _diveDuration;
      // The run-up/kick plays at real speed regardless of the ball's
      // slow-mo, the same way a broadcast replay keeps the kicker's
      // motion snappy even while the shot itself hangs in the air.
      if (_strikerT < 1) {
        _strikerT = math.min(1.0, _strikerT + dt / FootballPenaltyConfig.strikerCycleDuration);
      }
      final t = Curves.easeOut.transform(_shotT.clamp(0.0, 1.0));
      final curveOffset = math.sin(t * math.pi) * _curve * 0.06;
      _ballX = 0.5 + (_aimX - 0.5) * t + curveOffset;
      _ballY = FootballPenaltyConfig.ballStartY + (_aimY - FootballPenaltyConfig.ballStartY) * t;
      _ballScale = 1 - t * 0.63;
      _trail.add(_BallTrail(_ballX, _ballY, FootballPenaltyConfig.cyan));
      _keeperX += (_keeperTargetX - _keeperX) * math.min(1, dt * 6);
      if (_shotT >= 1) {
        _finishShot();
      }
    } else if (_pauseTimer > 0) {
      _pauseTimer -= dt;
      if (_pauseTimer <= 0 && !_ended) {
        _ballX = 0.5;
        _ballY = FootballPenaltyConfig.ballStartY;
        _keeperX = 0.5;
        _keeperT = 0;
        _result = PenaltyResult.none;
        _keeperLean = _pickLean();
        _keeperIdleT = 0;
        _dragVelX = 0;
        _prevAimX = 0.5;
        _strikerT = 1;
        _notify();
      }
    }
  }

  void _resolveShot() {
    final keeperReach = (0.105 +
        (1 - _power) * 0.04 +
        (_round - 1) * FootballPenaltyConfig.keeperReachPerRound)
        .clamp(0.08, FootballPenaltyConfig.keeperReachMax);
    final keeperDistance = (_aimX - _keeperTargetX).abs();
    final insideGoal = _aimX > FootballPenaltyConfig.goalLeft + 0.025 &&
        _aimX < FootballPenaltyConfig.goalRight - 0.025 &&
        _aimY > FootballPenaltyConfig.goalTop + 0.025 &&
        _aimY < FootballPenaltyConfig.goalBottom - 0.025;
    final saved = insideGoal && keeperDistance < keeperReach;
    final goal = insideGoal && !saved;

    if (goal) {
      _pendingResult = PenaltyResult.goal;
      final cornerDistance = math.min(
        (_aimX - FootballPenaltyConfig.goalLeft).abs(),
        (_aimX - FootballPenaltyConfig.goalRight).abs(),
      );
      final topBin = _aimY < FootballPenaltyConfig.goalTop + .085;
      _pendingPrecision = cornerDistance < .10 && topBin;
      final nextStreak = _streak + 1;
      _pendingPoints = FootballPenaltyConfig.baseGoalPoints +
          (nextStreak - 1) * FootballPenaltyConfig.streakBonus +
          (_power * 40).round() +
          (_pendingPrecision ? FootballPenaltyConfig.perfectBonus : FootballPenaltyConfig.cornerBonus);
      _pendingCommentary = _pendingPrecision ? _pick(_topBinLines) : _pick(_goalLines);
    } else if (saved) {
      _pendingResult = PenaltyResult.saved;
      _pendingPoints = 0;
      _pendingCommentary = _pick(_saveLines);
    } else {
      _pendingResult = PenaltyResult.miss;
      _pendingPoints = 0;
      final nearTop = _aimY < FootballPenaltyConfig.goalTop + FootballPenaltyConfig.nearMissBand &&
          _aimX > FootballPenaltyConfig.goalLeft &&
          _aimX < FootballPenaltyConfig.goalRight;
      final nearLeft = (_aimX - FootballPenaltyConfig.goalLeft).abs() < FootballPenaltyConfig.nearMissBand;
      final nearRight = (_aimX - FootballPenaltyConfig.goalRight).abs() < FootballPenaltyConfig.nearMissBand;
      if (nearTop) {
        _pendingCommentary = _pick(_crossbarLines);
        _pendingNearMiss = true;
      } else if (nearLeft || nearRight) {
        _pendingCommentary = _pick(_postLines);
        _pendingNearMiss = true;
      } else {
        _pendingCommentary = _pick(_wideLines);
        _pendingNearMiss = false;
      }
    }
  }

  void _finishShot() {
    _busy = false;
    _shots++;
    _result = _pendingResult;

    switch (_pendingResult) {
      case PenaltyResult.goal:
        _goals++;
        _streak++;
        _score += _pendingPoints;
        _spawnBurst(
          _ballX,
          _ballY,
          _pendingPrecision ? FootballPenaltyConfig.gold : FootballPenaltyConfig.lime,
          _pendingPrecision ? 38 : 26,
        );
        _shake = FootballPenaltyConfig.cameraShakeDuration;
        _impactPunch = 1.0;
        onShotResult(_result, _pendingPoints, _pendingCommentary);
      case PenaltyResult.saved:
        _streak = 0;
        _spawnBurst(_keeperX, FootballPenaltyConfig.keeperY, FootballPenaltyConfig.coral, 20);
        _shake = FootballPenaltyConfig.cameraShakeDuration * .7;
        _impactPunch = 0.7;
        onShotResult(_result, 0, _pendingCommentary);
      case PenaltyResult.miss:
        _streak = 0;
        final burstColor = _pendingNearMiss ? Colors.white : FootballPenaltyConfig.gold;
        _spawnBurst(_ballX, _ballY, burstColor, _pendingNearMiss ? 22 : 14);
        if (_pendingNearMiss) _shake = FootballPenaltyConfig.cameraShakeDuration * .5;
        onShotResult(_result, 0, _pendingCommentary);
      case PenaltyResult.none:
        break;
    }

    final roundOver = _shots >= FootballPenaltyConfig.totalShots;
    if (roundOver) {
      if (_goals >= FootballPenaltyConfig.advanceGoalsRequired) {
        _round++;
        _shots = 0;
        _goals = 0;
        _pauseTimer = FootballPenaltyConfig.postShotPause;
      } else {
        _ended = true;
      }
    } else {
      _pauseTimer = FootballPenaltyConfig.postShotPause;
    }
    _notify();
  }

  void _notify() => onHudChanged(
    score: _score,
    shots: _shots,
    goals: _goals,
    streak: _streak,
    round: _round,
    result: _result,
    ended: _ended,
  );

  void _spawnBurst(double x, double y, Color color, int count) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 0.08 + _random.nextDouble() * 0.2;
      _sparks.add(_Spark(x, y, math.cos(angle) * speed, math.sin(angle) * speed, color));
    }
  }

  void _updateSparks(double dt) {
    for (final spark in _sparks) {
      spark.update(dt);
    }
    _sparks.removeWhere((spark) => spark.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x, h = size.y;
    if (w <= 0 || h <= 0) return;
    _worldScale = (w / FootballPenaltyConfig.refWidth).clamp(0.75, 1.6);
    canvas.save();
    if (_shake > 0) {
      final amount = (_shake / FootballPenaltyConfig.cameraShakeDuration) * FootballPenaltyConfig.cameraShakeMagnitude;
      canvas.translate((_random.nextDouble() - .5) * amount, (_random.nextDouble() - .5) * amount);
    }
    if (_impactPunch > 0) {
      final zoom = 1 + _impactPunch * 0.05;
      final center = _p(_ballX, _ballY, w, h);
      canvas.translate(center.dx, center.dy);
      canvas.scale(zoom);
      canvas.translate(-center.dx, -center.dy);
    }
    _drawStadium(canvas, w, h);
    _drawGoal(canvas, w, h);
    _drawKeeper(canvas, w, h);
    if (_aiming && !_busy) _drawAim(canvas, w, h);
    _drawBall(canvas, w, h);
    _drawTrail(canvas, w, h);
    _drawStriker(canvas, w, h);
    _drawSparks(canvas, w, h);
    canvas.restore();
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

    // Floodlight glow washing down over the goalmouth — cheap but effective
    // depth/mood cue that a flat 2D scene otherwise lacks.
    final glowRect = Rect.fromLTWH(0, h * .16, w, h * .34);
    c.drawRect(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.1,
          colors: [FootballPenaltyConfig.sunGlow.withValues(alpha: .16), Colors.transparent],
        ).createShader(glowRect),
    );

    final grassTop = h * .43;
    final grassRect = Rect.fromLTWH(0, grassTop, w, h * .57);
    final grass = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [FootballPenaltyConfig.pitch, FootballPenaltyConfig.pitchDark],
    ).createShader(grassRect);
    c.drawRect(grassRect, grass);

    // Perspective mow stripes: narrow near the goal line, wide near the
    // camera, converging toward a vanishing point — a simple trick that
    // reads as a pitch receding into the distance rather than flat grass.
    const stripeCount = 8;
    final vanishX = w * .5;
    for (var i = 0; i < stripeCount; i++) {
      if (i.isOdd) continue;
      final t0 = i / stripeCount, t1 = (i + 1) / stripeCount;
      final topL = vanishX + (t0 - .5) * w * .18;
      final topR = vanishX + (t1 - .5) * w * .18;
      final botL = t0 * w;
      final botR = t1 * w;
      final stripe = Path()
        ..moveTo(topL, grassTop)
        ..lineTo(topR, grassTop)
        ..lineTo(botR, h)
        ..lineTo(botL, h)
        ..close();
      c.drawPath(stripe, Paint()..color = Colors.white.withValues(alpha: .035));
    }

    final line = Paint()..color = Colors.white.withValues(alpha: .72)..style = PaintingStyle.stroke..strokeWidth = 2;
    c.drawArc(Rect.fromCenter(center: _p(.5, .77, w, h), width: w * .42, height: w * .25), math.pi, math.pi, false, line);
    c.drawLine(_p(.08, .94, w, h), _p(.92, .94, w, h), line);
  }

  void _drawGoal(Canvas c, double w, double h) {
    final l = FootballPenaltyConfig.goalLeft * w, r = FootballPenaltyConfig.goalRight * w;
    final t = FootballPenaltyConfig.goalTop * h, b = FootballPenaltyConfig.goalBottom * h;
    final net = Paint()..color = Colors.white.withValues(alpha: .16)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var i = 0; i <= 8; i++) {
      c.drawLine(Offset(l + (r-l)*i/8, t), Offset(l + (r-l)*i/8, b), net);
    }
    for (var i = 0; i <= 5; i++) {
      c.drawLine(Offset(l, t + (b-t)*i/5), Offset(r, t + (b-t)*i/5), net);
    }
    // Soft post shadow drawn just behind/right of the bright frame gives
    // the posts a rounded, three-dimensional cross-section instead of a
    // flat white line.
    final postShadow = Paint()
      ..color = Colors.black.withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(l + 2, b), Offset(l + 2, t), postShadow);
    c.drawLine(Offset(r + 2, b), Offset(r + 2, t), postShadow);
    final frame = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    c.drawLine(Offset(l, b), Offset(l, t), frame); c.drawLine(Offset(r, b), Offset(r, t), frame); c.drawLine(Offset(l, t), Offset(r, t), frame);
  }

  void _drawKeeper(Canvas c, double w, double h) {
    final swayProgress = (_keeperIdleT / 0.6).clamp(0.0, 1.0);
    final sway = (!_busy && !_ended) ? _keeperLean * swayProgress * 0.05 : 0.0;
    final x = (_keeperX + sway) * w, y = FootballPenaltyConfig.keeperY * h;
    final diveT = _keeperT.clamp(0.0, 1.0);
    final dive = _busy ? math.sin(diveT * math.pi) : 0.0;
    final leanDir = (_keeperTargetX - .5).sign;
    final rotation = ((_keeperTargetX - .5) * dive + sway * 1.4) * .8;
    final scale = 1.55 * _worldScale;

    // Ground shadow — stretches sideways while diving for a grounded feel.
    final shadowW = (74 + dive * 60) * scale * .58;
    c.drawOval(
      Rect.fromCenter(center: Offset(x + leanDir * dive * 30 * scale, y + 36 * scale), width: shadowW, height: 13 * scale),
      Paint()..color = Colors.black.withValues(alpha: .28 * (1 - dive * .35)),
    );

    c.save();
    c.translate(x, y);
    c.rotate(rotation);
    c.scale(scale);

    final outline = Paint()
      ..color = FootballPenaltyConfig.navyDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // --- Legs & boots ------------------------------------------------------
    final legSpread = 7.0 + dive * 4;
    for (final side in [-1.0, 1.0]) {
      final legX = side * legSpread;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(legX, 30), width: 9, height: 22), const Radius.circular(4)),
        Paint()..color = FootballPenaltyConfig.keeperSkin,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(legX, 36), width: 10, height: 10), const Radius.circular(3)),
        Paint()..color = FootballPenaltyConfig.keeperSocks,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(legX, 43), width: 12, height: 7), const Radius.circular(3)),
        Paint()..color = FootballPenaltyConfig.keeperBoots,
      );
    }

    // --- Shorts --------------------------------------------------------------
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, 14, 32, 16), const Radius.circular(8)),
      Paint()..color = FootballPenaltyConfig.keeperShorts,
    );

    // --- Torso / jersey ---------------------------------------------------------
    final torso = RRect.fromRectAndRadius(const Rect.fromLTWH(-19, -14, 38, 34), const Radius.circular(14));
    c.drawRRect(torso, Paint()..color = FootballPenaltyConfig.keeper);
    c.drawRRect(torso, outline);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-19, 4, 38, 8), const Radius.circular(4)),
      Paint()..color = FootballPenaltyConfig.keeperJerseyDark.withValues(alpha: .55),
    );
    final numberPainter = TextPainter(
      text: const TextSpan(text: '1', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    numberPainter.paint(c, Offset(-numberPainter.width / 2, -8));

    // --- Arms & gloves (extend outward while diving) --------------------------
    final armSwing = dive * 30;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(side * 17, -8);
      final hand = Offset(side * (20 + armSwing), 3 - dive * 10);
      c.drawLine(shoulder, hand, Paint()..color = FootballPenaltyConfig.keeper..strokeWidth = 9..strokeCap = StrokeCap.round);
      c.drawCircle(hand, 8, Paint()..color = FootballPenaltyConfig.keeperGloves);
      c.drawCircle(hand, 8, outline);
    }

    // --- Head -------------------------------------------------------------------
    const headCenter = Offset(0, -26);
    c.drawCircle(headCenter, 12, Paint()..color = FootballPenaltyConfig.keeperSkin);
    c.drawCircle(headCenter, 12, outline);
    final hairPath = Path()
      ..moveTo(-12, -30)
      ..quadraticBezierTo(0, -42, 12, -30)
      ..quadraticBezierTo(9, -34, 0, -33)
      ..quadraticBezierTo(-9, -34, -12, -30)
      ..close();
    c.drawPath(hairPath, Paint()..color = FootballPenaltyConfig.keeperHair);
    // Eyes track the dive direction for a little personality.
    final gaze = leanDir * dive * 1.6;
    for (final side in [-1.0, 1.0]) {
      final eyeCenter = headCenter + Offset(side * 4.2, -1);
      c.drawCircle(eyeCenter, 2.6, Paint()..color = Colors.white);
      c.drawCircle(eyeCenter + Offset(gaze, 0), 1.3, Paint()..color = FootballPenaltyConfig.navyDeep);
    }
    final browPaint = Paint()
      ..color = FootballPenaltyConfig.navyDeep
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    c.drawLine(headCenter + const Offset(-6.5, -5.5), headCenter + const Offset(-1.5, -4.5), browPaint);
    c.drawLine(headCenter + const Offset(6.5, -5.5), headCenter + const Offset(1.5, -4.5), browPaint);
    c.drawOval(
      Rect.fromCenter(center: headCenter + const Offset(0, 5), width: dive > 0.15 ? 6 : 4, height: dive > 0.15 ? 4 : 2),
      Paint()..color = FootballPenaltyConfig.navyDeep.withValues(alpha: .8),
    );

    c.restore();
  }

  /// The player taking the kick: idles behind the ball while aiming, then
  /// runs up and swings through on release. Purely cosmetic — the shot's
  /// outcome is already locked in by [_resolveShot] — but it's the one
  /// thing the old scene was missing: showing *who* is taking the penalty.
  void _drawStriker(Canvas c, double w, double h) {
    final u = _strikerT.clamp(0.0, 1.0);
    final idle = !_busy && u >= 1.0;

    final runT = Curves.easeOut.transform((u / 0.5).clamp(0.0, 1.0));
    final baseY = idle
        ? FootballPenaltyConfig.strikerBaseY
        : FootballPenaltyConfig.strikerRunStartY +
        (FootballPenaltyConfig.strikerBaseY - FootballPenaltyConfig.strikerRunStartY) * runT;
    final idleBob = idle ? math.sin(_time * 2.4) * 0.004 : 0.0;
    final x = w * 0.5;
    final y = h * (baseY + idleBob);

    // Kick sub-phases: cock the leg back, whip it through ("contact"),
    // then hold a brief follow-through before settling back to idle.
    final backswing = ((u - 0.5) / 0.18).clamp(0.0, 1.0);
    final swing = ((u - 0.68) / 0.14).clamp(0.0, 1.0);
    final follow = ((u - 0.82) / 0.18).clamp(0.0, 1.0);
    final kickLegAngle = idle ? math.sin(_time * 2.4) * 0.03 : -backswing * 0.9 + swing * 1.6 - follow * 0.25;
    final lean = idle ? 0.0 : (swing * 0.22 - follow * 0.1);

    final scale = 1.85 * _worldScale;

    c.drawOval(
      Rect.fromCenter(center: Offset(x, y + 14 * scale), width: 29 * scale, height: 6 * scale),
      Paint()..color = Colors.black.withValues(alpha: .3),
    );

    c.save();
    c.translate(x, y);
    c.rotate(lean);
    c.scale(scale);

    final outline = Paint()
      ..color = FootballPenaltyConfig.navyDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // --- Planted (non-kicking) leg ------------------------------------------
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-11, 6, 8, 20), const Radius.circular(4)),
      Paint()..color = FootballPenaltyConfig.strikerSkin,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 22, 10, 8), const Radius.circular(3)),
      Paint()..color = FootballPenaltyConfig.strikerSocks,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-13, 28, 12, 6), const Radius.circular(3)),
      Paint()..color = FootballPenaltyConfig.strikerBoots,
    );

    // --- Kicking leg, rotated around the hip --------------------------------
    c.save();
    c.translate(4, 8);
    c.rotate(kickLegAngle);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4, 0, 8, 20), const Radius.circular(4)),
      Paint()..color = FootballPenaltyConfig.strikerSkin,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5, 16, 10, 8), const Radius.circular(3)),
      Paint()..color = FootballPenaltyConfig.strikerSocks,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 22, 14, 7), const Radius.circular(3)),
      Paint()..color = FootballPenaltyConfig.strikerBoots,
    );
    c.restore();

    // --- Shorts ---------------------------------------------------------------
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -4, 28, 14), const Radius.circular(7)),
      Paint()..color = FootballPenaltyConfig.strikerShorts,
    );

    // --- Torso / jersey ------------------------------------------------------------
    final torso = RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -30, 32, 30), const Radius.circular(12));
    c.drawRRect(torso, Paint()..color = FootballPenaltyConfig.strikerJersey);
    c.drawRRect(torso, outline);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -30, 32, 7), const Radius.circular(6)),
      Paint()..color = FootballPenaltyConfig.strikerJerseyDark,
    );

    // --- Arms swing opposite the kicking leg for balance -----------------------
    final armSwing = idle ? math.sin(_time * 2.4) * 4 : -kickLegAngle * 14;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(side * 14, -24);
      final hand = Offset(side * 18 - armSwing * side.sign, -8 + armSwing.abs() * .2);
      c.drawLine(
        shoulder,
        hand,
        Paint()
          ..color = FootballPenaltyConfig.strikerSkin
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }

    // --- Head ------------------------------------------------------------------
    const headCenter = Offset(0, -40);
    c.drawCircle(headCenter, 10, Paint()..color = FootballPenaltyConfig.strikerSkin);
    c.drawCircle(headCenter, 10, outline);
    final hairPath = Path()
      ..moveTo(-10, -44)
      ..quadraticBezierTo(0, -54, 10, -44)
      ..quadraticBezierTo(7, -47, 0, -46)
      ..quadraticBezierTo(-7, -47, -10, -44)
      ..close();
    c.drawPath(hairPath, Paint()..color = FootballPenaltyConfig.strikerHair);
    for (final side in [-1.0, 1.0]) {
      final eyeCenter = headCenter + Offset(side * 3.6, -1);
      c.drawCircle(eyeCenter, 2.1, Paint()..color = Colors.white);
      c.drawCircle(eyeCenter, 1.0, Paint()..color = FootballPenaltyConfig.navyDeep);
    }
    final browPaint = Paint()
      ..color = FootballPenaltyConfig.navyDeep
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    c.drawLine(headCenter + const Offset(-6, -5), headCenter + const Offset(-1.5, -4), browPaint);
    c.drawLine(headCenter + const Offset(6, -5), headCenter + const Offset(1.5, -4), browPaint);

    c.restore();
  }

  void _drawBall(Canvas c, double w, double h) {
    final pos = _p(_ballX, _ballY, w, h);
    final radius = FootballPenaltyConfig.ballRadius * _ballScale * _worldScale;

    // Cast shadow — squashes and fades as the ball rises and shrinks
    // toward the goal, reinforcing the sense of it lifting off the ground.
    c.drawOval(
      Rect.fromCenter(center: pos + Offset(0, radius * 0.9), width: radius * 2.1, height: radius * 0.55),
      Paint()..color = Colors.black.withValues(alpha: .28 * _ballScale),
    );

    final spin = (_ballX + _ballY) * 26 + _shotT * 16;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(spin);

    // Spherical shading via a radial gradient — this alone is what sells
    // a flat circle as a round, lit ball rather than a sticker.
    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: const [Colors.white, Color(0xFFE7E7EF), Color(0xFFB9BAC4)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    c.drawCircle(Offset.zero, radius, sphere);

    final panel = Paint()..color = FootballPenaltyConfig.navy;
    c.drawCircle(Offset.zero, radius * .34, panel);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final p = Offset(math.cos(a), math.sin(a)) * radius * .62;
      c.drawCircle(p, radius * .16, panel);
      c.drawLine(Offset.zero, p, Paint()..color = FootballPenaltyConfig.navy..strokeWidth = 1.6);
    }
    c.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.black.withValues(alpha: .12),
    );
    c.restore();
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

  void _drawSparks(Canvas c, double w, double h) { for (final s in _sparks) {
    c.drawCircle(_p(s.x, s.y, w, h), s.size, Paint()..color = s.color.withValues(alpha: s.life.clamp(0.0, 1.0)));
  } }
  void _drawResultGlow(Canvas c, double w, double h) { final color = _result == PenaltyResult.goal ? FootballPenaltyConfig.lime : FootballPenaltyConfig.coral; c.drawCircle(_p(_ballX, _ballY, w, h), 34, Paint()..color = color.withValues(alpha: .08)); }
}

const _goalLines = ['GOAL!', 'BURIED!', 'CLINICAL FINISH!', 'IN OFF THE POST!'];
const _topBinLines = ['TOP BINS!', 'UNSTOPPABLE!', 'ABSOLUTE SCREAMER!', 'NO CHANCE!'];
const _saveLines = ['DENIED!', 'WHAT A SAVE!', 'THE KEEPER READ IT!', 'SO CLOSE!'];
const _wideLines = ['WIDE!', 'OVER THE BAR!', 'NO WAY THROUGH!', 'KEEP YOUR HEAD UP'];
const _postLines = ['OFF THE POST!', 'CLANGS OFF THE WOODWORK!', 'AGONISINGLY CLOSE!'];
const _crossbarLines = ['OFF THE CROSSBAR!', 'RATTLES THE BAR!'];

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