import 'package:flutter/material.dart';

/// Tunable values and palette for "Physics Smash" (Angry-Birds-style
/// slingshot game). The whole scene simulates in a fixed reference
/// resolution ([refWidth] x [refHeight]); [AngryBirdGame] letterboxes /
/// scales that world to fit the real device screen so physics behaves
/// identically on every device and aspect ratio.
abstract final class AngryBirdConfig {
  // ---- Reference world -----------------------------------------------
  static const double refWidth = 800;
  static const double refHeight = 450;
  static const double groundHeight = 46;
  static double get groundY => refHeight - groundHeight;
  // How far above the ground the sling's pouch rests. Raised from the
  // original 60 so there's genuine room to pull the bird back and down
  // without the pull immediately running into the ground.
  static const double slingLift = 90;

  // ---- Palette ----------------------------------------------------------
  static const Color skyTop = Color(0xFF6FC8FF);
  static const Color skyBottom = Color(0xFFCFEFFF);
  static const Color hillFar = Color(0xFF6FBF8A);
  static const Color hillNear = Color(0xFF4FA972);
  static const Color groundTop = Color(0xFF7CC66B);
  static const Color groundBody = Color(0xFF8A5A34);
  static const Color slingWood = Color(0xFF6B4226);
  static const Color slingWoodDark = Color(0xFF48291A);
  static const Color band = Color(0xFF4A2E1B);

  static const Color birdRed = Color(0xFFEB4B3D);
  static const Color birdRedDark = Color(0xFFB8301F);
  static const Color birdYellow = Color(0xFFFFD23D);
  static const Color birdYellowDark = Color(0xFFE0A400);
  static const Color birdBlack = Color(0xFF3A3A3A);
  static const Color birdBlackDark = Color(0xFF1A1A1A);

  static const Color explosionCore = Color(0xFFFFF3C4);
  static const Color explosionMid = Color(0xFFFFC94A);
  static const Color explosionOuter = Color(0xFFFF6B4A);

  static const Color pigGreen = Color(0xFF8FD14F);
  static const Color pigGreenDark = Color(0xFF5FA22E);

  static const Color woodBlock = Color(0xFFC98A4B);
  static const Color woodBlockDark = Color(0xFF8F5F2E);
  static const Color stoneBlock = Color(0xFFAEB4BB);
  static const Color stoneBlockDark = Color(0xFF767C84);

  static const Color trajectoryDot = Color(0xCCFFFFFF);
  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color gold = Color(0xFFFFC94A);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyDeep = Color(0xFF060A11);

  // ---- Physics tuning -----------------------------------------------------
  static const double gravity = 620;
  static const double airDrag = 0.999;
  static const double groundRestitution = 0.32;
  static const double blockRestitution = 0.18;
  static const double groundFriction = 0.86;

  static const double birdRadius = 14;
  static const double pigRadius = 14;

  static const double maxDragRadius = 150;
  // Hit-test radius for picking up the bird — kept noticeably larger than
  // maxDragRadius so grabbing feels forgiving on touch screens.
  static const double grabRadius = 180;
  static const double launchPower = 6.2;
  static const double yellowBoostMultiplier = 1.8;

  static const double killImpactSpeed = 250;
  static const double blockDamageImpactSpeed = 230;
  static const double blockHealthWood = 40;
  static const double blockHealthStone = 110;

  static const double restSpeedThreshold = 6;

  // ---- Bomb bird (black) ---------------------------------------------
  // How far the shockwave reaches and how hard it shoves blocks/pigs.
  static const double bombExplosionRadius = 95;
  static const double bombExplosionForce = 900;

  // ---- Combo scoring ---------------------------------------------------
  // Extra points per additional pig killed by the same bird's flight.
  static const int pigBaseScore = 500;
  static const int comboBonusPerKill = 250;

  static const List<Color> confetti = [
    Color(0xFFFF6B4A),
    Color(0xFFFFC94A),
    Color(0xFF0EC9B0),
    Color(0xFF4D7CFF),
    Color(0xFFFF5C93),
  ];
}