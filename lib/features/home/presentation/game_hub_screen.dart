import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sfx.dart';
import '../../../../core/audio/sfx_player.dart';
import '../../../../core/feedback/haptics.dart';
import '../../../../core/persistence/game_progress_store.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../angry_bird/presentation/angry_bird_levels.dart';
import '../../angry_bird/presentation/angry_bird_screen.dart';
import '../../endless_runner/presentation/endless_runner_screen.dart';
import '../../fire_game/presentation/fire_game_screen.dart';
import '../../football_penalty/football_penalty_screen.dart';
import '../../gulti/presentation/gulti_screen.dart';
import '../../racing/presentation/racing_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sniper/sniper_screen.dart';
import '../../sniper2/sniper_screen.dart';


/// The arcade "front door" — a cartoon, glowing dashboard that lists every
/// mini-game as its own themed cabinet card. Adding a new game only means
/// appending one more [_GameEntry] to [_GameHubScreenState._buildGameEntries];
/// the grid, entrance animation and card chrome all scale automatically.
class GameHubScreen extends ConsumerStatefulWidget {
  const GameHubScreen({super.key});

  @override
  ConsumerState<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends ConsumerState<GameHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _openGame(Widget screen) {
    final sound = ref.read(settingsControllerProvider).soundEnabled;
    final haptics = ref.read(settingsControllerProvider).hapticsEnabled;
    ref.read(sfxPlayerProvider).play(Sfx.select, enabled: sound);
    AppHaptics.light(haptics);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  List<_GameEntry> _buildGameEntries(BuildContext context) {
    final store = ref.watch(gameProgressStoreProvider);
    final smashUnlocked = store.getInt(ProgressKeys.smashUnlockedLevels, fallback: 1);

    return [
      _GameEntry(
        icon: Icons.sports_soccer_rounded,
        title: 'PENALTY KINGS',
        tag: 'KICK',
        description: 'Pick your corner, beat the keeper and build a scoring streak.',
        colors: const [Color(0xFF159447), Color(0xFF63D9FF)],
        glow: const Color(0xFF63D9FF),
        badge: _bestBadge(store.getInt(ProgressKeys.penaltyBestScore)),
        onTap: () => _openGame(const FootballPenaltyScreen()),
      ),
      _GameEntry(
        icon: Icons.directions_car_filled_rounded,
        title: '2D RACING',
        tag: 'DRIVE',
        description: 'Dodge traffic, survive the road and chase a high score.',
        colors: const [Color(0xFFFF7A50), Color(0xFFFFC94A)],
        glow: const Color(0xFFFF7A50),
        badge: _bestBadge(store.getInt(ProgressKeys.racingBestScore)),
        onTap: () => _openGame(const RacingScreenView()),
      ),
      _GameEntry(
        icon: Icons.directions_run_rounded,
        title: 'ENDLESS RUNNER',
        tag: 'RUN',
        description: 'Switch lanes, jump obstacles, collect coins and survive.',
        colors: const [Color(0xFF11998E), Color(0xFF3DDC97)],
        glow: const Color(0xFF3DDC97),
        badge: _bestBadge(store.getInt(ProgressKeys.runnerBestScore)),
        onTap: () => _openGame(const EndlessRunnerScreen()),
      ),
      _GameEntry(
        icon: Icons.local_fire_department_rounded,
        title: '2D FIRE',
        tag: 'SURVIVE',
        description:
        'Shoot incoming enemies, survive the waves and beat your high score.',
        colors: const [Color(0xFFEB4B3D), Color(0xFFFFA24A)],
        glow: const Color(0xFFEB4B3D),
        badge: _bestBadge(store.getInt(ProgressKeys.fireBestScore)),
        onTap: () => _openGame(const FireGameScreen()),
      ),
      _GameEntry(
        icon: Icons.adjust_rounded,
        title: 'PHYSICS SMASH',
        tag: 'SMASH',
        description: 'Sling birds, topple structures and smash every pig.',
        colors: const [Color(0xFF6FC8FF), Color(0xFF8FD14F)],
        glow: const Color(0xFF6FC8FF),
        badge: smashUnlocked <= 1
            ? null
            : '$smashUnlocked/${angryBirdLevels.length} LEVELS',
        onTap: () => _openGame(const AngryBirdScreen()),
      ),
      _GameEntry(
        icon: Icons.flutter_dash_rounded,
        title: 'GULTI SHOOT',
        tag: 'AIM',
        description: 'Pull back the gulti, read the flock and take your shot.',
        colors: const [Color(0xFFE0703C), Color(0xFFFFC94A)],
        glow: const Color(0xFFE0703C),
        badge: _bestBadge(store.getInt(ProgressKeys.gultiBestScore)),
        onTap: () => _openGame(const GultiScreen()),
      ),
      _GameEntry(
        icon: Icons.multitrack_audio_sharp,
        title: 'SNIPER MISSION',
        tag: 'AIM',
        description: 'Drag to aim, fire on target and clear 10 desert missions.',
        colors: const [Color(0xFFFF8A3D), Color(0xFF2DD9C7)],
        glow: const Color(0xFF2DD9C7),
        // badge: _bestBadge(store.getInt(ProgressKeys.sniperBestScore)),
        onTap: () => _openGame(const Sniper2Screen()),
      ),
      _GameEntry(
        icon: Icons.track_changes_rounded,
        title: 'TARGET MISSION',
        tag: 'AIM',
        description: 'Drag to aim, fire on target and clear 10 desert missions.',
        colors: const [Color(0xFFFF8A3D), Color(0xFF2DD9C7)],
        glow: const Color(0xFF2DD9C7),
        // badge: _bestBadge(store.getInt(ProgressKeys.sniperBestScore)),
        onTap: () => _openGame(const SniperScreen()),
        // onTap: () => _openGame(const FireGame2Screen()),
      ),
    ];
  }

  String? _bestBadge(int best) => best > 0 ? 'BEST $best' : null;

  @override
  Widget build(BuildContext context) {
    final games = _buildGameEntries(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Stack(
        children: [
          const _HubBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    children: [
                      _HubHeader(
                        bounce: _bounce,
                        gameCount: games.length,
                        onSettingsTap: () {
                          final sound = ref.read(settingsControllerProvider).soundEnabled;
                          ref.read(sfxPlayerProvider).play(Sfx.tap, enabled: sound);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                          constraints.maxWidth < 620 ? 1 : 2;
                          return GridView.builder(
                            itemCount: games.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 18,
                              childAspectRatio:
                              crossAxisCount == 1 ? 1.38 : 0.82,
                            ),
                            itemBuilder: (context, index) => _AnimatedEntrance(
                              delay: index * 90,
                              child: _GameCard(entry: games[index]),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Background — layered gradient, soft color blobs, scattered stars
// ===========================================================================

class _HubBackground extends StatelessWidget {
  const _HubBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E17), Color(0xFF141B2B), Color(0xFF0E1420)],
            ),
          ),
        ),
        const Positioned(
          top: -70,
          left: -60,
          child: _Blob(color: Color(0xFFFF7A50), size: 220),
        ),
        const Positioned(
          top: 110,
          right: -80,
          child: _Blob(color: Color(0xFF3DDC97), size: 240),
        ),
        const Positioned(
          bottom: -60,
          left: 30,
          child: _Blob(color: Color(0xFF6FC8FF), size: 260),
        ),
        const Positioned(
          bottom: 40,
          right: -50,
          child: _Blob(color: Color(0xFFEB4B3D), size: 200),
        ),
        CustomPaint(painter: _StarsPainter(), size: Size.infinite),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
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
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.6 + rnd.nextDouble() * 1.3;
      paint.color = Colors.white.withValues(alpha: 0.12 + rnd.nextDouble() * 0.22);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => false;
}

// ===========================================================================
// Header — bouncing mascot badge + gradient marquee title
// ===========================================================================

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.bounce,
    required this.gameCount,
    required this.onSettingsTap,
  });
  final Animation<double> bounce;
  final int gameCount;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_rounded, color: Colors.white54),
            tooltip: 'Settings',
          ),
        ),
        AnimatedBuilder(
          animation: bounce,
          builder: (context, child) {
            final lift = math.sin(bounce.value * math.pi) * 6;
            return Transform.translate(offset: Offset(0, -lift), child: child);
          },
          child: Image.asset("assets/play-bits.png"),
        ),
        const SizedBox(height: 18),
        // ShaderMask(
        //   shaderCallback: (rect) => const LinearGradient(
        //     colors: [Color(0xFFFFC94A), Color(0xFFFF7A50)],
        //   ).createShader(rect),
        //   child: const Text(
        //     'PLAYBITS',
        //     textAlign: TextAlign.center,
        //     style: TextStyle(
        //       fontSize: 40,
        //       fontWeight: FontWeight.w900,
        //       letterSpacing: 1.5,
        //       color: Colors.white,
        //       height: 1,
        //     ),
        //   ),
        // ),
        // const SizedBox(height: 12),
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //   decoration: BoxDecoration(
        //     color: Colors.white.withValues(alpha: 0.08),
        //     borderRadius: BorderRadius.circular(20),
        //     border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        //   ),
        //   child: Text(
        //     '$gameCount GAMES • ONE ARCADE • TAP TO PLAY',
        //     style: const TextStyle(
        //       color: Colors.white60,
        //       fontSize: 11,
        //       fontWeight: FontWeight.w800,
        //       letterSpacing: 1.4,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

// ===========================================================================
// Staggered entrance
// ===========================================================================

class _AnimatedEntrance extends StatefulWidget {
  const _AnimatedEntrance({required this.delay, required this.child});
  final int delay;
  final Widget child;

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ===========================================================================
// Game card model + cartoon "cabinet" card
// ===========================================================================

class _GameEntry {
  const _GameEntry({
    required this.icon,
    required this.title,
    required this.tag,
    required this.description,
    required this.colors,
    required this.glow,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String tag;
  final String description;
  final List<Color> colors;
  final Color glow;
  final VoidCallback onTap;
  final String? badge;
}

class _GameCard extends StatefulWidget {
  const _GameCard({required this.entry});
  final _GameEntry entry;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: entry.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(entry.colors.first, Colors.black, 0.62)!,
                Color.lerp(entry.colors.last, Colors.black, 0.7)!,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: entry.glow.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                bottom: -22,
                child: Icon(
                  entry.icon,
                  size: 130,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: entry.colors),
                            boxShadow: [
                              BoxShadow(
                                color: entry.glow.withValues(alpha: 0.5),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(entry.icon, color: Colors.white, size: 30),
                        ),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (entry.badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: entry.glow.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: entry.glow.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 13, color: entry.glow),
                            const SizedBox(width: 5),
                            Text(
                              entry.badge!,
                              style: TextStyle(
                                color: entry.glow,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Text(
                          'PLAY NOW',
                          style: TextStyle(
                            color: entry.colors.last,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: entry.colors.last,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}