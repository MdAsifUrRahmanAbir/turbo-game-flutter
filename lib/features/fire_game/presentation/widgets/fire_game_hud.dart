import 'package:flutter/material.dart';

import '../controllers/fire_game_state.dart';

class FireGameHud extends StatelessWidget {
  const FireGameHud({
    super.key,
    required this.state,
    required this.onPause,
  });

  final FireGameState state;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _InfoCard(label: 'SCORE', value: '${state.score}'),
                const SizedBox(width: 8),
                _InfoCard(label: 'WAVE', value: '${state.wave}'),
                const SizedBox(width: 8),
                _InfoCard(label: 'KILLS', value: '${state.enemiesDefeated}'),
                const Spacer(),
                IconButton(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _HealthBar(health: state.health, maxHealth: 100),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.health, required this.maxHealth});

  final int health;
  final int maxHealth;

  @override
  Widget build(BuildContext context) {
    final value = (health / maxHealth).clamp(0.0, 1.0);

    return Row(
      children: [
        const Icon(Icons.favorite, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$health',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
