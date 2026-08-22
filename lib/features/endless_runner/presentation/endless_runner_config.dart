import 'package:flutter/material.dart';

/// Tunable values and the "Candy Park Sprint" palette shared by the endless
/// runner's game, HUD and menus. Centralising these makes it trivial to
/// re-skin or re-balance the whole feature from one place.
abstract final class EndlessRunnerConfig {
  // ---- Palette -------------------------------------------------------------
  static const Color skyTop = Color(0xFF7FD8FF);
  static const Color skyMid = Color(0xFFAEE9FF);
  static const Color skyBottom = Color(0xFFFFF4D6);
  static const Color sun = Color(0xFFFFE9A8);

  static const Color pathLight = Color(0xFFFFD3E8);
  static const Color pathDark = Color(0xFFFFB6D9);
  static const Color laneStripe = Color(0xFFFFFFFF);
  static const Color pathEdge = Color(0xFFFF8FC1);

  static const Color grassA = Color(0xFF8CE99A);
  static const Color grassB = Color(0xFF63D477);
  static const Color treeTrunk = Color(0xFF9A6B3F);

  static const Color playerBody = Color(0xFFFFC94A);
  static const Color playerBodyDark = Color(0xFFE0A63A);
  static const Color playerAccent = Color(0xFFFF6B4A);
  static const Color playerCheeks = Color(0xFFFF9EBB);

  static const Color coinColor = Color(0xFFFFD54F);
  static const Color coinShine = Color(0xFFFFF3C4);
  static const Color shieldColor = Color(0xFF4DD8FF);
  static const Color shieldGlow = Color(0xFF9CF2FF);

  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color navy = Color(0xFF120B1F);
  static const Color navyDeep = Color(0xFF08050D);
  static const Color cream = Color(0xFFFFF6E9);
  static const Color gold = Color(0xFFFFC94A);
  static const Color violet = Color(0xFF9B59F6);

  static const List<Color> obstaclePalette = [
    Color(0xFFFF5D5D),
    Color(0xFF6C63FF),
    Color(0xFF00C2A8),
  ];

  static const List<Color> confetti = [
    Color(0xFFFF6B4A),
    Color(0xFFFFC94A),
    Color(0xFF0EC9B0),
    Color(0xFF6C63FF),
    Color(0xFFFF5C93),
  ];

  // ---- Layout ---------------------------------------------------------------
  static const int laneCount = 3;

  // ---- Gameplay tuning --------------------------------------------------------
  static const double baseSpeed = 0.30;
  static const double speedRampCap = 0.30;
  static const double distanceForFullRamp = 2200;

  static const double jumpDuration = 0.58;
  static const double jumpHeight = 0.17;
  static const double duckDuration = 0.55;
  static const double laneSlideSpeed = 9.0;

  static const double shieldDuration = 6.0;
  static const double shieldTokenChance = 0.10;
  static const double coinRowChance = 0.55;
  static const int coinScoreValue = 15;

  static const double crashShakeDuration = 0.4;
  static const double crashShakeMagnitude = 10;

  static const double playerWidth = 52;
  static const double playerHeight = 78;
}
