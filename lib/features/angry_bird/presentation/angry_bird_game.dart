import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors, ValueNotifier, LinearGradient, Alignment;

import 'angry_bird_config.dart';
import 'angry_bird_levels.dart';

/// A hand-rolled 2D rigid-body-ish physics sim (gravity, circle/AABB
/// collision, impulse response, impact damage) driving a slingshot
/// "smash the pigs" game. No external physics package is used — this
/// keeps the game dependency-free and consistent with how [RacingGame]
/// draws everything by hand with [Canvas]. Real Box2D-accurate rotation
/// and stacking is intentionally out of scope; blocks stay axis-aligned
/// and structures topple through simple AABB push-apart + impulse
/// transfer, which is enough for convincing chain-reaction collapses.
class AngryBirdGame extends FlameGame {
  AngryBirdGame({required this.level, required this.onLevelEnd});

  final AngryBirdLevel level;

  /// Fired once when the run ends, with the final score and whether every
  /// pig was destroyed before the birds ran out.
  final void Function(int score, bool won) onLevelEnd;

  final math.Random _random = math.Random();
  final List<_Block> _blocks = [];
  final List<_Pig> _pigs = [];
  final List<_Particle> _particles = [];
  final List<_Cloud> _clouds = [];

  _Bird? _current;
  bool _dragging = false;
  int _birdIndex = 0;
  int _score = 0;
  bool _paused = false;
  bool _levelEnded = false;

  double _shakeTime = 0;
  static const double _shakeDuration = 0.25;

  double _renderScale = 1;
  double _renderOffsetX = 0;
  double _renderOffsetY = 0;

  /// Bumped every tick so a [ValueListenableBuilder] can cheaply rebuild
  /// the HUD without Flame needing to know about Flutter widgets.
  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  int get score => _score;
  int get birdsRemaining => level.birds.length - _birdIndex;
  int get pigsRemaining => _pigs.where((p) => p.alive).length;
  bool get isPausedByUser => _paused && !_levelEnded;
  bool get isAiming => _current != null && !_current!.launched;
  bool get isBoostReady =>
      _current != null &&
      _current!.launched &&
      _current!.kind == BirdKind.yellow &&
      !_current!.boosted;

  Offset get slingAnchor => Offset(120, AngryBirdConfig.groundY - 60);

  @override
  Color backgroundColor() => AngryBirdConfig.skyTop;

  @override
  Future<void> onLoad() async {
    for (final b in level.blocks) {
      _blocks.add(_Block(x: b.x, y: b.y, w: b.w, h: b.h, material: b.material));
    }
    for (final p in level.pigs) {
      _pigs.add(_Pig(x: p.x, y: p.y, radius: p.radius));
    }
    for (var i = 0; i < 4; i++) {
      _clouds.add(
        _Cloud(
          x: _random.nextDouble() * AngryBirdConfig.refWidth,
          y: 30 + _random.nextDouble() * 90,
          scale: 0.6 + _random.nextDouble() * 0.7,
          speed: 6 + _random.nextDouble() * 10,
        ),
      );
    }
    _spawnNextBird();
  }

  void _spawnNextBird() {
    final kind = level.birds[_birdIndex];
    _current = _Bird(kind: kind, x: slingAnchor.dx, y: slingAnchor.dy);
    hudTick.value++;
  }

  void togglePause() {
    if (_levelEnded) return;
    _paused = !_paused;
    hudTick.value++;
  }

  // ---------------------------------------------------------------------
  // Input (driven by a GestureDetector wrapping the GameWidget)
  // ---------------------------------------------------------------------

  Offset screenToWorld(Offset screenPos) => Offset(
        (screenPos.dx - _renderOffsetX) / _renderScale,
        (screenPos.dy - _renderOffsetY) / _renderScale,
      );

  void onDragStart(Offset screenPos) {
    if (_paused || _levelEnded || !isAiming) return;
    final world = screenToWorld(screenPos);
    final dx = world.dx - slingAnchor.dx;
    final dy = world.dy - slingAnchor.dy;
    if (dx * dx + dy * dy < AngryBirdConfig.maxDragRadius * AngryBirdConfig.maxDragRadius * 3) {
      _dragging = true;
    }
  }

  void onDragUpdate(Offset screenPos) {
    if (!_dragging || _current == null) return;
    final world = screenToWorld(screenPos);
    var dx = world.dx - slingAnchor.dx;
    var dy = world.dy - slingAnchor.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > AngryBirdConfig.maxDragRadius) {
      final s = AngryBirdConfig.maxDragRadius / dist;
      dx *= s;
      dy *= s;
    }
    _current!.x = slingAnchor.dx + dx;
    _current!.y = slingAnchor.dy + dy;
    hudTick.value++;
  }

  void onDragEnd() {
    if (!_dragging || _current == null) return;
    _dragging = false;
    final bird = _current!;
    final dx = slingAnchor.dx - bird.x;
    final dy = slingAnchor.dy - bird.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 12) {
      bird.x = slingAnchor.dx;
      bird.y = slingAnchor.dy;
      return; // Too small a pull — cancel, stays on the sling.
    }
    bird.vx = dx * AngryBirdConfig.launchPower;
    bird.vy = dy * AngryBirdConfig.launchPower;
    bird.launched = true;
    _shake(0.08);
  }

  void activateBoost() {
    final bird = _current;
    if (bird == null || !isBoostReady) return;
    bird.boosted = true;
    bird.vx *= AngryBirdConfig.yellowBoostMultiplier;
    bird.vy *= 0.55;
    _shake(0.1);
    for (var i = 0; i < 10; i++) {
      _particles.add(_Particle.burst(
        x: bird.x,
        y: bird.y,
        color: AngryBirdConfig.birdYellow,
        random: _random,
        speed: 90,
        life: 0.35,
        size: 4,
      ));
    }
  }

  void _shake(double amount) {
    _shakeTime = math.max(_shakeTime, amount);
  }

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateClouds(dt);
    _updateParticles(dt);
    if (_shakeTime > 0) _shakeTime = math.max(0, _shakeTime - dt);

    if (_paused || _levelEnded) {
      hudTick.value++;
      return;
    }

    _updatePhysics(dt.clamp(0.0, 0.032));
    hudTick.value++;
  }

  void _updateClouds(double dt) {
    for (final c in _clouds) {
      c.x -= c.speed * dt;
      if (c.x < -40) {
        c.x = AngryBirdConfig.refWidth + 40;
        c.y = 30 + _random.nextDouble() * 90;
      }
    }
  }

  void _updateParticles(double dt) {
    for (final p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _updatePhysics(double dt) {
    _updateActiveBird(dt);
    _updateBlocks(dt);
    _resolveBlockBlockCollisions();
    _blocks.removeWhere((b) => !b.alive);
  }

  void _updateActiveBird(double dt) {
    final b = _current;
    if (b == null || !b.launched) return;

    b.vy += AngryBirdConfig.gravity * dt;
    b.vx *= AngryBirdConfig.airDrag;
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    b.rotation += b.vx * dt * 0.01;
    b.trail.add(Offset(b.x, b.y));
    if (b.trail.length > 14) b.trail.removeAt(0);

    final floorY = AngryBirdConfig.groundY - b.radius;
    if (b.y > floorY) {
      b.y = floorY;
      b.vy = -b.vy * AngryBirdConfig.groundRestitution;
      b.vx *= AngryBirdConfig.groundFriction;
      b.bounces++;
      _spawnDust(b.x, AngryBirdConfig.groundY, count: 6);
      _shake(0.12);
    }

    for (final block in _blocks) {
      if (!block.alive) continue;
      final push = _circleRectPush(b.x, b.y, b.radius, block.x, block.y, block.w, block.h);
      if (push == null) continue;

      final speed = math.sqrt(b.vx * b.vx + b.vy * b.vy);
      block.vx += b.vx * 0.35;
      block.vy += b.vy * 0.35;
      block.resting = false;

      final dot = b.vx * push.nx + b.vy * push.ny;
      b.x += push.nx * push.depth;
      b.y += push.ny * push.depth;
      b.vx = (b.vx - 2 * dot * push.nx) * AngryBirdConfig.blockRestitution;
      b.vy = (b.vy - 2 * dot * push.ny) * AngryBirdConfig.blockRestitution;
      b.bounces++;

      if (speed > AngryBirdConfig.blockDamageImpactSpeed) {
        block.health -= (speed - AngryBirdConfig.blockDamageImpactSpeed) * 0.4;
        block.flash = 0.15;
        _spawnDebris(block, count: 4);
        if (block.health <= 0) {
          block.alive = false;
          _score += block.material == BlockMaterial.stone ? 150 : 100;
          _spawnDebris(block, count: 16);
          _shake(0.15);
        }
      }
    }

    for (final pig in _pigs) {
      if (!pig.alive) continue;
      final dx = b.x - pig.x;
      final dy = b.y - pig.y;
      final rr = b.radius + pig.radius;
      if (dx * dx + dy * dy >= rr * rr) continue;

      final speed = math.sqrt(b.vx * b.vx + b.vy * b.vy);
      pig.hitFlash = 0.2;
      if (speed > AngryBirdConfig.killImpactSpeed || b.bounces > 0) {
        _killPig(pig);
      } else {
        final dist = math.sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
        final nx = dx / dist;
        final ny = dy / dist;
        b.x = pig.x + nx * rr;
        b.y = pig.y + ny * rr;
        b.vx *= 0.6;
        b.vy *= 0.6;
      }
    }

    final spd = math.sqrt(b.vx * b.vx + b.vy * b.vy);
    final offscreen = b.x < -60 || b.x > AngryBirdConfig.refWidth + 60 || b.y > AngryBirdConfig.refHeight + 80;
    if (offscreen) {
      _endBirdTurn();
      return;
    }
    if (spd < AngryBirdConfig.restSpeedThreshold && b.bounces > 0) {
      b.restTimer += dt;
      if (b.restTimer > 0.5) _endBirdTurn();
    } else {
      b.restTimer = 0;
    }
  }

  void _updateBlocks(double dt) {
    for (final block in _blocks) {
      if (!block.alive || block.resting) continue;
      block.vy += AngryBirdConfig.gravity * dt;
      block.x += block.vx * dt;
      block.y += block.vy * dt;
      block.vx *= 0.995;

      final floorY = AngryBirdConfig.groundY - block.h / 2;
      if (block.y > floorY) {
        block.y = floorY;
        block.vy = -block.vy * AngryBirdConfig.groundRestitution * 0.4;
        block.vx *= AngryBirdConfig.groundFriction;
      }
      if (block.x < block.w / 2) {
        block.x = block.w / 2;
        block.vx = 0;
      }
      if (block.x > AngryBirdConfig.refWidth - block.w / 2) {
        block.x = AngryBirdConfig.refWidth - block.w / 2;
        block.vx = 0;
      }

      // Falling blocks can crush pigs underneath them (chain reactions).
      for (final pig in _pigs) {
        if (!pig.alive) continue;
        final overlapsX = (block.x - pig.x).abs() < block.w / 2 + pig.radius * 0.6;
        final overlapsY = (block.y - pig.y).abs() < block.h / 2 + pig.radius * 0.6;
        if (overlapsX && overlapsY && block.vy.abs() > 40) {
          _killPig(pig);
        }
      }

      final spd = math.sqrt(block.vx * block.vx + block.vy * block.vy);
      if (spd < AngryBirdConfig.restSpeedThreshold) {
        block.restTimer += dt;
        if (block.restTimer > 0.35) block.resting = true;
      } else {
        block.restTimer = 0;
      }
    }
  }

  void _resolveBlockBlockCollisions() {
    for (var i = 0; i < _blocks.length; i++) {
      final a = _blocks[i];
      if (!a.alive) continue;
      for (var j = i + 1; j < _blocks.length; j++) {
        final b = _blocks[j];
        if (!b.alive) continue;
        if (a.resting && b.resting) continue;
        _resolveBlockBlock(a, b);
      }
    }
  }

  void _resolveBlockBlock(_Block a, _Block b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final overlapX = (a.w + b.w) / 2 - dx.abs();
    final overlapY = (a.h + b.h) / 2 - dy.abs();
    if (overlapX <= 0 || overlapY <= 0) return;

    a.resting = false;
    b.resting = false;
    if (overlapX < overlapY) {
      final push = overlapX / 2 * (dx == 0 ? 1 : dx.sign);
      a.x += push;
      b.x -= push;
      final rel = a.vx - b.vx;
      a.vx -= rel * 0.5;
      b.vx += rel * 0.5;
      _damageFromImpact(a, b, rel.abs());
    } else {
      final push = overlapY / 2 * (dy == 0 ? 1 : dy.sign);
      a.y += push;
      b.y -= push;
      final rel = a.vy - b.vy;
      a.vy -= rel * 0.5;
      b.vy += rel * 0.5;
      _damageFromImpact(a, b, rel.abs());
    }
  }

  void _damageFromImpact(_Block a, _Block b, double relSpeed) {
    if (relSpeed < AngryBirdConfig.blockDamageImpactSpeed * 0.7) return;
    for (final block in [a, b]) {
      block.health -= (relSpeed - AngryBirdConfig.blockDamageImpactSpeed * 0.7) * 0.25;
      block.flash = 0.12;
      if (block.health <= 0 && block.alive) {
        block.alive = false;
        _score += block.material == BlockMaterial.stone ? 150 : 100;
        _spawnDebris(block, count: 14);
      }
    }
  }

  void _killPig(_Pig pig) {
    if (!pig.alive) return;
    pig.alive = false;
    _score += 500;
    _spawnPigPop(pig.x, pig.y);
    _shake(0.2);
    if (_pigs.every((p) => !p.alive)) {
      _finishLevel(won: true);
    }
  }

  void _endBirdTurn() {
    if (_current == null || _levelEnded) return;
    _current = null;
    if (_birdIndex >= level.birds.length - 1) {
      _finishLevel(won: false);
    } else {
      _birdIndex++;
      _spawnNextBird();
    }
  }

  void _finishLevel({required bool won}) {
    if (_levelEnded) return;
    _levelEnded = true;
    if (won) {
      final unusedBirds = math.max(0, level.birds.length - 1 - _birdIndex);
      _score += unusedBirds * 200;
    }
    hudTick.value++;
    onLevelEnd(_score, won);
  }

  // ---------------------------------------------------------------------
  // Collision helpers
  // ---------------------------------------------------------------------

  ({double nx, double ny, double depth})? _circleRectPush(
    double cx,
    double cy,
    double r,
    double rx,
    double ry,
    double rw,
    double rh,
  ) {
    final closestX = cx.clamp(rx - rw / 2, rx + rw / 2);
    final closestY = cy.clamp(ry - rh / 2, ry + rh / 2);
    final dx = cx - closestX;
    final dy = cy - closestY;
    final distSq = dx * dx + dy * dy;
    if (distSq >= r * r) return null;
    final dist = math.sqrt(distSq);
    if (dist < 0.0001) {
      return (nx: 0.0, ny: -1.0, depth: r);
    }
    return (nx: dx / dist, ny: dy / dist, depth: r - dist);
  }

  // ---------------------------------------------------------------------
  // Particles
  // ---------------------------------------------------------------------

  void _spawnDust(double x, double y, {required int count}) {
    for (var i = 0; i < count; i++) {
      _particles.add(_Particle.burst(
        x: x,
        y: y,
        color: Colors.white,
        random: _random,
        speed: 60,
        life: 0.35,
        size: 5,
      ));
    }
  }

  void _spawnDebris(_Block block, {required int count}) {
    final color = block.material == BlockMaterial.wood
        ? AngryBirdConfig.woodBlockDark
        : AngryBirdConfig.stoneBlockDark;
    for (var i = 0; i < count; i++) {
      _particles.add(_Particle.burst(
        x: block.x,
        y: block.y,
        color: color,
        random: _random,
        speed: 140,
        life: 0.6,
        size: 4,
      ));
    }
  }

  void _spawnPigPop(double x, double y) {
    for (var i = 0; i < 18; i++) {
      _particles.add(_Particle.burst(
        x: x,
        y: y,
        color: i.isEven ? AngryBirdConfig.pigGreen : AngryBirdConfig.pigGreenDark,
        random: _random,
        speed: 160,
        life: 0.55,
        size: 5,
      ));
    }
  }

  // ---------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = AngryBirdConfig.navyDeep);

    final scale = math.min(w / AngryBirdConfig.refWidth, h / AngryBirdConfig.refHeight);
    final offsetX = (w - AngryBirdConfig.refWidth * scale) / 2;
    final offsetY = (h - AngryBirdConfig.refHeight * scale) / 2;
    _renderScale = scale;
    _renderOffsetX = offsetX;
    _renderOffsetY = offsetY;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    if (_shakeTime > 0) {
      final p = _shakeTime / _shakeDuration;
      canvas.translate((_random.nextDouble() - 0.5) * 10 * p, (_random.nextDouble() - 0.5) * 10 * p);
    }

    _renderSky(canvas);
    _renderClouds(canvas);
    _renderHills(canvas);
    _renderGround(canvas);
    _renderSlingBack(canvas);
    for (final block in _blocks) {
      _renderBlock(canvas, block);
    }
    for (final pig in _pigs) {
      if (pig.alive) _renderPig(canvas, pig);
    }
    if (isAiming && _dragging) _renderTrajectory(canvas);
    _renderSlingFront(canvas);
    if (_current != null) _renderBird(canvas, _current!);
    _renderParticles(canvas);

    canvas.restore();
  }

  void _renderSky(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, AngryBirdConfig.refWidth, AngryBirdConfig.refHeight);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AngryBirdConfig.skyTop, AngryBirdConfig.skyBottom],
        ).createShader(rect),
    );
  }

  void _renderClouds(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (final c in _clouds) {
      final r = 16 * c.scale;
      canvas.drawCircle(Offset(c.x, c.y), r, paint);
      canvas.drawCircle(Offset(c.x - r * 0.8, c.y + r * 0.2), r * 0.7, paint);
      canvas.drawCircle(Offset(c.x + r * 0.8, c.y + r * 0.15), r * 0.75, paint);
    }
  }

  void _renderHills(Canvas canvas) {
    final farPath = Path()
      ..moveTo(0, AngryBirdConfig.groundY)
      ..quadraticBezierTo(140, AngryBirdConfig.groundY - 90, 320, AngryBirdConfig.groundY - 20)
      ..quadraticBezierTo(520, AngryBirdConfig.groundY - 110, 800, AngryBirdConfig.groundY - 10)
      ..lineTo(800, AngryBirdConfig.groundY)
      ..close();
    canvas.drawPath(farPath, Paint()..color = AngryBirdConfig.hillFar);

    final nearPath = Path()
      ..moveTo(0, AngryBirdConfig.groundY)
      ..quadraticBezierTo(220, AngryBirdConfig.groundY - 50, 460, AngryBirdConfig.groundY - 6)
      ..quadraticBezierTo(650, AngryBirdConfig.groundY - 60, 800, AngryBirdConfig.groundY)
      ..close();
    canvas.drawPath(nearPath, Paint()..color = AngryBirdConfig.hillNear);
  }

  void _renderGround(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, AngryBirdConfig.groundY, AngryBirdConfig.refWidth, AngryBirdConfig.groundHeight),
      Paint()..color = AngryBirdConfig.groundBody,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, AngryBirdConfig.groundY, AngryBirdConfig.refWidth, 8),
      Paint()..color = AngryBirdConfig.groundTop,
    );
  }

  void _renderSlingBack(Canvas canvas) {
    final base = slingAnchor;
    final woodPaint = Paint()
      ..color = AngryBirdConfig.slingWood
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(base.dx - 14, AngryBirdConfig.groundY), Offset(base.dx - 14, base.dy - 8), woodPaint);

    final bandFrom = Offset(base.dx - 14, base.dy - 8);
    final tip = _current != null ? Offset(_current!.x, _current!.y) : base;
    canvas.drawLine(bandFrom, tip, Paint()..color = AngryBirdConfig.band..strokeWidth = 3);
  }

  void _renderSlingFront(Canvas canvas) {
    final base = slingAnchor;
    final woodPaint = Paint()
      ..color = AngryBirdConfig.slingWood
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(base.dx + 14, AngryBirdConfig.groundY), Offset(base.dx + 14, base.dy - 8), woodPaint);
    canvas.drawLine(
      Offset(base.dx + 14, AngryBirdConfig.groundY),
      Offset(base.dx + 14, base.dy - 8),
      Paint()
        ..color = AngryBirdConfig.slingWoodDark
        ..strokeWidth = 2,
    );

    final bandFrom = Offset(base.dx + 14, base.dy - 8);
    final tip = _current != null ? Offset(_current!.x, _current!.y) : base;
    canvas.drawLine(bandFrom, tip, Paint()..color = AngryBirdConfig.band..strokeWidth = 3);
  }

  void _renderTrajectory(Canvas canvas) {
    final b = _current;
    if (b == null) return;
    final vx = (slingAnchor.dx - b.x) * AngryBirdConfig.launchPower;
    final vy = (slingAnchor.dy - b.y) * AngryBirdConfig.launchPower;
    var x = b.x;
    var y = b.y;
    var dvx = vx;
    var dvy = vy;
    final paint = Paint()..color = AngryBirdConfig.trajectoryDot;
    for (var i = 0; i < 30; i++) {
      dvy += AngryBirdConfig.gravity * 0.045;
      x += dvx * 0.045;
      y += dvy * 0.045;
      if (y > AngryBirdConfig.groundY) break;
      if (i % 2 == 0) {
        canvas.drawCircle(Offset(x, y), 2.6, paint);
      }
    }
  }

  void _renderBlock(Canvas canvas, _Block block) {
    final isWood = block.material == BlockMaterial.wood;
    final base = isWood ? AngryBirdConfig.woodBlock : AngryBirdConfig.stoneBlock;
    final dark = isWood ? AngryBirdConfig.woodBlockDark : AngryBirdConfig.stoneBlockDark;
    final damageT = 1 - (block.health / block.maxHealth).clamp(0.0, 1.0);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(block.x, block.y), width: block.w, height: block.h),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = Color.lerp(base, dark, damageT * 0.6)!);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    if (block.flash > 0) {
      canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: block.flash * 2.2));
    }
    if (damageT > 0.35) {
      final crackPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(block.x - block.w * 0.2, block.y - block.h * 0.3),
        Offset(block.x + block.w * 0.1, block.y + block.h * 0.3),
        crackPaint,
      );
    }
    if (block.flash > 0) block.flash = math.max(0, block.flash - 0.02);
  }

  void _renderPig(Canvas canvas, _Pig pig) {
    final wobble = math.sin(pig.wobbleT) * 0.06;
    pig.wobbleT += 0.08;
    canvas.save();
    canvas.translate(pig.x, pig.y);
    canvas.rotate(wobble);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, pig.radius * 0.85), width: pig.radius * 1.9, height: pig.radius * 0.5),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    final body = pig.hitFlash > 0 ? Colors.white : AngryBirdConfig.pigGreen;
    canvas.drawCircle(Offset.zero, pig.radius, Paint()..color = body);
    canvas.drawCircle(
      Offset.zero,
      pig.radius,
      Paint()
        ..color = AngryBirdConfig.pigGreenDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, pig.radius * 0.25), width: pig.radius * 0.8, height: pig.radius * 0.55),
      Paint()..color = AngryBirdConfig.pigGreenDark.withValues(alpha: 0.7),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(side * pig.radius * 0.35, -pig.radius * 0.15), pig.radius * 0.24, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(side * pig.radius * 0.35, -pig.radius * 0.15), pig.radius * 0.1, Paint()..color = Colors.black);
    }
    canvas.restore();
    if (pig.hitFlash > 0) pig.hitFlash = math.max(0, pig.hitFlash - 0.02);
  }

  void _renderBird(Canvas canvas, _Bird bird) {
    for (var i = 0; i < bird.trail.length; i++) {
      final a = (i / bird.trail.length) * 0.25;
      canvas.drawCircle(bird.trail[i], bird.radius * 0.4, Paint()..color = Colors.white.withValues(alpha: a));
    }

    final isYellow = bird.kind == BirdKind.yellow;
    final body = isYellow ? AngryBirdConfig.birdYellow : AngryBirdConfig.birdRed;
    final dark = isYellow ? AngryBirdConfig.birdYellowDark : AngryBirdConfig.birdRedDark;

    canvas.save();
    canvas.translate(bird.x, bird.y);
    canvas.rotate(bird.rotation);

    canvas.drawCircle(Offset.zero, bird.radius, Paint()..color = body);
    canvas.drawCircle(
      Offset.zero,
      bird.radius,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final beak = Path()
      ..moveTo(bird.radius * 0.7, -3)
      ..lineTo(bird.radius * 1.35, 0)
      ..lineTo(bird.radius * 0.7, 5)
      ..close();
    canvas.drawPath(beak, Paint()..color = AngryBirdConfig.gold);

    canvas.drawCircle(Offset(bird.radius * 0.15, -bird.radius * 0.25), bird.radius * 0.28, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(bird.radius * 0.2, -bird.radius * 0.25), bird.radius * 0.13, Paint()..color = Colors.black);

    final brow = Paint()
      ..color = AngryBirdConfig.navyDeep
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-bird.radius * 0.15, -bird.radius * 0.55),
      Offset(bird.radius * 0.35, -bird.radius * 0.35),
      brow,
    );

    canvas.restore();
  }

  void _renderParticles(Canvas canvas) {
    for (final p in _particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(p.x, p.y), p.size * alpha, Paint()..color = p.color.withValues(alpha: alpha));
    }
  }

  @override
  void onRemove() {
    hudTick.dispose();
    super.onRemove();
  }
}

class _Bird {
  _Bird({required this.kind, required this.x, required this.y});
  final BirdKind kind;
  double x, y, vx = 0, vy = 0;
  double rotation = 0;
  bool launched = false;
  bool boosted = false;
  int bounces = 0;
  double restTimer = 0;
  final double radius = AngryBirdConfig.birdRadius;
  final List<Offset> trail = [];
}

class _Pig {
  _Pig({required this.x, required this.y, required this.radius});
  double x, y;
  final double radius;
  bool alive = true;
  double hitFlash = 0;
  double wobbleT = 0;
}

class _Block {
  _Block({required this.x, required this.y, required this.w, required this.h, required this.material})
      : maxHealth = material == BlockMaterial.wood
            ? AngryBirdConfig.blockHealthWood
            : AngryBirdConfig.blockHealthStone,
        health = material == BlockMaterial.wood
            ? AngryBirdConfig.blockHealthWood
            : AngryBirdConfig.blockHealthStone;

  double x, y;
  double vx = 0, vy = 0;
  final double w, h;
  final BlockMaterial material;
  double health;
  final double maxHealth;
  bool alive = true;
  bool resting = false;
  double restTimer = 0;
  double flash = 0;
}

class _Cloud {
  _Cloud({required this.x, required this.y, required this.scale, required this.speed});
  double x, y;
  final double scale;
  final double speed;
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
      vy: math.sin(angle) * magnitude - 40,
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
    vy += AngryBirdConfig.gravity * 0.6 * dt;
    life -= dt;
  }
}
