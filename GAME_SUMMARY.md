# Windbound: game summary so far

*Snapshot of 21 Oct 2026, written to bring a fresh conversation up to speed before designing the next element. The full specs are `GAME_DESIGN.md` (core game, Air chapter) and `Earth_bending.md` (Earth chapter, with every play-test decision in its §11). Next elements: `Fire_bending.md` (spec v1) and `Water_bending.md` (draft).*

---

## 1. The game in one paragraph

**Windbound** is a Celeste-style precision 2D platformer where the hero is a bender. Bending isn't a power-up bolted onto platforming: it *is* the platforming, and every move also solves puzzles and fights enemies. The game is built in **chapters, one element each**. **Air** (7 rooms) is finished and **Earth** (10 rooms) is built and waiting for its play-test. The next step is to design a third element (Water and Fire are the candidates from the original pitch).

## 2. Status

| Part | State |
|---|---|
| Core movement (Celeste feel) | Done, tuned in play |
| **Air chapter**: glide, gust (the dash was removed); 7 rooms; end screen | Done (Milestone 1). The polish pass (Stage 10) is built but not yet ticked off |
| **Earth chapter**: column, rock, snake, cracked walls, enemies | Mechanics done and play-tested (Stages E1–E6) |
| Earth chapter rooms 1–10 | Built (Stage E7), **not yet play-tested** |
| Two Earth control experiments | Built, **off by default**, waiting to be tried (§7.8) |
| Main menu | Air chapter, Earth chapter, Earth test rooms, Air + Earth mixed test rooms |
| **Fire chapter** | Specced (`Fire_bending.md`) and planned as Stages F0–F15 in `PROMPTS.md`; F0 (plan) done, building from F1 |

## 3. Tech and constraints

- **Godot 4.7, GDScript.** 2D, internal resolution **320×180**, integer scaling, **8×8 px tiles**.
- **Placeholder art only** (rectangles, polygons, lines, particles), with one fixed color per object type. The ground of Earth rooms is painted per room in a Celeste-like style: bright crust, dark hatched inside.
- **Keyboard only.** The developer is new to Godot, so code is heavily commented and modular.
- Every feel number lives in a tuning resource (`PlayerTuning`, `EarthTuning`) that can be edited live in the Inspector.
- Each ability is a separate component node under the player, plus player states (a state machine), so an element can be added without rewriting the player.
- Rooms say which elements work in them (`air_allowed`, `earth_allowed`). Chapter rooms allow only their own element; mixed rooms allow both.

## 4. Design pillars and the rule for every element

1. **Movement feels great before anything else.**
2. **One verb, three uses.** Every ability has a **movement**, a **puzzle** and a **combat** use. No ability exists for only one of them.
3. **Fail fast, retry instantly.** Death costs under a second; dying or pressing R resets the whole room (objects, earth, creations).
4. **Readable at a glance.** One color and shape per object type. **No health bars**: outcomes come from what things are pushed *into* (spikes, walls).

Two more rules followed so far: each element **uses its own keys** and never reuses another element's, so later rooms can mix elements; and **anything that needs aiming slows the world down** while you aim.

## 5. Controls (all keyboard)

| Key | Action |
|---|---|
| Arrows | Move; aim (8 directions) for the gust and throws; steer the snake |
| **C** (or Space) | Jump (hold for higher). In the air: a fresh press = glide. Cancels bends and lets go of a held rock |
| **X** | free (was the Air dash, removed) |
| **Z** | Air: gust (hold to aim in slow motion) |
| **A** | Earth: column (quick tap) / snake (hold) |
| **S** | Earth: rock (tap) / big rock (hold) |
| **Q** | Fire: fireball (tap) / aim in slow motion (hold), from Stage F4 |
| **W** | Fire: flame jet burst (hold to chain), from Stage F3 |
| **R** | Restart room |
| **Esc** | Pause |

A new element needs its own keys that don't clash with these. Fire takes Q and W (it had D and F until Stage F3); D and F are free. Debug keys: F1 overlay, F2 room picker, F3 debug draw, F4 save tuning, F5 tuning panel (from F2).

## 6. Core movement

Values in the spirit of Celeste: run 90 px/s, gravity 900 px/s², jump about 30 px (variable height), apex half-gravity, coyote time and jump buffer 0.1 s, wall slide and wall jump, 4 px corner correction, max fall 300 px/s (500 when holding down). The player is a white 8×11 rectangle with squash and stretch, dust, and a 0.4 s death burst.

## 7. The Air chapter (finished)

### 7.1 Abilities

| Move | What it does | Movement / puzzle / combat |
|---|---|---|
| **Glide** (jump again in the air) | Fall capped at 30 px/s; 1.5 s stamina per airtime; updrafts lift you | Long drifts, updraft "elevators" / reach high exits / float over enemies |
| **Gust** (Z) | 40 px cone. Pushes pushable things, recoils you the other way. One gust per jump (ground gusts are free); down-gust = extra jump; no arrow = blast all around plus an air brake and float. Hold to aim in slow motion | Extra jump, mid-air correction / crates onto plates, windmills, leaf and sail platforms / knock enemies into spikes, reflect orbs |

The dash was removed: the gust and the flame jet replace it (GAME_DESIGN.md §5.1). Wind crystals refill the glide bar ("breath") and the gust charge.

### 7.2 Objects
Spikes, wind zones (currents and updrafts), wind crystals, gust diamonds (two gusts this airtime), crates (gust-pushed, press plates), pressure plates, windmills (gust timer that opens a door), leaf platforms and sail platforms on rails, doors, leaf piles (cosmetic; they can hide things), no-glide "dead air" zones, enemy gates (open when the linked enemies are beaten), and the Goal.

### 7.3 Enemies
- **Wisp:** patrols and kills on touch. A gust stuns it; knocking it into spikes (or fire, a big rock, a reflected orb) defeats it.
- **Sentry:** stationary turret, firing a slow orb every 2 s when it sees you. A gust reflects orbs, which destroy sentries.

### 7.4 Rooms
1. First Breath (run, jump, wall jump)
2. The Dash (built for the removed dash: needs redesign)
3. Updraft
4. Gust Works (puzzle)
5. Sentry Pass (combat)
6. Sail Under Fire
7. The Gauntlet (finale and goal)

## 8. The Earth chapter (built, rooms awaiting play-test)

### 8.1 The core idea
Some surfaces carry **earth** (brown-yellow). You can only bend while touching earth, and **each earth tile can be bent once**: used earth turns dark until the room resets, so rooms become puzzles about *where to spend the earth*.

**The bend shadow:** holding the bend key slows the world to 0.3× and roots you in place. After 0.5 s a dark shadow crawls from your feet along the surface (60 px/s, real time), wrapping around corners. Releasing fires the move where the shadow is (auto-fires after 2.5 s). The shadow crosses earth, used earth and grass, but **gray rock stops it**. Gravel bursts show energy travelling through the ground.

### 8.2 Materials

| Material | Behavior |
|---|---|
| Fresh earth | Bendable once; rocks can be torn out of it |
| Used earth | Dark, cracked; can't be bent again until reset |
| Hardened earth | Under a pillar's base or behind a stuck rock: can't be torn out (so nothing is left floating), can still be bent |
| Grass | Plain ground of Earth rooms. Never bendable, but the shadow crosses it. Blades sway with the player, gusts and wind |
| Gray rock | Not earth; **blocks the shadow** (used under spike pits) |
| Cracked wall | Gray with cracks; only a thrown **big** rock breaks it |
| Hidden chamber | Looks like deep earth; digging into it makes the whole cover crumble, revealing a tunnel |

### 8.3 Moves

**A: Column and Snake (one key, decided in play-testing)**
- **Quick tap** (released while the shadow is still under you): an 8×24 **column** rises under your feet in 0.1 s and throws you up about twice a full jump (the **super jump**). A column only springs while it's rising; once up, it's a platform. A rising tip squeezing an enemy or you against a ceiling **crushes** it.
- **Hold** until the shadow crawls off your feet, then release: a **snake** of earth comes out at the shadow. You steer its head on the tile grid with the arrows (80 px/s real time) while the world runs at 0.2×. Press A again (or Jump) to harden it into a solid platform: a bridge, stairs or a wall that blocks orbs.
  - **Budget:** each snake tile spends one fresh tile of the patch it came from, darkening outward from the emergence point (max 12 tiles).
  - **Hardens by itself** when the budget runs out, it hits something solid, or 2.5 s pass.
  - **The head** shoves crates, loose rocks and wisps one tile at a time, rams wisps off edges, and throws *you* off it like a column if you steer it into yourself (or crushes you against the ground).
- The trade-off: there's no column away from you any more (wall and ceiling springs). A setting switches back to separate behavior.

**S: Rock (tap) and Big rock (hold)**
- No shadow: pressing S **tears an 8×8 rock** out of the tile just ahead of your feet, leaving a hole. Thick earth can be dug into rock by rock.
- The rock rumbles out and **hops** over your head while the world slows down. Press S again to **throw** it, in 8 directions, always away from you. In the **perfect window** (the rock turns white as it comes back down level with your chest, ±0.08 s) it flies straight and fast; off-peak throws are slower and droop.
- **Holding S** through the tear grows it into a **16×16 big rock** (tears a 2×2 block). It's heavier, breaks cracked walls, and its hole is wide enough to drop into.
- **Thrown rocks:** stick into earth as footholds (2×2 for a big rock), shatter on anything else, knock back and defeat wisps, and destroy sentries. Every rock blocks orbs, so a held rock is a shield.
- **Loose rocks:** a rock that comes down without being thrown lies there, solid and standable. Press S next to it to lift it again; that uses no earth. At most 3 per room.

### 8.4 Look and feel
Celeste-style painted ground. Lumpy cracked rocks that tumble in flight. Banded pillars with cracked tips. Snakes and pillars grow out of the ground with roots and fillets. Pebbles from every bend stay on the ground and get kicked, gusted and blown by wind (capped per room).

### 8.5 Rooms 1–10
1. Solid Ground (super jump)
2. Spending Earth (one tile per tower)
3. Stone Throw (rock footholds)
4. Breakthrough (big rock, cracked wall, hidden tunnel)
5. First Wisp (thrown rocks, snake ram)
6. The Long Bridge (snake bridges with exactly enough earth)
7. Sentry Line (enemy gate; snake walls and held rocks against orbs)
8. Heavy Earth (the snake head pushes a crate onto a plate)
9. Siege (scrolling room)
10. Summit (scrolling room, everything together, the Goal)

### 8.6 Experiments built but switched off (to try)
- **Steerable shadow:** you move the bend shadow with the arrows instead of it crawling by itself.
- **Hover-aim rock:** the rock hovers beside you instead of hopping. You aim with the arrows, and a closing contour marks the perfect throw.

## 9. What play-testing taught us (useful for the next element)

- **Real time where you aim, slow world around it.** The shadow, the snake head and the gust aim move in *real* time while the world is slowed, so aiming feels the same every time and stays smooth.
- **Fewer keys, more depth per key.** A tap and a hold on the same key, decided by what's happening on screen (the shadow still under you, or gone), felt better than a separate key per move.
- **Keep it close to the player when precision matters.** The rock was first aimed with the shadow; tearing it out right next to the player felt much better.
- **Make timing visible.** The perfect throw only clicked once the rock turned white during the window, and only on the way *down*.
- **Springs throw once.** "Anything touching it bounces" felt chaotic; "only the rising tip throws, then it's a platform" felt right.
- **Clear materials.** Splitting "grass (shadow crosses)" from "gray rock (shadow stops)" made spike pits fair.
- **Every resource is visible.** Spent earth darkens; pebbles stay. A wasted resource means pressing R, which is fine because retries are instant.
- **Big actions get big reactions.** Each one comes with screen shake, gravel and squash.

## 10. Shared systems a new element can reuse

- **Player state machine:** for example rooted states while aiming, and Launched for spring throws.
- **Ability components:** the shared-core pattern (one core module plus move components) used for the Earth bend.
- **Tuning resources:** live-editable feel numbers.
- **Pushable contract:** gust, push, launch and crush hooks that crates, wisps and pebbles already answer.
- **Room reset group:** everything resets on death or R.
- **Element flags per room.**
- **FX autoload:** slow motion, screen shake, freeze frames, gravel bursts, an SFX hook (no audio yet).
- **Debug and testing tools:** headless smoke tests per chapter, room generators, a room screenshot tool, F2 room picker.
- **Depths (rooms behind rooms):** any room can sit behind another (Stages D1-D4, `Level_editor.md` §5a). The rooms one depth behind show through the open air of the room you're in, hazed, sliding a little slower but lined up exactly at the nearest depth gate; a gate pair (same map spot, one depth apart) takes you through with Up. Each depth lives in its own far-away band of the world, so physics and room code are untouched; the editor's map shows one depth at a time (Page Down / Page Up) with the next one hazed underneath.

## 11. Parked ideas (written down, not built)

- **Earth + Air combos:** gust pushes a resting rock, glide off a column's bounce, a gust-propelled throw.
- Thicker earth layers allowing more bends; sand or mud variants of earth.
- **Water:** now specified in `Water_bending.md` (Chapter 4, spec v2, 26 Oct 2026: hold 1 for slow motion and steer a waterball inside a ring; it gathers water, rises as a water snake when lifted slowly, flies on when released; 2 freezes the water you hold into ice TILES, shown first as a ghost (the grid ice of 31 Oct 2026: the ball a block, a snake its trail's tiles, a waterfall a wall, a ball at a surface a raft; ice hanging in mid-air crumbles after a touch; ice keeps your speed). The water is simulated: height-field pools with waves + capped particles for loose water, under a 2 ms budget).
- **Fire:** now specified in `Fire_bending.md` (Chapter 3, spec v1: fire bar of pips, fireball, flame jet, burning grass).
- An element wheel in slow motion once there are several elements. Plan: one stamina bar per element, showing only the active one.

## 12. What's next

1. Play-test Earth rooms 1–10 and fix what feels unfair or confusing.
2. Try the two Earth experiments and keep or drop each.
3. **Next elements:** Fire is specced in `Fire_bending.md` and planned in `PROMPTS.md` as Stages F1–F15 (jet first, then fireball, burning grass, thicket, bonfires, vines, hot-air objects, gust vs fire, enemies, look pass, rooms, mixed rooms); Water is specced in `Water_bending.md` (spec v2) as Stages W1–W13, to build after Fire; its first two stages build only the water simulation, with play-test gates. Any further element should be designed in the same format as `Earth_bending.md`:
   - the idea in one paragraph
   - its materials or tiles
   - its own keys
   - each move with its movement, puzzle and combat use
   - the shared core (if any)
   - how it interacts with existing enemies and objects
   - a room list
   - a "parking lot" for unconfirmed ideas
