import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/fire_game_controller.dart';
import '../controllers/fire_game_state.dart';
import '../game/fire_game.dart';
import '../widgets/fire_game_hud.dart';

class FireGameScreen extends ConsumerStatefulWidget {
  const FireGameScreen({super.key});

  @override
  ConsumerState<FireGameScreen> createState() => _FireGameScreenState();
}

class _FireGameScreenState extends ConsumerState<FireGameScreen> {
  late final FireGame _game;

  @override
  void initState() {
    super.initState();

    _game = FireGame(
      onHudUpdate: ({
        required score,
        required health,
        required wave,
        required enemiesDefeated,
      }) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          ref.read(fireGameControllerProvider.notifier).updateHud(
                score: score,
                health: health,
                wave: wave,
                enemiesDefeated: enemiesDefeated,
              );
        });
      },
      onGameOver: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(fireGameControllerProvider.notifier).gameOver();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fireGameControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(game: _game),

          if (state.status == FireGameStatus.playing)
            FireGameHud(state: state, onPause: _pause),

          if (state.status == FireGameStatus.menu)
            _MenuOverlay(onStart: _start, bestScore: state.bestScore),

          if (state.status == FireGameStatus.paused)
            _PauseOverlay(onResume: _resume, onMenu: _backToMenu),

          if (state.status == FireGameStatus.gameOver)
            _GameOverOverlay(
              state: state,
              onRestart: _start,
              onMenu: _backToMenu,
            ),

          if (state.status == FireGameStatus.playing)
            _Controls(
              onLeft: () => _game.movePlayer(-45),
              onRight: () => _game.movePlayer(45),
              onFire: _game.shoot,
            ),
        ],
      ),
    );
  }

  void _start() {
    ref.read(fireGameControllerProvider.notifier).startGame();
    _game.resetGame();
  }

  void _pause() {
    ref.read(fireGameControllerProvider.notifier).pauseGame();
    _game.pauseGame();
  }

  void _resume() {
    ref.read(fireGameControllerProvider.notifier).resumeGame();
    _game.resumeGame();
  }

  void _backToMenu() {
    ref.read(fireGameControllerProvider.notifier).backToMenu();
    _game.pauseGame();
  }

  @override
  void dispose() {
    _game.pauseEngine();
    super.dispose();
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({required this.onStart, required this.bestScore});

  final VoidCallback onStart;
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥 FIRE SURVIVAL',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'BEST SCORE: $bestScore',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 30),
          _GameButton(
            label: 'START GAME',
            icon: Icons.play_arrow,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onMenu});

  final VoidCallback onResume;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _GameButton(
            label: 'RESUME',
            icon: Icons.play_arrow,
            onPressed: onResume,
          ),
          const SizedBox(height: 12),
          _GameButton(
            label: 'MENU',
            icon: Icons.home,
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.state,
    required this.onRestart,
    required this.onMenu,
  });

  final FireGameState state;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GAME OVER',
            style: TextStyle(
              color: Colors.red,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Score: ${state.score}',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          Text(
            'Best: ${state.bestScore}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _GameButton(
            label: 'PLAY AGAIN',
            icon: Icons.refresh,
            onPressed: onRestart,
          ),
          const SizedBox(height: 12),
          _GameButton(
            label: 'MENU',
            icon: Icons.home,
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.onLeft,
    required this.onRight,
    required this.onFire,
  });

  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onFire;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(icon: Icons.arrow_back, onPressed: onLeft),
          _ControlButton(
            icon: Icons.local_fire_department,
            size: 80,
            color: Colors.orange,
            onPressed: onFire,
          ),
          _ControlButton(icon: Icons.arrow_forward, onPressed: onRight),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.size = 60,
    this.color = Colors.white24,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
