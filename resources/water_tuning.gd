class_name WaterTuning
extends Resource
## Every number that affects how WATER looks and feels lives here (Water_bending.md).
## The Water twin of FireTuning: the player holds one (resources/water_tuning.tres)
## in its `water_tuning` field, so the F5 panel shows it as the "Water" tab and F4
## saves it. Each room's WaterWorld preloads the same .tres, so a value changed in
## the panel reaches the water at once.
##
## Stages add their own export groups (Water_bending.md §14). W1 only needs the
## simulation of still and flowing water bodies (§6.1), the falling drops of a
## spill, and floating.

@export_group("Water bodies")
## Width of one column of a body, px (Water_bending.md §6.1). Smaller = finer waves
## but more columns to step. Read when a room loads (changing it in the panel needs
## a room reload: R doesn't rebuild the columns).
@export_range(1.0, 8.0, 1.0) var column_width: float = 2.0
## Gravity of the water, px/s². With the pipe model, a wave travels at about
## sqrt(water_gravity × depth): 900 and 24 px deep give ~147 px/s, so a wave crosses
## a one-screen pool in about 2 s.
@export var water_gravity: float = 900.0
## Waves move as if the water were never deeper than this, px. Deep water would
## otherwise make waves so fast that the step would need many more sub-steps.
@export var max_wave_depth: float = 40.0
## How much of the flow between two columns dies away per second (0 = never).
## Higher = waves settle sooner; lower = the water sloshes longer.
@export_range(0.0, 10.0) var flow_damping: float = 0.9
## Viscosity: how fast each pipe's flow evens out with its neighbours', per second.
## It hardly touches long waves but kills the column-to-column flicker that would
## otherwise keep a "calm" pool awake for ages.
@export_range(0.0, 100.0) var flow_viscosity: float = 30.0
## Sub-steps are added until a wave moves at most this share of a column per
## sub-step (the stability limit is 1; lower is calmer and costs more).
@export_range(0.1, 1.0) var max_step_courant: float = 0.9
## Never more sub-steps than this per physics frame (a cap on the cost).
@export_range(1, 16) var max_substeps: int = 8
## Water flowing off the end of a body onto ground at most this much lower, px, just
## flows on (the body grows over that ground). A bigger drop is a SPILL: the water
## pours over the lip as falling drops.
@export var spill_drop: float = 6.0
## Surface tension: water no deeper than this, px, doesn't spread onto dry ground.
## So a puddle stops spreading when it's this thin (4 units on a flat floor spread
## to about 128 px at 2 px).
@export var puddle_min_depth: float = 2.0
## A body whose flows are all slower than this (px of depth per second), whose
## ripples are all smaller than `sleep_ripple`, px, and whose surface is level falls
## asleep: it costs nothing until something touches it.
@export var sleep_flow: float = 1.0
@export var sleep_ripple: float = 0.05

@export_group("Ripples")
## The small, fast ripples on top of the bulk waves (a spring chain along the
## surface line, cosmetic: it moves no water). Spring stiffness (1/s²), damping
## (1/s), and how strongly neighbours pull each other (1/s²): the spread is what
## makes a ring run outward from a drop. Stepped once per frame, so keep
## sqrt(stiffness + 4 x spread) under about 90 or the ripples go wild.
@export var ripple_stiffness: float = 120.0
@export var ripple_damping: float = 4.0
@export var ripple_spread: float = 1500.0
## A ripple never lifts or sinks the surface line more than this, px.
@export var ripple_max_height: float = 3.0

@export_group("Drops")
## Water in one falling drop, in units (1 unit = 64 px², one tile of water).
@export var drop_units: float = 0.0625
## Gravity on falling drops, px/s², and their fastest fall, px/s.
@export var drop_gravity: float = 600.0
@export var drop_max_fall_speed: float = 360.0
## How hard a falling drop kicks the surface where it lands (a wave in the bulk and
## a ripple), scaled by its speed.
@export var drop_splash_strength: float = 0.6
## Most drops alive in one room (Water_bending.md §6.1 cap; W2 makes these real
## particles). Past it, a spill pours fewer, bigger drops.
@export_range(16, 2000) var max_drops: int = 400
## Spilling water leaves its lip at the flow's speed times this, px/s per px/s.
@export var spill_launch_scale: float = 1.0

@export_group("Loose water")
## Stage W2 (Water_bending.md §6.1 part 2): the drops are PARTICLES. Each pulls on
## its neighbours within `cohesion_radius` px toward `cohesion_rest` px apart (a
## spring, `cohesion_stiffness`, 1/s² per px), and matches their speed a little
## (`cohesion_viscosity`, 1/s). That's what keeps a thrown ball round, beads a pour
## into drops and lets a stretched stream pinch off. No pressure solve: water that
## lands stops being particles.
@export_range(2.0, 10.0) var cohesion_radius: float = 4.5
@export_range(0.5, 5.0) var cohesion_rest: float = 2.2
@export var cohesion_stiffness: float = 260.0
@export var cohesion_viscosity: float = 6.0
## Closer than cohesion_rest, the spring pushes this many times harder: it keeps a
## ball the size of its water (higher = puffier, lower = it squeezes smaller).
@export_range(1.0, 20.0) var cohesion_repulsion: float = 6.0
## Air drag on particles, share of their speed lost per second.
@export_range(0.0, 2.0) var particle_air_drag: float = 0.15
## A particle touching a wall loses this share of its fall speed per hit: water
## runs down walls a little slower, and clings at edges before it drips.
@export_range(0.0, 1.0) var wall_stick: float = 0.35
## Splash crown: a particle landing in a pool faster than this, px/s, bounces back
## up out of it with this chance (it stays a particle), at `crown_bounce` of its
## speed. A ball hitting a pool throws up a crown of its own water.
@export var crown_min_speed: float = 130.0
@export_range(0.0, 1.0) var crown_chance: float = 0.3
@export_range(0.0, 1.0) var crown_bounce: float = 0.4
## Sources (pipes, waterfalls): each particle leaves with a random nudge of up to
## this many px/s, sideways (x) and up/down (y). Low = a smooth, glassy waterfall;
## high = a scattered spray. (Before the W2 play-test: 6 and 4.)
@export_range(0.0, 30.0) var pour_jitter_x: float = 1.5
@export_range(0.0, 30.0) var pour_jitter_y: float = 1.0
## Soaking (stub of W8's wet layer): an absorbent tile (earth, grass) under water
## that lands takes up to this many units before it's wet; then water puddles on it.
@export var soak_per_tile: float = 0.25
## Debug key 6: throw a ball of this many units at this speed, in the arrow direction.
@export var debug_throw_units: float = 4.0
@export var debug_throw_speed: float = 200.0

@export_group("Metaballs")
## Particles are drawn as soft dots into their own picture, then a threshold
## shader turns overlapping dots into smooth blobs (Water_bending.md §6.3). Off:
## plain 2 px squares (the fallback).
@export var use_metaballs: bool = true
## Radius of each particle's soft dot, px: bigger = rounder, fatter blobs.
@export_range(1.0, 8.0) var blob_dot_radius: float = 3.2
## The blob's edge: where the summed dots reach this, 0..1 (lower = fatter).
@export_range(0.05, 0.95) var blob_threshold: float = 0.45
## Fast particles are drawn stretched along their velocity: this much longer per
## px/s (a waterfall becomes a ribbon, §6.2 `waterfall_particle_scale`). 0 = round.
@export_range(0.0, 0.05) var blob_stretch: float = 0.012
## White water on loose water: a particle foams when it moves faster than
## `particle_foam_speed_start` px/s (fully at `particle_foam_speed_full`: the bottom of
## a tall waterfall), and for `particle_foam_life` s after it hits something (bouncing
## out of a pool as a crown, a wall, a crate) or is thrown off a splash or a breaking
## wave. `particle_foam_strength`: how white full foam is (0 = never).
@export var particle_foam_speed_start: float = 240.0
@export var particle_foam_speed_full: float = 350.0
@export_range(0.0, 2.0) var particle_foam_life: float = 0.35
@export_range(0.0, 1.0) var particle_foam_strength: float = 0.8

@export_group("Breaking waves")
## Waves behave more like the loose water (W2 play-test): where a pool's surface
## rises faster than `wave_break_speed` px/s, the crest BREAKS: bits of it leave the
## pool as foaming particles, thrown up at `wave_break_throw` x the rise speed (plus
## the water's own sideways speed), and fall back in, kicking new waves. The water is
## only borrowed: it all lands again. wave_break_throw 0 = off.
@export var wave_break_speed: float = 20.0
@export_range(0.0, 8.0) var wave_break_throw: float = 3.5
## How often a breaking column throws a particle, per second, when it rises at twice
## wave_break_speed (slower = rarer). At most `wave_break_max_per_frame` a frame in a room.
@export var wave_break_rate: float = 60.0
@export_range(0, 32) var wave_break_max_per_frame: int = 8

@export_group("Floating")
## How strongly water lifts a floating thing: 2 = it floats half under water.
@export var buoyancy: float = 2.0
## How much of a floating thing's speed the water takes away per second, at full
## depth. Keeps a dropped crate from bouncing out again.
@export var water_drag: float = 4.0
## Floating things slide down the slope of a wave: px/s² per unit of slope.
@export var wave_slope_push: float = 400.0
## Something falling into water pushes a wave: this share of its speed.
@export var entry_splash_strength: float = 0.25

@export_group("Look")
## Which look the water shader draws, to compare in play (key 7 cycles them; F4
## saves the choice). B: see-through, swaying, caustics. C: pixel-art bands with
## dithered edges and sparkles. A: the B tint, plain. B+C: B with the bands over it. Foam and spray in all three.
@export_enum("B: see-through", "C: pixel bands", "A: plain", "B+C: blend") var look_style: int = 3
## Look C: how tall each band of blue is, px (4 bands: light, mid, dark, deep).
@export_range(2.0, 16.0, 1.0) var band_px: float = 7.0
## Looks C and B+C: how much the bands cover what's behind them (1 = opaque).
@export_range(0.0, 1.0) var band_alpha: float = 0.9
## Look B+C: how strongly the bands are laid over the see-through B (0 = pure B,
## 1 = pure C). B's own cover is shallow_alpha / deep_alpha.
@export_range(0.0, 1.0) var blend_band_alpha: float = 0.5
## The water shader (scenes/objects/water/water.gdshader). How much the blue covers
## what's behind the water: at the surface, and at full depth (`deep_full_depth` px).
@export_range(0.0, 1.0) var shallow_alpha: float = 0.45
@export_range(0.0, 1.0) var deep_alpha: float = 0.88
@export var deep_full_depth: float = 48.0
## How far things seen through the water sway, in whole px (0 = still).
@export_range(0.0, 3.0, 1.0) var wobble_px: float = 1.0
## Brightness of the drifting light lines in shallow water (0 = none).
@export_range(0.0, 0.5) var caustic_strength: float = 0.16
## The caustic cells' average size, px (bigger = fewer, wider cells).
@export_range(8.0, 120.0, 1.0) var caustic_size: float = 42.0
## How uneven the cells are: 0 = a regular grid of round cells, 1 = gently bent
## (the first look), 2-3 = stretched, random-looking shapes.
@export_range(0.0, 3.0) var caustic_warp: float = 1.0
## Line thickness (0.02 = hairline, 0.2 = wide soft bands).
@export_range(0.01, 0.3) var caustic_thickness: float = 0.08
## Foam: water running faster than `foam_speed_start` px/s starts to foam, fully at
## `foam_speed_full`. Choppy ripples foam too (ripples moving `foam_ripple_full`
## px/s foam fully): splashes and wakes.
@export var foam_speed_start: float = 40.0
@export var foam_speed_full: float = 140.0
@export var foam_ripple_full: float = 20.0
## Spray: white specks (only a look, no water in them) thrown up when a drop lands
## faster than `spray_min_speed` px/s, by splashes, and from spilling lips.
@export var spray_min_speed: float = 120.0
@export var spray_life: float = 0.45
@export_range(0, 1000) var max_spray: int = 300

@export_group("Water hands")
## Stage W3 (Water_bending.md §5.1): hold 1 to steer a waterball in slow motion.
## The world's speed while holding (the ball runs in real time).
@export_range(0.05, 1.0) var hold_time_scale: float = 0.3
## The ring: how far from your center the ball can go, px. Pushing it out of the
## ring lets go of it (a throw).
@export_range(16.0, 160.0) var control_radius: float = 56.0
## Where the ball appears: this far in front of you, px.
@export var ball_start_distance: float = 8.0
## Steering, in REAL time: top speed px/s, how fast it gets there (px/s²), and how
## fast it stops with no arrow held (px/s²). A weight of water, not a mouse cursor.
@export var ball_move_speed: float = 90.0
@export var ball_accel: float = 500.0
@export var ball_drag: float = 350.0
## Let go by itself after this many REAL seconds (slow motion can't be held forever).
@export_range(0.5, 10.0) var max_hold_time: float = 4.0
## The ball gathers water within this many px of its edge, at gather_rate units per
## REAL second, up to ball_max_units.
@export var gather_reach: float = 6.0
@export var gather_rate: float = 6.0
@export_range(0.5, 10.0) var ball_max_units: float = 4.0
## On release the water keeps its steering velocity times this (it moved in slow
## motion, so without a boost a throw would look feeble).
@export_range(0.5, 5.0) var throw_multiplier: float = 2.5
## Under water, a ball with water in it moving INTO something SHOVES it once, the
## way the ball moves, like a gust (after play-test 3): you, or a floating crate.
## The shove is ball_push_speed (game px/s); yours is scaled by how much of you is
## under water, and only from ball_push_min_share under (a floating crate, about
## half under, takes it whenever it's wet). The ball gives its speed away:
## it stops, and must leave the thing before it can shove it again.
@export var ball_push_speed: float = 200.0
@export_range(0.0, 1.0) var ball_push_min_share: float = 0.5

@export_group("Water snake")
## Stage W4 (Water_bending.md §5.1-5.2), all in REAL time like the ball.
## How you ask for a snake (after the first W4 play-test: heavy water made the ball
## feel slow everywhere, so the ball keeps its W3 feel and these are tried instead;
## pick the one that feels best and the rest go):
##   KEY: hold `water_snake` (3) while the ball comes up out of a pool.
##   DOUBLE_TAP: start the hold with a double tap of 1 (the ring turns green); in
##     that hold, every lift out of a pool raises a snake.
##   GENTLE: no key; come up slower than snake_max_rise_speed (tap ↑) and a snake
##     follows; faster, it tears (a splash rains back). The snake tears too if you
##     lift it faster than that.
##   REST: the ball in a pool with no arrow held for snake_rest_time arms (the ring
##     turns green); armed, lifting it out raises a snake.
## In every mode but GENTLE, speed never tears a snake.
enum SnakeTrigger { KEY, DOUBLE_TAP, GENTLE, REST }
@export var snake_trigger: SnakeTrigger = SnakeTrigger.KEY
## DOUBLE_TAP: a press of 1 within this many REAL seconds of the last one.
@export var snake_double_tap_window: float = 0.3
## REST: how long (real s) the ball rests in a pool (no arrow held) before it's armed.
@export var snake_rest_time: float = 0.4
## GENTLE: lifting the ball out of a pool no faster than this (px/s) raises a snake;
## faster, it tears: a little water rains back and the ball comes out alone.
@export var snake_max_rise_speed: float = 40.0
## With a snake hanging from it, the ball moves at this share of ball_move_speed: a
## little slower, the water's weight (play-test 4: a 30 px/s lift felt sluggish).
@export_range(0.1, 1.0) var snake_speed_share: float = 0.85
## The snake's thickness, px: it holds snake_width px² of water per px of length
## (6: 1 unit per ~11 px), drawn from its pool as it grows (and given back as it
## shortens). The pool running dry tears it.
@export var snake_width: float = 6.0
## Longer than this (px, along the rope) and it tears. Its pool drops as it fills
## it, so a snake from the ring's edge down to a lowered surface needs some room.
@export var snake_max_length: float = 80.0
## The ball back down within this many px of the surface (or under it), not rising,
## and the snake sinks back into its pool (no tear).
@export var snake_min_length: float = 4.0
## The foot slides along the surface toward under the ball at this speed (px/s),
## dragging a wave (snake_foot_wake x its speed pushes the water). 110: close behind
## the faster snake (ball_move_speed x snake_speed_share), so a sideways sweep
## doesn't stretch it to a tear.
@export var snake_foot_speed: float = 110.0
@export var snake_foot_wake: float = 0.6
## The rope's own weight (px/s²): it sags and swings behind the ball.
@export var snake_sag: float = 150.0
## Its head (the ball) shoves what it moves into once per touch, like a gust:
## crates, leaf piles, wisps (Pushable). px/s, like gust_push_strength.
@export var snake_shove_strength: float = 160.0
## GENTLE, lifting too fast: this much of the pool (units) jumps up and rains back.
@export var snake_tear_splash_units: float = 0.25

@export_group("Water and projectiles")
## Any water (a pool, loose drops, the held ball) puts a FIREBALL out, and SOAKS a
## sentry orb (after play-test 3): it keeps orb_soaked_speed_keep of its speed and
## from then on falls under orb_soaked_gravity (px/s²). Soaked, it no longer
## bounces: the next solid pops it. It still kills.
@export_range(0.0, 1.0) var orb_soaked_speed_keep: float = 0.3
@export var orb_soaked_gravity: float = 300.0
## Inside water a soaked orb sinks: gravity orb_sink_gravity (the water holds it up)
## and a drag that takes orb_water_drag of its speed a second (like crates).
@export var orb_sink_gravity: float = 60.0
@export var orb_water_drag: float = 6.0

@export_group("Swimming")
## The water holds you back in proportion to how much of you is in it (the
## submerged share of the hitbox, 0..1; Water_bending.md §5.4). Run speed is
## multiplied by 1 - water_resistance x share: 0.4 makes fully under 60 %.
@export_range(0.0, 0.9) var water_resistance: float = 0.4
## A jump from the bottom is multiplied by 1 - water_jump_loss x share.
@export_range(0.0, 0.9) var water_jump_loss: float = 0.5
## Water shallower than this around you, px, doesn't count (puddles and the thin
## films splashes leave on the ground don't slow you down).
@export_range(0.0, 8.0) var wade_min_depth: float = 3.0
## At least this share under water and you swim: jump becomes a stroke.
@export_range(0.5, 1.0) var swim_share: float = 0.9
## In water, gravity and the fastest sink blend toward these, by the share.
@export var swim_gravity: float = 240.0
@export var swim_max_sink: float = 50.0
## Falling into water faster than that sink speed, the water brakes you this hard,
## px/s² (at full share): a plunge, not a stop.
@export var swim_brake: float = 1500.0
## Each jump press under water sets your upward speed to this, px/s: tap jump
## again and again to swim up (one stroke rises about speed² / 2 / swim_gravity).
@export var swim_stroke_speed: float = 80.0
## Jump with your head out of the water (not standing): a leap out, this share of a
## full jump.
@export_range(0.0, 1.5) var surface_leap_scale: float = 1.0
## No air gust under water (after play-test 3): with MORE than this share of you
## under (0.5 = the water above your middle), the gust key only makes a little puff.
@export_range(0.0, 1.0) var gust_max_submerged_share: float = 0.5

@export_group("Player in water")
## The player wading or swimming drags the water along: the water around the body
## is pulled toward this share of the player's speed, so a hump builds in front and
## a dip behind. (0.9: the water already slows the player to ~54 px/s.) (Water_bending.md §5.4, "your body pushes the water").
@export_range(0.0, 1.5) var player_wake_strength: float = 0.9
## How quickly the water takes on that speed, per second (high = a sharper wake).
@export var player_wake_grip: float = 8.0
## Where the body cuts the surface, the ripples get a kick this big per px/s of
## speed: the small, fast rings of a wake.
@export var player_ripple_strength: float = 0.15
## Falling in or leaping out faster than this, px/s, makes a splash.
@export var splash_min_speed: float = 60.0
## A splash pushes the water down this much per px/s of speed, px (capped at 10).
@export var splash_dip_per_speed: float = 0.03
## A splash throws this many drops per px/s of speed (capped at 16), taken from the
## pool's own water, at up to this share of the entry speed.
@export var splash_drops_per_speed: float = 0.05
@export var splash_throw_scale: float = 0.6

@export_group("Debug keys")
## Units dropped by 9 (debug_water_dump) and taken by 0 (debug_water_drain).
@export var debug_bucket_units: float = 4.0
## 8 (debug_water_wave): how deep the poke's dip is, px (its water heaps up around
## it, and the two make the waves).
@export var debug_wave_depth: float = 6.0
