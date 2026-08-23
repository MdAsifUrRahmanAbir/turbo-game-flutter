import 'package:flutter/material.dart';

/// Tunable values and the "Neon Boardwalk" palette shared by the sniper
/// game's engine, HUD and menus. Centralising these makes it trivial to
/// re-skin or re-balance the whole feature from one place.
abstract final class SniperConfig {
  // ---- Palette -----------------------------------------------------------
  static const Color skyTop = Color(0xFF2B1150);
  static const Color skyMid = Color(0xFF6E2C7A);
  static const Color skyBottom = Color(0xFFFF6F91);
  static const Color bulbGlow = Color(0xFFFFE082);

  static const Color wallLight = Color(0xFF8B5A3C);
  static const Color wallDark = Color(0xFF6B4028);
  static const Color postColor = Color(0xFF4A2E1C);

  static const Color bullseyeRed = Color(0xFFFF4757);
  static const Color bullseyeWhite = Color(0xFFFFF6E9);
  static const Color bullseyeGold = Color(0xFFFFD54F);

  static const Color duckBody = Color(0xFF4DD8FF);
  static const Color duckAccent = Color(0xFFFFC94A);

  static const Color decoyBody = Color(0xFFB9F0C4);
  static const Color decoyAccent = Color(0xFFFF6B4A);

  static const Color goldenCore = Color(0xFFFFF3C4);
  static const Color goldenMid = Color(0xFFFFD54F);
  static const Color goldenOuter = Color(0xFFFF9F40);

  static const Color crosshair = Color(0xFF4DD8FF);
  static const Color crosshairFire = Color(0xFFFF4757);

  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyDeep = Color(0xFF060A11);
  static const Color cream = Color(0xFFFFF6E9);
  static const Color gold = Color(0xFFFFC94A);
  static const Color violet = Color(0xFF9B59F6);

  static const List<Color> confetti = [
    Color(0xFFFF6B4A),
    Color(0xFFFFC94A),
    Color(0xFF0EC9B0),
    Color(0xFF6C63FF),
    Color(0xFFFF5C93),
  ];

  // ---- Gameplay tuning -----------------------------------------------------
  static const int slotCount = 5;
  static const double targetRadius = 34;
  static const double duckRadius = 26;
  static const double goldenRadius = 26;

  static const double riseDuration = 0.28;
  static const double holdDuration = 2.2;
  static const double fallDuration = 0.22;
  static const double goldenHoldDuration = 1.1;

  static const double baseSpawnInterval = 0.9;
  static const double minSpawnInterval = 0.42;

  static const double decoyChanceBase = 0.14;
  static const double decoyChancePerWave = 0.02;
  static const double decoyChanceCap = 0.34;

  static const double goldenChance = 0.06;

  static const double duckSpawnInterval = 3.2;
  static const double duckSpeedBase = 90;
  static const double duckSpeedPerWave = 8;

  static const int maxAmmo = 6;
  static const double reloadDuration = 1.1;

  static const int maxStrikes = 3;
  static const int hitsPerWave = 12;

  static const double comboWindow = 1.6;
  static const double comboScoreStep = 0.15;
  static const int maxComboStacks = 10;

  static const int bullseyeCenterScore = 100;
  static const int bullseyeMidScore = 50;
  static const int bullseyeOuterScore = 20;
  static const int duckScore = 60;
  static const int goldenScore = 200;
  static const int decoyPenalty = 100;

  static const double crashShakeDuration = 0.3;
  static const double crashShakeMagnitude = 8;
}
