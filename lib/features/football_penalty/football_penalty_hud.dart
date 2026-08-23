import 'dart:ui';

import 'package:flutter/material.dart';

import 'football_penalty_config.dart';
import 'football_penalty_state.dart';

class FootballPenaltyHud extends StatelessWidget {
  const FootballPenaltyHud({
    super.key,
    required this.score,
    required this.shots,
    required this.goals,
    required this.streak,
    required this.round,
    required this.power,
    required this.result,
    required this.commentary,
    required this.onPause,
  });

  final int score;
  final int shots;
  final int goals;
  final int streak;
  final int round;
  final double power;
  final PenaltyResult result;
  final String commentary;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final resultColor = switch (result) {
      PenaltyResult.goal => FootballPenaltyConfig.lime,
      PenaltyResult.saved => FootballPenaltyConfig.coral,
      PenaltyResult.miss => FootballPenaltyConfig.gold,
      PenaltyResult.none => Colors.white70,
    };
    final resultText = result == PenaltyResult.none
        ? 'DRAG TO AIM  •  RELEASE TO SHOOT'
        : commentary;

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
                        _Stat(
                          icon: Icons.emoji_events_rounded,
                          label: 'SCORE',
                          value: score.toString().padLeft(4, '0'),
                          color: FootballPenaltyConfig.gold,
                        ),
                        _Stat(
                          icon: Icons.sports_soccer_rounded,
                          label: 'GOALS',
                          value: '$goals / 5',
                          color: FootballPenaltyConfig.lime,
                        ),
                        _Stat(
                          icon: Icons.flag_rounded,
                          label: 'SHOT',
                          value: '${shots + 1}',
                          color: FootballPenaltyConfig.cyan,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIconButton(icon: Icons.pause_rounded, onTap: onPause),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: shots / 5,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                valueColor: const AlwaysStoppedAnimation(FootballPenaltyConfig.lime),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _RoundPill(round: round),
                if (streak >= 2) _ComboChip(streak: streak),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: _GlassBar(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      resultText,
                      key: ValueKey(resultText),
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 18, color: FootballPenaltyConfig.gold),
                      const SizedBox(width: 8),
                      const Text('POWER', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: power,
                            minHeight: 9,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation(FootballPenaltyConfig.gold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(power * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .7)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
      ]),
    ],
  );
}

class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.round});
  final int round;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Text(
      'ROUND $round  •  ${FootballPenaltyConfig.difficultyLabel(round)}',
      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6),
    ),
  );
}

class _ComboChip extends StatelessWidget {
  const _ComboChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [FootballPenaltyConfig.gold, FootballPenaltyConfig.coral]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: FootballPenaltyConfig.coral.withValues(alpha: .5), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Text('x$streak  ON FIRE', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7)),
  );
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
