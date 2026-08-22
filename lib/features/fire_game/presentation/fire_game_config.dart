import 'package:flutter/material.dart';

/// Tunable values and the "Ember Canyon" sunset palette shared by the fire
/// game's engine, HUD and menus. Centralising these makes it trivial to
/// re-skin or re-balance the whole feature from one place.
abstract final class FireGameConfig {
  // ---- Palette ---------------------------------------------------------
  static const Color skyTop = Color(0xFF2B0B3D);
  static const Color skyMid = Color(0xFF6E1F4B);
  static const Color skyBottom = Color(0xFFFF6B4A);
  static const Color sunGlow = Color(0xFFFFB454);

  static const Color mountainFar = Color(0xFF3A1440);
  static const Color mountainNear = Color(0xFF23092B);
  static const Color groundLight = Color(0xFF4A2038);
  static const Color groundDark = Color(0xFF2E1224);
  static const Color lavaCrack = Color(0xFFFF7A3D);

  static const Color playerBody = Color(0xFFFF7A3D);
  static const Color playerBodyDark = Color(0xFFCF5522);
  static const Color playerFlame = Color(0xFFFFD54F);
  static const Color playerCheeks = Color(0xFFFF9EBB);

  static const Color fireballCore = Color(0xFFFFF3C4);
  static const Color fireballMid = Color(0xFFFFC94A);
  static const Color fireballOuter = Color(0xFFFF6B4A);
  static const Color emberParticle = Color(0xFFFFB454);

  static const List<Color> enemyPalette = [
    Color(0xFFFF5D5D),
    Color(0xFF9B59F6),
    Color(0xFF00C2A8),
    Color(0xFFFF9F40),
  ];
  static const Color bossColor = Color(0xFF6C2BD9);
  static const Color bossAccent = Color(0xFFFFD54F);

  static const Color heartColor = Color(0xFFFF5C93);
  static const Color tripleShotColor = Color(0xFF4DD8FF);
  static const Color tripleShotGlow = Color(0xFF9CF2FF);

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

  // ---- Gameplay tuning ---------------------------------------------------
  static const double playerSize = 46;
  static const double playerSpeed = 300;
  static const double fireballSpeed = 560;

  static const double baseEnemySpeed = 95;
  static const double enemySpeedPerWave = 10;
  static const double baseSpawnInterval = 1.15;
  static const double minSpawnInterval = 0.38;

  static const int maxHealth = 100;
  static const int damagePerHit = 20;
  static const int enemiesPerWave = 10;

  static const int bossEveryNWaves = 5;
  static const int bossHitsToKill = 4;
  static const double bossSpeedMultiplier = 0.55;
  static const double bossSize = 1.9;

  static const double comboWindow = 1.4;
  static const double comboScoreStep = 0.12;
  static const int maxComboStacks = 8;

  static const double powerupDropChance = 0.16;
  static const double tripleShotDuration = 6.0;
  static const int heartHealAmount = 25;

  static const double crashShakeDuration = 0.35;
  static const double crashShakeMagnitude = 9;
}
