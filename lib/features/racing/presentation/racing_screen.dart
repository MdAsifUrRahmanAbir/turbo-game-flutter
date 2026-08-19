import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'racing_config.dart';
import 'racing_controller.dart';
import 'racing_game.dart';
import 'racing_state.dart';

class RacingScreenView extends ConsumerStatefulWidget {
  const RacingScreenView({super.key});

  @override
  ConsumerState<RacingScreenView> createState() => _RacingScreenViewState();
}

class _RacingScreenViewState extends ConsumerState<RacingScreenView> {
  RacingGame? _game;

  void _start() {
    ref.read(racingControllerProvider.notifier).startRace();
    // Flame disposes the game's resources (including hudTick) via onRemove()
    // once its GameWidget leaves the tree, e.g. when we navigate to the
    // game-over screen. So on replay we must not reuse the old instance and
    // call resetGame() on it — that would touch an already-disposed
    // ValueNotifier. A fresh RacingGame is created for every run instead.
    setState(() {
      _game = RacingGame(
        onGameOver: (score, coins) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(racingControllerProvider.notifier)
                .finishRace(score: score, coins: coins);
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(racingControllerProvider);
    return Scaffold(
      backgroundColor: RacingConfig.navy,
      body: switch (state.screen) {
        RacingScreen.menu => _MenuView(onStart: _start, state: state),
        RacingScreen.race => _RaceView(
          game: _game!,
          onMenu: () => ref.read(racingControllerProvider.notifier).backToMenu(),
        ),
        RacingScreen.gameOver => _GameOverView(
          state: state,
          onReplay: _start,
          onMenu: () => ref.read(racingControllerProvider.notifier).backToMenu(),
        ),
      },
    );
  }
}

// ===========================================================================
// Shared premium chrome
// ===========================================================================

class _SunsetBackground extends StatelessWidget {
  const _SunsetBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RacingConfig.navyDeep, RacingConfig.navy, Color(0xFF171130)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Glow(color: RacingConfig.coral, size: 260),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _Glow(color: RacingConfig.teal, size: 280),
          ),
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
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 28,
  });

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
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
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
    this.colors = const [RacingConfig.coral, Color(0xFFFF8A5C)],
    this.textColor = Colors.white,
  });

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
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.55),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.textColor),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
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

class _MenuView extends StatefulWidget {
  const _MenuView({required this.onStart, required this.state});
  final VoidCallback onStart;
  final RacingState state;

  @override
  State<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<_MenuView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SunsetBackground(
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
                      final bounce = math.sin(_controller.value * math.pi * 2) * 6;
                      return Transform.translate(offset: Offset(0, bounce), child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [RacingConfig.coral, RacingConfig.gold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: RacingConfig.coral.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.sports_motorsports, size: 60, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [RacingConfig.gold, RacingConfig.coral],
                    ).createShader(rect),
                    child: const Text(
                      'TURBO TRACK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'CANDY HIGHWAY DASH',
                    style: TextStyle(color: Colors.white60, letterSpacing: 5, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 30),
                  _GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(
                          icon: Icons.emoji_events_rounded,
                          label: 'BEST SCORE',
                          value: widget.state.bestScore.toString().padLeft(6, '0'),
                          color: RacingConfig.gold,
                        ),
                        Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.15)),
                        _StatChip(
                          icon: Icons.monetization_on_rounded,
                          label: 'TOTAL COINS',
                          value: '${widget.state.totalCoins}',
                          color: RacingConfig.coinColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _GradientButton(
                    label: 'START RACE',
                    icon: Icons.play_arrow_rounded,
                    onPressed: widget.onStart,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Steer with the arrows, brake to dodge and grab\nlightning tokens for a nitro burst.',
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
// Race
// ===========================================================================

class _RaceView extends StatelessWidget {
  const _RaceView({required this.game, required this.onMenu});
  final RacingGame game;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: game),
          ValueListenableBuilder<int>(
            valueListenable: game.hudTick,
            builder: (_, __, ___) {
              if (!game.isPausedByUser) return const SizedBox.shrink();
              return _PausedOverlay(
                onResume: game.togglePause,
                onMenu: onMenu,
              );
            },
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: ValueListenableBuilder<int>(
              valueListenable: game.hudTick,
              builder: (_, __, ___) => Row(
                children: [
                  Expanded(
                    child: _GlassPanel(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _HudMini(icon: Icons.speed_rounded, text: '${(game.speed * 100).round()}', color: RacingConfig.teal),
                          _HudMini(icon: Icons.emoji_events_rounded, text: game.score.toString().padLeft(5, '0'), color: RacingConfig.gold),
                          _HudMini(icon: Icons.monetization_on_rounded, text: '${game.coins}', color: RacingConfig.coinColor),
                          _HudMini(icon: Icons.flag_rounded, text: 'L${game.lap}', color: RacingConfig.coral),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PauseButton(onTap: game.togglePause),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 22,
            child: ValueListenableBuilder<int>(
              valueListenable: game.hudTick,
              builder: (_, __, ___) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NitroGauge(game: game),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _WheelButton(icon: Icons.arrow_back_rounded, onChanged: game.steerLeft),
                      _NitroButton(game: game),
                      _WheelButton(icon: Icons.arrow_forward_rounded, onChanged: game.steerRight),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _BrakePedal(onChanged: game.brake),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            const Icon(Icons.pause_circle_filled_rounded, size: 48, color: RacingConfig.nitroColor),
            const SizedBox(height: 12),
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              onPressed: onResume,
              colors: const [RacingConfig.teal, RacingConfig.nitroColor],
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

class _HudMini extends StatelessWidget {
  const _HudMini({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
      ],
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(4),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.pause_rounded, color: Colors.white),
      ),
    );
  }
}

class _NitroGauge extends StatelessWidget {
  const _NitroGauge({required this.game});
  final RacingGame game;

  @override
  Widget build(BuildContext context) {
    final active = game.nitroActive;
    return _GlassPanel(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: active ? RacingConfig.nitroColor : Colors.white54, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: active ? 1.0 : game.nitroCharge,
                minHeight: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(
                  active ? RacingConfig.nitroColor : RacingConfig.nitroGlow,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            active ? 'BOOST!' : 'NITRO',
            style: TextStyle(
              color: active ? RacingConfig.nitroColor : Colors.white54,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NitroButton extends StatelessWidget {
  const _NitroButton({required this.game});
  final RacingGame game;

  @override
  Widget build(BuildContext context) {
    final ready = game.nitroReady;
    return GestureDetector(
      onTap: game.activateNitro,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: ready
                ? [RacingConfig.nitroColor, RacingConfig.teal]
                : [Colors.white24, Colors.white12],
          ),
          boxShadow: ready
              ? [BoxShadow(color: RacingConfig.nitroColor.withValues(alpha: 0.55), blurRadius: 24, spreadRadius: 2)]
              : [],
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
        ),
        child: Icon(Icons.bolt_rounded, size: 36, color: ready ? Colors.white : Colors.white38),
      ),
    );
  }
}

class _WheelButton extends StatelessWidget {
  const _WheelButton({required this.icon, required this.onChanged});
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Icon(icon, size: 28, color: Colors.white),
      ),
    );
  }
}

class _BrakePedal extends StatelessWidget {
  const _BrakePedal({required this.onChanged});
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: RacingConfig.coral.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RacingConfig.coral.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_downward_rounded, size: 16, color: RacingConfig.coral),
            SizedBox(width: 6),
            Text('BRAKE', style: TextStyle(color: RacingConfig.coral, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Game over
// ===========================================================================

class _GameOverView extends StatelessWidget {
  const _GameOverView({required this.state, required this.onReplay, required this.onMenu});
  final RacingState state;
  final VoidCallback onReplay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final isBest = state.isNewBest;

    return _SunsetBackground(
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
                                ? [RacingConfig.gold, RacingConfig.coral]
                                : [RacingConfig.teal, RacingConfig.coral],
                          ),
                        ),
                        child: Icon(
                          isBest ? Icons.emoji_events_rounded : Icons.sports_motorsports,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isBest ? 'NEW BEST!' : 'RACE OVER',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultStat(
                              icon: Icons.emoji_events_rounded,
                              label: 'SCORE',
                              value: state.lastScore.toString().padLeft(6, '0'),
                              color: RacingConfig.gold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ResultStat(
                              icon: Icons.monetization_on_rounded,
                              label: 'COINS',
                              value: '${state.lastCoins}',
                              color: RacingConfig.coinColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ResultStat(
                        icon: Icons.military_tech_rounded,
                        label: 'BEST SCORE',
                        value: state.bestScore.toString().padLeft(6, '0'),
                        color: RacingConfig.teal,
                        wide: true,
                      ),
                      const SizedBox(height: 26),
                      _GradientButton(label: 'RACE AGAIN', icon: Icons.replay_rounded, onPressed: onReplay),
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
  const _ResultStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: wide ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}