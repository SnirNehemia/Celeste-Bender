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
- Camera is **room-locked** like Celeste: each room is one screen (or scrolls inside its own bounds), with a quick slide transition between rooms.

---

## 3. Controls (keyboard only)

Mouse is not needed. Celeste-style 8-direction aiming with the arrow keys is more precise for a platformer than mouse aim, and it keeps one hand on movement, one on actions. Mouse aim can be revisited later for combat if it feels limiting.

| Action | Key | Notes |
|---|---|---|
| Move / aim | Arrow keys (WASD as alternate) | Aim direction for dash and gust = held arrows (8 directions) |
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

The player is a **state machine**: `Idle`, `Run`, `Jump`, `Fall`, `WallSlide`, `Dash`, `Glide`, `GustRecoil`, `Dead`.

---

## 5. Air abilities

Each ability lists its movement, puzzle and combat use.

### 5.1 Air Dash (X)
- Burst of 240 px/s in the aimed direction (8 directions; default = facing) for 0.15 s, ignores gravity during the dash.
- **1 charge**, refilled on touching ground or touching a **wind crystal** (floating green diamond that respawns after 2.5 s).
- Brief freeze frame (~3 frames) on dash start + small screen shake + afterimage trail.
- **Movement:** cross gaps, reach ledges, chain off crystals.
- **Puzzle:** dashing *through* a wind zone briefly doubles the dash distance.
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
- Future elements: plan is **one bar per element, showing only the active element's bar**, rather than one global bar.

### 5.3 Gust (Z)
- Short-range blast (a cone ~32 px long) in the aimed direction. 0.6 s cooldown.
- **Recoil:** the player is pushed the *opposite* way (120 px/s). Gusting straight down mid-air acts as a small extra jump — *once per airtime*.
- Gust applies a push force to anything in the cone that is "pushable":
  - **Crates** slide (on ground) or are knocked (in air).
  - **Windmills** spin for 4 s, powering a linked door/platform while spinning.
  - **Leaf platforms** float up a fixed distance, then slowly sink back.
  - **Enemies** are knocked back and stunned for 1 s.
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
| Crate | Pushable rigid-ish body; can rest on pressure plates; player can stand on it |
| Pressure plate | Active while something heavy sits on it; opens a linked door |
| Windmill | Gust-activated timer (4 s) that powers a linked door or moving platform |
| Leaf platform | One-way platform that rises when gusted, sinks back slowly |
| Door | Opens/closes based on its linked switch(es) |
| Checkpoint / room entry | Player respawns at the last entered room's spawn point |

Linking: switches emit signals; doors listen. Links are set in the editor with exported node paths, so rooms can be wired by hand.

---

## 7. Enemies (slice only needs two)

- **Wisp** — patrols back and forth on a platform; touching it kills the player. Gust stuns it for 1 s; dashing into a stunned wisp, or knocking it into spikes, defeats it.
- **Sentry** — stationary; fires a slow orange orb toward the player every 2 s when in line of sight. Gust reflects orbs; a reflected orb destroys the sentry.

---

## 8. The 5 rooms

Each room teaches one thing, then tests it.

1. **"First Breath"** — run, jump, wall jump. Short gaps, one wall climb. No bending.
2. **"The Dash"** — gap too wide to jump; first wind crystal; ends with a crystal-chain over spikes.
3. **"Updraft"** — glide over a long pit; ride an updraft to a high exit; one horizontal wind current pushing against you.
4. **"Gust Works"** — puzzle room: gust a crate onto a plate to open a door; spin a windmill to hold a gate open while you dash through; raise a leaf platform to reach the exit.
5. **"Sentry Pass"** — combat room: two wisps over a spike floor and one sentry guarding the exit. Requires down-gust jumps, reflecting an orb, and a dash finish.

A simple end screen shows deaths and time.

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

- **Earth:** raise pillars as platforms, throw boulders, break walls.
- **Water:** surf on streams, freeze water into ice platforms, water whip.
- **Fire:** jet boost, burn vines/obstacles, fireballs.

Design rule for all of them: same pattern as Air — each ability has a movement, puzzle and combat use. Abilities should be separate components the player can hold, so swapping or adding an element doesn't require rewriting the player.

---

## 12. Milestone 1 is done when

- All 5 rooms are beatable start to finish with no errors in the Godot output.
- Movement constants are tweakable in the Inspector at runtime.
- A friend who's never seen it can finish room 1 without explanation.
- Dying and respawning feels instant.
