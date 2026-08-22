import 'package:flutter/material.dart';

abstract final class FootballPenaltyConfig {
  static const double refWidth = 360;
  static const double refHeight = 640;
  static const int totalShots = 5;

  // Premium arcade palette aligned with Racing, Fire, and Endless Runner.
  static const Color skyTop = Color(0xFF25103F);
  static const Color skyMid = Color(0xFF6D2451);
  static const Color skyBottom = Color(0xFFFF7A58);
  static const Color night = skyMid;
  static const Color sunGlow = Color(0xFFFFC15A);
  static const Color navy = Color(0xFF0B1220);
  static const Color navyDeep = Color(0xFF060A11);
  static const Color cream = Color(0xFFFFF6E9);
  static const Color gold = Color(0xFFFFC94A);
  static const Color coral = Color(0xFFFF6B4A);
  static const Color teal = Color(0xFF0EC9B0);
  static const Color violet = Color(0xFF9B59F6);
  static const Color lime = Color(0xFF3DDC97);
  static const Color cyan = Color(0xFF4DD8FF);
  static const Color pitchLight = Color(0xFF2BB57C);
  static const Color pitch = pitchLight;
  static const Color pitchDark = Color(0xFF126344);
  static const Color keeper = Color(0xFFFF9F40);
  static const Color keeperDark = Color(0xFFCF5522);

  static const double goalLeft = 0.14;
  static const double goalRight = 0.86;
  static const double goalTop = 0.25;
  static const double goalBottom = 0.52;
  static const double ballStartX = 0.5;
  static const double ballStartY = 0.86;
  static const double keeperY = 0.40;

  static const double maxAimOffset = 0.38;
  static const double minPower = 0.25;
  static const double maxPower = 1.0;
  static const double minShotPower = minPower;
  static const double maxShotPower = maxPower;
  static const double shotDuration = 0.78;
  static const double resultPause = 1.25;
  static const double postShotPause = resultPause;
  static const double keeperReaction = 0.22;
  static const double keeperDiveDuration = 0.52;
  static const double cameraShakeDuration = 0.28;
  static const double cameraShakeMagnitude = 5;

  static const int baseGoalPoints = 100;
  static const int cornerBonus = 75;
  static const int perfectBonus = 125;
  static const int streakBonus = 25;
}
