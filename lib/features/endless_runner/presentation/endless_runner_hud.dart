import 'dart:ui';

import 'package:flutter/material.dart';

import 'endless_runner_config.dart';


class EndlessRunnerHud extends StatelessWidget {
  const EndlessRunnerHud({
    super.key,
    required this.score,
    required this.coins,
    required this.distance,
    required this.shieldCharge,
    required this.onPause,
    required this.onLeft,
    required this.onRight,
    required this.onJump,
    required this.onDuck,
  });

  final int score;
  final int coins;
  final double distance;
  final double shieldCharge;
  final VoidCallback onPause;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onJump;
  final VoidCallback onDuck;

  @override
  Widget build(BuildContext context) {
    final shieldActive = shieldCharge >= 0.999;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: _GlassBar(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Stat(icon: Icons.emoji_events_rounded, value: '$score', color: EndlessRunnerConfig.gold),
                        _Stat(icon: Icons.monetization_on_rounded, value: '$coins', color: EndlessRunnerConfig.coinColor),
                        _Stat(icon: Icons.directions_run_rounded, value: '${distance.floor()}m', color: EndlessRunnerConfig.teal),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIconButton(icon: Icons.pause_rounded, onTap: onPause),
              ],
            ),
          ),
          if (shieldCharge > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _GlassBar(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 16, color: shieldActive ? EndlessRunnerConfig.shieldColor : Colors.white54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: shieldCharge,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(EndlessRunnerConfig.shieldColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('SHIELD', style: TextStyle(color: EndlessRunnerConfig.shieldColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _LaneButton(icon: Icons.arrow_back_rounded, onTap: onLeft),
                const SizedBox(width: 12),
                _LaneButton(icon: Icons.arrow_forward_rounded, onTap: onRight),
                const Spacer(),
                _ActionButton(
                  icon: Icons.keyboard_double_arrow_down_rounded,
                  label: 'DUCK',
                  colors: const [EndlessRunnerConfig.violet, EndlessRunnerConfig.teal],
                  onTap: onDuck,
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: 'JUMP',
                  colors: const [EndlessRunnerConfig.coral, EndlessRunnerConfig.gold],
                  big: true,
                  onTap: onJump,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  const _GlassBar({
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.color});
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassBar(
      radius: 18,
      padding: const EdgeInsets.all(4),
      child: IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white)),
    );
  }
}

class _LaneButton extends StatelessWidget {
  const _LaneButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Icon(icon, size: 26, color: Colors.white),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 78.0 : 62.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(color: colors.first.withValues(alpha: 0.55), blurRadius: 22, spreadRadius: 1),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            child: Icon(icon, size: big ? 34 : 26, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }
}
