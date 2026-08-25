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
                _RoundIconButton(icon: Icons.pause_rounded, onTap: onPause),
                const SizedBox(width: 10),
                Expanded(child: _ScoreBadge(score: state.score, makes: state.makes)),
                const SizedBox(width: 10),
                _TrophyButton(bestScore: state.bestScore),
              ],
            ),
          ),
          if (state.streak >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Align(alignment: Alignment.centerLeft, child: _StreakChip(streak: state.streak)),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _MissesIndicator(misses: state.misses, maxMisses: SunsetHoopsConfig.maxMisses),
            ),
          ),
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

/// Circular "avatar" badge + score, echoing the player-badge-plus-score
/// layout of typical arcade basketball HUDs, drawn purely with Flutter
/// widgets (no image assets).
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.makes});
  final int score;
  final int makes;

  @override
  Widget build(BuildContext context) {
    return _GlassBar(
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [SunsetHoopsConfig.coral, SunsetHoopsConfig.gold]),
              boxShadow: [BoxShadow(color: SunsetHoopsConfig.coral.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 1)],
            ),
            child: const Icon(Icons.sports_basketball_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
              Text('$makes MADE', style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrophyButton extends StatelessWidget {
  const _TrophyButton({required this.bestScore});
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return _GlassBar(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: SunsetHoopsConfig.gold, size: 18),
          const SizedBox(width: 6),
          Text('$bestScore', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MissesIndicator extends StatelessWidget {
  const _MissesIndicator({required this.misses, required this.maxMisses});
  final int misses;
  final int maxMisses;

  @override
  Widget build(BuildContext context) {
    return _GlassBar(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('MISSES', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(width: 8),
          ...List.generate(maxMisses, (i) {
            final active = i < misses;
            return Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(Icons.close_rounded, size: 15, color: active ? SunsetHoopsConfig.coral : Colors.white.withValues(alpha: 0.25)),
            );
          }),
        ],
      ),
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