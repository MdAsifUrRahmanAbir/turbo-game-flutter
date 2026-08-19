import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/endless_runner_controller.dart';
import '../controllers/endless_runner_state.dart';
import '../game/endless_runner_game.dart';
import '../widgets/endless_runner_hud.dart';

class EndlessRunnerScreen extends ConsumerStatefulWidget {
  const EndlessRunnerScreen({super.key});

  @override
  ConsumerState<EndlessRunnerScreen> createState() => _EndlessRunnerScreenState();
}

class _EndlessRunnerScreenState extends ConsumerState<EndlessRunnerScreen> {
  late final EndlessRunnerGame _game;
  bool _hudUpdateScheduled = false;
  bool _gameOverUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _game = EndlessRunnerGame(
      onHudChanged: (score, coins, distance) {
        // Flame's update() can run while Flutter is building/layouting.
        // Never mutate a Riverpod provider directly from the Flame game loop.
        _scheduleHudUpdate(
          score: score,
          coins: coins,
          distance: distance,
        );
      },
      onGameOver: (score, coins, distance) {
        // Game-over is also emitted from Flame's update() callback.
        // Defer the Riverpod mutation until the current Flutter frame is done.
        _scheduleGameOver(
          score: score,
          coins: coins,
          distance: distance,
        );
      },
    );
  }


  void _scheduleHudUpdate({
    required int score,
    required int coins,
    required double distance,
  }) {
    if (_hudUpdateScheduled) return;
    _hudUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hudUpdateScheduled = false;
      if (!mounted) return;

      ref.read(endlessRunnerControllerProvider.notifier).updateHud(
            score: score,
            coins: coins,
            distance: distance,
          );
    });
  }

  void _scheduleGameOver({
    required int score,
    required int coins,
    required double distance,
  }) {
    if (_gameOverUpdateScheduled) return;
    _gameOverUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameOverUpdateScheduled = false;
      if (!mounted) return;

      ref.read(endlessRunnerControllerProvider.notifier).finish(
            score: score,
            coins: coins,
            distance: distance,
          );
    });
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _hudUpdateScheduled = false;
    _gameOverUpdateScheduled = false;
    super.dispose();
  }

  void _start() {
    ref.read(endlessRunnerControllerProvider.notifier).start();
    _game.reset();
    _game.resumeEngine();
  }

  void _pause() {
    ref.read(endlessRunnerControllerProvider.notifier).pause();
    _game.pauseGame();
    _game.pauseEngine();
  }

  void _resume() {
    ref.read(endlessRunnerControllerProvider.notifier).resume();
    _game.resumeGame();
    _game.resumeEngine();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(endlessRunnerControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF10151D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          if (state.status == EndlessRunnerStatus.playing)
            EndlessRunnerHud(
              score: state.score,
              coins: state.coins,
              distance: state.distance,
              onPause: _pause,
              onLeft: _game.moveLeft,
              onRight: _game.moveRight,
              onJump: _game.jump,
              onDuck: _game.duck,
            ),
          if (state.status == EndlessRunnerStatus.menu) _MenuOverlay(onStart: _start),
          if (state.status == EndlessRunnerStatus.paused)
            _PauseOverlay(onResume: _resume, onMenu: () {
              ref.read(endlessRunnerControllerProvider.notifier).backToMenu();
              _game.pauseEngine();
            }),
          if (state.status == EndlessRunnerStatus.gameOver)
            _GameOverOverlay(state: state, onRestart: _start, onMenu: () {
              ref.read(endlessRunnerControllerProvider.notifier).backToMenu();
              _game.pauseEngine();
            }),
        ],
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _CenterCard(
      title: 'ENDLESS RUNNER',
      subtitle: 'Dodge • Jump • Collect • Survive',
      buttonLabel: 'START RUN',
      onPressed: onStart,
      icon: Icons.directions_run_rounded,
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onMenu});
  final VoidCallback onResume;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _CenterCard(
      title: 'PAUSED',
      subtitle: 'Take a breath. The road is waiting.',
      buttonLabel: 'RESUME',
      onPressed: onResume,
      icon: Icons.pause_circle_filled_rounded,
      secondaryLabel: 'MAIN MENU',
      onSecondary: onMenu,
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.state, required this.onRestart, required this.onMenu});
  final EndlessRunnerState state;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _CenterCard(
      title: 'RUN OVER',
      subtitle: 'Score ${state.score}  •  ${state.coins} coins  •  ${state.distance.floor()}m',
      buttonLabel: 'RUN AGAIN',
      onPressed: onRestart,
      icon: Icons.replay_rounded,
      secondaryLabel: 'MAIN MENU',
      onSecondary: onMenu,
      extra: state.score >= state.bestScore
          ? const Text('🏆  BEST SCORE!', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900))
          : Text('Best: ${state.bestScore}', style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    required this.icon,
    this.secondaryLabel,
    this.onSecondary,
    this.extra,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final IconData icon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 390),
          decoration: BoxDecoration(
            color: const Color(0xFF18202B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const [BoxShadow(blurRadius: 35, color: Colors.black54)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 62, color: const Color(0xFFFFC107)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              if (extra != null) ...[const SizedBox(height: 14), extra!],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(buttonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
