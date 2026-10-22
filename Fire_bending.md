# Windbound: Fire bending (Chapter 3)

*Spec v1, 21 Oct 2026. Companion to `GAME_DESIGN.md` (core + Air) and `Earth_bending.md` (Earth). Every number marked* **(tune)** *lives in `FireTuning` and is exposed in the live tuning menu (the in-game tuning panel, F5, built in Stage F2). Play-test decisions go in §13. The build stages are planned in §11 and written out as prompts in `PROMPTS.md` (Stages F0–F15); the rules agreed while planning are in §13 "Decided in Stage F0" and override older text above them.*

---

## 1. The idea in one paragraph

Fire is the element of **spending**. You carry a small, **non-refilling** fire bar made of red-orange **pips**, and every pip you burn is gone until you find more, either from an orange **fire diamond** or by **burning an air diamond** to turn it into one. A pip buys you one **fireball** or one half-second **flame jet burst** that you steer while it surges and dies down. Fire does not stay where you put it: **grass burns like a fuse**, spreading tile by tile and leaving **ash** behind, and **leaf piles** go up as lasting **bonfires**. So Fire rooms are puzzles about *what to light, from where, and when*, and about not standing in the path of what you lit.

## 2. Pillars check

| Pillar | How Fire meets it |
|---|---|
| Movement first | The flame jet is a steerable, fuel-limited thrust in 8 directions. It's the chapter's main movement verb |
| One verb, three uses | Fireball and jet each have a movement, puzzle and combat use (§5) |
| Fail fast | R resets fire, ash, bonfires, pips and diamonds. Touching flames kills like spikes |
| Readable | Fire and everything fire-owned is red-orange. Ash is dark gray. Fire diamonds are orange; the air diamonds they're made from keep their Air colors (green wind crystal, blue gust diamond). No health bars: flames kill, so you stay out of them |

## 3. Keys

| Key | Action |
|---|---|
| **Q** | **Fireball.** Tap = throw in the arrow direction (facing direction if no arrow). Hold = slow-motion aim (world 0.3×, aim moves in real time, like the gust); release throws |
| **W** | **Flame jet.** Press = fire a fixed-length **burst** (1 pip) toward the arrow direction, steerable live in 8 directions while it burns. Flame pours out the opposite side. **Holding W** at the end of a burst chains the next pip. Jump (C) cuts a burst short, and the pip is still spent |

Both keys are new and clash with nothing: Q and W sit above A/S (Earth), so each element has its own row, and the arrows stay free for movement (changed from D/F in Stage F3, see §13). C (Jump) cancels a fireball aim without spending a pip.

The jet is **steered, not aimed**. You fly it continuously, so it does **not** slow the world (same logic as running). Only the fireball aim, which commits a resource to one direction, slows time.

## 4. The fire bar

### 4.1 Pips
- One shared bar feeds both moves. **1 pip = 1 fireball = 1 jet burst of 0.5 s** **(tune: `jet_burst_time` = 0.5)**.
- **Pips are always whole.** Every fireball and every jet press costs exactly one full pip, spent at the moment of the press. Nothing is ever left half spent.
- **Max pips: 5** **(tune: `max_pips`)**. Pips start at **0** in a room unless the room sets `fire_start_pips` (rooms 1–2 start with some).
- **Pips are per room** (decided in F0): entering a room, dying or pressing R sets the bar to that room's `fire_start_pips`. Pips left over from the previous room are dropped, so every room is a self-contained budget.
- **Pips never refill on their own**: not from the ground, time or updrafts.
- **At 0 pips:** the fireball "fizzles" (a puff of smoke, short click, no projectile). A jet press with no pips sputters: a dry cough of smoke from the nozzle and no thrust. When you hold W to chain with no pips left, the last burst ends in that same sputter, so running dry is readable.

### 4.2 HUD placement: a row over the player's head, **above** the white gust pips
- The pips float over the player's head, like the gust pips (decided in F0). Unlike the gust pips, which show only while airborne, the fire row is **always visible** in rooms where fire is allowed: pips are a budget you plan with, on the ground too.
- Fire pips are gained and spent constantly. A row of their own means the **gust pips never shift sideways** when the fire count changes.
- **Two stacked rows read as two separate pools.** Pips side by side read as one long bar, which would suggest gusts and fireballs share a resource. They don't.
- It leaves room for the parked "one bar per element" plan: elements stack upward, the active one on top.
- In Fire-only rooms there are no gust pips, so the fire row sits in their slot just above the head; in mixed rooms it sits one row higher.
- **Look:** each pip is a tiny 3×4 flame that flickers out of sync with its neighbors. An empty pip is a dim ember outline. A spent pip **snuffs out at once** with a 2-frame flash and a puff, never a slow drain, so the HUD only ever shows whole pips. On gain, the new pip flares up from a spark.

### 4.3 Fire diamonds
- An **orange diamond**, with a small flame licking inside it. Touching it adds pips:
  - single-tick fire diamond: **+1 pip**
  - double-tick fire diamond: **+2 pips**
  - extra pips above the cap are lost
- **Single use per room life.** A collected fire diamond does not respawn until death or R. This keeps fire a budget, like earth tiles.
- **Converting air diamonds:** "air diamond" in this doc means the two existing Air pickups (decided in F0): the green **wind crystal** counts as single (→ **+1** fire diamond) and the blue **gust diamond** as double (→ **+2**). Any flame touching one turns it into a fire diamond of that size. Fireballs, the jet, burning grass and bonfires all count. The conversion is a short animation: green/blue → orange wipe from the touching side, then a flare. A converted diamond stays a fire diamond until reset, and like every fire diamond it's single use (it no longer respawns like a crystal).
- **Pick-up in passing:** you can fly the jet through a diamond to collect it mid-thrust. Chains of diamonds become fuel routes, the fire version of the wind-crystal chain.

## 5. Moves

### 5.1 Fireball (Q)
- **Flight:** 8×8 hitbox, **200 px/s** straight line **(tune: `fireball_speed`)**. No gravity, max range 160 px **(tune)**, then it gutters out. Costs **1 pip**.
- **On hit:** ignites what it hits plus anything flammable within **6 px** **(tune: `fireball_splash`)**, then bursts.
- **Recoil:** none. Recoil movement was rejected in the element design; the jet is the movement.
- **Movement:** opens routes by burning vines and thicket walls, and lights fuses to braziers that open doors. It's indirect, which is fine because the jet carries the direct movement.
- **Puzzle:** light things you can't reach, light a fuse from far away, convert an air diamond across a gap, burn a crate off a plate.
- **Combat:** defeats wisps in one hit. **Cancels an orb head-on** (both burst). **Destroys a sentry**, but it costs a pip, so reflecting orbs with Air or a rock with Earth stays cheaper in mixed rooms.

### 5.2 Flame jet (W)

The jet is a **committed burst**: one press = one pip = one fixed-length burst you steer while it burns. Control stays predictable; the chaos is in how it looks (§9.3).

- **The burst:** pressing W spends 1 pip and starts a burst of `jet_burst_time` (0.5 s). The burst runs to the end even if W is released. **Gravity is off** during the burst. No arrow = thrust straight up.
- **Thrust curve (the flame tapering):** a burst pushes hard at ignition and tapers toward the end, like a flame bursting and dying. The curve is the same every time, so it can be learned. It's fully tunable:

| Tuning | Start | Meaning |
|---|---|---|
| `jet_burst_time` | 0.5 s | Length of one burst (= one pip) |
| `jet_max_speed` | 170 px/s | Base top speed, multiplied by the curve below |
| `jet_accel` | 1400 px/s² | Base acceleration toward the steered direction, multiplied by the curve |
| `jet_thrust_start` | 1.3 | Thrust multiplier at ignition |
| `jet_thrust_end` | 0.8 | Thrust multiplier at the end of the burst |
| `jet_thrust_curve` | `Curve` resource, ease-out from start to end | Shape of the taper over the burst's normalized time (0 → 1). It's edited visually in the Inspector and overrides the straight start→end line when set |
| `jet_turn_accel` | 3000 px/s² | Acceleration used to **change direction** (sideways to current velocity). Kept high so the burst feels steerable even though it can't be stopped |
| `jet_end_carry` | 1.0 | Fraction of velocity kept when a burst ends (1.0 = keep it all) |

  The multiplier at time *t* in the burst = `jet_thrust_curve.sample(t / jet_burst_time)` if a curve is set, otherwise `lerp(jet_thrust_start, jet_thrust_end, t / jet_burst_time)`. It scales both `jet_max_speed` and `jet_accel`. All values are exposed in the live tuning menu.
- **Steering:** the arrows steer live throughout the burst (8 directions). Turning uses `jet_turn_accel`, so a sharp change of course happens quickly, while the top speed still follows the curve.
- **Chaining:** if W is **still held** when a burst ends and you have a pip left, the next pip fires straight away with a visible **"pump" flare**. Each chained burst restarts the thrust curve, so a long flight is a rhythm of surges. Letting go of W means the current burst finishes and nothing more is spent.
- **Cutting short:** pressing **Jump (C)** during a burst ends it immediately. The pip is **still spent**: an escape from a bad line that never refunds fuel. Normal gravity takes over at once.
- **End of a burst:** you keep `jet_end_carry` of your velocity, then normal gravity takes over (with apex half-gravity as usual).
- **Distance guide:** one full burst carries you roughly 80–90 px in a straight line, more than twice a dash. Room layouts should be built around that, and re-measured whenever the curve is retuned.
- **The exhaust:** a flame plume **24 px** long **(tune: `jet_plume_length`)**, 8 px wide at the nozzle, fanning to 14 px, pointing opposite to the thrust.
- **The exhaust ignites anything flammable it touches:** grass, leaf piles, vines, braziers, crates, sails, leaf platforms, air diamonds (conversion), wisps.
- **You are immune to your own jet.** Other flames still kill you.
- **Movement:** the main traversal tool. You can cross gaps, climb shafts, make mid-air corrections, and chain through fire diamonds.
- **Puzzle:** your take-off scorches the grass under you, so taking off from grass **starts a fire behind you**. A sideways jet along the ground is a moving fuse. Rooms can ask you to light a long grass run by jetting along it.
- **Combat:** the plume burns wisps that chase you, like the dash wake. Orbs pass through the plume and still hit you, so the jet is not a shield.

### 5.3 Hot updrafts (from bonfires and burning grass)
- A **lit leaf pile** becomes a bonfire with a hot updraft column above it, **48 px** tall, 16 px wide **(tune)**.
- **A burning grass or thicket tile** gives a short, weak updraft of 16 px for as long as it burns.
- **Hot updrafts affect only these things:**
  1. **Gliding (Air):** a gliding player is lifted, as in an Air updraft but stronger (lift **(tune: `hot_updraft_lift`)**).
  2. **Gusts (Air):** a gust fired from inside a hot updraft is **×1.5 force and ×1.25 cone length** **(tune)**. Add a visual cue: the cone is tinted orange and carries sparks.
  3. **Hot-air objects:** the balloon platform, the heat sail and the windmill (§6.4). This is what gives hot updrafts a job in Fire-only rooms.
  4. **Light things:** leaflings (§7), embers, smoke and ash flakes.
- **Nothing else is lifted:** not the player on foot, not the jet, not crates, rocks or other enemies.
- **Implementation:** reuse the Air `WindZone` updraft with new flags: `heat = true` (so it only acts on glide, gusts and anything in the `heat_receiver` group) and `gust_multiplier = 1.5`.

### 5.4 Gust against fire (mixed Air + Fire rooms)

A gust is wind. It **blows small fires out** but **feeds big ones**.

| Fire | Effect of a gust |
|---|---|
| **Burning grass / thicket tile** | Snuffed: the tile turns to **ash at once** (grass ash stays as a firebreak; thicket ash crumbles away as usual). The hazard ends early and the tile doesn't spread any more. Smoldering tiles are unaffected |
| **Fireball in flight** | Snuffed in a puff of smoke. The pip is lost |
| **Burning vine** | The burn stops. The burnt part is gone, the rest stays intact and can be lit again |
| **Burning crate** | Snuffed: the crate is **charred** (black, still solid and usable) and can be lit again |
| **Burning leafling** (living torch) | Snuffed: it smolders, is stunned for 1 s, then carries on as a normal leafling. It can be lit again |
| **Brazier** | **Not affected**: its flame is protected by the bowl |
| **Bonfire** | **Flares up** for `bonfire_flare_time` (1.5 s) **(tune)**: flame ×1.6 taller and wider (the kill zone grows), **blue base**, and its updraft is ×1.5 stronger and taller **(tune)**. A flare pumps balloons and heat sails harder. Gusting again during a flare restarts its timer |

The gust only acts on fire inside its cone. An "all around" gust snuffs and flares everything in its radius.

## 6. Materials and objects

### 6.1 Burnable tile states (the fire grid)

| State | Look | Behavior |
|---|---|---|
| **Grass** | As now | Flammable. Earth shadow crosses it |
| **Burning** | Flame tongues along the surface | **Kills on touch.** Ignites its neighbors after `spread_delay`. Burns for `burn_time` |
| **Smoldering** | Black, glowing ember specks, thin smoke | **Harmless.** Can't ignite neighbors. Lasts `smolder_time`, then turns to ash |
| **Ash** | Dark gray crust, pale flecks | Solid ground, **never burns again**: a firebreak. Earth shadow crosses it (like grass). Ash flakes get kicked like pebbles |

Starting values, all to be tuned live:

| Tuning | Start | Meaning |
|---|---|---|
| `spread_delay` | 0.25 s | Burning tile → neighbor ignites |
| `spread_jitter` | ±0.06 s | Random variation per tile, so the front looks alive and not like a metronome |
| `burn_time` | 1.0 s | How long a tile is a hazard |
| `smolder_time` | 0.6 s | Harmless glow before ash |
| `max_burning_tiles` | 96 | Safety cap. Extra ignitions queue |

**Neighbors:** fire spreads along **connected grass surface tiles**: left and right along floors, up and down along grassy walls, and around corners (the same surface-walking the Earth shadow uses, so reuse that code). It does not jump through air or through non-flammable tiles.

**Not flammable:** earth (fresh, used, hardened), gray rock, cracked walls, ash, ice (later), metal objects. Earth creations (columns, snakes, rocks) don't burn.

### 6.1b Plant terrain: thicket and overgrown covers

Fire can **burn its way through** plant terrain. That is how Fire opens paths and reveals secrets, the counterpart of Earth's cracked walls and hidden chambers.

| Material | Look | Behavior |
|---|---|---|
| **Thicket** | Dark green tangled brambles with thorny edges, clearly plant and clearly solid | Solid wall, floor or ceiling tiles. **Flammable through its whole volume**: fire spreads to the 4 neighboring thicket tiles, and to and from touching grass. Burning thicket kills on touch. When it's done burning, it **crumbles into falling ash and leaves empty space**. A burning thicket floor drops you; a burning thicket ceiling opens the way up. The Earth shadow crosses it like grass; it can't be bent or torn. Thrown rocks shatter on it |
| **Overgrown cover** | Looks like ordinary grass-topped ground or a thicket wall. **One small tell**: a few hanging root tendrils or a slightly different shade at its edge | When fire reaches any tile of it, the **whole cover flashes over** in about 0.3 s and burns away, revealing a hidden passage or chamber. This is the same rule as Earth's hidden chamber, where the whole cover crumbles at once. Hidden chambers often hold fire diamonds, or air diamonds that the flash-over converts |

| Tuning | Start | Meaning |
|---|---|---|
| `thicket_spread_delay` | 0.15 s | Faster than grass: thicket is dry fuel |
| `thicket_burn_time` | 0.8 s | Hazard time before it crumbles |
| `overgrown_flashover_time` | 0.3 s | How fast a whole cover burns away |

### 6.2 Flammable objects

| Object | When ignited |
|---|---|
| **Leaf pile** | Becomes a **bonfire**: a 16×20 flame that kills on touch and gives a hot updraft. Lasts until reset **(tune: `bonfire_duration`, 0 = forever)**. Anything it was hiding is revealed (a hidden air diamond is converted straight away). Ignites neighboring grass |
| **Vine** (new) | Burns from the touched point outward along its length in 0.6 s. Whatever it held (a platform, a crate, a gate) **falls or opens**. Vines are ropes and barriers only: not climbable, no new movement verb |
| **Brazier** (new) | Iron bowl. Lit = stays lit and opens its linked door, like a windmill but permanent. Some rooms use **timed braziers** that go out after N seconds |
| **Crate** (Air) | Burns for 1.5 s (kills on touch, ignites grass under it), then collapses into an ash pile, so the crate is **gone**. This lets you clear a crate off a plate, or loses one you needed. ⚠ confirm in play-test |
| **Leaf platform / sail** (Air, mixed rooms) | A leaf platform burns away in 0.8 s. A burning sail stops catching wind, and the platform coasts to the end of its rail |
| **Air diamond** | Converted to a fire diamond (§4.3) |

### 6.3 New objects and tiles (summary)
- Fire diamond (single, double)
- Vine
- Brazier (permanent, timed)
- Thicket tiles, overgrown cover (§6.1b)
- Balloon platform, heat sail (§6.4); the existing windmill gains heat behavior

### 6.4 Hot-air objects

These are moved by **hot updrafts** (§5.3), never by the player directly. They give fire a **continuous** push, in contrast to the gust's discrete shoves. They're objects, not abilities, so they work in Fire-only rooms. All of them join the `heat_receiver` group.

| Object | Behavior |
|---|---|
| **Balloon platform** (new) | A round envelope above a 16 px wide basket. The basket top is a solid platform. It sits on a vertical track (or rises freely up to a ceiling). **While its mouth is in a hot updraft it rises** (up to 30 px/s, faster during a bonfire flare). **When the heat stops it sinks slowly** (15 px/s) back to its rest point. A permanent bonfire under it lifts it to the top and holds it there. A burning grass run gives a short lift. **The envelope is flammable:** a fireball, the jet or any flame touching it burns it in 0.5 s, and the basket drops. That's a trap if you're careless, or a way to drop it on purpose |
| **Heat sail** (new) | A platform on a rail with a sail. **While a hot updraft overlaps the sail, it's pushed along the rail continuously** toward the rail's drive end (accelerating up to 40 px/s). Outside heat it slows to a stop (no sliding back unless the rail slopes). A burning grass run under the rail moves it in steps; a bonfire drives it all the way. The sail is flammable: if it burns, the platform coasts and stops |
| **Windmill** (existing, Air) | **A hot updraft under its blades spins it continuously** and holds its door open. When the heat stops, it winds down and the door's normal timer starts. A windmill out of reach is driven by lighting the grass below it (a short window) or a bonfire (permanent). The blades don't burn |

| Tuning | Start |
|---|---|
| `balloon_rise_speed`, `balloon_sink_speed` | 30, 15 px/s |
| `balloon_envelope_burn_time` | 0.5 s |
| `heat_sail_accel`, `heat_sail_max_speed`, `heat_sail_friction` | 80 px/s², 40 px/s, 60 px/s² |
| `windmill_heat_spin` | Spin rate while heated (same scale as gust spin) |

## 7. Enemies

### 7.1 Existing enemies

| Enemy | Fire interaction |
|---|---|
| **Wisp** | Dies to a fireball, the jet plume, burning tiles or bonfires. Wisps don't avoid fire, so a fuse can be timed to meet a patrol |
| **Sentry** | A fireball destroys it (1 pip). A fireball cancels an orb head-on. The sentry is metal, so burning grass under it does nothing |

### 7.2 New enemies: one per element, each a wall for the others

**Rule:** each element gets an enemy that **only its own element can kill**. In its home chapter it's an enemy; in other chapters it's an obstacle you dodge, push or route around. Mixed rooms then ask "which element does this one need?"

**Leafling** (home: **Fire**)
- **Look:** a small walking leaf-creature, green with a lighter vein pattern, about 8×8. It hops along its patrol with a papery flutter.
- **Behavior:** patrols like a wisp and kills on touch. It's light, so **hot updrafts lift it**: leaflings drift upward over fires.
- **Only fire kills it.** Spikes don't (it's too light: it lands on them harmlessly). Rocks knock it back but don't kill it (a big rock knocks it further). Gusts blow it far but don't kill it, and wind carries it. Earth columns launch it; the snake head shoves it.
- **On ignition, it becomes a living torch:** it panics for `leafling_torch_time` (1.5 s) **(tune)**, running fast (120 px/s) in its current direction and turning at walls and ledges. It **ignites everything flammable it touches** (grass, thicket, leaf piles, vines, air diamonds) and still kills on touch. Then it crumbles to ash.
- **Puzzle use:** a leafling is a **moving fuse**. Light one and it carries fire where you can't reach: across a gap it patrols, into a sealed thicket room, under a windmill.
- **A gust** snuffs a burning leafling (§5.4).

**Shell** (home: **Earth**; armored)
- **Look:** a squat armored crawler, about 12×8. Slate-gray plates with ochre seams, so it's clearly "earth, but tougher".
- **Behavior:** a slow patrol (25 px/s) that kills on touch and turns at ledges and spikes.
- **Only a big rock (boulder) kills it.** That means a thrown 16×16 rock, or a loose big rock falling onto it from at least 2 tiles ⚠ confirm.
- **Everything else is shrugged off:**
  - A small rock **staggers** it: it stops for 0.5 s and is knocked back 4 px.
  - Spikes don't hurt it.
  - Crushing doesn't hurt it either: a rising column lifts it or the snake head shoves it one tile, but neither kills it.
  - A fireball sparks off its plates harmlessly (the pip is still spent).
  - The jet and flames don't hurt it, and it walks through burning grass.
  - Gusts barely nudge it (heavy). Orbs bounce off it.
- **Puzzle use in Fire rooms:**
  - Burn the thicket floor under it to drop it somewhere harmless.
  - Ride a balloon over it.
  - Time your crossing against its slow patrol.
- **Home chapter note:** the Shell is an **Earth chapter** enemy. Add it to `Earth_bending.md` as an addendum, with a new Earth room ("Armor", using big rocks against Shells) once the Earth play-test is done. It's built in Fire stage F12 because Fire rooms need it as an obstacle, and its boulder kill uses the existing big-rock hit hook.

| | Wisp | Sentry | Leafling | Shell |
|---|---|---|---|---|
| Fire | dies | dies (fireball) | **dies (torch run)** | immune |
| Big rock | dies | dies | knocked back | **dies** |
| Small rock | dies | dies | knocked back | staggered |
| Gust | stunned | reflects orbs | blown away | nudged |
| Spikes | dies | n/a | immune | immune |

## 8. Player

- **Touching any flame kills you,** except your own jet plume. That covers burning tiles (grass and thicket), bonfires (including the bigger flare), burning crates, vines and balloon envelopes, burning leaflings, and fireballs (you can't hit yourself with your own; they start outside your hitbox).
- **Burning floors fall away.** When a thicket floor you're standing on crumbles, you fall like from any ledge.
- **New state `Jetting`:** gravity off, thrust on the tapering curve, steering, burst timer. It exits when the burst ends without a chain, on a Jump cancel, or when you hit a ceiling head-on (bonk with a short stun-free stop; the pip is spent either way).
- **The fireball aim** reuses the gust aim state: on the ground you stay put, in the air you keep drifting at 0.3×, exactly like the gust aim.

## 9. The look: fire must feel alive

Placeholder rules still apply (shapes, lines, particles, one color family per type). "Alive" comes from **motion**, not texture. Every flame **flickers, sways, throws embers and smokes.**

### 9.1 Palette (fire family only)

| Use | Color |
|---|---|
| Core | `#FFF6CC` pale yellow-white |
| Inner | `#FFD34D` yellow |
| Body | `#FF8A1E` orange |
| Edge | `#E8431A` red-orange |
| Ember | `#8A2410` deep red |
| Smoke | `#2E282B` at 40–60% alpha |
| Ash | `#4A4545` with `#7A7470` flecks |
| Flare base (hottest, only during a bonfire flare) | `#BFE6FF` core, `#4FA3FF` edge |

Use **additive blending** (`CanvasItemMaterial.blend_mode = ADD`) for the core, inner and glow layers. The red edge and smoke use normal blending, so flames read on dark ground and on bright crust.

### 9.2 Building blocks (one script each, reused everywhere)
1. **`FlameTongue`:** a 5–7 vertex polygon whose top vertices are driven by `FastNoiseLite` (time-scrolling, per-instance seed), so the tip licks and splits. It's drawn in 3 nested layers (edge, body, core), each slightly smaller and faster. Height breathes ±20% on slow noise.
2. **`EmberEmitter`:** `CPUParticles2D` with 1-px sparks that rise with jitter, curl sideways on noise, and fade from yellow → red → nothing. They pick up wind and gusts through the existing pushable/wind hooks.
3. **`SmokeEmitter`:** 2–4 px soft squares that rise slowly, grow, drift with wind, and fade. They're sparse; smoke is a hint, not fog.
4. **`HeatGlow`:** an additive soft circle under each fire source that flickers in radius and alpha on noise. It lights the ground and walls around the fire without a lighting system. (`PointLight2D` stays optional, off by default.)
5. **`HeatShimmer`** (optional, toggle in tuning): a small screen-texture shader rectangle above big fires (bonfires, burning runs) with a gentle vertical wobble. Off by default in case it costs too much.

### 9.3 Per source

| Source | Look |
|---|---|
| **Fireball** | Bright 6 px core + 3 orbiting tongues + a fading trail of embers and puffs. It wobbles slightly as it flies (visual only, the hitbox is straight). **Impact:** flash frame, a ring of 10–14 sparks, a smoke puff, 1–2 embers that stick to the surface and glow for 0.5 s |
| **Fizzle** (0 pips) | A small smoke puff from the hand and 2 dull sparks |
| **Flame jet** | The nozzle at your feet/back has a white-hot cone that flickers in length (±3 px). Body particles stream along the plume, widening, cooling yellow → orange → red and turning to smoke at the tail. A heat glow sits on the player. Light constant shake while thrusting (very small) plus squash along the thrust axis. **The plume follows the thrust curve:** longest and whitest at ignition, shrinking and reddening as the burst tapers. The plume sprays and stutters (random flicker, ember spray), but the player's motion stays clean. **Ignition:** a "whoomp" burst ring. **Chain pump:** a bright flare and a ring of sparks at the nozzle as the next pip fires. **Jump cancel:** the flame snaps off in a puff. **Sputter** (no pips): the cone chokes in three gasps, then smoke |
| **Burning grass** | The blades curl and blacken from the base, 2–3 short tongues per tile, out of phase with their neighbors. **The fire front is the brightest part:** each newly ignited tile flares for 0.1 s, so the eye follows the spread. Smoke rises from tiles behind the front |
| **Smolder → ash** | Glowing specks that blink out one by one. Ash flakes lift and drift when you walk, gust or jet near them |
| **Bonfire** | 5–7 overlapping tongues of different heights, a tall smoke column bending with wind, sparks popping upward in bursts every 0.5–1.2 s (random), and a strong heat glow. The hot updraft above shows rising embers and shimmer |
| **Vine burn** | A glowing line runs along the vine, leaving a black thread that snaps and falls in pieces |
| **Brazier** | Small steady flame (less flicker = "controlled fire"). Lighting it gives a flare plus a ring of sparks. Timed braziers shrink as their time runs out and gutter for the last second |
| **Diamond conversion** | The white diamond catches from the touching side, an orange wipe crosses it, then it flares and settles into the fire diamond's idle flicker |
| **Bonfire flare** (gust) | The tongues stretch ×1.6 with a roar-like pulse. A **blue band rises from the base** (pale blue core, blue edge), creeping up about a third of the height. Sparks burst sideways in the gust's direction, the glow brightens, and the updraft's embers race upward. Over the last 0.3 s the blue sinks back into the base |
| **Snuff** (gust on a small fire) | The flame bends hard in the gust's direction, thins and blows off as a curl of smoke and a few sparks carried downwind. A snuffed tile shows a brief gray puff before its ash |
| **Thicket burn** | The brambles glow from inside along their branches before the flames break out. The burning mass sags and drops clumps of glowing ash, then the whole tile crumbles into a shower of flakes that fall and drift |
| **Overgrown flash-over** | A bright line races across the whole cover's outline, the cover flashes as one sheet of flame, then collapses in a single burst of ash and embers. Freeze frame 2 frames + shake, like a cracked wall breaking |
| **Leafling torch** | A leaf with a flame on its back, leaving a trail of sparks and smoke. It flickers more wildly as it runs out of time and shrinks to a black curl before crumbling |
| **Balloon** | The envelope swells slightly and glows warmer while heated, and the basket sways. A burning envelope blackens from the touched spot, rips and flaps down as burning tatters |
| **Heat sail** | The sail bulges toward the drive end while heated, with embers streaming past it |

### 9.4 Feel
- Big actions get big reactions: a lit bonfire = short screen shake + flash. Fire reaching a brazier = freeze frame 2 frames + shake.
- Embers and smoke count toward the existing per-room particle cap. Fire FX degrade gracefully: fewer embers first, then smoke.
- SFX hooks: `fire_ignite`, `fire_crackle_loop` (volume by burning tile count), `fireball_throw`, `fireball_hit`, `jet_start`, `jet_loop`, `jet_sputter`, `fizzle`, `diamond_convert`, `brazier_lit`.

## 10. Architecture (reuse first)

- **`FireTuning`** resource: all numbers above, exposed in the live tuning menu. Spread speed is meant to be dialed in there.
- **Tuning panel** (Stage F2): an in-game overlay (F5) generic over every tuning resource (`PlayerTuning`, `EarthTuning`, `FireTuning`), built from their `@export` groups so new values show up by themselves. Keyboard only, live changes, the existing F4 `debug_save_tuning` key (today it saves only `PlayerTuning`) writes all of them back to their `.tres`. `Curve` values are edited in the Inspector.
- **`FireBar`**: a component on the player holding pips as a **whole number**. `spend()` returns false at 0. Signals `pips_changed` and `ran_dry` for the HUD and FX.
- **`FireballAbility`** and **`FlameJetAbility`**: components under the player using `FireBar`, the same shared-core pattern as the Earth bend.
- **`FireGrid`**: a per-room node that owns burnable tile states, the spread queue and the cap. It reuses the Earth shadow's surface-walking for neighbors. It joins the room reset group.
- **`Flammable` contract** (like `Pushable`): `ignite(source)`, `is_burning()`, `snuff()` (for gusts), group `flammable`. Leaf piles, vines, braziers, crates, sails, balloon envelopes, air diamonds, wisps and leaflings implement it. Bonfires answer `snuff()` by flaring.
- **`HeatReceiver` contract:** `apply_heat(strength, delta)`, group `heat_receiver`. Balloons, heat sails, windmills and leaflings implement it.
- **Thicket and overgrown covers** live in `FireGrid` as extra tile states. Spread through thicket uses 4-neighbors; grass keeps surface-walking.
- **`ElementImmunity`** on enemies: a small per-enemy table (which hits kill, stagger, push or are ignored), so the wisp, sentry, leafling and Shell share one damage path instead of special cases.
- **`FireHazard` group**: anything that kills on touch, checked by the same code path as spikes.
- **Rooms:** new flags `fire_allowed` and `fire_start_pips`. Chapter rooms are Fire-only (Air and Earth off) and built like the Earth ones: generated by a tool script, with painted ground (`GroundPainter`) and `Grass` layers. The main menu gets "Fire chapter", "Fire test rooms", "Air + Fire test rooms" and "Earth + Fire test rooms".
- **Headless smoke test** for the fire chapter, like the others: every room loads, pips and grid reset on R, no runaway burning count.

## 11. Build stages

Planned in Stage F0 (replaces the first 9-stage draft): the jet comes right after the fire bar, because it's the chapter's movement verb and needs the most play-test time, and the big stages are split so each one is a single mechanic with its own test room. The full prompts are in `PROMPTS.md`.

| Stage | Contents | Done when |
|---|---|---|
| **F0** | Plan the chapter (this table, §13 "Decided in Stage F0") | Docs updated |
| **F1** | `FireTuning`, `FireBar`, flame pips above the head, fire diamonds (+1, +2, single use), `Room.fire_allowed` + `fire_start_pips` (per-room pips), `fireball` / `flame_jet` actions (first D/F, Q/W since F3), fire test world + smoke test | Pips gained and shown; R resets them to the room's start; a debug key spends one |
| **F2** | In-game tuning panel (F5) for Player/Earth/Fire tuning; F4 saves every tuning `.tres` | Any tuning value changes live from the keyboard and survives a restart once saved |
| **F3** | Flame jet: `Jetting` state, bursts, tapering thrust curve, steering, hold-to-chain, Jump cancel, ceiling bonk, sputter; first `FlameTongue` + `EmberEmitter` for the plume | Cross a 10-tile gap on 1 burst; climb a shaft with a 3-pip chain; every curve value changes the feel live |
| **F4** | Fireball (tap, hold-aim, fizzle), `Flammable` contract, `FireHazard` group, braziers (permanent, timed) + doors; the plume ignites flammables | Light a brazier from across a room, with a fireball or the jet |
| **F5** | `FireGrid` on grass: burning, smolder, ash, surface spread, kill on touch, cap, reset; jet take-off scorches grass | A grass fuse runs and kills you if you stand in it; ash stops it |
| **F6** | Thicket tiles (burn through their volume, crumble to open air) + overgrown covers (flash-over) | A thicket wall burns open; a thicket floor drops you; a cover flashes over to reveal a chamber |
| **F7** | Leaf pile → bonfire, hot updrafts (`WindZone.heat`, `heat_receiver` group), air diamond conversion | A bonfire lifts a glide; a burnt pile's hidden crystal becomes a fire diamond |
| **F8** | Vines; Air objects burn (crate, leaf platform, sail) | A vine burns and drops what it held; a crate burns off a plate |
| **F9** | Hot-air objects: balloon, heat sail, windmill heat spin | A bonfire lifts a balloon; burning grass spins an out-of-reach windmill and steps a heat sail |
| **F10** | Gust vs fire (§5.4: snuff, bonfire flare) and gusts boosted in hot updrafts | A gust snuffs grass and flares a bonfire, and the balloon surges |
| **F11** | `ElementImmunity`; wisp/sentry/orb fire hooks; Leafling (torch run, updraft lift, snuffed by gusts) | A lit leafling carries fire across a gap; fire kills wisps and sentries as written |
| **F12** | Shell (big rock only) | Every cell of the §7.2 table behaves as written, in a test room |
| **F13** | Look & feel pass (§9) across every source, SFX hooks | It looks alive in a still screenshot *and* in motion |
| **F14** | Fire rooms 1–10 (generated), `fire_world.tscn`, chapter smoke test, main menu entry | Chapter playable start to Goal |
| **F15** | Mixed test rooms: Air + Fire, Earth + Fire | Both on the main menu, every §12 mixed idea has a spot |

A basic flame (one `FlameTongue` + embers) exists from F3, so every later stage is tested with fire that already looks like fire. F13 is the full pass.

## 12. Rooms (draft)

1. **Kindling:** start with 2 pips. Throw a fireball at a brazier to open a door. Second brazier behind a gap: the fizzle teaches that pips run out.
2. **The Fuse:** a long grass run leads to a far brazier. Light it, then shelter on gray rock as the front passes. Spread speed sets the room's pace.
3. **Burning Bridges:** vines hold a platform up; a thicket wall blocks the way; a thicket floor drops you into the next section. The order matters.
4. **Ember Diamonds:** the first fire diamonds, double-tick, and converting air diamonds across a gap with a fireball.
5. **Jet:** the flame jet. A diamond chain is a fuel route; taking off from grass lights a fire behind you that chases you to the next safe ledge.
6. **Hidden Heat:** leaf piles hide air diamonds; burning a pile converts what it hid. An overgrown cover hides a chamber with a fire diamond: find the tell, light the fuse.
7. **Hot Air:** light a bonfire under a balloon to ride it up; a grass run steps a heat sail across a pit; an out-of-reach windmill spins while the grass below it burns. Don't set the balloon on fire.
8. **Leaflings:** the fire enemy. Kill them with fireballs, or light one as a moving fuse to reach a brazier behind a gap. Wisps return too.
9. **Wildfire:** scrolling room. A grass fire is lit behind you at the start and the front chases you. Shells you can't kill block the way, so burn thicket floors to drop them, or ride over them. Sentries cover the end.
10. **Summit:** everything together, the Goal.

**Mixed test rooms:**
- **Air + Fire:**
  - bonfire elevators with glide
  - gust a bonfire into a flare to pump a balloon higher
  - snuff a grass fire to make a safe path
  - enhanced gusts in hot updrafts pushing heavy loads
  - a burning sail platform
- **Earth + Fire:**
  - a Shell and leaflings together (boulders for one, fire for the other)
  - a leafling launched by a column into a leaf pile
  - a rock foothold beside a thicket wall you burn open

## 13. Decision log (play-test)

### Decided in Stage F0 (planning)

These were agreed when planning the build. Where they differ from the sections above, this list wins.

- **Stage order:** the jet is built right after the fire bar (F3), before the fireball and burning. Stages are small, one mechanic each (§11).
- **Tuning panel:** the "live tuning menu" doesn't exist yet; Stage F2 builds it as an in-game overlay (F5; F4 is already the save key) over every tuning resource. Changes apply live, and F4 (`debug_save_tuning`) writes all three resources back to their `.tres`. The jet's `Curve` is still edited in the Inspector.
- **Air diamonds** are the existing wind crystal (→ +1 fire diamond) and gust diamond (→ +2). No new white diamond object.
- **Pip HUD:** a row of flames over the player's head, always visible where fire is allowed, above the gust pips in mixed rooms (§4.2).
- **Pips are per room:** entering a room, dying or R sets them to the room's `fire_start_pips` (§4.1).
- **Keys:** `fireball` on D, `flame_jet` on F. The unused `earth_snake` action (still bound to D) is removed in F1. *(Superseded in Stage F3: Q and W, see below.)*
- **Shell:** built in the Fire chapter, in its own stage (F12), after the leafling.
- **Rooms:** built like the Earth chapter: generated (`tools/build_fire_rooms.gd` for test rooms, `tools/build_fire_chapter.gd` for rooms 1–10), painted ground, Fire-only chapter rooms. Test rooms that need the glide or gust (F7, F10) allow Air too.
- **Full bar keeps the diamond** (Stage F1): a fire diamond is only used up when it adds at least one pip, like a wind crystal, so brushing past one with a full bar doesn't waste it. A double touched with room for one pip is used up and the second pip is lost.
- **Fire off by default:** `Room.fire_allowed` defaults to false (Air and Earth default to true), because the fire pips are always drawn where fire is allowed. Existing Air and Earth rooms are unchanged.
- **Testing:** every stage adds a test room to `tests/fire_test_world.tscn` and a section to `tests/fire_smoke_test.tscn`, like the Earth stages did.

### Decided in Stage F3

- **Keys moved to Q (fireball) and W (flame jet)** (21 Oct 2026, asked by the developer). Q/W sit right above A/S, so the elements read as rows: Earth on A/S, Fire on Q/W. D and F are free again.
- **Turning backwards counts as turning:** `jet_turn_accel` bleeds off the sideways part of the velocity *and* any part pointing against the steered direction (falling fast when you jet up). With only `jet_accel` (1400 × thrust), jetting out of a 300 px/s fall took a third of the burst just to stop falling.
- **Bonk = straight up only:** the burst ends on a ceiling only when thrusting straight up. A diagonal slides along the ceiling (and the corner correction still slips past edges).
- **Plume size:** at full thrust the plume is `jet_plume_length` long and white-hot; at the end of the taper it is 60% as long and orange-red. A chained burst restarts it.
- **Plume shape (F3 play-test):** the §5.2 width stays (8 px at the nozzle, fanning to 14 px; a narrower 5→8 px was tried and rejected), but the plume is a sheaf of `jet_plume_tongue_count` = 4 FlameTongues spread over `jet_plume_spread_degrees` = 14°, middle ones longest and whitest. The flames **dance**: each tip forks into two points that sway apart and rejoin (`jet_plume_fork_amount`), and small licks tear off the tips (`jet_plume_licks_per_second` = 40, `jet_plume_lick_lifetime` = 0.3 s), flutter, shrink and cool to red as the jet leaves them behind. Both live in `FlameTongue`, so braziers and bonfires get them too.
- **Measured:** one burst straight up from standing rises 80 px during the burst, then about 10 px more with `jet_end_carry` = 1 (smoke test prints it). Fire B's 10-tile gap is sized for that with a running start.
- The F1 debug key (F spends a pip) is gone: W spends pips for real now.
- Starting a jet: from Idle, Run, Jump, Fall, WallSlide, Glide and Launched (checked right after the dash and gust). Not from the Earth states or mid-dash/gust.

### Decided in Stage F4

- **Brazier flames don't kill.** They are not FireHazards, so lighting one with the jet (flying right past it) is safe. Burning grass, bonfires and burning crates will be.
- **Fireballs ignore enemies until Stage F11.** For now they hit walls (layer 1) and flammables (new physics layer 6, "flammable") only.
- **Fireball aim:** the GustAim state is shared, not copied. It talks to an "aim source" (GustAbility or FireballAbility) through a small duck-typed contract (written out in `fireball_ability.gd`). The fireball's aim uses `fireball_aim_time_scale` = 0.3 and throws by itself after `fireball_aim_max_real_time` = 0.8 s real time (the gust's is 0.4 s). No arrow held = thrown the way you face.
- **The pip is spent at the throw**, not at the press: the press only checks there is one (0 = fizzle). So Jump during the aim cancels for free.
- **Q works from** the same states as the jet: Idle, Run, Jump, Fall, WallSlide, Glide, Launched.
- **Timed braziers** have two notches on the post, so you can tell them apart before lighting. Relighting a lit timed brazier restarts its time.
- **Shared smoke:** `SmokePuff` (scenes/objects/fire/smoke_puff.gd) is the third fire building block for now; the jet, fireball and braziers use it.
- **F4 play-test changes:**
  - **Smoke:** every flame's torn-off licks burn for about half their life, then turn into smoke that floats up (whichever way the flame points), grows and fades. Flame tips also give off a thin smoke trail (`jet_plume_smoke_per_second`, `brazier_smoke_per_second`, `fireball_smoke_per_second`). The smoke is a lighter warm gray than §9.1's, which vanished against the dark sky.
  - **Fireball gravity:** `fireball_gravity_scale` = 0.2 of the player's gravity. On its own that made a level throw from standing hit the floor after about 25 px, so level throws get a **lift** (`fireball_arc_lift`, on) that cancels the drop over the full range: a gentle 14 px arc back to hand height at 160 px. The lift scales with how sideways the throw is.
  - **Held fireball:** while Q is held, a small dancing flame sits in the hand on the aim side (it dances at full speed even though the world is slowed).
  - **Aim preview:** an arc of embers along the fireball's real path (same gravity and lift), marching outward and cooling from yellow to red, ending in a flame star where it would hit a wall or flammable, or a gray puff where it would gutter out.
  - **Fireball mid-jet:** Q during a burst throws at once toward the steered direction: no slow-motion aim, and the burst keeps going. It costs a pip, so it competes with hold-to-chain for fuel.

### Decided in Stage F5

- **FireGrid** (scenes/objects/fire/fire_grid.gd) is made by `Room` in rooms with `fire_allowed` and a Grass layer. Fire spreads along the surface with the Earth shadow's step, now shared as `EarthFace.step_along_surface`. It never steps onto earth, gray rock or ash, and buried grass (no open side) can't catch.
- **The jet's fire catches late:** grass lit by the plume, and the take-off scorch under your feet, catches `spread_delay` later. Without the delay, jetting up from grass set the cell under you alight and killed you on the spot. Fireballs light grass at once.
- **Kill zone:** each burning cell has a band of flame `grass_fire_hazard_height` (5 px) deep on each open side, inset 1 px along it. One check for the whole grid; the grid joins the `fire_hazard` group. Smoldering cells are harmless.
- **Fuses light braziers:** a cell that catches lights any flammable within 4 px of its flame band.
- **Flammable contract:** an optional `ignite_at(point, radius, source)` for things that burn in parts (the grid). `Flammable.ignite_near` and the jet plume use it.
- **Ash flakes:** a cell turning to ash leaves 2 gray flakes in the room's PebbleField, so they get kicked like pebbles (§6.1).
- **Test rooms are earth now:** grass burns, so Fire A–C were rebuilt with earth frames, and grass is laid only where a room wants fire.
- **F5 play-test changes:**
  - **Slower, longer fire:** `spread_delay` 0.25 → 0.32 s (jitter ±0.08), `burn_time` 1.0 → 1.6 s, and the charred smolder before ash 0.6 → 2.5 s. Each cell rolls its own burn and smolder time (±`burn_time_jitter` = 15%), so neighbours don't go out in step.
  - **Organic look:** the first version lined up with the tiles and repeated itself. Now:
    - Each cell remembers where its fire came in and the flames *creep* across it from there at the spread speed. Blades curl as the creep reaches each one.
    - Cells get a random number of FlameTongues at random spots (even a pixel past the edge), each with its own size, lean, flicker and lifetime. A tongue that dies comes back elsewhere on the cell while it still burns.
    - The edge between burnt and unburnt ground wanders ±3 px on smooth noise.
  - **No square flash:** a new flame flares longer and white-hot, with a soft round glow at its foot. Glows under flames and ember specks are soft circles too.
- **Frame rate:** burning all of Fire D dropped to ~27 fps. The cause was soft glows drawn as 4 stacked `draw_circle` calls each, about 800 a frame with a field of smoldering specks. Every glow is now one rectangle with a shared radial gradient texture, speck layouts are made once per cell, and the ground picture is uploaded once per frame. Measured: 58–60 fps through a full burn. Keep this in mind for F13's HeatGlow: soft glows should be textured quads.
- **Bug fixed (F4):** fireballs flew through tile walls. A non-monitorable Area2D counts as static in Godot's 2D physics and is never checked against the (static) tile layers. The fireball stays monitorable now.

### Play-test log

*Empty until play-tested. Record each decision as: what was tried / what felt wrong / what was kept.*

Open questions to answer in play-test:
- Spread speed (`spread_delay`): does a fuse feel readable and fair at 0.25 s?
- Should burning grass kill instantly, or after a short 0.1 s grace when you're already standing on it as it ignites?
- Burst length (0.5 s) and taper (1.3 → 0.8): is one burst too long to control near hazards? Does the surge read as "fire" without feeling random?
- Hold-to-chain: does it ever spend a pip the player didn't mean to? If so, try requiring a fresh press near the end of the burst instead.
- Leafling torch run: chaotic in a fun way, or unfair? Is 1.5 s right, and should it run toward the player or keep its direction?
- Shell: does a falling loose big rock count as a kill?
- Overgrown covers: is the tell readable enough without being obvious?
- Balloon envelope burning: a good trap, or too easy to trigger by accident with your own jet?
- Crates burning away: fun puzzle, or a frustrating way to lose a needed object?
- Should the fireball aim root you on the ground, or let you keep walking slowly?

## 14. Parking lot (not confirmed)

- **Fire + Earth:** heated rock throw (rock passes through a bonfire → it ignites what it hits). Glowing rocks melt ice later.
- **Fire + Air:** wind zones push the fire front faster downwind and stop it upwind.
- **Updraft embers:** embers carried by a hot updraft ignite flammable things above it.
- **More fire enemies:** e.g. a moth drawn to the nearest flame (lure it with a fire), or a soot crawler that walks only on ash.
- **An Air-only enemy** to complete the "one per element" rule (e.g. a heavy-winged creature only a gust can ground).
- **Charged fireball:** hold Q longer = 2 pips, a bigger splash.
- **Lantern** that carries a flame across a room.
- **Wet grass** (from Water) that won't burn.
