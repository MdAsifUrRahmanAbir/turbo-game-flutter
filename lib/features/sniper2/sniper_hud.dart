import 'dart:ui';

import 'package:flutter/material.dart';

import 'sniper_config.dart';
import 'sniper_state.dart';

class SniperHud extends StatelessWidget {
  const SniperHud({super.key, required this.state, required this.onPause, required this.onFire});

  final SniperState state;
  final VoidCallback onPause;
  final VoidCallback onFire;

  @override
  Widget build(BuildContext context) {
    final targetsRemaining = (state.targetGoal - state.targetsHit).clamp(0, state.targetGoal);

    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: SniperConfig.navyDeep.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LEVEL ${state.currentLevel}', style: const TextStyle(color: SniperConfig.gold, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                      _HudStat(icon: Icons.track_changes_rounded, value: '$targetsRemaining', color: SniperConfig.scopeGlow),
                      _HudStat(icon: Icons.linear_scale_rounded, value: '${state.ammo}', color: SniperConfig.gold),
                      if (state.timeRemaining != null)
                        _HudStat(icon: Icons.timer_rounded, value: '${state.timeRemaining!.ceil()}s', color: SniperConfig.coral),
                      _PauseButton(onTap: onPause),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ScoreBanner(score: state.score),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 30, right: 24),
            child: Align(
              alignment: Alignment.bottomRight,
              child: _FireButton(onTap: onFire, disabled: state.ammo <= 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({required this.icon, required this.value, required this.color});
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.pause_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: SniperConfig.navyDeep.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          score.toString().padLeft(5, '0'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _FireButton extends StatelessWidget {
  const _FireButton({required this.onTap, required this.disabled});
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: disabled ? [Colors.white24, Colors.white12] : const [SniperConfig.coral, SniperConfig.gold],
          ),
          boxShadow: disabled
              ? []
              : [BoxShadow(color: SniperConfig.coral.withValues(alpha: 0.55), blurRadius: 24, spreadRadius: 1)],
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Icon(Icons.gps_fixed_rounded, size: 34, color: disabled ? Colors.white38 : Colors.white),
      ),
    );
  }
}
