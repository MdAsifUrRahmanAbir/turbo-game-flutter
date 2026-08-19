import 'package:flutter/material.dart';
import 'package:turbo_track_racing/features/fire_game/presentation/screens/fire_game_screen.dart';

import '../../racing/presentation/racing_screen.dart';
import '../../endless_runner/presentation/screens/endless_runner_screen.dart';

class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E131A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  const Icon(
                    Icons.sports_esports_rounded,
                    size: 72,
                    color: Color(0xFFFFC107),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'TURBO ARCADE',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'One Flutter project • Multiple games',
                    style: TextStyle(
                      color: Colors.white60,
                    ),
                  ),

                  const SizedBox(height: 30),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final vertical = constraints.maxWidth < 600;

                      final cards = [
                        _GameCard(
                          icon: Icons.directions_car_filled_rounded,
                          title: '2D RACING',
                          description:
                          'Dodge traffic, survive the road and chase a high score.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RacingScreenView(),
                              ),
                            );
                          },
                        ),

                        _GameCard(
                          icon: Icons.directions_run_rounded,
                          title: 'ENDLESS RUNNER',
                          description:
                          'Switch lanes, jump obstacles, collect coins and survive.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const EndlessRunnerScreen(),
                              ),
                            );
                          },
                        ),

                        _GameCard(
                          icon: Icons.local_fire_department_rounded,
                          title: '2D FIRE',
                          description:
                          'Shoot incoming enemies, survive the waves and beat your high score.',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FireGameScreen(),
                              ),
                            );
                          },
                        ),
                      ];

                      if (vertical) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 16),
                            cards[1],
                            const SizedBox(height: 16),
                            cards[2],
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 16),
                                cards[2],
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: cards[1],
                          ),
                        ],
                      );
                    },
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

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF18202B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                icon,
                size: 64,
                color: const Color(0xFFFFC107),
              ),

              const SizedBox(height: 14),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'PLAY NOW  →',
                style: TextStyle(
                  color: Color(0xFFFFC107),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}