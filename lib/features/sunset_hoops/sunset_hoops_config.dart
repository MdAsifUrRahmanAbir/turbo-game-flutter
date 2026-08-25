import 'package:flutter/material.dart';

/// Tunable values and the "Sunset Hoops" palette shared by the basketball
/// game's engine, HUD and menus.
abstract final class SunsetHoopsConfig {
  // ---- Palette -----------------------------------------------------------
  static const Color skyTop = Color(0xFFFF7A50);
  static const Color skyMid = Color(0xFFFF9B6A);
  static const Color skyBottom = Color(0xFFFFD98A);
  static const Color sunGlow = Color(0xFFFFE9A8);

  static const Color courtLight = Color(0xFFE0954A);
  static const Color courtDark = Color(0xFFC96A2E);
  static const Color courtLine = Color(0xFFFFF6E9);

  static const Color backboard = Color(0xFFF3FFFC);
  static const Color backboardShade = Color(0xFFD9E7E4);
  static const Color rimColor = Color(0xFFFF3D3D);
  static const Color netColor = Color(0xFFFFFFFF);

  static const Color ballBody = Color(0xFFFF7A3D);
  static const Color ballLine = Color(0xFF2B1400);

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

  // ---- Ball / shooting spot ------------------------------------------------
  static const double ballRadius = 20;
  static const double shooterX = 0.5;
  static const double shooterY = 0.86;

  /// Max pixels the drag can register as full power.
  static const double maxDragDistance = 220;

  /// Multiplies the drag vector into a launch velocity (px/s-ish).
  static const double launchPowerMultiplier = 7.2;

  /// A flick shorter than this is treated as a cancelled shot.
  static const double minDragDistance = 18;

  static const double gravity = 900;
  static const double airDrag = 0.999;
  static const double ballRotationDrag = 6.0;

  // ---- Hoop ----------------------------------------------------------------
  static const double rimWidth = 86;
  static const double rimThickness = 10;
  static const double backboardWidth = 130;
  static const double backboardHeight = 84;

  static const double hoopXMin = 0.22;
  static const double hoopXMax = 0.78;
  static const double hoopYMin = 0.18;
  static const double hoopYMax = 0.34;

  // ---- Gameplay tuning -------------------------------------------------------
  static const int maxMisses = 3;
  static const int baseScore = 100;
  static const int streakBonusStep = 20;
  static const int backboardBankBonus = 40;

  static const double crashShakeDuration = 0.22;
  static const double crashShakeMagnitude = 6;

  static const double netSwingDecay = 4.5;

  static String difficultyLabel(int makes) {
    if (makes < 5) return 'ROOKIE';
    if (makes < 12) return 'STARTER';
    if (makes < 22) return 'ALL-STAR';
    return 'LEGEND';
  }

  // ---- Collision tuning ------------------------------------------------
  /// Radius of each rim "post" collider (left end + right end of the rim).
  /// The center opening between them is intentionally left with no
  /// collider at all so the ball can pass straight through.
  static const double rimPostRadius = 7;

  static const double rimRestitution = 0.65;
  static const double backboardRestitution = 0.75;
  static const double groundRestitution = 0.55;
  static const double groundFriction = 0.82;

  /// Fraction of screen height the court surface sits at.
  static const double groundYFraction = 0.94;

  /// Combined speed (px/s) below which a settled ball is considered done.
  static const double stopThreshold = 55;

  /// Small push-out applied after every collision so the ball never stays
  /// exactly touching (and therefore re-colliding with) a collider.
  static const double collisionEpsilon = 0.5;

  /// Pause between a shot resolving (make or miss) and the next ball
  /// appearing at the shooter spot.
  static const double resetDelay = 0.35;
}