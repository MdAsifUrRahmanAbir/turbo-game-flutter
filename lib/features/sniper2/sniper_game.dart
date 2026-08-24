import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sniper_config.dart';

enum _Phase { rising, holding, falling, hit }

/// A hand-painted, cartoon-styled desert sniper mission. Everything is
/// drawn with [Canvas] primitives (no image assets required) so the whole
/// look can be re-themed from [SniperConfig].
///
/// Aiming: drag anywhere to move the crosshair freely; fire with the HUD's
/// dedicated shoot button. A physical keyboard also works (for web/desktop):
/// WASD to move the crosshair, Enter or Space to fire.
class SniperGame extends FlameGame with DragCallbacks, KeyboardEvents {
  SniperGame({required this.onHudUpdate, required this.onMissionEnd});

  /// Fired several times a second while playing so the HUD can stay in
  /// sync without hammering Riverpod every single frame.
  final void Function(
    int score,
    int ammo,
    int targetsHit,
    double? timeRemaining,
    int shotsFired,
    int shotsHit,
  ) onHudUpdate;

  /// Fired once when a mission ends, successfully or not.
  final void Function(bool success, int score, int completionBonus, String? failReason) onMissionEnd;

  final math.Random _random = math.Random();

  late SniperLevelConfig _level;

  final List<_BanditTarget?> _slots = List<_BanditTarget?>.filled(SniperConfig.slotCount, null);
  final List<_MovingBandit> _movers = <_MovingBandit>[];
  final List<_BulletTrail> _bullets = <_BulletTrail>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_FloatingText> _floatingTexts = <_FloatingText>[];
  final List<_Cloud> _clouds = <_Cloud>[];
  final List<_Cactus> _cacti = <_Cactus>[];

  double _crosshairX = 0;
  double _crosshairY = 0;
  double _muzzleFlash = 0;

  bool _keyUp = false;
  bool _keyDown = false;
  bool _keyLeft = false;
  bool _keyRight = false;

  double _spawnTimer = 0;
  double _hudTimer = 0;

  int _score = 0;
  int _ammo = 0;
  int _targetsHit = 0;
  int _shotsFired = 0;
  int _shotsHit = 0;
  double? _timeRemaining;

  bool _running = false;
  bool _paused = false;
  bool _missionEnded = false;
  double _shakeTime = 0;

  bool get isRunning => _running && !_missionEnded && !_paused;

  @override
  Color backgroundColor() => SniperConfig.skyTop;

  @override
  Future<void> onLoad() async {
    _crosshairX = size.x / 2;
    _crosshairY = size.y / 2;
    _seedScenery();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    if (_crosshairX == 0 && _crosshairY == 0) {
      _crosshairX = newSize.x / 2;
      _crosshairY = newSize.y / 2;
    }
  }

  void _seedScenery() {
    _clouds.clear();
    for (var i = 0; i < 4; i++) {
      _clouds.add(_Cloud(x: _random.nextDouble(), y: 0.08 + _random.nextDouble() * 0.18, scale: 0.7 + _random.nextDouble() * 0.7));
    }
    _cacti.clear();
    for (var i = 0; i < 5; i++) {
      _cacti.add(_Cactus(x: _random.nextDouble(), scale: 0.6 + _random.nextDouble() * 0.7));
    }
  }

  // ---------------------------------------------------------------------
  // Mission lifecycle
  // ---------------------------------------------------------------------

  void startLevel(SniperLevelConfig level) {
    _level = level;

    for (var i = 0; i < _slots.length; i++) {
      _slots[i] = null;
    }
    _movers.clear();
    _bullets.clear();
    _particles.clear();
    _floatingTexts.clear();

    _crosshairX = size.x / 2;
    _crosshairY = size.y / 2;
    _muzzleFlash = 0;
    _keyUp = _keyDown = _keyLeft = _keyRight = false;

    _spawnTimer = 0;
    _hudTimer = 0;

    _score = 0;
    _ammo = level.ammo;
    _targetsHit = 0;
    _shotsFired = 0;
    _shotsHit = 0;
    _timeRemaining = level.timeLimit;

    _running = true;
    _paused = false;
    _missionEnded = false;
    _shakeTime = 0;
  }

  void pauseGame() {
    if (!_missionEnded) _paused = true;
  }

  void resumeGame() {
    if (!_missionEnded) _paused = false;
  }

  // ---------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------

  void _moveCrosshair(double dx, double dy) {
    _crosshairX = (_crosshairX + dx).clamp(20, math.max(20, size.x - 20)).toDouble();
    _crosshairY = (_crosshairY + dy).clamp(20, math.max(20, size.y - 20)).toDouble();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isRunning) return;
    _moveCrosshair(event.localDelta.x, event.localDelta.y);
  }

  void fire() {
    if (!isRunning || _ammo <= 0) return;

    _ammo--;
    _shotsFired++;
    _muzzleFlash = 0.1;
    _shakeTime = math.max(_shakeTime, 0.08);

    final hit = _resolveShot();
    _bullets.add(
      _BulletTrail(
        startX: _muzzleX,
        startY: _muzzleY,
        endX: _crosshairX,
        endY: _crosshairY,
        timer: 0,
        hit: hit,
      ),
    );

    if (!hit) {
      if (_ammo <= 0 && _targetsHit < _level.targetGoal) {
        _endMission(success: false, failReason: 'outOfAmmo');
      }
    } else if (!_missionEnded && _ammo <= 0 && _targetsHit < _level.targetGoal) {
      // The shot connected but still wasn't enough to clear the goal, and
      // that was the last bullet in the clip — mission over.
      _endMission(success: false, failReason: 'outOfAmmo');
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keyUp = keysPressed.contains(LogicalKeyboardKey.keyW);
    _keyLeft = keysPressed.contains(LogicalKeyboardKey.keyA);
    _keyDown = keysPressed.contains(LogicalKeyboardKey.keyS);
    _keyRight = keysPressed.contains(LogicalKeyboardKey.keyD);

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      fire();
    }

    return KeyEventResult.handled;
  }

  double get _muzzleX => size.x * 0.80;
  double get _muzzleY => size.y * 0.82;

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateClouds(dt);
    _updateParticles(dt);
    _updateFloatingTexts(dt);
    _updateBullets(dt);

    if (!_running || _paused) return;

    const keyboardSpeed = 420.0;
    var kx = 0.0;
    var ky = 0.0;
    if (_keyLeft) kx -= 1;
    if (_keyRight) kx += 1;
    if (_keyUp) ky -= 1;
    if (_keyDown) ky += 1;
    if (kx != 0 || ky != 0) {
      _moveCrosshair(kx * keyboardSpeed * dt, ky * keyboardSpeed * dt);
    }

    if (_muzzleFlash > 0) _muzzleFlash = math.max(0, _muzzleFlash - dt);
    if (_shakeTime > 0) _shakeTime = math.max(0, _shakeTime - dt);

    if (!_missionEnded) {
      if (_timeRemaining != null) {
        _timeRemaining = math.max(0, _timeRemaining! - dt);
        if (_timeRemaining == 0 && _targetsHit < _level.targetGoal) {
          _endMission(success: false, failReason: 'timeUp');
        }
      }

      _updateSlots(dt);
      _updateMovers(dt);

      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnTimer = _level.spawnInterval;
        _trySpawnTarget();
      }
    }

    _hudTimer += dt;
    if (_hudTimer >= 0.08) {
      _hudTimer = 0;
      onHudUpdate(_score, _ammo, _targetsHit, _timeRemaining, _shotsFired, _shotsHit);
    }
  }

  void _updateClouds(double dt) {
    for (final cloud in _clouds) {
      cloud.x -= 0.012 * dt;
      if (cloud.x < -0.2) cloud.x = 1.2;
    }
  }

  void _updateParticles(double dt) {
    for (final particle in _particles) {
      particle.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _updateFloatingTexts(double dt) {
    for (final text in _floatingTexts) {
      text.y -= 40 * dt;
      text.life -= dt;
    }
    _floatingTexts.removeWhere((t) => t.life <= 0);
  }

  void _updateBullets(double dt) {
    for (final bullet in _bullets) {
      bullet.timer += dt;
    }
    _bullets.removeWhere((b) => b.timer >= SniperConfig.bulletFlightDuration);
  }

  double _slotX(int index) {
    final margin = size.x * 0.12;
    final usable = size.x - margin * 2;
    if (SniperConfig.slotCount <= 1) return size.x / 2;
    return margin + usable * (index / (SniperConfig.slotCount - 1));
  }

  double get _groundY => size.y * 0.58;

  void _trySpawnTarget() {
    final wantsMover = _random.nextDouble() < _level.movingRatio;

    if (wantsMover) {
      if (_movers.length >= 2) return;
      final fromLeft = _random.nextBool();
      _movers.add(
        _MovingBandit(
          x: fromLeft ? -40 : size.x + 40,
          y: _groundY - 10 - _random.nextDouble() * 30,
          vx: fromLeft ? _level.targetSpeed : -_level.targetSpeed,
          color: _randomShirt(),
        ),
      );
      return;
    }

    final emptySlots = <int>[
      for (var i = 0; i < _slots.length; i++)
        if (_slots[i] == null) i,
    ];
    if (emptySlots.isEmpty) return;
    final index = emptySlots[_random.nextInt(emptySlots.length)];
    _slots[index] = _BanditTarget(color: _randomShirt());
  }

  Color _randomShirt() {
    const colors = [SniperConfig.banditShirtA, SniperConfig.banditShirtB, SniperConfig.banditShirtC];
    return colors[_random.nextInt(colors.length)];
  }

  void _updateSlots(double dt) {
    for (var i = 0; i < _slots.length; i++) {
      final target = _slots[i];
      if (target == null) continue;

      target.wobble += dt * 3;
      target.phaseTimer += dt;

      switch (target.phase) {
        case _Phase.rising:
          if (target.phaseTimer >= SniperConfig.riseDuration) {
            target.phase = _Phase.holding;
            target.phaseTimer = 0;
          }
          break;
        case _Phase.holding:
          if (target.phaseTimer >= SniperConfig.idleTimeout) {
            target.phase = _Phase.falling;
            target.phaseTimer = 0;
          }
          break;
        case _Phase.falling:
        case _Phase.hit:
          if (target.phaseTimer >= SniperConfig.fallDuration) {
            _slots[i] = null;
          }
          break;
      }
    }
  }

  void _updateMovers(double dt) {
    for (final mover in _movers) {
      if (mover.phase == _Phase.hit) {
        mover.phaseTimer += dt;
      } else {
        mover.x += mover.vx * dt;
        mover.wobble += dt * 6;
      }
    }
    _movers.removeWhere((m) => m.x < -60 || m.x > size.x + 60 || (m.phase == _Phase.hit && m.phaseTimer >= SniperConfig.fallDuration));
  }

  double _popAmount(_BanditTarget target) {
    switch (target.phase) {
      case _Phase.rising:
        return (target.phaseTimer / SniperConfig.riseDuration).clamp(0.0, 1.0);
      case _Phase.holding:
        return 1.0;
      case _Phase.falling:
        return 1 - (target.phaseTimer / SniperConfig.fallDuration).clamp(0.0, 1.0);
      case _Phase.hit:
        return 1.0;
    }
  }

  bool _resolveShot() {
    for (var i = 0; i < _slots.length; i++) {
      final target = _slots[i];
      if (target == null) continue;
      if (target.phase == _Phase.hit || target.phase == _Phase.falling) continue;
      if (target.phase == _Phase.rising && target.phaseTimer < 0.04) continue;

      final tx = _slotX(i);
      final pop = _popAmount(target);
      final ty = _groundY - SniperConfig.targetRadius * 1.5 * pop;
      final dx = _crosshairX - tx;
      final dy = _crosshairY - ty;
      if (dx * dx + dy * dy <= SniperConfig.targetRadius * SniperConfig.targetRadius) {
        target.phase = _Phase.hit;
        target.phaseTimer = 0;
        _registerHit(tx, ty);
        return true;
      }
    }

    for (final mover in _movers) {
      if (mover.phase == _Phase.hit) continue;
      final dx = _crosshairX - mover.x;
      final dy = _crosshairY - mover.y;
      if (dx * dx + dy * dy <= SniperConfig.targetRadius * SniperConfig.targetRadius) {
        mover.phase = _Phase.hit;
        mover.phaseTimer = 0;
        _registerHit(mover.x, mover.y);
        return true;
      }
    }

    return false;
  }

  void _registerHit(double x, double y) {
    _shotsHit++;
    _targetsHit++;
    _score += SniperConfig.targetHitScore;

    _spawnBurst(x, y, SniperConfig.coral, count: 16);
    _spawnFloatingText(x, y, '+${SniperConfig.targetHitScore}', SniperConfig.gold);

    if (_targetsHit >= _level.targetGoal) {
      _endMission(success: true, failReason: null);
    }
  }

  void _endMission({required bool success, required String? failReason}) {
    if (_missionEnded) return;
    _missionEnded = true;
    _running = false;

    var bonus = 0;
    if (success) {
      bonus += _level.completionBonus;
      final accuracy = _shotsFired == 0 ? 0 : ((_shotsHit / _shotsFired) * 100).round();
      if (accuracy >= SniperConfig.accuracyBonusThreshold) {
        bonus += SniperConfig.accuracyBonusPoints;
      }
      _score += bonus;
    }

    onHudUpdate(_score, _ammo, _targetsHit, _timeRemaining, _shotsFired, _shotsHit);
    onMissionEnd(success, _score, bonus, failReason);
  }

  void _spawnBurst(double x, double y, Color color, {required int count}) {
    for (var i = 0; i < count; i++) {
      _particles.add(
        _Particle.burst(x: x, y: y, color: color, random: _random, speed: 150, life: 0.5, size: 4.2),
      );
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color) {
    _floatingTexts.add(_FloatingText(x: x, y: y, text: text, color: color, life: 0.85, maxLife: 0.85));
  }

  // ---------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    canvas.save();
    if (_shakeTime > 0) {
      final power = _shakeTime / SniperConfig.crashShakeDuration;
      final dx = (_random.nextDouble() - 0.5) * SniperConfig.crashShakeMagnitude * power;
      final dy = (_random.nextDouble() - 0.5) * SniperConfig.crashShakeMagnitude * power;
      canvas.translate(dx, dy);
    }

    _renderSky(canvas, w, h);
    _renderCanyon(canvas, w, h);
    _renderGround(canvas, w, h);
    _renderCacti(canvas, w, h);

    for (var i = 0; i < _slots.length; i++) {
      final target = _slots[i];
      if (target != null) {
        _drawBandit(
          canvas,
          _slotX(i),
          _groundY - SniperConfig.targetRadius * 1.5 * _popAmount(target),
          target.color,
          target.wobble,
          target.phase,
          standing: true,
        );
      }
    }
    for (final mover in _movers) {
      _drawBandit(canvas, mover.x, mover.y, mover.color, mover.wobble, mover.phase, standing: false, facingRight: mover.vx > 0);
    }

    _renderBullets(canvas);
    _renderParticles(canvas);
    _renderFloatingTexts(canvas);

    _drawGunAndScope(canvas, w, h);
    _drawCrosshair(canvas);

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
          colors: [SniperConfig.skyTop, SniperConfig.skyBottom],
        ).createShader(rect),
    );
    for (final cloud in _clouds) {
      _drawCloud(canvas, w * cloud.x, h * cloud.y, w * 0.1 * cloud.scale);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double r) {
    final paint = Paint()..color = SniperConfig.cloudColor.withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 2.4, height: r * 0.8), paint);
    canvas.drawCircle(Offset(x - r * 0.5, y), r * 0.55, paint);
    canvas.drawCircle(Offset(x + r * 0.5, y - r * 0.1), r * 0.6, paint);
  }

  void _renderCanyon(Canvas canvas, double w, double h) {
    final far = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.14, h * 0.32)
      ..lineTo(w * 0.28, h * 0.46)
      ..lineTo(w * 0.46, h * 0.28)
      ..lineTo(w * 0.62, h * 0.44)
      ..lineTo(w * 0.8, h * 0.3)
      ..lineTo(w, h * 0.42)
      ..lineTo(w, h * 0.58)
      ..lineTo(0, h * 0.58)
      ..close();
    canvas.drawPath(far, Paint()..color = SniperConfig.canyonFar);

    final near = Path()
      ..moveTo(0, h * 0.56)
      ..lineTo(w * 0.1, h * 0.4)
      ..lineTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.36, h * 0.36)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.7, h * 0.34)
      ..lineTo(w * 0.9, h * 0.48)
      ..lineTo(w, h * 0.4)
      ..lineTo(w, h * 0.6)
      ..lineTo(0, h * 0.6)
      ..close();
    canvas.drawPath(near, Paint()..color = SniperConfig.canyonMid);
  }

  void _renderGround(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, h * 0.58, w, h * 0.42);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SniperConfig.sandLight, SniperConfig.sandDark],
        ).createShader(rect),
    );
  }

  void _renderCacti(Canvas canvas, double w, double h) {
    for (final cactus in _cacti) {
      final x = w * cactus.x;
      final y = _groundY + 14;
      final scale = cactus.scale;
      final trunk = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 5 * scale, y - 46 * scale, 10 * scale, 46 * scale),
        Radius.circular(6 * scale),
      );
      canvas.drawRRect(trunk, Paint()..color = SniperConfig.cactusGreen);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 20 * scale, y - 32 * scale, 15 * scale, 8 * scale),
          Radius.circular(4 * scale),
        ),
        Paint()..color = SniperConfig.cactusDark,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 5 * scale, y - 24 * scale, 15 * scale, 8 * scale),
          Radius.circular(4 * scale),
        ),
        Paint()..color = SniperConfig.cactusDark,
      );
    }
  }

  void _drawBandit(
    Canvas canvas,
    double x,
    double y,
    Color shirt,
    double wobble,
    _Phase phase, {
    required bool standing,
    bool facingRight = true,
  }) {
    final hit = phase == _Phase.hit;
    final wob = standing ? math.sin(wobble) * 2 : math.sin(wobble) * 3;
    final r = SniperConfig.targetRadius;

    canvas.save();
    canvas.translate(x, y);
    if (hit) {
      canvas.rotate((facingRight ? 1 : -1) * math.pi / 2.2);
      canvas.translate(0, r * 0.3);
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.95), width: r * 1.3, height: r * 0.35),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    // Legs.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-r * 0.22, r * 0.62), width: r * 0.32, height: r * 0.7), Radius.circular(r * 0.1)),
      Paint()..color = SniperConfig.navyDeep,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(r * 0.22, r * 0.62), width: r * 0.32, height: r * 0.7), Radius.circular(r * 0.1)),
      Paint()..color = SniperConfig.navyDeep,
    );

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(wob * 0.3, r * 0.1), width: r * 1.05, height: r * 1.15),
        Radius.circular(r * 0.3),
      ),
      Paint()..color = shirt,
    );

    // Head.
    final headCenter = Offset(wob * 0.3, -r * 0.62);
    canvas.drawCircle(headCenter, r * 0.42, Paint()..color = SniperConfig.banditSkin);

    // Hat.
    canvas.drawOval(
      Rect.fromCenter(center: headCenter + Offset(0, -r * 0.06), width: r * 1.05, height: r * 0.28),
      Paint()..color = SniperConfig.banditHat,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: headCenter + Offset(0, -r * 0.34), width: r * 0.5, height: r * 0.42),
        Radius.circular(r * 0.14),
      ),
      Paint()..color = SniperConfig.banditHat,
    );

    // Simple face.
    canvas.drawCircle(headCenter + Offset(-r * 0.14, 0), r * 0.05, Paint()..color = SniperConfig.navyDeep);
    canvas.drawCircle(headCenter + Offset(r * 0.14, 0), r * 0.05, Paint()..color = SniperConfig.navyDeep);

    canvas.restore();
  }

  void _renderBullets(Canvas canvas) {
    for (final bullet in _bullets) {
      final t = (bullet.timer / SniperConfig.bulletFlightDuration).clamp(0.0, 1.0);
      final x = bullet.startX + (bullet.endX - bullet.startX) * t;
      final y = bullet.startY + (bullet.endY - bullet.startY) * t;
      final fade = 1 - t;

      canvas.drawLine(
        Offset(bullet.startX, bullet.startY),
        Offset(x, y),
        Paint()
          ..color = SniperConfig.bulletTrail.withValues(alpha: 0.5 * fade)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = SniperConfig.bulletTrail.withValues(alpha: fade));

      if (t >= 0.98 && bullet.hit) {
        canvas.drawCircle(Offset(bullet.endX, bullet.endY), 14, Paint()..color = Colors.white.withValues(alpha: 0.4 * (1 - t)));
      }
    }
  }

  void _renderParticles(Canvas canvas) {
    for (final particle in _particles) {
      final alpha = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * alpha,
        Paint()..color = particle.color.withValues(alpha: alpha),
      );
    }
  }

  void _renderFloatingTexts(Canvas canvas) {
    for (final text in _floatingTexts) {
      final alpha = (text.life / text.maxLife).clamp(0.0, 1.0);
      final painter = TextPainter(
        text: TextSpan(text: text.text, style: TextStyle(color: text.color.withValues(alpha: alpha), fontWeight: FontWeight.w900, fontSize: 15)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(text.x - painter.width / 2, text.y - painter.height / 2));
    }
  }

  void _drawGunAndScope(Canvas canvas, double w, double h) {
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(-0.36);

    final body = RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.48, -h * 0.10, w * 0.5, h * 0.14), const Radius.circular(18));
    canvas.drawRRect(body, Paint()..color = SniperConfig.gunMetal);
    canvas.drawRRect(
      body,
      Paint()
        ..color = SniperConfig.gunMetalDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.78, -h * 0.055, w * 0.34, h * 0.045), const Radius.circular(8)),
      Paint()..color = SniperConfig.gunMetalDark,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.5, -h * 0.22, w * 0.32, h * 0.09), const Radius.circular(14)),
      Paint()..color = SniperConfig.gunMetalDark,
    );

    final lensCenter = Offset(-w * 0.36, -h * 0.24);
    canvas.drawCircle(lensCenter, 30, Paint()..color = SniperConfig.gunMetalDark);
    canvas.drawCircle(lensCenter, 24, Paint()..color = SniperConfig.scopeGlass.withValues(alpha: 0.85));
    canvas.drawCircle(
      lensCenter,
      24,
      Paint()
        ..color = SniperConfig.scopeGlow.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      lensCenter + const Offset(-16, 0),
      lensCenter + const Offset(16, 0),
      Paint()
        ..color = SniperConfig.navyDeep
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      lensCenter + const Offset(0, -16),
      lensCenter + const Offset(0, 16),
      Paint()
        ..color = SniperConfig.navyDeep
        ..strokeWidth = 1.4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.24, -h * 0.01, w * 0.06, h * 0.12), const Radius.circular(6)),
      Paint()..color = SniperConfig.gunMetalDark,
    );

    if (_muzzleFlash > 0) {
      final flashT = _muzzleFlash / 0.1;
      canvas.drawCircle(
        Offset(-w * 0.78, -h * 0.033),
        18 * flashT,
        Paint()..color = SniperConfig.muzzleFlash.withValues(alpha: 0.8 * flashT),
      );
    }

    canvas.restore();
  }

  void _drawCrosshair(Canvas canvas) {
    final pos = Offset(_crosshairX, _crosshairY);
    final flashScale = 1 + _muzzleFlash * 1.6;

    canvas.drawCircle(pos, 20 * flashScale, Paint()..color = SniperConfig.crosshair.withValues(alpha: 0.12));
    canvas.drawCircle(
      pos,
      15,
      Paint()
        ..color = SniperConfig.crosshair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(pos, 2.2, Paint()..color = SniperConfig.crosshair);

    final linePaint = Paint()
      ..color = SniperConfig.crosshair
      ..strokeWidth = 2;
    canvas.drawLine(pos + const Offset(0, -24), pos + const Offset(0, -9), linePaint);
    canvas.drawLine(pos + const Offset(0, 9), pos + const Offset(0, 24), linePaint);
    canvas.drawLine(pos + const Offset(-24, 0), pos + const Offset(-9, 0), linePaint);
    canvas.drawLine(pos + const Offset(9, 0), pos + const Offset(24, 0), linePaint);
  }
}

class _BanditTarget {
  _BanditTarget({required this.color});
  final Color color;
  _Phase phase = _Phase.rising;
  double phaseTimer = 0;
  double wobble = 0;
}

class _MovingBandit {
  _MovingBandit({required this.x, required this.y, required this.vx, required this.color});
  double x;
  final double y;
  final double vx;
  final Color color;
  _Phase phase = _Phase.holding;
  double phaseTimer = 0;
  double wobble = 0;
}

class _BulletTrail {
  _BulletTrail({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.timer,
    required this.hit,
  });
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  double timer;
  final bool hit;
}

class _Cloud {
  _Cloud({required this.x, required this.y, required this.scale});
  double x;
  final double y;
  final double scale;
}

class _Cactus {
  _Cactus({required this.x, required this.scale});
  final double x;
  final double scale;
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
