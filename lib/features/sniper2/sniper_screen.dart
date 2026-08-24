import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sniper_config.dart';
import 'sniper_controller.dart';
import 'sniper_game.dart';
import 'sniper_hud.dart';
import 'sniper_state.dart';

class Sniper2Screen extends ConsumerStatefulWidget {
  const Sniper2Screen({super.key});

  @override
  ConsumerState<Sniper2Screen> createState() => _SniperScreenState();
}

class _SniperScreenState extends ConsumerState<Sniper2Screen> {
  late final SniperGame _game;
  bool _hudUpdateScheduled = false;
  bool _missionEndScheduled = false;

  int _pendingScore = 0;
  int _pendingAmmo = 0;
  int _pendingTargetsHit = 0;
  double? _pendingTimeRemaining;
  int _pendingShotsFired = 0;
  int _pendingShotsHit = 0;

  bool _pendingSuccess = false;
  int _pendingBonus = 0;
  String? _pendingFailReason;

  @override
  void initState() {
    super.initState();
    _game = SniperGame(
      onHudUpdate: (score, ammo, targetsHit, timeRemaining, shotsFired, shotsHit) {
        // Flame's update() can run while Flutter is building/laying out.
        // Never mutate a Riverpod provider directly from the Flame game loop.
        _pendingScore = score;
        _pendingAmmo = ammo;
        _pendingTargetsHit = targetsHit;
        _pendingTimeRemaining = timeRemaining;
        _pendingShotsFired = shotsFired;
        _pendingShotsHit = shotsHit;
        _scheduleHudUpdate();
      },
      onMissionEnd: (success, score, bonus, failReason) {
        // Mission-end is also emitted from Flame's update()/fire() calls.
        // Defer the Riverpod mutation until the current Flutter frame is done.
        _pendingSuccess = success;
        _pendingScore = score;
        _pendingBonus = bonus;
        _pendingFailReason = failReason;
        _scheduleMissionEnd();
      },
    );
  }

  void _scheduleHudUpdate() {
    if (_hudUpdateScheduled) return;
    _hudUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hudUpdateScheduled = false;
      if (!mounted) return;

      ref.read(sniperControllerProvider.notifier).updateHud(
            score: _pendingScore,
            ammo: _pendingAmmo,
            targetsHit: _pendingTargetsHit,
            timeRemaining: _pendingTimeRemaining,
            shotsFired: _pendingShotsFired,
            shotsHit: _pendingShotsHit,
          );
    });
  }

  void _scheduleMissionEnd() {
    if (_missionEndScheduled) return;
    _missionEndScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _missionEndScheduled = false;
      if (!mounted) return;

      final notifier = ref.read(sniperControllerProvider.notifier);
      if (_pendingSuccess) {
        notifier.missionComplete(score: _pendingScore, completionBonus: _pendingBonus);
      } else {
        final reason = _pendingFailReason == 'timeUp' ? SniperFailReason.timeUp : SniperFailReason.outOfAmmo;
        notifier.missionFailed(score: _pendingScore, reason: reason);
      }
    });
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _hudUpdateScheduled = false;
    _missionEndScheduled = false;
    super.dispose();
  }

  void _startLevel(int level) {
    ref.read(sniperControllerProvider.notifier).startLevel(level);
    _game.startLevel(SniperConfig.levels[level - 1]);
    _game.resumeEngine();
  }

  void _pause() {
    ref.read(sniperControllerProvider.notifier).pauseGame();
    _game.pauseGame();
  }

  void _resume() {
    ref.read(sniperControllerProvider.notifier).resumeGame();
    _game.resumeGame();
  }

  void _backToMenu() {
    ref.read(sniperControllerProvider.notifier).backToMenu();
    _game.pauseGame();
  }

  void _openLevelSelect() {
    ref.read(sniperControllerProvider.notifier).openLevelSelect();
    _game.pauseGame();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sniperControllerProvider);

    return Scaffold(
      backgroundColor: SniperConfig.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          if (state.status == SniperStatus.playing)
            SniperHud(state: state, onPause: _pause, onFire: _game.fire),
          if (state.status == SniperStatus.menu)
            _MainMenu(onPlay: _openLevelSelect, state: state),
          if (state.status == SniperStatus.levelSelect)
            _LevelSelect(state: state, onSelect: _startLevel, onBack: _backToMenu),
          if (state.status == SniperStatus.paused)
            _PausedOverlay(onResume: _resume, onMenu: _backToMenu),
          if (state.status == SniperStatus.missionComplete)
            _MissionCompleteOverlay(
              state: state,
              onNext: state.currentLevel < SniperConfig.levels.length
                  ? () => _startLevel(state.currentLevel + 1)
                  : null,
              onRetry: () => _startLevel(state.currentLevel),
              onMenu: _openLevelSelect,
            ),
          if (state.status == SniperStatus.missionFailed)
            _MissionFailedOverlay(
              state: state,
              onRetry: () => _startLevel(state.currentLevel),
              onMenu: _openLevelSelect,
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared premium chrome
// ===========================================================================

class _DesertBackground extends StatelessWidget {
  const _DesertBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SniperConfig.navyDeep, Color(0xFF17324A), SniperConfig.navy],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: -80, right: -60, child: _Glow(color: SniperConfig.scopeGlow, size: 260)),
          Positioned(bottom: -100, left: -80, child: _Glow(color: SniperConfig.coral, size: 280)),
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
    this.colors = const [SniperConfig.coral, Color(0xFFFF8A5C)],
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
            boxShadow: [BoxShadow(color: widget.colors.first.withValues(alpha: 0.55), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.textColor),
              const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Main menu
// ===========================================================================

class _MainMenu extends StatefulWidget {
  const _MainMenu({required this.onPlay, required this.state});
  final VoidCallback onPlay;
  final SniperState state;

  @override
  State<_MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<_MainMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2, milliseconds: 400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DesertBackground(
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
                      final pulse = 0.92 + math.sin(_controller.value * math.pi * 2) * 0.08;
                      return Transform.scale(scale: pulse, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [SniperConfig.scopeGlow, SniperConfig.teal]),
                        boxShadow: [BoxShadow(color: SniperConfig.scopeGlow.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 4)],
                      ),
                      child: const Icon(Icons.track_changes_rounded, size: 60, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(colors: [SniperConfig.gold, SniperConfig.coral]).createShader(rect),
                    child: const Text(
                      'SNIPER MISSION',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, height: 1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '10 DESERT MISSIONS • AIM • FIRE',
                    style: TextStyle(color: Colors.white60, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 30),
                  _GradientButton(label: 'PLAY', icon: Icons.play_arrow_rounded, onPressed: widget.onPlay),
                  const SizedBox(height: 14),
                  Text(
                    'Progress: mission ${widget.state.unlockedLevel} of ${SniperConfig.levels.length} unlocked',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
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
// Level select
// ===========================================================================

class _LevelSelect extends StatelessWidget {
  const _LevelSelect({required this.state, required this.onSelect, required this.onBack});
  final SniperState state;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _DesertBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                children: [
                  IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  const SizedBox(width: 4),
                  const Text('SELECT MISSION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: SniperConfig.levels.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final level = SniperConfig.levels[index];
                        final unlocked = level.id <= state.unlockedLevel;
                        return _LevelTile(level: level, unlocked: unlocked, onTap: unlocked ? () => onSelect(level.id) : null);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.unlocked, required this.onTap});
  final SniperLevelConfig level;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: unlocked
              ? const LinearGradient(colors: [SniperConfig.coral, SniperConfig.gold], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: unlocked ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: unlocked ? 0.25 : 0.1)),
          boxShadow: unlocked ? [BoxShadow(color: SniperConfig.coral.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))] : [],
        ),
        child: Center(
          child: unlocked
              ? Text('${level.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26))
              : const Icon(Icons.lock_rounded, color: Colors.white24, size: 24),
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
            const Icon(Icons.pause_circle_filled_rounded, size: 48, color: SniperConfig.scopeGlow),
            const SizedBox(height: 12),
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              onPressed: onResume,
              colors: const [SniperConfig.teal, SniperConfig.scopeGlow],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onMenu,
              child: const Text('MISSION SELECT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Mission complete
// ===========================================================================

class _MissionCompleteOverlay extends StatelessWidget {
  const _MissionCompleteOverlay({required this.state, required this.onNext, required this.onRetry, required this.onMenu});
  final SniperState state;
  final VoidCallback? onNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _DesertBackground(
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
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [SniperConfig.gold, SniperConfig.coral]),
                        ),
                        child: const Icon(Icons.emoji_events_rounded, size: 46, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('MISSION COMPLETE', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _ResultStat(icon: Icons.emoji_events_rounded, label: 'SCORE', value: '${state.score}', color: SniperConfig.gold)),
                          const SizedBox(width: 10),
                          Expanded(child: _ResultStat(icon: Icons.gps_fixed_rounded, label: 'ACCURACY', value: '${state.accuracyPercent}%', color: SniperConfig.scopeGlow)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ResultStat(icon: Icons.card_giftcard_rounded, label: 'MISSION BONUS', value: '+${state.completionBonus}', color: SniperConfig.teal, wide: true),
                      const SizedBox(height: 26),
                      if (onNext != null) ...[
                        _GradientButton(label: 'NEXT MISSION', icon: Icons.arrow_forward_rounded, onPressed: onNext!),
                        const SizedBox(height: 12),
                      ],
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('REPLAY MISSION', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                      TextButton(
                        onPressed: onMenu,
                        child: const Text('MISSION SELECT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
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

// ===========================================================================
// Mission failed
// ===========================================================================

class _MissionFailedOverlay extends StatelessWidget {
  const _MissionFailedOverlay({required this.state, required this.onRetry, required this.onMenu});
  final SniperState state;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final reasonText = state.failReason == SniperFailReason.timeUp ? 'TIME RAN OUT' : 'OUT OF AMMO';

    return _DesertBackground(
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
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [SniperConfig.violet, SniperConfig.coral]),
                        ),
                        child: const Icon(Icons.close_rounded, size: 46, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('MISSION FAILED', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(reasonText, style: const TextStyle(color: SniperConfig.coral, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _ResultStat(icon: Icons.emoji_events_rounded, label: 'SCORE', value: '${state.score}', color: SniperConfig.gold)),
                          const SizedBox(width: 10),
                          Expanded(child: _ResultStat(icon: Icons.gps_fixed_rounded, label: 'ACCURACY', value: '${state.accuracyPercent}%', color: SniperConfig.scopeGlow)),
                        ],
                      ),
                      const SizedBox(height: 26),
                      _GradientButton(label: 'RETRY MISSION', icon: Icons.replay_rounded, onPressed: onRetry),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: onMenu,
                        child: const Text('MISSION SELECT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1)),
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
  const _ResultStat({required this.icon, required this.label, required this.value, required this.color, this.wide = false});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6))]),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6))]),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
    );
  }
}
