import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/game_progress_store.dart';

const _soundKey = 'settings.soundEnabled';
const _hapticsKey = 'settings.hapticsEnabled';

@immutable
class SettingsState {
  const SettingsState({this.soundEnabled = true, this.hapticsEnabled = true});

  final bool soundEnabled;
  final bool hapticsEnabled;

  SettingsState copyWith({bool? soundEnabled, bool? hapticsEnabled}) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsState(
      soundEnabled: prefs.getBool(_soundKey) ?? true,
      hapticsEnabled: prefs.getBool(_hapticsKey) ?? true,
    );
  }

  void toggleSound() {
    final next = !state.soundEnabled;
    state = state.copyWith(soundEnabled: next);
    ref.read(sharedPreferencesProvider).setBool(_soundKey, next);
  }

  void toggleHaptics() {
    final next = !state.hapticsEnabled;
    state = state.copyWith(hapticsEnabled: next);
    ref.read(sharedPreferencesProvider).setBool(_hapticsKey, next);
  }
}
