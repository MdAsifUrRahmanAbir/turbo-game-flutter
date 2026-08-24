import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sniper_config.dart';

enum _SlotKind { bullseye, decoy, golden }
enum _Phase { rising, holding, falling }

/// A hand-painted, cartoon-styled shooting-gallery precision game.
/// Everything is drawn with [Canvas] primitives (no image assets required)
/// so the whole look can be re-themed from [SniperConfig].
///
/// Aiming: drag anywhere to move the crosshair freely; a quick tap/click
/// fires at that spot. A physical keyboard also works (for web): WASD to
/// move the crosshair, Enter or Space to fire.
class SniperGame extends FlameGame with TapCallbacks, DragCallbacks, KeyboardEvents {
  SniperGame({required this.onHudUpdate, required this.onGameOver});

  /// Fired several times a second while playing so the HUD can stay in
  /// sync without hammering Riverpod every single frame.
  final void Function(
    int score,
    int wave,
    int strikes,
    int combo,
    int ammo,
    bool reloading,
    int shotsFired,
    int shotsHit,
  ) onHudUpdate;

  /// Fired once when a run ends. The final stats are already reflected in
  /// the HUD state via [onHudUpdate], so this is a plain notification.
  final VoidCallback onGameOver;

  final math.Random _random = math.Random();

  final List<_SlotTarget?> _slots = List<_SlotTarget?>.filled(SniperConfig.slotCount, null);
  final List<_Duck> _ducks = <_Duck>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_FloatingText> _floatingTexts = <_FloatingText>[];
  final List<_Bulb> _bulbs = <_Bulb>[];

  double _crosshairX = 0;
  double _crosshairY = 0;
  double _fireFlash = 0;

  bool _keyUp = false;
  bool _keyDown = false;
  bool _keyLeft = false;
  bool _keyRight = false;

  double _spawnTimer = 0;
  double _duckTimer = 0;
  double _hudTimer = 0;
  double _reloadTimer = 0;

  int _score = 0;
  int _wave = 1;
  int _strikes = 0;
  int _combo = 0;
  double _comboTimer = 0;
  int _ammo = SniperConfig.maxAmmo;
  int _shotsFired = 0;
  int _shotsHit = 0;
  int _legitHits = 0;

  bool _running = true;
  bool _paused = false;
  bool _gameOverFired = false;
  double _shakeTime = 0;

  bool get isRunning => _running && !_gameOverFired && !_paused;
  bool get isReloading => _reloadTimer > 0;
  double get reloadCharge =>
      isReloading ? 1 - (_reloadTimer / SniperConfig.reloadDuration).clamp(0.0, 1.0) : 1.0;

  @override
  Color backgroundColor() => SniperConfig.skyTop;

  @override
  Future<void> onLoad() async {
    _crosshairX = size.x / 2;
    _crosshairY = size.y / 2;
    _seedBulbs();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    if (_crosshairX == 0 && _crosshairY == 0) {
      _crosshairX = newSize.x / 2;
      _crosshairY = newSize.y / 2;
    }
  }

  void _seedBulbs() {
    _bulbs.clear();
    for (var i = 0; i < 14; i++) {
      _bulbs.add(_Bulb(x: i / 13, phase: _random.nextDouble() * math.pi * 2));
    }
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

  @override
  void onTapUp(TapUpEvent event) {
    if (!isRunning) return;
    _crosshairX = event.localPosition.x.clamp(20, math.max(20, size.x - 20)).toDouble();
    _crosshairY = event.localPosition.y.clamp(20, math.max(20, size.y - 20)).toDouble();
    fire();
  }

  void fire() {
    if (!isRunning || isReloading || _ammo <= 0) return;

    _ammo--;
    _shotsFired++;
    _fireFlash = 0.12;
    _resolveShot();

    if (_ammo <= 0) {
      _reloadTimer = SniperConfig.reloadDuration;
    }
  }

  void togglePause() {
    if (_gameOverFired) return;
    _paused = !_paused;
  }

  void pauseGame() {
    if (!_gameOverFired) _paused = true;
  }

  void resumeGame() {
    if (!_gameOverFired) _paused = false;
  }

  void resetGame() {
    for (var i = 0; i < _slots.length; i++) {
      _slots[i] = null;
    }
    _ducks.clear();
    _particles.clear();
    _floatingTexts.clear();

    _crosshairX = size.x / 2;
    _crosshairY = size.y / 2;
    _fireFlash = 0;
    _keyUp = _keyDown = _keyLeft = _keyRight = false;

    _spawnTimer = 0;
    _duckTimer = 0;
    _hudTimer = 0;
    _reloadTimer = 0;

    _score = 0;
    _wave = 1;
    _strikes = 0;
    _combo = 0;
    _comboTimer = 0;
    _ammo = SniperConfig.maxAmmo;
    _shotsFired = 0;
    _shotsHit = 0;
    _legitHits = 0;

    _running = true;
    _paused = false;
    _gameOverFired = false;
    _shakeTime = 0;
  }

  // ---------------------------------------------------------------------
  // Keyboard (web/desktop)
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateBulbs(dt);
    _updateParticles(dt);
    _updateFloatingTexts(dt);

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

    if (_fireFlash > 0) _fireFlash = math.max(0, _fireFlash - dt);
    if (_comboTimer > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) _combo = 0;
    }
    if (_shakeTime > 0) _shakeTime = math.max(0, _shakeTime - dt);

    if (_reloadTimer > 0) {
      _reloadTimer = math.max(0, _reloadTimer - dt);
      if (_reloadTimer == 0) _ammo = SniperConfig.maxAmmo;
    }

    _updateSlots(dt);
    _updateDucks(dt);

    _spawnTimer -= dt;
    final interval = math.max(
      SniperConfig.minSpawnInterval,
      SniperConfig.baseSpawnInterval - (_wave - 1) * 0.05,
    );
    if (_spawnTimer <= 0) {
      _spawnTimer = interval;
      _trySpawnSlotTarget();
    }

    _duckTimer -= dt;
    if (_duckTimer <= 0) {
      _duckTimer = SniperConfig.duckSpawnInterval - (_wave - 1) * 0.12;
      _spawnDuck();
    }

    _hudTimer += dt;
    if (_hudTimer >= 0.08) {
      _hudTimer = 0;
      onHudUpdate(_score, _wave, _strikes, _combo, _ammo, isReloading, _shotsFired, _shotsHit);
    }
  }

  void _updateBulbs(double dt) {
    for (final bulb in _bulbs) {
      bulb.phase += dt * 2;
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

  double _slotX(int index) {
    final margin = size.x * 0.1;
    final usable = size.x - margin * 2;
    if (SniperConfig.slotCount <= 1) return size.x / 2;
    return margin + usable * (index / (SniperConfig.slotCount - 1));
  }

  double get _slotY => size.y * 0.6;

  void _trySpawnSlotTarget() {
    final emptySlots = <int>[
      for (var i = 0; i < _slots.length; i++)
        if (_slots[i] == null) i,
    ];
    if (emptySlots.isEmpty) return;

    final index = emptySlots[_random.nextInt(emptySlots.length)];
    final decoyChance = math.min(
      SniperConfig.decoyChanceCap,
      SniperConfig.decoyChanceBase + (_wave - 1) * SniperConfig.decoyChancePerWave,
    );

    final _SlotKind kind;
    if (_random.nextDouble() < SniperConfig.goldenChance) {
      kind = _SlotKind.golden;
    } else if (_random.nextDouble() < decoyChance) {
      kind = _SlotKind.decoy;
    } else {
      kind = _SlotKind.bullseye;
    }

    _slots[index] = _SlotTarget(kind: kind);
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
          final holdLimit =
              target.kind == _SlotKind.golden ? SniperConfig.goldenHoldDuration : SniperConfig.holdDuration;
          if (target.phaseTimer >= holdLimit) {
            target.phase = _Phase.falling;
            target.phaseTimer = 0;
          }
          break;
        case _Phase.falling:
          if (target.phaseTimer >= SniperConfig.fallDuration) {
            _slots[i] = null;
          }
          break;
      }
    }
  }

  void _spawnDuck() {
    if (size.x <= 0) return;
    final fromLeft = _random.nextBool();
    final speed = SniperConfig.duckSpeedBase + (_wave - 1) * SniperConfig.duckSpeedPerWave;
    _ducks.add(
      _Duck(
        x: fromLeft ? -40 : size.x + 40,
        y: size.y * (0.30 + _random.nextDouble() * 0.12),
        vx: fromLeft ? speed : -speed,
      ),
    );
  }

  void _updateDucks(double dt) {
    for (final duck in _ducks) {
      duck.x += duck.vx * dt;
      duck.wobble += dt * 6;
    }
    _ducks.removeWhere((d) => d.x < -60 || d.x > size.x + 60);
  }

  void _resolveShot() {
    // Slot targets (bullseye / decoy / golden) take priority since they're
    // usually the intended target when overlapping with a duck's flight path.
    for (var i = 0; i < _slots.length; i++) {
      final target = _slots[i];
      if (target == null) continue;
      if (target.phase == _Phase.rising && target.phaseTimer < 0.05) continue;

      final tx = _slotX(i);
      final ty = _slotY;
      final popAmount = _popAmount(target);
      if (popAmount <= 0.1) continue;

      final radius = target.kind == _SlotKind.golden ? SniperConfig.goldenRadius : SniperConfig.targetRadius;
      final dx = _crosshairX - tx;
      final dy = _crosshairY - (ty - radius * 1.4 * popAmount);
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist <= radius) {
        _shotsHit++;
        _handleSlotHit(i, target, dist, radius);
        return;
      }
    }

    for (final duck in _ducks) {
      final dx = _crosshairX - duck.x;
      final dy = _crosshairY - duck.y;
      if (dx * dx + dy * dy <= SniperConfig.duckRadius * SniperConfig.duckRadius) {
        _shotsHit++;
        duck.dead = true;
        _onLegitHit(duck.x, duck.y, SniperConfig.duckScore, SniperConfig.duckBody);
        _ducks.removeWhere((d) => d.dead);
        return;
      }
    }

    // Clean miss.
    _combo = 0;
    _comboTimer = 0;
  }

  double _popAmount(_SlotTarget target) {
    switch (target.phase) {
      case _Phase.rising:
        return (target.phaseTimer / SniperConfig.riseDuration).clamp(0.0, 1.0);
      case _Phase.holding:
        return 1.0;
      case _Phase.falling:
        return 1 - (target.phaseTimer / SniperConfig.fallDuration).clamp(0.0, 1.0);
    }
  }

  void _handleSlotHit(int index, _SlotTarget target, double dist, double radius) {
    final tx = _slotX(index);
    final ty = _slotY - radius * 1.4 * _popAmount(target);

    switch (target.kind) {
      case _SlotKind.decoy:
        _strikes++;
        _combo = 0;
        _comboTimer = 0;
        _score = math.max(0, _score - SniperConfig.decoyPenalty);
        _shakeTime = SniperConfig.crashShakeDuration;
        _spawnBurst(tx, ty, SniperConfig.coral, count: 16);
        _spawnFloatingText(tx, ty, '-${SniperConfig.decoyPenalty} OOPS!', SniperConfig.coral);
        _slots[index] = null;
        if (_strikes >= SniperConfig.maxStrikes) {
          _endGame();
        }
        break;
      case _SlotKind.golden:
        _onLegitHit(tx, ty, SniperConfig.goldenScore, SniperConfig.goldenMid);
        _slots[index] = null;
        break;
      case _SlotKind.bullseye:
        final value = dist <= radius * 0.28
            ? SniperConfig.bullseyeCenterScore
            : dist <= radius * 0.6
                ? SniperConfig.bullseyeMidScore
                : SniperConfig.bullseyeOuterScore;
        final label = dist <= radius * 0.28 ? 'BULLSEYE!' : null;
        _onLegitHit(tx, ty, value, SniperConfig.bullseyeRed, label: label);
        _slots[index] = null;
        break;
    }
  }

  void _onLegitHit(double x, double y, int baseValue, Color color, {String? label}) {
    _legitHits++;
    _wave = 1 + (_legitHits ~/ SniperConfig.hitsPerWave);

    _combo = math.min(SniperConfig.maxComboStacks, _combo + 1);
    _comboTimer = SniperConfig.comboWindow;

    final multiplier = 1 + (_combo - 1) * SniperConfig.comboScoreStep;
    final gained = (baseValue * multiplier).round();
    _score += gained;

    _spawnBurst(x, y, color, count: 16);
    _spawnFloatingText(x, y, label ?? '+$gained', SniperConfig.gold);
    if (label != null) {
      _spawnFloatingText(x, y - 22, '+$gained', SniperConfig.gold);
    }
    if (_combo >= 3) {
      _spawnFloatingText(x, y - (label != null ? 44 : 22), 'x$_combo COMBO', SniperConfig.teal);
    }
  }

  void _endGame() {
    if (_gameOverFired) return;
    _gameOverFired = true;
    _running = false;
    onHudUpdate(_score, _wave, _strikes, _combo, _ammo, isReloading, _shotsFired, _shotsHit);
    onGameOver();
  }

  void _spawnBurst(double x, double y, Color color, {required int count}) {
    for (var i = 0; i < count; i++) {
      _particles.add(
        _Particle.burst(x: x, y: y, color: color, random: _random, speed: 160, life: 0.55, size: 4.5),
      );
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color) {
    _floatingTexts.add(_FloatingText(x: x, y: y, text: text, color: color, life: 0.9, maxLife: 0.9));
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
      final power = _shakeTime / SniperConfig.crashShakeDuration;
      final dx = (_random.nextDouble() - 0.5) * SniperConfig.crashShakeMagnitude * power;
      final dy = (_random.nextDouble() - 0.5) * SniperConfig.crashShakeMagnitude * power;
      canvas.translate(dx, dy);
    }

    _renderSky(canvas, w, h);
    _renderBulbs(canvas, w, h);
    _renderWall(canvas, w, h);

    for (var i = 0; i < _slots.length; i++) {
      final target = _slots[i];
      if (target != null) _drawSlotTarget(canvas, i, target);
    }
    for (final duck in _ducks) {
      _drawDuck(canvas, duck);
    }

    _renderParticles(canvas);
    _renderFloatingTexts(canvas);
    _drawCrosshair(canvas);

    if (_strikes >= SniperConfig.maxStrikes - 1 && !_gameOverFired) {
      _renderWarningVignette(canvas, w, h);
    }

    canvas.restore();
  }

  void _renderSky(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [SniperConfig.skyTop, SniperConfig.skyMid, SniperConfig.skyBottom],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, gradient);
  }

  void _renderBulbs(Canvas canvas, double w, double h) {
    final y = h * 0.08;
    for (final bulb in _bulbs) {
      final glow = 0.6 + math.sin(bulb.phase).abs() * 0.4;
      final x = w * bulb.x;
      canvas.drawCircle(Offset(x, y), 10 * glow, Paint()..color = SniperConfig.bulbGlow.withValues(alpha: 0.3 * glow));
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = SniperConfig.bulbGlow);
    }
    canvas.drawLine(
      Offset(0, y),
      Offset(w, y),
      Paint()
        ..color = SniperConfig.navyDeep.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );
  }

  void _renderWall(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, h * 0.42, w, h * 0.58);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SniperConfig.wallLight, SniperConfig.wallDark],
        ).createShader(rect),
    );

    final plankPaint = Paint()
      ..color = SniperConfig.navyDeep.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    for (var i = 1; i < 8; i++) {
      final x = w * (i / 8);
      canvas.drawLine(Offset(x, h * 0.42), Offset(x, h), plankPaint);
    }

    for (var i = 0; i < _slots.length; i++) {
      final x = _slotX(i);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, h * 0.86), width: 10, height: h * 0.28),
        Paint()..color = SniperConfig.postColor,
      );
    }
  }

  void _drawSlotTarget(Canvas canvas, int index, _SlotTarget target) {
    final pop = _popAmount(target);
    if (pop <= 0) return;

    final x = _slotX(index);
    final radius = target.kind == _SlotKind.golden ? SniperConfig.goldenRadius : SniperConfig.targetRadius;
    final y = _slotY - radius * 1.4 * pop;
    final wobble = math.sin(target.wobble) * 2;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, _slotY + 6), width: radius * 1.4, height: radius * 0.4),
      Paint()..color = Colors.black.withValues(alpha: 0.2 * pop),
    );

    switch (target.kind) {
      case _SlotKind.bullseye:
        canvas.drawCircle(Offset(x + wobble, y), radius, Paint()..color = SniperConfig.bullseyeWhite);
        canvas.drawCircle(Offset(x + wobble, y), radius * 0.72, Paint()..color = SniperConfig.bullseyeRed);
        canvas.drawCircle(Offset(x + wobble, y), radius * 0.42, Paint()..color = SniperConfig.bullseyeWhite);
        canvas.drawCircle(Offset(x + wobble, y), radius * 0.18, Paint()..color = SniperConfig.bullseyeRed);
        canvas.drawCircle(
          Offset(x + wobble, y),
          radius,
          Paint()
            ..color = SniperConfig.navyDeep
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
        break;
      case _SlotKind.decoy:
        canvas.drawCircle(Offset(x + wobble, y), radius, Paint()..color = SniperConfig.decoyBody);
        canvas.drawCircle(
          Offset(x + wobble, y),
          radius,
          Paint()
            ..color = SniperConfig.navyDeep
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        // Friendly cartoon dove face.
        canvas.drawCircle(Offset(x + wobble - radius * 0.22, y - radius * 0.1), radius * 0.13, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x + wobble + radius * 0.22, y - radius * 0.1), radius * 0.13, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x + wobble - radius * 0.2, y - radius * 0.08), radius * 0.06, Paint()..color = SniperConfig.navyDeep);
        canvas.drawCircle(Offset(x + wobble + radius * 0.24, y - radius * 0.08), radius * 0.06, Paint()..color = SniperConfig.navyDeep);
        final beak = Path()
          ..moveTo(x + wobble, y + radius * 0.06)
          ..lineTo(x + wobble - radius * 0.1, y + radius * 0.2)
          ..lineTo(x + wobble + radius * 0.1, y + radius * 0.2)
          ..close();
        canvas.drawPath(beak, Paint()..color = SniperConfig.decoyAccent);
        // "Do not shoot" band.
        canvas.drawLine(
          Offset(x + wobble - radius, y + radius * 0.55),
          Offset(x + wobble + radius, y + radius * 0.55),
          Paint()
            ..color = Colors.white
            ..strokeWidth = radius * 0.28,
        );
        canvas.drawLine(
          Offset(x + wobble - radius, y + radius * 0.55),
          Offset(x + wobble + radius, y + radius * 0.55),
          Paint()
            ..color = SniperConfig.decoyAccent
            ..strokeWidth = radius * 0.14,
        );
        break;
      case _SlotKind.golden:
        final glow = 0.6 + math.sin(target.wobble * 2).abs() * 0.4;
        canvas.drawCircle(Offset(x, y), radius * 1.5 * glow, Paint()..color = SniperConfig.goldenOuter.withValues(alpha: 0.25));
        _drawStar(canvas, Offset(x + wobble, y), radius, SniperConfig.goldenMid);
        canvas.drawCircle(Offset(x + wobble, y), radius * 0.35, Paint()..color = SniperConfig.goldenCore);
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * 0.45;
      final point = Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = SniperConfig.navyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawDuck(Canvas canvas, _Duck duck) {
    final bob = math.sin(duck.wobble) * 4;
    final x = duck.x;
    final y = duck.y + bob;
    final facingRight = duck.vx > 0;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, duck.y + SniperConfig.duckRadius * 0.9), width: SniperConfig.duckRadius * 1.6, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    canvas.drawCircle(Offset(x, y), SniperConfig.duckRadius, Paint()..color = SniperConfig.duckBody);
    canvas.drawCircle(
      Offset(x, y),
      SniperConfig.duckRadius,
      Paint()
        ..color = SniperConfig.navyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final headX = x + (facingRight ? SniperConfig.duckRadius * 0.55 : -SniperConfig.duckRadius * 0.55);
    canvas.drawCircle(Offset(headX, y - SniperConfig.duckRadius * 0.4), SniperConfig.duckRadius * 0.55, Paint()..color = SniperConfig.duckBody);

    final beakDir = facingRight ? 1 : -1;
    final beak = Path()
      ..moveTo(headX + beakDir * SniperConfig.duckRadius * 0.5, y - SniperConfig.duckRadius * 0.4)
      ..lineTo(headX + beakDir * SniperConfig.duckRadius * 0.9, y - SniperConfig.duckRadius * 0.32)
      ..lineTo(headX + beakDir * SniperConfig.duckRadius * 0.5, y - SniperConfig.duckRadius * 0.2)
      ..close();
    canvas.drawPath(beak, Paint()..color = SniperConfig.duckAccent);

    canvas.drawCircle(
      Offset(headX + beakDir * SniperConfig.duckRadius * 0.15, y - SniperConfig.duckRadius * 0.5),
      SniperConfig.duckRadius * 0.1,
      Paint()..color = SniperConfig.navyDeep,
    );
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
        text: TextSpan(
          text: text.text,
          style: TextStyle(color: text.color.withValues(alpha: alpha), fontWeight: FontWeight.w900, fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(text.x - painter.width / 2, text.y - painter.height / 2));
    }
  }

  void _drawCrosshair(Canvas canvas) {
    final pos = Offset(_crosshairX, _crosshairY);
    final flashScale = 1 + _fireFlash * 2.2;
    final color = _fireFlash > 0 ? SniperConfig.crosshairFire : SniperConfig.crosshair;

    canvas.drawCircle(pos, 22 * flashScale, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(
      pos,
      16,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(pos, 2.4, Paint()..color = color);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2;
    canvas.drawLine(pos + const Offset(0, -26), pos + const Offset(0, -10), linePaint);
    canvas.drawLine(pos + const Offset(0, 10), pos + const Offset(0, 26), linePaint);
    canvas.drawLine(pos + const Offset(-26, 0), pos + const Offset(-10, 0), linePaint);
    canvas.drawLine(pos + const Offset(10, 0), pos + const Offset(26, 0), linePaint);
  }

  void _renderWarningVignette(Canvas canvas, double w, double h) {
    final pulse = 0.14 + math.sin(_hudTimer * 30).abs() * 0.1;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, SniperConfig.coral.withValues(alpha: pulse)],
        stops: const [0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

class _SlotTarget {
  _SlotTarget({required this.kind});
  final _SlotKind kind;
  _Phase phase = _Phase.rising;
  double phaseTimer = 0;
  double wobble = 0;
}

class _Duck {
  _Duck({required this.x, required this.y, required this.vx});
  double x;
  final double y;
  final double vx;
  double wobble = 0;
  bool dead = false;
}

class _Bulb {
  _Bulb({required this.x, required this.phase});
  final double x;
  double phase;
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
