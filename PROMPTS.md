# Build plan — prompts for Claude Code

You don't paste these. Claude Code reads this file itself. Run one stage per session with:

```
/stage 3
```

(or just type "Do Stage 3 from PROMPTS.md"). Don't move on until the stage feels right in play — especially Stage 2.

## Progress
<!-- Claude Code updates this list when a stage is finished and you've confirmed it works -->
- [x] Stage 0 · [x] 1 · [x] 2 · [x] 3 · [x] 4 · [x] 5 · [x] 6 · [x] 7 · [x] 8 · [x] 9 · [ ] 10
- Earth chapter: [x] E0 (plan) · [x] E1 · [x] E2 · [x] E3 · [ ] E4 · [ ] E5 · [ ] E6 · [ ] E7

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

## Earth chapter

## Stage E0 — Plan the Earth chapter
> Read Earth_bending.md, CLAUDE.md and GAME_DESIGN.md, then look at how the Air abilities, PlayerTuning, tiles and room reset are currently built. Don't write game code yet. Propose an implementation plan for Earth as sub-stages (E1, E2, …) following Earth_bending.md §10, including any refactors needed so Air and Earth abilities can coexist later. Flag any rule in the spec that conflicts with the current code or that you expect to feel bad. After I approve, append each sub-stage to this file in the same format as the other stages (prompt + what I should see) and add them to the Progress list.

Rules decided in E0 are written into Earth_bending.md §11 ("Decided in Stage E0"). They override the older text above them.

## Stage E1 — Earth ground
> Read Earth_bending.md §2, §8 and §11. Add an `EarthTuning` resource (resources/earth_tuning.gd + .tres, exported on the player like PlayerTuning) and the input actions `earth_column` (A), `earth_boulder` (S), `earth_snake` (D); remove the WASD movement alternates from the InputMap. Add an earth tile to the placeholder tileset and an `EarthLayer` script for a separate TileMapLayer named "Earth" in a room: it tracks each cell's fresh/used state, knows each cell's exposed faces (which sides touch open air), draws used cells fading to dark over 0.2 s and a 1 px shiver on request, and restores everything on room reset. Add a player query "touching fresh earth?" (feet on the floor, or wall-sliding on an earth wall) and show it on the F1 debug label. Let rooms declare which elements are allowed (Air abilities do nothing in Earth-only rooms). Add the shared `spawn_gravel(position, amount, direction)` helper. Build a test room with earth floors, walls, ceilings and a few plain gray solids. Add a temporary debug key that marks the earth tile under the player as used.

**You should see:** brown-yellow earth tiles on floors, walls and ceilings. The F1 label says when you're touching fresh earth. The debug key darkens the tile under you (a short fade) and drops some gravel. R brings it back. A/S/D no longer move you, and Air abilities are off in this room.

## Stage E2 — Shared bend core (the shadow)
> Read Earth_bending.md §4, §8 and §11. Add an `EarthBend` player state shared by all three moves: entered when an earth key is pressed while touching fresh earth (Idle, Run, WallSlide). Rooted stance with a small squash, world at 0.3× speed (FX slow motion), all bend timers in real time. The shadow (dark oval) starts under the feet; after 0.5 s it crawls at 60 px/s along the faces of connected fresh earth, wrapping around inner and outer corners: on floors and ceilings in the facing direction, on walls up (down if holding down). It stops at a gap, plain solid or used earth. The aim phase ends automatically after 2.5 s. Jump cancels without using earth (and the press doesn't also jump). Move and draw the shadow in `_process` with real time so it stays smooth while physics is slowed. Gravel at the feet, along the path (with tile shiver) and at the shadow. For this stage only, releasing A marks the target tile used and makes a gravel burst with a small shake. Add a debug draw (F3) of the face path.

**You should see:** holding A on earth slows the world, a shadow appears under you and crawls away after half a second, wraps over a ledge edge and down its side, and stops at gray rock or a gap. Releasing A darkens the tile under the shadow. Pressing C cancels with nothing used. It feels the same every time, because the timing is in real time.

## Stage E3 — Earth Column
> Read Earth_bending.md §5 and §11. Add `EarthColumnAbility` as a component under the player. Releasing A raises an 8×24 column out of the shadow's surface in 0.1 s, perpendicular to it (up from floors, sideways from walls, down from ceilings), in used-earth color, and the tile becomes used. The column is a bouncer: anything touching a face is launched away from that face at 220 px/s. The player goes through a new `Launched` state with a short steering lock; sideways launches get a small upward component (Celeste side springs). Bouncing refills the Air dash. Crates and wisps are launched through the Pushable contract. A quick tap (release before the shadow moves) raises the column under the player as a super jump. Columns are removed on room reset. Gravel burst and shake on rising, a gravel puff on each bounce.

**You should see:** tap A on earth for a super jump (about twice a normal jump), then land on the column: it's a platform now. Hold A, let the shadow go up a wall and release: the column throws you sideways across a gap. A column from a ceiling crushes a wisp against the floor. A column rising under a crate throws it up. (Springs only while rising, crushing, and the mixed Air + Earth room were decided in E3, see Earth_bending.md §11.)

## Stage E4 — Boulder
> Read Earth_bending.md §6 and §11. Add `BoulderAbility`. Releasing S rips a 16×16 boulder out of the shadow's tile and the one before it on the path (both become used) and pops it away from the surface: it eases out about 22 px, hangs briefly, then falls. Slow motion ends at release; the throw is timed in game time. Pressing S again throws it in the arrow direction (8 directions; facing if none). The perfect window is ±0.08 s around the hang moment: the boulder flashes white, flies at 320 px/s and ignores gravity for 0.3 s. Off-peak throws scale smoothly down to 180 px/s with normal gravity. The player stays rooted until the throw (max 1.0 s); no throw = it drops and shatters. One boulder at a time. On impact: sticks into any earth face as a solid 2×2 block (standable, wall-jumpable); shatters on plain solid or another boulder; bounces off columns. Enemy and cracked-wall hits come in E6. Removed on room reset.

**You should see:** hold S, release, press S again just as the boulder hangs: it flashes white and flies straight and fast. A late throw is slow and droops. A boulder thrown into an earth wall sticks and you can stand on it and wall-jump off it. One thrown at gray rock shatters into gravel.

## Stage E5 — Earth Snake
> Read Earth_bending.md §7 and §11. Add `EarthSnakeAbility`. Hold D for the shadow, release D: a ribbon of earth emerges at the shadow and its head moves at 80 px/s (real time) on the tile grid, steered by the arrows (4 directions, no reversing onto itself). The world stays slowed and the player stays rooted. Budget: up to 12 tiles, one fresh tile from the emergence patch per snake tile, darkening outward from the emergence point. It hardens when D is pressed again, the budget runs out, the head hits something solid (or the player), or 2.5 s pass. While moving, the head pushes crates and boulders through the Pushable contract. Hardened, it is a solid, standable platform in used-earth color that blocks orbs and enemies. Removed on room reset.

**You should see:** hold and release D, then steer a bridge across a gap with the arrows. The patch it came from darkens tile by tile, and the snake stops when the earth runs out. It hardens into a platform you can walk on. A sentry orb pops against it.

## Stage E6 — Cracked walls and enemies
> Read Earth_bending.md §2, §5–§7 and §11. Add cracked walls (gray with crack lines, solid, resettable): a boulder breaks one and shatters. Boulder hits: knocked back and defeated (a wisp is defeated, a sentry destroyed). Columns launch enemies, so a wisp launched into spikes is defeated (it already dies to spikes). The snake head knocks enemies back. Check that slow motion slows enemies and orbs during bends. Build a test room with all of these.

**You should see:** a boulder smashes a cracked wall open. A boulder kills a wisp or a sentry. A column under a wisp throws it into spikes. A snake wall blocks orb fire, and its head shoves a wisp away.

## Stage E7 — The 5 Earth rooms
> Build the Earth chapter rooms 1–5 from Earth_bending.md §9 in a separate world scene (scenes/earth_world.tscn) with an Earth layer per room, Earth-only (Air off), connected in order and ending at a Goal with the end screen. Make sure the F2 room picker works there. Update the CLAUDE.md folder layout with the new Earth folders. Explain how to paint earth in the editor.

**Test:** play all 5 Earth rooms. Note every spot that feels unfair or confusing and give Claude the list.

---

## Tips for vibe coding with Claude Code
- **Describe feel, not code:** "the jump feels floaty at the top" or "the dash stops too abruptly" works better than guessing which variable to change.
- **Report what you see:** copy error text from Godot's Output/Debugger panel into Claude Code.
- **Commit after each stage** so you can roll back if a change breaks things.
- **Use `/clear` between stages** to keep context focused; CLAUDE.md is reloaded automatically.
- When a stage gets big, ask Claude Code to make a plan first and approve it before it writes code.
