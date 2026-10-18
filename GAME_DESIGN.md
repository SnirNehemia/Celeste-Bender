# Game Design Doc — "Windbound" (working title)

A tight, precision 2D platformer in the spirit of Celeste, where the hero is an **air-bender**. Bending is not a power-up bolted onto platforming — it *is* the platforming, and the same three moves also solve puzzles and handle enemies.

This doc covers **Milestone 1: the Air vertical slice** — one element, 5 rooms, placeholder shapes. Other elements are listed at the end only so the code leaves room for them.

---

## 1. Design pillars

1. **Movement feels great before anything else.** If running and jumping in an empty room isn't fun, nothing else gets built.
2. **One verb, three uses.** Every air ability works for movement, puzzles *and* combat. No ability exists for only one of them.
3. **Fail fast, retry instantly.** Death costs under a second. Rooms are short and readable.
4. **Readable at a glance.** Placeholder rectangles, but each object type has one consistent color and shape.

---

## 2. Look & screen

- Internal resolution **320×180**, scaled up with integer scaling (pixel-perfect), window 1280×720 by default.
- Tile size **8×8 px**.
- Placeholder art only: `ColorRect` / `Polygon2D` shapes. Color key:
  - Player: white rectangle (8×11), turns pale blue when the dash is used up
  - Solid ground: dark gray · Spikes: red triangles · Wind zones: translucent cyan with drifting particles
  - Crates: brown · Windmills/fans: yellow · Enemies: purple · Projectiles: orange · Checkpoint/room exit: green
  - Puzzle objects (added in Stage 7): doors blue-gray · pressure plates tan, green when pressed · leaf platforms olive green with a pale pinwheel · sail platforms slate deck with a cream sail · rails thin gray-blue lines with end dots · leaf piles muted greens and golds (kept clear of yellow, orange and brown)
- Camera is **room-locked** like Celeste: each room is one screen (or scrolls inside its own bounds), with a quick slide transition between rooms.

---

## 3. Controls (keyboard only)

Mouse is not needed. Celeste-style 8-direction aiming with the arrow keys is more precise for a platformer than mouse aim, and it keeps one hand on movement, one on actions. Mouse aim can be revisited later for combat if it feels limiting.

| Action | Key | Notes |
|---|---|---|
| Move / aim | Arrow keys | Aim direction for dash and gust = held arrows (8 directions). The WASD alternates are dropped in Stage E1: A/S/D are the Earth keys (`Earth_bending.md` §3) |
| Jump | **C** (Space as alternate) | Hold for higher jump; hold while falling = glide |
| Air Dash | **X** | |
| Gust | **Z** | |
| Restart room | **R** | |
| Pause | **Esc** | |

All bindings live in Godot's **InputMap** under named actions (`move_left`, `jump`, `dash`, `gust`, …) so they're easy to remap and to add a gamepad later.

---

## 4. Core movement (no bending yet)

Starting values in the spirit of Celeste. All of these go in one tuning resource (`PlayerTuning`) so they can be tweaked in the Godot Inspector while playing.

| Parameter | Start value | Purpose |
|---|---|---|
| Max run speed | 90 px/s | |
| Run acceleration | 1000 px/s² | snappy start |
| Run deceleration (ground) | 400 px/s² | short slide |
| Air acceleration multiplier | 0.65 | slightly less control in air |
| Gravity | 900 px/s² | |
| Max fall speed | 300 px/s | tuned in play (was 160) |
| Fast-fall max (holding down) | 500 px/s | tuned in play (was 240) |
| Jump velocity | −105 px/s | |
| Variable jump time | 0.2 s | holding jump keeps upward speed this long; tap ≈ 7 px hop, full hold ≈ 30 px |
| Apex half-gravity threshold | \|vy\| < 40 px/s | gravity ×0.5 near the top of a jump while jump is held — floaty, controllable apex |
| Coyote time | 0.1 s | can still jump just after leaving a ledge |
| Jump buffer | 0.1 s | jump pressed slightly before landing still counts |
| Wall slide max speed | 40 px/s | |
| Wall jump | +130 px/s away, −105 px/s up | brief 0.15 s input lock away from the wall; upward speed is held like a normal jump (variable height) |
| Wall jump reach | 2 px | a wall this close counts as touching; no need to press into it |
| Corner correction | up to 4 px | nudge around ceiling corners instead of bonking |

The player is a **state machine**: `Idle`, `Run`, `Jump`, `Fall`, `WallSlide`, `Dash`, `Glide`, `GustAim`, `GustRecoil`, `Dead`.

---

## 5. Air abilities

Each ability lists its movement, puzzle and combat use.

### 5.1 Air Dash (X)
- Burst of 240 px/s in the aimed direction (8 directions; default = facing) for 0.15 s, ignores gravity during the dash.
- **1 charge**, refilled on touching ground or touching a **wind crystal** (floating green diamond that respawns after 2.5 s).
- Brief freeze frame (~3 frames) on dash start + small screen shake + afterimage trail.
- **Wake:** the dash blows a small gust *backward* from its start point (cone 24 px, push 120 px/s vs the gust's 40 px / 160). It looks like the gust and pushes Pushable things behind you. Toggle: `dash_wake_enabled`.
- **Movement:** cross gaps, reach ledges, chain off crystals.
- **Puzzle:** dashing *through* a wind zone briefly doubles the dash distance. The wake can nudge a crate or leaf you just dashed away from.
- **Combat:** dashing into a stunned enemy defeats it.

### 5.2 Glide (press Jump again while falling, hold to keep gliding)
- Started by a *fresh* Jump press in the air (not by holding the original jump), so normal jumps keep their feel.
- Fall speed capped at 30 px/s; horizontal control unchanged.
- **Stamina:** 1.5 s per airtime, refills on ground (shown as a small bar above the player).
- Inside an **updraft** zone, gliding lifts you upward instead.
- **Movement:** long horizontal drifts, ride updrafts.
- **Puzzle:** updrafts are the "elevators" of the level.
- **Combat:** float over ground enemies and their attacks.
- Riding an updraft costs no stamina (`glide_updraft_stamina_drain = 0`).

### 5.2b Shared air stamina ("breath") — experimental, on by default
- Toggle: `PlayerTuning.dash_uses_stamina`. When on, the dash spends **0.9 s of glide stamina** (60% of the bar) instead of a charge. A full bar buys one dash plus a short glide, or a long glide; a second dash needs a wind crystal or the ground.
- The bar shows a white notch at the dash cost. The player still turns pale blue when there isn't enough for a dash.
- Wind crystals and the ground refill the whole bar.
- **The gust spends breath too** (`gust_uses_stamina`, 0.3 s = 20% of the bar, a fainter notch on the bar). Ground gusts are effectively free, since the bar refills on the ground. Pressing gust without enough breath plays a small "fizzle" puff.
- Future elements: plan is **one bar per element, showing only the active element's bar**, rather than one global bar.

### 5.3 Gust (Z)
- Short-range blast (a cone ~40 px long; was 32) in the aimed direction. 0.6 s cooldown.
- **Recoil:** the player is pushed the *opposite* way (120 px/s). **On the ground** the sideways recoil is halved (`gust_ground_recoil_multiplier`) and braked by strong friction (`gust_ground_recoil_friction`), so you can knock an enemy off a platform without sliding off yourself. Gusting down mid-air acts as a small extra jump, up to **2 times per airtime** (`gust_down_boosts_per_airtime`, 0 = unlimited). It sets the upward speed, so it also works mid-fall. Several gusts per jump are allowed; cooldown and breath are the limits. **Wind crystals refill the down-boosts** too. A straight-down gust in the air with no down-boosts left is **ignored entirely** (no air), since it would do nothing; with hold-to-aim the preview turns gray.
- **Neutral gust (no arrow held):** a burst in *all* directions (circle, 28 px radius) that pushes everything nearby straight away from the player. No recoil: instead it is an **air brake**: for 0.2 s gravity is off and the player's speed slows toward a stop (a hard stop on the ground). Mid-air it is followed by a **float** (0.4 s): quarter gravity, fall capped at 25 px/s, full steering, so the player drifts down gently and is in control when it ends. Glide, dash and jumps can cut the float short.
- **Hold to aim (experimental, `gust_hold_to_aim`, on by default):** holding Z slows time (×0.25) and the arrows only aim (no steering), with a cone preview. Releasing Z fires; a tap fires almost at once; holding over 0.4 s real time fires by itself. This solves "running right, want to gust left". Off = the gust fires the instant Z is pressed.
- **Diagonal grace:** after aiming a diagonal, releasing one of its two keys still counts as the diagonal for 0.12 s (`gust_diagonal_grace_time`), so diagonals don't turn sideways when one key comes up a moment before Z.
- **Gust → glide:** pressing jump during the recoil starts a glide at once, and gliding keeps speed above run speed (it fades at 100 px/s², `glide_overspeed_deceleration`), so a side-gust or dash can launch a long, fast glide.
- **No damage.** The gust itself never hurts anything; damage comes from what it pushes things *into* (see §7).
- *Later (not Milestone 1):* with a second element, holding the bend key could open a slow-motion element wheel. With only Air, a wheel would have one option.
- Gust applies a push force to anything in the cone that is "pushable":
  - **Crates** slide (on ground) or are knocked (in air).
  - **Windmills** spin for 4 s, powering a linked door while spinning. A ring around the hub shows the time left.
  - **Leaf platforms** travel to the far end of their rail (any gust, from any side, always the same way), wait, then slowly drift home.
  - **Sail platforms** move along their rail in the gust's direction (only the part along the rail counts) and coast to a stop.
  - **Leaf piles** blow away (cosmetic, see §6).
  - **Enemies** are knocked back and stunned for 1.5 s.
  - **Projectiles** are reflected.
- **Movement:** down-gust as an extra jump; side-gust to adjust mid-air.
- **Puzzle:** move crates onto pressure plates, spin windmills, raise leaf platforms.
- **Combat:** knock enemies into spikes, reflect projectiles back at turrets.

---

## 6. Environment objects

| Object | Behavior |
|---|---|
| Solid tiles | TileMapLayer with collisions |
| Spikes | Instant death on touch (with a fair, slightly smaller hitbox) |
| Wind zone | Constant force in one direction while inside (horizontal currents or updrafts) |
| Wind crystal | Refills dash on touch; respawns after 2.5 s |
| Crate | Pushable box with its own simple physics (not a RigidBody): a gust slides it a predictable ~40 px. Can rest on pressure plates; player can stand on it. The player can't push it by walking, only with air. |
| Pressure plate | Active while something **heavy** (a crate) sits on it. The player doesn't count, so crate puzzles can't be skipped. |
| Windmill | Gust-activated timer (4 s, refreshed by each gust) that powers a linked door. Blades slow down over the last second as a warning. |
| Leaf platform | One-way platform on a visible **rail** (any direction, default 32 px up). Any gust sends it to the far end; it waits 1.5 s, then drifts home slowly. A pinwheel under it spins while the wind drives it. |
| Sail platform | One-way deck with mast and sail on a visible rail. Moves **in the wind's direction**: gusts shove it (only the part along the rail counts), wind zones carry it. Standing on the deck: sideways gusts have **no recoil** (the sail takes the shove, so you can blow your own boat) and wind zones don't push you along the deck. Decorative railings mark the deck ends. Jumping off keeps the sail's speed. |
| Leaf pile | Cosmetic mound of loose leaves drawn in front of other objects, so it can **hide a plate or a secret path**. Gusts blow away the leaves near you; the player or a crate moving through kicks them up. Leaves flutter down slowly, swinging left-right like a pendulum, land on any solid, ride along on moving things, fall again if their support goes away, and pop out if something slides over them. |
| Door | Opens/closes based on its linked switch(es): *any* or *all* of them, optionally inverted. Won't close on the player or a crate. |
| No-glide zone ("dead air") | Mauve, hatched rectangle with sinking specks. Gliding can't start inside it, and a glide that drifts in ends at once. Jump, dash and gust still work, so it turns a float-over into a dash or down-gust pass (rooms 2, 4, 5, 7). |
| Enemy gate | A switch that turns on once every enemy linked to it is defeated (room 5's exit). A row of pips shows each linked enemy: purple alive, green beaten. Resets with the room. |
| Goal | Green exit area in the last room. Touching it ends the run and shows the end screen (deaths, time). |
| Checkpoint / room entry | Player respawns at the last entered room's spawn point |

Linking: switches emit signals; doors listen. Links are set in the editor with exported node paths, so rooms can be wired by hand. In the editor, doors draw dashed lines to their switches.

**Room reset:** dying or pressing R puts every puzzle object in the room back to its starting state (crates, windmills, platforms, doors, leaf piles), so a misplaced crate can never make a room unsolvable.

---

## 7. Enemies (slice only needs two)

- **Wisp** — patrols back and forth on a platform; touching it kills the player. Gust stuns it for 1.5 s; dashing into a stunned wisp, or knocking it into spikes, defeats it.
- **Sentry** — stationary; fires a slow orange orb toward the player every 2 s when in line of sight (eye glows 0.4 s before each shot). Can hang from the ceiling (`mounted_on_ceiling`); with `can_fire` off it's a passive practice target. Gust reflects orbs (gold, 1.5× speed, harmless to the player); a reflected orb destroys a sentry or defeats a wisp. **Aim assist:** a reflected orb flies straight at the enemy closest to the gust's direction, within 45°, in the same room and in clear view.

Full enemy reference with animated drawings: `ENEMIES.html`.

**Impact rule (no HP):** the gust (and dash wake) deal no damage, only push. What a pushed enemy *hits* decides the outcome:
- slammed into a **wall** or solid → stunned longer (2.5 s instead of 1.5 s)
- knocked into **spikes** → defeated
- a **stunned** enemy hit by a dash → defeated

No health bars: every outcome is readable at a glance with placeholder shapes (pillar 4). Stage 8 builds this.

---

## 8. The 5 rooms

Each room teaches one thing, then tests it.

1. **"First Breath"** — run, jump, wall jump. Short gaps, one wall climb. No bending.
2. **"The Dash"** — gap too wide to jump; first wind crystal; ends with a crystal-chain over spikes.
3. **"Updraft"** — glide over a long pit; ride an updraft to a high exit; one horizontal wind current pushing against you.
4. **"Gust Works"** — puzzle room: gust a crate onto a plate to open a door; spin a windmill to hold a gate open while you dash through; raise a leaf platform to reach the exit.
5. **"Sentry Pass"** — combat room: two wisps over a spike floor and one sentry guarding the exit. Requires down-gust jumps, reflecting an orb, and a dash finish.

6. **"Sail Under Fire"** — ride a sail platform across a long spike pit, pushing it with your own gusts (no recoil on deck) while two ceiling sentries and a dock sentry shoot at you. Two **thorn crowns** (spiked pillars sticking up through the rail) block the deck: jump each one as the boat slides under it and land back on board.
7. **"The Gauntlet"** — the hard finale: race a windmill gate through a crystal chain in a head-wind, climb with down-gusts under sentry fire, slip past a wisp to the goal.

A simple end screen shows deaths and time (the goal is at the end of room 7).

---

## 9. Game feel checklist

- Squash and stretch on the player rectangle (jump, land, dash)
- Freeze frames on dash and on hitting an enemy
- Small screen shake (dash, gust, death)
- Dust particles on land and wall jump; dash afterimages; gust cone particles
- Death: quick burst of particles, 0.4 s, then respawn
- Sound is out of scope for Milestone 1 (but leave a single `play_sfx(name)` hook)

---

## 10. Out of scope for Milestone 1

Real art, music/sound, story, menus beyond pause/restart, save files, gamepad, other elements.

## 11. Later elements (leave room in the code, don't build)

- **Earth:** now specified in `Earth_bending.md` (its own chapter: column, boulder, snake) and planned as Stages E1–E7 in `PROMPTS.md`.
- **Water:** surf on streams, freeze water into ice platforms, water whip.
- **Fire:** jet boost, burn vines/obstacles, fireballs.

Design rule for all of them: same pattern as Air — each ability has a movement, puzzle and combat use. Abilities should be separate components the player can hold, so swapping or adding an element doesn't require rewriting the player.

---

## 12. Milestone 1 is done when

- All 5 rooms are beatable start to finish with no errors in the Godot output.
- Movement constants are tweakable in the Inspector at runtime.
- A friend who's never seen it can finish room 1 without explanation.
- Dying and respawning feels instant.
