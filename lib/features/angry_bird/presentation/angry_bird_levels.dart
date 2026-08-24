import 'angry_bird_config.dart';

enum BlockMaterial { wood, stone }

enum BirdKind { red, yellow, black }

class BlockDef {
  const BlockDef(this.x, this.y, this.w, this.h, this.material);
  final double x;
  final double y;
  final double w;
  final double h;
  final BlockMaterial material;
}

class PigDef {
  const PigDef(this.x, this.y, {this.radius = AngryBirdConfig.pigRadius});
  final double x;
  final double y;
  final double radius;
}

class AngryBirdLevel {
  const AngryBirdLevel({
    required this.name,
    required this.birds,
    required this.blocks,
    required this.pigs,
    required this.twoStarScore,
    required this.threeStarScore,
  });

  final String name;
  final List<BirdKind> birds;
  final List<BlockDef> blocks;
  final List<PigDef> pigs;
  final int twoStarScore;
  final int threeStarScore;
}

double get _g => AngryBirdConfig.groundY;

/// Static, hand-tuned level set. New levels can be appended freely — the
/// controller and game read this list's length directly, so no other file
/// needs to change to add level 4, 5, etc.
final List<AngryBirdLevel> angryBirdLevels = [
  AngryBirdLevel(
    name: 'Wooden Nest',
    birds: const [BirdKind.red, BirdKind.red, BirdKind.yellow],
    blocks: [
      BlockDef(560, _g - 20, 18, 40, BlockMaterial.wood),
      BlockDef(640, _g - 20, 18, 40, BlockMaterial.wood),
      BlockDef(600, _g - 46, 96, 14, BlockMaterial.wood),
    ],
    pigs: [PigDef(600, _g - 60)],
    twoStarScore: 4000,
    threeStarScore: 7000,
  ),
  AngryBirdLevel(
    name: 'Stone Tower',
    birds: const [BirdKind.red, BirdKind.red, BirdKind.yellow, BirdKind.red],
    blocks: [
      BlockDef(560, _g - 20, 18, 40, BlockMaterial.stone),
      BlockDef(560, _g - 60, 18, 40, BlockMaterial.wood),
      BlockDef(680, _g - 20, 18, 40, BlockMaterial.stone),
      BlockDef(680, _g - 60, 18, 40, BlockMaterial.wood),
      BlockDef(620, _g - 92, 150, 14, BlockMaterial.wood),
    ],
    pigs: [PigDef(560, _g - 34), PigDef(680, _g - 34)],
    twoStarScore: 6000,
    threeStarScore: 10000,
  ),
  AngryBirdLevel(
    name: 'Double Fortress',
    birds: const [
      BirdKind.red,
      BirdKind.yellow,
      BirdKind.red,
      BirdKind.yellow,
      BirdKind.red,
    ],
    blocks: [
      BlockDef(520, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(520, _g - 60, 16, 40, BlockMaterial.wood),
      BlockDef(580, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(580, _g - 60, 16, 40, BlockMaterial.wood),
      BlockDef(550, _g - 92, 90, 14, BlockMaterial.wood),
      BlockDef(700, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(700, _g - 60, 16, 40, BlockMaterial.wood),
      BlockDef(760, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(760, _g - 60, 16, 40, BlockMaterial.wood),
      BlockDef(730, _g - 92, 90, 14, BlockMaterial.wood),
    ],
    pigs: [
      PigDef(550, _g - 106),
      PigDef(730, _g - 106),
      PigDef(640, _g - 20),
    ],
    twoStarScore: 8500,
    threeStarScore: 14000,
  ),
  AngryBirdLevel(
    name: 'Bomb Bay',
    // A sealed stone box needs the bomb bird's shockwave to crack open —
    // chipping away at it with a red bird alone is far too slow.
    birds: const [BirdKind.black, BirdKind.red, BirdKind.yellow, BirdKind.red],
    blocks: [
      BlockDef(560, _g - 30, 18, 80, BlockMaterial.stone),
      BlockDef(640, _g - 30, 18, 80, BlockMaterial.stone),
      BlockDef(600, _g - 78, 100, 16, BlockMaterial.stone),
      BlockDef(760, _g - 20, 16, 40, BlockMaterial.wood),
      BlockDef(760, _g - 60, 16, 40, BlockMaterial.wood),
    ],
    pigs: [PigDef(600, _g - 50), PigDef(760, _g - 80)],
    twoStarScore: 9500,
    threeStarScore: 15500,
  ),
  AngryBirdLevel(
    name: 'Grand Fortress',
    birds: const [
      BirdKind.red,
      BirdKind.black,
      BirdKind.yellow,
      BirdKind.red,
      BirdKind.black,
      BirdKind.yellow,
    ],
    blocks: [
      BlockDef(480, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(480, _g - 60, 16, 40, BlockMaterial.wood),
      BlockDef(540, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(540, _g - 60, 16, 40, BlockMaterial.wood),
      BlockDef(510, _g - 92, 90, 14, BlockMaterial.wood),
      BlockDef(620, _g - 45, 16, 90, BlockMaterial.stone),
      BlockDef(680, _g - 45, 16, 90, BlockMaterial.stone),
      BlockDef(650, _g - 96, 96, 16, BlockMaterial.stone),
      BlockDef(760, _g - 20, 16, 40, BlockMaterial.stone),
      BlockDef(760, _g - 60, 16, 40, BlockMaterial.wood),
    ],
    pigs: [
      PigDef(510, _g - 106),
      PigDef(650, _g - 114),
      PigDef(760, _g - 80),
      PigDef(600, _g - 20),
    ],
    twoStarScore: 12500,
    threeStarScore: 20000,
  ),
];