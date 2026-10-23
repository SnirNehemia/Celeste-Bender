# Build plan — prompts for Claude Code

You don't paste these. Claude Code reads this file itself. Run one stage per session with:

```
/stage 3
```

(or just type "Do Stage 3 from PROMPTS.md"). Don't move on until the stage feels right in play — especially Stage 2.

## Progress
<!-- Claude Code updates this list when a stage is finished and you've confirmed it works -->
- [x] Stage 0 · [x] 1 · [x] 2 · [x] 3 · [x] 4 · [x] 5 · [x] 6 · [x] 7 · [x] 8 · [x] 9 · [ ] 10
- Earth chapter: [x] E0 (plan) · [x] E1 · [x] E2 · [x] E3 · [x] E4 · [x] E4a · [x] E4b · [x] E4c · [x] E4c2 · [x] E4c3 · [x] E4d · [x] E4e · [x] E5 · [x] E6 · [x] E7
- Fire chapter: [x] F0 (plan) · [x] F1 · [x] F2 · [x] F3 · [x] F4 · [x] F5 · [x] F6 · [x] F7 · [x] F8 · ~~F9~~ (dropped) · [x] F10 (covered by F7) · [x] F11 · [ ] F11a · [x] F11b · [ ] F12 · [ ] F13 · [ ] F14 · [ ] F15
- Level editor (parallel track): [x] L0 (plan) · [x] L1 · [x] L2 · [x] L3 · [x] L4 · [x] L5 · [x] L6 · [x] L7 · [x] L8 · [ ] L9 · [ ] L10 · [ ] L11

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

(Changed after the E5 play-test: the snake moved to A, see Earth_bending.md §11 "One key"; D is free. The head throws or crushes the player it runs into.)

**You should see:** hold and release D, then steer a bridge across a gap with the arrows. The patch it came from darkens tile by tile, and the snake stops when the earth runs out. It hardens into a platform you can walk on. A sentry orb pops against it.

## Stage E6 — Cracked walls and enemies
> Read Earth_bending.md §2, §5–§7 and §11. Add cracked walls (gray with crack lines, solid, resettable): a boulder breaks one and shatters. Boulder hits: knocked back and defeated (a wisp is defeated, a sentry destroyed). Columns launch enemies, so a wisp launched into spikes is defeated (it already dies to spikes). The snake head knocks enemies back. Check that slow motion slows enemies and orbs during bends. Build a test room with all of these.

**You should see:** a boulder smashes a cracked wall open. A boulder kills a wisp or a sentry. A column under a wisp throws it into spikes. A snake wall blocks orb fire, and its head shoves a wisp away.

## Stage E7 — The 5 Earth rooms
> Build the Earth chapter rooms 1–5 from Earth_bending.md §9 in a separate world scene (scenes/earth_world.tscn) with an Earth layer per room, Earth-only (Air off), connected in order and ending at a Goal with the end screen. Make sure the F2 room picker works there. Update the CLAUDE.md folder layout with the new Earth folders. Explain how to paint earth in the editor.

(Built as **10 rooms** at the user's request, getting harder as you go: 1-4 platform/puzzle, 5 and 7 enemies, 6 and 8 puzzles, 9-10 wider rooms mixing everything. Generated by tools/build_earth_chapter.gd into scenes/rooms/earth/.)

**Test:** play all 10 Earth rooms. Note every spot that feels unfair or confusing and give Claude the list.

---

## Fire chapter

## Stage F0 — Plan the Fire chapter
> Read Fire_bending.md, CLAUDE.md and GAME_DESIGN.md, look at how the Air and Earth abilities, tuning resources, rooms and tests are built, and plan the Fire chapter as small stages. Clarify open points with me, then write the stages here and into Fire_bending.md §11.

Rules decided in F0 are written into Fire_bending.md §13 ("Decided in Stage F0"). They override the older text above them. In short: the jet comes right after the fire bar; an in-game tuning panel is built in F2; "air diamonds" are the wind crystal (+1) and gust diamond (+2); fire pips float over the head, always visible; pips are per room; the Shell gets its own stage; rooms are built like the Earth ones.

Every Fire stage adds its test room to `tests/fire_test_world.tscn` (rooms generated by `tools/build_fire_rooms.gd`) and a section to `tests/fire_smoke_test.tscn`, and puts every new number in `FireTuning`.

## Stage F1 — Fire bar and fire diamonds
> Read Fire_bending.md §3, §4 and §13. Add a `FireTuning` resource (resources/fire_tuning.gd + .tres, exported on the player like EarthTuning; this stage needs `max_pips`, later stages add their groups). Add the input actions `fireball` (D) and `flame_jet` (F), and remove the unused `earth_snake` action that still holds D. Add `Room.fire_allowed` and `Room.fire_start_pips`, and Fire to `Player.is_element_allowed()`. Add a `FireBar` component under the player: pips as a whole number from 0 to `max_pips`, `gain(amount)`, `spend() -> bool` (false at 0), signals `pips_changed` and `ran_dry`. Pips are per room: entering a room, dying or R sets them to that room's `fire_start_pips`. Draw the pips as a row of tiny 3×4 flames over the player's head, always visible where fire is allowed (one row above the gust pips in mixed rooms): they flicker out of sync, an empty pip is a dim ember outline, a spent pip snuffs out at once with a 2-frame flash and a puff, a gained pip flares up from a spark. Add fire diamonds (orange, a small flame inside; single = +1, double = +2; extra above the cap is lost) that don't respawn until death or R. Add a temporary debug key that spends a pip. Start the fire test world (Earth-style painted ground) with room Fire A, the fire smoke test with an F1 section, and "Fire test rooms" on the main menu.

**You should see:** a row of flame pips over the player. A fire diamond adds a pip (a double adds two) and is gone; past 5 the extra is lost. The debug key snuffs a pip with a flash. R or dying brings back the room's starting pips and every diamond. D no longer does anything Earth-related.

## Stage F2 — Tuning panel
> Read Fire_bending.md §10 and §13. Build an in-game tuning panel, toggled with F5 (a new `debug_tuning_panel` action), that works on any tuning resource: PlayerTuning, EarthTuning and FireTuning, one tab each. It lists the resource's `@export` vars under their export groups, read with get_property_list(), so values added later show up without touching the panel. Keyboard only: Up/Down pick a value, Left/Right change it (step taken from the export range hint, or a sensible default; hold Shift for ×10), bools flip with Left/Right, a key resets the value to the one in the saved .tres, PageUp/PageDown switch tabs. The game is paused while the panel is open (so the arrows don't move the player) and changes apply as soon as it closes, or live where they can. `Curve` values are shown read-only ("edit in Inspector"). Extend the existing F4 `debug_save_tuning` key so it saves all three resources back to their .tres files, with the on-screen confirmation it already has.

**You should see:** F5 opens a panel over the paused game. Pick `max_run_speed`, raise it, close the panel: you run faster. Press F4, quit and run again: the value is still there. Tabs switch between Player, Earth and Fire.

## Stage F3 — Flame jet
> Read Fire_bending.md §5.2, §8, §9.3 (flame jet) and §13. Add `FlameJetAbility` under the player and a `Jetting` state. Pressing W (`flame_jet`; the fire keys moved from D/F to Q/W in this stage) spends 1 pip and starts a burst of `jet_burst_time` that runs to its end even if W is released. Gravity is off; the arrows steer live in 8 directions (no arrow = up). The thrust multiplier (`jet_thrust_curve` if set, else lerp from `jet_thrust_start` to `jet_thrust_end`) scales `jet_max_speed` and `jet_accel`; `jet_turn_accel` changes direction sideways to the velocity. Holding W when a burst ends chains the next pip with a pump flare (the curve restarts). Jump cancels a burst at once (the pip is still spent, and the press doesn't also jump). Hitting a ceiling head-on ends it (bonk). At the end, keep `jet_end_carry` of the velocity, then normal gravity with apex half-gravity. No pip: a sputter (three gasps, smoke, no thrust), also at the end of a chain that ran dry. Fire diamonds are collected mid-burst. Build the first two fire building blocks, `FlameTongue` (noise-driven polygon, 3 nested layers, additive core) and `EmberEmitter`, and use them for a basic plume (24 px, opposite to the thrust, longest and whitest at ignition, shrinking as the burst tapers) and an ignition "whoomp" ring. The plume ignites nothing yet (F4). Every jet value is in FireTuning and the panel. Test room Fire B: a 10-tile gap with a fire diamond before it, a shaft for a 3-pip chain, a diamond-chain fuel route.

**You should see:** W throws you into a surge that tapers off, steered by the arrows; one pip crosses the 10-tile gap. Hold W to chain up the shaft, each pip a visible pump. C cuts a burst short and you fall. With no pips, W coughs smoke. Changing a jet value in the panel changes the feel at once.

## Stage F4 — Fireball, Flammable and braziers
> Read Fire_bending.md §5.1, §6.2 (brazier), §8, §10 and §13. Add `FireballAbility`: tap Q throws an 8×8 fireball at `fireball_speed` in the arrow direction (facing if none), no gravity, guttering out after its max range; holding Q aims in slow motion like the gust (reuse the GustAim state: world 0.3×, aim in real time, rooted on the ground, drifting in the air), releasing throws, Jump cancels the aim without spending. It costs 1 pip; at 0 it fizzles (smoke puff, 2 dull sparks). Define the `Flammable` contract (duck typing like pushable.gd: `ignite(source)`, `is_burning()`, `snuff()`, group `flammable`) and the `FireHazard` group (kills the player on touch through the same path as spikes; your own plume never counts). A fireball ignites what it hits plus every flammable within `fireball_splash`, then bursts (flash, spark ring, smoke, embers that stick and glow). Add braziers as Switches that open doors: permanent, and timed (they go out after N s, shrink, gutter the last second). Lighting one: flare, spark ring, 2-frame freeze and a shake. The jet plume now ignites flammables it touches. Test room Fire C: a brazier across the room opening a door, a timed brazier racing a door, a brazier only the jet can reach.

**You should see:** tap Q: a fireball flies and lights the far brazier, and the door opens. Hold Q: the world slows and you aim; C cancels and keeps the pip. With 0 pips Q fizzles. A timed brazier gutters and its door closes. Jetting past a brazier lights it.

## Stage F5 — Burning grass (FireGrid)
> Read Fire_bending.md §6.1, §9.3 (burning grass, smolder → ash) and §13. Add `FireGrid`, one per room with a Grass layer (made by Room like the PebbleField), in the reset group. It owns each grass cell's state (grass → burning → smoldering → ash), the spread queue (`spread_delay` ± `spread_jitter`), `burn_time`, `smolder_time` and the `max_burning_tiles` cap (extra ignitions wait). Fire spreads along connected exposed grass surfaces (floors, grassy walls, around corners), reusing the Earth shadow's face walking; never through air or non-flammable tiles. Burning cells are FireHazards. Ash is solid ground that never burns again, painted dark gray with pale flecks by the GroundPainter; the Earth shadow crosses it. Fireballs and the plume ignite grass, and taking off with the jet from grass scorches the tile under you. Blades on burning cells curl and blacken, each newly lit cell flares for 0.1 s, smoke rises behind the front. Test room Fire D: a long fuse to a brazier with a gray-rock shelter on the way, and a grass run to light by jetting along it. The smoke test checks that the burning count never runs away and that R restores every cell.

**You should see:** a fireball into the grass starts a front that runs tile by tile, up a grassy wall and around its corner, leaving smolder then ash. Standing in it kills you; standing on gray rock is safe. The fuse lights the far brazier. Jetting off grass leaves a fire behind you. R puts the grass back.

## Stage F6 — Thicket and overgrown covers
> Read Fire_bending.md §6.1b, §9.3 (thicket burn, flash-over) and §13. Add a "Thicket" TileMapLayer (solid, painted by the GroundPainter as dark tangled brambles with thorny edges). FireGrid burns thicket through its whole volume: fire spreads to the 4 neighbors and to and from touching grass (`thicket_spread_delay`, `thicket_burn_time`); a burnt cell crumbles into falling ash and becomes open air, so a burning floor drops you. Thrown rocks shatter on thicket; the Earth shadow crosses it. Add overgrown covers: a layer marking cells that look like grass ground or thicket with a small tell (hanging root tendrils); fire reaching any cell flashes the whole connected cover over in `overgrown_flashover_time`, revealing the chamber behind it (objects inside stay hidden and switched off until then, like the HiddenLayer). Flash-over: 2-frame freeze and a shake. All restored on R. Test room Fire E: a thicket wall, a thicket floor over a lower path, an overgrown cover hiding a fire diamond.

**You should see:** a fireball into a thicket wall sets it glowing, it burns and crumbles into ash, and the way is open. A burning thicket floor drops you to the path below. Fire touching the overgrown cover flashes the whole thing over and reveals a chamber with a diamond. R brings it all back.

## Stage F7 — Bonfires, hot updrafts and air diamond conversion
> Read Fire_bending.md §4.3, §5.3, §6.2 (leaf pile, air diamond) and §13. LeafPile implements Flammable: lit, it becomes a bonfire (16×20 flame, a FireHazard, lasting `bonfire_duration`, 0 = forever) with a 48×16 hot updraft above it; it reveals what it hid and ignites neighboring grass. Burning grass and thicket cells give a short, weak updraft while they burn. Add a `heat` flag to WindZone: a heat zone acts only on a gliding player (lift `hot_updraft_lift`) and on nodes in the new `heat_receiver` group (`apply_heat(strength, delta)`); nothing else is lifted. Any flame touching a wind crystal or gust diamond converts it (an orange wipe from the touching side, then a flare) into a +1 or +2 fire diamond, single use until reset. Test room Fire F (Air allowed, for the glide): a bonfire elevator to glide up, a leaf pile hiding a wind crystal, a gust diamond converted across a gap with a fireball.

**You should see:** a fireball turns a leaf pile into a roaring bonfire that kills on touch. Gliding over it lifts you high. Burning the pile reveals the crystal already orange. A fireball across the gap turns the blue gust diamond into a +2 fire diamond. R puts the piles and diamonds back.

## Stage F8 — Vines and burning Air objects
> Read Fire_bending.md §6.2 (vine, crate, leaf platform / sail), §9.3 (vine burn) and §13. Add vines (ropes and barriers, not climbable) that hold up a platform or a crate, or keep a gate shut: lit at a point, they burn outward along their length in 0.6 s and whatever they held falls or opens (a gate through the Switch/Door path). Crates become Flammable: they burn for 1.5 s (FireHazard, igniting grass under them), then collapse into an ash pile and are gone until reset. Leaf platforms burn away in 0.8 s; a burning sail stops catching wind and its platform coasts to the end of its rail. Test room Fire G: a vine-hung platform, a vine gate, a crate to burn off a plate.

**You should see:** a fireball cuts a vine: a glowing line runs along it, it snaps and the platform drops. A vine gate burns open. A burning crate on a plate collapses into ash and the plate lifts. R brings everything back.

## Stage F9 — Hot-air objects (DROPPED)
**Dropped after building it (22 Oct 2026, developer's call):** the balloon, heat sail and heated windmill didn't add enough. Fire's continuous-push puzzles will come from Fire + Water making steam (Water chapter). Hot updrafts stay as the glide's elevator only. Don't build this stage; the text below is kept for reference.

> Read Fire_bending.md §6.4, §9.3 (balloon, heat sail) and §13. Add the balloon platform (an envelope over a 16 px basket whose top is a solid platform; it rises up to `balloon_rise_speed` while its mouth is in a hot updraft and sinks at `balloon_sink_speed` back to its rest point otherwise; the envelope is flammable, burns in `balloon_envelope_burn_time` and the basket drops) and the heat sail (a platform on a rail pushed toward its drive end while a hot updraft overlaps its sail, slowing to a stop outside heat; the sail is flammable). Windmills join `heat_receiver`: a hot updraft under the blades spins them and holds the door open; when the heat stops they wind down and the normal door timer starts. Test room Fire H: a bonfire under a balloon, a grass run under a heat sail across a pit, an out-of-reach windmill over grass.

**You should see:** light the pile under the balloon and it rises to the top and stays; ride it up. Burning grass under the rail moves the heat sail in steps across the pit. Lighting the grass under the windmill spins it and opens its door until the fire dies. A careless jet sets the balloon's envelope on fire and the basket drops.

## Stage F10 — Gust against fire (DONE in F7, rest dropped)
**Covered by the F7 play-test work** (Fire_bending.md §13 "Decided in Stage F7"): a gust snuffs burning grass and thicket, a close gust scatters a bonfire (this replaced the flare) and blows out lone embers. The rest is dropped: a gust doesn't snuff fireballs, stop vine burns or char burning crates, and there is no boosted gust in hot updrafts. The text below is kept for reference.

> Read Fire_bending.md §5.3 (gusts), §5.4, §9.3 (bonfire flare, snuff) and §13. In rooms with Air and Fire, a gust acts on fire inside its cone (an all-around gust in its radius): a burning grass or thicket cell turns to ash at once (already done in the F7 play-test: `FireGrid.snuff_in`; burning leaves too), a fireball in flight is snuffed, a vine burn stops, a burning crate is charred (still solid, can be lit again); braziers aren't affected; a bonfire flares for `bonfire_flare_time` (flame ×1.6, blue base, updraft ×1.5, gusting again restarts it). A gust fired from inside a hot updraft gets ×1.5 force and ×1.25 cone length, tinted orange with sparks (`WindZone.gust_multiplier`). Test room Fire I (Air + Fire): a grass fire to snuff into a safe path, a bonfire to flare under a balloon, a heavy push only a boosted gust manages.

**You should see:** a gust at burning grass blows it out into ash and the fire stops there. A gust at a bonfire makes it flare with a blue base and the balloon surges up. A gust from inside a hot updraft is orange and pushes further.

## Stage F11 — Enemies and the vine monkey
> Read Fire_bending.md §7 and §13 (especially "Decided before Stage F11"). Add `ElementImmunity`, a small per-enemy table (for each hit type: kill, stagger, push or ignore) that the wisp, the sentry and the new enemies share, so every hit goes through one damage path. Fire hooks: a wisp dies to a fireball, the plume, burning cells and bonfires (it doesn't avoid fire); a fireball destroys a sentry and cancels an orb head-on (both burst); orbs pass through the plume. Add the vine monkey on the ground (about 10×10, a thicket body with vine arms and tail; runs a fixed route on a loop, hopping short gaps; kills on touch; lifted by hot updrafts as a heat receiver). Only fire kills it: spikes, rocks, gusts, columns and the snake push it around. Lit, it becomes a living torch for `leafling_torch_time`: it runs at 120 px/s in its current direction, turning at walls and ledges, ignites every flammable it touches and still kills, then crumbles to ash. A gust snuffs a burning monkey (it smolders, is stunned 1 s, then carries on). Vine swinging waits for F11a. Test room Fire J (Air allowed).

**You should see:** a fireball kills a wisp and destroys a sentry; a fireball and an orb cancel out. A monkey runs its route over spikes unharmed and drifts up over a bonfire. Lit, it runs and sets the grass and a leaf pile across its gap on fire. A gust puts it out.

## Stage F11a — Vine monkey swinging
> Read Fire_bending.md §7.2 (vine monkey) and §13. The monkey's route can include vines: it jumps to a vine, grabs it (the rope takes its weight), swings and lets go at a set point to land on the next ledge, on a loop you can learn. A vine burnt while it hangs on drops it. A lit monkey on a vine sets the vine burning. Test room Fire K.

**You should see:** the monkey crosses a pit vine to vine, the same way every loop. A fireball at its vine drops it into the pit. Lit mid-swing, it burns the vine it holds.

## Stage F11b — Thicket elephant
> Read Fire_bending.md §7.2 (thicket elephant) and §13. Add the elephant (96x60, minimalist flat rectangles like the wisp: a stepped stone silhouette, a mossy trunk, moss on its back, a long simulated vine tail; basic walk animation). Slow patrol; kills on touch only at its front; its back is a moving platform 60 px up (climbing on is a puzzle; it walks over spikes). It charges whenever it sees you in front of it on its level (rear as the tell, then charge). Tail whip: wiggle, raise (the tell), strike down behind like a whip; kills anything it touches. Three burn spots, each lit from its own side, each staying burnt until R: trunk: rears and charges forward 2x fast; tail: bolts away from the fire 2x fast; back: the tail strikes forward over its back (and does whenever someone stands on its burnt back). A charge stops at walls (stun, shake), brakes at ledges, and smashes cracked walls, thicket and new STONE walls that only an elephant breaks. A big rock pushes it back (stopping a charge); a column or the snake breaks on touching it. All three burnt: it crumbles into a big heap of ash. Enemies go back to their start on every reset and when you walk into their room. Test room Fire L.

**You should see:** climb onto the elephant and ride it across a spike pit to a high diamond. Stand in front of it: it rears and charges; jump onto a ledge and it smashes the stone wall. Burning its tail makes it bolt through thicket. Its tail wiggles, rises and whips. With all three spots burnt, it crumbles.

## Stage F12 — Shell
> Read Fire_bending.md §7.2 (Shell) and §13. Add the Shell (12×8 slate-gray armored crawler with ochre seams, a slow 25 px/s patrol turning at ledges and spikes, kills on touch) with its ElementImmunity row: only a thrown big rock kills it (a loose big rock falling on it from 2+ tiles too, to confirm in play-test); a small rock staggers it (stops 0.5 s, knocked back 4 px); spikes, crushing, fireballs (the pip is still spent), the plume and burning grass do nothing; a column lifts it and the snake head shoves it a tile; gusts barely nudge it; orbs bounce off. Test room Fire M (Earth + Fire, Air allowed) with every enemy, checking every cell of the §7.2 table; the smoke test checks the table too.

**You should see:** a Shell shrugs off fireballs, spikes and fire. A small rock makes it stagger; a thrown big rock kills it. A burning thicket floor under it drops it out of the way. Every cell of the §7.2 table does what it says.

## Stage F13 — Fire look & feel pass
> Read Fire_bending.md §9. Bring every fire source in §9.3 up to the spec: add `SmokeEmitter`, `HeatGlow` and the optional `HeatShimmer` (FireTuning toggle, off by default), the §9.1 palette with additive core layers, bonfire spark bursts and smoke columns, the conversion wipe, the balloon and sail looks, the monkey torch, the elephant's burning spots, the thicket glow, the snuff and flare effects. Fire FX count toward the per-room particle cap and degrade gracefully (fewer embers first, then smoke). Add the §9.4 SFX hooks through FX.play_sfx. Save screenshots of every fire test room with the screenshot tool.

**You should see:** every fire flickers, sways, throws embers and smokes: alive in a still screenshot and in motion. A room full of burning grass stays smooth.

## Stage F14 — The 10 Fire rooms
> Read Fire_bending.md §12 and §13. Build Fire rooms 1–10 in scenes/fire_world.tscn, generated by tools/build_fire_chapter.gd into scenes/rooms/fire/, Fire-only (Air and Earth off), each with its `fire_start_pips`, connected in order and ending at a Goal with the end screen. Lay out jet gaps from the measured burst distance. Add "Fire chapter" to the main menu, make sure the F2 room picker works there, add tests/fire_chapter_smoke_test.tscn (structure, each room's key move, no runaway burning), and update CLAUDE.md's folder layout and commands.

**Test:** play all 10 Fire rooms. Note every spot that feels unfair or confusing and give Claude the list.

## Stage F15 — Mixed test rooms
> Read Fire_bending.md §12 (mixed test rooms) and §13. Build the Air + Fire and Earth + Fire test rooms from §12 into their own test worlds (like tests/mixed_test_world.tscn) and add "Air + Fire test rooms" and "Earth + Fire test rooms" to the main menu.

**You should see:** Air + Fire: bonfire glide elevators, a snuffed safe path, a burning sail (the balloon and boosted gusts were dropped with F9/F10). Earth + Fire: a Shell with leaflings, a leafling launched by a column into a leaf pile, a rock foothold next to a thicket wall you burn open.

---

## Level editor track (parallel)

Not an element chapter. It runs in its own sessions alongside the element stages (`/stage L3` and so on). Spec: `Level_editor.md`, with the decisions in §2. Rules for every L stage:
- Editor code lives in `scenes/editor/`, the Story screens in `scenes/ui/`, levels in `res://levels/`. Gameplay scripts are not touched, except the Goal/EndScreen hook in L11 and "Back to editor" in the pause menu in L3.
- Each stage adds a section to `tests/editor_smoke_test.tscn`. It drives the editor through its functions (paint, place, link, save, load, play), not the mouse, and prints PASS/FAIL.
- Editor keys are InputMap actions named `editor_*` (`Level_editor.md` §4).

## Stage L0 — Plan the level editor (DONE)
> Clarify the level editor and Story Mode with me, then write the spec and the stages.

Written into `Level_editor.md` (spec v1) and the stages below.

## Stage L1 — Main menu and level storage
> Read Level_editor.md §2, §3 and §10. Restructure the main menu: Story Mode (a placeholder screen for now), Level Editor (greyed out with "dev build only" when `OS.has_feature("editor")` is false), and a "Chapters & test rooms" submenu holding today's five entries. Esc goes back, and C or Enter picks as now. Keep the chapter list a const array, so F14/F15 only append to it. Add `scenes/editor/level_storage.gd` (the only code that knows `res://levels/`): list, save a world scene with `PackedScene.pack()`, load, rename, duplicate, delete. Add the `LevelInfo` node (title, start room, notes). Add the level library screen (list + New / Open / Duplicate / Rename / Delete with confirm). New makes a level with one empty 320×180 room, a SpawnPoint, Player, RoomCamera and DebugOverlay. Open plays it for now (there's no editor yet). Start tests/editor_smoke_test.tscn: make a level from code, save it, reload it, check its structure and that RoomManager runs it.

**You should see:** the new menu, with the old entries under "Chapters & test rooms". Level Editor → New → a level appears in the list. Open drops you into an empty room you can walk in.

## Stage L2 — Editor canvas, ground painting, save
> Read Level_editor.md §4. Open from the library now goes to the editor screen: canvas, palette (only the Ground brush for now), top bar and status line. Switch the window to `canvas_items` stretch while the editor is open and back on leaving; check that the switch is clean. Add pan (middle drag, Space + drag), whole-step zoom, the 8 px grid (G), painting and erasing Ground tiles (left/right mouse, Shift-drag rectangles), undo/redo through `UndoRedo`, Ctrl+S save, an unsaved dot, and an Esc prompt if there are unsaved changes. Add the `editor_*` InputMap actions.

**You should see:** paint a floor and walls, undo and redo, save, leave, reopen: everything is still there and sharp at any zoom.

## Stage L3 — Spawn, goal and play-test
> Read Level_editor.md §6 (Basics) and §8. Make spawn point (one per room), goal and spikes (facing + tile count) placeable, movable and deletable. Tab plays from the start room, Shift+Tab from the mouse; Tab comes back with view, selection and undo history kept. Add "Back to editor" in the pause menu during play-tests. Pre-play checks: a missing start SpawnPoint blocks, the rest are status-line warnings. Reaching the Goal shows "Goal reached — time, deaths" and returns to the editor. Play-testing uses the level packed in memory, with no save needed.

**You should see:** build a small room with spikes and a goal, press Tab, play it, die on the spikes, reach the goal, land back in the editor where you were.

*Decided while building (L3):* the palette catalog was started here (Ground + Basics) instead of in L4. Spawn points can be moved but not deleted, because Room looks up `$SpawnPoint` when it starts. Spikes are dragged along a row or column, facing comes from the neighbouring ground, and R turns them. The play-test copy runs without its EndScreen, which would reload the editor scene.

## Stage L4 — Objects and the palette catalog (basics + Air)
> Read Level_editor.md §6. `scenes/editor/palette_catalog.gd` exists since L3 (Ground + Basics, with only the fields they need): add the remaining entry fields from §6. Add every Air object (wind zone, wind crystal, gust diamond, crate, windmill, leaf platform, sail platform, door, pressure plate, no-glide zone). Selection, drag-to-move, Delete and R already work (L3); add Alt = free placement, Ctrl+D duplicate and palette tabs. (The cross-track rule is already in CLAUDE.md.) Objects draw themselves in the editor where they already can (`@tool` scripts); the others get a stand-in in `editor_color`.

**You should see:** an Air room with crates, wind zones and crystals, laid out by mouse and played with Tab.

*Decided while building (L4):* placement snaps the object's OUTLINE, not its origin (see Level_editor.md §6 "As built"). Ctrl+D copies the selected object to the mouse, with its settings and links, by making a fresh instance and copying its saved settings: `Node.duplicate()` would also copy the drawing nodes it built in `_ready`. The palette has a tab per family. The editor updates the positions leaves and sails remember from `_ready` after every move, so their path and rail move with them.

## Stage L5 — Property panel and room settings
> Read Level_editor.md §5 (room settings) and §7 (properties). Add the property panel: a widget for each type (checkbox, number, dropdown, Vector2, 8-way direction picker), driven by the catalog's `editable_properties`. Add drag handles for `size_property` and `point_properties`. Every change can be undone. With nothing selected, the panel shows the room settings (title, elements allowed, fire start pips, one-key Earth).

**You should see:** turn a wind zone to blow left and make it wider by dragging, resize a door, set a room to Earth-only, play: it behaves that way.

*Decided while building (L5):* the room settings shown are those of the room last clicked in. The room's size isn't in the panel (L7's map resizes rooms). Quick changes to one setting are one undo step. The editor opens at the largest zoom where the start room fits between the panels.

## Stage L6 — Link tool
> Read Level_editor.md §7 (links). L starts link mode for the selected object if its catalog entry has a `link_property`. Clicking a target of the accepted type adds or removes it; Esc or L ends link mode. Links are always drawn as dim lines, bright for the selected object, and may cross rooms. Deleting a target drops it from every link list. Saving and reloading keeps the links (they're node references in the packed scene).

**You should see:** a crate, a pressure plate and a door. Link the door to the plate, play, push the crate onto the plate: the door opens.

*After L6 (play-test):* zones are picked by their edge only, because a placed no-glide zone swallowed every click inside it. Added the Eraser (E: objects first, zones from inside too, else tiles on every terrain layer) and a quick reference (H or "?").

*Decided while building (L6):* only doors link in the Air palette. A crate's `hung_from` takes vines only (Fire F8), so crates get their links in L9.

## Stage L7 — Map of rooms and import as copy
> Read Level_editor.md §5. M toggles the map view: rooms as named rectangles with a tiny tile drawing. Drag on empty space to make a room, drag to move, drag edges to resize, with snapping to the grid and to neighbour edges. Overlaps are refused (red), and openings on shared edges are marked green. Add the start-room star; double-click opens a room; neighbours are drawn dimmed in the room view. Add "Import room as a copy" from every existing world (Air 1–7, Earth 1–10, test worlds, other levels), placed where you click and fully owned by this level. Match the existing rooms' handling of 180 px heights.

**You should see:** three rooms in an L shape, with green exits between them. Play from the start: the camera slides room to room. Import Earth room 3 next to them and play through it.

*Decided while building (L7):* widths are whole tiles (at least 320) and heights are 180 + whole tiles, so the last tile row always hangs half below the room, as in every existing room. Positions are on the 8 px grid or on a neighbour's edge. A new room is empty but for its spawn point (changed after the play-test, see below). Dragging a left or top edge keeps the room's contents where they are in the level (in whole tiles of the room's grid); tiles left outside a smaller room are cut off, and undo brings them back. In the map: S = start room, Delete = delete room (never the start room or the last one), I = import (also from the room view). An imported room that is its own scene file is rebuilt from that file as a root, so no hidden tie to it is saved. Links to things outside the copied room are dropped.

## Stage L8 — Earth palette
> Read Level_editor.md §6 (Earth) and Earth_bending.md for the objects' settings. Add the Earth brush (EarthLayer; GroundPainter draws it in the editor as in play), cracked wall, stone wall, boulder and loose rocks to the catalog. Rooms with Earth painted default to Earth allowed.

**You should see:** an Earth room painted by mouse that looks like the Earth chapter and bends like it.

*Decided while building (L8):* the Earth brush is in the Terrain tab, the walls and rocks in a new Earth tab. Placed rocks are a new small object, `RockSpot` (`boulder_spot.tscn` big, `loose_rock_spot.tscn` small): it lays a loose Boulder there when the room starts and again after every reset, so boulder.gd is untouched. The cap of 3 loose rocks per room still applies. After every tile change in a room with Earth, `RoomLook` rebuilds the room's GroundPainter, so painting shows as in play (while a stroke is held, the raw tiles show). Walls are sized in tiles: catalog `size_unit`.

*After L7/L8 (play-test):* Earth bending didn't work in play-tests: the editor's hidden copy of the level was still in the scene tree, so group lookups (`EarthLayer.find_layer_at`) found its earth first. The editor's copy now leaves the tree while a play-test runs. Opening a world in the import list no longer errors (its rooms are read a moment later). Added: the eraser's Shift+drag clears a block (tiles on every layer, objects fully inside it); new map rooms start empty, and the room panel has a "Fill edges: <terrain>" button (walls, ceiling, 2-row floor) using the terrain brush chosen last; `Room.painted_ground` (new, on for every room the editor makes) draws plain ground with the GroundPainter too, so it looks like stone from the start; every palette entry has a `hint` (what triggers it, what it triggers, what breaks or burns it), shown as the button's tooltip, in the status line when chosen and in the property panel.

## Stage L9 — Fire palette
> Read Level_editor.md §6 (Fire) and Fire_bending.md §13. Add the Grass, Thicket and Overgrown brushes, fire diamond, brazier, vine (end-point handle), hanging platform (linked to its vines with L) and leaf pile. A room's FireGrid only runs in play, not while editing.

**You should see:** a grass field with a brazier and a hanging platform on two vines. Play, burn a vine: the plank swings, then falls.

## Stage L10 — Enemies palette
> Read Level_editor.md §6 (Enemies). Add the wisp, sentry, vine monkey, thicket elephant and shell (once F12 has landed; otherwise leave a note), each with its design settings (patrol range, facing…), and the enemy gate linked to its enemies with L.

**You should see:** an enemy gate that opens when the two wisps linked to it are beaten.

## Stage L11 — Story Mode
> Read Level_editor.md §9. Add the `StoryList` resource (`res://levels/story.tres`) and the Story screen: Continue, Level select (✓ with best time and deaths, next open, rest locked) and New run with a confirm. Add Edit order in dev builds: Shift+Up/Down moves an entry, plus Add (editor levels and the existing chapter worlds), Remove and Rename. Play the levels back to back with a level-complete card between them and the end screen after the last. Save progress in `user://story_progress.cfg`, keyed by scene path. Add the small Goal/EndScreen hook so the end screen only appears at the end of a story run. Check that Story Mode works in a web export (`tools/publish_web.ps1 -NoPush`).

**You should see:** Story Mode with Air 1–7, then one of your levels, then Earth 1–10. Finish the first, quit, come back: Continue starts the second, and the third is still locked.

---

## Next chapters (not planned in this file yet)
- **Water (Chapter 4):** only a draft in `Water_bending.md`. Refine it after Fire is built; no stages yet.

---

## Tips for vibe coding with Claude Code
- **Describe feel, not code:** "the jump feels floaty at the top" or "the dash stops too abruptly" works better than guessing which variable to change.
- **Report what you see:** copy error text from Godot's Output/Debugger panel into Claude Code.
- **Commit after each stage** so you can roll back if a change breaks things.
- **Use `/clear` between stages** to keep context focused; CLAUDE.md is reloaded automatically.
- When a stage gets big, ask Claude Code to make a plan first and approve it before it writes code.
