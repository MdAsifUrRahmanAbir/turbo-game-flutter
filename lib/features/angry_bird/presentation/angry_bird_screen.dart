import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/settings/settings_controller.dart';
import 'angry_bird_config.dart';
import 'angry_bird_controller.dart';
import 'angry_bird_game.dart';
import 'angry_bird_levels.dart';
import 'angry_bird_state.dart';

class AngryBirdScreen extends ConsumerStatefulWidget {
  const AngryBirdScreen({super.key});

  @override
  ConsumerState<AngryBirdScreen> createState() => _AngryBirdScreenState();
}

class _AngryBirdScreenState extends ConsumerState<AngryBirdScreen> {
  AngryBirdGame? _game;

  @override
  void initState() {
    super.initState();
    // Physics Smash — sling, trajectory and fortress layout all read best
    // wide, so the whole screen (level select, play, results) is locked
    // to landscape for as long as it's on-screen.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Hand orientation control back to the rest of the app (the hub and
    // other games are portrait-first) the moment this screen is left.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _launchLevel(int index) {
    ref.read(angryBirdControllerProvider.notifier).selectLevel(index);
    _spawnGame(index);
  }

  void _retry(int index) {
    ref.read(angryBirdControllerProvider.notifier).retry();
    _spawnGame(index);
  }

  void _spawnGame(int index) {
    // Flame disposes game resources (hudTick) once its GameWidget leaves
    // the tree, so a fresh instance is created for every attempt rather
    // than reused — matching the pattern used by the racing game.
    setState(() {
      _game = AngryBirdGame(
        level: angryBirdLevels[index],
        onLevelEnd: (score, won) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(angryBirdControllerProvider.notifier).finishLevel(score: score, won: won);
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(angryBirdControllerProvider);
    return Scaffold(
      backgroundColor: AngryBirdConfig.navy,
      body: switch (state.screen) {
        AngryBirdStatus.menu => _MenuView(state: state, onSelect: _launchLevel),
        AngryBirdStatus.playing => _PlayView(
          game: _game!,
          onMenu: () => ref.read(angryBirdControllerProvider.notifier).backToMenu(),
        ),
        AngryBirdStatus.levelComplete => _LevelCompleteView(
          state: state,
          onNext: () {
            final controller = ref.read(angryBirdControllerProvider.notifier);
            controller.nextLevel();
            final next = ref.read(angryBirdControllerProvider);
            if (next.screen == AngryBirdStatus.playing) _spawnGame(next.currentLevel);
          },
          onMenu: () => ref.read(angryBirdControllerProvider.notifier).backToMenu(),
        ),
        AngryBirdStatus.gameOver => _GameOverView(
          state: state,
          onRetry: () => _retry(state.currentLevel),
          onMenu: () => ref.read(angryBirdControllerProvider.notifier).backToMenu(),
        ),
      },
    );
  }
}

// ===========================================================================
// Shared chrome
// ===========================================================================

class _SkyBackground extends StatelessWidget {
  const _SkyBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AngryBirdConfig.navyDeep, AngryBirdConfig.navy, Color(0xFF14210F)],
        ),
      ),
      child: child,
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding = const EdgeInsets.all(24), this.radius = 28});
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 16))],
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
    this.colors = const [AngryBirdConfig.coral, Color(0xFFFF8A5C)],
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<Color> colors;

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
            boxShadow: [BoxShadow(color: widget.colors.first.withValues(alpha: 0.55), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white),
              const SizedBox(width: 10),
              Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars, this.size = 22});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < stars;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: filled ? AngryBirdConfig.gold : Colors.white24,
        );
      }),
    );
  }
}

// ===========================================================================
// Menu — level select
// ===========================================================================

class _MenuView extends StatelessWidget {
  const _MenuView({required this.state, required this.onSelect});
  final AngryBirdState state;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _SkyBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AngryBirdConfig.birdRed, AngryBirdConfig.gold]),
                      boxShadow: [BoxShadow(color: AngryBirdConfig.coral.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.adjust_rounded, size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PHYSICS SMASH',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'SLINGSHOT • DESTROY • CONQUER',
                    style: TextStyle(color: Colors.white54, letterSpacing: 4, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  ...List.generate(angryBirdLevels.length, (i) {
                    final unlocked = i < state.unlockedLevels;
                    final level = angryBirdLevels[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LevelTile(
                        index: i,
                        name: level.name,
                        unlocked: unlocked,
                        stars: state.starsFor(i),
                        onTap: unlocked ? () => onSelect(i) : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.index, required this.name, required this.unlocked, required this.stars, required this.onTap});
  final int index;
  final String name;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassPanel(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: unlocked ? AngryBirdConfig.coral.withValues(alpha: 0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: unlocked
                  ? Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))
                  : const Icon(Icons.lock_rounded, color: Colors.white38, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  if (unlocked) _StarRow(stars: stars, size: 16) else const Text('Locked', style: TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            ),
            if (unlocked) const Icon(Icons.play_circle_fill_rounded, color: AngryBirdConfig.gold, size: 30),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Play view
// ===========================================================================

class _PlayView extends ConsumerWidget {
  const _PlayView({required this.game, required this.onMenu});
  final AngryBirdGame game;
  final VoidCallback onMenu;

  void _tap(WidgetRef ref, VoidCallback action) {
    action();
    final settings = ref.read(settingsControllerProvider);
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: settings.soundEnabled);
    AppHaptics.selection(settings.hapticsEnabled);
  }

  void _boost(WidgetRef ref, VoidCallback action) {
    action();
    final settings = ref.read(settingsControllerProvider);
    ref.read(sfxPlayerProvider).play(Sfx.powerUp, enabled: settings.soundEnabled);
    AppHaptics.medium(settings.hapticsEnabled);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => game.onDragStart(d.localPosition),
            onPanUpdate: (d) => game.onDragUpdate(d.localPosition),
            onPanEnd: (_) => game.onDragEnd(),
            child: GameWidget(game: game),
          ),
          ValueListenableBuilder<int>(
            valueListenable: game.hudTick,
            builder: (_, _, _) {
              if (!game.isPausedByUser) return const SizedBox.shrink();
              return _PausedOverlay(onResume: game.togglePause, onMenu: onMenu);
            },
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: ValueListenableBuilder<int>(
              valueListenable: game.hudTick,
              builder: (_, _, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _GlassPanel(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _HudMini(icon: Icons.emoji_events_rounded, text: '${game.score}', color: AngryBirdConfig.gold),
                              _HudMini(icon: Icons.pest_control_rodent_rounded, text: '${game.pigsRemaining}', color: AngryBirdConfig.pigGreen),
                              _HudMini(icon: Icons.adjust_rounded, text: '${game.birdsRemaining}', color: AngryBirdConfig.coral),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PauseButton(onTap: () => _tap(ref, game.togglePause)),
                    ],
                  ),
                  if (game.nextBirds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _BirdQueue(birds: game.nextBirds),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 24,
            child: ValueListenableBuilder<int>(
              valueListenable: game.hudTick,
              builder: (_, _, _) {
                if (!game.isBoostReady) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _boost(ref, game.activateBoost),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AngryBirdConfig.birdYellow, AngryBirdConfig.birdYellowDark]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: AngryBirdConfig.birdYellow.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: 1)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.black87),
                        SizedBox(width: 6),
                        Text('BOOST', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
      ],
    );
  }
}

class _BirdQueue extends StatelessWidget {
  const _BirdQueue({required this.birds});
  final List<BirdKind> birds;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NEXT',
            style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(width: 8),
          for (final kind in birds.take(5)) _BirdQueueDot(kind: kind),
        ],
      ),
    );
  }
}

class _BirdQueueDot extends StatelessWidget {
  const _BirdQueueDot({required this.kind});
  final BirdKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      BirdKind.red => AngryBirdConfig.birdRed,
      BirdKind.yellow => AngryBirdConfig.birdYellow,
      BirdKind.black => AngryBirdConfig.birdBlack,
    };
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
      ),
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
      child: IconButton(onPressed: onTap, icon: const Icon(Icons.pause_rounded, color: Colors.white)),
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
            const Icon(Icons.pause_circle_filled_rounded, size: 48, color: AngryBirdConfig.teal),
            const SizedBox(height: 12),
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              onPressed: onResume,
              colors: const [AngryBirdConfig.teal, Color(0xFF4DD8FF)],
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
// Level complete / game over
// ===========================================================================

class _LevelCompleteView extends StatelessWidget {
  const _LevelCompleteView({required this.state, required this.onNext, required this.onMenu});
  final AngryBirdState state;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final isLast = state.currentLevel >= angryBirdLevels.length - 1;
    return _SkyBackground(
      child: Stack(
        children: [
          const Positioned.fill(child: _ConfettiOverlay()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _GlassPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AngryBirdConfig.gold, AngryBirdConfig.coral]),
                          ),
                          child: const Icon(Icons.emoji_events_rounded, size: 46, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text('LEVEL CLEAR!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 12),
                        _StarRow(stars: state.lastStars, size: 34),
                        const SizedBox(height: 18),
                        Text('SCORE  ${state.lastScore}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 26),
                        _GradientButton(
                          label: isLast ? 'BACK TO MENU' : 'NEXT LEVEL',
                          icon: isLast ? Icons.home_rounded : Icons.arrow_forward_rounded,
                          onPressed: onNext,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: onMenu,
                          child: const Text('LEVEL SELECT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Confetti (level-complete celebration)
// ===========================================================================

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final List<_ConfettiPiece> _pieces = List.generate(26, _ConfettiPiece.new);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece(int seed)
      : x = math.Random(seed * 17 + 1).nextDouble(),
        delay = math.Random(seed * 31 + 2).nextDouble(),
        speed = 0.6 + math.Random(seed * 53 + 3).nextDouble() * 0.6,
        drift = (math.Random(seed * 71 + 4).nextDouble() - 0.5) * 40,
        colorIndex = seed % AngryBirdConfig.confetti.length,
        spin = math.Random(seed * 97 + 5).nextDouble() * math.pi * 2;

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final int colorIndex;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_ConfettiPiece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t + p.delay) * p.speed) % 1.0;
      final dy = local * (size.height + 40) - 20;
      final dx = p.x * size.width + math.sin(local * math.pi * 4) * p.drift;
      final paint = Paint()..color = AngryBirdConfig.confetti[p.colorIndex].withValues(alpha: 0.85);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin + local * math.pi * 6);
      canvas.drawRect(const Rect.fromLTWH(-3, -5, 6, 10), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class _GameOverView extends StatelessWidget {
  const _GameOverView({required this.state, required this.onRetry, required this.onMenu});
  final AngryBirdState state;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _SkyBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AngryBirdConfig.pigGreenDark),
                      child: const Icon(Icons.sentiment_satisfied_alt_rounded, size: 46, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('OUT OF BIRDS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('The pigs held their fortress.', style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 26),
                    _GradientButton(label: 'TRY AGAIN', icon: Icons.replay_rounded, onPressed: onRetry),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onMenu,
                      child: const Text('LEVEL SELECT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}