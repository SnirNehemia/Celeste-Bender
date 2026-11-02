# Windbound: Water bending (Chapter 4)

*Spec v2, 26 Oct 2026. Replaces spec v1 (the scoop / pull / carry / frost-dart model), rewritten from the developer's prompt of 26 Oct 2026, which takes priority over v1 wherever they differ. Companion to `GAME_DESIGN.md` (core + Air), `Earth_bending.md` (Earth) and `Fire_bending.md` (Fire). Water is built **after** Fire: several combinations in §9 need Fire's grid, `Flammable` and hot updrafts. Every number marked* **(tune)** *lives in `WaterTuning` and is exposed in the live tuning menu (F5). Play-test decisions go in §16.*

---

## 1. The idea in one paragraph

Water is the element of **shaping something that flows**. Hold the water key and the world slows down: a faint blue ring appears around you, and you steer a **waterball** with the arrows anywhere inside it. Touch water with it and it **gathers** water and swells. Lift it **slowly** out of a pool and the water follows it up as a **water snake**, a living column still joined to the pool; lift it **fast** and it tears free. Let go of the key (or push the ball out of the ring) and the water **flies on by itself**, faster than you moved it, and from then on it is just water: it arcs, splashes, drips, runs downhill, fills dips and makes waves. Then the **freeze** key turns the water you last threw (or the water you're touching) into **ice**, in exactly the shape it had: a flying ball becomes a block, a flung snake becomes a curved slide, a pool becomes a skating rink. Water rooms are puzzles about *where water is, where you can move it, and what shape to freeze it in*. Because the water is **simulated**, it has to look and feel like real water, and the first build stages exist only to get that right (§6, §14).

## 2. Pillars check

| Pillar | How Water meets it |
|---|---|
| Movement first | Ice keeps your momentum (long jumps, slides, ramps), and frozen snakes are platforms you sculpt yourself: pillars, bridges, slides |
| One verb, three uses | The waterball, the snake and the freeze each have a movement, puzzle and combat use (§5) |
| Fail fast | R resets every body of water, all loose water, ice, mud, growth, steam and enemies |
| Readable | Water is **blue**, ice is **cyan-white**, mud is **glossy brown**, steam is **white**. The ball's size *is* how much water you hold. The ring shows your reach. Wet things look wet (darker, with droplets) |

## 3. Keys

### 3.1 The water keys

| Key | Action |
|---|---|
| **1** | **Water hands.** Hold: slow motion, the ring, steer the waterball with the arrows. Release: the water flies on (§5.1) |
| **2** | **Freeze.** While holding 1: freezes the water you hold into ice tiles, exactly as the ghost shows (§16 "Re-planned: grid ice"). With nothing held: a fizzle |

Action names: `water_hands` (1) and `water_freeze` (2), on **physical** keys like every other action, so they sit in the same place on any keyboard layout (QWERTY, AZERTY, Hebrew…). The top-row digits, not the numpad. **Jump cancels** a hold: the ball just drops (no throw boost) and you jump.

### 3.2 One row per element

The developer's idea, adopted: jump stays under one finger, and the other two fingers move **between rows, one row per element**. On a staggered keyboard, 1, Q, A, Z are one diagonal column and 2, W, S, X the next, so the two fingers simply slide up and down:

```
          left finger   right finger
Water     1 hands       2 freeze
Fire      Q fireball    W flame jet
Earth     A column      S boulder
Air       Z gust        X (free)
Jump      C  (index finger)   ·   Space (thumb)
```

Nothing clashes: 1 and 2 are unbound today, and Q/W (Fire) and A/S (Earth) stay put. Each row reads as one element, and the farther rows belong to the later chapters.

**My take (with one caveat):** it's a good map: it's easy to learn, one row per element is easy to remember, and it leaves X free for a future second Air key or the element wheel. The caveat is **reach**: with the index on C, the number row is about 3½ key widths away diagonally, so *holding* jump while pressing 1 or 2 is a stretch. It matters less than it sounds:
- **1 is never pressed together with jump.** It's held in slow motion, and jump cancels it.
- **2 is a single tap**, usually right after letting go of 1. Those are neighbouring fingers on one row: a quick roll.
- **Space stays a jump key.** With the thumb on Space, the fingers rest naturally on the 1–Q rows. It's the common PC-game grip (thumb on Space, fingers on 1–4), and it's the comfortable choice for Fire + Water rooms.

So: **keep C and Space both on jump, put Water on 1/2, change nothing else.** Two small flags: **Esc** (pause) and **Tab** (back to the editor while play-testing an editor level) are next to 1 and Q; an accidental press is harmless (a pause, or the editor), so no remap. If the reach still feels bad in play-test, the fallback is to try jump on **V**, which brings the hand one column closer to the middle (§16).

## 4. The water itself

### 4.1 Units
- **1 unit = 64 px² of water** (one 8×8 tile full). Every amount in this chapter (the ball, a snake, a pool, a puddle) is counted in units, and **water is conserved**: a unit taken from a pool is visibly gone from it, a unit thrown somewhere is there. The only exceptions are **sources and sinks** (§4.2), soaking (§8.2) and steam (§9.2).

### 4.2 Where water lives
- **Pools:** still water lying in a dip. Their surface makes waves (§6). Finite until reset.
- **Puddles:** thin pools on flat ground (thrown water that spread out). Same thing as a pool, just shallow.
- **Basins:** just dips with no water yet. No special object: any dip fills if water is put in it.
- **Streams:** water that really flows along a channel, fed by a **source** and drained by a **sink** (§7.4). Endless.
- **Waterfalls:** water really falling from a lip, also fed by a source. Endless.
- **Loose water:** everything in the air or running over a surface: drops, splashes, thrown balls, flung snakes, spills off a ledge.

### 4.3 No meter
There's no water bar and nothing to carry between holds: you hold water only while the key is down. The **ball's size** shows how much you hold. The freeze has only a short cooldown (§5.3), so Water needs **no HUD row**.

## 5. Moves

### 5.1 Water hands (hold 1): the waterball

**Hold**
- The world slows to **0.3×** **(tune: `hold_time_scale`)**. The ball and its steering run in **real time**, like the fireball aim.
- A **faint blue ring** of radius **56 px** **(tune: `control_radius`)** appears around you and moves with you: that's your reach.
- The **ball** appears at your hands (8 px in front of you). It starts **empty**: a small blue spark with no water in it.
- **Arrows steer the ball** at up to **90 px/s real time** **(tune: `ball_move_speed`)**, with a little acceleration and drag (`ball_accel`, `ball_drag`), so it feels like moving a weight of water, not a mouse cursor. Diagonals work.
- **You:** the arrows belong to the ball, so you don't steer. On the ground you stand still; in the air you keep your arc, slowed by the slow motion (like the gust aim) ⚠ confirm.
- Auto-release after **4 s real time** **(tune: `max_hold_time`)**, so the slow motion can't be held forever ⚠ confirm.

**Gathering**
- When the ball is **within 6 px of water** **(tune: `gather_reach`)** (a pool's surface, inside a pool, a puddle, loose drops, a stream, a waterfall), water flows into it at **6 units/s real time** **(tune: `gather_rate`)** up to **4 units** **(tune: `ball_max_units`)**. A short tendril joins the ball to the water while it gathers.
- The pool **loses exactly what the ball gains**: its level drops and the surface dips toward the ball, rippling outward.
- **Streams and waterfalls never run dry**; gathering from them costs nothing.
- The ball's **size grows with the water** it holds (its area is the volume: 4 units is a ball about 18 px across, about the player's height). It wobbles, sloshes when it changes direction, and sheds a few drops when moved fast.
- An empty ball released does nothing (a small fizzle of sparkles).

**The water snake** (raise it slowly)
- If the ball is **lifted out of water while still gathering** and rises **no faster than 40 px/s** **(tune: `snake_max_rise_speed`)**, the water **follows it up**: a column of water joins the ball to the surface. That's the **water snake**.
- The snake is **6 px thick** **(tune: `snake_width`)** and keeps drawing water from its source to fill its length (1 unit per ~11 px), so the pool keeps dropping while it rises. It bends like a rope as you steer the ball sideways, and its foot slides along the surface to stay under it, dragging a wave.
- It **tears** (pinches into drops that fall back) if you lift **faster** than the limit, if the pool runs out of water, or if the snake hits its length limit (the ring sets the reach). After a tear, the ball is just a ball: it no longer gathers from that pool until it touches water again.
- From a **waterfall or stream** the snake is endless: it never drains anything.
- **While held, the snake is water you can steer:** its head **shoves** crates, leaf piles, wisps and floating things, **douses** fires it sweeps through, **kills cinders** and **absorbs orbs**. You can't stand on it (it's water) until you freeze it.

**Release** (let go of 1, or the ball leaves the ring)
- The world returns to normal speed. The water keeps the **velocity it had while you steered it, times 2.5** **(tune: `throw_multiplier`)**. It was moving in slow motion, so without the boost a throw would look feeble.
- So **steering the ball fast out of the ring is a throw**, and the ring edge is where it leaves your hands. A ball that wasn't moving just **drops**: that's how you pour water onto a spot.
- A **snake** is released as a **ribbon** (changed in play-test 4, see "Decided in Stage W4"): its water flows out after the ball along the ball's own arc. Its foot stays in the pool and falls back in.
- From the moment it's released, it's **loose water** (§6): it arcs under gravity, splashes, wets what it lands on, fills dips, runs downhill.
- **Jump** while holding: the ball drops in place (no boost) and you jump.

**Uses**
- **Movement:** the water is the material for your ice (§5.3, §7); move a pool's water to where you need ice.
- **Puzzle:** move water from pool to pool: fill a basin to float a crate up to a ledge, drain a pool to uncover a passage, fill a water scale, spin a waterwheel, soak a plant, wet a floor into mud.
- **Combat:** a thrown ball knocks back and wets enemies; a snake sweeps them off ledges; any water **kills cinders**; the held ball and snake **block orbs** (each orb costs the ball 1 unit and fizzles).

### 5.2 What "slowly" means (the snake rule, worked through)
- At 0.3× world speed, 40 px/s real time is about the speed of a gentle hand-lift. A full 56 px snake takes about 1.4 s real time to raise, the same as aiming a careful fireball.
- Tearing is shown before it happens: as the lift speed nears the limit, the snake's neck **thins** and drips, so you learn the speed by eye.
- Sideways speed doesn't tear the snake (only rising does), so you can sweep it fast once it's up ⚠ confirm in play-test.

### 5.3 Freeze (tap 2)

> **Refined in the W5 planning (§16 "Decided in Stage W5"):** rules 3 and 4 below became an **ice crystal**: with nothing held and no live throw, 2 throws a crystal (tap: at once in the arrow direction; hold: aim in slow motion) that freezes the first water it touches. Rule 2 applies only while the throw is LIVE (≤ 1.5 s old, at least half still loose), shown by frost glints and a ring over your head. Frozen balls keep their momentum; a pool freezes over a stretch around the hit, not whole. Wet-tile ice waits for W8.

The freeze picks its target in this order:

| # | When | Freezes |
|---|---|---|
| 1 | You're **holding** water (1 is down) | The **ball or snake you hold**, in place, and ends the hold. ⚠ Added in this spec (not in the prompt): it's the precise way to build an ice pillar from a snake. Drop it if it makes rule 2 pointless |
| 2 | The water you **last threw** still has loose, unfrozen water | **All of it**, wherever it is now and in its current shape |
| 3 | Otherwise (the last throw is already frozen, or all of it has merged into a pool or soaked in) | The **water you're touching**: the pool or puddle you stand or swim in, the stream or waterfall you're inside, a wet tile under your feet |
| 4 | Nothing to freeze | A small frost puff, no effect |

- **No cost**, cooldown **0.25 s** **(tune: `freeze_cooldown`)**. Ice is limited by the ice cap (§7.3), and above all by how much water you can get to.
- **Which shape the ice takes:**

| Frozen water | Becomes |
|---|---|
| **Compact** (a ball, a splash, anything ≤ 16 px across **(tune)**) | An **ice block** that **falls** and behaves like a crate (§7.3) |
| **Long** (a snake, a flung arc, a stream of drops > 16 px) | A **static ice shape**, staying where it froze: a pillar, a bridge, a **curved slide** (§7.2) |
| A snake whose foot is still in its pool (rule 1) | A **pillar** standing in the pool, with a small ice collar on the surface |
| A **pool** you touch | An **ice sheet** over its whole surface, 8 px thick **(tune)**; the water below stays water. If you're swimming in it, you're lifted to stand on the new ice ⚠ confirm |
| A **puddle** or **wet tile** you touch | An **ice patch**, spreading along connected wet tiles up to 16 tiles **(tune: `freeze_surface_reach`)** in a quick wipe |
| A **stream** or **waterfall** you're inside | The stretch of it within 48 px of you **(tune)**: a frozen stream stops flowing there (the water backs up behind it); a frozen waterfall becomes an **ice column** with wall-jumpable sides (no cling) |
| Thrown water **clinging to a wisp** | The wisp, in an ice block (§10) |

- **Melting** (any flame, §9.2) gives the water back as loose water: an ice block collapses into a splash, a slide rains down in drops, a sheet sinks back into its pool. Conservation holds: the pool you drained to build a pillar refills when the pillar melts into it.
- **Movement:** freeze a thrown ball in the air and land on the block, freeze a flung arc into a slide over spikes, freeze a snake into a pillar to climb, freeze a pool and long-jump off it.
- **Puzzle:** ice is a commitment: frozen water can't be gathered. Freezing a stream dams it; freezing a waterfall cuts what it feeds.
- **Combat:** freeze the water on a wet wisp to trap it; ice blocks stop orbs.

### 5.4 Swimming
- **The water resists you, in proportion to how much of you is in it** (the submerged share of your hitbox, 0..1, the same number floating crates use). Run speed is multiplied by `1 − water_resistance × share` (start 0.4 **(tune)**: ankle-deep is nearly full speed, chest-deep about 70 %, fully under 60 %, about 54 px/s). A jump from the bottom is weaker the deeper you stand (`1 − water_jump_loss × share`, start 0.5 **(tune)**).
- **Swimming:** once the water is over your head (share 1), you swim: gravity 240 px/s², max sink 50 px/s **(tune)**. Every **Jump** press is a stroke that sets your upward speed to `swim_stroke_speed` (80 px/s, about 13 px per stroke **(tune)**), so tapping jump again and again swims you up. At the surface, jump leaps out with a full jump. No breath meter. Under an ice sheet you can't surface: find an open edge or a hole.
- Your body **pushes the water**: jumping in makes a splash and a wave, swimming leaves a wake. That's the simulation, not an effect.
- You can **hold water while swimming**: the ball starts inside the water and fills at once.
- **Currents:** real flow in a stream carries you along (its speed scaled by `current_push`, start 0.6 **(tune)**). Waterfalls push you down.
- **Off underwater:** the flame jet sputters and the fireball fizzles while you're submerged. The gust works but is weak (half strength) ⚠ confirm.

## 6. The water simulation

This is the heart of the chapter, so it's specified before any move is built (stages W1–W2, §14). **Goals:** waves that travel, bounce off walls and settle; water that runs downhill, spreads into puddles and levels out between connected dips; drips, splashes and spills that fall as streams; every unit accounted for. **Constraint:** it's GDScript, at 60 physics frames a second, in a game that already spends a few ms a frame on fire.

### 6.1 Three forms of water, one budget

Water moves between three forms. Each form uses the cheapest model that still looks right for it:

**1. Bodies: pools, puddles, streams (a height field)**
- A body is a horizontal run of **columns 2 px wide** **(tune: `column_width`)** over its floor. Each column stores its floor height, its water depth and the flow through its two sides.
- Update rule: the **virtual pipe model**. Each pair of neighbouring columns is joined by a "pipe" whose flow speeds up with the difference in their surface heights and is slightly damped. Depths change by the net flow, never below zero. This one rule gives **waves** that travel and reflect, water that **runs down steps and levels out**, and exact volume bookkeeping. It's the standard shallow-water trick for games, and it's cheap: a full-room-width body is 160 columns.
- On top of it, a light **ripple layer** (the classic spring chain along the surface line) adds the small, fast ripples from drops and swimmers, so the bulk model can stay coarse.
- **Spilling:** where a column's neighbour is a drop (its floor more than 6 px lower **(tune: `spill_drop`)**) or a body's end, the outflow becomes **loose water** at the lip: water you see pour over the edge.
- **Puddles stop spreading** at a minimum depth of 2 px **(tune: `puddle_min_depth`)** (surface tension). So 4 units thrown onto a flat floor spread about 128 px: a natural ice runway once frozen.
- Bodies **merge** when their surfaces meet and **split** when a column runs dry. A body whose flows are all below a small threshold **sleeps** and costs nothing until something touches it.
- **Things in the water:** anything entering, moving in or leaving a body pushes its columns (displacement), so a falling crate makes a wave and a swimmer leaves a wake. Floating things read the local depth and slope for buoyancy (§8.5).

**2. Loose water (particles)**
- Each particle is a little packet of **1/16 unit** **(tune: `particle_units`)**: position, velocity, age. Gravity, light air drag, and collision against the room's solid tiles through a **grid lookup** (not physics bodies), plus a short list of moving solids (crates, columns, ice blocks, the player) as boxes.
- **Cohesion:** particles within 4 px pull gently together and slightly match their neighbours' speed (viscosity), found through a spatial hash with 4 px cells. That's enough for a thrown ball to stay round, a flung snake to stay a rope that **thins and breaks into drops** when stretched, and spray to bead. It has **no pressure solve**, the expensive part of a real fluid simulation: water that has landed stops being particles.
- **Landing:** a particle that touches a body's surface **merges** into it (its volume goes into that column, plus a wave kick where it hit). One that comes to rest on bare ground **starts or joins a puddle**. One that hits a dry absorbent tile **soaks in** (§8.2).
- **Cap:** at most **400 particles** per room **(tune: `max_particles`)**. Near the cap, splashes spawn fewer, bigger drops and the slowest particles merge into the nearest body first. The player never sees water vanish.

**3. Held water (the ball and the snake)**
- Not particles while held. The **ball** is one object (position, velocity, units), drawn as a wobbling blob. The **snake** is a short rope of 8–16 points (verlet) from its foot to the ball, with water per unit of length.
- On release, both are **converted into particles** carrying their velocities times the throw boost.

### 6.2 Sources, sinks and flows
- A **source** adds water at a fixed rate (units/s) into a body or as falling particles at a lip. A **sink** (a drain grate, or the room edge) removes it. Streams are bodies on a long or stepped channel with a source upstream and a sink or spill downstream, so their current is real flow. Waterfalls are particles from a lip to whatever is below.
- **Waterfall cost is bounded:** particles in a waterfall = rate × fall time. Long falls use fewer, bigger particles drawn stretched (`waterfall_particle_scale`) to stay under the cap.

### 6.3 Drawing it
- **Bodies:** one filled polygon per body along its column tops, a lighter surface line, foam where the flow is fast or a wave breaks.
- **Particles, ball and snake:** drawn as soft dots into one low-resolution `SubViewport`, then a **threshold shader** merges overlapping dots into smooth blobs with a crisp pixel edge and a lighter rim (2D "metaballs"). In the same colors as the bodies, so a ball landing in a pool reads as one water, and a drop pinching off a snake looks like water, not a sprite. One draw call, cheap on the GPU, skipped in headless runs.
- **Fallback** if the shader misbehaves in the web export (the project uses the Compatibility renderer): plain 2 px dots, no merging.

### 6.4 Time and slow motion
- The simulation runs in `_physics_process` with a fixed step (2 sub-steps for bodies, 1 for particles **(tune)**), on the world's scaled time, so slow motion slows the water too, while the ball you steer runs in real time. Fixed steps keep headless tests repeatable.

### 6.5 Cost: what's heavy, and what this design does about it

**Budget:** the whole water simulation must stay under **2 ms per physics frame** in the worst test room on this machine (for scale: Fire's heaviest room measured 3.85 ms a frame for everything). Stage W1 adds a performance section to the smoke test that prints the water's ms per frame under a fixed stress test and **fails over budget**, so this is checked from day one, not discovered in room 9.

| | What | Cost | Decision |
|---|---|---|---|
| 🔴 | A real particle fluid (SPH / FLIP / PBF) for all water | Thousands of particles with a pressure solve every frame: roughly 10–50 ms a frame in GDScript | **Not used.** Still water is a height field, which costs almost nothing, and sleeps when calm |
| 🔴 | One node, `RigidBody2D` or `Area2D` per droplet | Node overhead per drop, and drops that behave like marbles | **Not used.** One `WaterWorld` node per room owns all water in packed arrays and draws it all |
| 🟠 | Particles with cohesion | Grows with particles × neighbours; the main risk | Capped at 400, spatial hash, one cohesion pass. If GDScript can't hold 400 in about 1 ms: lower the cap first; then, only if needed, move the particle loop to a compute shader or a small C++ GDExtension (that adds a build toolchain, so it's the last resort) |
| 🟠 | Waterfalls and streams that never stop | Particles are spawned forever | Bounded by rate × fall time; stretched particles on long falls |
| 🟠 | Several rooms simulating at once | Cost × rooms | Only the current room (and the one you're entering) simulates. This ties into the "freeze far rooms" work already in the game |
| 🟡 | Metaball rendering | One extra viewport + a shader; GPU work, not CPU | Fine; check it in the web export (fallback in §6.3) |
| 🟡 | Solid-tile lookup for particles | A grid built at room load | Rebuilt only for the tiles that change (Earth columns, cracked walls, new ice) |
| 🟡 | Freezing into collision shapes | Building a polygon | Once per freeze; ice cap 6 |
| 🟢 | Height-field bodies | About 160 columns per room-wide body, a few multiplies each | Cheap; sleeps when calm |
| 🟢 | Wetting tiles | A grid write when water lands | Cheap |

## 7. Ice

> **Re-planned again (§16 "Re-planned: grid ice", 31 Oct 2026, Stages I1–I5):** freeze only what you hold; ice is tiles on the grid (the ball a block, the snake lines, a waterfall a wall, a ball at a surface a raft on any water); a ghost shows the result first; ice hanging in mid-air crumbles after a touch; ice keeps your speed. That entry overrides everything below.
>
> **Re-planned (§16 "Re-planned: predictable ice", 28 Oct 2026):** ice hangs exactly where it froze; the snake is a trail snapped to 0/45/90°; slides come from trails and painted slope tiles; pins are gone; rafts carry you over black water. That entry overrides §5.3's shape table, §7.2's "frozen snakes and flung arcs are curved" and §7.3's block behaviour where they disagree.

### 7.1 Ice surfaces
Starting values, all **(tune)**:

| Property | Ice | Notes |
|---|---|---|
| Ground acceleration | ×0.15 of normal | Slow to start, slow to turn |
| Ground friction | ×0.08 of normal | You keep sliding after release |
| Speed cap on ground | **not applied** while above run speed | Momentum from a flame jet, an Earth launch or a slope is kept |
| Jump | keeps full horizontal speed | **Long jumps** off ice are the signature move |
| Ice walls | wall slide ×2, no cling | Wall jumps still work |

### 7.2 Ice slides (the first slopes in the game)
- Frozen snakes and flung arcs are **curved**, so this is the first time the game has slopes. Slopes exist **only as ice**.
- A slide is a 4 px thick polyline along the frozen water. **Your own ice slides are one-way** (solid from above, pass through from below and the sides) so they never trap you. Pillars and ice blocks are fully solid.
- **New player state `Sliding`:** on a slide you follow its slope; gravity pulls you along it (`g · sinθ · slide_gravity_scale`, start 1.0 **(tune)**), with ice friction. Arrows lean slightly (±40 px/s² **(tune)**). You can't walk up an ice slope steeper than 15° **(tune)**; you slide back down.
- Jumping off a slide keeps your velocity. A slide that curves upward at its end is a **ramp**: you launch off the lip.

### 7.3 Ice objects and limits
- **Ice block** (a compact frozen shape, its size from its water: 1 unit ≈ 8×8): standable, pushable (gust, Earth snake, crates), slides far on ice, **floats** on water and rides currents (a raft), blocks orbs. Shatters when a big rock hits it or it falls 4+ tiles **(tune)**, into loose water.
- **Ice cap:** at most **6** pieces of player-made ice per room **(tune: `max_player_ice`)**. Making a 7th melts the oldest with a visible drip-and-crack (its water comes back as loose water). Ice placed in the level doesn't count.
- **Look:** pale cyan with white streaks, a glint that slides along it as you move, white skid sparks when you change direction. Ice over water keeps a faint blue tint below.

## 8. Materials and objects

### 8.1 Water in a level

| Placed in the editor | Behavior |
|---|---|
| **Water** (painted per tile) | Becomes a body at room load; the level settles flat in the first frames |
| **Source** | Endless water at a rate, at a point or along a lip (streams, waterfalls) |
| **Sink** | A drain grate: removes water that reaches it |
| **Ice** (painted) | Level ice; doesn't count toward the cap; melts into water |

### 8.2 What water does to each tile (the wet layer)

Water that lands on a tile changes it. **Absorbent tiles soak water in**: each takes up to 0.25 unit **(tune: `soak_per_tile`)** before it's wet, then water runs over it like rock. So a small throw soaks into a lawn; a big one wets it and puddles.

| Tile | Wet result | Details |
|---|---|---|
| **Fresh / used / hardened earth** | **Mud** (fresh mud stays bendable once; used mud stays spent) | Sticky floor and walls, mud rocks (§9.1). The Earth shadow crosses mud |
| **Grass** | **Wet grass**, which **grows into tall grass** in 0.8 s **(tune)** | Won't burn while wet (§9.2). Tall grass hides you and objects (§8.3) |
| **Ash** (from Fire) | **Wet ash** (gray-black sludge) that **sets into ashstone** after 2 s **(tune: `ash_set_time`)** | Ashstone acts like gray rock: solid, never burns, **blocks the Earth shadow**. Freeze wet ash before it sets and it's ice instead |
| **Thicket** | **Wet thicket** that grows a **branch** (§8.3) | Won't burn while wet |
| **Gray rock, ashstone, crates, metal** | Not absorbent: water **puddles** on them | Freezes into an ice patch |
| **Burning anything** | **Doused** (§9.2) | Often makes steam |
| **Ice** | Nothing (water runs off) | |

- **Wet things stay wet until reset**, but **heat dries them**: a direct flame (fireball, flame jet plume, bonfire, a burning vine monkey, a cinder) touching a wet tile dries it in a puff of steam **instead** of igniting it. The next flame ignites as usual. Fire **spreading** from a neighbor does **not** dry wet tiles, so a wet line is a firebreak.
- Dried tall grass stays tall.

### 8.3 Plants: water makes things grow

| Plant | Watered (per unit landing on it) | Uses |
|---|---|---|
| **Tall grass** (grown from grass) | Grows 16 px tall in 0.8 s | **Hiding:** while you're on the ground inside tall grass, **sentries can't see you**. **Hides objects:** authored tall grass can hide diamonds, plates or seeds; it parts as you walk through and lies flat for 1 s under a gust. **Slows you** to ×0.8 run speed **(tune)**. **Burns bigger** once dry: 16 px flames, burn time 1.4 s **(tune)** |
| **Vine** (from Fire) | Grows **16 px longer** **(tune)**, up to its authored max | Lowers whatever it holds (a plank, a crate), or reaches down to a lower ledge. Still a rope, not a ladder |
| **Seed: stalk** (new) | A stalk grows **24 px up** (max 2 units) **(tune)**, with a leaf pad on top | A slow-rising platform: it lifts you gently. Flammable |
| **Seed: lily** (new, on water) | A **lily pad** 16 px wide opens on the surface | Floats, rides the waves and the level, drifts with currents. Standable. Flammable |
| **Thicket** (from Fire) | Grows a **branch** straight out of the face the water hit, **1 tile per unit**, max 4 **(tune)** | Hit a side face → a horizontal bridge. Hit the top → a wall grows up. Solid; Fire can burn it later |

Growth needs water to **land on** the plant: a thrown ball, a dropped ball, a snake swept over it, a waterfall, melting ice dripping on it. A plant at its max ignores more water.

### 8.4 New objects

| Object | Behavior |
|---|---|
| **Waterwheel** | Spins while water (falling particles or a stream's flow) hits its paddles, and holds its door open. When the water stops, it winds down and the door's timer starts (like the windmill). Turned by a waterfall, a thrown ball (a short spin) or a stream led onto it |
| **Steam turbine** | A bladed wheel in a metal housing. **Only steam spins it** (§9.2). Spins up and opens its linked door for N seconds **(tune)**; a steady steam column keeps it spinning. Often out of reach |
| **Water scale** | A cup on a spring. Sinks and presses like a pressure plate while it holds **2+ units** **(tune)** of water or ice. Fire evaporating its water lifts it again |
| **Drain grate** | A sink (§8.1). Can be opened or closed by a switch: empty a pool on a switch |
| **Seeds** (stalk, lily) | See §8.3 |

No pipe or basin objects: with real flow, a pool **connected under a wall** shares its level by itself, and any dip is a basin.

### 8.5 What floats
Crates, ice blocks, lily pads, leaf platforms and loose leaf piles **float**, bob on the waves and drift with currents. Rocks, Shells and the player don't (the player swims). A floating thing pushes the water as much as it weighs, so a crate dropped in a narrow pool raises its level a little. Implemented as a `floatable` group with a buoyancy hook that reads `WaterWorld` depth and slope.

## 9. Element combinations

### 9.0 Transformation map

```
earth  --water--> mud        --heat--> earth
grass  --water--> tall grass (wet) --heat--> tall grass (dry) --fire--> big fire --> ash
ash    --water--> wet ash    --2 s--> ashstone (blocks the Earth shadow, never burns)
water  --freeze--> ice       --fire--> water
fire   --water--> doused + steam
steam  --> lifts gliders; spins turbines
```

### 9.1 Water + Earth

**Mud** (wet earth)
- **Sticky floor:** run ×0.5, jump height ×0.65 **(tune)**. Landing on mud **kills any momentum** at once: the brake at the end of an ice runway.
- **Sticky walls:** on a mud wall you **cling without sliding** for as long as you hold toward it. Wall jumps still work. You can't climb up or down on mud: you stay put, or let go and fall or jump off.
- Frozen mud is ice (slippery). Heat dries it back to earth.

**Mud as a way to change the level** (decided in the mud-walls refinement, 27 Oct 2026)
- Water is how you make **earth walls passable**. Any smooth earth wall that would normally make you slide down becomes a **resting spot**: wet a patch of it and you can stop on it, catch your breath and wall-jump from it.
- **Which tiles:** any dirt tile (fresh, used or hardened earth, §8.2). Gray rock, ashstone, crates and metal never become mud, so authors decide where mud is allowed by their choice of tile.
- **How far it spreads:** only the tiles the water touches. A ball wets the wall tiles of its splash area and no others, so you **paint a path** with your aim: a ball too small to reach the next ledge leaves a gap you have to cover with a second throw. Mud does not spread along connected earth and does not trickle down a wall.
- **Typical use:** a tall earth shaft with no ledges is climbed by wetting a few patches one above the other and wall-jumping between them. Wet only the floor of a pit and the mud slows you, so wet the wall and not the floor.
- **How long it lasts:** until reset, like every wet tile (§8.2). A direct flame dries it back to earth (puff of steam). Freezing mud makes it ice, which is slippery and has no cling (§7.1). There is no timer: mud never dries on its own.
- **Readable:** a mud tile is glossy brown and drips slowly (§12), and you leave hand prints where you cling, so you can tell at a glance which wall is climbable.

**Mud rocks** (the boulder key S on a mud tile)
- Brown, dripping. They **stick to anything** they hit: gray rock, walls, ceilings, ice, crates.
- They **do no damage**. They **gum enemies up** for 4 s **(tune: `mud_stick_time`)**: walking enemies are stuck in place, sentries are clogged (no orbs), **cinders are smothered and die**.

**Other** (most of these come free from the simulation)
- An Earth **column rising in a pool** pushes the water aside: the level rises and a wave runs out.
- A **hardened snake across a stream** dams it: the water backs up behind it and spills over or fills the dip behind.
- A rock thrown into a pool **splashes** (real particles: it wets what the splash lands on).
- A rising column under an ice block launches it.
- The Earth shadow crosses mud and ice but **stops at ashstone**.
- **Shells sink** and walk along pool floors. On ice they can't stop at ledges, so they slide off.

### 9.2 Water + Fire

**Douse** (water touching fire)

| Fire | Doused |
|---|---|
| Burning grass / thicket / tall grass | Out; becomes the **wet** version. A small steam puff (24 px, 0.5 s) |
| **Bonfire** | Out; a smoking **wet leaf pile** (needs one flame to dry, then another to relight). A big **steam burst** |
| Burning crate | **Charred wet crate** (solid, usable) |
| Burning vine | Stops; the burnt part is gone |
| Burning vine monkey | Snuffed, stunned 1 s, then carries on (as in `Fire_bending.md` §5.4) |
| **Brazier** | **Goes out**, and its door closes ⚠ confirm |
| **Cinder** | **Dies** (§10) |

**Steam** is fast-moving clusters of hot vapor. Harmless to you.
- **Steam burst** (water onto a bonfire, or onto 3+ burning tiles at once): a jet of puffs shooting **up 64 px** for 1.2 s **(tune)**. A **hot updraft** while it lasts (lifts gliders) that **spins any turbine** in its path.
- **Steam shot** (a fireball flying **through loose water**: a thrown ball, a flung snake, a waterfall): the fireball spends up to 1 unit of that water and leaves as a **steam shot** (260 px/s, range 160 px **(tune)**) in its direction. It ignites nothing; it **spins turbines from afar**, shoves light objects and dries wet tiles it crosses. A fireball through a *small* splash just goes out in a puff.
- **Jet over water:** the flame jet's plume touching a body raises a steam column while it touches + 0.5 s, and boils off 1 unit per 0.5 s ⚠ confirm.

**Fire melts ice**: any flame touching ice turns it back to loose water (§5.3). The flame jet carves through ice.

### 9.3 Water + Air
- A **gust over a pool** pushes its surface: a real wave runs across and shoves floating things.
- A gust **pushes loose water** (it's particles): it sprays a ball wide, bends a falling stream, slides ice blocks.
- A gust **bends a steam column** sideways: aim steam at a turbine.
- **Gliding** over steam lifts you.

### 9.4 Three or four elements (summit and mixed rooms)
- Burn a grass run (Fire) → wet the ash (Water) → it sets into ashstone → the Earth shadow can't cross there, so it must go the long way round.
- Wet earth into mud (Water) → tear a mud rock (Earth) → stick a sentry shut → glide past (Air).
- Douse a bonfire (Water) → steam burst → glide up on it (Air) → a gust bends it onto a turbine.
- Raise an Earth column in a pool to lift its level up to a ledge, then freeze the surface to run across (Earth + Water).
- Water grass into tall grass, hide from a sentry, then let a cinder walk into it once it's dry: a big fire that clears the thicket ahead.

## 10. Enemies

### 10.1 Cinder (home: **Water**)
Completes "one enemy per element that only its element kills".

- **Look:** an 8×7 lump of coal with glowing orange seams and a small flickering flame crown. It moves in short hops and sheds sparks.
- **Behavior:** patrols at 40 px/s **(tune)** and kills on touch. **It ignites flammable things it touches**, so in grassy rooms it leaves a burning trail: a walking fuse you don't control.
- **It fears water:** it turns around at wet tiles, puddles, mud and ice. A wet line is a fence.
- **Only water kills it:** a ball, a snake, a waterfall, a mud rock, falling into a pool. It dies with a hiss and a **steam puff** (a small steam burst that can nudge a turbine).
- **Everything else fails:** fire feeds it; spikes and column crushes don't hurt it; rocks knock it back; a **gust flares it** (×1.5 speed for 1 s, igniting everything along the way).
- **Puzzle use:** fence it with water, or **use it** as a fuse to burn thicket, then kill it.

### 10.2 All enemies against Water

| | Wisp | Sentry | Vine monkey | Thicket elephant | Shell | **Cinder** |
|---|---|---|---|---|---|---|
| Thrown ball | stunned 0.5 s + **wet** | doused 3 s (no orbs) | knocked back, wet (won't burn) | wet (won't burn), not moved | nudged | **dies** |
| Snake (held) | pushed far | doused while touched | pushed | not moved | nudged | **dies** |
| Freeze | in an ice block **if wet** | its orbs, if wet | nothing | nothing | nothing | dies (it was already in water) |
| Mud rock | stuck 4 s | clogged 4 s | stuck 4 s | stuck 4 s | stuck 4 s | **dies** |
| Deep water | **dies** (can't swim) | n/a | floats, swims to shore | wades, half speed ⚠ | sinks, walks the floor | **dies** |
| Fire | dies | dies (fireball) | **dies (torch)** | burns (as in Fire) | immune | immune |
| Big rock | dies | dies | knocked back | pushed back | **dies** | knocked back |

- **Frozen wisp:** a wisp in an ice block is harmless and pushable. Push it into spikes or drop it 4+ tiles to shatter it, which defeats it. Fire thaws it out.
- Orbs that fly through loose water get wet; the next freeze (rule 2 or 3) can freeze them mid-air, and they drop and shatter.

## 11. Player
- **New states:** `WaterHolding` (slow motion, ball steering; on the ground you stand, in the air you keep your arc), `Swimming`, `Sliding` (ice slopes).
- **Hazards:** water isn't a hazard. Spikes under water still kill. Steam is harmless.
- **Momentum on ice** carries into every move: jumps and jets launched from ice keep their speed.

## 12. The look: water must feel alive

Placeholder rules still apply (shapes, lines, particles, one color family per type). With the simulation (§6) most of "alive" comes for free: real waves, real drips. The look's job is to make it readable and pretty.

### 12.1 Palette (water family)

| Use | Color |
|---|---|
| Deep water | `#1F4E8C` (88% cover at 48 px deep) |
| Water body, ball, drops | `#2F7FD1`, 45% cover at the surface (what's behind shows through) |
| Surface line / foam / blob rim | `#BFE4FF`; foam and spray near-white `#F2FAFF` |
| Control ring | `#7FC8FF` at 25% alpha |
| Ice | `#A9F0FF` with `#FFFFFF` streaks |
| Black water (W7a) | ink `#2A2236` at the surface to `#0E0B14` deep, 86–97% cover; an oily violet sheen `#6B5A80` on its surface line and churn |
| Freeze wipe | `#E8FBFF` crystal lines |
| Mud | `#5A3B22` with glossy `#A47A4E` highlights |
| Wet ash / ashstone | `#2B2A2E` sludge / `#565359` stone with pale flecks |
| Steam | `#F2F2F2` at 50–70% alpha |
| Plants | the existing grass greens; tall grass slightly bluer while wet |

**The water shader** (built after play-test 1, option B + foam and spray; `scenes/objects/water/water.gdshader`). Every pixel of water is colored on the graphics card, so the look costs nothing from the 2 ms simulation budget. It shows what's behind the water swaying by a pixel, tints it from see-through light blue at the surface to murky deep blue, draws a drifting net of thin caustic lines in shallow water, glints along the surface line, and adds white foam specks just under the surface where the water runs fast or is choppy (splashes, wakes, spills). Spray is white specks with no water in them, thrown up by splashes, fast drops landing and spilling lips. All of it is pixel-snapped and tunable in F5 → Water → Look. To compare, `look_style` switches the shader between three looks (key **7** cycles them, the F1 overlay names the one on, F4 saves the choice): **B** see-through (the above, default), **C** pixel-art bands (four flat blues by depth with dithered edges, sparkles, hardly see-through), **A** plain (B's tint without sway, caustics or glints), **B+C** (B with C's bands laid over it: `band_alpha` is how much the bands cover, `blend_band_alpha` how strongly they go over B; B keeps its own `shallow_alpha`/`deep_alpha`). The caustics' shapes have their own knobs: `caustic_size` (average cell size, px), `caustic_warp` (0 a regular grid, higher more uneven and random-looking) and `caustic_thickness`. Foam and spray in all three. **Picked after play-test 1: B+C** (the default `look_style`); the other looks stay on key 7 for now. The metaball renderer (W2) will draw loose water through the same shader.

### 12.2 Building blocks (one script each, reused everywhere)
1. **`WaterWorld`**: the simulation (§6), one per room.
2. **`WaterRenderer`**: body polygons + the metaball layer for particles, ball and snake (§6.3).
3. **`ControlRing`**: the faint ring, with a soft pulse where the ball nears its edge ("about to leave your hands").
4. **`FreezeWipe`**: frost spreads from where the freeze starts as branching white crystal lines, then the water snaps to ice with a glint. For thrown water, it races along the shape from the end nearest you.
5. **`SteamEmitter`**: puffs rise fast, swell and fade.

### 12.3 Per source

| Source | Look |
|---|---|
| Hold | The world dims a touch, the ring fades in, a spark at your hands |
| Gather | A tendril from the surface into the ball; the surface dips under it and rings outward; the ball swells |
| Snake | A glossy column with a foam lip at its foot; the neck thins and drips as you near the tear speed |
| Tear | The neck pinches into drops that rain back into the pool |
| Throw | The ball stretches along its flight, sheds a few drops; a splash crown and spray on impact, waves if it lands in a pool, a dark wet patch on land |
| Freeze | The `FreezeWipe`, a 2-frame freeze frame, a soft crackle |
| Ice slide | A cyan ribbon along the frozen arc, frozen ripples on it |
| Swimming | A wake behind you; a splash crown when you jump in or leap out |
| Mud | Glossy, slowly dripping; footprints sink and squelch; hand prints where you cling |
| Wet ash → ashstone | Sludge bubbles, then the bubbles freeze and it dulls to stone with a small crack |
| Growth | Tall grass pushes up and sways; stalks uncurl their leaf; branches knot outward tile by tile |
| Steam | Puffs shooting fast in their direction, curling at the edges, thinning to nothing |
| Douse | The flame hisses down into a steam puff; the tile turns dark and dripping |
| Melt | Ice glows, drips, then collapses into loose water and a splash |
| Cinder | Pulsing seams, a flickering crown, sparks on each hop; dies in a hiss and a white puff |

### 12.4 Feel
- Big actions get big reactions: a big splash = small shake; freezing a pool = freeze frame + crackle; a steam burst = whoosh + puff column.
- SFX hooks: `water_hold_loop`, `water_gather`, `snake_rise_loop`, `snake_tear`, `water_throw`, `water_splash`, `water_drip`, `freeze`, `ice_skid`, `swim_stroke`, `mud_squelch`, `douse_hiss`, `steam_burst`, `grow`, `melt`.

## 13. Architecture (reuse first)

- **`WaterTuning`** resource: every number above, in the live tuning panel.
- **`WaterWorld`** (one per room, created by `Room` like the fire grid): owns every body, every particle (packed arrays), the spatial hash, the solid-tile grid, sources, sinks and the volume bookkeeping. It's the only node that steps water. API used by everyone else: `depth_at(pos)`, `surface_at(x)`, `gather(pos, max_units) -> units`, `add_loose(points, velocities, units, group_id)`, `push(pos, impulse)`, `freeze_group(id)`, `freeze_touching(rect)`, `total_units()` (for tests), `reset()`.
- **Abilities** (components under the player): `WaterHandsAbility` (hold, ring, ball, snake, release), `FreezeAbility` (picks the target in the §5.3 order). `HeldWater` holds the ball + snake rope while held.
- **Throw groups:** each release gets a group id; particles keep it until they merge or soak. "The water you last threw" = the newest group with particles left.
- **Ice:** `IcePiece` (`StaticBody2D` with a `CollisionPolygon2D` built from the frozen shape; one-way for player slides) and `IceBlock` (a falling, pushable, floating block, built on the crate). Both melt back into `WaterWorld`.
- **`SurfaceGrid`**: generalize Fire's `FireGrid` into one per-room grid of tile states shared by Fire and Water: burning, smoldering, ash, wet, mud, wet ash, ashstone, ice crust, tall grass.
- **Contracts** (like `Pushable` and `Flammable`): `Wettable` (`wet(source)`, `is_wet()`, `dry()`), `Freezable` (`freeze(source)`, `thaw()`), `Growable` (`water(units, from_direction)`), and the `floatable` group. Steam reuses `HeatReceiver`; turbines join a `steam_receiver` group.
- **`ElementImmunity`** gains water, freeze, mud and deep-water entries for every enemy.
- **Rooms:** new flag `water_allowed`. Fire objects (bonfires, braziers, burning grass) can appear **pre-lit** in Water-only rooms. Main menu: "Water chapter", "Water test rooms", mixed test rooms.
- **Level editor:** each stage that adds something placeable adds it to `palette_catalog.gd` (water tiles, source, sink, drain grate, painted ice, waterwheel, turbine, scale, seeds, cinder), per CLAUDE.md rule 7.
- **Tests:** `tests/water_test_world.tscn` + `tests/water_smoke_test.tscn` (one section per W stage; checks volume conservation, reset, the ice cap, and the §6.5 budget), later `tests/water_chapter_smoke_test.tscn`.

## 14. Build stages

The first two stages build **only the water**, with no bending, and end with a play-test gate: nothing else is built until the developer says the water feels right.

| Stage | Contents | Done when |
|---|---|---|
| **W1** | **Water sim I: bodies.** `WaterTuning`, `WaterWorld` with height-field bodies (pipe model + ripple layer), sleeping, merging/splitting, spilling at lips (as simple falling drops for now), body drawing, painted water in rooms; floating crate (buoyancy); debug keys: poke a wave, dump 4 units at the player, drain 4 units. Water test world (a pool, a stepped channel, two pools joined under a wall, a ledge to spill over); smoke test with volume checks and the **performance section** | A dumped bucket makes a wave that crosses the pool, bounces and settles; water runs down the steps and levels out; the joined pools share a level; a crate bobs. Water ≤ 2 ms per frame in the stress test. **Play-test gate 1** |
| **W2** | **Water sim II: loose water.** Particles with cohesion, tile and moving-solid collision, merging into bodies, puddles forming and spreading, soaking (stub wet flag), splash spray, drips; the metaball renderer; sources and sinks; streams and waterfalls; a debug "throw a ball" key in the arrow direction | A thrown ball arcs, splashes into a pool with a crown and waves; on a floor it spreads into a puddle; a waterfall pours into a pool and the waterwheel test stub turns. Total volume is conserved (sources/sinks aside). ≤ 2 ms with 400 particles. **Play-test gate 2: "the water feels right"** |
| **W3** | **Water hands:** `water_hands` / `water_freeze` actions on 1 / 2, `WaterHoldingState`, slow motion, the ring, ball steering, gathering (bodies, puddles, loose drops, flows), release with the boost, auto-release at the ring edge and after `max_hold_time`, jump cancel, orbs vs the held ball | Gather 4 units from one pool and throw them into another: the first is lower, the second higher |
| **W4** | **Water snake:** rise-speed rule, rope, foot sliding along the surface, tear, draining while it rises, endless from flows, shoving, dousing, whip release | Raise a snake slowly and sweep a crate off a ledge; lift too fast and it tears and rains back |
| **W5** | **Freeze and ice:** target order (held / last throw / touching / fizzle), ice blocks from compact water, static ice from long shapes, pool sheets, puddle and wet-tile ice, frozen streams and waterfalls, ice ground physics, ice cap, melting back to water | Freeze a thrown ball mid-air and land on the block; freeze a pool and long-jump off it; a melted pillar refills its pool |
| **W6** | Predictable ice (re-scoped, §16 "Re-planned: predictable ice"): freeze hangs in place, one piece per freeze, pushed blocks become pucks, the trail snake snapped to 0/45/90° with retraction, frozen trails as ground/slide/pillar, painted ice slope tiles, pins removed; one-way slides, `Sliding` with belly slide, ramps, objects sliding down slopes kept | Draw a 45° trail from a pool, freeze it, slide down it and launch off its lip over a spike pit; freeze a thrown ball mid-air as a step to a high ledge; gust a puck along a frozen sheet onto a pressure plate |
| **W7a** | **Black water** (kills, can't be gathered or frozen, its drops are ink), **slicks** (clean water floats on black like oil for a moment), **ice rafts** (water frozen at a surface; ride, gust, jump-off recoil), **painted ice slope tiles** (45°, 22.5° pairs; left over from the W6 re-plan). Split from W7 (developer's call, §16 "Decided in Stage W7a") | Carry clean water to a black-water channel, freeze a raft on it, cross it; freeze a slick into a stepping stone; slide down painted slopes and launch off a ramp |
| **W7b** | ~~Swimming~~ (built early, after play-test 1: §16 "Decided in Stage W1"), **currents** (a placed current zone pushes the water; swimmers and floating things ride the water's own speed), floating objects riding waves and streams (crates, rafts, **leaf platforms and leaf piles**). Enemies in deep water moved to W11 | Ride a stream on a floating crate; a raft drifts with the current |
| **I1** | **Grid ice core** (§16 "Re-planned: grid ice"): freeze only what you hold, the square ball, ball → a block of ice tiles in `PlayerIceLayer`, the ghost, the ice cap per freeze, fire melts tiles; the live window, snow puff, crystal, ice ball, free blocks and pucks removed | Hold a 4-unit ball in the air, see a 2×2 ghost, press 2: a 2×2 block of ice tiles exactly there |
| **I2** | **Snake lines and waterfall walls:** the trail snaps to tile angles and the grid, freezes into flat / slope / column tiles paid from the pool; the ball in a waterfall freezes it into a wall | Draw a 45° trail down from a pool, freeze it, slide down it; freeze a waterfall and wall-jump up it |
| **I3** | **Rafts on any water**, sized in tiles; pool sheets and their ceilings removed | A ball on a clean pool's surface + 2 = a floating raft |
| **I4** | **Crumbling hanging ice:** brittle patches, shake + closing contour, shatter into loose water | A block frozen in mid-air holds 2 s after you land on it, then breaks and rains into the pool below |
| **I5** | **Speed and cleanup:** no friction above run speed on ice, slide tuning, the ROPE snake and dead ice code removed, rooms Water E–H rebuilt, smoke test section Ice | Every room's key move works; the water smoke test passes |
| **W8** | Wet layer: `SurfaceGrid` (from `FireGrid`), `Wettable`, soaking, mud, wet grass, wet ash → ashstone, heat dries, looks | Wet a floor three ways (ball, drop, waterfall); it looks wet; mud brakes an ice runway |
| **W9** | Plants: tall grass (hiding, hidden objects, slow, big burn), vine growth, stalk and lily seeds, thicket branches; water scale, waterwheel, drain grate | Every row of §8.3 and §8.4 works in a test room |
| **W10** | Combinations: mud rocks and gumming, douse table, steam burst / shot / jet-over-water, steam turbine, fire melts ice, gust on water | Every row of §9.1–9.3 works in a test room |
| **W11** | Cinder; `ElementImmunity` rows for all enemies; frozen wisp | Every cell of the §10.2 table behaves as written |
| **W12** | Look and feel pass (§12) | It looks alive in a screenshot and in motion |
| **W13** | Rooms 1–10, mixed test rooms, chapter smoke test | Chapter playable start to Goal |

The stage prompts get written into `PROMPTS.md` (a W0 planning stage) once Fire is finished, like Fire's F0.

## 15. Rooms (draft)

1. **Still Water:** hold, gather, throw. Carry water from a deep pool to a dry basin until a floating crate rises to a ledge.
2. **Rising:** raise a snake slowly to sweep a crate off a shelf; lift too fast and watch it tear. Draining a pool with snakes uncovers the way on.
3. **Waves:** float on lily pads and crates; a dropped ball's wave carries a floating platform across; joined pools share their level.
4. **First Frost:** freeze a thrown ball into a block to stand on; freeze a pool and long-jump off it; build a pillar from a snake to climb.
5. **Slide:** fling an arc over a spike pit and freeze it into a slide; spread a puddle into a runway, freeze it, and brake in mud at the end.
6. **The Falls:** gather endlessly from a waterfall; spin a waterwheel with thrown water; freeze a waterfall and wall-jump up it; freeze a stream to dam it.
7. **Green Thumb:** grow a vine down to a ledge, a stalk up to an exit, a thicket branch across a gap; hide in tall grass to sneak past a sentry.
8. **Mud and Ash:** wet a bare earth shaft in patches and cling to the mud walls on a long climb; a pre-burnt field of ash becomes ashstone where you wet it; douse a pre-lit bonfire for a steam burst that spins a turbine.
9. **Cinders:** fence cinders with wet lines, kill them with water, and let one burn a thicket open before you put it out.
10. **Glacier:** scrolling summit with everything together, the Goal.

**Mixed test rooms**
- **Water + Fire:** steam shots through a waterfall at an out-of-reach turbine; douse a burning vine to save a plank; melt an ice wall with the jet; dry tall grass and burn it.
- **Water + Earth:** raise a column in a pool to lift its level; mud rocks on gray rock and ceilings; gum a sentry shut; dam a stream with a hardened snake; slide a Shell off an ice sheet.
- **Water + Air:** gust waves across a pool; spray a falling stream sideways onto a wheel; glide on steam; bend steam onto a turbine.
- **All four:** the §9.4 chains.

## 16. Decision log

### Decided in the v2 rewrite (26 Oct 2026, developer's prompt)
- **Keys moved from Q/W to 1/2** (Q/W are Fire's). One row per element: Air Z, Earth A/S, Fire Q/W, Water 1/2; jump stays on C (index) and Space (thumb). X stays free (§3).
- **One water verb instead of six:** scoop, pull, flow-bending, ball, stream, trail and pour are replaced by the held **waterball** steered in slow motion inside a ring, which gathers water, raises a **snake** when lifted slowly, and flies on with a **throw boost** when released or pushed out of the ring.
- **Freeze instead of the frost dart:** no aiming and no airtime charge; it freezes the last thrown water, else the water you touch. Added: freezing what you hold (⚠ confirm).
- **Simulated water** (height-field bodies + capped particles + metaball drawing) with a hard 2 ms budget, built and play-tested before any bending (W1–W2).
- **Dropped:** the blob carried between uses and its HUD row, the frost charge, propel and breach (the 1 key is the waterball even underwater), pipes and basin objects (real flow does it), the "Q in context" table.

### Decided in the mud-walls refinement (27 Oct 2026, developer's idea)
- **Throwing water at earth to make mud walls you can stay on** is the way Water changes the level to make it passable (§9.1).
- On mud you **stay put and can wall-jump**; no up/down climbing and no stamina.
- **Any dirt tile** (fresh, used, hardened) can become mud; gray rock and the others can't.
- Mud covers **only the tiles the water touches** (you paint a path); no spreading, no trickling.
- Mud lasts **until reset**; heat dries it, freeze makes it ice. No timer.

### Decided in Stage W1 (water bodies, 27 Oct 2026)
- **Built ahead of the rest of Fire** (developer's call): W1 touches no Fire code. Painted water lives on a non-solid "Water" tile layer (`WaterLayer`); a room that has one gets a `WaterWorld` whether or not Water bending is allowed there (`Room.water_allowed`, off by default, only gates the moves).
- **Columns are 2 px** and line up with the tiles (`column_width` is rounded so whole columns fit in a tile).
- **Pressure under ceilings:** a column under a low wall may hold more water than fits under it; the extra is its pressure and isn't drawn. That's what makes two pools joined by a passage settle at one level (communicating vessels), at the cost of a few px² hidden in the passage.
- **Viscosity added** (`flow_viscosity`, 30/s): plain damping left a column-to-column flicker of tiny flows running for ages, so calm pools never slept. Viscosity evens each pipe out with its neighbours: long waves keep sloshing, the flicker dies in a few frames.
- **Steps:** water can't climb onto a step its surface doesn't reach, and only the water above a step's edge can go over it. Without this, momentum carried a tank's water over its lip until the tank was far below the lip.
- **A tank still ends ~2 px below its lip:** the water rushing to the outlet sloshes, the heap pours over, the backswing leaves the rest lower. That's a real dam-break effect (the painted water starts 16 px over the lip), so it was kept.
- **A big wave can slop over a pool's rim** and leave a thin film on the ground (surface tension holds films up to `puddle_min_depth`). Kept: real.
- **Pokes displace water** (a dip with the water heaped around it) instead of pushing flow: a flow push moved too little water to make a visible wave. Drops still push flow (small kicks).
- **Ripples step once per frame**, not per sub-step (cosmetic only; that halved their cost). Keep sqrt(stiffness + 4 × spread) under ~90.
- **Drops are simple points** (gravity + tile collision, merge on landing, one per 1/16 unit, cap 400): enough for spills and the debug bucket. W2 makes them real particles (cohesion, splashes, metaballs).
- **Floating:** wooden crates float about half under (`buoyancy` 2) and bob on waves; metal crates sink (drag only). The player pushes waves (and swims, since play-test 1).
- **The player's wake** (play-test 1): the first version pushed flow and was about 100× too weak to see. Now the body **drags** the water around it toward half its speed (`player_wake_strength`, `player_wake_grip`): a bow wave in front, a dip behind, about 2 px when wading at full speed. Ripples are kicked where the body cuts the surface. Falling in or leaping out faster than `splash_min_speed` (60 px/s) dips the water and throws a crown of drops **taken from the pool** (water stays conserved). Standing still leaves the water alone, so pools can fall asleep around you.
- **Cost, measured** (headless, this machine): the stress test (every body sloshing, ~385 drops, 9 bodies) averages **1.4 ms** a frame (bodies 0.8, drops 0.4), under the 2 ms budget; single frames peak near 4 ms when many drops land at once. Calm rooms cost almost nothing (bodies sleep). The hot loops work on local copies of the packed arrays: a member lookup per element was the main cost.
- **Swimming moved up from W7** (play-test 1, developer's call): the test rooms are all pools and walking on their floors felt wrong. Built as `SwimAbility` (scenes/player/abilities/water/swim_ability.gd), which reads the submerged share of the hitbox every frame; the Player's gravity, run and jump helpers and the Fall/Jump states use it (§5.4). Measured: run speed under water 54 px/s (dry 90), a held jump off the pool's floor rises ~18 px (dry ~30), each stroke rises ~13 px, sinking tops out at 50 px/s, a held jump at the surface leaps out like a normal jump. Falling in fast is braked (`swim_brake`): a plunge that can touch the floor of a shallow pool. W7 keeps currents, floating on streams and enemies in deep water.
- **The look, option B + foam and spray** (play-test 1: "less uniform, more water-like"): the water shader of §12.1. Options weighed: A, better vertex colors only; B, a shader (see-through tint, wobble, caustics); C, pixel-art depth bands; D, foam and spray. B + D was picked: it reads as water, and it runs on the GPU, so it costs nothing from the 2 ms budget. The colors in each corner of the triangles now carry data for the shader (depth, foam, what it is).
- **Crates never ride on the player** (play-test 1: swimming up under the floating crate picked it up and carried it). A CharacterBody2D moves along with the body it stands on, and the crate stood on the swimmer's head. Now `platform_floor_layers` leaves out the player's layer, so the crate stays where the water holds it and you swim out from under it. The same goes on land: a crate that lands on your head no longer rides along (only the gust moves crates).
- **Debug keys** 8 (poke a 6 px dip at the player's feet), 9 (a 4-unit bucket over the player's head), 0 (drain 4 units from the nearest water), 7 (cycle the water's look), on the top-row digits. They stay until the water hands (W3) replace them. They were F6/F7/F8 at first, but in the Godot editor's embedded Game view F8 stops the game and F7 pauses it, even while the game has the focus (play-test 1: "F8 crashes the game").

### Decided in Stage W2 (loose water, 27 Oct 2026)
- **Particles are W1's drops, grown up**: the same packed arrays in `WaterWorld` (no node per drop), now with air drag, cohesion, wall stickiness, moving-solid boxes, crowns and soaking. Spill and splash code from W1 is unchanged; it just makes particles.
- **Cohesion** (`WaterCohesion`): a soft spring between particles closer than `cohesion_radius` (4.5 px) toward `cohesion_rest` (2.2 px), plus a little viscosity. **Neighbours by a sorted spatial hash**: one packed array of keys (cell, then index), sorted by native code, and three native binary searches per particle (the 3 cells of each row are consecutive). Two findings: the many weak pulls of far neighbours squeezed a 4-unit ball into a 3 px dot, so the push closer than rest is 6× stronger (`cohesion_repulsion`); and the pass runs **every other frame with a double step** (stable at these strengths), which halves its cost.
- **Cost, measured**: the 400-particle cap in one falling clump (cohesion's worst case) with both sources running averages **~1.35 ms** a frame (cohesion ~0.65 ms). A single frame spikes to ~10 ms when a 30-unit clump lands at once (400 landings that frame); a real throw is a few units. The W1 stress test stays ~1.5 ms.
- **Crowns**: a particle landing in a pool faster than `crown_min_speed` (130 px/s) bounces back up with a 30 % chance, at 40 % of its speed, ±30 px/s sideways (it stays a particle). A ball into a pool throws up a crown of its own water; a waterfall keeps a little spray going. Side effect: splashes leave thin films on the banks (surface tension holds them), so **water shallower than `wade_min_depth` (3 px) doesn't count for swimming**: puddles don't slow you.
- **Moving solids** are boxes from a `water_solid` group (`get_water_box()`: crates, the player). Particles are pushed out the shortest way; on a box's top they slide off toward the nearer edge (water doesn't sit on a crate).
- **Soaking stub** (W8 makes the wet layer real): earth and grass tiles soak up to `soak_per_tile` (0.25 unit), from landing particles and from puddles standing on them, and a full tile **wicks** into absorbent tiles up to 2 beside it, so a 1-unit ball on a lawn soaks in entirely and a big one wets it and puddles. Soaked water leaves the books as "soaked"; a soaked tile shows a damp darker top; R dries it.
- **Sources and sinks** are placeable (palette: Objects tab, "Water source" and "Drain"). A source pours into a pool directly when it's under the surface. A drain takes the particles in its box and the pool water above its bottom edge, so on a pool's side it's an **overflow** (the level stands a little over it while water flows to it). A room with only a source still gets a WaterWorld. The books: total + lost + soaked + drained − sourced never changes; debug throws (key 6) make new water, the hands (W3) will take it from pools.
- **Metaballs**: `WaterRenderer` draws one soft dot per particle into a SubViewport that copies the main camera's canvas transform, then the screen-sized picture through `water_blob.gdshader` (threshold, light rim, see-through). **Fast particles are stretched along their velocity** (`blob_stretch`), so a waterfall reads as a ribbon that pinches into drops, not a dotted line. Headless runs (tests) and `use_metaballs` off draw plain squares.
- **The waterwheel stub** (`WaterWheel`, test rooms only, not in the palette): spins with the falling water through its right half (`get_flow_through`). The real wheel is a W9 switch.
- **Debug key 6** throws a 4-unit ball at 200 px/s in the arrow direction (ahead and up with no arrow).
- **Play-test 2 changes:**
  - **Calmer pours.** A source's random nudge per particle is now tuning: `pour_jitter_x` / `pour_jitter_y`, at 1.5 / 1 px/s (it was 6 / 4). A pipe now pours a smooth sheet, like a waterfall.
  - **White water on particles.** Each particle carries foam in its soft dot's green channel, and the blob shader whitens by green ÷ red, in 3 steps. Foam comes from:
    - speed, from `particle_foam_speed_start` (240) to `_full` (350) px/s, so a waterfall whitens near its bottom (falls cap at 360) while a thrown ball (about 225 px/s) stays blue (raised from 150 / 320 in Stage W3, when thrown balls came out white);
    - hitting something (a crown bounce, a hard wall hit, a crate), and being thrown off a splash or a breaking wave. That foam fades over `particle_foam_life` (0.35 s).
  - **Breaking waves.** Pools behave more like the loose water. A crest whose surface rises faster than `wave_break_speed` (20 px/s) throws off foaming particles taken from its own water, at `wave_break_throw` (3.5) × the rise speed plus the water's sideways speed. The water falls back in and makes new waves.
    - A crest must be at least as high as both neighbours. The rise is averaged over 5 columns (10 px).
    - Measured without that averaging, the one-column spike from each landing particle counted as a crest, and the thrown water kept breaking until the particle cap filled.
    - The rate is `wave_break_rate` (60/s at twice the threshold), and at most `wave_break_max_per_frame` (8), only while the room holds under half the particle cap (decoration yields to the budget).

### Decided in Stage W3 (water hands, 27 Oct 2026)
- **The ball runs on real time in `_process`**, not in `_physics_process`: at 0.3x there are only about 18 physics frames a real second, so steering there would be choppy. Real time comes from `Time.get_ticks_usec()` (the fireball's aim preview does the same). Key presses (release, Jump) are still read by the `WaterHolding` state in physics frames, with `is_action_pressed` so a release between two slow frames isn't missed.
- **The held water stays in the room's books** (`WaterWorld.held_area`): gathering moves water from a pool or loose particles into the hands, releasing moves it back as particles (`release_held`). The debug throw (6) still makes new water.
- **Gathering**: particles within reach first (whole particles: a waterfall's stream is eaten drop by drop and keeps falling, so flows never run dry), then the pool under the ball, taken from its column and two tiles' worth each side, so the surface dips under the ball and the dip runs out as waves. Reach is measured from the ball's edge (`gather_reach` 6 px), so a fuller ball reaches farther.
- **The ball is drawn as the loose water is**: its dots (a sunflower disc as big as its water, wobbling) go to the WaterWorld (`held_dots`) and through the metaball renderer, so the ball and the water it lets go of look like one thing. An empty ball is a twinkling spark; the tendril is a 1 px light line for now (W12 makes it a real tendril).
- **Walls**: the ball stops at anything on physics layer 1 (rock, crates, doors), but a ball that is somehow inside rock can always move out (the player pressed against a wall); facing a wall, the ball starts at your chest instead of in the rock.
- **Orbs**: ~~a ball with water in it eats the orb and loses `orb_block_cost` (1) unit~~; replaced in play-test 3: water soaks orbs (below).
- **Jump while holding**: the ball drops (no boost); from the ground you jump, in the air the press is left for Fall (a swimmer strokes).
- **Foam on thrown balls**: a 4-unit throw moves at about 225 px/s and the W2 speed foam (from 150 px/s) turned it white, so `particle_foam_speed_start`/`_full` went up to 240/350: throws stay blue, the bottom of a waterfall (falls cap at 360 px/s) still foams.
- **Play-test 3 (27 Oct 2026):**
  - **The ball shoves, once, like a gust** (replaces a first try where it pushed you continuously and couldn't pass through you: awkward). Under water, a ball with water in it moving INTO something in `WaterWorld.SOLID_GROUP` shoves it the way the ball moves: you get `ball_push_speed` (200 game px/s) times how much of you is under (only from `ball_push_min_share`, 0.5); a floating crate gets it whole through the Pushable contract (`receive_launch`). The ball stops (it gave its speed away) and can't shove the same thing again until it has left it. A ball moving away from or past something doesn't shove, so you can steer it around yourself.
  - **Water vs projectiles: water is water.** A pool, loose drops and the held ball all count (`WaterWorld.is_water_near`). A FIREBALL (yours or a sentry's) goes out in any water: a puff of steam, nothing lit. A SENTRY ORB gets SOAKED: it keeps `orb_soaked_speed_keep` (0.3) of its speed, from then on falls (`orb_soaked_gravity` 300), sinks slowly inside water (`orb_sink_gravity` 60, `orb_water_drag` 6), no longer bounces (the next solid pops it), and is tinted blue. It still kills. The held ball no longer "eats" orbs or loses water to them (`orb_block_cost` and the `orb_blocker` group are gone). Values in WaterTuning "Water and projectiles".
  - **No air gust under water**: with more than `gust_max_submerged_share` (0.5: the water above your middle) of you under, the gust key only puffs (`GustAbility.is_under_water`).
  - **Room Water C**: the deep pool is 48 px deep (66 units) to swim in, the basin narrower (7 tiles), leaving 80 px of ground before the sentry, where it sees you (from the ledge it doesn't); it fires every 1.5 s.
- **Not yet** (W12 look pass): the world dimming a touch, the ball sloshing and shedding drops when moved fast, SFX hooks. `water_freeze` (2) is bound but does nothing until W5.

### Decided in Stage W4 (water snake, 28 Oct 2026)
- **How to ask for a snake: four triggers to compare** (play-test 4). First built as HEAVY WATER (in a pool the ball accelerated at 80 px/s² and braked hard, so a slow lift out of the surface raised a snake and a fast one tore). In play it made the ball slow and unsatisfying wherever there was water, so it was taken out: the ball steers exactly as in W3 everywhere. Instead `snake_trigger` (F5 → Water → Water snake; the F1 line shows it) switches between:
  - **KEY** (the default): hold `water_snake` (3, new action) while the ball comes up out of a pool.
  - **DOUBLE_TAP**: a hold started by pressing 1 twice within `snake_double_tap_window` (0.3 s real); every lift out of a pool in that hold raises a snake. The first tap is a hold of its own (an empty ball fizzles).
  - **GENTLE**: the original rule, no key and no heavy water: come out slower than `snake_max_rise_speed` (40 px/s) and a snake follows; faster, it tears (a splash rains back), and a snake lifted faster than that tears too. With digital arrows at the W3 ball tuning that means tapping ↑.
  - **REST** (Claude's suggestion): the ball in a pool with no arrow held for `snake_rest_time` (0.4 s) arms; armed, the next lift out raises a snake. (First built needing a FULL and STOPPED ball: filling, ~0.7 s, and drifting to a stop, ~0.4 s, hid the rest time, so tuning it did nothing you could feel; now only letting go of the arrows counts.)
  In KEY, DOUBLE_TAP and REST the ring turns green while a snake is ready, and speed never tears a snake; in GENTLE it does. Once one is chosen in play-test, the others go.
- **The rope** is `WaterSnake` (not a node): 10 verlet points from the foot to the ball, 20 constraint passes a frame, 5 % slack and a little sag (`snake_sag`), so it bends and swings behind the ball. Its water is length × `snake_width` (6 px: 1 unit per ~11 px), taken from the pool at the foot as it grows and poured back, spread over two tiles each side, as it shortens; it's in the WaterWorld's `held_area` like the ball's.
- **The foot rides a smoothed surface**: pinned to the exact surface, it followed every wave the snake itself made (taking water dips the pool under it), so the rope's length jerked and it tore "too long". Now the foot averages the surface over ±6 px and follows it at 8/s, and water given back is spread instead of poured into one column (which made a spike).
- **Tears:** longer than `snake_max_length` (80 px: raised from 64, since the pool drops as the snake fills: 9 units out of a 5-tile pool lower it about 15 px), the pool can't feed it, the foot leaves the water, or rising too fast. A torn snake rains back as particles; the ball keeps its own water and gathers nothing until it has left the water's reach. **Sinking back:** the ball lowered back to the surface (shorter than `snake_min_length`, not rising) pours the snake back into its pool, no tear.
- **Speed (play-test 4):** a snake first rose at a capped 30 px/s, which felt sluggish. Now, with a snake, the ball moves at `snake_speed_share` (0.85) of its own speed in every direction, the water's weight; the foot slides at `snake_foot_speed` 110 (was 60) to keep up sideways.
- **No tears outside GENTLE (play-test 4):** with KEY, DOUBLE_TAP or REST a snake never tears. Too long becomes a LEASH: the ball can't get farther from the foot than `snake_max_length` allows. A dry pool makes it run thinner, and a foot at the pool's edge stays put. It ends only when you let go or lower it back. GENTLE keeps every tear.
- **Walls (play-test 4):** the foot only moves where there's water right under it (it used to average the surface over ±6 px, which let it walk into a pool's wall and pour water onto the rock). The rope collides with rock (physics layer 1, what stops the ball, crates included): after each step, a point inside a solid goes back toward where it was at the step's start, to the rock's face, so a snake swung past a pool's rim drapes over it like a hose (the nearest open spot, up to 24 px, only for a rope born across rock).
- **No jitter (play-test 4, seen over the thin wall between Water D's narrow pool and the pillar):** a test holding the head still over the pillar measured rope points jumping up to 20.8 px a frame. Three fixes, now 0.1-0.2 px: (1) the rope steps at a fixed 120 Hz (verlet takes a point's speed from one step ago, so the slow motion's uneven real frames made it overshoot); (2) a point in rock always goes back the way it came, never to the nearest side (it flipped sides of the thin wall); (3) the rope's rest length eases toward its target, and while it wraps around rock it grows to the way around (too short, it kept snapping through the corner). Sinking back is now judged by the ball's height (within `snake_min_length` of the surface, not rising), not the rope's length, which lags a moment with the eased rest length.
- **The gather tendril** (W3, a 1 px line from the ball to where it gathers) was removed: under the ball it read as a white glitch line.
- **Release is a RIBBON (play-test 4; first built as a whip, every point flying on at its own speed, which scattered the body):** the rope's shape freezes and its water flows along it into the point the ball left from, at the throw speed, and leaves there as particles at the ball's throw velocity. Every bit leaves from one point at one velocity, so the body follows the head's arc: one ribbon of water. The bit within 8 px of the foot falls back; a throw slower than 40 px/s (or Jump) just drops it. A new hold lets the rest of a still-flying ribbon go at once; a reset ends it (`WaterWorld.reset_count`).
- **Look (play-test 4: "a ball on a stick"):** the snake's dots widen over its last 16 px to 80 % of the ball's width, so snake and ball draw as one body, and a small ripple (0.8 px) runs up it toward the head so it flows.
- **Shoving:** the snake's head (the ball) shoves pushables it moves INTO, once per touch, with `snake_shove_strength` (160, like the gust) through `Pushable.try_push`: crates, leaf piles, wisps, and the ground's pebble field. Orbs are soaked (play-test 3), not pushed. The steering velocity from before walls stopped the ball is used, since a crate is a wall to the ball (this also fixed the play-test 3 underwater shove, which a crate's own collision stopped). The underwater shove now pushes things other than you only while they float (wet and not standing on a floor), so a wave lapping at a crate on a ledge doesn't push it.
- **Dousing:** the ball (with water) and every point of a snake call `Flammable.douse_near`: the FireGrid puts out burning grass and thicket there (its gust hook `snuff_in`), and objects with a new optional `douse()` go out. None has `douse()` yet: braziers, bonfires, burning crates and the rest come with the douse table (§9.2, Stage W10). Thrown loose water doesn't douse yet either (W10).
- **Not built:** a snake from a waterfall (the ball gathers from one endlessly, but a snake needs a pool under it: a stream works, since its source refills it); the neck thinning near the tear speed and drips (W12: with the lift capped under the tear speed it never gets close).
- **Room Water D** (`-- water_d`): a narrow deep pool (25 units) by the start, a crate on a low pillar past it within the ring, a wide pool (70 units) on the right.

### Decided in the budget perf pass (28 Oct 2026)
- **Why:** the two budget checks swung between runs on the same code (W1 1.25-2.73 ms, W2 0.96-2.32 ms, peaks 3-31 ms). Measured: W1 is steady (±3% over 6 runs); a failing W2 run had EVERY part about 2× slower at once (same 400 particles), which is the laptop CPU (i7-10510U, 1.8 GHz base, far higher in turbo) changing speed, not the code. A per-part probe also found one real hot spot the checks didn't cover.
- **Soaking was the hot spot:** every awake pool over grass or earth redid the whole soak loop every frame, even on full tiles (Dictionary lookups, small arrays made per call): ~0.45 ms a frame in Water A, ~1.3 ms with every pool on grass. Now each tile's soaked amount is also kept in a packed array, and `soak_open` (one byte per tile) says whether it or a tile within SOAK_REACH can still take water; a column over a full tile costs one read. The same water soaks as before.
- **Cohesion finds each pair once** (the "half-neighbourhood": the rest of its own cell, the cell to its right, the three below; one binary search per particle instead of three). Same springs; pairs are just handled in a different order, so numbers differ in the last digits.
- **The budget checks** now repeat each stress 5 times and judge the **median of the 5 averages** against the same 2 ms; each round reseeds the random numbers, so every run does the same work. Waiting for calm counts physics frames, not real time. Each check prints a "machine check" (a fixed GDScript loop) so a slow-CPU run can be told apart from slow code. A third check runs the W1 stress with every pool resting on grass (painted for the check, then removed): the case of a room mixing Fire's meadows and Water's pools.
- **Fire and water together** (measured headless with a throwaway probe, every surface of Water A grass, the fire at its 96-cell cap, W1's stress): FireGrid's logic 19 µs a frame on average (p95 0.1 ms), its flames 58 µs (p95 0.6 ms). Script time for both stays far under the 16.6 ms frame; drawing (flames, metaballs) wasn't measured headless.

### Decided in Stage W5 (freeze and ice, 28 Oct 2026)
- **Planning (developer's answers, before building):**
  - **Hybrid freeze.** The developer asked whether a thrown "ice crystal" that freezes what it touches would play better than the target order. Claude's view: a crystal alone makes "freeze your own throw in the air" a projectile-hits-projectile shot (aim and lead it in half a second), while the target order can't reach far water. So the order was kept for what you hold and your last throw, and the crystal REPLACES rule 3 ("the water you're touching") and the frost puff.
  - **Crystal aim:** a tap throws it at once in the arrow direction (facing with none), and holding 2 aims it in slow motion, like the fireball (the shared GustAim state).
  - **Live window:** the last throw counts only while it's at most 1.5 s old AND at least half of it is still loose (`freeze_live_time`, `freeze_live_share`). Developer's addition: an indicator shows the window, as frost glints on the throw's water and a frost ring over the player's head that runs down.
  - **Mid-air blocks keep their momentum** (developer's call; Claude suggested "hang, then fall"): a ball frozen in flight flies on as a block.
  - **Pools freeze over a stretch, not whole** (developer's call): `freeze_pool_reach` (56 px each side of the hit; "fairly large, tunable").
  - **Wet-tile ice waits for W8** (the real wet layer).
  - **Defaults taken:**
    - long ice is a solid curved shape, made of capsules along a spine (slopes up to 45° walkable; W6 makes slides one-way and adds Sliding);
    - fire melts ice now, through the Flammable contract (`ignite()` melts);
    - freezing what you hold stays;
    - a swimmer whose head is at the surface is lifted onto a new sheet.
- **Throw groups:** every release (the hands, a snake's ribbon, the debug throw 6) gets an id that its particles carry (`WaterWorld.drop_groups`). "The last throw" is the room's newest group.
- **Which shape:** the frozen particles are measured along their principal axis (the direction they're spread most). COMPACT means no longer than `compact_max_size` (16 px) or not twice as long as wide; it becomes an `IceBlock`, 1 unit = 8×8. The ratio rule is needed because a full 4-unit ball is about 18 px round and would otherwise count as "long". Otherwise the water becomes an `IcePiece` along a spine (the points averaged in 4 px slices), as thick as area / length (4-10 px).
- **Sheets reuse the ceilings:**
  - The water above the sheet's bottom becomes ice, and the columns under it get the sheet's bottom as their ceiling, the same pressure model that joins pools under a wall. So you can't surface through it, and water under it keeps its level with the open part.
  - A column frozen to its floor (ceiling at the floor) passes no flow: that's the dam (`WaterBody.FROZEN_GAP`).
  - Melting gives each column its old ceiling and its water back.
- **Ice ground:**
  - accel ×0.15 and friction ×0.08, as specced;
  - **Claude's addition:** a top speed of ×1.4 run speed (`ice_max_run_scale`) that only a long run on ice reaches. Without it a frozen pool was no runway: with no jet or launch around, nothing gave you speed for the "long jump off a frozen pool". 1.0 turns it off;
  - leaving ice above run speed, the extra speed fades at `ice_air_overspeed_fade` (60 px/s²) in the air;
  - ice walls slide ×2 (there's no wall cling in the game to remove).
  - Measured in Water E: a run from standing reaches 126 px/s and long-jumps a 64 px spike pit (a run-speed jump covers about 55 px).
- **Shatter fall 48 px** (`ice_block_shatter_fall`, the spec said 4 tiles): at 32 px, a ball frozen at the top of an ordinary throw shattered on landing.
- **Waterfalls:** the crystal takes the drops joined to its hit. Two drops count as joined within `freeze_join_distance` plus how far the faster one moves in 0.06 s (`STREAM_JOIN_TIME`), because a fast waterfall's drops are 10-20 px apart and a fixed distance often froze one drop into a tiny block. A source with ice 4 px under its mouth stops pouring.
- **Room Water E:** the big pool is held in by a rim of painted ice, not rock. Its water first leaked into the spike pit beside it, and a rock rim would brake the run-up right before the jump.
- **Play-test 5 (28 Oct 2026, developer):**
  - *The ice looked wrong* (the crucial point): a ball frozen in the air became a square, pool sheets were bland slabs, and frozen snakes were lumpy lines. Three looks were mocked up (A glass, B faceted crystal, C frosted); **A, glass with icicles,** was picked.
    - Ice keeps EXACTLY the outline of the water that froze: `IceOutline` adds up the metaballs' field (the same soft dots and threshold `WaterRenderer` draws) on a 1 px grid and traces it with marching squares.
    - A thrown ribbon or a waterfall is traced with its drops stretched as they're drawn (that's what joins a waterfall's beads into a column); a compact ball is traced round, so it doesn't freeze its motion blur.
    - Sheets follow the surface as it was (frozen waves).
    - `IceLook` draws all ice the same way: a see-through pale body, a darker underside band, a light top band, a 1 px rim, a small shine, and icicles under long pieces and sheets. `ice.gdshader` adds a glint band that slides with the player.
  - *A frozen snake stayed in the air*: every free piece now keeps its momentum (`IceBlock` for all of them; its collision is its outline split into convex parts, and it never turns). COMPACT pieces are pushable blocks that slide and shatter; LONG pieces fly, then **lie still** where they land (not pushable, no shatter). Only a snake frozen in the hands, its foot in its pool, stays a standing pillar (`IcePiece`). A frozen waterfall falls too and stands where it lands. **W6 must re-plan slides**: they'll be pieces that landed as ramps, not arcs hanging in the air (done: §16 "Planned in Stage W6").
  - *Too quick to speed up on ice*: `ice_accel_scale` 0.15 → 0.03 (about 3 s to run speed), so speed on ice comes from gusts, jumps and launches, which the ice keeps. The x1.4 runway stays (developer's call): a long enough run still builds past run speed.
  - *A block under water turned back to water*: it shattered on the pool's floor (the fall was measured from above the water). Water now breaks a fall.
  - *Splats froze into one piece* (second look): a throw that had split into separate blobs became one IceBlock with several parts, so splats hung in the air together. Now each blob of the drawn outline is its own piece, with its own water and velocity (`freeze_particles` → `_freeze_blob`). All the pieces of one freeze share a freeze id, and the ice cap counts FREEZES, not pieces (`get_ice_freeze_count`), so a frozen splash can't melt your other ice; melting the oldest freeze melts all its pieces.
  - *Painted ice still looked like tiles*: `IceLayer` now hides its tiles and draws each connected patch in the same glass look (its outline is the patch's boundary on the tile grid), with icicles only where there's open air below.
- **Not built:**
  - ice slides and the Sliding state (W6);
  - ice blocks floating as rafts on currents (W7);
  - wet-tile ice crust (W8);
  - jet and fireball melt combos beyond the Flammable hook (W10);
  - frozen wisps (W11);
  - the ice collar at a pillar's foot and skid sparks on ice (W12 look pass).

### Planned in Stage W6 (ice slides, 28 Oct 2026)
Play-test 5 made free ice fall and lie still where it lands, so the old W6 ("fling an arc over a spike pit and freeze it into a slide") no longer works: nothing holds ice up in the air. The developer's idea fixes that: **pins**.
- **Ice pins** (developer's idea, refined; `IcePins`, placeable like spikes, floor-facing only):
  - tall, thin pale needles, 2 per tile, 7 px tall **(tune)**. **Deadly to the player** with the same fairness as spikes (smaller hitbox than drawn; no kill while moving up), so you can't walk across a pin bed;
  - **they impale ice** (developer's pick): any free ice (`IceBlock`, compact or long) whose shape touches a pin tip stops dead and stays there, static, at the angle it had (free ice never turns). A frozen ball dropped on pins becomes a fixed step; a falling frozen ribbon becomes a fixed slide;
  - the held **snake's rope drapes over the pin tips** like it drapes over walls (W4), so you can lay a snake along a pin bed as a slope, press 2, and it freezes in place as a slide (developer's pick, "drape and freeze");
  - loose water falls **through** pins (they're too thin to hold it): a pin bed never fills up;
  - physics: the pins' tips are a thin static body on a new layer 7 "ice_catch" that only ice and the snake's rope queries look at; the deadly part is an Area2D on layer 3 "hazards", like spikes.
- **Slides vs pillars:** long ice whose spine is flatter than 45° (the player's floor limit, `MIN_FLOOR_NORMAL_UP` 0.7) is a **SLIDE**; steeper is a **PILLAR**. Sheets and compact blocks are neither (solid, flat).
- **Slides are one-way** (developer's pick, as §7.2 said): solid from above, you jump up through them from below and the sides, so a slide never traps you. Pillars, blocks and sheets stay fully solid.
- **`Sliding` state** (§7.2, kept):
  - on ice steeper than `slide_min_angle` 15° **(tune)** you slide: gravity along the slope `g · sinθ · slide_gravity_scale` (1.0), ice friction, arrows lean ±`slide_lean_accel` 40 px/s², capped at `slide_max_speed` (260 px/s, tune); you can't walk up it;
  - flatter ice is W5's ice ground (slow to start, keeps speed);
  - jumping off keeps your velocity (the whole vector along the slope) plus the normal jump; leaving a slide that curves up is a **ramp launch**: you fly on with your speed and it fades like a long jump off ice (`ice_air_overspeed_fade`);
  - floor snap is longer while sliding (`slide_snap_length` 4 px) so you don't hop off small bumps going down; it never pulls you down off an upward lip.
- **Claude's additions, picked by the developer:**
  - **Things slide too:** crates, ice blocks and shells on an ice slope slide down it (same formula, their own friction), so a slide can deliver a block onto a pressure plate or slide a Shell off into a pit.
  - **Belly slide:** holding down while Sliding tucks you in: no lean, gravity along the slope ×`belly_slide_scale` (1.25) and a higher cap, and a hitbox half as tall (with a stand-up check under low ceilings). The skill ceiling of slides.
- **Not picked (parked):** pins in other facings (wall pins catching a thrown ribbon as a ledge, ceiling pins holding a frozen ball up); fire melting a pin's grip so a slide drops (W10 at the earliest).
- **Room Water F:** a pool at the left edge of a pin bed (snake source), the bed sloping down toward a 64 px spike pit that's too wide for a run-speed jump; a high ledge to drop a frozen ball onto pins as a step; a slope down to a pressure plate that opens a door, with an ice block to send down it.

### Decided in Stage W6 (ice slides and pins, 28 Oct 2026)
- **Built as planned** ("Planned in Stage W6" above): `IcePins` (extends Spikes, floor only), impaling in `IceBlock`, the rope and the snake's head resting on pin tips, slides vs pillars, one-way slides, the `Sliding` state with the belly slide, crates / ice blocks / shells sliding down ice slopes, room Water F, the palette entry (Basics tab), the W6 smoke test section.
- **Slide or pillar** is measured once, when the ice is made, along the principal axis of its outline (`IceOutline.lying_angle_degrees`), against `slide_pillar_angle` (45°). It's the overall lie: a snake laid over pins measured about 9° in the test because its foot stands in the pool. Whether you SLIDE on a spot depends only on the local slope there (`slide_min_angle`, 15°).
- **One-way, done by hand:** Godot's one-way collision only checks a direction within about 45° of "up" and misbehaves on curved, multi-part shapes. So each frame the player compares its feet with the slide's top under its left edge, middle and right edge (`get_slide_top_y`): feet above everywhere (tolerance 2 px plus a frame of sideways movement), it collides; otherwise it gets a collision exception for that slide (`Player._update_one_way_slides`).
- **Two Godot details** (both in `IceSlope`):
  - after a move that ends on the floor, `move_and_slide()` drops the velocity's vertical part, so going down a slope the speed along it is read back from the horizontal speed (`velocity.x / tangent.x`). A dot product lost about 10 % a frame;
  - a body held on the floor only by snapping has no slide collision, so `get_floor_contact` probes 2 px down (`Player.get_floor_body` uses it too).
- **The slope comes from the ice's own surface** (its top 3 px either side of the body), not the contact's normal. A box resting on the rounded end of a frozen snake touches it at one corner, gets a flat normal, and would stand on the peak.
- **Pins:** the tip strip is 4 px thick (its top is the tips), so a rope point sagging a few px in one step can't skip through it. Only the snake's rope and head rest on pins: a plain held ball and loose water go through.
- **Measured in Water F:** from the top of a 25° slide, 40 px further down you're at 161 px/s (179 px/s belly-sliding); a jump off the end clears the 64 px spike pit. A crate set on a slide reaches 216 px/s and ends on the plate.
- **Not built:** pins in other facings, fire melting a pin's grip (parked); skid sparks on slides (W12 look pass).

### Re-planned: predictable ice (28 Oct 2026, developer's call mid-W6)
**Why:** the W5/W6 ice looks great but plays too randomly for a skill game. Free ice flew on with the throw's momentum, its shape was whatever the metaballs happened to be (splats split into several pieces), the snake was a swinging rope, and pins caught all of it at random angles. The new rule: **you decide where ice goes, and it stays there.** The glass look (`IceOutline`, `IceLook`, `ice.gdshader`) stays as it is.

- **Freeze = hang in place** (overrides §5.3 "Which shape", the W5 "keep their momentum" decision and the play-test 5 "every free piece keeps its momentum"):
  - water that freezes stops dead and stays exactly where and how it froze: static, with no momentum, no falling and no turning. A ball frozen mid-air is a floating step, and the skill is freezing it at the right moment;
  - **one freeze makes one piece** (splats no longer split into separate blobs): the drawn outline's blobs are joined into one body. The ice cap stays 6 freezes;
  - the live window (1.5 s, half still loose) and the frost-ring indicator stay: they're what makes a mid-air step a timing skill and not a free platform.
- **Hanging ice only moves when you push it:** a gust, the ball's shove or an Earth snake hitting a **compact** block knocks it loose. From then on it's a **puck**: it falls straight down (no sideways carry), and on flat ice it slides with no friction in a straight line until a wall, a crate or a drop stops it. Off ice it stops at once (ground friction). Pucks still shatter on a 48 px fall. Long ice (trails, waterfall columns, sheets) never moves.
- **The snake is a trail, snapped to the arrow angles** (replaces the W4 verlet rope):
  - its body lies **exactly along the path the ball took** since it left the water, with no sag and no swing. Each segment snaps to 0°, 45° or 90° (the arrows' 8 directions), and the corners between segments are rounded (a short arc, about 6 px radius **(tune)**), so a 45° run into a flat one makes a smooth ramp lip;
  - steering the ball back over its own trail **retracts** it (rewinds the path), so mistakes can be undone while you're still holding;
  - length is still paid for in water from the pool (1 unit per ~11 px) and capped by `snake_max_length`; the foot stays where the ball left the pool;
  - frozen (rule 1, while holding) it becomes that exact shape as static ice: **flat segments are ice ground, 45° segments are slides, 90° segments are pillars** (wall-jumpable, no cling). Released, it flows out as today's ribbon;
  - which trigger raises a snake (KEY / DOUBLE_TAP / GENTLE / REST) is still open: play-test it on the new trail.
- **Slides:** one-way (solid from above), the `Sliding` state, belly slide, ramp launches and things sliding down slopes are all **kept** from W6. Only where slides come from changes: trails and painted slopes, not landed pieces.
- **Designer-placed ice slopes:** the Ice tile layer gets 45° slope tiles (both facings, plus half-tile 22.5° pairs if a room needs a gentler slide) in the editor palette, drawn in the same glass look. Those are the fixed, learnable slides levels are built around; player ice is added on top.
- **Ice pins are removed:** `IcePins`, physics layer 7 "ice_catch", impaling in `IceBlock` and the rope resting on pin tips. Their only job was catching flying ice. Spikes already cover "deadly floor".
- **Ice rafts on black water** (new; a W7 item, since it needs currents):
  - **Black water**: dark, inky water (a new color in §12.1) that **kills on touch**, can't be gathered and can't be frozen. Painted as its own tile type on the Water layer; it's still a height-field body (waves, floating), so rafts bob on it;
  - **a raft** is a ball frozen while resting on any water surface: a flat floating slab, its width set by its water (4 units ≈ 3 tiles **(tune)**), about 6 px thick. It floats, bobs on waves, drifts with currents, and you push it with a gust, the ball's shove or the recoil of jumping off it. Its deck is ice ground (slippery: running on it is slow to start and slow to stop);
  - so crossing black water means bringing clean water from elsewhere, setting it down on the black surface and freezing it there.
- **Kept as core uses** (already in the spec; now the chapter's main ice verbs, next to trails, rafts and pucks): frozen waterfalls (a slick column to wall-jump, standing where it froze) and frozen streams as dams (§5.3); puddle runways frozen for the ×1.4 top speed, with mud at the end as the brake (§9.1, W8).
- **What this changes in the build:**
  - **W6 (re-scoped):** hang-in-place freezing, one piece per freeze, pucks, the trail snake with snapped angles and retraction, freezing a trail into ground/slide/pillar segments, painted ice slope tiles (+ palette), pins removed; Sliding, belly slide, ramps and sliding objects kept. Room Water F rebuilt without pins: draw a 45° trail from a pool down to a ramp lip over the spike pit; a mid-air ball frozen as a step to a high ledge; a puck gusted along a frozen sheet onto a pressure plate.
  - **W7:** black water, rafts, then currents (as planned), with rafts riding them.

### Built for play-test: predictable ice (28 Oct 2026)
The developer's follow-ups: **start with 22.5°** (not 0/45/90), **the live window stays a tuning value** (`freeze_live_time`, F5 → Water → Freeze, now up to 10 s), and **W6 is parked**: the pins, the rope draping over them and room Water F stay as they are, untouched, and the re-planned ice is built next to them for play-testing.
- **Two switches, so old and new can be compared in F5 → Water:**
  - `snake_shape` (Water snake): **TRAIL** (the default) or ROPE (W4);
  - `ice_hangs` (Freeze): on (the default) or off (W5: momentum, splats in pieces).
  The W4-W6 smoke test sections switch both back to the old behaviour; the new section **Ice** checks the defaults.
- **Hanging:** a freeze makes ONE piece (`WaterWorld._freeze_hanging`). Compact water becomes an `IceBlock` frozen in place (`is_frozen_in_place`); long water becomes a static `IcePiece`. A block frozen in water floats instead (water can't hold ice still).
- **Pucks:** a gust or a launch (`receive_gust` / `receive_launch`) frees a block. Resting on something, it takes the push. In the air it drops straight (its sideways speed is zeroed until it lands). On ice its friction is `puck_ice_friction` (0); anywhere else it's `puck_ground_friction` (2000 px/s²: it stops within a few px). Measured: gusted at 120 px/s along a frozen pool, it was still at 119 px/s after 0.25 s, and it stopped 6 px onto the rock past the sheet.
- **The trail** (`WaterSnake`, TRAIL):
  - corners plus a current run. The run's direction is snapped to `snake_trail_angle_step` (22.5°), judged once the ball is `snake_trail_min_segment` (10 px) away from the run's start (the average direction, which is how 22.5° comes out of mixed arrows);
  - straying more than `snake_trail_tolerance` (3 px) off the line makes a corner;
  - coming back within 10 px of a run's start re-judges it, and on the run before it, rewinds;
  - corners are rounded over `snake_trail_corner_radius` (6 px);
  - the foot stays at the x where the ball left the pool;
  - the leash is the length along the trail (`snake_max_length`);
  - it sinks back only once it's been rewound to a stub;
  - it's frozen without the drawn ripple.
  - Measured: a wobbly 22.5° lift gave a run at exactly 22.50°, straight to 0.000 px past the corner. The frozen slide's top runs at 22.5°, and you slide down it at up to 240 px/s.
- **Room Water G** (`-- water_g`, after F in the test world): a plateau pool by an 80 px spike pit (draw a slide), a small pool by a 40 px ledge (freeze a throw as a step), a small pool and a big one with a plate past its end and a door (freeze the pool, freeze a ball on it, gust the puck onto the plate).
- **Not built yet:** painted ice slope tiles, black water and rafts (W7). The round ball at the end of a trail freezes with it as a bulb at the slide's end: watch for it in play-test.

### Decided in Stage W7a (black water and rafts, 28 Oct 2026)
- **Planning (developer's answers, before building):**
  - **W7 split in two:** W7a black water, rafts, painted ice slopes; W7b currents, floating things riding them (with leaf platforms and leaf piles floating), after a play-test.
  - **Currents (W7b):** a placeable current zone that pushes the WATER; swimmers, crates and rafts ride the water's own speed (one physics for waves and currents).
  - **Rafts come two ways:** the held ball steered down onto any surface and frozen, and clean water THROWN onto black water, which floats like oil (a slick) long enough to freeze from a distance.
  - **Extras taken:** painted ice slope tiles (left from the W6 re-plan) and floating leaves (W7b). Enemies in deep water wait for W11 (enemies vs Water).
- **Black water** is painted as a second tile of the Water layer (`WaterLayer.BLACK_TILE`, palette Terrain tab "Black water"). Each patch becomes a body with `is_black`. It's simulated like any water (waves, floating, spills).
  - **Kills** the player with more than `black_kill_depth` (1 px) of the hitbox in it, measured at the hitbox's left, middle and right; a black drop inside the hitbox kills too. The slack lets a raft's deck bob at the surface without killing its rider.
  - **Can't be gathered** (the ball skips black bodies and drops), **raises no snake** (a lift out of black water is just a lift), **can't be frozen** (the crystal fizzles in it), **doesn't soak** into earth or grass.
  - **Black wins:** drops thrown off a black body (spills, splashes, breaking crests) carry `WaterWorld.BLACK_GROUP` (-1) and turn any water they land in black; two pools that join are black if either was. So paint black water apart from clean water.
  - **Look:** vertex alpha 0.5 marks black water for `water.gdshader` (ink, darker with depth, a faint shimmer of what's behind, an oily violet sheen drifting along the surface line); black drops carry it in the metaball dots' blue channel (`water_blob.gdshader`). Color added to §12.1.
- **Slicks:** clean water landing on black water floats on it for `black_slick_time` (2.5 s) from its first touch, then sinks in and turns black (`drop_slick_time` per drop).
  - First built with the surface as a flat floor: every drop was squeezed onto one line, and the cohesion springs spread a 4-unit ball into a film over the whole 64 px pit (and drops pressed into the pit's walls were lost as crumbs).
  - Now a drop under the surface is lifted the harder the deeper it is (`black_slick_buoyancy` 0.5 of gravity per px: balanced 2 px under, never deeper than 6 px) and damped strongly both ways (`black_slick_damping` 12/s), and kept inside its pool's ends. Measured: a 4-unit ball settles as a lens 35-43 px wide. A whole slick sinking in at once makes a small wave whose crest throws a few black drops (an ink splash); none of the water is lost. A slick piled up near a low bank can roll a drop or two over onto it, so room Water H's pit has its surface 16 px below the bank.
- **Rafts** (`WaterWorld._try_make_raft` / `_make_raft`, `IceBlock.is_raft`):
  - water frozen with its lowest point within `raft_surface_reach` (8 px) above an open surface and its highest within 8 px below it becomes a flat slab there. That covers the held ball resting on the surface (freeze rule 1), a slick (rule 2, the live throw), and a throw just landing. Under an ice sheet it stays a puck; deeper, a floating block; higher, hanging ice;
  - its size: `raft_width_per_unit` 6 px per unit (4 units = 24 px), between 10 and 64 px, `raft_thickness` 6 px, fitted between the walls around it. Its water is exactly what froze;
  - a compact IceBlock that's never frozen in place: it floats half under, bobs, and drifts far (its own `raft_water_drag` 0.6, no air friction: afloat, a crate counts as "in the air"). The deck is ice. It counts toward the ice cap and melts in fire like any ice;
  - **a rider presses it down** (`raft_rider_weight` 0.25 of gravity: about 2 px);
  - **jumping off with an arrow held pushes it back** at `raft_jump_push` (60 px/s) plus a dip. First built as a share of the jumper's speed, but on the ice deck you've barely moved, so it did almost nothing;
  - **Claude's addition: gusting sideways while standing on it** pushes the raft the other way (it takes the gust's recoil, like a boat pushed off with a paddle: `raft_gust_recoil_share` 0.8; a gust to the left moved it 72 px right with you on it). It uses the sail platform's wind-catcher contract (`Player.WIND_CATCHER_METHOD`); only rafts catch it (`IceBlock.is_catching_wind`), so on a puck you still recoil. ⚠ Play-test: the Air chapter's sail moves WITH the gust; this moves against it.
- **Painted ice slopes:** the ice tileset has six slope tiles (`IceLayer.TILE_SHAPES`: 45° rising right and left; 22.5° as a LOW and a HIGH tile side by side, both ways), solid on layer 1 with their shape as collision, fully solid (not one-way). The player, crates and blocks slide on them through IceSlope (the slope comes from the contact's normal).
  - **One glass outline:** `IceLayer._trace_patches` now walks every tile's polygon as edges cut into 4 px pieces; an edge two tiles share is walked once each way and cancels, so a slope with ice under it draws as one piece of glass.
  - **Palette:** four entries in the Terrain tab ("Ice slope, up right/left", "Gentle ice slope, up right/left"). A gentle brush paints its low tile on even columns and its high tile on odd ones (`TileBrush.tile_odd_column`).
  - **Level design note:** walking off a 45° slope is a fall, and landing on a gentler slope throws away the speed you fell with. A ramp launch needs one continuous slide. Measured in Water H: 48 px down six 22.5° pairs reaches ~265 px/s, and the 2-tile 45° ramp launches you over a 56 px spike pit (to x 553, the pit ends at 544).
- **Water against slope tiles (play-test fix, the Test level's room 4):** the water saw solid ground as whole tiles, so a pool beside a painted slope stood on the tile tops in a staircase and never filled the open half of each slope tile. Now a slope cell is PARTLY SOLID in the WaterWorld's grid (`PARTLY_SOLID`, its shape in `slope_shapes`): `is_solid_px` tests the shape and `floor_below` returns the slope line, so the pool's columns climb the slope 2 px at a time. Two follow-ups the fix showed:
  - **Films run downhill:** surface tension (a film thinner than `puddle_min_depth` stops spreading) now holds only on level ground. A wave sloshing up a slope used to leave a film painted up it; now it drains back (`WaterBody.DOWNHILL_SLACK`).
  - **Ceilings on slopes:** a column whose floor is on a slope tile used to get that same tile as its ceiling (below its floor), which reads as frozen through, so its water stopped flowing. A slope tile is now a ceiling only when it lies wholly above the water; and a drop landing on a slope takes its column's floor at the column's center, so a puddle's floors line up.
  - **Drops landing on a slope run down it:** a one-drop puddle used to count as level and fall asleep where it landed. Now a thin end grows onto lower ground beside it, and a puddle with open, lower ground past an end isn't "level" (it stays awake until it has run down).
- **Room Water H** (`-- water_h`, after G in the test world): a clean pool by a black channel (make a raft, ride it, gust), a small clean pool by a black pit (throw a slick, freeze it), the painted slopes down to a ramp over spikes.
- **Not built:** currents and things riding them (W7b); a raft getting pushed by waves you make yourself beyond the existing wave-slope push; black-water steam with fire (W10, if ever).

### Decided after the W7a play-test: higher rafts, the snow puff, the ice ball (29 Oct 2026)
- **Rafts float higher** (developer: "the player should be above the dark water when he stands on an ice sheet"): rafts have their own `raft_buoyancy` (4; crates keep `buoyancy` 2). Alone a raft floats a quarter under; with you on it, about a third; your feet stay ~3 px above the black water (the W7a test checks it).
- **The snow puff replaces the ice crystal on 2** (developer's idea; `SnowPuff`, scenes/objects/water/snow_puff.gd). Developer's answers to the planning questions:
  - **Aiming: a short toss.** A tap of 2 (shorter than `snow_tap_time`, 0.15 s real) bursts the puff around you; holding 2 aims in slow motion (GustAim, as the crystal did: a dotted frost line to where the puff lands, with its ring) and tosses it `snow_toss_distance` (48 px) that way.
  - **The other rules stay:** 2 while holding still freezes your hands' water, and 2 within the live window still freezes your last throw wherever it is. The puff replaces only rule 3, the crystal.
  - **Pools: each flake its own stretch:** a flake landing on a pool freezes a sheet `snow_pool_reach` (10 px) each side; a flake landing on ice already there just melts. Measured over a 32 px pool: two sheets.
  - **The puff:** `snow_flake_count` (24) flakes burst out to `snow_puff_radius` (22 px) from the center (sunflower spread), the air stops them (`snow_flake_drag` 6/s: a flake travels speed / drag, so its start speed is its offset x drag), then they fall at `snow_fall_speed` (28 px/s) swaying (`snow_sway`) and melt after `snow_flake_life` (2.5 s). Every value is in F5 → Water → Snow puff.
  - **What a flake freezes:** the first water it touches, like the crystal did: a throw (all of it; a raft if it's resting on a surface), other loose water (the drops joined to it: a waterfall column), or a pool (a sheet). Black water doesn't freeze. Anything solid or player ice melts a flake.
  - **One puff = one freeze** for the ice cap: everything it freezes shares one freeze id (`WaterWorld.shared_freeze_id`). Without that, a puff over a pool made several sheets and melted your other ice.
  - **A reset clears falling snow:** puffs are children of the room and join `Room.RESETTABLE_GROUP`. A puff still falling after death or R refroze the fresh pool (found by the test).
  - `IceCrystal` stays, unused by the player: the smoke tests still use it to freeze pools and waterfalls directly.
- **The ice ball** (developer's idea; the `IceBall` player state, the ball itself in `FreezeAbility`): 2 with at least `ice_ball_min_share` (0.98) of you under clean water freezes `ice_ball_units` (1) of the water around you into a ball (radius 10 px) you sit in. Its water is in the room's held water, so the books balance.
  - It floats up fast (`ice_ball_buoyancy` 3, at up to `ice_ball_max_rise_speed` 220 px/s), then bobs at the surface; the arrows roll it (`ice_ball_roll_speed` 45). Developer's pick: it bobs and rolls (a lifeboat).
  - The rise is capped by how deep it still is (share squared). The first version shot 27 px clear of the water and bounced for seconds, because the water's drag only works in water. Now it settles into a ±2 px bob.
  - 2 again shatters it: its water goes back as loose water and you pop up a little and swim. Death or a reset shatters it too.
  - **Claude's addition:** inside the ball, black water can't kill you, so rolling from clean water onto black is a way across. ⚠ Play-test.

### Planned in Stage W7b (currents and floating things, 29 Oct 2026)
Developer's answers to the planning questions:
- **Current zones move real water** (not a separate "carry" layer): a zone drives the pipe flow inside it, so it moves volume. In a closed pool that TILTS the surface (water piles up downstream until the slope pushes back as hard as the zone), and that's accepted as real. Long streams are a source upstream plus a drain or spill downstream; the zone speeds them up.
- **Loop zones (the developer's turbulence idea), in W7b:** a second zone mode where the surface runs one way and the deep water the other, with zero net volume (no tilt). The height field has one depth per column, so a loop is stored as speed that changes evenly with depth. Riders take the speed at their depth: floaters drift with the top, a diver is carried back along the bottom.
- **Leaf platforms bob on their rails:** where the rail runs through water, the platform rides the surface (bobs on waves), and a current pushes it along the rail like a gust. The rail stays the level designer's guarantee.
- **Loose leaves float and drift:** a leaf landing on water lies on the surface, bobs, rides currents and gets nudged by wakes. Fire can't reach a floating leaf.
- **Extras taken:** waterfalls push down (§5.4), a visible current look, a surfing check (a raft or crate riding a stream carries you), and the zone in the editor with a direction picker.

### Decided in Stage W7b (currents and floating things, 29 Oct 2026)
- **CurrentZone** (`scenes/objects/water/current_zone.gd`, palette Objects tab "Current": a rectangle, a left/right arrow, `strength` px/s, `mode` FLOW or LOOP). It moves nothing itself: the WaterWorld reads every zone in its room each frame.
  - **FLOW** (`WaterWorld._apply_currents`): every pipe of a column whose water reaches into the zone moves `current_grip` (3/s) of the way toward the zone's speed (flow = speed × depth / column width, the wake's formula). A body under a flow zone never sleeps (`WaterBody.is_in_current`).
  - **LOOP** isn't stored: `CurrentZone.get_loop_speed` gives +strength at the surface, 0 halfway down, −strength at the floor, fading in over 8 px at the zone's ends. It moves no water (measured: the pool stays level to 0.00 px).
- **Real flow has a consequence for level design:** a stream runs only as fast as its source feeds it (rate ÷ depth). The first stream (2 units/s through 22 px of water) ran at 18 px/s and mostly tilted. Room Water I's stream is now 16 px deep and fed 10 units/s, with an overflow drain: it runs at ~40 px/s. In a closed pool, a 40 px/s FLOW zone tilts the surface by ~12 px across 72 px (measured), which is a lot: for a pool, use LOOP.
- **The water's speed** (`WaterWorld.get_water_velocity_at`): the column's pipe flow × column width ÷ depth (depth at least `current_min_depth`, 2 px), plus any loop at that depth, capped at `current_max_speed`. Everything that rides water reads it:
  - **the player**: `SwimAbility.current_speed_x` = the speed × `current_push` (0.6) × how much of you is under, added to `Player.get_wind_velocity()`, so a current works like a sideways wind (it shifts the speed you settle at). It's sampled `current_sample_margin` (6 px) past each side of the hitbox (`get_water_velocity_around`): the wake you drag along is water moving at your own speed, and riding it would speed you up without end. Measured: swimming in still water tops out at 54.9 px/s against a 54 px/s cap;
  - **crates and rafts**: the water's drag pulls their sideways speed toward the water's (in the middle of their wet part), and afloat their air friction settles them at it too (`Crate.water_speed_x`). Measured: the stream's crate rides 112 px in 3 s;
  - **floating leaves** (`LeafPile`, `leaf_is_flying` = `FLOATING`): a leaf landing on water lies `leaf_float_lift` above the surface (with its ripples, so it bobs), tilts with the surface's slope, drifts at the surface's speed plus a little sway, stops at walls, and falls again when its water drains away. It can't be lit, a burning one going in goes out, and it's drawn without the ground sink;
  - **leaf platforms** (`LeafPlatform._float_on_water`): where the rail runs through water, the leaf rises along the rail until its top floats `leaf_platform_float_lift` above the surface (at up to 60 px/s; it follows the surface down a little, so it bobs), and the current pushes it along the rail by the rail's sideways part.
- **Waterfalls push down** (`WaterWorld.get_falling_push`): the falling water's area × downward speed over the hitbox's area × `waterfall_push`, up to `waterfall_max_push`, reached at `waterfall_grip`. Two things the first try showed:
  - loose water bumps off the player and crates, so it never gets inside their box: the check also looks 6 px above it;
  - under water a waterfall lands in the pool at the surface: the check reaches up to the surface.
  For the player it raises the sink speed and the pull (`Player.apply_gravity`); for crates it's a push. Measured under the room's 2 units/s waterfall: 20-40 px/s.
- **The look:** each corner of the water's quads carries the water's speed in its UV.x (`STREAK_SPEED_ENCODE`), and `water.gdshader` scrolls faint dashes along 2 px rows at half that speed (speed rounded to 4 px/s, so a stream reads as even bands), from `streak_speed_start` (8) to full at `streak_speed_full` (60), at most `streak_alpha` (0.35). In black water they're in the oily sheen color. Sloshing waves show brief streaks too.
- **Surfing works with no extra code:** a raft on the black channel's loop carries its rider (the CharacterBody2D floor carries the player along).
- **Room Water I** (`-- water_i`, after H in the test world): a fed stream with a floating crate over a spiked floor; a clean pool by a black channel with a loop current (surf a raft); a deep loop pool between two ledges with a waterfall (its floor drain takes what it pours), a leaf pile on the left ledge and a leaf platform on a vertical rail from the pool's floor.
- **Cost:** Water I with everything running: ~0.7 ms median (budget 2 ms).
- ⚠ **Play-test:** `current_push` 0.6, the closed-pool tilt of FLOW (and whether `current_grip` should be lower), the waterfall push, how the streaks read, the raft's slow pick-up of a current (`raft_water_drag` 0.6).

### Re-planned: grid ice (31 Oct 2026, developer's call: "a complete rework of the ice, more gameplay-oriented")
**Why:** the predictable-ice pass made ice stay put, but it was still hard to judge: its outline was whatever the metaballs were, five different rules made it (held, live throw, snow puff, ice ball, slicks), and pucks, sheets and pins each had their own physics. The new rule: **you see exactly what 2 will make before you press it, it snaps to the tile grid, and it stays.** Built as Stages I1–I5 (§14, `PROMPTS.md`). This entry overrides §5.3, §7 and every earlier ice entry in this log where they disagree.

- **What ice is for** (developer's answers): platforms you make, which are slippery and hard to use, and **speed** for big gaps in fast, long horizontal rooms. Speed comes from **slides** (height turns into speed) and from **ice keeping any speed** (a gust, jet or launch that ends on ice isn't braked).
- **Freeze = only what you hold.** 2 while holding 1 freezes the ball (or the snake) in slow motion. 2 with nothing held only fizzles (a few frost specks). **Gone:** the live-throw window and its frost ring, the snow puff, the ice crystal, the ice ball, freezing slicks.
- **Ice is tiles.** Frozen water becomes tiles of the ice tileset (the same full and slope tiles as painted ice, `IceLayer.TILE_SHAPES`) in a per-room `PlayerIceLayer` (the "PlayerIce" layer, made by the WaterWorld). Each tile holds exactly its own area of water (a full tile 1 unit, a 45° slope ½, a 22.5° pair ¼ + ¾). Painted and player ice share one physics and one glass look.
- **The ball is a soft square** while you hold it (its side is √(its water), so 4 units is exactly 2×2 tiles), and it freezes into a **block**: the most square rectangle its whole units fill, wider than tall (1 → 1×1, 2 → 2×1, 3 → 2×1 + 1 unit that drips off, 4 → 2×2; `ball_max_units` 9 would allow 3×3). The block snaps to the cells nearest the ball.
- **The snake makes lines.** The trail's runs snap to the tile angles only (0°, 22.5°, 45°, 90°: 67.5° goes to the nearer of 45° and 90°), its corners to the grid. Frozen, it becomes tiles **under** the line (the line is the surface you walk on): flat runs full tiles, 45° runs slope tiles, 22.5° runs gentle pairs, 90° runs a column. The tiles cost their exact water: the snake's and the ball's first, then the rest from the pool at the foot (or back into it); a pool that runs dry cuts the trail short.
- **Waterfall → ice wall.** The ball inside a source's falling water + 2: the whole fall, from the source's mouth down to where it lands (the ground or a pool's surface), becomes a column of full tiles (one tile wide; wider for a wide source). Its water comes from the source (counted as sourced), so it costs no ball water; the ball's water drops. The source stops while the wall stands; fire melts it and the waterfall starts again.
- **Rafts on any water.** The ball touching a water surface (or under it) + 2 makes a **raft**: a slab as wide as the ball's whole units in tiles (4 units = 32 px), `raft_thickness` thick, floating at the surface. Clean water or black. It's the only ice that moves (floats, bobs, rides currents; gust recoil and jump-off push as in W7a). **Gone:** pool sheets and their ceilings, dams.
- **The ghost.** While you hold, the tiles 2 would make are drawn as a ghost: a solid cyan outline where the ice would stay, a **cracked** outline where it would hang in mid-air (it will crumble; since the play-test: a faint fill and one pulsing outline, see "Decided after the grid-ice play-test"), a slab on the surface for a raft, the full column for a wall. Cells it can't fill are **red** (rock, you, a crate, a door, water) and are skipped (their water drips off).
- **Hanging ice crumbles** (developer's idea, refined): a connected patch of player ice that touches no terrain (no rock, earth, painted ice or other solid tile beside it, and no pool's water right under it) is **brittle**. The first time you or a crate touch it, it shakes for `crumble_time` (2 s) while a bright contour runs around it and closes; then it **shatters** into ice shards (a look) and its water falls as loose water, which can be gathered again. Ice that touches terrain (or rests on a pool) is permanent. This also stops endless staircases.
- **Limits:** water (each tile is real water) plus the ice cap, `max_player_ice` (6) freezes per room (rafts and walls count); a new one melts the oldest. Fire melts any player ice (the freeze it touches) back into loose water.
- **Speed on ice** (I5): on ice, speed above run speed has no friction (`ice_overspeed_friction`, 0) unless you steer against it; a jump keeps it, and it fades gently in the air as before. Slides, the belly slide and ramp launches stay. Player ice is fully solid (no one-way slides: the ghost won't put ice inside you, so it can't trap you).
- **Removed with it:** pucks, `IcePiece` (pillars and sheets), free `IceBlock`s (only rafts are left, now `IceRaft`), `IceOutline`'s metaball tracing for player ice, `IcePins`, `IceCrystal`, `SnowPuff`, the `IceBall` state, the ROPE snake and the `snake_shape` / `ice_hangs` switches; rooms Water E–H rebuilt (F lost its pins).

### Decided in Stages I1–I5 (grid ice, built 31 Oct 2026)
- **One node per room for player ice:** `PlayerIceLayer` (extends `IceLayer`), added by the WaterWorld as the room's "PlayerIce" layer and joined to its solid grid. It only keeps the cells' bookkeeping (freeze id, water) and the patches; the WaterWorld owns the water (`apply_ice_plan`, `melt_freeze`, `shatter_cells`). `IceLayer.ICE_GROUP` replaced `IceBlock.ICE_GROUP`.
- **The plan is the ghost:** `IcePlan` is built every rendered frame while holding (a few physics queries per cell; cheap) and the very same object is applied on 2, so the ghost can't lie.
- **Blocked cells:** solid tiles, outside the room, water deeper than 1 px in the cell, or anything on physics layers 1, 2 or 4 (rock, you, crates, doors). Their water drips off. Loose drops inside new ice are set on top of it.
- **The trail's tiles lie under the line:** each column the trail crosses gets the tile whose top holds the line (full, 45° or gentle by the line's height at the column's two edges). A vertical run's column goes on the side of the run next to it, so an L joins up. The gentle angle is really 1:2 (26.6°, what the "22.5°" tiles are), and the snake now snaps to exactly the tile angles: flat, 1:2, 45°, upright (67.5° goes to the nearer of 45° and 90°).
- **Anchoring:** a patch is permanent if any cell has a solid non-player tile beside it (4 neighbours) or a pool's surface within the tile under it. Patches connect through 8 neighbours (a 45° trail's tiles touch at corners only).
- **The ball is a soft square:** a grid of dots inset by 0.6 × `blob_dot_radius`, so the drawn square is about the water's size; `get_ball_radius()` is now half its side.
- **Test sections:** `Ice` (room E: block sizes, the fizzle, the square ball, the ghost's 2×2 block, blocked cells dripping, crumbling after `crumble_time`, the cap, fire, speed kept on ice, reset) and `Lines` (rooms F and G: snapping, a trail's tiles and the pool paying, sliding down a trail, a hand-drawn snake frozen, a crate down a shelf trail onto a plate, a waterfall wall stopping its source and melting, a raft on clean water). W4 lost its rope checks; W7a makes its rafts from held water.

### Decided after the grid-ice play-test (31 Oct 2026)
- **Backed slopes:** a snake's slope tiles touched only at their corners and read as a dotted line. Every slope tile of a trail now gets a full tile under it (`IcePlan._add_backing`), so neighbours share an edge and the ramp looks solid. Flat runs stay one tile thick. The backings cost about one more unit of water per slope tile, and they are frozen last, so a pool short of water leaves them out first. (Freezing "the snake as drawn" was considered: the snake's 6 px body straddles two tile rows, so it isn't on the grid.)
- **A quieter ghost:** a faint fill (18%) per tile and ONE faint outline round the whole shape (`IceLayer.trace_tiles`), instead of a box round every tile. Ice that would crumble gets a slowly **pulsing** outline (the dashes are gone). Blocked cells are a faint red fill with no lines.
- **Sailing a raft:** gusting on a diagonal while standing on a raft. Down and back (↙ sailing right) **hops** you and the raft together: up at `raft_hop_speed` (200) and forward at the sideways push. In the air the raft stays under your feet (`raft_follow_speed`, for up to `raft_follow_time`; its deck `FOLLOW_GAP` 2.5 px under you while you rise, more than your floor snap), so you land on it unless something stops it (a wall). Landing back on water, the splash cuts the raft's fall to `raft_land_speed` (30), so the deck doesn't plunge under (it went 6 px under). Landing on it, your speed becomes your speed on it, so you don't run off its front. Up and back (↖) **dives** (second play-test round: it replaced a "pump" that dipped and sprang into a higher hop): for `raft_dive_time` (0.7 s) the raft goes forward, down at `raft_dive_speed` (70) for the first half and back up for the second, carrying you wholly under, beneath whatever hangs into the water. Its lift is neutral while it dives, and it puts you back on its deck after its own move each frame (`process_physics_priority` 1: rafts move after the player), with `move_and_collide`, so a rock in the way stops you and the raft goes on without you. On black water a dive kills you (developer's call: it's a clean-water move).
- **A floating crate takes the gust's recoil too** (second round): standing on a crate that floats, a sideways gust moves you both away from it, like a raft (`Crate.absorb_gust_recoil`, `is_catching_wind` while it floats). Before, the gust's cone hit the crate under you and carried you both INTO the gust.
- **Hollow snake ice** (second round): a snake that turns back on itself (a `<` or a zigzag) made ice whose parts met at a single corner. Its traced outline passed that corner twice, Godot can't fill such a polygon (`draw_colored_polygon` draws nothing), and the ice showed only its rim and bands. 1 random snake shape in 9 did it. `IceLayer._split_at_pinches` now cuts the outline there into simple loops (0 in 3000 after).
- **See-through ice** (second round): the glass body is 55% opaque (was 80%), its bands lighter too (`IceLook`).
- **Calmer rafts** (third round): a raft floats high, so its lift is stiff (about 4 bobs a second), and its low water drag hardly slowed that: every wave or landing set it bouncing for seconds. Afloat and not sailing, it now also loses `raft_bob_damping` (30) of its up-and-down speed per second (`Crate._get_bob_damping`, 0 for crates): it settles in a bob or two.
- **The neutral gust lands you on ice** (third round): a neutral gust in the air grips your next landing (`Player.has_ice_landing_grip`): land on ice and you stop dead (on a raft: still on its deck). Its all-around blast no longer blows away a raft under you: from over the deck it brakes the raft instead (`IceRaft.receive_gust_from`).
- **Straight up dives, straight down hops** (fourth round): the raft takes every gust you fire standing on it, straight up and down too, not only diagonals. A floating crate still takes only the sideways part.
- **Rafts keep their speed** (fourth round): each sideways gust's recoil ADDS to the raft's speed (up to `raft_max_sail_speed`, 260), and a hop or a dive keeps it. Build up speed with a few gusts, then hop (down) or dive (up) and carry on. Flying, if you steer nothing you keep the hop's sideways speed (air control alone braked a slow hop to a stop). A neutral gust standing on it brakes it by `raft_neutral_brake` (130, about one gust).
- **The hop launches you whole:** you used to get the launch minus the raft's speed and relied on Godot adding that back as you left the deck (`platform_on_leave`). The raft had already risen into your feet, so sometimes you never left and it flew off without you. Now you get the whole launch, and leaving the deck adds nothing until the hop ends. Hops are a little higher (about 22–27 px, was 17–20).
- **Rafts only sail on water** (fifth round): a raft on dry ground is just ground (`IceRaft.is_catching_wind` needs it floating). On land an up-gust "dived" it into the ground and it sprang back out a moment later.
- **The aimed arrow doesn't walk** (fifth round): after a gust into a raft (or any floor that catches wind), the sideways arrow you aimed with reads as no input until you let go of it (`Player.sail_aim_arrow`). Held on, it steered you away from a hopping raft and walked you off its ice deck. Pressing the other way, or pressing it again, walks as usual.
- **Water on crumbled ice falls:** a puddle on a block (its freeze's drips) kept the floor it was made on and floated where the ice had been until you splashed it. When ice goes, every body with a column whose floor is gone turns into loose water (`WaterWorld._drop_unsupported_bodies`).

### Open questions for play-test
- **Reach:** is 1/2 comfortable with the index on C? If not, try jump on V, or rely on Space (§3.2).
- **Moving while holding:** standing still on the ground, and keeping your arc in the air: right? Or should you walk slowly while holding?
- **Throw boost 2.5×:** throws feel strong enough? Too wild?
- **Snake rise speed 40 px/s:** learnable by eye? Should sideways speed also tear it?
- **Freeze while holding:** keep it, or does it make throwing-then-freezing pointless?
- **Freezing a pool you swim in** lifts you onto it: helpful or weird?
- **Max hold 4 s:** enough to build a snake, short enough to stop slow-motion camping?
- **Ice cap 6:** enough?
- **Mud gum time:** 4 s, or until reset?
- **Mud patch size:** is "only the tiles the water touches" big enough to paint a wall path with a 4-unit ball, or too fiddly?
- **Slow climb on mud:** should up/down move you slowly after all (parked: see §17)?
- **Douse a brazier** closing its door: good puzzle, or confusing?
- **Jet over water** boiling pools down: fun, or a way to wreck a room by accident?
- **Tall grass everywhere:** if all watered grass growing tall clutters rooms, only "sprout grass" tiles grow tall.
- **Underwater:** the jet and fireball off, the gust at half strength: right?

## 17. Parking lot (not confirmed)
- **Propel and breach** (v1): a swimming burst and a jump out of the water. Needs a key: maybe holding 1 with the ball inside the water you're in.
- **Bending a flow like a hose** (v1): steer a whole waterfall. The snake from a waterfall covers part of it.
- **Water whip:** a quick snake strike.
- **Riding a snake:** stand on a frozen snake's head while it's raised (freeze, thaw, raise again).
- **Surfing:** stand on an ice block riding a stream (may just work with floating + currents; test it).
- **Climbing up a waterfall**, salmon-style.
- **Icicles** that grow under wet ceilings and fall when shaken.
- **Bloom cap:** a seed that grows into a bouncy mushroom.
- **Frost crystal:** a pickup that refreshes the freeze or the hold.
- **Cinder on ice:** a cinder touching ice melts it and drowns in the puddle.
- **Slow climb on mud:** holding up/down on mud moves you slowly, instead of only staying put.
- **Wet vine monkey** grows bigger and slower.
- **Gust dries:** wind slowly dries wet tiles.
- **Rain:** a room where water falls from the ceiling all the time (cheap with sources; watch the particle cap).
- **A water diamond** to give a full ball far from any water.
