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

  // ---- Cartoon character palette --------------------------------------
  // Goalkeeper.
  static const Color keeperSkin = Color(0xFFE7A472);
  static const Color keeperHair = Color(0xFF171012);
  static const Color keeperJerseyDark = Color(0xFFCF5522);
  static const Color keeperShorts = Color(0xFF0B1220);
  static const Color keeperSocks = Color(0xFFFF9F40);
  static const Color keeperGloves = Color(0xFFFFE156);
  static const Color keeperBoots = Color(0xFF1A1A22);

  // Penalty taker ("striker").
  static const Color strikerSkin = Color(0xFFFFC49B);
  static const Color strikerHair = Color(0xFF2B1B12);
  static const Color strikerJersey = Color(0xFF3D6BFF);
  static const Color strikerJerseyDark = Color(0xFF2A4ACC);
  static const Color strikerShorts = Color(0xFFFFFFFF);
  static const Color strikerSocks = Color(0xFF3D6BFF);
  static const Color strikerBoots = Color(0xFF1A1A22);

  static const double goalLeft = 0.14;
  static const double goalRight = 0.86;
  static const double goalTop = 0.25;
  static const double goalBottom = 0.52;
  static const double ballStartX = 0.5;
  static const double ballStartY = 0.86;
  static const double keeperY = 0.40;

  // ---- Character scale & positioning -----------------------------------
  // The ball used to be a tiny 10px dot — bumped up and given real
  // spherical shading so it reads clearly on every device.
  static const double ballRadius = 17;

  // The penalty taker stands just behind the ball (foreground / closest
  // to the "camera") and runs up into that spot from further down-screen.
  static const double strikerBaseY = 0.965;
  static const double strikerRunStartY = 1.16;
  static const double strikerCycleDuration = 0.85;

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

  // Endless shootout progression: clear a round with enough goals and the
  // keeper comes back sharper next round.
  static const int advanceGoalsRequired = 3;
  static const double keeperReachPerRound = 0.010;
  static const double keeperReachMax = 0.20;
  static const double keeperDiveDurationMin = 0.30;
  static const double keeperDiveDurationPerRound = 0.018;

  // How often the keeper's idle "lean" tell actually predicts their dive.
  // Read it and shoot the other way — reliability drops as rounds climb.
  static const double keeperReadBase = 0.72;
  static const double keeperReadPerRound = 0.035;
  static const double keeperReadMin = 0.30;

  static const double nearMissBand = 0.055;
  static const double curveStrength = 0.6;
  static const double slowMoThreshold = 0.82;
  static const double slowMoScale = 0.30;
  static const double impactPunchDecay = 2.6;

  static String difficultyLabel(int round) {
    if (round <= 1) return 'AMATEUR';
    if (round == 2) return 'SEMI-PRO';
    if (round == 3) return 'PRO';
    if (round == 4) return 'ELITE';
    return 'WORLD CLASS';
  }
}