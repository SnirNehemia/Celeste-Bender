# Windbound

A Celeste-style precision platformer where the hero is an air-bender, built in **Godot 4.4 (GDScript)**.
Current goal: **Milestone 1 — Air vertical slice** (5 rooms, placeholder shapes).

- Design: [`GAME_DESIGN.md`](GAME_DESIGN.md)
- Build plan and progress: [`PROMPTS.md`](PROMPTS.md)
- Coding rules: [`CLAUDE.md`](CLAUDE.md)

## Status

| Stage | What | State |
|---|---|---|
| 0 | Project skeleton: 320×180 pixel-perfect, InputMap, folder layout | done |
| 1 | Player basics: run, gravity, jump, state machine | done |
| 2 | Celeste feel: variable jump, apex half-gravity, coyote time, jump buffer, fast-fall, wall slide/jump, corner correction, F1 debug overlay | done |
| 3 | Rooms, camera, death | next |
| 4–10 | Air Dash, Glide, Gust, puzzle objects, enemies, 5 rooms, polish | to do |

The main scene is currently the movement test room (`tests/test_room_player.tscn`): a wall-jump shaft on the left, a corner-correction slab in the middle, and jump-practice platforms on the right.

## Running

Open the folder in the Godot 4.4 Project Manager (**Import**) and press F5, or from a terminal:

```
godot --path .
```

## Controls (keyboard)

| Action | Key |
|---|---|
| Move / aim | Arrow keys (WASD) |
| Jump (hold = higher) | C (Space) |
| Fast-fall | Hold ↓ while falling |
| Air Dash | X *(Stage 4)* |
| Gust | Z *(Stage 6)* |
| Restart room | R *(Stage 3)* |
| Pause | Esc *(Stage 10)* |
| Debug overlay | F1 |

## Tuning movement

Every feel value lives in `resources/player_tuning.tres` (a `PlayerTuning` resource). Tweak it live while the game runs: Scene dock → **Remote** → Player → `tuning`. Then copy the values you like into the `.tres`.

Values changed from the design doc after play-testing: max fall speed **300** (was 160) and fast-fall max **500** (was 240).

## Layout

```
autoload/      global singletons (Stage 3+)
resources/     player_tuning.gd/.tres
scenes/
  player/      player.tscn/.gd, state_machine.gd, states/ (Idle, Run, Jump, Fall, WallSlide)
  ui/          debug_overlay
  objects/ enemies/ rooms/   (later stages)
tests/         isolated test rooms
```
