# Windbound: Water bending (Chapter 4)

*Spec v1, 22 Oct 2026. Replaces the v0 draft. Companion to `GAME_DESIGN.md` (core + Air), `Earth_bending.md` (Earth) and `Fire_bending.md` (Fire). Water is built **after** Fire: several combinations in §8 need Fire's `FireGrid`, `Flammable` and hot updrafts. Every number marked* **(tune)** *lives in `WaterTuning` and is exposed in the live tuning menu. Play-test decisions go in §15.*

---

## 1. The idea in one paragraph

Water is the element of **carrying and changing**. You **grab** water with your hands: a quick **scoop** on the run, or a rooted **pull** that drains a pool while its level visibly drops. Moving water (**streams and waterfalls**) never runs dry, and instead of taking from it you can **bend the flow itself** like a hose. Carried water floats beside you as a **blob** of up to 4 units. You **throw** it as a quick ball, **pour** it as an arcing stream, or **drip** a trail behind you. Then the **frost** shot freezes whatever water it hits: pool tops become slippery **ice sheets**, a poured arc becomes a curved **ice slide**, a bent waterfall becomes a sculpted ice ramp. And water **changes everything it touches**: earth turns to sticky **mud**, ash sets into **stone**, plants **grow**, fire goes out or bursts into **steam**. Water rooms are puzzles about *where to take water from, where to put it, and what to turn it into*.

## 2. Pillars check

| Pillar | How Water meets it |
|---|---|
| Movement first | Ice keeps your momentum (long jumps, slides, ramps). Swimming has its own burst, the **propel**, with a breach jump out of the water |
| One verb, three uses | Grab, bend, throw, frost and propel each have a movement, puzzle and combat use (§5) |
| Fail fast | R resets pools, flows, the blob, ice, mud, growth, steam and enemies |
| Readable | Water is **blue**, ice is **cyan-white**, mud is **glossy brown**, steam is **white**. The blob's size *is* the water meter. Wet things look wet (darker, with droplets) |

## 3. Keys

| Key | Action |
|---|---|
| **Q** | **Water hands.** What it does depends on where you are (table below) |
| **W** | **Frost.** Tap = frost shot in the arrow direction (facing direction if no arrow). Hold = slow-motion aim (world 0.3×, aim moves in real time, like the gust); release fires. **One per airtime**: free on the ground, one shot per jump |

Both keys are new and clash with nothing. Every element now has its own pair: Air Z/X, Earth A/S, Fire D/F, Water Q/W. **C (Jump)** cancels any aim, pull or bend without spending water.

**Q in context** (checked in this order, like the Earth one-key rule):

| Where you are | Tap Q | Hold Q |
|---|---|---|
| **Submerged** (head under water) | Propel kick (short burst) | Propel (continuous thrust) |
| **Touching water** (feet in a pool or puddle, swimming at the surface, or overlapping a stream or waterfall), blob not full | **Scoop** +1 unit, no stop | → see next rows |
| Within 24 px of a **pool**, blob not full | — | **Pull**: rooted, slow motion. Once the blob is full and you're still holding, it turns into the **stream aim** ("fill and fire") |
| Within 24 px of a **stream or waterfall** | — | **Bend the flow** (§5.2) |
| **Carrying water**, none of the above | **Ball**: throw 1 unit | **Stream aim**, release pours all units. With **Down** held on the ground: **trail** instead |
| Not carrying, not near water | Empty-hand flick (no effect, small click) | Nothing |

**Down + tap Q** while carrying pours 1 unit at your feet.

## 4. The water resource

### 4.1 Sources
- **Pools** are still water with a visible surface line, measured in **units** (1 unit = one 8×8 tile of water). Pulling a unit lowers the whole surface evenly, so wide pools drop slowly and narrow ones fast. Pools are **finite** until reset.
- **Streams** (horizontal or sloped channels of moving water) and **waterfalls** (vertical curtains) are **flows**. They are **endless**: scooping from a flow never lowers anything. You can't pull from a flow; you bend it instead (§5.2).
- **Linked pools** share one level through a visible pipe: pulling from one lowers both.
- **Basins** are empty dips. A flow diverted into a basin fills it as a pool at 1 unit/s **(tune)** up to its rim.

### 4.2 The blob
- Holds **up to 4 units** **(tune: `blob_max_units`)**. It floats above and behind your shoulder, wobbling, and **its size is the readout**: 1 unit is a droplet, 4 units a sloshing ball half your size.
- It's a **shield**: each orb that hits it splashes and costs 1 unit.
- Lost on death or R. Pools give their water back on reset.

### 4.3 Frost charge
- **One frost per airtime.** It refills on the ground, while swimming, and on landing on ice. Ground frost has a short cooldown of 0.25 s **(tune)**.
- Frost costs **no water**: water is the resource, frost only shapes it.

### 4.4 HUD
- A row of **4 droplet pips** in the stacked element HUD (the plan from `Fire_bending.md` §4.2). Full droplets mirror the blob. A small **snowflake** at the end of the row shows the frost charge; it dims when spent in the air.
- The player is **not** tinted when frost is spent, (the old pale-blue "no dash" tint is gone with the dash, so a tint is free again if wanted).

## 5. Moves

### 5.1 Scoop and pull (grab)
- **Scoop** (tap Q while touching water): a gulp of water leaps from the surface in a little arc into the blob. +1 unit, 0.15 s cooldown **(tune)**. You keep running, jumping or swimming. Works on pools, puddles, streams and waterfalls (from a pool it lowers the level by 1 unit; from a flow it costs nothing).
- **Pull** (hold Q within 24 px of a pool): the world slows to 0.3× and you're rooted (like the Earth bend). A tendril rises from the closest point of the surface and twists into the blob, **1 unit per 0.15 s real time** **(tune)**, until you release, the blob is full, or the pool is empty. If you keep holding at full, the pull flows straight into the stream aim.
- **Movement:** lowering a pool uncovers a passage under it, or drains a pool you'd otherwise have to swim through. Scooping on the run keeps you moving.
- **Puzzle:** floating things ride the level down: a crate onto a plate, a lily pad down to a ledge. Linked pools drain together.
- **Combat:** the blob blocks orbs. Draining a pool strands what floats on it.

### 5.2 Bending a flow (hold Q near a stream or waterfall)
The signature move: you grab moving water and **steer it like a hose**.

- **Grab:** the flow bends at the point closest to you. The world slows to 0.25× and you're rooted. The part of the flow past the grab point swings toward your aim, steered with the arrows in real time (tip speed 90 px/s **(tune)**), keeping its length. It stops at solid walls.
- **Release:** the flow snaps back to its natural course in 0.2 s, **unless its end rests in a catch**: a **channel** (a carved dry trench), a **basin**, or a **waterwheel**. Then it keeps its new course until reset.
- **Freeze while bending:** pressing **W** while holding a flow freezes it **in its bent shape** (no aiming needed; the frost races down the flow from your hands). That's **sculpting**: a waterfall bent into a curve becomes a curved ice ramp, and the passage it was covering is open.
- Auto-release after 3 s **(tune)**, like the snake's auto-harden.
- **Movement:** bend a waterfall aside to reach the ledge behind it, sculpt ramps and bridges out of flows, ride a bent stream's current.
- **Puzzle:** divert a stream into a dry channel or onto a waterwheel; fill a basin to float a crate up. Flows are endless, so bending or freezing them is the only way to "turn them off".
- **Combat:** swing a flow through enemies: it shoves wisps and leaflings along and **kills cinders**.

**Waterfalls are curtains:** passing through one pushes you down hard (200 px/s **(tune)**), so a ledge hidden behind a waterfall can only be reached once it's bent aside or frozen bent.

### 5.3 Throw: ball, stream, trail, pour

**Ball** (tap Q while carrying)
- **1 unit**, 200 px/s **(tune)**, a light arc (gravity 250 px/s²). On impact it **splashes**: wets the hit tile and one neighbor each side along the surface, shoves light pushables, knocks back and **wets** wisps.
- Freeze a ball **in flight** with a frost shot and it becomes an **8×8 ice block** that drops.

**Stream** (hold Q while carrying, aim, release)
- Slow-motion aim at 0.3×, aim moving in real time, with a dotted preview of the arc.
- On release, **all carried units** pour out as a continuous rope of water over 0.4 s **(tune)**, along a ballistic arc (launch 220 px/s, gravity 500 px/s² **(tune)**). Length ≈ **24 px per unit** **(tune)**, so 4 units make about 96 px of arc.
- Where it lands, it wets a run of surface tiles (or fills a basin, or soaks into a plant).
- **Freezing a stream:** press **W during the pour or up to 0.3 s after it** **(tune: `stream_freeze_window`)** and the whole arc freezes into an **ice slide**, shaped exactly as it was at that moment. No aiming needed: frost races along the arc from your hand. (Outside that window, W fires a normal aimed frost.)

**Trail** (hold Q with Down held, on the ground, while carrying)
- No slow motion. You run normally and water dribbles behind you: **1 unit wets 4 tiles** of ground (32 px) **(tune)**, until you release or run dry.
- Frost the trail and it becomes an **ice runway** along your path.

**Pour** (Down + tap Q): 1 unit drops at your feet. On rock it makes a puddle; on earth, grass, ash or plants it soaks in (§7.2).

**Uses**
- **Movement:** stream + frost = a slide over a gap; trail + frost = a runway for a long jump; ball + frost = an ice block to stand on.
- **Puzzle:** wet things to change them (§7.2, §8): mud, stone, growth, dousing. A ball fills a water scale; a stream refills a pool.
- **Combat:** a ball stuns and wets a wisp; a stream pushes enemies off edges; any water **kills cinders**; a ball **douses** a sentry (no fire for 3 s **(tune)**).

### 5.4 Frost (W)
- A pale cyan dart, 280 px/s, range 128 px **(tune)**, straight line, no gravity. It freezes the **first water it touches**, then bursts in a puff of snow. On dry things it bursts harmlessly (exceptions: fire and cinders, §8.3 and §9).
- **What freezes when it hits:**

| Hit | Becomes |
|---|---|
| **Pool** surface | A full-width **ice sheet**, 8 px thick, on top. The water below stays water (you can swim under it) |
| **Stream** | The whole visible segment freezes into ice; its current stops. Melting restarts it |
| **Waterfall** | A solid **ice column** from top to bottom, with ice walls (wall jumps work, no cling). The flow below stops |
| **Wet surface tiles** (puddles, trails, wet patches, mud, wet grass) | An **ice crust**, spreading along connected wet tiles up to 16 tiles **(tune: `frost_surface_reach`)** in a quick wipe |
| **Wet wall patch** | An **ice ledge**: a foothold, like a stuck rock |
| **Ball in flight** | An **8×8 ice block** that drops |
| **Your stream / held flow** | Frozen whole, automatically (§5.2, §5.3) |
| **A wet wisp** | Frozen into an ice block (§9) |

- **Movement:** freeze where you want to slide. Frost refills on landing on ice, so ice chains can be built mid-air: jump, freeze, land, freeze again.
- **Puzzle:** frozen water can't be scooped or pulled (a commitment, like spent earth). Freezing a waterfall cuts what it feeds.
- **Combat:** kills cinders, freezes wet wisps, freezes orbs mid-flight (they drop and shatter), snuffs small fires.

### 5.5 Swimming and propel
- **Swimming:** in water you swim at 70 px/s, gravity 180 px/s², max sink 60 px/s **(tune)**. **C** strokes upward; at the surface, C jumps out with a full jump. No breath meter. Under an ice sheet you can't surface; find an open edge or hole.
- **Propel** (Q while submerged): you push a current out behind you and shoot through the water in the arrow direction (8 directions): 170 px/s, accel 1200 px/s² **(tune)**. Tap = a short kick (0.15 s), hold = continuous thrust. No slow motion: like the flame jet, it's flown, not aimed.
- **Breach:** propel up through the surface and you leave the water in the `Launched` state, about **1.5× a full jump** **(tune: `breach_launch`)**. This is the swimming "super jump".
- **Currents:** streams push you along (60 px/s **(tune)**); propelling against a current is slower. Waterfalls push you down.
- **Not underwater:** frost can't be fired while submerged, and Air and Fire moves are off while submerged (the flame jet sputters, the dash and gust are suppressed) ⚠ confirm.
- **Movement:** fast swimming, breach jumps to high ledges. **Puzzle:** the propel's back-current shoves floating and sunken objects. **Combat:** the back-current shoves enemies; a breach under a wisp knocks it into the air.

## 6. Ice

### 6.1 Ice surfaces
Starting values, all **(tune)**:

| Property | Ice | Notes |
|---|---|---|
| Ground acceleration | ×0.15 of normal | Slow to start, slow to turn |
| Ground friction | ×0.08 of normal | You keep sliding after release |
| Speed cap on ground | **not applied** while above run speed | Momentum from a dash, flame jet, breach or column launch is kept |
| Jump | keeps full horizontal speed | **Long jumps** off ice are the signature move |
| Ice walls | wall slide ×2, no cling | Wall jumps still work |

### 6.2 Ice slides (the first slopes in the game)
- Frozen streams (yours) and sculpted flows can be **curved**, so this is the first time the game has slopes. Slopes exist **only as ice**.
- A slide is a 4 px thick polyline. **Your own frozen streams are one-way** (solid from above, pass through from below and the sides) so they never trap you. Frozen natural flows are solid.
- **New player state `Sliding`:** on a slide you follow its tangent; gravity accelerates you along it (`g · sinθ · slide_gravity_scale`, start 1.0 **(tune)**), with ice friction. Arrows lean slightly (±40 px/s² **(tune)**). You can't walk up an ice slope steeper than 15° **(tune)**; you slide back down.
- Jumping off a slide keeps your velocity. A slide that curves upward at its end is a **ramp**: you launch off the lip.

### 6.3 Ice objects and limits
- **Ice block** (8×8): standable, pushable (gust, snake head, crates), slides far on ice, **floats** on water and rides currents (a raft), blocks orbs. Shatters when a big rock hits it or it falls 4+ tiles **(tune)**. Fire melts it into a 1-unit puddle.
- **Ice cap:** at most **6** pieces of player-made ice per room **(tune: `max_player_ice`)**. Making a 7th melts the oldest with a visible drip-and-crack. Natural sheets and frozen flows don't count. (Flows are endless, so without a cap you could ice over a whole room.)
- **Look:** pale cyan with white streaks, a glint that slides along it as you move, white skid sparks when you change direction. Ice over water keeps a faint blue tint below so you can see there's water under it.

## 7. Materials and objects

### 7.1 Water bodies

| Body | Behavior |
|---|---|
| **Pool** | Finite units, level drops evenly. Swim in it. Frost → ice sheet |
| **Stream** | Endless flow along a channel. Pushes you and floating things. Scoop, bend, frost → ice |
| **Waterfall** | Endless vertical curtain. Pushes you down. Scoop, bend, frost → ice column |
| **Puddle** | 1 unit lying on a non-absorbent tile (gray rock, ashstone, crates, metal). Scoopable. Frost → ice patch |
| **Basin** | An empty dip that a diverted flow fills as a pool |

### 7.2 What water does to each tile (the wet layer)

Water that lands on a tile changes it. This is the heart of the chapter.

| Tile | Wet result | Details |
|---|---|---|
| **Fresh / used / hardened earth** | **Mud** (fresh mud stays bendable once; used mud stays spent) | Sticky floor and walls, mud rocks (§8.1). The Earth shadow crosses mud |
| **Grass** | **Wet grass**, which **grows into tall grass** in 0.8 s **(tune)** | Won't burn while wet (§8.2). Tall grass hides you and objects (§7.3) |
| **Ash** (from Fire) | **Wet ash** (gray-black sludge) that **sets into ashstone** after 2 s **(tune: `ash_set_time`)** | Ashstone acts like gray rock: solid, never burns, **blocks the Earth shadow**. Frost wet ash before it sets and it's ice instead |
| **Thicket** | **Wet thicket** that grows a **branch** (§7.3) | Won't burn while wet |
| **Gray rock, ashstone** | **Puddle / wet patch** | Freezes into an ice patch or ice ledge |
| **Burning anything** | **Doused** (§8.2) | Often makes steam |
| **Ice** | Nothing (water runs off) | |

- **Wet things stay wet until reset**, but **heat dries them**: a direct flame (fireball, flame jet plume, bonfire, burning leafling, cinder) touching a wet tile dries it back in a puff of steam **instead** of igniting it. The next flame ignites as usual. Fire **spreading** from a neighbor does **not** dry wet tiles, so a wet line is a firebreak.
- Dried tall grass stays tall.

### 7.3 Plants: water makes things grow

| Plant | Watered (per unit) | Uses |
|---|---|---|
| **Tall grass** (grown from grass) | Grows 16 px tall in 0.8 s | **Hiding:** while you're on the ground inside tall grass, **sentries can't see you**. **Hides objects:** authored tall grass can hide diamonds, plates or seeds; it parts as you walk through and lies flat for 1 s under a gust. **Slows you** to ×0.8 run speed **(tune)**. **Burns bigger** once dry: 16 px flames, burn time 1.4 s **(tune)**, tall enough to block a jump over it |
| **Vine** (from Fire) | Grows **16 px longer** per unit **(tune)**, up to its authored max | Lowers whatever it holds (a platform, a crate), or reaches down to a lower ledge. Still a rope, not a ladder |
| **Seed: stalk** (new) | A stalk grows **24 px up** per unit (max 2 units) **(tune)**, with a leaf pad on top | A slow-rising platform: it lifts you gently, it doesn't throw you (that's Earth's column). Flammable |
| **Seed: lily** (new, on water) | A **lily pad** 16 px wide opens on the surface | Floats, rides the water level up and down and drifts with currents. Standable. Flammable |
| **Thicket** (from Fire) | Grows a **branch** straight out of the face the water hit, **1 tile per unit**, max 4 **(tune)** | Hit a side face → a horizontal bridge. Hit the top → a wall grows up. Solid, and Fire can burn it later |

Growth needs water to **land on** the plant (ball, stream, trail, pour, a bent flow, rain from melting ice). A plant that's already grown to its max ignores more water.

### 7.4 New objects

| Object | Behavior |
|---|---|
| **Channel** | A carved dry trench. A flow bent into it stays there |
| **Waterwheel** | A paddle wheel. Spins while a flow hits its paddles and holds its door open. When the flow stops, it winds down and the door's timer starts (like the windmill). Also a catch for bent flows |
| **Steam turbine** | A bladed wheel in a metal housing. **Only steam spins it** (§8.2): a steam burst or steam shot. Spins up and opens its linked door for N seconds **(tune)**; a steady steam column keeps it spinning. Often placed out of reach |
| **Water scale** | A cup on a spring. Sinks and presses like a pressure plate while it holds **2+ units** **(tune)** of water or ice. Fire evaporating its water lifts it again |
| **Linked pools + pipe** | Share one level |
| **Seeds** (stalk, lily) | See §7.3 |

### 7.5 What floats
Crates, ice blocks, lily pads, leaf platforms and loose leaf piles **float** and ride the water level and currents. Rocks, Shells and the player don't (the player swims). Implemented as a `floatable` group with a buoyancy hook.

## 8. Element combinations

Every element changes at least one material, and Water touches all of them. Mixed rooms are built on this map.

### 8.0 Transformation map

```
earth  --water--> mud        --heat--> earth
grass  --water--> tall grass (wet) --heat--> tall grass (dry) --fire--> big fire --> ash
ash    --water--> wet ash    --2 s--> ashstone (blocks the Earth shadow, never burns)
water  --frost--> ice        --fire--> water
fire   --water--> doused + steam
fire   --frost--> snuffed
steam  --> lifts gliders, balloons; spins turbines
```

### 8.1 Water + Earth

**Mud** (wet earth)
- **Sticky floor:** run ×0.5, jump height ×0.65 **(tune)**. Landing on mud **kills any momentum** at once: the brake at the end of an ice runway.
- **Sticky walls:** on a mud wall you **cling without sliding** for as long as you hold toward it. Wall jumps still work. A rest stop on a long climb.
- Frozen mud is ice (slippery). Heat dries it back to earth.

**Mud rocks** (pressing S on a mud tile)
- Brown, dripping. They **stick to anything** they hit: gray rock, walls, ceilings, ice, crates, not only earth. Mud footholds can go anywhere.
- They **do no damage**. Instead they **gum enemies up** for `mud_stick_time` = 4 s **(tune)** ⚠ confirm (or until reset):
  - **Walking enemies** (wisp, leafling, Shell) are **stuck in place**.
  - **Shooting enemies** (sentry) are **clogged**: no orbs.
  - **Cinders** are **smothered and die** (mud is wet).
- A big mud rock gums a bigger area (everything it touches) and still breaks cracked walls.

**Other**
- A **hardened snake** across a stream dams it: the flow ends there, and if there's a basin behind the dam, it fills.
- A rock thrown into a pool **splashes**, wetting the tiles within 16 px of the surface.
- A rising column under an ice block launches it.
- The Earth shadow crosses mud and ice crust but **stops at ashstone**.
- **Shells sink** and walk along pool floors. On ice they can't stop at ledges, so they slide off.

### 8.2 Water + Fire

**Douse** (water touching fire)

| Fire | Doused |
|---|---|
| Burning grass / thicket / tall grass | Out; becomes the **wet** version. A small steam puff (24 px, 0.5 s) |
| **Bonfire** | Out; a smoking **wet leaf pile** (needs one flame to dry, then another to relight). A big **steam burst** |
| Burning crate | **Charred wet crate** (solid, usable) |
| Burning vine | Stops; the burnt part is gone |
| Burning leafling | Snuffed, stunned 1 s, then a normal leafling |
| **Brazier** | **Goes out**, and its door closes ⚠ confirm (the gust can't do this; water can) |
| Fireball in flight (hit by a ball) | Both pop in a steam puff |
| **Cinder** | **Dies** (§9) |

**Steam** is **fast-moving clusters of hot vapor**. It's harmless to you.
- **Steam burst** (water onto a bonfire, or onto 3+ burning tiles at once): a jet of puffs shooting **up 64 px** for 1.2 s **(tune)**. It's a **hot updraft** while it lasts (lifts gliders, balloons, heat sails) and **spins any turbine** in its path.
- **Steam shot** (fireball thrown **through your blob** while carrying water): the fireball spends 1 unit of water and leaves as a **steam shot**, a fast cluster of puffs (260 px/s, range 160 px **(tune)**) flying the fireball's direction. It doesn't ignite anything; it **spins turbines from afar**, shoves light objects and dries wet tiles it crosses.
- **Jet over water:** the flame jet's plume touching a pool raises a steam column for as long as it touches + 0.5 s, and **boils off 1 unit per 0.5 s** ⚠ confirm.

**Fire melts ice**
- Any flame touching ice turns it back to water: a sheet sinks back into its pool, a frozen flow starts flowing again, a slide or ice block falls as puddles and wet tiles, an ice ledge drips into a wet patch. The flame jet can **carve through** ice.

**Frost snuffs fire**
- A frost shot on a small fire (grass, thicket, vine, crate, leafling): out, and the tile is left **wet** (the frost melts in the heat), unlike the gust, which leaves ash.
- On a **bonfire**: it freezes into an **ice-coated leaf pile**, a standable lump. A flame thaws it into a wet pile.
- Frost meeting a fireball: both burst into a steam puff.

### 8.3 Water + Air
- A **gust over a pool** raises a wave in its direction that shoves floating things across.
- A gust **slides ice blocks** and carries a **ball** in flight along with it.
- A gust through a **stream arc in flight** sprays it wide: it wets a wider, shorter area.
- A gust **bends a steam column** sideways: aim steam at a turbine.
- The **dash** keeps its momentum on ice. **Gliding** over steam lifts you.
- Air moves are off while submerged ⚠ confirm.

### 8.4 Three or four elements (summit and mixed rooms)
- Burn a grass run (Fire) → wet the ash (Water) → it sets into ashstone → the Earth shadow can't cross there, so the shadow is forced the long way round.
- Wet earth into mud (Water) → tear a mud rock (Earth) → stick a sentry shut → glide past (Air).
- Douse a bonfire (Water) → steam burst → glide up on it (Air) → a gust bends it onto a turbine.
- Water grass into tall grass, hide from a sentry, then let a cinder walk into it once it's dry: a big fire that clears the thicket ahead.

## 9. Enemies

### 9.1 Cinder (home: **Water**)
Completes "one enemy per element that only its element kills".

- **Look:** an 8×7 lump of coal with glowing orange seams and a small flame crown that flickers. It moves in short hops and sheds sparks.
- **Behavior:** patrols at 40 px/s **(tune)** and kills on touch. **It ignites flammable things it touches**, so in grassy rooms it leaves a burning trail behind it: a walking fuse you don't control.
- **It fears water:** it turns around at wet tiles, puddles, mud and ice. A wet line is a fence.
- **Only water kills it:** a ball, a stream, a swung flow, a frost shot, a mud rock, or falling into a pool. It dies with a hiss and a **steam puff** (a small steam burst that can nudge a turbine).
- **Everything else fails:**
  - Fire feeds it (no effect).
  - Spikes don't hurt it; a column crush doesn't either.
  - Rocks (small and big) knock it back.
  - A **gust flares it**: ×1.5 speed for 1 s, and it ignites everything along the way.
- **Puzzle use:** fence it with water, or **use it** as a fuse to burn thicket or light a fuse you can't reach, then kill it.
- **Note:** the Cinder is built in stage W9 and also appears in later mixed rooms. Add it to the enemy table in `Fire_bending.md` §7.2 when Fire is play-tested.

### 9.2 All enemies against Water

| | Wisp | Sentry | Leafling | Shell | **Cinder** |
|---|---|---|---|---|---|
| Ball | stunned 0.5 s + **wet** | doused 3 s | knocked back, wet (won't burn) | nudged | **dies** |
| Stream / flow | pushed far | doused 3 s | carried away | nudged | **dies** |
| Frost | freezes **if wet** (else nothing) | freezes orbs mid-flight | nothing | nothing | **dies** |
| Mud rock | stuck 4 s | clogged 4 s | stuck 4 s | stuck 4 s | **dies** |
| Deep water | **dies** (can't swim) | n/a | floats | sinks, walks the floor | **dies** |
| Fire | dies | dies (fireball) | **dies (torch)** | immune | immune |
| Big rock | dies | dies | knocked back | **dies** | knocked back |

- **Frozen wisp:** a wisp in an ice block is harmless and pushable. Push it into spikes or drop it 4+ tiles to shatter it, which defeats it. Fire thaws it out.

## 10. Player
- **New states:** `Swimming` (with propel), `Sliding` (ice slopes), `Pulling` and `Bending` (rooted, slow motion). The ball and stream aims and the frost aim reuse the gust aim state. The breach reuses `Launched`.
- **Hazards:** water isn't a hazard by itself. Spikes under water still kill. Steam is harmless.
- **Momentum on ice** carries into every move: jumps, dashes and jets launched from ice keep their speed.

## 11. The look: water must feel alive

Placeholder rules still apply (shapes, lines, particles, one color family per type). As with fire, "alive" comes from **motion**.

### 11.1 Palette (water family)

| Use | Color |
|---|---|
| Deep water | `#1F4E8C` |
| Water body | `#2F7FD1` at 85% alpha |
| Surface line / foam | `#BFE4FF` |
| Ice | `#A9F0FF` with `#FFFFFF` streaks |
| Frost dart | `#E8FBFF` core, `#7FDFFF` trail |
| Mud | `#5A3B22` with glossy `#A47A4E` highlights |
| Wet ash / ashstone | `#2B2A2E` sludge / `#565359` stone with pale flecks |
| Steam | `#F2F2F2` at 50–70% alpha |
| Plants | the existing grass greens; tall grass slightly bluer while wet |

### 11.2 Building blocks (one script each, reused everywhere)
1. **`WaterSurface`:** a 1D spring chain along the pool's surface line (the classic 2D water trick: each column is a damped spring, coupled to its neighbors). Splashes, scoops, swimmers and floating objects push the springs, so waves ripple outward. Cheap and very alive.
2. **`FlowRibbon`:** a `Line2D` polyline for streams and waterfalls with scrolling stripes, a foam lip and spray at the bottom. Bending a flow just moves its points.
3. **`Blob`:** a wobbling polygon whose radius is driven by noise and by your motion (it lags and sloshes when you turn), with a highlight. Its size steps up with each unit.
4. **`Tendril`:** a tapering `Line2D` with noise along its length for pulls and scoops.
5. **`DropletEmitter`** and **`SteamEmitter`:** droplets arc and splash; steam puffs rise fast, swell and fade.
6. **`FreezeWipe`:** frost spreads from the hit point as branching white crystal lines, then the surface snaps to ice with a glint.

### 11.3 Per source

| Source | Look |
|---|---|
| Scoop | A gulp leaps from the surface in an arc; the surface dips and rings outward |
| Pull | The tendril twists up into the blob; the pool level visibly slides down; ripples run toward the pull point |
| Bend | The flow curves smoothly toward your hands, foam where it bends, spray at its tip |
| Ball | A wobbling droplet with a short trail; splash crown on impact, droplets, a dark wet patch |
| Stream | A glossy rope of water along the arc, thinning at the tail, splashing where it lands |
| Trail | Drips behind your heels, wet footprints |
| Frost | A sparkling dart; on impact, the `FreezeWipe`, a freeze frame of 2 frames, a soft crackle |
| Ice slide | A cyan ribbon following the frozen arc, with frozen ripples along it |
| Propel | A cone of bubbles and current lines behind you; on breach, a splash crown and spray |
| Mud | Glossy, slowly dripping; footprints sink and squelch; mud walls show hand prints when you cling |
| Wet ash → ashstone | Sludge bubbles, then the bubbles freeze and it dulls to stone with a small crack sound |
| Growth | Tall grass pushes up and sways; stalks uncurl their leaf; branches knot outward tile by tile |
| Steam | Puffs shooting fast in their direction, curling at the edges, thinning to nothing |
| Douse | The flame hisses down into a steam puff; the tile turns dark and dripping |
| Melt | Ice glows, drips, then collapses into water and a splash |
| Cinder | Pulsing seams, a flickering crown, sparks on each hop; dies in a hiss and a white puff |

### 11.4 Feel
- Big actions get big reactions: a breach = splash crown + small shake; freezing a pool = freeze frame + crackle; a steam burst = whoosh + puff column.
- Droplets, steam and ice shards count toward the per-room particle cap and degrade gracefully.
- SFX hooks: `water_scoop`, `water_pull_loop`, `water_throw`, `water_splash`, `stream_pour`, `flow_bend_loop`, `frost_shot`, `freeze`, `ice_skid`, `swim_stroke`, `propel_loop`, `breach`, `mud_squelch`, `douse_hiss`, `steam_burst`, `grow`, `melt`.

## 12. Architecture (reuse first)

- **`WaterTuning`** resource: every number above, in the live tuning menu.
- **`WaterCarrier`**: a component on the player holding the blob's units (an int). Signals `units_changed`, `ran_dry`.
- **Abilities** (shared-core pattern, like the Earth bend): `WaterHandsAbility` (context resolver for Q: scoop, pull, bend, ball, stream, trail, pour, propel), `FrostAbility` (dart, airtime charge, auto-freeze of your own stream or held flow).
- **`Pool`** node: units, level, `WaterSurface`, linked pools, basin filling. **`Flow`** node: a polyline with a source, natural path, current zone (reuse the Air `WindZone`), bend state and catch detection.
- **`SurfaceGrid`**: one per-room grid of tile **states** shared by Fire and Water: burning, smoldering, ash, wet, mud, wet ash, ashstone, ice crust, tall grass. **If Fire's `FireGrid` isn't built yet when this spec is approved, build it as `SurfaceGrid` from the start**; otherwise generalize it in stage W2.
- **Contracts** (like `Pushable` and `Flammable`): `Wettable` (`wet(source)`, `is_wet()`, `dry()`), `Freezable` (`freeze(source)`, `thaw()`), `Growable` (`water(units, from_direction)`), and the `floatable` group. Steam reuses `HeatReceiver` and the `heat` WindZone flag; turbines join a `steam_receiver` group.
- **Ice slides:** a `StaticBody2D` with a `CollisionPolygon2D` built from the frozen arc (one-way for player-made slides). `CharacterBody2D` already handles slopes (`floor_max_angle`); the `Sliding` state adds the tangent acceleration.
- **`ElementImmunity`** gains water, frost, mud and deep-water entries for every enemy.
- **Rooms:** new flag `water_allowed`. Fire objects (bonfires, braziers, burning grass) can appear **pre-lit** in Water-only rooms, so steam and dousing work without Fire moves. Main menu: "Water chapter", "Water test rooms", and mixed test rooms.
- **Headless smoke test:** every room loads, pools, flows, grid and ice reset on R, ice count stays under the cap.

## 13. Build stages

| Stage | Contents | Done when |
|---|---|---|
| **W1** | `WaterTuning`, `Pool` with `WaterSurface`, `WaterCarrier`, blob visual, HUD row; scoop and pull | Scoop on the run, pull a pool down and see the level drop and the waves ripple |
| **W2** | Ball, stream aim and pour, trail, pour at feet; `SurfaceGrid` wet states, puddles, mud and wet grass looks; `Wettable` | Wet a floor three ways; it looks wet |
| **W3** | Swimming, propel, breach; `Flow` (streams, waterfalls) with currents and endless scooping; floating | Breach out of a pool onto a high ledge; ride a stream on a crate |
| **W4** | Frost dart, airtime charge; freezing pools, puddles, wet tiles, balls, wet wisps; ice ground physics; ice blocks; ice cap | Freeze a pool and long-jump off it |
| **W5** | Ice slides from frozen streams and flows; `Sliding` state; one-way slides; ramps | Pour and freeze a slide over a spike pit and ride it across |
| **W6** | Bending flows: grab, steer, snap back, catches (channel, basin, waterwheel); sculpting with frost; waterfall curtains | Bend a waterfall onto a waterwheel; sculpt it into a ramp and reach the ledge behind it |
| **W7** | Plants: tall grass (hiding, sentry sight, hidden objects, slow, big burn), vine growth, stalk and lily seeds, thicket branches; water scale | Every row of §7.3 works in a test room |
| **W8** | Combinations: mud floor and walls, mud rocks and gumming, wet ash → ashstone, heat dries, douse table, steam burst / shot / jet-over-water, steam turbine, fire melts ice, frost snuffs | Every row of §8.1–8.3 works in a test room |
| **W9** | Cinder; `ElementImmunity` rows for all enemies; frozen wisp | Every cell of the §9.2 table behaves as written |
| **W10** | Look and feel pass (§11) | It looks alive in a screenshot and in motion |
| **W11** | Rooms 1–10, mixed test rooms, smoke test | Chapter playable start to Goal |

Each stage should ship with basic visuals (a wobbling blob, a rippling surface) so it's tested with water that already looks like water. W10 is the full pass.

## 14. Rooms (draft)

1. **Still Water:** scoop on the run, pull a pool, watch the level drop, swim through.
2. **Undercurrent:** propel and breach out of a deep pool to a high ledge; a stream current carries you along.
3. **Draining:** pull a pool down to uncover the way on; a floating crate rides the level down onto a plate; a lily pad lowers you to a ledge.
4. **First Frost:** freeze a pool into an ice sheet and run across; long jumps off ice.
5. **Slide:** pour a stream and freeze it into a slide over a spike pit; drip a trail and freeze it into a runway, ending in mud to stop you.
6. **The Falls:** bend a waterfall onto a waterwheel to open a door; sculpt a waterfall into a ramp to reach the ledge it hid; wall-jump up a frozen waterfall.
7. **Green Thumb:** grow a vine down to a ledge, a stalk up to an exit, a thicket branch across a gap; hide in tall grass to sneak past a sentry.
8. **Mud and Ash:** cling to mud walls on a long climb; a pre-burnt field of ash becomes ashstone where you wet it; douse a pre-lit bonfire for a steam burst that spins a turbine.
9. **Cinders:** the water enemy. Fence cinders with wet lines, kill them with balls and frost, and let one burn a thicket open for you before you put it out.
10. **Glacier:** scrolling summit with everything together, the Goal.

**Mixed test rooms**
- **Water + Fire:** steam shots at an out-of-reach turbine; douse a fuse to save a bridge; melt an ice wall with the jet; dry tall grass and burn it for a big fire.
- **Water + Earth:** mud rocks on gray rock and ceilings; gum a sentry shut; snake-dam a stream to fill a basin; slide a Shell off an ice sheet.
- **Water + Air:** gust waves across a pool; dash along ice runways; glide on steam; bend steam onto a turbine with a gust.
- **All four:** the §8.4 chains.

## 15. Decision log (play-test)

*Empty until play-tested. Record each decision as: what was tried / what felt wrong / what was kept.*

Open questions to answer in play-test:
- **Q in context:** carrying water at a pool's edge, a tap scoops instead of throwing. Is that annoying? If so, try "an arrow pointing away from the water throws".
- **Fill and fire:** does holding Q through a full pull into the stream aim feel natural, or does it fire streams you didn't mean to?
- **Frost one per airtime:** too stingy for building slides mid-air? Should landing on ice refill it (as written) or only ground?
- **Stream freeze window** (0.3 s after the pour): easy to hit? Should W during a pour always freeze your stream, even with an arrow held?
- **Slopes:** does the `Sliding` state feel good at 1.0 gravity scale? Are one-way slides readable?
- **Bend:** is rooted slow motion right for bending flows, or should you be able to walk slowly while holding one?
- **Mud gum time:** 4 s, or until reset?
- **Douse a brazier** closing its door: good puzzle, or confusing?
- **Jet over water** boiling pools down: fun, or a way to wreck a room by accident?
- **Tall grass everywhere:** does all watered grass growing tall clutter rooms? If so, only "sprout grass" tiles grow tall.
- **Ice cap 6:** enough?
- **Submerged:** should Air and Fire moves really be off underwater?

## 16. Parking lot (not confirmed)
- **Water whip:** a tendril strike from the blob.
- **Surfing:** stand on an ice block riding a stream (it may just work with floating + currents; test it).
- **Climbing up a waterfall** with the propel, salmon-style.
- **Icicles** that grow under wet ceilings and fall when shot.
- **Big ice block** (16×16) from 3–4 units.
- **Bloom cap:** a seed that grows into a bouncy mushroom.
- **Frost crystal:** a pickup that refills the frost charge mid-air (the wind-crystal equivalent).
- **Cinder on ice:** a cinder touching ice melts it and drowns in the puddle.
- **Wet leafling** grows bigger and slower.
- **Gust dries:** wind slowly dries wet tiles.
- **Steam vents** as static objects (dropped for now).
- **A water diamond** to refill the blob far from any source.
