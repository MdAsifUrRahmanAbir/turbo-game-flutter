import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx.dart';
import '../../../core/audio/sfx_player.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/persistence/game_progress_store.dart';
import '../../../core/settings/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final sfx = ref.read(sfxPlayerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SETTINGS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const _SectionLabel('AUDIO & FEEDBACK'),
            _SettingsCard(
              children: [
                _SettingsSwitch(
                  icon: Icons.volume_up_rounded,
                  title: 'Sound effects',
                  subtitle: 'Chimes, hits and celebration cues',
                  value: settings.soundEnabled,
                  onChanged: (_) {
                    controller.toggleSound();
                    sfx.play(Sfx.tap, enabled: !settings.soundEnabled);
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                _SettingsSwitch(
                  icon: Icons.vibration_rounded,
                  title: 'Haptics',
                  subtitle: 'Vibration feedback on taps and impacts',
                  value: settings.hapticsEnabled,
                  onChanged: (_) {
                    controller.toggleHaptics();
                    AppHaptics.medium(!settings.hapticsEnabled);
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionLabel('PROGRESS'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  iconColor: const Color(0xFFFF7A50),
                  title: 'Reset all progress',
                  subtitle: 'Clears every high score and unlocked level',
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionLabel('ABOUT'),
            _SettingsCard(
              children: const [
                _SettingsTile(
                  icon: Icons.sports_esports_rounded,
                  iconColor: Color(0xFF63D9FF),
                  title: 'PlayBits',
                  subtitle: 'Version 1.0.0 — five games, one arcade',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141B2B),
        title: const Text('Reset all progress?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Every high score and unlocked level across all five games will be cleared. This can\'t be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset', style: TextStyle(color: Color(0xFFFF5C5C))),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final store = ref.read(gameProgressStoreProvider);
    for (final key in const [
      ProgressKeys.racingBestScore,
      ProgressKeys.racingTotalCoins,
      ProgressKeys.runnerBestScore,
      ProgressKeys.runnerBestDistance,
      ProgressKeys.runnerTotalCoins,
      ProgressKeys.fireBestScore,
      ProgressKeys.penaltyBestScore,
      ProgressKeys.smashUnlockedLevels,
      ProgressKeys.smashLevelStars,
      ProgressKeys.smashTotalScore,
    ]) {
      await store.setInt(key, 0);
    }
    await store.setIntMap(ProgressKeys.smashLevelStars, const {});
    await store.setInt(ProgressKeys.smashUnlockedLevels, 1);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset. Restart games to see fresh scores.')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFFF7A50),
      secondary: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    this.iconColor = Colors.white70,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}
