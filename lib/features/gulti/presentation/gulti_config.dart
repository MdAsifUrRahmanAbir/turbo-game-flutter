import 'package:flutter/material.dart';

/// Tunable values and palette for "Gulti Shoot" — a childhood-slingshot
/// bird game. Unlike [AngryBirdConfig] (which locks to a fixed reference
/// resolution because it needs identical physics in landscape across
/// devices), this game is portrait-only and positions everything as a
/// fraction of the device's actual logical size, the same approach
/// [FireGame] and [RacingGame] use — so no letterboxing/scaling step is
/// needed anywhere in [GultiGame].
abstract final class GultiConfig {
  // ---- Palette -------------------------------------------------------------
  static const Color skyTop = Color(0xFF6FC8FF);
  static const Color skyMid = Color(0xFFA8E2FF);
  static const Color skyBottom = Color(0xFFE8F7E0);
  static const Color sun = Color(0xFFFFE9A8);
  static const Color cloud = Color(0xFFFFFFFF);

  static const Color hillFar = Color(0xFF7FC98A);
  static const Color grassB = Color(0xFF63D477);
  static const Color groundBody = Color(0xFF8A5A34);
  static const Color groundTop = Color(0xFF6FA84A);

  static const Color treeTrunk = Color(0xFF7A4B2E);
  static const Color leafLight = Color(0xFF57B36C);
  static const Color leafDark = Color(0xFF2F8C4A);
  static const Color branch = Color(0xFF6B4226);

  static const Color woodFrame = Color(0xFF6B4226);
  static const Color band = Color(0xFF3A2415);
  static const Color pouch = Color(0xFF6B4226);
  static const Color stone = Color(0xFF9AA0A8);
  static const Color stoneDark = Color(0xFF6E747C);

  static const Color birdNormal = Color(0xFFE0703C);
  static const Color birdNormalDark = Color(0xFFB2532A);
  static const Color birdFast = Color(0xFF4D9CFF);
  static const Color birdFastDark = Color(0xFF2E6FCC);
  static const Color birdRare = Color(0xFFFFC94A);
  static const Color birdRareDark = Color(0xFFE0A400);

  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color gold = Color(0xFFFFC94A);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyDeep = Color(0xFF060A11);
  static const Color cream = Color(0xFFFFF6E9);

  static const List<Color> featherBurst = [
    Color(0xFFFFFFFF),
    Color(0xFFE0703C),
    Color(0xFFFFC94A),
  ];

  // ---- World layout ---------------------------------------------------------
  // Fraction of screen height where the ground line sits.
  static const double groundYFraction = 0.93;

  // ---- Gulti & stone physics ----------------------------------------------
  static const double gravity = 1450;
  static const double maxPullRadius = 115;
  static const double launchPowerMultiplier = 7.6;
  static const double stoneRadius = 9;
  static const double stoneRotationSpeed = 14;
  static const double airDrag = 0.999;

  // Fractional resting position of the gulti pouch (anchor).
  static const double anchorXFraction = 0.5;
  static const double anchorYFraction = 0.83;
  static const double restLift = 34;

  // ---- Bird tuning ---------------------------------------------------------
  static const double birdRadius = 15;
  static const double normalBirdSpeed = 42;
  static const double fastBirdSpeed = 78;
  static const double rareBirdSpeed = 98;

  static const double flapCycleSpeed = 9;
  static const double idleBobSpeed = 2.4;
  static const double takeOffDuration = 0.45;
  static const double hitReactionDuration = 0.5;

  /// How close a stone needs to pass a sitting bird — without directly
  /// hitting it — to startle it into the air.
  static const double startleRadius = 46;

  static const int scoreNormal = 100;
  static const int scoreFast = 150;
  static const int scoreRare = 250;

  // ---- Combo & bonuses -------------------------------------------------------
  static const int comboBonusPerHit = 40;
  static const int stoneSavedBonus = 60;
  static const int timeBonusPerSecond = 8;

  static const double crashShakeDuration = 0.18;
  static const double crashShakeMagnitude = 6;
}
