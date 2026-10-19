# Earth Bending — Design Spec

Design spec for the **Earth chapter**. It describes *what* the moves do and how they should feel. *How* to build them is left to Claude Code, which knows the codebase (see §10).

Earth is introduced in its own chapter with its own rooms. Later puzzles may combine Earth and Air, so **Earth uses its own keys** and never reuses Air's.

All numbers are starting values to tune in playtesting. Put them in an `EarthTuning` resource (like `PlayerTuning`) so they can be tweaked in the Inspector.

---

## 1. The idea in one paragraph

Some surfaces have a layer of **earth** (brown-yellow). The player can only bend while **touching earth** (standing on it or wall-sliding on it). Bending sends a **shadow** crawling through the earth from the player's feet to a target spot, with gravel bursting along the way, so you can *see* energy travel through the ground. Each earth tile can be bent **once**. Used earth turns dark and can't be bent again until the room resets. Rooms become puzzles about *where* to spend the earth.

---

## 2. Earth tiles

| State | Color | Meaning |
|---|---|---|
| Fresh earth | brown-yellow | Can be bent |
| Used earth | dark brown | Already bent from, or a hardened creation. Can't be bent |
| Plain solid | dark gray (as in Air chapter) | Not earth, never bendable |
| Cracked wall | gray with crack lines | Breaks when hit by a boulder |

- Earth is a surface layer on platforms, walls and ceilings (1 tile thick is enough for now).
- Each tile tracks its own fresh/used state.
- **Room reset (death or R) restores everything**: tiles turn fresh again and all columns, boulders and snakes disappear.

---

## 3. Controls

| Move | Key |
|---|---|
| Earth Column | **A** |
| Boulder | **S** |
| Earth Snake | **D** |
| Aim / steer | Arrow keys (same as Air) |
| Cancel a bend in progress | **Jump** (C). Uses no earth |

---

## 4. Shared core: the bend shadow

All three moves start the same way. Build this once and share it.

1. **Start:** the player presses or holds the move's key while touching fresh earth.
2. **Slow motion:** the world slows to **0.3× speed**. The player is rooted in place in a bending stance.
3. **Shadow appears** under the player's feet (a dark oval on the earth surface).
4. **After 0.5 s (real time)**, the shadow crawls away at **60 px/s (real time)**:
   - On the floor or ceiling it goes in the direction the player is facing.
   - On a wall it goes up by default, or down if holding down.
5. **Path rules:**
   - The shadow follows **connected fresh earth only**.
   - It **wraps around corners** (floor → wall → ceiling), so a column can rise sideways or downward from places the player can't reach.
   - At a gap, a non-earth tile or used earth, it stops and waits at the last valid tile.
6. **Time limit:** the aim phase lasts at most **2.5 s (real time)**, then the move fires automatically at wherever the shadow is.
7. **Gravel FX** (see §8) run the whole time: at the player's feet, trailing along the shadow's path, and at the shadow itself.

Slow motion should slow enemies, projectiles and objects, but the shadow and the hold timer run in real time so aiming feels the same every time.

---

## 5. Move 1 — Earth Column (A)

**Flow:** hold A → shadow (§4) → **release A** → a column shoots out of the surface at the shadow's location.

- The column rises **perpendicular to the surface** it comes from: upward from floors, sideways from walls, downward from ceilings.
- Size: **1 tile wide × 3 tiles long** (8×24 px), rises in 0.1 s.
- **It's a bouncer, not a platform.** Anything touching any face of it is launched away from that face at **220 px/s** (fixed, like a Celeste spring). This applies to the player, crates, boulders and enemies.
- Bouncing off a column **refills the Air dash** (for later mixed puzzles).
- The column is drawn in used-earth color. The tile it rose from becomes used.
- The column stays until the room resets.
- **Quick tap:** releasing before the shadow starts moving (under 0.5 s) raises the column right under the player. This works as a self-launch, a "super jump."

**Movement:** self-launch, place springs on walls and ceilings to redirect yourself.
**Puzzle:** bounce crates and boulders to where they need to go; block a passage with a bouncer.
**Combat:** pop a column under an enemy to launch it into spikes.

---

## 6. Move 2 — Boulder (S)

**Flow:** hold S → shadow (§4) → **release S** → a boulder rips out of the earth and pops up → **press S again** to throw it.

- Size: **2×2 tiles** (16×16 px). It uses up the 2 earth tiles it rips from.
- Pop-up: launched away from the surface at **200 px/s** under normal gravity, so it reaches its peak about 0.2 s later.
- **Throw direction:** arrow keys (8 directions). With no arrow held, it goes horizontally in the facing direction.
- **Timing sets the throw quality:**
  - **Perfect window:** within ±0.08 s of the peak, the boulder flashes white so the player can read the timing. It fires at **320 px/s**, ignores gravity for **0.3 s**, then falls normally.
  - **Off-peak:** speed and gravity resistance shrink smoothly with distance from the peak, down to 180 px/s with normal gravity.
- **No throw:** if S isn't pressed again within 1.0 s, the boulder drops and shatters into gravel.
- Only **one boulder** can be in the air at a time.

**On impact:**

| Hits | Result |
|---|---|
| Fresh or used earth wall/ceiling | **Sticks** into it. Becomes a solid 2×2 ledge you can stand on and wall-jump from |
| Plain solid or another boulder | Shatters into gravel |
| Cracked wall | Breaks the wall, and the boulder shatters |
| Enemy | Knocks it back and damages it (a sentry is destroyed, a wisp is defeated) |
| Column | Bounces off (see §5) |

**Movement:** stick boulders into earth walls to build footholds.
**Puzzle:** break cracked walls, hit far switches, build a ledge to reach an exit.
**Combat:** ranged attack, with a big reward for perfect timing.

---

## 7. Move 3 — Earth Snake (D)

**Flow:** hold D → shadow (§4) → **release D** → a ribbon of earth emerges at the shadow and you **steer it with the arrow keys** → **press D again** → it hardens. (Changed in Stage E0 to match Column and Boulder, see §11.)

- **Steering:** the head moves at **80 px/s** on the tile grid and turns in 4 directions. It can't reverse back onto itself.
- **Earth budget:**
  - Each snake tile uses one fresh tile from the patch it emerged from. Those tiles darken outward from the emergence point, so you can see the earth being "pulled" out.
  - Maximum length is **12 tiles**, or less if the patch has less fresh earth.
- **It stops** when the budget runs out, the head hits something solid, or the steering phase reaches **2.5 s**. Then it hardens automatically.
- The world stays in slow motion while steering, and the player stays rooted.
- **While moving:** the head pushes crates and boulders and knocks enemies back.
- **After hardening:** it becomes a **solid, standable platform** in used-earth color that **blocks projectiles and enemies**. It stays until the room resets.

**Movement:** draw bridges, stairs and ledges.
**Puzzle:** route a path, wall off a hazard, push objects with the head.
**Combat:** shield wall against sentry orbs; ram enemies with the head.

---

## 8. Gravel & feedback (applies to all moves)

The goal is to *show energy traveling through the earth* from the player to the bend point.

- **At the player's feet:** small gravel bits pop off when bending starts, plus a slight crouch/squash in the bending stance.
- **Along the path:** as the shadow crawls, the tiles it passes shiver (a 1 px wobble) and drop a few gravel bits behind it.
- **At the target:** a bigger gravel burst plus a small screen shake when the column, boulder or snake erupts.
- **Impacts:** a boulder sticking or shattering, and a column bouncing something, each make a gravel puff.
- **Darkening:** used tiles fade to dark over about 0.2 s rather than snapping.
- Use one shared `spawn_gravel(position, amount, direction)` helper for all of these.
- Use placeholder squares only: 1–2 px earth-colored bits under gravity that fade out.

---

## 9. Chapter rooms (suggested)

1. **"Solid Ground"** — what earth looks like; column under yourself to reach a ledge.
2. **"Springs"** — place columns on walls and the ceiling to redirect jumps; shadow wraps a corner.
3. **"Stone Throw"** — boulders: break a cracked wall, then stick boulders into an earth wall to climb it. Teaches the perfect throw.
4. **"The Long Bridge"** — the snake: bridge a spike pit with a limited earth patch (you must plan the shape).
5. **"Spending Earth"** — combat and puzzle mix with too little earth for careless bending: sentry orbs blocked by a snake wall, a wisp launched into spikes by a column.

---

## 10. For Claude Code

- Treat this as the design source for Earth. Read it together with `CLAUDE.md` and `GAME_DESIGN.md`.
- **Plan before building.** Propose an implementation plan as sub-stages and append them to `PROMPTS.md` (and its Progress list) as `Stage E1`, `E2`, …. Suggested order:
  1. Earth tiles with fresh/used state, and room reset
  2. Shared bend core: slow motion, rooted stance, shadow crawl with corner wrapping, gravel FX
  3. Earth Column
  4. Boulder, including throw timing
  5. Earth Snake
  6. Cracked walls and enemy interactions
  7. The 5 chapter rooms
- Follow the same architecture as Air: each move is a separate ability component, and the shadow/targeting logic is shared by all three.
- Don't build anything from §12.
- If a rule here would feel bad in play or conflicts with existing code, say so and propose an alternative before building.

---

## 11. Decided in Stage E0

These rules were agreed when planning the build. Where they differ from the sections above, this list wins.

- **Keys:** the WASD movement alternates are removed, so A/S/D are free for Earth. Movement is arrows only.
- **Air in the Earth chapter:** rooms declare which elements are allowed. Earth rooms 1–5 are Earth-only (dash, glide and gust do nothing), so their puzzles can't be skipped with Air. Mixed rooms come later.
- **Shadow path:** the shadow travels along the exposed *faces* of earth tiles (a tile plus the side that touches open air). That's what lets it wrap inner and outer corners. A corner tile has two faces but one fresh/used state.
- **Shadow crosses everything solid** (changed after E2 play-test): it follows any surface, gray rock and used earth included, wrapping corners. It can only *erupt* from fresh earth: over gray or used tiles it's drawn pale, and releasing there (or timing out there) fizzles with no earth used. Gaps no longer stop it either: it wraps down into them.
- **Wall bends go down by default** (changed after E2 play-test): from a wall slide the shadow crawls down the wall, so you can raise something to land on. Hold Up to send it up.
- **Shiver** is a quick bright flicker of the tile, not a 1 px shift (the shift opened a 1 px gap to the background: a flickering black line).
- **Real time:** the shadow and the snake head move in real time, and are drawn every rendered frame, so they stay smooth while physics is slowed to 0.3×.
- **Cancel:** cancelling with Jump uses up that press, so the player doesn't also jump.
- **Column bounces:** the player goes into a `Launched` state with a short steering lock. Sideways launches get a small upward component, like Celeste's side springs; otherwise normal air control eats the 220 px/s within about 0.2 s.
- **Boulder pop:** on every surface the boulder eases out about 22 px, hangs briefly, then falls. The "peak" in §6 is that hang moment, about 0.22 s after the pop, so throw timing is the same from floors, walls and ceilings. Slow motion ends when S is released, and the throw is timed in game time. The player stays rooted until the throw or the 1.0 s timeout.
- **Boulder tiles:** a boulder uses the shadow's tile and the tile before it on the path.
- **Boulder impacts:** a thrown boulder sticks into *any* earth face, floors included. A boulder that's never thrown always shatters.
- **Snake controls:** hold D for the shadow, release D and the snake emerges and you steer it, press D again to harden it. It also hardens on its own when the budget runs out, the head hits something solid (or the player), or 2.5 s pass.
- **Snake speed:** 80 px/s in real time (at 0.3× game speed it would crawl at 24 px/s).

---

## 12. Ideas parking lot (not to be built yet)

Unconfirmed ideas go here so they're written down but not built.

- **Earth + Air combos:** gust pushes a resting boulder; dash through a column's bounce for extra speed; a gust-propelled boulder throw.
- Choosing the shadow's direction during the first 0.5 s with left/right instead of locking it to facing.
- Thicker earth layers that allow more bends, or taller columns.
- Boulders that land and rest (pushable, re-throwable) instead of shattering.
- Sand or mud variants of earth with different behavior.
