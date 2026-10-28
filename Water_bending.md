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
| **2** | **Freeze.** Tap: freezes the water you're holding, else the water you last threw, else the water you're touching (§5.3) |

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
| **W6** | Ice slides: one-way polylines, `Sliding` state, slopes, ramps | Fling a snake arc over a spike pit, freeze it into a slide and ride it across |
| **W7** | ~~Swimming~~ (built early, after play-test 1: §16 "Decided in Stage W1"), currents (they carry a swimmer), floating objects riding waves and streams, enemies in deep water | Swim through a pool, ride a stream on a floating crate |
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
