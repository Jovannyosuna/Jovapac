# JOVA-LAND

Arcade maze game built with Flutter + Flame. Eat every pellet, grab a burger
to turn the tables on the ghosts, and clear 6 levels across 3 mazes.

## Run

```sh
flutter pub get
flutter run -d chrome          # or any connected device
flutter run -d web-server --web-port 8765 --release
```

Controls: arrows / WASD to move, Esc or P to pause, M to toggle sound.
On touch devices: swipe or use the on-screen D-pad.

## Checks

```sh
flutter analyze
flutter test                              # rules, AI, movement, full session
flutter test tool/screenshots_test.dart   # renders key screens at 4 viewports into build/screenshots/
dart run tool/generate_audio.dart         # regenerates the chiptune SFX/music in assets/audio/
```

## Layout

| Path | Contents |
| --- | --- |
| `lib/app/` | App shell, theme (palette, fonts), `AppScope` for save data and audio |
| `lib/services/` | `AudioService` (flame_audio pools + music), `SaveData` (high score, mute) |
| `lib/game/core/` | Grid primitives (`Dir`, `Cell`) and tile units |
| `lib/game/maze/` | Maze layouts, parsing/validation, BFS paths, pre-rendered neon maze |
| `lib/game/ai/` | Ghost personalities, scatter/chase schedule, targeting |
| `lib/game/entities/` | Player, ghosts, pellets, bonus coin, shared `GridMover` |
| `lib/game/effects/` | Pooled particles, score popups, ambient motes, flashes |
| `lib/game/jova_game.dart` | Phase state machine and the deterministic simulation step |
| `lib/game/levels.dart` | Campaign difficulty curve |
| `lib/ui/` | HUD, menus, overlays and touch controls (Flutter widgets) |

The simulation runs only inside `JovaGame._simulate`; entities just render
themselves. Gameplay state the UI needs is exposed through `GameSession`
`ValueNotifier`s, so the HUD never rebuilds the game.
