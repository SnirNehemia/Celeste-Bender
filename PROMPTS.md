# Build plan — prompts for Claude Code

You don't paste these. Claude Code reads this file itself. Run one stage per session with:

```
/stage 3
```

(or just type "Do Stage 3 from PROMPTS.md"). Don't move on until the stage feels right in play — especially Stage 2.

## Progress
<!-- Claude Code updates this list when a stage is finished and you've confirmed it works -->
- [x] Stage 0 · [x] 1 · [x] 2 · [x] 3 · [x] 4 · [x] 5 · [ ] 6 · [ ] 7 · [ ] 8 · [ ] 9 · [ ] 10

---

## Setup (once, by hand)

1. Create an empty folder, e.g. `windbound/`, and put `CLAUDE.md`, `GAME_DESIGN.md`, `PROMPTS.md` in it, plus `stage.md` in `.claude/commands/` (so the path is `windbound/.claude/commands/stage.md`).
2. Open a terminal in the folder and run `claude`.
3. Type `/stage 0`. Claude Code handles the rest of the setup, including the Godot MCP.

---

## Stage 0 — Tools check and project skeleton
> **Part A — tools (do this first, ask before installing anything):**
> 1. Check Godot is reachable: run `godot --version`. If that fails, look in the usual install locations for this OS, then ask me for the path. Record the working path/command in CLAUDE.md under "Running and checking".
> 2. Check for a Godot MCP server: run `claude mcp list`. If any server named godot (or using `godot-mcp`) is listed and connected, use it and skip to step 4.
> 3. If not: check Node.js with `node --version` (needs a recent LTS). If Node is missing, tell me how to install it and stop. Otherwise, ask me, then install it for this project:
>    `claude mcp add godot -e GODOT_PATH=<godot path from step 1> -- npx @coding-solo/godot-mcp`
>    Then tell me to restart Claude Code (exit and run `claude` again) so the new tools load, and to run `/stage 0` again — Part A will then pass straight through.
> 4. Run `git init` if this folder isn't a git repo yet, with a Godot `.gitignore` (ignore `.godot/`).
>
> **Part B — skeleton:** Read CLAUDE.md and GAME_DESIGN.md. Create the Godot 4 project for this game: project.godot with 320×180 internal resolution, integer scaling, nearest filtering, window 1280×720, the full InputMap from the design doc, the folder layout from CLAUDE.md, and an empty main scene with a gray floor. Explain the basic Godot concepts I need (nodes, scenes, scripts, the main scene) briefly. Then tell me how to open it in the Godot editor and run it.

**You should see:** a window with a gray floor. Open the folder in Godot's Project Manager with "Import".

## Stage 1 — Player basics
> Create the player as a CharacterBody2D (white 8×11 rectangle) with a PlayerTuning resource holding all movement values from GAME_DESIGN.md §4. Implement only: run with acceleration/deceleration, gravity, max fall speed, and a basic jump. Use a simple state machine (Idle, Run, Jump, Fall) as separate state scripts. Add a test room with a few platforms. Explain how _physics_process and move_and_slide work.

## Stage 2 — Celeste feel (spend time here)
> Add variable jump height, apex half-gravity, coyote time, jump buffering, fast-fall, wall slide, wall jump with input lock, and ceiling corner correction. Add a small on-screen debug label showing current state and velocity (toggle with F1). Make sure every PlayerTuning value can be changed in the Inspector while the game runs.

**Test:** Does jumping feel responsive? Tweak values live in the Remote tab of the Scene dock while the game runs; tell Claude which values you settled on.

## Stage 3 — Rooms, camera, death
> Add a room system: each room is a scene with bounds, a spawn point and exits. Camera locked to the current room with a short slide transition. Add spikes (instant death), a 0.4 s death effect, instant respawn at the room spawn, R to restart room, and a GameState autoload counting deaths and time.

## Stage 4 — Air Dash
> Implement AirDashAbility as a separate component under the player, per GAME_DESIGN.md §5.1: 8-direction dash, one charge refilled on ground, player turns pale blue when out of dashes, freeze frames, screen shake, afterimage trail. Add the FX autoload for shake and freeze frames. Add wind crystals that refill the dash and respawn.

## Stage 5 — Glide and wind zones
> Implement GlideAbility (§5.2) with stamina and a small stamina bar, plus wind zones (horizontal currents and updrafts) that apply a force to the player. Gliding inside an updraft lifts the player.

## Stage 6 — Gust
> Implement GustAbility (§5.3): cone in the aimed direction, cooldown, recoil on the player, once-per-airtime down-gust boost. Create a "Pushable" interface/group so any object can react to a gust. Visualize the cone with particles. Add a debug toggle to draw the gust hitbox.

## Stage 7 — Puzzle objects
> Add crates, pressure plates, doors, windmills and leaf platforms (§6). Switches emit signals; doors are linked to switches via exported NodePaths I can set in the editor. Build a small test room using all of them.

## Stage 8 — Enemies
> Add the Wisp and the Sentry with its orb (§7). Gust stuns/knocks back enemies and reflects orbs. Knocking a wisp into spikes or dashing into a stunned wisp defeats it. Reflected orbs destroy sentries.

## Stage 9 — The 5 rooms
> Build rooms 1–5 as described in GAME_DESIGN.md §8, connected in order, using a TileMapLayer with an 8×8 placeholder tileset. Then add an end screen with deaths and time. Explain how to edit the rooms myself in the Godot editor.

**Test:** Play all 5 rooms. Note every spot that feels unfair or confusing and give Claude the list.

## Stage 10 — Polish pass
> Go through GAME_DESIGN.md §9 and add anything missing: squash and stretch, dust particles, land/jump/wall-jump effects, death burst. Add pause (Esc) and a play_sfx() hook that does nothing yet. Check the project for errors, remove leftover debug prints, and list anything from §12 that's still not met.

---

## Tips for vibe coding with Claude Code
- **Describe feel, not code:** "the jump feels floaty at the top" or "the dash stops too abruptly" works better than guessing which variable to change.
- **Report what you see:** copy error text from Godot's Output/Debugger panel into Claude Code.
- **Commit after each stage** so you can roll back if a change breaks things.
- **Use `/clear` between stages** to keep context focused; CLAUDE.md is reloaded automatically.
- When a stage gets big, ask Claude Code to make a plan first and approve it before it writes code.
