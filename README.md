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
| 3 | Rooms, room-locked camera with slide transitions, spikes, pits, death/respawn, R restart, GameState autoload | done |
| 4 | Air Dash | next |
| 5–10 | Glide, Gust, puzzle objects, enemies, 5 rooms, polish | to do |

The main scene is currently a three-room test world (`tests/test_world.tscn`): a wide scrolling room with spikes and a wall-jump shaft, a room above it, and a bottomless-pit room. The Stage 2 movement test room is still in `tests/test_room_player.tscn`.

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
| Restart room (counts as a death) | R |
| Pause | Esc *(Stage 10)* |
| Debug overlay | F1 |

## Tuning movement

Every feel value lives in `resources/player_tuning.tres` (a `PlayerTuning` resource). Tweak it live while the game runs: Scene dock → **Remote** → Player → `tuning`. Then copy the values you like into the `.tres`.

Values changed from the design doc after play-testing: max fall speed **300** (was 160) and fast-fall max **500** (was 240).

## Layout

```
autoload/      game_state.gd (deaths, time, current room)
resources/     player_tuning.gd/.tres
scenes/
  player/      player.tscn/.gd, state_machine.gd, states/ (Idle, Run, Jump, Fall, WallSlide, Dead)
  rooms/       room_base.gd, room_camera.gd, room_manager.gd
  objects/     spikes
  ui/          debug_overlay
tests/         test_world.tscn + rooms/, test_room_player.tscn
```
