import 'dart:ui';

import 'package:flutter/material.dart';

import 'sniper_config.dart';
import 'sniper_state.dart';

class SniperHud extends StatelessWidget {
  const SniperHud({super.key, required this.state, required this.onPause});

  final SniperState state;
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Stat(icon: Icons.emoji_events_rounded, value: '${state.score}', color: SniperConfig.gold),
                            _Stat(icon: Icons.flag_rounded, value: 'WAVE ${state.wave}', color: SniperConfig.teal),
                            _StrikesIndicator(strikes: state.strikes, maxStrikes: state.maxStrikes),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _AmmoRow(ammo: state.ammo, maxAmmo: state.maxAmmo, reloading: state.reloading),
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
          const Spacer(),
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

class _StrikesIndicator extends StatelessWidget {
  const _StrikesIndicator({required this.strikes, required this.maxStrikes});
  final int strikes;
  final int maxStrikes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStrikes, (i) {
        final active = i < strikes;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Icon(
            Icons.close_rounded,
            size: 15,
            color: active ? SniperConfig.coral : Colors.white.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

class _AmmoRow extends StatelessWidget {
  const _AmmoRow({required this.ammo, required this.maxAmmo, required this.reloading});
  final int ammo;
  final int maxAmmo;
  final bool reloading;

  @override
  Widget build(BuildContext context) {
    if (reloading) {
      return Row(
        children: [
          const Icon(Icons.autorenew_rounded, size: 16, color: SniperConfig.crosshair),
          const SizedBox(width: 8),
          const Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              child: LinearProgressIndicator(
                minHeight: 8,
                backgroundColor: Color(0x1FFFFFFF),
                valueColor: AlwaysStoppedAnimation(SniperConfig.crosshair),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('RELOADING', style: TextStyle(color: SniperConfig.crosshair, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
        ],
      );
    }

    return Row(
      children: List.generate(maxAmmo, (i) {
        final loaded = i < ammo;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: loaded ? SniperConfig.gold : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
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
        gradient: const LinearGradient(colors: [SniperConfig.teal, SniperConfig.crosshair]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: SniperConfig.teal.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
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
