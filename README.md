# PlayBits — Flutter Game Collection

A single Flutter project containing two playable 2D games:

1. **2D Racing** — the original Turbo Track Racing game.
2. **2D Endless Runner** — lane switching, jumping, ducking, obstacles, coins, particles, score, distance, pause/resume and game-over flow.

## Stack

- Flutter >= 3.44
- Dart >= 3.11
- Flame ^1.38.0
- flutter_riverpod ^3.4.2

Flame 1.38.0 is the current stable release used by this project and requires Dart 3.11+. Riverpod 3.4.2 is used for application/game UI state.

## Architecture

```text
lib/
├── core/
│   └── theme/
├── features/
│   ├── home/
│   │   └── presentation/
│   │       └── game_hub_screen.dart
│   ├── racing/
│   │   └── presentation/
│   └── endless_runner/
│       ├── data/
│       │   └── models/
│       └── presentation/
│           ├── controllers/
│           ├── game/
│           ├── screens/
│           └── widgets/
└── main.dart
```

The game engine owns frame-by-frame gameplay. Riverpod owns screen/UI state such as menu, playing, paused and game over.

## Endless Runner controls

- Left arrow: move one lane left
- Right arrow: move one lane right
- Up button: jump
- Down button: duck
- Pause button: pause

The game is asset-free: the road, player, obstacles, coins, scenery and particles are drawn with Canvas so the project runs immediately without downloading image packs.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Build APK

```bash
flutter build apk --release
```

## Notes

The Endless Runner is intentionally self-contained under `features/endless_runner`, so it can be expanded later with sprite sheets, audio, power-ups, missions, persistence, authentication and a backend leaderboard without mixing game logic into the app shell.
