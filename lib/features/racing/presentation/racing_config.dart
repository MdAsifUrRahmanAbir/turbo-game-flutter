import 'package:flutter/material.dart';

/// Tunable values and the "Sunset Candy" palette shared by the racing
/// game, its HUD and its menus. Centralising these makes it trivial to
/// re-skin or re-balance the whole feature from one place.
abstract final class RacingConfig {
  // ---- Palette ---------------------------------------------------------
  static const Color skyTop = Color(0xFFFF9B6A);
  static const Color skyMid = Color(0xFFFFB177);
  static const Color skyBottom = Color(0xFFFFD98A);
  static const Color sun = Color(0xFFFFE9A8);

  static const Color roadDark = Color(0xFF2B2438);
  static const Color roadLight = Color(0xFF3A3050);
  static const Color laneStripe = Color(0xFFFFF6E9);
  static const Color roadEdge = Color(0xFFFFF1D6);

  static const Color grassA = Color(0xFF3DDC97);
  static const Color grassB = Color(0xFF2BB57C);
  static const Color treeTrunk = Color(0xFF7A4B2E);
  static const Color treeLeaf = Color(0xFF1F9E63);

  static const Color playerBody = Color(0xFFFF5D5D);
  static const Color playerBodyDark = Color(0xFFCF3F3F);
  static const Color playerAccent = Color(0xFFFFE156);
  static const Color canopy = Color(0xFFBEE9FF);

  static const Color coinColor = Color(0xFFFFD54F);
  static const Color coinShine = Color(0xFFFFF3C4);
  static const Color nitroColor = Color(0xFF4DD8FF);
  static const Color nitroGlow = Color(0xFF9CF2FF);

  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyDeep = Color(0xFF060A11);
  static const Color cream = Color(0xFFFFF6E9);
  static const Color gold = Color(0xFFFFC94A);

  static const List<Color> rivalBodies = [
    Color(0xFF4D7CFF),
    Color(0xFF9B59F6),
    Color(0xFF00C2A8),
    Color(0xFFFF9F40),
    Color(0xFFFF5C93),
  ];

  static const List<Color> confetti = [
    Color(0xFFFF6B4A),
    Color(0xFFFFC94A),
    Color(0xFF0EC9B0),
    Color(0xFF4D7CFF),
    Color(0xFFFF5C93),
  ];

  // ---- Gameplay tuning ---------------------------------------------------
  static const double baseSpeed = 0.34;
  static const double brakeSpeed = 0.18;
  static const double distanceForFullRamp = 1800;
  static const double speedRampCap = 0.30;

  static const double nitroSpeedBoost = 0.30;
  static const double nitroDuration = 2.2;
  static const double nitroCooldown = 6.0;

  static const double coinSpawnChance = 0.55;
  static const int coinScoreValue = 25;
  static const double nitroTokenChance = 0.10;

  static const double laneMin = 0.16;
  static const double laneMax = 0.84;
  static const double steerRate = 0.42;

  static const double crashShakeDuration = 0.4;
  static const double crashShakeMagnitude = 10;
}
