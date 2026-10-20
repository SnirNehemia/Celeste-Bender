# Build plan — prompts for Claude Code

You don't paste these. Claude Code reads this file itself. Run one stage per session with:

```
/stage 3
```

(or just type "Do Stage 3 from PROMPTS.md"). Don't move on until the stage feels right in play — especially Stage 2.

## Progress
<!-- Claude Code updates this list when a stage is finished and you've confirmed it works -->
- [x] Stage 0 · [x] 1 · [x] 2 · [x] 3 · [x] 4 · [x] 5 · [x] 6 · [x] 7 · [x] 8 · [x] 9 · [ ] 10
- Earth chapter: [x] E0 (plan) · [x] E1 · [x] E2 · [x] E3 · [x] E4 · [x] E4a · [x] E4b · [x] E4c · [x] E4c2 · [x] E4c3 · [x] E4d · [x] E4e · [ ] E5 · [ ] E6 · [ ] E7

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

## Stage E4a — Rock and tearing
> Read Earth_bending.md §6 and §11. The boulder becomes an 8×8 ROCK that is TORN out of the ground: its tile becomes open air (EarthLayer remembers torn tiles and restores them on room reset). Earth under or behind the hole is now on the surface and counts as fresh, so thick earth can be dug into rock by rock. No shadow for S: pressing S on earth tears out the tile just ahead of the feet, and the world slows to 0.5× until the throw. The rock rumbles out of its hole, then hops above the player's head, away from them (from a wall: away from the wall), lands and rests a moment. Perfect window: when the rock comes back down level with the player. Throws go away from the player, never into the wall you're on. It sticks into earth as a one-tile foothold. Pillars harden the earth under their base in a pyramid, and stuck rocks the tile behind them, so rocks can't dig them loose. Add a patch of thick earth to the boulder test room.

**You should see:** press S: a small rock tears out of the ground just ahead of you, leaving a hole, and hops over your head and away. The world slows down. It turns white as it comes back down past your chest: press S again then and it flies straight and fast. Aim up-right to stick a step high on the wall. Stand at the hole's edge and press S again to dig deeper. You can't dig under a pillar. R fills every hole again.

## Stage E4b — Ground look
> Make the ground look amorphous and not tile-like, while the layout and collision stay tile-based. A per-room GroundPainter draws the Earth, Grass and gray Tiles layers itself (the TileMapLayers stay for collision only): convex corners cut by 1-2 px, small seeded bumps along exposed edges, a lighter rim on top edges, speckles scattered across the ground rather than repeating per tile. Depth shading: a cell gets darker the farther it is from open air (surface, 1 deep, 2+ deep), recomputed when a tear opens a hole. Used earth also gets crack lines so it never reads as deep earth.

**You should see:** ground that looks like lumpy earth and turf, not a grid. Thick ground darkens toward its middle. Tearing a rock out of thick ground lights up the newly exposed earth.

## Stage E4c — Hidden chambers
> Add a "Hidden" TileMapLayer per room (no collision) marking open-air cells drawn as deep earth by the GroundPainter. When a tear connects a hidden region to the outside air, the cover over that whole connected region crumbles away (a short fade, pebbles/gravel falling out). Restored on room reset. Build a test room with a buried pathway reachable by digging.

**You should see:** a wall of thick dark earth. Dig into it with rocks: when the hole reaches the hidden pathway, the cover crumbles and reveals a tunnel you can walk through. R hides it again.

## Stage E4c2 — Big rock (hold S)
> Pressing S still tears out the small rock at once. If S is still held when the rock has rumbled out of its hole (the end of the tear phase), it GROWS into a 16x16 big rock: it tears out the 2x2 block made of its tile, the next tile along the surface (away from the player) and the two tiles behind those, then rumbles out of the 2x2 hole and hops like a small rock (same perfect window). If the 2x2 block can't all be torn out (thin earth, hardened, gray, the player in the way), it stays small. The big rock throws a little slower, sticks into earth as a 2x2 foothold (hardening every tile behind it) and shatters into more gravel. The 2x2 hole is wide enough to drop into. Update RoomEarthD so the tunnel is reached with a big rock.

**You should see:** tap S: a small rock as before. Hold S: the rock rumbles out, then the ground around it cracks open and a big rock comes out of a 2x2 hole. Throw it into an earth wall: a 2x2 step. On top of the earth wall in Earth D, a big rock opens the tunnel and you drop straight in.

## Stage E4c3 — Loose rocks
> A rock that comes to rest without being thrown (let go with Jump, or never thrown) no longer crumbles: it stays as a loose rock, solid and standable. Pressing S next to a loose rock lifts it again: it hops exactly like a freshly torn rock, with the same perfect window, and uses no earth. Thrown rocks still stick into earth or shatter. At most 3 loose rocks per room (the oldest crumbles). Room reset clears them.

**You should see:** tear a rock and don't throw it: it lands and stays. Walk up to it and press S: it hops up and you can throw it, perfect window and all, without digging. A big loose rock is a step you can stand on.

## Stage E4d — Pebbles
> Every earth interaction (tears, eruptions, impacts, shatters, a few along the shadow's path) leaves small pebbles that STAY on the ground. One pebble field per room, simulated like the leaf pile: the player, crates and wisps kick them as they move through, gusts and wind zones blow them. Capped per room (oldest go first), only the current room simulates, room reset clears them.

**You should see:** after a few bends the ground is littered with pebbles. Running through them scatters them, a gust blows them away, a wind zone rolls them along.

## Stage E4e — Rock and pillar look
> Take inspiration from the grass blades and the leaf pile. Rock: a lumpy polygon outline instead of a square, a crack and speckles, tumbling rotation in flight, sheds a pebble now and then. Pillar: layered bands, rough sides, a cracked tip, crumbles pebbles as it rises.

**You should see:** rocks that look like rocks and tumble when thrown; pillars that look like piled earth rather than brown rectangles.

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
