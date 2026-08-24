import 'package:flutter/material.dart';

/// A single mission's tuning — how many targets to clear, how much ammo,
/// whether there's a timer, and how fast/likely targets move. Ten of these
/// (see [SniperConfig.levels]) make up the full campaign, each a little
/// harder than the last.
@immutable
class SniperLevelConfig {
  const SniperLevelConfig({
    required this.id,
    required this.label,
    required this.objective,
    required this.targetGoal,
    required this.ammo,
    required this.spawnInterval,
    required this.targetSpeed,
    required this.movingRatio,
    this.timeLimit,
    this.completionBonus = 150,
  });

  final int id;
  final String label;
  final String objective;

  /// Number of targets that must be hit to clear the mission.
  final int targetGoal;
  final int ammo;

  /// Seconds between target spawns.
  final double spawnInterval;

  /// Horizontal speed (px/s) used by moving targets.
  final double targetSpeed;

  /// Chance (0..1) that a freshly spawned target moves instead of standing.
  final double movingRatio;

  /// Mission timer in seconds. Null means no timer.
  final double? timeLimit;

  final int completionBonus;
}

/// Tunable values and the "Sundown Canyon" desert palette shared by the
/// sniper game's engine, HUD and menus.
abstract final class SniperConfig {
  // ---- Palette -------------------------------------------------------------
  static const Color skyTop = Color(0xFF35D6C4);
  static const Color skyBottom = Color(0xFFBDF0E6);
  static const Color cloudColor = Color(0xFFF3FFFC);

  static const Color canyonFar = Color(0xFFE0954A);
  static const Color canyonMid = Color(0xFFD97D3B);
  static const Color canyonNear = Color(0xFFC96A2E);
  static const Color sandLight = Color(0xFFE9C27C);
  static const Color sandDark = Color(0xFFD9A75C);

  static const Color cactusGreen = Color(0xFF4E9B4B);
  static const Color cactusDark = Color(0xFF3D7A3B);

  static const Color banditShirtA = Color(0xFFD9522B);
  static const Color banditShirtB = Color(0xFF3E6FA8);
  static const Color banditShirtC = Color(0xFF6B4F9B);
  static const Color banditSkin = Color(0xFFE8B583);
  static const Color banditHat = Color(0xFF5B3B24);

  static const Color gunMetal = Color(0xFF3A3F44);
  static const Color gunMetalDark = Color(0xFF23262A);
  static const Color scopeGlass = Color(0xFF9BE8DD);
  static const Color scopeGlow = Color(0xFF4DD8FF);

  static const Color crosshair = Color(0xFFFFFFFF);
  static const Color muzzleFlash = Color(0xFFFFE082);
  static const Color bulletTrail = Color(0xFFFFF3C4);

  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyDeep = Color(0xFF060A11);
  static const Color cream = Color(0xFFFFF6E9);
  static const Color gold = Color(0xFFFFC94A);
  static const Color violet = Color(0xFF9B59F6);

  // ---- Gameplay tuning -----------------------------------------------------
  static const int slotCount = 4;
  static const double targetRadius = 30;

  static const double riseDuration = 0.26;
  static const double fallDuration = 0.3;
  static const double idleTimeout = 4.5;

  static const double bulletFlightDuration = 0.11;
  static const double crashShakeDuration = 0.22;
  static const double crashShakeMagnitude = 6;

  static const double accuracyBonusThreshold = 90;
  static const int accuracyBonusPoints = 250;

  static const int targetHitScore = 100;

  /// The full 10-mission campaign. Difficulty ramps via more targets, less
  /// ammo headroom, faster/likelier moving targets, and tighter timers.
  static const List<SniperLevelConfig> levels = [
    SniperLevelConfig(
      id: 1,
      label: 'LEVEL 1',
      objective: 'Hit 3 targets',
      targetGoal: 3,
      ammo: 6,
      spawnInterval: 1.6,
      targetSpeed: 0,
      movingRatio: 0,
    ),
    SniperLevelConfig(
      id: 2,
      label: 'LEVEL 2',
      objective: 'Hit 4 targets',
      targetGoal: 4,
      ammo: 7,
      spawnInterval: 1.5,
      targetSpeed: 40,
      movingRatio: 0.2,
    ),
    SniperLevelConfig(
      id: 3,
      label: 'LEVEL 3',
      objective: 'Hit the moving targets',
      targetGoal: 4,
      ammo: 7,
      spawnInterval: 1.4,
      targetSpeed: 55,
      movingRatio: 0.85,
    ),
    SniperLevelConfig(
      id: 4,
      label: 'LEVEL 4',
      objective: 'Hit 5 targets — low ammo',
      targetGoal: 5,
      ammo: 5,
      spawnInterval: 1.3,
      targetSpeed: 50,
      movingRatio: 0.4,
    ),
    SniperLevelConfig(
      id: 5,
      label: 'LEVEL 5',
      objective: 'Finish before time runs out',
      targetGoal: 5,
      ammo: 9,
      spawnInterval: 1.2,
      targetSpeed: 55,
      movingRatio: 0.5,
      timeLimit: 35,
    ),
    SniperLevelConfig(
      id: 6,
      label: 'LEVEL 6',
      objective: 'Hit 6 targets',
      targetGoal: 6,
      ammo: 8,
      spawnInterval: 1.15,
      targetSpeed: 60,
      movingRatio: 0.55,
    ),
    SniperLevelConfig(
      id: 7,
      label: 'LEVEL 7',
      objective: 'Hit 6 targets — low ammo',
      targetGoal: 6,
      ammo: 7,
      spawnInterval: 1.05,
      targetSpeed: 65,
      movingRatio: 0.6,
    ),
    SniperLevelConfig(
      id: 8,
      label: 'LEVEL 8',
      objective: 'Finish before time runs out',
      targetGoal: 7,
      ammo: 10,
      spawnInterval: 1.0,
      targetSpeed: 70,
      movingRatio: 0.65,
      timeLimit: 32,
    ),
    SniperLevelConfig(
      id: 9,
      label: 'LEVEL 9',
      objective: 'Hit 7 targets — low ammo',
      targetGoal: 7,
      ammo: 8,
      spawnInterval: 0.95,
      targetSpeed: 75,
      movingRatio: 0.7,
    ),
    SniperLevelConfig(
      id: 10,
      label: 'LEVEL 10',
      objective: 'Final mission — beat the clock',
      targetGoal: 8,
      ammo: 11,
      spawnInterval: 0.9,
      targetSpeed: 80,
      movingRatio: 0.75,
      timeLimit: 30,
      completionBonus: 400,
    ),
  ];
}
