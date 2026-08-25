import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in [main] once [SharedPreferences.getInstance] resolves, so
/// every provider below can read/write synchronously for the rest of the
/// app's life.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final gameProgressStoreProvider = Provider<GameProgressStore>((ref) {
  return GameProgressStore(ref.watch(sharedPreferencesProvider));
});

/// Thin, typed wrapper around [SharedPreferences] used by every game to
/// persist best scores and unlock progress across app restarts.
class GameProgressStore {
  GameProgressStore(this._prefs);

  final SharedPreferences _prefs;

  int getInt(String key, {int fallback = 0}) => _prefs.getInt(key) ?? fallback;

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  double getDouble(String key, {double fallback = 0}) =>
      _prefs.getDouble(key) ?? fallback;

  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  /// Persists a sparse `levelIndex -> stars` map (used by Physics Smash and
  /// Gulti Shoot) as compact JSON.
  Map<int, int> getIntMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(int.parse(k), v as int));
  }

  Future<void> setIntMap(String key, Map<int, int> value) {
    final encoded = jsonEncode(value.map((k, v) => MapEntry(k.toString(), v)));
    return _prefs.setString(key, encoded);
  }
}

/// Shared-preferences keys, namespaced per game so each feature owns its
/// slice without colliding with the others.
abstract final class ProgressKeys {
  // Racing
  static const racingBestScore = 'racing.bestScore';
  static const racingTotalCoins = 'racing.totalCoins';

  // Endless runner
  static const runnerBestScore = 'runner.bestScore';
  static const runnerBestDistance = 'runner.bestDistance';
  static const runnerTotalCoins = 'runner.totalCoins';

  // Fire game
  static const fireBestScore = 'fire.bestScore';

  // Football penalty
  static const penaltyBestScore = 'penalty.bestScore';
  static const penaltyBestRound = 'penalty.bestRound';

  // Physics smash (angry bird)
  static const smashUnlockedLevels = 'smash.unlockedLevels';
  static const smashLevelStars = 'smash.levelStars';
  static const smashTotalScore = 'smash.totalScore';

  // Gulti shoot
  static const gultiUnlockedLevels = 'gulti.unlockedLevels';
  static const gultiLevelStars = 'gulti.levelStars';
  static const gultiTotalScore = 'gulti.totalScore';
  static const gultiBestScore = 'gulti.bestScore';

  // Sunset Hoops
  static const hoopsBestScore = 'hoops.bestScore';
  static const hoopsBestStreak = 'hoops.bestStreak';
}