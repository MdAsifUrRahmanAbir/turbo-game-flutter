import 'package:flutter/material.dart';

class EndlessRunnerHud extends StatelessWidget {
  const EndlessRunnerHud({
    super.key,
    required this.score,
    required this.coins,
    required this.distance,
    required this.onPause,
    required this.onLeft,
    required this.onRight,
    required this.onJump,
    required this.onDuck,
  });

  final int score;
  final int coins;
  final double distance;
  final VoidCallback onPause;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onJump;
  final VoidCallback onDuck;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Stat(label: 'SCORE', value: '$score'),
                const SizedBox(width: 10),
                _Stat(label: 'COINS', value: '$coins'),
                const Spacer(),
                _Stat(label: 'DIST', value: '${distance.floor()}m'),
                const SizedBox(width: 8),
                _RoundButton(icon: Icons.pause_rounded, onTap: onPause),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ControlButton(icon: Icons.arrow_back_rounded, onTap: onLeft),
                const SizedBox(width: 12),
                _ControlButton(icon: Icons.arrow_forward_rounded, onTap: onRight),
                const Spacer(),
                _ControlButton(icon: Icons.keyboard_double_arrow_down_rounded, onTap: onDuck),
                const SizedBox(width: 12),
                _JumpButton(onTap: onJump),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: Colors.white)),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundButton(icon: icon, onTap: onTap);
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFC107),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Icon(Icons.arrow_upward_rounded, size: 30, color: Colors.black87),
        ),
      ),
    );
  }
}
