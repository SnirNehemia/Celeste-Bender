# CLAUDE.md — Windbound (Godot 4 platformer)

Instructions for Claude Code working on this project. Read this and `GAME_DESIGN.md` at the start of every session.

## Project in one line
A Celeste-style precision platformer where the hero is an air-bender. Current goal: **Milestone 1 — Air vertical slice** (5 rooms, placeholder shapes). Full spec in `GAME_DESIGN.md`.

## About the developer
- Experienced in Python/PyTorch and ML, **new to Godot and GDScript**.
- Wants to *understand* the code, not just run it. After each change, explain what you did and why in 3–6 short bullets, and name any Godot concept involved (signals, nodes/scenes, `_physics_process`, autoloads, resources, InputMap…) in one sentence each the first time it appears.
- Plays with keyboard only.

## Tech
- **Godot 4.x, GDScript** (standard build, not .NET). Check the version with `godot --version` before relying on version-specific APIs.
- 2D, internal resolution 320×180, integer scaling, `texture_filter = nearest`.
- Physics: `CharacterBody2D` for the player and enemies; custom movement code, not RigidBody, for anything that needs to feel precise.

## Code style (important)
- **Heavily commented.** Every script starts with a header comment saying what it is and how it connects to other nodes. Comment the *why* of every non-obvious line, especially movement math.
- **Explicit names**: `max_run_speed`, `coyote_time_remaining`, not `spd`, `ct`.
- **Static typing everywhere**: `var dash_speed: float = 240.0`, typed function args and returns.
- **Modular**: one responsibility per script. Abilities are separate component nodes (`AirDashAbility`, `GlideAbility`, `GustAbility`) attached under the player, so new elements can be added later without rewriting the player.
- Constants that affect feel go in **`PlayerTuning` (a custom `Resource`)** with `@export` vars, never as magic numbers in code.
- Prefer **signals** for communication between objects (switch → door, player died → room manager). Avoid `get_node("../../..")` chains.

## Folder layout
```
res://
  project.godot
  scenes/
    player/        player.tscn, player.gd, states/, abilities/
    objects/       crate, spikes, wind_zone, wind_crystal, windmill, leaf_platform, door, pressure_plate
    enemies/       wisp, sentry, sentry_orb
    rooms/         room_01.tscn … room_05.tscn, room_base.gd
    ui/            hud, pause, end_screen
  resources/       player_tuning.tres
  autoload/        game_state.gd (deaths, timer, current checkpoint), fx.gd (screen shake, freeze frames)
  tests/           simple test scenes for isolated mechanics
```

## Input
Define all actions in **Project Settings → InputMap** (edit `project.godot`): `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `dash`, `gust`, `restart_room`, `pause`. Bindings per `GAME_DESIGN.md` §3. Code reads only action names, never raw keys.

## Working rules
1. **Small steps.** One mechanic per task. Don't build ahead of the current stage in `PROMPTS.md`.
2. **Verify before saying done.** After editing, check for script errors (see "Running and checking" below). Never report success with errors in the output.
3. **Tell me how to test.** End each task with a short checklist: what to press and what I should see.
4. **Scenes (.tscn):** keep them simple. It's fine to write `.tscn` files directly, but prefer building small node trees in code (`_ready`) when that's clearer. Don't hand-edit resource UIDs; don't delete `.uid` / `.import` files — Godot manages them.
5. **Placeholder art only** (`ColorRect`, `Polygon2D`, `Line2D`, `CPUParticles2D`) using the color key in `GAME_DESIGN.md` §2.
6. **Git:** after each stage that works, suggest a commit message (don't commit unless I say so).
7. If something in the design doc seems wrong or won't feel good, say so and propose an alternative before building it.

## Running and checking
- If the Godot MCP server is available, use it to run the project and read the debug output after changes.
- Godot is not on PATH on this machine. Use the console build (prints to the terminal):
  `D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe` (v4.4.1). In the commands below, `godot` means this path.
- Node.js LTS is installed and the `godot` MCP server (`@coding-solo/godot-mcp`) is registered for this project (local scope); it needs a Claude Code restart to load its tools.
- Otherwise, from the project folder:
  - `godot --headless --path . --import` — imports assets and surfaces parse errors in scripts
  - `godot --headless --check-only --script res://path/to/file.gd` — checks one script
  - `godot --path .` — runs the game (I'll play-test and report back)
- Use `print()` with a clear prefix (e.g. `[Dash]`) for temporary debugging, and remove it once the feature works.

## Definition of done for Milestone 1
See `GAME_DESIGN.md` §12.
