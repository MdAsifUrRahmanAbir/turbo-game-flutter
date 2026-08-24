import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/settings/settings_controller.dart';
import 'gulti_config.dart';
import 'gulti_controller.dart';
import 'gulti_game.dart';
import 'gulti_levels.dart';
import 'gulti_state.dart';

class GultiScreen extends ConsumerStatefulWidget {
  const GultiScreen({super.key});

  @override
  ConsumerState<GultiScreen> createState() => _GultiScreenState();
}

class _GultiScreenState extends ConsumerState<GultiScreen> {
  GultiGame? _game;

  void _launchLevel(int index) {
    ref.read(gultiControllerProvider.notifier).selectLevel(index);
    _spawnGame(index);
  }

  void _retry(int index) {
    ref.read(gultiControllerProvider.notifier).retry();
    _spawnGame(index);
  }

  void _spawnGame(int index) {
    // Flame disposes game resources (hudTick) once its GameWidget leaves
    // the tree, so a fresh instance is created for every attempt rather
    // than reused — matching the pattern used by the other games.
    setState(() {
      _game = GultiGame(
        level: gultiLevels[index],
        onLevelEnd: ({
          required score,
          required birdsHit,
          required totalBirds,
          required stonesUsed,
          required stoneCount,
          required won,
        }) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(gultiControllerProvider.notifier).finishLevel(
                  score: score,
                  birdsHit: birdsHit,
                  totalBirds: totalBirds,
                  stonesUsed: stonesUsed,
                  stoneCount: stoneCount,
                  won: won,
                );
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gultiControllerProvider);
    return Scaffold(
      backgroundColor: GultiConfig.navy,
      body: switch (state.status) {
        GultiStatus.menu => _MenuView(state: state, onSelect: _launchLevel),
        GultiStatus.playing => _PlayView(
            game: _game!,
            onMenu: () => ref.read(gultiControllerProvider.notifier).backToMenu(),
          ),
        GultiStatus.levelComplete => _LevelCompleteView(
            state: state,
            onNext: () {
              final controller = ref.read(gultiControllerProvider.notifier);
              controller.nextLevel();
              final next = ref.read(gultiControllerProvider);
              if (next.status == GultiStatus.playing) _spawnGame(next.currentLevel);
            },
            onMenu: () => ref.read(gultiControllerProvider.notifier).backToMenu(),
          ),
        GultiStatus.gameOver => _GameOverView(
            state: state,
            onRetry: () => _retry(state.currentLevel),
            onMenu: () => ref.read(gultiControllerProvider.notifier).backToMenu(),
          ),
      },
    );
  }
}

// ===========================================================================
// Shared premium chrome
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
          colors: [GultiConfig.navyDeep, GultiConfig.navy, Color(0xFF14210F)],
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
    this.colors = const [GultiConfig.coral, Color(0xFFFF8A5C)],
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
          color: filled ? GultiConfig.gold : Colors.white24,
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
  final GultiState state;
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
                      gradient: const LinearGradient(colors: [GultiConfig.birdNormal, GultiConfig.gold]),
                      boxShadow: [BoxShadow(color: GultiConfig.coral.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 4)],
                    ),
                    child: const Icon(Icons.flutter_dash_rounded, size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'GULTI SHOOT',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PULL • AIM • RELEASE',
                    style: TextStyle(color: Colors.white54, letterSpacing: 4, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  ...List.generate(gultiLevels.length, (i) {
                    final unlocked = i < state.unlockedLevels;
                    final level = gultiLevels[i];
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
                color: unlocked ? GultiConfig.coral.withValues(alpha: 0.25) : Colors.white10,
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
            if (unlocked) const Icon(Icons.play_circle_fill_rounded, color: GultiConfig.gold, size: 30),
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
  final GultiGame game;
  final VoidCallback onMenu;

  void _tap(WidgetRef ref, VoidCallback action) {
    action();
    final settings = ref.read(settingsControllerProvider);
    ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: settings.soundEnabled);
    AppHaptics.selection(settings.hapticsEnabled);
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
            onPanEnd: (_) {
              final settings = ref.read(settingsControllerProvider);
              ref.read(sfxPlayerProvider).play(Sfx.kick, enabled: settings.soundEnabled);
              AppHaptics.light(settings.hapticsEnabled);
              game.onDragEnd();
            },
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
                              _HudMini(icon: Icons.emoji_events_rounded, text: '${game.score}', color: GultiConfig.gold),
                              _HudMini(
                                icon: Icons.flutter_dash_rounded,
                                text: '${game.birdsHit}/${game.totalBirds}',
                                color: GultiConfig.birdNormal,
                              ),
                              _HudMini(icon: Icons.circle, text: '${game.stonesRemaining}', color: GultiConfig.stone),
                              if (game.timeRemaining != null)
                                _HudMini(
                                  icon: Icons.timer_rounded,
                                  text: '${game.timeRemaining!.ceil()}s',
                                  color: GultiConfig.coral,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PauseButton(onTap: () => _tap(ref, game.togglePause)),
                    ],
                  ),
                  if (game.combo >= 2) ...[
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: _ComboChip(combo: game.combo)),
                  ],
                ],
              ),
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
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
      ],
    );
  }
}

class _ComboChip extends StatelessWidget {
  const _ComboChip({required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [GultiConfig.gold, GultiConfig.coral]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: GultiConfig.coral.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Text('x$combo COMBO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
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
            const Icon(Icons.pause_circle_filled_rounded, size: 48, color: GultiConfig.teal),
            const SizedBox(height: 12),
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              onPressed: onResume,
              colors: const [GultiConfig.teal, Color(0xFF4DD8FF)],
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
  final GultiState state;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final isLast = state.currentLevel >= gultiLevels.length - 1;
    final accuracyPct = (state.lastAccuracy * 100).round();
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [GultiConfig.gold, GultiConfig.coral]),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, size: 46, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('LEVEL CLEAR!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 12),
                    _StarRow(stars: state.lastStars, size: 34),
                    const SizedBox(height: 18),
                    Text('SCORE  ${state.lastScore}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultStat(
                            icon: Icons.flutter_dash_rounded,
                            label: 'BIRDS HIT',
                            value: '${state.lastBirdsHit}/${state.lastTotalBirds}',
                            color: GultiConfig.birdNormal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ResultStat(
                            icon: Icons.track_changes_rounded,
                            label: 'ACCURACY',
                            value: '$accuracyPct%',
                            color: GultiConfig.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultStat(
                            icon: Icons.circle,
                            label: 'STONES USED',
                            value: '${state.lastStonesUsed}/${state.lastStoneCount}',
                            color: GultiConfig.stone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ResultStat(
                            icon: Icons.military_tech_rounded,
                            label: 'BEST SCORE',
                            value: '${state.bestScore}',
                            color: GultiConfig.gold,
                          ),
                        ),
                      ],
                    ),
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

class _GameOverView extends StatelessWidget {
  const _GameOverView({required this.state, required this.onRetry, required this.onMenu});
  final GultiState state;
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
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: GultiConfig.hillFar),
                      child: const Icon(Icons.sentiment_neutral_rounded, size: 46, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('OUT OF STONES', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      'You hit ${state.lastBirdsHit} of ${state.lastTotalBirds} birds.',
                      style: const TextStyle(color: Colors.white54),
                    ),
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
