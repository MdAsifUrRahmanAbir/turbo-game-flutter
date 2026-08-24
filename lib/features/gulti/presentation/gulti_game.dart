import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Colors, ValueNotifier, TextPainter, TextSpan, TextStyle, FontWeight, RadialGradient, LinearGradient, Alignment;

import 'gulti_config.dart';
import 'gulti_levels.dart';

enum _BirdState { sitting, takingOff, flying, hit }

/// A hand-painted, Canvas-only slingshot bird game — no external physics
/// package, no Flame Component tree, matching the style [AngryBirdGame]
/// and [RacingGame] already use in this project. The whole scene is
/// positioned as a fraction of the device's actual logical size (see
/// [GultiConfig]) rather than a fixed reference resolution, since this
/// game is portrait-only.
class GultiGame extends FlameGame {
  GultiGame({required this.level, required this.onLevelEnd});

  final GultiLevel level;

  /// Fired once when the run ends, with the final tally so the screen can
  /// hand it to [GultiController.finishLevel].
  final void Function({
    required int score,
    required int birdsHit,
    required int totalBirds,
    required int stonesUsed,
    required int stoneCount,
    required bool won,
  }) onLevelEnd;

  final math.Random _random = math.Random();
  final List<_GBird> _birds = [];
  final List<_TreeSpot> _treeSpots = [];
  final List<_Particle> _particles = [];
  final List<_Cloud> _clouds = [];
  final List<_FloatingText> _floatingTexts = [];

  _Stone? _stone;
  bool _dragging = false;
  double _aimX = 0;
  double _aimY = 0;

  int _stonesRemaining = 0;
  int _score = 0;
  int _combo = 0;
  int _birdsHit = 0;
  int _shotsTaken = 0;
  double? _timeRemaining;

  bool _paused = false;
  bool _levelEnded = false;
  double _shakeTime = 0;

  /// Bumped every tick so a [ValueListenableBuilder] can cheaply rebuild
  /// the HUD without Flame needing to know about Flutter widgets.
  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  int get score => _score;
  int get combo => _combo;
  int get stonesRemaining => _stonesRemaining;
  int get birdsHit => _birdsHit;
  int get totalBirds => level.birds.length;
  double? get timeRemaining => _timeRemaining;
  bool get isPausedByUser => _paused && !_levelEnded;

  Offset get anchor => Offset(
        size.x * GultiConfig.anchorXFraction,
        size.y * GultiConfig.anchorYFraction - GultiConfig.restLift,
      );

  @override
  Color backgroundColor() => GultiConfig.skyTop;

  @override
  Future<void> onLoad() async {
    _stonesRemaining = level.stoneCount;
    _timeRemaining = level.timeLimit;
    _seedClouds();
    if (size.x > 0 && size.y > 0) {
      _spawnBirdsFromDefs();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_birds.isEmpty && size.x > 0 && size.y > 0) {
      _spawnBirdsFromDefs();
    }
  }

  void _spawnBirdsFromDefs() {
    _birds.clear();
    _treeSpots.clear();
    for (final def in level.birds) {
      final px = def.x * size.x;
      final py = def.y * size.y;
      final bird = _GBird(
        kind: def.kind,
        state: def.perch == BirdPerch.sitting ? _BirdState.sitting : _BirdState.flying,
        x: px,
        y: py,
        perchX: px,
        perchY: py,
        radius: GultiConfig.birdRadius,
        speed: _baseSpeedFor(def.kind) * level.speedScale,
      );
      if (def.perch == BirdPerch.flying) {
        bird.boundLeft = (def.boundLeft ?? 0.05) * size.x;
        bird.boundRight = (def.boundRight ?? 0.95) * size.x;
        bird.boundTop = (def.boundTop ?? 0.10) * size.y;
        bird.boundBottom = (def.boundBottom ?? 0.35) * size.y;
        bird.targetX = px;
        bird.targetY = py;
      } else {
        _treeSpots.add(_TreeSpot(px, py));
      }
      _birds.add(bird);
    }
  }

  double _baseSpeedFor(BirdKind kind) => switch (kind) {
        BirdKind.normal => GultiConfig.normalBirdSpeed,
        BirdKind.fast => GultiConfig.fastBirdSpeed,
        BirdKind.rare => GultiConfig.rareBirdSpeed,
      };

  int _scoreFor(BirdKind kind) => switch (kind) {
        BirdKind.normal => GultiConfig.scoreNormal,
        BirdKind.fast => GultiConfig.scoreFast,
        BirdKind.rare => GultiConfig.scoreRare,
      };

  // ---------------------------------------------------------------------
  // Input (driven by a GestureDetector wrapping the GameWidget)
  // ---------------------------------------------------------------------

  bool get isAiming => _stone == null && _stonesRemaining > 0 && !_paused && !_levelEnded;

  void onDragStart(Offset pos) {
    if (!isAiming) return;
    final a = anchor;
    final dx = pos.dx - a.dx;
    final dy = pos.dy - a.dy;
    if (dx * dx + dy * dy < 160 * 160) {
      _dragging = true;
      _aimX = a.dx;
      _aimY = a.dy;
    }
  }

  void onDragUpdate(Offset pos) {
    if (!_dragging) return;
    final a = anchor;
    var dx = pos.dx - a.dx;
    var dy = pos.dy - a.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > GultiConfig.maxPullRadius) {
      final s = GultiConfig.maxPullRadius / dist;
      dx *= s;
      dy *= s;
    }
    // Keep the pouch from being pulled above the anchor — that would aim
    // the stone straight into the ground, which never feels good.
    dy = math.max(dy, 6);
    _aimX = a.dx + dx;
    _aimY = a.dy + dy;
    hudTick.value++;
  }

  void onDragEnd() {
    if (!_dragging) return;
    _dragging = false;
    final a = anchor;
    final dx = a.dx - _aimX;
    final dy = a.dy - _aimY;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 14) return; // too small a pull — cancelled, stays loaded

    _stone = _Stone(
      x: _aimX,
      y: _aimY,
      vx: dx * GultiConfig.launchPowerMultiplier,
      vy: dy * GultiConfig.launchPowerMultiplier,
    );
    _stonesRemaining--;
    _shotsTaken++;
    _shake(0.08);
    hudTick.value++;
  }

  void togglePause() {
    if (_levelEnded) return;
    _paused = !_paused;
    hudTick.value++;
  }

  void _shake(double amount) => _shakeTime = math.max(_shakeTime, amount);

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateClouds(dt);
    _updateParticles(dt);
    _updateFloatingTexts(dt);
    if (_shakeTime > 0) _shakeTime = math.max(0, _shakeTime - dt);

    if (_paused || _levelEnded) {
      hudTick.value++;
      return;
    }

    if (_timeRemaining != null) {
      _timeRemaining = math.max(0, _timeRemaining! - dt);
      if (_timeRemaining == 0) {
        _finishLevel(won: _birdsHit >= level.birds.length);
      }
    }

    _updateBirds(dt);
    _updateStone(dt);
    hudTick.value++;
  }

  void _updateClouds(double dt) {
    for (final c in _clouds) {
      c.x -= c.speed * dt;
      if (c.x < -0.25) {
        c.x = 1.2;
        c.y = 0.05 + _random.nextDouble() * 0.18;
      }
    }
  }

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _updateFloatingTexts(double dt) {
    for (final t in _floatingTexts) {
      t.y -= 32 * dt;
      t.life -= dt;
    }
    _floatingTexts.removeWhere((t) => t.life <= 0);
  }

  void _seedClouds() {
    _clouds.clear();
    for (var i = 0; i < 4; i++) {
      _clouds.add(_Cloud(
        x: _random.nextDouble(),
        y: 0.05 + _random.nextDouble() * 0.18,
        scale: 0.6 + _random.nextDouble() * 0.7,
        speed: 0.006 + _random.nextDouble() * 0.012,
      ));
    }
  }

  void _updateBirds(double dt) {
    for (final bird in _birds) {
      if (!bird.alive) continue;
      bird.flapPhase += dt * GultiConfig.flapCycleSpeed * (bird.state == _BirdState.sitting ? 0.35 : 1.0);
      bird.idleT += dt;

      if (bird.state == _BirdState.sitting) {
        bird.waypointTimer -= dt;
        if (bird.waypointTimer <= 0) {
          bird.waypointTimer = 2 + _random.nextDouble() * 2.2;
          bird.hopTarget = bird.perchX + (_random.nextDouble() - 0.5) * 30;
        }
        bird.x += (bird.hopTarget - bird.x) * math.min(1, dt * 3);
        bird.y = bird.perchY + math.sin(bird.idleT * GultiConfig.idleBobSpeed) * 1.6;
      } else if (bird.state == _BirdState.takingOff) {
        bird.takeOffTimer -= dt;
        bird.y -= 60 * dt;
        bird.x += math.sin(bird.idleT * 6) * 12 * dt;
        if (bird.takeOffTimer <= 0) {
          bird.state = _BirdState.flying;
          bird.boundLeft = (bird.perchX - 100).clamp(10, math.max(10, size.x - 10));
          bird.boundRight = (bird.perchX + 100).clamp(10, math.max(10, size.x - 10));
          bird.boundTop = math.max(30, bird.perchY - 150);
          bird.boundBottom = bird.perchY - 20;
          bird.targetX = bird.x;
          bird.targetY = bird.y;
          bird.waypointTimer = 0;
        }
      } else if (bird.state == _BirdState.flying) {
        bird.waypointTimer -= dt;
        if (bird.waypointTimer <= 0) {
          final span = (2.6 - level.speedScale * 0.5).clamp(1.1, 2.6);
          bird.waypointTimer = span + _random.nextDouble() * span;
          bird.targetX = bird.boundLeft + _random.nextDouble() * (bird.boundRight - bird.boundLeft);
          bird.targetY = bird.boundTop + _random.nextDouble() * (bird.boundBottom - bird.boundTop);
        }
        final dx = bird.targetX - bird.x;
        final dy = bird.targetY - bird.y;
        final dist = math.sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
        final desiredVx = (dx / dist) * bird.speed;
        final desiredVy = (dy / dist) * bird.speed + math.sin(bird.idleT * 2.2) * 10;
        bird.vx += (desiredVx - bird.vx) * math.min(1, dt * 2.4);
        bird.vy += (desiredVy - bird.vy) * math.min(1, dt * 2.4);
        bird.x += bird.vx * dt;
        bird.y += bird.vy * dt;
        bird.x = bird.x.clamp(bird.boundLeft, bird.boundRight);
        bird.y = bird.y.clamp(bird.boundTop, bird.boundBottom);
        final targetRotation = math.atan2(bird.vy, bird.vx) * 0.35;
        bird.rotation += (targetRotation - bird.rotation) * math.min(1, dt * 5);
      } else if (bird.state == _BirdState.hit) {
        bird.hitTimer -= dt;
        bird.vy += GultiConfig.gravity * 0.4 * dt;
        bird.x += bird.vx * dt;
        bird.y += bird.vy * dt;
        bird.rotation += dt * 10;
        if (bird.hitTimer <= 0) bird.alive = false;
      }
    }
    _birds.removeWhere((b) => !b.alive);
  }

  void _updateStone(double dt) {
    final s = _stone;
    if (s == null) return;
    s.vy += GultiConfig.gravity * dt;
    s.vx *= GultiConfig.airDrag;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.rotation += GultiConfig.stoneRotationSpeed * dt;
    s.trail.add(Offset(s.x, s.y));
    if (s.trail.length > 12) s.trail.removeAt(0);

    // Startle nearby sitting birds even on a near miss.
    for (final bird in _birds) {
      if (bird.state != _BirdState.sitting) continue;
      final dx = s.x - bird.x;
      final dy = s.y - bird.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < GultiConfig.startleRadius) {
        bird.state = _BirdState.takingOff;
        bird.takeOffTimer = GultiConfig.takeOffDuration;
        bird.idleT = 0;
      }
    }

    for (final bird in _birds) {
      if (bird.state == _BirdState.hit) continue;
      final dx = s.x - bird.x;
      final dy = s.y - bird.y;
      final rr = GultiConfig.stoneRadius + bird.radius;
      if (dx * dx + dy * dy < rr * rr) {
        _resolveHit(bird, s);
        return;
      }
    }

    final offscreen = s.x < -40 || s.x > size.x + 40 || s.y > size.y + 40;
    final groundHit = s.y > size.y * GultiConfig.groundYFraction;
    if (offscreen || groundHit) {
      _resolveMiss(s.x, math.min(s.y, size.y * GultiConfig.groundYFraction));
    }
  }

  void _resolveHit(_GBird bird, _Stone stone) {
    bird.state = _BirdState.hit;
    bird.hitTimer = GultiConfig.hitReactionDuration;
    bird.vx = stone.vx * 0.12;
    bird.vy = -90;

    _combo++;
    final points = _scoreFor(bird.kind);
    final comboBonus = (_combo - 1) * GultiConfig.comboBonusPerHit;
    final total = points + comboBonus;
    _score += total;
    _birdsHit++;

    _spawnFeatherBurst(bird.x, bird.y);
    _spawnFloatingText(
      bird.x,
      bird.y,
      _combo > 1 ? '+$total  x$_combo COMBO' : '+$total',
      _combo > 1 ? GultiConfig.gold : Colors.white,
    );
    _shake(GultiConfig.crashShakeDuration);

    _stone = null;
    hudTick.value++;
    _afterShotResolved();
  }

  void _resolveMiss(double x, double y) {
    _combo = 0;
    _spawnDust(x, y);
    _stone = null;
    hudTick.value++;
    _afterShotResolved();
  }

  void _afterShotResolved() {
    if (_levelEnded) return;
    if (_birdsHit >= level.birds.length) {
      _finishLevel(won: true);
    } else if (_stonesRemaining <= 0) {
      _finishLevel(won: false);
    }
  }

  void _finishLevel({required bool won}) {
    if (_levelEnded) return;
    _levelEnded = true;
    if (won) {
      final savedBonus = _stonesRemaining * GultiConfig.stoneSavedBonus;
      final timeBonus =
          _timeRemaining != null ? (_timeRemaining! * GultiConfig.timeBonusPerSecond).round() : 0;
      _score += savedBonus + timeBonus;
    }
    hudTick.value++;
    onLevelEnd(
      score: _score,
      birdsHit: _birdsHit,
      totalBirds: level.birds.length,
      stonesUsed: _shotsTaken,
      stoneCount: level.stoneCount,
      won: won,
    );
  }

  // ---------------------------------------------------------------------
  // Particles
  // ---------------------------------------------------------------------

  void _spawnFeatherBurst(double x, double y) {
    for (var i = 0; i < 16; i++) {
      final color = GultiConfig.featherBurst[i % GultiConfig.featherBurst.length];
      _particles.add(_Particle.burst(x: x, y: y, color: color, random: _random, speed: 130, life: 0.55, size: 4.5));
    }
  }

  void _spawnDust(double x, double y) {
    for (var i = 0; i < 8; i++) {
      _particles.add(_Particle.burst(
        x: x,
        y: y,
        color: Colors.white.withValues(alpha: 0.6),
        random: _random,
        speed: 70,
        life: 0.35,
        size: 4,
      ));
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
      final p = _shakeTime / GultiConfig.crashShakeDuration;
      canvas.translate(
        (_random.nextDouble() - 0.5) * GultiConfig.crashShakeMagnitude * p,
        (_random.nextDouble() - 0.5) * GultiConfig.crashShakeMagnitude * p,
      );
    }

    _renderSky(canvas, w, h);
    _renderClouds(canvas, w, h);
    _renderHills(canvas, w, h);
    _renderGround(canvas, w, h);

    for (final spot in _treeSpots) {
      _renderTree(canvas, spot, h);
    }

    _renderSlingBack(canvas);

    for (final bird in _birds) {
      if (bird.state != _BirdState.hit) _renderBird(canvas, bird);
    }

    if (_dragging) {
      _renderPullBoundary(canvas);
      _renderTrajectory(canvas);
      _renderPowerMeter(canvas);
    }

    _renderPouchAndStoneIdle(canvas);
    _renderSlingFront(canvas);

    for (final bird in _birds) {
      if (bird.state == _BirdState.hit) _renderBird(canvas, bird);
    }

    if (_stone != null) _renderFlyingStone(canvas, _stone!);

    _renderParticles(canvas);
    _renderFloatingTexts(canvas);
    _renderVignette(canvas, w, h);

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
          colors: [GultiConfig.skyTop, GultiConfig.skyMid, GultiConfig.skyBottom],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(Offset(w * 0.78, h * 0.10), w * 0.09, Paint()..color = GultiConfig.sun.withValues(alpha: 0.95));
    canvas.drawCircle(Offset(w * 0.78, h * 0.10), w * 0.14, Paint()..color = GultiConfig.sun.withValues(alpha: 0.25));
  }

  void _renderClouds(Canvas canvas, double w, double h) {
    final paint = Paint()..color = GultiConfig.cloud.withValues(alpha: 0.9);
    for (final c in _clouds) {
      final x = w * c.x;
      final y = h * c.y;
      final r = w * 0.075 * c.scale;
      canvas.drawCircle(Offset(x, y), r * 0.6, paint);
      canvas.drawCircle(Offset(x - r * 0.7, y + r * 0.15), r * 0.45, paint);
      canvas.drawCircle(Offset(x + r * 0.7, y + r * 0.12), r * 0.5, paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y + r * 0.2), width: r * 2, height: r * 0.8), paint);
    }
  }

  void _renderHills(Canvas canvas, double w, double h) {
    final far = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.2, h * 0.52, w * 0.42, h * 0.60)
      ..quadraticBezierTo(w * 0.68, h * 0.50, w, h * 0.58)
      ..lineTo(w, h * 0.70)
      ..lineTo(0, h * 0.70)
      ..close();
    canvas.drawPath(far, Paint()..color = GultiConfig.hillFar);
  }

  void _renderGround(Canvas canvas, double w, double h) {
    final groundY = h * GultiConfig.groundYFraction;
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h - groundY), Paint()..color = GultiConfig.groundBody);
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, 8), Paint()..color = GultiConfig.groundTop);

    final blade = Paint()
      ..color = GultiConfig.grassB
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (double x = 4; x < w; x += 13) {
      final bh = 4.0 + (x.toInt() % 5);
      canvas.drawLine(Offset(x, groundY), Offset(x - 2.5, groundY - bh), blade);
      canvas.drawLine(Offset(x, groundY), Offset(x + 2.5, groundY - bh * 0.8), blade);
    }
  }

  void _renderTree(Canvas canvas, _TreeSpot spot, double h) {
    final groundY = h * GultiConfig.groundYFraction;
    canvas.drawRect(
      Rect.fromLTWH(spot.x - 6, spot.y, 12, groundY - spot.y),
      Paint()..color = GultiConfig.treeTrunk,
    );
    canvas.drawLine(
      Offset(spot.x - 44, spot.y),
      Offset(spot.x + 44, spot.y),
      Paint()
        ..color = GultiConfig.branch
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(spot.x, spot.y - 26), 30, Paint()..color = GultiConfig.leafLight);
    canvas.drawCircle(Offset(spot.x - 26, spot.y - 12), 22, Paint()..color = GultiConfig.leafDark);
    canvas.drawCircle(Offset(spot.x + 26, spot.y - 14), 22, Paint()..color = GultiConfig.leafDark);
  }

  Offset get _bandTip => _dragging ? Offset(_aimX, _aimY) : anchor;

  void _renderSlingBack(Canvas canvas) {
    final a = anchor;
    final postTop = Offset(a.dx - 16, a.dy - 6);
    final postBottom = Offset(a.dx - 16, size.y * GultiConfig.groundYFraction);
    canvas.drawLine(
      postBottom,
      postTop,
      Paint()
        ..color = GultiConfig.woodFrame
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    if (_stonesRemaining > 0 || _stone != null) {
      canvas.drawLine(
        postTop,
        _bandTip,
        Paint()
          ..color = GultiConfig.band
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderSlingFront(Canvas canvas) {
    final a = anchor;
    final postTop = Offset(a.dx + 16, a.dy - 6);
    final postBottom = Offset(a.dx + 16, size.y * GultiConfig.groundYFraction);
    canvas.drawLine(
      postBottom,
      postTop,
      Paint()
        ..color = GultiConfig.woodFrame
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    if (_stonesRemaining > 0 || _stone != null) {
      canvas.drawLine(
        postTop,
        _bandTip,
        Paint()
          ..color = GultiConfig.band
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderPouchAndStoneIdle(Canvas canvas) {
    if (_stone != null || _stonesRemaining <= 0) return;
    final pos = _dragging ? Offset(_aimX, _aimY) : anchor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 20, height: 13), const Radius.circular(4)),
      Paint()..color = GultiConfig.pouch.withValues(alpha: 0.9),
    );
    _drawStoneShape(canvas, pos, 0);
  }

  void _drawStoneShape(Canvas canvas, Offset pos, double rotation) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);
    final path = Path();
    const pts = [
      Offset(0, -9),
      Offset(7, -4),
      Offset(6, 6),
      Offset(-1, 9),
      Offset(-8, 3),
      Offset(-6, -6),
    ];
    path.moveTo(pts[0].dx, pts[0].dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = GultiConfig.stone);
    canvas.drawPath(
      path,
      Paint()
        ..color = GultiConfig.stoneDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(const Offset(-2, -3), 1.6, Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.restore();
  }

  void _renderFlyingStone(Canvas canvas, _Stone stone) {
    for (var i = 0; i < stone.trail.length; i++) {
      final a = (i / stone.trail.length) * 0.3;
      canvas.drawCircle(stone.trail[i], 3.5, Paint()..color = Colors.white.withValues(alpha: a));
    }
    _drawStoneShape(canvas, Offset(stone.x, stone.y), stone.rotation);
  }

  void _renderPullBoundary(Canvas canvas) {
    final a = anchor;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const dashCount = 32;
    for (var i = 0; i < dashCount; i += 2) {
      final a0 = (i / dashCount) * 2 * math.pi;
      final a1 = ((i + 1.1) / dashCount) * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: a, radius: GultiConfig.maxPullRadius), a0, a1 - a0, false, paint);
    }
  }

  void _renderTrajectory(Canvas canvas) {
    final a = anchor;
    var x = _aimX;
    var y = _aimY;
    final vx = (a.dx - _aimX) * GultiConfig.launchPowerMultiplier;
    var vy = (a.dy - _aimY) * GultiConfig.launchPowerMultiplier;
    for (var i = 0; i < 26; i++) {
      vy += GultiConfig.gravity * 0.045;
      x += vx * 0.045;
      y += vy * 0.045;
      if (y > size.y * GultiConfig.groundYFraction) break;
      if (i % 2 == 0) {
        final fade = 1 - i / 26;
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white.withValues(alpha: 0.5 * fade));
      }
    }
  }

  void _renderPowerMeter(Canvas canvas) {
    final a = anchor;
    final dx = a.dx - _aimX;
    final dy = a.dy - _aimY;
    final pull = math.sqrt(dx * dx + dy * dy);
    final pct = (pull / GultiConfig.maxPullRadius).clamp(0.0, 1.0);
    final center = Offset(a.dx, a.dy - 60);
    const radius = 20.0;
    canvas.drawCircle(center, radius, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(GultiConfig.teal, GultiConfig.coral, pct)!,
    );
  }

  void _renderBird(Canvas canvas, _GBird bird) {
    final body = switch (bird.kind) {
      BirdKind.normal => GultiConfig.birdNormal,
      BirdKind.fast => GultiConfig.birdFast,
      BirdKind.rare => GultiConfig.birdRare,
    };
    final dark = switch (bird.kind) {
      BirdKind.normal => GultiConfig.birdNormalDark,
      BirdKind.fast => GultiConfig.birdFastDark,
      BirdKind.rare => GultiConfig.birdRareDark,
    };

    final r = bird.radius;
    final wingLift = (math.sin(bird.flapPhase) + 1) / 2;

    canvas.save();
    canvas.translate(bird.x, bird.y);
    canvas.rotate(bird.state == _BirdState.sitting ? 0 : bird.rotation);

    // Wings — drawn behind the body, flapped by scaling vertically.
    canvas.save();
    canvas.translate(-r * 0.1, 0);
    canvas.scale(1, 0.5 + wingLift * 0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 0.9),
      Paint()..color = dark,
    );
    canvas.restore();

    // Body.
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 1.5);
    canvas.drawOval(bodyRect, Paint()..color = body);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Tail.
    final tail = Path()
      ..moveTo(-r * 0.85, 0)
      ..lineTo(-r * 1.5, -r * 0.4)
      ..lineTo(-r * 1.3, r * 0.25)
      ..close();
    canvas.drawPath(tail, Paint()..color = dark);

    // Head.
    canvas.drawCircle(Offset(r * 0.75, -r * 0.35), r * 0.62, Paint()..color = body);

    // Beak.
    final beak = Path()
      ..moveTo(r * 1.15, -r * 0.35)
      ..lineTo(r * 1.6, -r * 0.22)
      ..lineTo(r * 1.15, -r * 0.1)
      ..close();
    canvas.drawPath(beak, Paint()..color = GultiConfig.gold);

    // Eye.
    canvas.drawCircle(Offset(r * 0.85, -r * 0.45), r * 0.14, Paint()..color = Colors.black87);

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
        text: TextSpan(
          text: t.text,
          style: TextStyle(color: t.color.withValues(alpha: alpha), fontSize: 13, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(t.x - tp.width / 2, t.y - tp.height / 2));
    }
  }

  void _renderVignette(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.14)],
          stops: const [0.6, 1],
          radius: 0.9,
        ).createShader(rect),
    );
  }

  @override
  void onRemove() {
    hudTick.dispose();
    super.onRemove();
  }
}

class _GBird {
  _GBird({
    required this.kind,
    required this.state,
    required this.x,
    required this.y,
    required this.perchX,
    required this.perchY,
    required this.radius,
    required this.speed,
  });

  final BirdKind kind;
  _BirdState state;
  double x, y, vx = 0, vy = 0;
  final double perchX, perchY;
  final double radius;
  final double speed;

  double boundLeft = 0, boundRight = 0, boundTop = 0, boundBottom = 0;
  double targetX = 0, targetY = 0;
  double waypointTimer = 0;
  double flapPhase = 0;
  double idleT = 0;
  double rotation = 0;
  double hitTimer = 0;
  double takeOffTimer = 0;
  double hopTarget = 0;
  bool alive = true;
}

class _Stone {
  _Stone({required this.x, required this.y, required this.vx, required this.vy});
  double x, y, vx, vy;
  double rotation = 0;
  final List<Offset> trail = [];
}

class _TreeSpot {
  _TreeSpot(this.x, this.y);
  final double x, y;
}

class _Cloud {
  _Cloud({required this.x, required this.y, required this.scale, required this.speed});
  double x, y;
  final double scale, speed;
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

  double x, y;
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
      vy: math.sin(angle) * magnitude - 30,
      color: color,
      life: life,
      maxLife: life,
      size: size * (0.6 + random.nextDouble() * 0.8),
    );
  }

  double x, y, vx, vy;
  final Color color;
  double life;
  final double maxLife;
  final double size;

  bool get isDead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += GultiConfig.gravity * 0.5 * dt;
    life -= dt;
  }
}
