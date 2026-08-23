import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sfx.dart';
import '../../core/audio/sfx_player.dart';
import '../../core/settings/settings_controller.dart';
import 'football_penalty_config.dart';
import 'football_penalty_controller.dart';
import 'football_penalty_game.dart';
import 'football_penalty_hud.dart';
import 'football_penalty_state.dart';

class FootballPenaltyScreen extends ConsumerStatefulWidget {
  const FootballPenaltyScreen({super.key});

  @override
  ConsumerState<FootballPenaltyScreen> createState() => _FootballPenaltyScreenState();
}

class _FootballPenaltyScreenState extends ConsumerState<FootballPenaltyScreen> {
  int _lastSeenRound = 1;
  String? _roundBanner;

  late final FootballPenaltyGame _game = FootballPenaltyGame(
    onHudChanged: ({
      required score,
      required shots,
      required goals,
      required streak,
      required round,
      required result,
      required ended,
    }) {
      _defer(() {
        ref.read(footballPenaltyControllerProvider.notifier).updateHud(
          score: score,
          shots: shots,
          goals: goals,
          streak: streak,
          round: round,
          result: result,
          ended: ended,
        );
        if (round > _lastSeenRound) _showRoundBanner(round);
        _lastSeenRound = round;
      });
    },
    onShotResult: (result, points, commentary) {
      _defer(() => ref.read(footballPenaltyControllerProvider.notifier).updateShot(
        result: result,
        points: points,
        commentary: commentary,
      ));
    },
  );

  void _defer(VoidCallback action) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _showRoundBanner(int round) {
    setState(() => _roundBanner = 'ROUND $round  •  ${FootballPenaltyConfig.difficultyLabel(round)} KEEPER');
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _roundBanner = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _game.pauseEngine();
  }

  @override
  void dispose() {
    _game.pauseEngine();
    super.dispose();
  }

  void _start() {
    ref.read(footballPenaltyControllerProvider.notifier).start();
    _game.reset();
    _game.resumeEngine();
    _lastSeenRound = 1;
    _roundBanner = null;
  }

  void _pause() {
    ref.read(footballPenaltyControllerProvider.notifier).pause();
    _game.pauseGame();
  }

  void _resume() {
    ref.read(footballPenaltyControllerProvider.notifier).resume();
    _game.resumeGame();
  }

  void _backToMenu() {
    ref.read(footballPenaltyControllerProvider.notifier).backToMenu();
    _game.pauseGame();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(footballPenaltyControllerProvider);

    return Scaffold(
      backgroundColor: FootballPenaltyConfig.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: (_) => _game.beginAim(),
            onPointerMove: (event) => _game.updateAim(event.localPosition),
            onPointerUp: (_) {
              final sound = ref.read(settingsControllerProvider).soundEnabled;
              ref.read(sfxPlayerProvider).play(Sfx.kick, enabled: sound);
              _game.releaseShot();
            },
            child: GameWidget(game: _game),
          ),
          if (state.status == FootballPenaltyStatus.playing)
            FootballPenaltyHud(
              score: state.score,
              shots: state.shotsTaken,
              goals: state.goals,
              streak: state.streak,
              round: state.round,
              power: _game.power,
              result: state.lastResult,
              commentary: state.lastCommentary,
              onPause: _pause,
            ),
          if (state.status == FootballPenaltyStatus.playing && _roundBanner != null)
            _RoundBanner(text: _roundBanner!),
          if (state.status == FootballPenaltyStatus.menu)
            _PenaltyMenu(state: state, onStart: _start),
          if (state.status == FootballPenaltyStatus.paused)
            _PauseOverlay(onResume: _resume, onMenu: _backToMenu),
          if (state.status == FootballPenaltyStatus.complete)
            _CompleteOverlay(state: state, onAgain: _start, onMenu: _backToMenu),
        ],
      ),
    );
  }
}

class _PenaltyBackdrop extends StatelessWidget {
  const _PenaltyBackdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FootballPenaltyConfig.navyDeep,
            FootballPenaltyConfig.navy,
            Color(0xFF17152C),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -80,
            right: -60,
            child: _Glow(color: FootballPenaltyConfig.coral, size: 250),
          ),
          const Positioned(
            bottom: -100,
            left: -80,
            child: _Glow(color: FootballPenaltyConfig.teal, size: 290),
          ),
          CustomPaint(painter: _StadiumLightsPainter()),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _StadiumLightsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .14);
    for (var i = 0; i < 18; i++) {
      final x = size.width * (0.05 + i * .055);
      final y = size.height * (.12 + (i.isEven ? .03 : 0));
      canvas.drawCircle(Offset(x, y), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StadiumLightsPainter oldDelegate) => false;
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RoundBanner extends StatelessWidget {
  const _RoundBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(text),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.85 + value * 0.15, child: child),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 70),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [FootballPenaltyConfig.gold, FootballPenaltyConfig.coral]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: FootballPenaltyConfig.coral.withValues(alpha: .5), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PenaltyMenu extends StatefulWidget {
  const _PenaltyMenu({required this.state, required this.onStart});
  final FootballPenaltyState state;
  final VoidCallback onStart;

  @override
  State<_PenaltyMenu> createState() => _PenaltyMenuState();
}

class _PenaltyMenuState extends State<_PenaltyMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PenaltyBackdrop(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, -_pulse.value * 6),
                      child: child,
                    ),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [FootballPenaltyConfig.coral, FootballPenaltyConfig.gold]),
                        boxShadow: [
                          BoxShadow(color: FootballPenaltyConfig.coral.withValues(alpha: .55), blurRadius: 32, spreadRadius: 2),
                        ],
                      ),
                      child: const Icon(Icons.sports_soccer_rounded, size: 54, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(colors: [FootballPenaltyConfig.gold, FootballPenaltyConfig.coral]).createShader(rect),
                    child: const Text(
                      'PENALTY KINGS',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('FIND THE CORNER  •  BEAT THE KEEPER', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                  const SizedBox(height: 28),
                  _GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    child: Column(
                      children: [
                        const Text('CLEAR THE ROUND. FACE A TOUGHER KEEPER.', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        const Text('Drag from the ball to aim, release to shoot. Watch which way the keeper leans before you let go — then curve one past them. Score 3 of 5 to advance; the keeper gets sharper every round.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                        const SizedBox(height: 18),
                        Wrap(alignment: WrapAlignment.center, spacing: 22, runSpacing: 12, children: const [
                          _MenuTip(icon: Icons.touch_app_rounded, label: 'AIM'),
                          _MenuTip(icon: Icons.bolt_rounded, label: 'POWER'),
                          _MenuTip(icon: Icons.remove_red_eye_rounded, label: 'READ THE KEEPER'),
                          _MenuTip(icon: Icons.local_fire_department_rounded, label: 'STREAK'),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  _PrimaryButton(label: 'KICK OFF', icon: Icons.play_arrow_rounded, onPressed: widget.onStart),
                  const SizedBox(height: 18),
                  Text(
                    'BEST SCORE  ${widget.state.bestScore.toString().padLeft(4, '0')}   •   BEST ROUND  ${widget.state.bestRound}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
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

class _MenuTip extends StatelessWidget {
  const _MenuTip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [Icon(icon, color: FootballPenaltyConfig.gold, size: 24), const SizedBox(height: 6), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8))]);
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: FootballPenaltyConfig.coral,
      foregroundColor: Colors.white,
      elevation: 12,
      shadowColor: FootballPenaltyConfig.coral.withValues(alpha: .5),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7),
    ),
  );
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onMenu});
  final VoidCallback onResume;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => _PenaltyBackdrop(
    child: Center(
      child: _GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_filled_rounded, color: FootballPenaltyConfig.gold, size: 68),
            const SizedBox(height: 14),
            const Text('MATCH PAUSED', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 24),
            _PrimaryButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: onResume),
            const SizedBox(height: 12),
            TextButton(onPressed: onMenu, child: const Text('QUIT TO MENU', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    ),
  );
}

class _CompleteOverlay extends StatelessWidget {
  const _CompleteOverlay({required this.state, required this.onAgain, required this.onMenu});
  final FootballPenaltyState state;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => _PenaltyBackdrop(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, color: FootballPenaltyConfig.gold, size: 72),
              const SizedBox(height: 8),
              const Text('FULL TIME', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(
                'ROUND ${state.round}  •  ${FootballPenaltyConfig.difficultyLabel(state.round)} KEEPER',
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 26,
                runSpacing: 16,
                children: [
                  _ResultStat(label: 'GOALS', value: '${state.goals}/5', color: FootballPenaltyConfig.lime),
                  _ResultStat(label: 'SCORE', value: '${state.score}', color: FootballPenaltyConfig.gold),
                  _ResultStat(label: 'BEST SCORE', value: '${state.bestScore}', color: FootballPenaltyConfig.cyan),
                  _ResultStat(label: 'BEST ROUND', value: '${state.bestRound}', color: FootballPenaltyConfig.violet),
                ],
              ),
              const SizedBox(height: 28),
              _PrimaryButton(label: 'PLAY AGAIN', icon: Icons.replay_rounded, onPressed: onAgain),
              const SizedBox(height: 12),
              TextButton(onPressed: onMenu, child: const Text('BACK TO MENU', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))]);
}
