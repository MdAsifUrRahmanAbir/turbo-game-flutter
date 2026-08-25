import 'dart:ui';

import 'package:flutter/material.dart';

import 'sunset_hoops_config.dart';
import 'sunset_hoops_state.dart';

class SunsetHoopsHud extends StatelessWidget {
  const SunsetHoopsHud({super.key, required this.state, required this.onPause});

  final SunsetHoopsState state;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
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
                        _Stat(icon: Icons.emoji_events_rounded, value: '${state.score}', color: SunsetHoopsConfig.gold),
                        _Stat(icon: Icons.sports_basketball_rounded, value: '${state.makes}', color: SunsetHoopsConfig.coral),
                        _MissesIndicator(misses: state.misses, maxMisses: SunsetHoopsConfig.maxMisses),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIconButton(icon: Icons.pause_rounded, onTap: onPause),
              ],
            ),
          ),
          if (state.streak >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Align(alignment: Alignment.centerLeft, child: _StreakChip(streak: state.streak)),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.child, this.radius = 18, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10)});
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
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
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
    ],
  );
}

class _MissesIndicator extends StatelessWidget {
  const _MissesIndicator({required this.misses, required this.maxMisses});
  final int misses;
  final int maxMisses;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxMisses, (i) {
        final active = i < misses;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Icon(Icons.close_rounded, size: 15, color: active ? SunsetHoopsConfig.coral : Colors.white.withValues(alpha: 0.25)),
        );
      }),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [SunsetHoopsConfig.gold, SunsetHoopsConfig.coral]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: SunsetHoopsConfig.coral.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Text('x$streak ON FIRE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _GlassBar(
    radius: 18,
    padding: const EdgeInsets.all(4),
    child: IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white)),
  );
}