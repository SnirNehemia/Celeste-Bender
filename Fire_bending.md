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

### Decided in Stage F6

- **Burning thicket kills on touch, like grass** (developer's choice). "A burning thicket floor drops you" means the burnt floor opens a way down; it doesn't carry you down alive (the player is one tile wide, so falling past still-burning neighbours would kill anyway). The dramatic version: take off from a thicket floor with the jet (it catches a moment late, like grass) and come back down through the hole.
- **Glow first:** a thicket cell only glows from inside for `thicket_glow_share` (20%) of its burn, harmless; then its flames break out and kill. The glow is the warning.
- **Thicket burns through its volume:** the 4 neighbours, buried cells too. It lights touching grass after `thicket_spread_delay`; grass lights touching thicket after `spread_delay`. A burnt cell crumbles (state GONE) with no smolder and no ash crust: a shower of flakes (`AshFall`), and the grass it covered catches.
- **Layers:** "Thicket" (`ThicketLayer`) and "Overgrown" (`OvergrownLayer`, which extends `GrassLayer`, so grass-looking covers grow the same blades). Both use `resources/tiles/thicket_tileset.tres` (a thicket tile and a grass-look tile). The `FireGrid` owns the fire; the layers only erase and restore tiles. A room gets a FireGrid if it has any of Grass, Thicket or Overgrown.
- **Flash-over:** a front crosses the cover in the first half of `overgrown_flashover_time` (flood fill from where the fire came in), the cover burns as one deadly sheet, then everything collapses in the same frame: freeze (`overgrown_freeze_time`), shake, ash burst. The collapse opens any `HiddenLayer` chamber it touches (objects inside appear as its crumble reaches them) and lights the grass and thicket around it.
- **The tell:** root tendrils hanging from a cover's undersides and poking out of its sides, plus a crust a shade off (`GroundPainter.OVERGROWN_TINT`); since the play-test, a thicket-looking cover's leaves are browner too. A covered chamber behind a cover is painted in the cover's look, not as earth.
- **Thorns** only on thicket's sides and underside; never on top, where they would read as spikes.
- **Frame time:** crumbling thicket redraws the ground around it several times a second. The redraw area is 3 tiles around the change (`BURN_REDRAW_RADIUS`), about 11 ms median in the headless test (the 5-tile area of earth tears took 25-45 ms). Watch for hitches in a big thicket fire; the next step would be caching the room's static tile kinds.

- **F6 play-test changes:**
  - **The jet burns only what its flame touches:** the take-off scorch now happens only when the flame points at the floor (any downward part). Standing on thicket or grass with the flame pointing up or straight sideways leaves the floor under you alone (a sideways plume still lights what it brushes).
  - **Ash stays:** burnt grass and crumbled thicket leave light gray ash flakes in the room's PebbleField (`PebbleField.leave_ash`). They're not pebbles: low gravity and strong air drag, so they drift down at about 25 px/s with a flutter, take on the wind's speed in every direction (an updraft lifts them), swirl round anything moving within `ash_kick_reach`, fly further in a gust, never bounce. Their own cap (`ash_max_per_room`), separate from the pebbles'. Values in FireTuning "Ash flakes". Cost measured: ~1.7 ms a frame with 190 flakes drifting.
  - **Thicket leaves:** `ThicketLeaves` (scenes/objects/fire/thicket_leaves.gd), made by ThicketLayer and by OvergrownLayer for thicket-looking covers. Second play-test: the first stem-and-2-px leaves read as grass blades, so they're now a bush of the leaf piles' 4x2 diamonds (0.9-1.4x, splayed out of the face), `leaves_per_face` = 5 (tops 6), from a little inside the edge to `leaf_bush_reach` = 3.5 px past it, so the outline is a leafy bush and not the tile grid (collision is still the tile); darker leaves over the crust drawn under brighter ones sticking out. They move with springs like the grass blades, leaning with wind, pushed away and dragged by the player, whipped by gusts; on a burning cell they blacken, shrink and drop off one by one. Values in FireTuning "Thicket leaves".
  - **Leaves over the tiles too** (third play-test, "more like a bush"): `leaves_per_cell` = 4 dark leaves spread over every thicket tile (buried ones too), under the edge leaves, so the brambles show only through the gaps. Measured with 441 leaves in Fire E: ~0.35 ms simulating + ~0.35 ms drawing a frame (median, headless). Cost grows with the leaf count; a room with several times more thicket may want the leaves that nothing touches to sway by formula instead of by spring.
  - **Covers that pass for thicket grow the same bush,** its leaves pulled `cover_leaf_brownness` (0.3) toward a dry brown: with the roots and the crust shade, that's the tell. Fire E's cover is now a thicket-looking one (it was grass-looking, which stood out in an earth block).
  - **Brambles:** the painter's branch strokes are broken into short pieces, so the inside reads as a tangle instead of a lattice.

### Decided in Stage F7

- **Hot air is not wind.** A WindZone with `heat` on returns zero from `get_wind_velocity()`, so everything that already reads wind (the player on foot, the jet, sails, grass, pebbles, crates) ignores it without a change. Lift comes only from asking `Heat.get_lift_at()` (scenes/objects/fire/heat.gd), and only the glide asks.
- **Heat contracts:** heat *sources* (group `heat_sources`, `get_heat_lift_at(point)`) and heat *receivers* (group `heat_receiver`, `apply_heat(strength, delta)`, optional `get_heat_point()`). Each source hands its heat to the receivers inside it every physics frame. Nothing is a receiver yet (balloons, sails, windmills, leaflings come in F9/F11); the smoke test uses a stand-in.
- **Glide lift:** `hot_updraft_lift` (160 px/s) is subtracted from the glide's target fall speed as it is (an Air updraft goes through `glide_updraft_lift_multiplier` instead): a glider rises at 130 px/s over a bonfire (Air updraft: 90). Glide stamina drains as in an Air updraft (`glide_updraft_stamina_drain`).
- **Bonfire elevator height:** the 48 px column starts at the flame's top (20 px), so a glider hovers with its feet about 72 px above the floor (measured; the smoke test prints it). Rooms place the ledge a bonfire lifts you to at most ~64 px up. `bonfire_updraft_size` changes it.
- **Burning grass and thicket heat:** the FireGrid is a heat source itself (a burning cell with an open top lifts `grass_updraft_lift` = 60 px/s up to `grass_updraft_height` = 16 px above it), instead of a WindZone per cell.
- **Air diamonds look like fire diamonds** (F7 play-test): the wind crystal has the single fire diamond's shape (4 x 6), the gust diamond the double's (6 x 7), so each converts into the fire diamond of its own shape. Both are the same very light blue with a darker blue rim (they were green and blue), like the two fire diamonds share their orange, and inside each, wind blows: thin mid-blue streaks sliding across on their own rows (2 in the crystal, 3 in the gust diamond), cut off at the diamond's edge. This is their look everywhere, the Air rooms too (GAME_DESIGN.md updated). Fire_bending.md §1/§4.3 still say "green wind crystal, blue gust diamond" for the air diamonds: read them as the light blue single and double.
- **Conversion:** wind crystals and gust diamonds are flammable (`fire_pip_value` 1 and 2; fire diamonds 0). The orange wipe comes from the side of the fire's source (from below for burning grass), takes `conversion_wipe_time` (0.25 s), then a real FireDiamond is spawned in the air diamond's place (pickup, single use and look for free). Only an air diamond that is there converts: one waiting to respawn doesn't. R frees the fire diamond and brings the air one back.
- **F7 play-test: the LEAVES burn, not the pile.** `LeafFire` (scenes/objects/fire/leaf_fire.gd), a child the pile makes the first time anything lights it, gives every leaf its own state (unlit, burning, gone), wherever the leaf is.
  - A **lone burning leaf is a harmless ember**: it lights unlit leaves within `leaf_spread_radius` (4 px) after ~`leaf_spread_delay`, lights flammables within `leaf_ignite_reach` every `leaf_ignite_interval` (grass, air diamonds, other piles), falls `leaf_ember_fall_scale` (3x) faster than an unlit leaf (it curls up), and burns away after `leaf_burn_time` (3.5 s ±25%), leaving a flake of ash now and then.
  - A **bonfire** stands wherever at least `bonfire_min_leaves` (6) burning leaves *lie* together (cells of `bonfire_cluster_cell` touching; falling leaves don't count). It is **as wide as the heap** (`bonfire_min_width`..`bonfire_max_width`, 12..48 px) and its leaves are **held**: they don't burn out while it lasts (`bonfire_duration`, 0 = until R; when it runs out they all burn away). A pile can have several bonfires if its burning leaves lie in separate heaps.
  - **Merged flames, in every fire:** tongues that overlap are drawn as one fire (`FlameMerge`, scenes/objects/fire/flame_merge.gd): all their red edges first, then all their bodies, then all their hot cores, so the red outline only goes round the outside and neighbouring tongues don't read as separate fires. The bonfire keeps its row of tongues spread over the heap's width (a single wide body flame was tried and rejected); braziers, burning grass and thicket, the jet plume, the fireball and the held fireball are merged the same way. Costs nothing extra: the same polygons, drawn onto one canvas item per fire instead of two per tongue. Inside a merge each tongue's base is drawn `base_widen` (1.8x) wider and `base_drop` (1 px) lower, so the feet run together into one bed of flame.
  - **Bug fixed: flames frozen on screen after R.** A canvas item keeps its last drawing until asked to redraw; when R (or a fire burning out) removed a fire's last tongue, its FlameMerge stopped redrawing and the last frame stayed. It now redraws once more whenever a tongue leaves.
  - It **grows**: amber (glowing coals, harmless, no lift, `bonfire_amber_time`), then a low flame (`bonfire_low_height_share` of `bonfire_flame_height`, kills and lifts, `bonfire_low_time`), then it rises to full height (`bonfire_grow_time`). So you can light a heap from above (jet, fireball) and ride its hot air up.
  - **A close gust puts it out:** a gust that reaches any leaf of a bonfire's heap blows the whole heap apart (even a heap wider than the gust's reach). The leaves fly on still burning, as embers that can light grass downwind and make a new bonfire where 6+ land together.
  - **A gust blows embers out:** a lone burning leaf (not part of a bonfire's heap) that a gust reaches goes out and turns to ash at once (a gray flake and a puff of smoke). So a second gust puts out the embers of a scattered bonfire.
  - **Ember rain:** gust a pile up and sweep a flame through the falling leaves (jet, or a fireball flying through: it lights the leaves it passes without bursting). The fire chains where leaves are close; the embers land still burning and light the grass.
  - **Leaves stack, like sand:** a falling leaf lands on a resting leaf just under it, `stack_spacing` (0.6 px) above it, so stacked leaves overlap a little (a leaf is 2 px tall). It stays only if it's within `stack_center_reach` (1 px) of that leaf's middle, or something else holds up its overhanging side; otherwise it slides off outward (`slide_step`) and keeps falling. Heaps get rounded slopes; the first version (any leaf within 1.6 px caught you) built lacy, twig-like chains with air in them.
  - **No hanging leaves:** whenever a leaf takes off or burns, every resting leaf without a leaf (within `settle_reach` 2.5 / `settle_depth` 3 px) or ground under it falls again, a layer per frame. That includes the untouched pile's own leaves, which used to stay hanging when you kicked out the ones below them.
  - **Leaves sink into the ground's edge:** they're drawn `ground_sink` (2 px) below where they physically lie, because the floor's painted top edge is ragged and showed a strip of sky under every pile. Only the drawing moves; wind, kicks and landing use the real positions.
  - **Dense piles:** the untouched pile is laid out on a jittered grid filling the mound (random spots left air pockets). Fire F's piles have more leaves.
  - **Fireballs fly on through leaves:** a fireball lights every leaf it passes (heap or cloud) and keeps going. Leaf piles have no catch area on the "flammable" layer, so nothing in a pile bursts it.
  - **Burning grass lights leaves where its flames are** (FireGrid calls `ignite_at` on things that burn in parts), not the whole pile.
- **Gusts put out grass and thicket fires** (F7 play-test, ahead of Stage F10's §5.4): a gust's cone (or an all-around gust's circle) over burning cells turns burning grass to ash at once (a firebreak) and makes burning thicket crumble away without lighting what it touched; cells about to catch inside the gust don't, and neither do cells only a snuffed cell was about to light. Smoldering cells and a flashing cover are left alone. A gust across a fire front stops it there. Through a new optional part of the Flammable contract, `snuff_in(world_polygon, direction)`, which `GustAbility` calls through `Flammable.snuff_in_area` (the dash wake doesn't). Stage F10 still has the rest of §5.4 (fireballs, vines, crates, the boosted gust).
- **Keep a hidden diamond out of the flame:** the crystal under Fire F's wide pile converts inside the bonfire (the fire is as wide as the heap); gust the heap apart from close by, then take it.
- **All elements in the Fire test rooms** (F7 play-test): `_fire_room()` in build_fire_rooms.gd turns Air, Earth and Fire on. The chapter rooms (F14) stay Fire-only.
- **Cost (measured headless, the leaf piles' own `_physics_process`, Fire F):** idle 0.03-0.09 ms a step; 170 unlit leaves flying ~1.1 ms (the per-leaf physics point query, as before, plus the landing lookup); a 60-leaf bonfire ~1 ms; ember rain of 40 leaves ~1 ms; a 170-leaf bonfire ~1.5 ms; 170 burning leaves flying ~2.2 ms (worst case: each one checks the room's flammables 5 times a second). Two fixes made it cheaper: a pile asked about a far-off point says no from its bounding box, and the bucket lookups don't build empty arrays. The later changes cost little: the ground sink is free; sliding off another leaf is one more bucket lookup (or a physics query, if no second leaf is there) per off-center landing; settling checks every resting leaf once per frame in which a leaf took off (a lookup each, a physics query only for leaves with no leaf under them); the merged bonfire draws one big tongue plus up to 6 small ones (up to 10 before). Drawing isn't included (one polygon per leaf, about what it was). If a room needs several big piles burning at once, the next step is fewer ignite checks for leaves inside a bonfire (the bonfire already lights what it touches).

### Decided in Stage F8

- **A vine is a Switch** (scenes/objects/fire/vine.gd): it turns ON when it snaps. What it holds listens to its `switched` signal: a `HangingPlatform` (`vines`) or a Crate (`hung_from`). The vine never knows what it holds.
- A flame lights a vine only where it touches its line (`ignite_at`), not its bounding box. Fire reaching an end lights grass and leaves there, but not whole objects: a hung crate falls, it isn't set on fire by its own vine. A vine's flame doesn't kill.
- **F8 play-test changes:**
  - **Vines are burning ropes.** A vine is simulated as a chain of points 3 px apart (Verlet, stretch-only constraints, a little slack, gravity 500, sleeps when still), anchored at one end, its other end following what it's tied to (`Vine.tie_to`, every frame). Lit at a point, it burns through THERE after `vine_cut_time` (0.15 s) and snaps; the fire runs both ways at `vine_burn_speed` (110 px/s) along the two dangling halves, each piece glowing, charring and dropping off as falling bits `vine_char_time` (0.25 s) after the fire reached it. (Replaces "the whole vine burns in 0.6 s, then snaps": `vine_burn_time` is gone.)
  - **Vines curl round what they hold:** 4 coils round the plank at the tie, a tendril winding 12 px along it toward its middle (ending in a leaf) and a short stub the other way. They burn when the fire reaches the tied end.
  - **Planks swing.** `HangingPlatform` is a stiff two-point body (Verlet ends, a length constraint, each intact vine a leash from its anchor, ground pushed out with short rays down, an end resting on the ground doesn't slide). With one vine cut it swings on the other; with all cut it falls, lands, tips over edges and sleeps. A plank can stand on end held by a vine: a **drawbridge** that topples across a gap when the vine burns. The body is placed with one `global_transform` assignment (setting position then rotation put the old position back on a synced AnimatableBody2D).
  - **Vine gate dropped** (developer's call): a door a vine holds shut added nothing thicket walls don't, and wasn't readable. Vines still are Switches, so a Door could listen to one, but no room uses it.
  - **The jet catches crates late:** a crate lit by the jet glows and smokes for `crate_jet_catch_delay` (0.45 s, a bit longer than grass's `spread_delay`) before it burns, so jetting up off a crate no longer kills you on the spot. Fireballs and other fires light it at once (also while it's catching).
  - **Fire at the knot lights the vine:** a flame touching the coils and tendrils round what a vine holds (a fireball bursting on the plank near the tie) lights the vine at its tied end.
  - **Bug fixed:** a burnt vine kept stopping fireballs (its catch area stayed on the "flammable" layer). The catch area is now a segment following the rope, switched off as soon as the vine is lit. A burnt sail's area drops the flammable layer too.
- **Crates burn** `crate_burn_time` (1.5 s): deadly (a FireHazard over the box and flames), they light grass and leaves within `crate_ignite_reach`, still slide when gusted, then collapse into a drawn ash heap with no collision, out of the "heavy" group (a plate under it lifts).
- **A burning leaf platform doesn't kill** (decided before building): it burns away in `leaf_platform_burn_time` (0.8 s) while you stand on it, which is your time to jump off.
- **A burning sail stops catching wind at once** (gusts, recoil and wind zones no longer move it), burns for `sail_burn_time` (0.6 s) to a bare mast with tatters, and the platform coasts at its current speed with no friction to the end of its rail, where it stops dead. A still sail stays still. The deck doesn't burn.
- New FireTuning group "Burning objects": `vine_cut_time`, `vine_burn_speed`, `vine_char_time`, `crate_burn_time`, `crate_ignite_reach`, `crate_jet_catch_delay`, `leaf_platform_burn_time`, `sail_burn_time`.
- **Fire G** test room (560×180): a drawbridge plank standing on a pit's far rim, a plank hung from two vines over a second pit (swings, falls), a crate on a plate holding a door shut over grass, and a leaf platform and a sail to burn.

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
