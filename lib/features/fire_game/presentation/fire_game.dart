import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fire_game_config.dart';

enum _EnemyKind { imp, boss }

/// A hand-painted, cartoon-styled fire-survival shooter. Everything is
/// drawn with [Canvas] primitives (no image assets required) so the whole
/// look can be re-themed from [FireGameConfig].
///
/// Supports both on-screen touch controls and a physical keyboard (for web):
/// A/D to move, and Enter or Space to shoot.
class FireGame extends FlameGame with TapCallbacks, KeyboardEvents {
  FireGame({required this.onHudUpdate, required this.onGameOver});

  /// Fired several times a second while playing so the HUD can stay in
  /// sync without hammering Riverpod every single frame.
  final void Function(
    int score,
    int health,
    int wave,
    int enemiesDefeated,
    int combo,
    double tripleShotCharge,
  ) onHudUpdate;

  /// Fired once when a run ends. The final stats are already reflected in
  /// the HUD state via [onHudUpdate], so this is a plain notification.
  final VoidCallback onGameOver;

  final math.Random _random = math.Random();

  final List<_Enemy> _enemies = <_Enemy>[];
  final List<_Fireball> _fireballs = <_Fireball>[];
  final List<_Powerup> _powerups = <_Powerup>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_FloatingText> _floatingTexts = <_FloatingText>[];
  final List<_Ember> _embers = <_Ember>[];
  final Set<int> _bossWavesSpawned = <int>{};

  double _playerX = 0;
  double _bobTime = 0;
  double _recoilTimer = 0;
  double _tiltX = 0;
  bool _left = false;
  bool _right = false;

  double _spawnTimer = 0;
  double _hudTimer = 0;

  int _score = 0;
  int _health = FireGameConfig.maxHealth;
  int _wave = 1;
  int _enemiesDefeated = 0;
  int _combo = 0;
  double _comboTimer = 0;
  double _tripleShotTimer = 0;

  bool _running = true;
  bool _paused = false;
  bool _gameOverFired = false;
  double _shakeTime = 0;

  bool get isRunning => _running && !_gameOverFired && !_paused;
  bool get isPausedByUser => _paused && !_gameOverFired;
  double get tripleShotCharge =>
      (_tripleShotTimer / FireGameConfig.tripleShotDuration).clamp(0.0, 1.0);

  @override
  Color backgroundColor() => FireGameConfig.skyTop;

  @override
  Future<void> onLoad() async {
    _playerX = size.x / 2;
    _seedEmbers();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_playerX == 0) _playerX = size.x / 2;
  }

  void _seedEmbers() {
    _embers.clear();
    for (var i = 0; i < 22; i++) {
      _embers.add(
        _Ember(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          speed: 0.03 + _random.nextDouble() * 0.06,
          drift: (_random.nextDouble() - 0.5) * 0.01,
          size: 1.4 + _random.nextDouble() * 2.6,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------

  void steerLeft(bool active) => _left = active;
  void steerRight(bool active) => _right = active;

  void shoot() {
    if (!isRunning) return;
    _recoilTimer = 0.12;
    final y = _playerTopY();
    if (_tripleShotTimer > 0) {
      _spawnFireball(_playerX, y, angleOffset: -0.30);
      _spawnFireball(_playerX, y, angleOffset: 0);
      _spawnFireball(_playerX, y, angleOffset: 0.30);
    } else {
      _spawnFireball(_playerX, y, angleOffset: 0);
    }
  }

  double _playerTopY() => size.y - 100 - FireGameConfig.playerSize * 0.55;
  double get _playerCenterY => size.y - 100;

  void _spawnFireball(double x, double y, {required double angleOffset}) {
    _fireballs.add(
      _Fireball(
        x: x,
        y: y,
        vx: math.sin(angleOffset) * FireGameConfig.fireballSpeed,
        vy: -math.cos(angleOffset) * FireGameConfig.fireballSpeed,
      ),
    );
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
    _enemies.clear();
    _fireballs.clear();
    _powerups.clear();
    _particles.clear();
    _floatingTexts.clear();
    _bossWavesSpawned.clear();

    _playerX = size.x / 2;
    _bobTime = 0;
    _recoilTimer = 0;
    _tiltX = 0;
    _left = false;
    _right = false;

    _spawnTimer = 0;
    _hudTimer = 0;

    _score = 0;
    _health = FireGameConfig.maxHealth;
    _wave = 1;
    _enemiesDefeated = 0;
    _combo = 0;
    _comboTimer = 0;
    _tripleShotTimer = 0;

    _running = true;
    _paused = false;
    _gameOverFired = false;
    _shakeTime = 0;
  }

  @override
  void onTapDown(TapDownEvent event) => shoot();

  // ---------------------------------------------------------------------
  // Keyboard (web/desktop)
  // ---------------------------------------------------------------------

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    steerLeft(keysPressed.contains(LogicalKeyboardKey.keyA));
    steerRight(keysPressed.contains(LogicalKeyboardKey.keyD));

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      shoot();
    }

    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _updateEmbers(dt);
    _updateParticles(dt);
    _updateFloatingTexts(dt);

    if (!_running || _paused) return;

    _bobTime += dt;
    if (_recoilTimer > 0) _recoilTimer = math.max(0, _recoilTimer - dt);
    if (_tripleShotTimer > 0) _tripleShotTimer = math.max(0, _tripleShotTimer - dt);
    if (_comboTimer > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) _combo = 0;
    }
    if (_shakeTime > 0) _shakeTime = math.max(0, _shakeTime - dt);

    if (_left) _playerX -= FireGameConfig.playerSpeed * dt;
    if (_right) _playerX += FireGameConfig.playerSpeed * dt;
    final halfPlayer = FireGameConfig.playerSize / 2;
    _playerX = _playerX.clamp(halfPlayer, math.max(halfPlayer, size.x - halfPlayer)).toDouble();
    _tiltX = _left ? -1.0 : (_right ? 1.0 : 0.0);

    _spawnTimer -= dt;
    final interval = math.max(
      FireGameConfig.minSpawnInterval,
      FireGameConfig.baseSpawnInterval - (_wave - 1) * 0.07,
    );
    if (_spawnTimer <= 0) {
      _spawnTimer = interval;
      _spawnEnemy();
    }

    _updateFireballs(dt);
    _updateEnemies(dt);
    _updatePowerups(dt);

    _hudTimer += dt;
    if (_hudTimer >= 0.08) {
      _hudTimer = 0;
      onHudUpdate(_score, _health, _wave, _enemiesDefeated, _combo, tripleShotCharge);
    }
  }

  void _updateEmbers(double dt) {
    for (final ember in _embers) {
      ember.y -= ember.speed * dt;
      ember.x += ember.drift * dt;
      if (ember.y < -0.05) {
        ember.y = 1.05;
        ember.x = _random.nextDouble();
      }
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

  void _spawnEnemy() {
    if (size.x <= 0) return;
    final isBossWave = _wave % FireGameConfig.bossEveryNWaves == 0;

    if (isBossWave && !_bossWavesSpawned.contains(_wave)) {
      _bossWavesSpawned.add(_wave);
      _enemies.add(
        _Enemy(
          x: size.x / 2,
          y: -70,
          speed: FireGameConfig.baseEnemySpeed * FireGameConfig.bossSpeedMultiplier +
              (_wave - 1) * FireGameConfig.enemySpeedPerWave * 0.4,
          kind: _EnemyKind.boss,
          color: FireGameConfig.bossColor,
          maxHits: FireGameConfig.bossHitsToKill,
        ),
      );
      return;
    }

    final x = 30 + _random.nextDouble() * math.max(1, size.x - 60);
    _enemies.add(
      _Enemy(
        x: x,
        y: -40,
        speed: FireGameConfig.baseEnemySpeed + (_wave - 1) * FireGameConfig.enemySpeedPerWave,
        kind: _EnemyKind.imp,
        color: FireGameConfig.enemyPalette[_random.nextInt(FireGameConfig.enemyPalette.length)],
        maxHits: 1,
      ),
    );
  }

  void _updateFireballs(double dt) {
    for (final fireball in _fireballs) {
      fireball.x += fireball.vx * dt;
      fireball.y += fireball.vy * dt;
      fireball.trailTimer += dt;
      if (fireball.trailTimer > 0.024) {
        fireball.trailTimer = 0;
        _particles.add(
          _Particle(
            x: fireball.x,
            y: fireball.y,
            vx: (_random.nextDouble() - 0.5) * 18,
            vy: 26,
            color: FireGameConfig.emberParticle,
            life: 0.28,
            maxLife: 0.28,
            size: 3 + _random.nextDouble() * 2,
          ),
        );
      }
    }
    _fireballs.removeWhere(
      (f) => f.y < -30 || f.x < -30 || f.x > size.x + 30,
    );
  }

  void _updateEnemies(double dt) {
    for (final enemy in _enemies) {
      enemy.y += enemy.speed * dt;
      enemy.wobble += dt * 5;
    }

    // Fireball vs enemy collisions.
    for (final fireball in _fireballs) {
      if (fireball.dead) continue;
      for (final enemy in _enemies) {
        if (enemy.dead) continue;
        final dx = fireball.x - enemy.x;
        final dy = fireball.y - enemy.y;
        final hitRadius = enemy.radius + 9;
        if (dx * dx + dy * dy < hitRadius * hitRadius) {
          fireball.dead = true;
          enemy.hits++;
          _spawnHitSpark(fireball.x, fireball.y, enemy.color);
          if (enemy.hits >= enemy.maxHits) {
            enemy.dead = true;
            _onEnemyDefeated(enemy);
          }
          break;
        }
      }
    }
    _fireballs.removeWhere((f) => f.dead);

    // Enemy vs player collisions.
    for (final enemy in _enemies) {
      if (enemy.dead) continue;
      final dx = enemy.x - _playerX;
      final dy = enemy.y - _playerCenterY;
      final hitRadius = enemy.radius + FireGameConfig.playerSize * 0.4;
      if (dx * dx + dy * dy < hitRadius * hitRadius) {
        enemy.dead = true;
        _damagePlayer();
        continue;
      }
    }

    // Enemies that reached the bottom without being stopped.
    for (final enemy in _enemies) {
      if (enemy.dead) continue;
      if (enemy.y > size.y + 60) {
        enemy.dead = true;
        _damagePlayer();
      }
    }

    _enemies.removeWhere((e) => e.dead);
  }

  void _onEnemyDefeated(_Enemy enemy) {
    _enemiesDefeated++;
    _wave = 1 + (_enemiesDefeated ~/ FireGameConfig.enemiesPerWave);

    _combo = math.min(FireGameConfig.maxComboStacks, _combo + 1);
    _comboTimer = FireGameConfig.comboWindow;

    final baseValue = enemy.kind == _EnemyKind.boss ? 100 : 10;
    final multiplier = 1 + (_combo - 1) * FireGameConfig.comboScoreStep;
    final gained = (baseValue * multiplier).round();
    _score += gained;

    _spawnBurst(enemy.x, enemy.y, enemy.color, count: enemy.kind == _EnemyKind.boss ? 30 : 16);
    _spawnFloatingText(enemy.x, enemy.y, '+$gained', FireGameConfig.gold);
    if (_combo >= 3) {
      _spawnFloatingText(enemy.x, enemy.y - 22, 'x$_combo COMBO', FireGameConfig.tripleShotColor);
    }

    if (_random.nextDouble() < FireGameConfig.powerupDropChance) {
      _spawnPowerup(enemy.x, enemy.y);
    }
  }

  void _spawnPowerup(double x, double y) {
    final wantHeart = _health < FireGameConfig.maxHealth && _random.nextBool();
    _powerups.add(_Powerup(x: x, y: y, isHeart: wantHeart));
  }

  void _updatePowerups(double dt) {
    for (final powerup in _powerups) {
      powerup.y += 120 * dt;
      powerup.pulse += dt * 4;
    }
    _powerups.removeWhere((p) => p.y > size.y + 40);

    _powerups.removeWhere((powerup) {
      final dx = powerup.x - _playerX;
      final dy = powerup.y - _playerCenterY;
      final catchRadius = FireGameConfig.playerSize * 0.6;
      if (dx * dx + dy * dy < catchRadius * catchRadius) {
        if (powerup.isHeart) {
          _health = math.min(FireGameConfig.maxHealth, _health + FireGameConfig.heartHealAmount);
          _spawnFloatingText(powerup.x, powerup.y, '+HP', FireGameConfig.heartColor);
          _spawnBurst(powerup.x, powerup.y, FireGameConfig.heartColor, count: 12);
        } else {
          _tripleShotTimer = FireGameConfig.tripleShotDuration;
          _spawnFloatingText(powerup.x, powerup.y, 'TRIPLE SHOT!', FireGameConfig.tripleShotColor);
          _spawnBurst(powerup.x, powerup.y, FireGameConfig.tripleShotColor, count: 16);
        }
        return true;
      }
      return false;
    });
  }

  void _damagePlayer() {
    if (_gameOverFired) return;
    _health -= FireGameConfig.damagePerHit;
    _shakeTime = FireGameConfig.crashShakeDuration;
    _combo = 0;
    _comboTimer = 0;
    _spawnBurst(_playerX, _playerCenterY, FireGameConfig.coral, count: 10);

    if (_health <= 0) {
      _health = 0;
      _gameOverFired = true;
      _running = false;
      onHudUpdate(_score, _health, _wave, _enemiesDefeated, _combo, tripleShotCharge);
      onGameOver();
    }
  }

  void _spawnHitSpark(double x, double y, Color color) {
    for (var i = 0; i < 6; i++) {
      _particles.add(
        _Particle.burst(x: x, y: y, color: color, random: _random, speed: 90, life: 0.3, size: 3),
      );
    }
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
      final power = _shakeTime / FireGameConfig.crashShakeDuration;
      final dx = (_random.nextDouble() - 0.5) * FireGameConfig.crashShakeMagnitude * power;
      final dy = (_random.nextDouble() - 0.5) * FireGameConfig.crashShakeMagnitude * power;
      canvas.translate(dx, dy);
    }

    _renderSky(canvas, w, h);
    _renderMountains(canvas, w, h);
    _renderEmbers(canvas, w, h);
    _renderGround(canvas, w, h);

    for (final powerup in _powerups) {
      _drawPowerup(canvas, powerup);
    }
    for (final enemy in _enemies) {
      _drawEnemy(canvas, enemy);
    }
    for (final fireball in _fireballs) {
      _drawFireball(canvas, fireball);
    }
    _renderParticles(canvas);

    if (!_gameOverFired) {
      _drawPlayer(canvas, w, h);
    }

    _renderFloatingTexts(canvas);

    if (_health <= FireGameConfig.maxHealth * 0.25 && !_gameOverFired) {
      _renderLowHealthVignette(canvas, w, h);
    }

    canvas.restore();
  }

  void _renderSky(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [FireGameConfig.skyTop, FireGameConfig.skyMid, FireGameConfig.skyBottom],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, gradient);

    final sunPulse = 0.85 + math.sin(_bobTime * 1.2) * 0.15;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.14 * sunPulse,
      Paint()..color = FireGameConfig.sunGlow.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.20 * sunPulse,
      Paint()..color = FireGameConfig.sunGlow.withValues(alpha: 0.22),
    );
  }

  void _renderMountains(Canvas canvas, double w, double h) {
    final far = Path()
      ..moveTo(0, h * 0.62)
      ..lineTo(w * 0.18, h * 0.46)
      ..lineTo(w * 0.34, h * 0.58)
      ..lineTo(w * 0.52, h * 0.42)
      ..lineTo(w * 0.7, h * 0.56)
      ..lineTo(w * 0.86, h * 0.44)
      ..lineTo(w, h * 0.55)
      ..lineTo(w, h * 0.66)
      ..lineTo(0, h * 0.66)
      ..close();
    canvas.drawPath(far, Paint()..color = FireGameConfig.mountainFar);

    final near = Path()
      ..moveTo(0, h * 0.68)
      ..lineTo(w * 0.22, h * 0.55)
      ..lineTo(w * 0.4, h * 0.66)
      ..lineTo(w * 0.6, h * 0.5)
      ..lineTo(w * 0.8, h * 0.64)
      ..lineTo(w, h * 0.58)
      ..lineTo(w, h * 0.7)
      ..lineTo(0, h * 0.7)
      ..close();
    canvas.drawPath(near, Paint()..color = FireGameConfig.mountainNear);
  }

  void _renderEmbers(Canvas canvas, double w, double h) {
    for (final ember in _embers) {
      canvas.drawCircle(
        Offset(w * ember.x, h * ember.y),
        ember.size,
        Paint()..color = FireGameConfig.emberParticle.withValues(alpha: 0.55),
      );
    }
  }

  void _renderGround(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(0, h * 0.68, w, h * 0.32);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FireGameConfig.groundLight, FireGameConfig.groundDark],
        ).createShader(rect),
    );

    final crackPaint = Paint()
      ..color = FireGameConfig.lavaCrack.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      final startX = w * (0.15 + i * 0.24);
      final path = Path()..moveTo(startX, h * 0.7);
      path.lineTo(startX + w * 0.03, h * 0.78);
      path.lineTo(startX - w * 0.02, h * 0.86);
      path.lineTo(startX + w * 0.02, h * 0.95);
      canvas.drawPath(path, crackPaint);
    }
  }

  void _drawFireball(Canvas canvas, _Fireball fireball) {
    final pos = Offset(fireball.x, fireball.y);
    canvas.drawCircle(pos, 14, Paint()..color = FireGameConfig.fireballOuter.withValues(alpha: 0.35));
    canvas.drawCircle(pos, 9, Paint()..color = FireGameConfig.fireballMid);
    canvas.drawCircle(pos, 4.5, Paint()..color = FireGameConfig.fireballCore);
  }

  void _drawEnemy(Canvas canvas, _Enemy enemy) {
    final isBoss = enemy.kind == _EnemyKind.boss;
    final scale = isBoss ? FireGameConfig.bossSize : 1.0;
    final r = enemy.radius;
    final wobble = math.sin(enemy.wobble) * 3 * scale;
    final x = enemy.x + wobble;
    final y = enemy.y;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y + r * 0.9), width: r * 1.6, height: r * 0.5),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    if (isBoss) {
      for (var i = -1; i <= 1; i++) {
        final spike = Path()
          ..moveTo(x + i * r * 0.5, y - r * 0.7)
          ..lineTo(x + i * r * 0.5 - 6, y - r * 1.05)
          ..lineTo(x + i * r * 0.5 + 6, y - r * 1.05)
          ..close();
        canvas.drawPath(spike, Paint()..color = FireGameConfig.bossAccent);
      }
    }

    canvas.drawCircle(Offset(x, y), r, Paint()..color = enemy.color);
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..color = FireGameConfig.navyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, r * 0.09),
    );
    canvas.drawCircle(
      Offset(x - r * 0.3, y - r * 0.3),
      r * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // Angry eyebrows.
    final browPaint = Paint()
      ..color = FireGameConfig.navyDeep
      ..strokeWidth = math.max(1.6, r * 0.1)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - r * 0.42, y - r * 0.28), Offset(x - r * 0.12, y - r * 0.12), browPaint);
    canvas.drawLine(Offset(x + r * 0.42, y - r * 0.28), Offset(x + r * 0.12, y - r * 0.12), browPaint);

    // Eyes.
    canvas.drawCircle(Offset(x - r * 0.28, y - r * 0.02), r * 0.15, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x + r * 0.28, y - r * 0.02), r * 0.15, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x - r * 0.26, y), r * 0.07, Paint()..color = FireGameConfig.navyDeep);
    canvas.drawCircle(Offset(x + r * 0.30, y), r * 0.07, Paint()..color = FireGameConfig.navyDeep);

    // Mouth.
    final mouth = Path()
      ..moveTo(x - r * 0.22, y + r * 0.3)
      ..quadraticBezierTo(x, y + r * 0.5, x + r * 0.22, y + r * 0.3);
    canvas.drawPath(
      mouth,
      Paint()
        ..color = FireGameConfig.navyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, r * 0.08),
    );

    if (isBoss) {
      final pipWidth = r * 0.32;
      final totalWidth = pipWidth * enemy.maxHits + 4 * (enemy.maxHits - 1);
      final startX = x - totalWidth / 2;
      for (var i = 0; i < enemy.maxHits; i++) {
        final filled = i >= enemy.hits;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(startX + i * (pipWidth + 4), y - r * 1.5, pipWidth, 6),
            const Radius.circular(3),
          ),
          Paint()..color = filled ? FireGameConfig.bossAccent : Colors.white.withValues(alpha: 0.2),
        );
      }
    }
  }

  void _drawPowerup(Canvas canvas, _Powerup powerup) {
    final glow = 0.5 + math.sin(powerup.pulse).abs() * 0.5;
    final color = powerup.isHeart ? FireGameConfig.heartColor : FireGameConfig.tripleShotColor;
    final pos = Offset(powerup.x, powerup.y);

    canvas.drawCircle(pos, 18 * (0.8 + glow * 0.35), Paint()..color = color.withValues(alpha: 0.28 * glow));

    if (powerup.isHeart) {
      final path = Path()
        ..moveTo(powerup.x, powerup.y + 7)
        ..cubicTo(powerup.x - 14, powerup.y - 6, powerup.x - 6, powerup.y - 16, powerup.x, powerup.y - 6)
        ..cubicTo(powerup.x + 6, powerup.y - 16, powerup.x + 14, powerup.y - 6, powerup.x, powerup.y + 7)
        ..close();
      canvas.drawPath(path, Paint()..color = FireGameConfig.heartColor);
    } else {
      canvas.drawCircle(pos, 11, Paint()..color = FireGameConfig.tripleShotColor);
      canvas.drawCircle(pos, 6, Paint()..color = Colors.white.withValues(alpha: 0.85));
      for (final angle in [-0.5, 0.0, 0.5]) {
        canvas.drawLine(
          pos,
          Offset(powerup.x + math.sin(angle) * 14, powerup.y - math.cos(angle) * 14),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..strokeWidth = 2,
        );
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
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: text.color.withValues(alpha: alpha),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(text.x - painter.width / 2, text.y - painter.height / 2));
    }
  }

  void _renderLowHealthVignette(Canvas canvas, double w, double h) {
    final pulse = 0.15 + math.sin(_bobTime * 6).abs() * 0.12;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, FireGameConfig.coral.withValues(alpha: pulse)],
        stops: const [0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawPlayer(Canvas canvas, double w, double h) {
    final y = _playerCenterY;
    final x = _playerX;
    final bodyScale = (h / 800).clamp(0.75, 1.4);
    final bodyW = FireGameConfig.playerSize * bodyScale;
    final bodyH = FireGameConfig.playerSize * 1.35 * bodyScale;
    final bob = math.sin(_bobTime * 3) * 3;
    final lean = _tiltX * 6 - (_recoilTimer > 0 ? 8 : 0);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y + bodyH * 0.5), width: bodyW * 1.2, height: bodyW * 0.34),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    canvas.save();
    canvas.translate(x, y + bob);
    canvas.rotate(lean * math.pi / 180);
    canvas.translate(-x, -(y + bob));

    final cx = x;
    final cy = y + bob;

    // Flame crest on top of the head.
    final crest = Path()
      ..moveTo(cx, cy - bodyH * 0.62)
      ..quadraticBezierTo(cx - bodyW * 0.22, cy - bodyH * 0.78, cx - bodyW * 0.08, cy - bodyH * 0.96)
      ..quadraticBezierTo(cx, cy - bodyH * 0.86, cx + bodyW * 0.1, cy - bodyH * 1.0)
      ..quadraticBezierTo(cx + bodyW * 0.24, cy - bodyH * 0.8, cx, cy - bodyH * 0.62)
      ..close();
    canvas.drawPath(crest, Paint()..color = FireGameConfig.playerFlame);

    // Body.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH),
      Radius.circular(bodyW * 0.42),
    );
    canvas.drawRRect(bodyRect, Paint()..color = FireGameConfig.playerBody);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = FireGameConfig.navyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, bodyW * 0.045),
    );

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - bodyH * 0.08), width: bodyW * 0.5, height: bodyH * 0.36),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    // Cheeks.
    canvas.drawCircle(Offset(cx - bodyW * 0.26, cy), bodyW * 0.08, Paint()..color = FireGameConfig.playerCheeks);
    canvas.drawCircle(Offset(cx + bodyW * 0.26, cy), bodyW * 0.08, Paint()..color = FireGameConfig.playerCheeks);

    // Eyes.
    final eyeY = cy - bodyH * 0.06;
    canvas.drawCircle(Offset(cx - bodyW * 0.15, eyeY), bodyW * 0.1, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + bodyW * 0.15, eyeY), bodyW * 0.1, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx - bodyW * 0.13, eyeY + bodyH * 0.01), bodyW * 0.05, Paint()..color = FireGameConfig.navyDeep);
    canvas.drawCircle(Offset(cx + bodyW * 0.17, eyeY + bodyH * 0.01), bodyW * 0.05, Paint()..color = FireGameConfig.navyDeep);

    // Raised arm holding a small flame orb (the "gun").
    final armY = cy + bodyH * 0.06 + (_recoilTimer > 0 ? -4 : 0);
    canvas.drawCircle(Offset(cx + bodyW * 0.58, armY), bodyW * 0.14, Paint()..color = FireGameConfig.playerBody);
    canvas.drawCircle(
      Offset(cx + bodyW * 0.58, armY - bodyH * 0.1),
      bodyW * 0.12 * (_recoilTimer > 0 ? 1.3 : 1.0),
      Paint()..color = FireGameConfig.fireballMid,
    );
    canvas.drawCircle(
      Offset(cx + bodyW * 0.58, armY - bodyH * 0.1),
      bodyW * 0.06,
      Paint()..color = FireGameConfig.fireballCore,
    );
    canvas.drawCircle(Offset(cx - bodyW * 0.55, cy + bodyH * 0.1), bodyW * 0.13, Paint()..color = FireGameConfig.playerBody);

    // Feet.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - bodyW * 0.2, cy + bodyH * 0.52), width: bodyW * 0.26, height: bodyH * 0.14),
        Radius.circular(bodyW * 0.08),
      ),
      Paint()..color = FireGameConfig.playerBodyDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + bodyW * 0.2, cy + bodyH * 0.52), width: bodyW * 0.26, height: bodyH * 0.14),
        Radius.circular(bodyW * 0.08),
      ),
      Paint()..color = FireGameConfig.playerBodyDark,
    );

    canvas.restore();
  }
}

class _Enemy {
  _Enemy({
    required this.x,
    required this.y,
    required this.speed,
    required this.kind,
    required this.color,
    required this.maxHits,
  });

  double x;
  double y;
  final double speed;
  final _EnemyKind kind;
  final Color color;
  final int maxHits;
  int hits = 0;
  double wobble = 0;
  bool dead = false;

  double get radius => kind == _EnemyKind.boss ? 21 * FireGameConfig.bossSize : 21;
}

class _Fireball {
  _Fireball({required this.x, required this.y, required this.vx, required this.vy});
  double x;
  double y;
  final double vx;
  final double vy;
  double trailTimer = 0;
  bool dead = false;
}

class _Powerup {
  _Powerup({required this.x, required this.y, required this.isHeart});
  double x;
  double y;
  final bool isHeart;
  double pulse = 0;
}

class _Ember {
  _Ember({required this.x, required this.y, required this.speed, required this.drift, required this.size});
  double x;
  double y;
  final double speed;
  final double drift;
  final double size;
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
