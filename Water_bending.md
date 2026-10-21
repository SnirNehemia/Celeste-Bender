# Windbound: Water bending (Chapter 4), DRAFT

*Draft v0, 21 Oct 2026. Written before Fire is built, to be refined afterwards. It uses the **pull-and-carry** model chosen in design. Numbers marked* **(tune)** *go in `WaterTuning`.*

---

## 1. The idea in one paragraph

Water is the element of **carrying**. Water lives in **pools**, and the pool is the resource: you **pull** water out of it and the level visibly drops, as earth darkens when spent. The pulled water becomes a **blob** that floats beside you. You can **throw** it as a wave that shoves things, or **pour** it into puddles. Then you **freeze**: pool surfaces become **slippery ice sheets**, the blob becomes an **ice block**, and splashes become **ice footholds**. Ice keeps your momentum, so it's a movement tool as much as a puzzle tool. Every pool is a choice: take the water away (lower the pool, reveal a path), or leave it and freeze it into a floor.

## 2. Keys (tentative)

| Key | Action |
|---|---|
| **Q** | Near a pool: **hold to pull** water into a blob. While carrying: **tap = throw** in the arrow direction, **hold = slow-motion aim** then release. Down = pour |
| **W** | **Freeze** everything watery around you (tap) |

Q and W sit above A and S, clash with nothing, and keep the "own keys per element" rule (Air on Z/X, Earth on A/S, Fire on D/F, Water on Q/W). Following the "fewer keys" lesson, a later version might move freeze onto Q-hold-while-carrying. Try it after the first play-test.

## 3. The resource: pools and the blob

- **A pool** is a body of water with a visible surface line. Its volume is counted in **units** (1 unit = one 8×8 tile of water). Pulling a unit lowers the whole surface evenly, so wide pools drop slowly and narrow ones fast.
- **The blob** holds **up to 4 units** **(tune: `blob_max_units`)**. It floats above and behind your shoulder, wobbling. Its size *is* the readout, so water needs no pips (in keeping with the "one bar per element" plan, the bar is the blob itself).
- **Pools reset on death or R.** Water you pulled and lost is gone until then.

## 4. Moves

### 4.1 Pull (hold Q within 24 px of a pool surface)
- World slows to 0.3×, and you're rooted (like the Earth bend).
- A tendril of water rises from the closest point of the surface and twists into the blob. **1 unit per 0.15 s** real time **(tune)**, until release, the max, or an empty pool.
- **Movement:** lowering a pool uncovers a passage underneath, or drains a pool you'd otherwise have to swim through.
- **Puzzle:** **crates float**, so draining a pool lowers a crate onto a plate. Pools linked by pipes drain together.
- **Combat:** the blob is a **shield**: each orb that hits it splashes and costs 1 unit.

### 4.2 Throw / pour (Q while carrying)
- **Wave:** all carried units fly in the chosen direction. On landing, the wave rolls along the surface for `units × 16 px` **(tune)**, then sinks into a puddle.
- **Wall splash:** a wave that hits a wall leaves a **wet patch** on it.
- **Pour** (down): the water drops and settles into the lowest tiles below, as a **puddle**, filling dips one tile at a time.
- **Movement:** a puddle fills a spike gap level with the ground, ready to freeze into a floor (see 4.3).
- **Puzzle:** the wave **shoves pushables** (crates, loose rocks, pebbles) with force scaling with units. It carries light things along, and refills another pool.
- **Combat:** a wave knocks wisps along and off edges or into spikes. A wave over a sentry **douses** it: no fire for 3 s **(tune)**.

### 4.3 Freeze (W)
Freezes all water within **28 px** **(tune: `freeze_radius`)**, including the blob you carry:

| Water | Becomes |
|---|---|
| **Pool surface** (if any part is in radius) | A full-width **ice sheet**, 8 px thick, on top of the pool. Solid and slippery. The water below stays water |
| **Carried blob** | An **ice block** (1–2 units = 8×8, 3–4 units = 16×16) that drops in front of you. Standable, pushable, slides far on ice |
| **Puddle** | **Ice patch** |
| **Wet patch on a wall** | **Ice ledge**: a foothold, like a stuck rock |
| **Wave in flight** | **Ice chunks** that stick where they land |

- **Movement:** ice runways, ice ledges, an ice block to stand on.
- **Puzzle:** frozen water can't be pulled again (a commitment, like spent earth). An ice block slid across an ice sheet presses a far plate.
- **Combat:** a wisp touching water when you freeze is **frozen in an ice block**. Push it into spikes or drop it from a height to shatter it, which defeats it. An ice block blocks orbs.

## 5. Ice: the slippery surface

Starting values, all **(tune)**:

| Property | Ice | Notes |
|---|---|---|
| Ground acceleration | ×0.15 of normal | Slow to start, slow to turn |
| Ground friction | ×0.08 of normal | You keep sliding after release |
| Speed cap on ground | **not applied** while above run speed | Momentum from a dash, jet or launch is kept on ice |
| Jump | keeps full horizontal speed | **Long jumps** off ice are the signature move |
| Wall slide on ice walls | ×2 slide speed, no wall-cling | Wall jumps still work |

- **Look:** pale cyan with white streaks and a glint that slides along it as you move. Skid sparks (white specks) when you change direction on ice.
- **Readable:** ice is cyan, water is blue. A frozen pool keeps a faint blue tint under the sheet so you can see there's water below.

## 6. Swimming (minimal)

- In water, the player swims slowly: the jump key strokes up, gravity is weak, and you can jump out from the surface.
- **Under an ice sheet,** you can't surface there. Swim to an open edge or hole. This is a pressure moment, not a timer.
- No breath meter in v0.

## 7. Enemies

| Enemy | Water interaction |
|---|---|
| **Wisp** | Wave shoves it. Freeze it in water → ice block → shatter to defeat |
| **Sentry** | Wave douses it for 3 s. Blob and ice block absorb or stop orbs |

## 8. Cross-element (mixed rooms)

- **Fire:**
  - Water **puts out** burning tiles and bonfires: burning grass becomes **wet grass** (won't burn for 4 s), a bonfire becomes a smoking wet leaf pile.
  - **Fire melts ice:** ice turns back into water (falls as a puddle, or the sheet melts back into the pool).
  - **A fireball through the blob** makes a **steam cloud** that works as a hot updraft for glide and gust.
- **Air:**
  - A gust slides ice blocks.
  - A gust over a pool makes a wave in the gust's direction.
  - You can glide over a pool, and dash along ice keeping the momentum.
- **Earth:**
  - A rock thrown into a pool splashes, making wet patches around it.
  - Earth next to water: **mud** (parking lot).
  - A snake of earth can dam water.

## 9. Rooms (rough)

1. **Still Water:** pull, see the level drop, swim.
2. **Draining:** lower a pool to uncover the way on.
3. **Float:** drain to drop a floating crate onto a plate.
4. **First Ice:** freeze a pool surface and run across.
5. **Momentum:** long jumps off ice runways.
6. **Ice Block:** freeze the blob into a block and push it.
7. **Wave:** throw waves at wisps and crates.
8. **Frozen Ledges:** wall splashes → ice footholds.
9. **Under the Ice:** swimming under a frozen sheet, find the opening.
10. **Glacier:** scrolling summit, the Goal.

## 10. Open questions (decide after Fire)

- Should freeze move to Q (fewer keys), or stay on W?
- Should freeze cover an area around you, or be aimed at range (a frost dart)?
- Should a frozen pool sheet span the whole width or only what's in the radius?
- How many units per pool, and is 4 the right blob max?
- Is swimming worth the code, or should water be "deadly deep / shallow only" like spikes?

## 11. Parking lot

- Water whip (a tendril strike)
- Surfing on streams (from the original pitch)
- Freezing a waterfall into a ladder
- Icicles falling from ceilings
- Mud (earth + water) as a sticky slow surface
- Steam vents
- A water diamond?
- A rideable ice block
