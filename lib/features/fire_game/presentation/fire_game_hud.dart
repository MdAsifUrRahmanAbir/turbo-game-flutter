import 'dart:ui';

import 'package:flutter/material.dart';

import 'fire_game_config.dart';
import 'fire_game_state.dart';


class FireGameHud extends StatelessWidget {
  const FireGameHud({
    super.key,
    required this.state,
    required this.onPause,
    required this.onLeft,
    required this.onRight,
    required this.onFire,
  });

  final FireGameState state;
  final VoidCallback onPause;
  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;
  final VoidCallback onFire;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Stat(icon: Icons.emoji_events_rounded, value: '${state.score}', color: FireGameConfig.gold),
                            _Stat(icon: Icons.local_fire_department_rounded, value: 'WAVE ${state.wave}', color: FireGameConfig.coral),
                            _Stat(icon: Icons.whatshot_rounded, value: '${state.enemiesDefeated}', color: FireGameConfig.teal),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _HealthBar(health: state.health, maxHealth: state.maxHealth),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIconButton(icon: Icons.pause_rounded, onTap: onPause),
              ],
            ),
          ),
          if (state.combo >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ComboChip(combo: state.combo),
              ),
            ),
          if (state.tripleShotCharge > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _GlassBar(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: FireGameConfig.tripleShotColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: state.tripleShotCharge,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(FireGameConfig.tripleShotColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('TRIPLE SHOT', style: TextStyle(color: FireGameConfig.tripleShotColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    _HoldButton(icon: Icons.arrow_back_rounded, onChanged: onLeft),
                    const SizedBox(width: 12),
                    _HoldButton(icon: Icons.arrow_forward_rounded, onChanged: onRight),
                  ],
                ),
                _FireButton(onTap: onFire),
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
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.health, required this.maxHealth});
  final int health;
  final int maxHealth;

  @override
  Widget build(BuildContext context) {
    final value = maxHealth == 0 ? 0.0 : (health / maxHealth).clamp(0.0, 1.0);
    final low = value <= 0.25;

    return Row(
      children: [
        Icon(Icons.favorite_rounded, color: low ? FireGameConfig.coral : FireGameConfig.heartColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(low ? FireGameConfig.coral : FireGameConfig.heartColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$health', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
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
        gradient: const LinearGradient(colors: [FireGameConfig.gold, FireGameConfig.coral]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: FireGameConfig.coral.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Text(
        'x$combo COMBO',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
      ),
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

class _HoldButton extends StatelessWidget {
  const _HoldButton({required this.icon, required this.onChanged});
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Container(
        width: 60,
        height: 60,
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

class _FireButton extends StatelessWidget {
  const _FireButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [FireGameConfig.coral, FireGameConfig.gold]),
          boxShadow: [
            BoxShadow(color: FireGameConfig.coral.withValues(alpha: 0.55), blurRadius: 24, spreadRadius: 1),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: const Icon(Icons.local_fire_department_rounded, size: 38, color: Colors.white),
      ),
    );
  }
}
