import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/settings/settings_controller.dart';
import 'fire_game_config.dart';
import 'fire_game_controller.dart';
import 'fire_game_state.dart';
import 'fire_game.dart';
import 'fire_game_hud.dart';

class FireGameScreen extends ConsumerStatefulWidget {
  const FireGameScreen({super.key});

  @override
  ConsumerState<FireGameScreen> createState() => _FireGameScreenState();
}

class _FireGameScreenState extends ConsumerState<FireGameScreen> {
  late final FireGame _game;
  bool _hudUpdateScheduled = false;
  bool _gameOverUpdateScheduled = false;

  int _pendingScore = 0;
  int _pendingHealth = FireGameConfig.maxHealth;
  int _pendingWave = 1;
  int _pendingKills = 0;
  int _pendingCombo = 0;
  double _pendingTripleShot = 0;

  @override
  void initState() {
    super.initState();
    _game = FireGame(
      onHudUpdate: (score, health, wave, enemiesDefeated, combo, tripleShotCharge) {
        // Flame's update() can run while Flutter is building/laying out.
        // Never mutate a Riverpod provider directly from the Flame game loop.
        // Reading/playing sfx+haptics here is safe though — it doesn't touch
        // Riverpod state, just fires audio for the delta since last frame.
        if (mounted) {
          final sound = ref.read(settingsControllerProvider).soundEnabled;
          final haptics = ref.read(settingsControllerProvider).hapticsEnabled;
          final sfx = ref.read(sfxPlayerProvider);

          if (enemiesDefeated > _pendingKills) {
            sfx.play(Sfx.hit, enabled: sound);
          }
          if (health < _pendingHealth) {
            sfx.play(Sfx.damage, enabled: sound);
            AppHaptics.heavy(haptics);
          }
          if (wave > _pendingWave) {
            sfx.play(Sfx.levelUp, enabled: sound);
            AppHaptics.medium(haptics);
          }
          if (tripleShotCharge > 0 && _pendingTripleShot <= 0) {
            sfx.play(Sfx.powerUp, enabled: sound);
            AppHaptics.light(haptics);
          }
        }

        _pendingScore = score;
        _pendingHealth = health;
        _pendingWave = wave;
        _pendingKills = enemiesDefeated;
        _pendingCombo = combo;
        _pendingTripleShot = tripleShotCharge;
        _scheduleHudUpdate();
      },
      onGameOver: () {
        // Game-over is also emitted from Flame's update() callback.
        // Defer the Riverpod mutation until the current Flutter frame is done.
        _scheduleGameOver();
      },
    );
  }

  void _scheduleHudUpdate() {
    if (_hudUpdateScheduled) return;
    _hudUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hudUpdateScheduled = false;
      if (!mounted) return;

      ref.read(fireGameControllerProvider.notifier).updateHud(
            score: _pendingScore,
            health: _pendingHealth,
            wave: _pendingWave,
            enemiesDefeated: _pendingKills,
            combo: _pendingCombo,
            tripleShotCharge: _pendingTripleShot,
          );
    });
  }

  void _scheduleGameOver() {
    if (_gameOverUpdateScheduled) return;
    _gameOverUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameOverUpdateScheduled = false;
      if (!mounted) return;
      ref.read(fireGameControllerProvider.notifier).gameOver();
    });
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _hudUpdateScheduled = false;
    _gameOverUpdateScheduled = false;
    super.dispose();
  }

  void _start() {
    ref.read(fireGameControllerProvider.notifier).startGame();
    _game.resetGame();
    _game.resumeEngine();
  }

  void _pause() {
    ref.read(fireGameControllerProvider.notifier).pauseGame();
    _game.pauseGame();
  }

  void _resume() {
    ref.read(fireGameControllerProvider.notifier).resumeGame();
    _game.resumeGame();
  }

  void _backToMenu() {
    ref.read(fireGameControllerProvider.notifier).backToMenu();
    _game.pauseGame();
  }

  void _fire() {
    final sound = ref.read(settingsControllerProvider).soundEnabled;
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: sound);
    _game.shoot();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fireGameControllerProvider);

    return Scaffold(
      backgroundColor: FireGameConfig.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          if (state.status == FireGameStatus.playing)
            FireGameHud(
              state: state,
              onPause: _pause,
              onLeft: _game.steerLeft,
              onRight: _game.steerRight,
              onFire: _fire,
            ),
          if (state.status == FireGameStatus.menu) _MenuOverlay(onStart: _start, state: state),
          if (state.status == FireGameStatus.paused)
            _PausedOverlay(onResume: _resume, onMenu: _backToMenu),
          if (state.status == FireGameStatus.gameOver)
            _GameOverOverlay(state: state, onRestart: _start, onMenu: _backToMenu),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared premium chrome
// ===========================================================================

class _EmberBackground extends StatelessWidget {
  const _EmberBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FireGameConfig.navyDeep, Color(0xFF2B0B3D), FireGameConfig.navy],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: -80, right: -60, child: _Glow(color: FireGameConfig.coral, size: 260)),
          Positioned(bottom: -100, left: -80, child: _Glow(color: FireGameConfig.violet, size: 280)),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  }) : radius = 28;

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 16)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.colors = const [FireGameConfig.coral, Color(0xFFFF8A5C)],
  }) : textColor = Colors.white;

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<Color> colors;
  final Color textColor;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: widget.colors.first.withValues(alpha: 0.55), blurRadius: 22, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.textColor),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              Text(value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Menu
// ===========================================================================

class _MenuOverlay extends StatefulWidget {
  const _MenuOverlay({required this.onStart, required this.state});
  final VoidCallback onStart;
  final FireGameState state;

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2, milliseconds: 200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EmberBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final flicker = 0.9 + math.sin(_controller.value * math.pi * 2) * 0.1;
                      return Transform.scale(scale: flicker, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [FireGameConfig.coral, FireGameConfig.gold]),
                        boxShadow: [
                          BoxShadow(color: FireGameConfig.coral.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, size: 60, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ShaderMask(
                    shaderCallback: (rect) =>
                        const LinearGradient(colors: [FireGameConfig.gold, FireGameConfig.coral]).createShader(rect),
                    child: const Text(
                      'EMBER RUSH',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white, height: 1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'SHOOT • SURVIVE • CHAIN COMBOS',
                    style: TextStyle(color: Colors.white60, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 30),
                  _GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(
                          icon: Icons.emoji_events_rounded,
                          label: 'BEST SCORE',
                          value: widget.state.bestScore.toString().padLeft(6, '0'),
                          color: FireGameConfig.gold,
                        ),
                        Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.15)),
                        _StatChip(
                          icon: Icons.local_fire_department_rounded,
                          label: 'BOSS EVERY',
                          value: 'WAVE ${FireGameConfig.bossEveryNWaves}',
                          color: FireGameConfig.violet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _GradientButton(label: 'START GAME', icon: Icons.play_arrow_rounded, onPressed: widget.onStart),
                  const SizedBox(height: 20),
                  const Text(
                    'Move to dodge, tap to shoot fireballs, chain kills\nfor combo bonuses, and watch for boss waves.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Paused
// ===========================================================================

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.onResume, required this.onMenu});
  final VoidCallback onResume;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: _GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_filled_rounded, size: 48, color: FireGameConfig.tripleShotColor),
            const SizedBox(height: 12),
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              onPressed: onResume,
              colors: const [FireGameConfig.teal, FireGameConfig.tripleShotColor],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onMenu,
              child: const Text('MAIN MENU', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Game over
// ===========================================================================

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.state, required this.onRestart, required this.onMenu});
  final FireGameState state;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final isBest = state.isNewBest;

    return _EmberBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: _GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isBest
                                ? [FireGameConfig.gold, FireGameConfig.coral]
                                : [FireGameConfig.violet, FireGameConfig.coral],
                          ),
                        ),
                        child: Icon(
                          isBest ? Icons.emoji_events_rounded : Icons.local_fire_department_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isBest ? 'NEW BEST!' : 'DEFEATED',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultStat(
                              icon: Icons.emoji_events_rounded,
                              label: 'SCORE',
                              value: state.score.toString().padLeft(6, '0'),
                              color: FireGameConfig.gold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultStat(
                              icon: Icons.local_fire_department_rounded,
                              label: 'WAVE REACHED',
                              value: '${state.wave}',
                              color: FireGameConfig.coral,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultStat(
                              icon: Icons.whatshot_rounded,
                              label: 'KILLS',
                              value: '${state.enemiesDefeated}',
                              color: FireGameConfig.teal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultStat(
                              icon: Icons.military_tech_rounded,
                              label: 'BEST SCORE',
                              value: state.bestScore.toString().padLeft(6, '0'),
                              color: FireGameConfig.violet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      _GradientButton(label: 'PLAY AGAIN', icon: Icons.replay_rounded, onPressed: onRestart),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: onMenu,
                        child: const Text('MAIN MENU', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
