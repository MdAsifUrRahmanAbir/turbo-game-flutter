enum BirdKind { normal, fast, rare }

enum BirdPerch { sitting, flying }

class BirdSpawnDef {
  const BirdSpawnDef({
    required this.kind,
    required this.perch,
    required this.x,
    required this.y,
    this.boundLeft,
    this.boundRight,
    this.boundTop,
    this.boundBottom,
  });

  /// Species — controls color, score value and base speed.
  final BirdKind kind;

  /// Whether the bird starts sitting on a branch or already flying.
  final BirdPerch perch;

  /// Fractional (0..1) starting position on screen.
  final double x;
  final double y;

  /// Fractional roaming bounds for flying birds. Ignored for sitting birds
  /// — their perch anchors the small hop/idle movement instead.
  final double? boundLeft;
  final double? boundRight;
  final double? boundTop;
  final double? boundBottom;
}

class GultiLevel {
  const GultiLevel({
    required this.name,
    required this.birds,
    required this.stoneCount,
    required this.speedScale,
    required this.twoStarScore,
    required this.threeStarScore,
    this.timeLimit,
  });

  final String name;
  final List<BirdSpawnDef> birds;
  final int stoneCount;

  /// Multiplies every bird's base movement speed — the main knob used to
  /// ramp difficulty level over level.
  final double speedScale;

  /// Seconds available, or null for an untimed level.
  final double? timeLimit;

  final int twoStarScore;
  final int threeStarScore;
}

/// Static, hand-tuned level set. New levels can be appended freely — the
/// hub badge and level-select grid both read this list's length directly.
final List<GultiLevel> gultiLevels = [
  GultiLevel(
    name: 'First Aim',
    birds: const [
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.24, y: 0.46),
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.50, y: 0.40),
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.76, y: 0.47),
    ],
    stoneCount: 6,
    speedScale: 1.0,
    twoStarScore: 250,
    threeStarScore: 320,
  ),
  GultiLevel(
    name: 'First Flight',
    birds: const [
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.22, y: 0.44),
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.78, y: 0.42),
      BirdSpawnDef(
        kind: BirdKind.normal,
        perch: BirdPerch.flying,
        x: 0.35,
        y: 0.20,
        boundLeft: 0.12,
        boundRight: 0.55,
        boundTop: 0.12,
        boundBottom: 0.30,
      ),
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.65,
        y: 0.22,
        boundLeft: 0.45,
        boundRight: 0.90,
        boundTop: 0.14,
        boundBottom: 0.32,
      ),
    ],
    stoneCount: 8,
    speedScale: 1.1,
    twoStarScore: 400,
    threeStarScore: 520,
  ),
  GultiLevel(
    name: 'Busy Branches',
    birds: const [
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.20, y: 0.45),
      BirdSpawnDef(kind: BirdKind.fast, perch: BirdPerch.sitting, x: 0.50, y: 0.38),
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.80, y: 0.46),
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.30,
        y: 0.18,
        boundLeft: 0.10,
        boundRight: 0.60,
        boundTop: 0.10,
        boundBottom: 0.28,
      ),
      BirdSpawnDef(
        kind: BirdKind.rare,
        perch: BirdPerch.flying,
        x: 0.70,
        y: 0.20,
        boundLeft: 0.40,
        boundRight: 0.92,
        boundTop: 0.12,
        boundBottom: 0.30,
      ),
    ],
    stoneCount: 9,
    speedScale: 1.25,
    twoStarScore: 550,
    threeStarScore: 720,
  ),
  GultiLevel(
    name: 'Restless Flock',
    birds: const [
      BirdSpawnDef(kind: BirdKind.fast, perch: BirdPerch.sitting, x: 0.18, y: 0.44),
      BirdSpawnDef(kind: BirdKind.normal, perch: BirdPerch.sitting, x: 0.42, y: 0.36),
      BirdSpawnDef(kind: BirdKind.rare, perch: BirdPerch.sitting, x: 0.82, y: 0.45),
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.25,
        y: 0.18,
        boundLeft: 0.08,
        boundRight: 0.55,
        boundTop: 0.10,
        boundBottom: 0.30,
      ),
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.60,
        y: 0.22,
        boundLeft: 0.35,
        boundRight: 0.80,
        boundTop: 0.12,
        boundBottom: 0.32,
      ),
      BirdSpawnDef(
        kind: BirdKind.rare,
        perch: BirdPerch.flying,
        x: 0.85,
        y: 0.16,
        boundLeft: 0.60,
        boundRight: 0.95,
        boundTop: 0.10,
        boundBottom: 0.28,
      ),
    ],
    stoneCount: 9,
    speedScale: 1.45,
    twoStarScore: 700,
    threeStarScore: 950,
    timeLimit: 55,
  ),
  GultiLevel(
    name: 'Sky Chase',
    birds: const [
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.20,
        y: 0.18,
        boundLeft: 0.05,
        boundRight: 0.45,
        boundTop: 0.10,
        boundBottom: 0.34,
      ),
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.50,
        y: 0.15,
        boundLeft: 0.30,
        boundRight: 0.70,
        boundTop: 0.08,
        boundBottom: 0.30,
      ),
      BirdSpawnDef(
        kind: BirdKind.fast,
        perch: BirdPerch.flying,
        x: 0.80,
        y: 0.20,
        boundLeft: 0.55,
        boundRight: 0.95,
        boundTop: 0.10,
        boundBottom: 0.34,
      ),
      BirdSpawnDef(
        kind: BirdKind.rare,
        perch: BirdPerch.flying,
        x: 0.35,
        y: 0.24,
        boundLeft: 0.15,
        boundRight: 0.60,
        boundTop: 0.14,
        boundBottom: 0.38,
      ),
      BirdSpawnDef(
        kind: BirdKind.rare,
        perch: BirdPerch.flying,
        x: 0.65,
        y: 0.26,
        boundLeft: 0.40,
        boundRight: 0.90,
        boundTop: 0.14,
        boundBottom: 0.38,
      ),
    ],
    stoneCount: 8,
    speedScale: 1.7,
    twoStarScore: 850,
    threeStarScore: 1150,
    timeLimit: 50,
  ),
];
