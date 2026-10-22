class_name FireTuning
extends Resource
## Every number that affects how FIRE bending feels lives here (Fire_bending.md).
## The Fire twin of PlayerTuning and EarthTuning: the player holds one
## (resources/fire_tuning.tres) in its `fire_tuning` field, and the fire code reads
## it fresh every time, so Remote-tab edits while the game runs take effect at once.
##
## Stages add their own export groups as they need them (Fire_bending.md §11):
## F1 only needs the bar itself.

@export_group("Fire bar")
## Most pips the bar can hold (Fire_bending.md §4.1). Pips gained above this are lost.
## The HUD draws this many slots, so changing it changes the row's width too.
@export_range(1, 10) var max_pips: int = 5

@export_group("Flame jet")
## Length of one burst = one pip, seconds (Fire_bending.md §4.1, §5.2). The burst
## always runs to its end, unless Jump cancels it or a ceiling bonks it.
@export var jet_burst_time: float = 0.5
## Base top speed along the steered direction, px/s. Multiplied by the thrust curve.
@export var jet_max_speed: float = 170.0
## Base acceleration toward that top speed, px/s². Multiplied by the thrust curve.
@export var jet_accel: float = 1400.0
## Thrust multiplier at ignition and at the end of the burst. The burst surges at
## ignition and tapers off, the same way every time, so it can be learned.
@export var jet_thrust_start: float = 1.3
@export var jet_thrust_end: float = 0.8
## Optional shape of the taper over the burst (x = 0..1 through the burst, y = the
## multiplier). When set, it replaces the straight start -> end line. Edit it in the
## Inspector (the F5 panel shows it read-only).
@export var jet_thrust_curve: Curve
## Acceleration used to CHANGE DIRECTION, px/s²: it bleeds off the part of the
## velocity that doesn't point where you steer (sideways, or backwards). Kept high so
## a burst feels steerable even though it can't be stopped.
@export var jet_turn_accel: float = 3000.0
## Fraction of the velocity kept when a burst ends (1 = all of it), before normal
## gravity takes over.
@export_range(0.0, 1.0) var jet_end_carry: float = 1.0

@export_group("Flame jet look")
## Plume length at full thrust (ignition), px. It shrinks with the thrust curve.
@export var jet_plume_length: float = 24.0
## Plume width at the nozzle and where it fans out widest, px (the whole bundle of
## tongues, not one tongue).
@export var jet_plume_nozzle_width: float = 8.0
@export var jet_plume_fan_width: float = 14.0
## How many flame tongues make up the plume. They lick out of step, the middle ones
## longest, so the jet reads as a ragged sheaf of flame rather than one cone.
@export_range(1, 8) var jet_plume_tongue_count: int = 4
## How much each tongue's tip forks into two dancing points (0 = never).
@export_range(0.0, 1.0) var jet_plume_fork_amount: float = 0.6
## Small licks of flame torn off the plume's tips, per second (all tongues together).
## They flutter, shrink and cool as they drift away.
@export var jet_plume_licks_per_second: float = 40.0
## How long a lick lives, seconds, and how fast it leaves the tip, px/s.
@export var jet_plume_lick_lifetime: float = 0.3
@export var jet_plume_lick_speed: float = 45.0
## Angle between the outermost tongues, degrees: how much the sheaf fans out.
@export var jet_plume_spread_degrees: float = 14.0
## Light camera shake while thrusting, px (scaled by the thrust).
@export var jet_shake_strength: float = 0.5
## Body squash along the thrust axis while jetting: x = across, y = along the thrust.
@export var jet_squash: Vector2 = Vector2(0.8, 1.2)
## Embers streaming off the plume, per second.
@export var jet_embers_per_second: float = 60.0
## Sparks in the ignition "whoomp" ring and in a chain's pump flare.
@export var jet_ignition_spark_count: int = 14
@export var jet_pump_spark_count: int = 10

@export_group("Fireball")
## Flight speed, px/s, straight and without gravity (Fire_bending.md §5.1).
@export var fireball_speed: float = 200.0
## Distance flown before it gutters out, px.
@export var fireball_max_range: float = 160.0
## Gravity on the fireball, as a fraction of the player's gravity (PlayerTuning.gravity):
## 0.2 = it droops gently over its flight.
@export_range(0.0, 1.0) var fireball_gravity_scale: float = 0.2
## Level throws get a small lift that cancels the drop over the full range, so a
## fireball thrown sideways from standing arcs a little (about 14 px) and comes back
## to hand height at fireball_max_range instead of hitting the floor after 25 px.
## Scaled by how sideways the throw is (none straight up or down). Off = no lift.
@export var fireball_arc_lift: bool = true
## On a hit, everything flammable within this many px of the hit point catches too.
@export var fireball_splash: float = 6.0
## Holding Q aims in slow motion (the GustAim state, shared with the gust): the
## world's speed while aiming, and the real seconds before it throws by itself.
@export_range(0.05, 1.0) var fireball_aim_time_scale: float = 0.3
@export var fireball_aim_max_real_time: float = 0.8

@export_group("Fireball look")
## Embers left behind in flight, per second.
@export var fireball_trail_embers_per_second: float = 40.0
## Sparks in the ring when it bursts on a hit.
@export var fireball_impact_spark_count: int = 12
## How long the 1-2 embers that stick to the hit surface keep glowing, seconds.
@export var fireball_stuck_ember_time: float = 0.5

@export_group("Burning grass")
## A burning grass cell lights its surface neighbours after this many seconds
## (Fire_bending.md §6.1)...
## (0.25 in the spec; slowed after the F5 play-test.)
@export var spread_delay: float = 0.32
## ...give or take up to this much, picked at random per cell, so the front looks
## alive and not like a metronome.
@export var spread_jitter: float = 0.08
## How long a cell burns (a hazard, spreading), then how long it smolders (harmless,
## charred and glowing specks) before it is ash for good. Seconds, each give or take
## burn_time_jitter (a fraction, per cell), so neighbours don't go out in step.
## (Spec: 1.0 and 0.6; both longer after the F5 play-test.)
@export var burn_time: float = 1.6
@export var smolder_time: float = 2.5
@export_range(0.0, 0.5) var burn_time_jitter: float = 0.15
## Most cells burning at once in one room. Ignitions past the cap wait in the queue
## until a cell stops burning, so a big field can never run away.
@export_range(1, 512) var max_burning_tiles: int = 96
## How far the deadly flames reach out from a burning cell's open faces, px. The
## player touching that band dies, like on spikes.
@export var grass_fire_hazard_height: float = 5.0

@export_group("Burning grass look")
## Average flame tongues on a burning floor cell (each cell rolls 1 to this + 1, at
## random spots, so the fire never lines up with the tiles).
@export_range(1, 4) var grass_tongues_per_tile: int = 2
## Average tongue length on a floor, px; each tongue is 55-135% of it (walls and
## ceilings get shorter ones).
@export var grass_flame_length: float = 7.0
## A flame that just appeared flares (longer, white-hot, a soft bright glow at its
## foot) for this many seconds, so the eye follows the front.
@export var grass_flare_time: float = 0.1
## Smoke from each burning cell's tongues, per second (smoldering cells puff now and
## then on top of that).
@export var grass_smoke_per_second: float = 2.0

@export_group("Flame smoke")
## Smoke given off by the flame tips, per second: the whole jet plume, one brazier,
## one fireball. (Licks torn off any flame also turn into smoke as they die.)
@export var jet_plume_smoke_per_second: float = 12.0
@export var brazier_smoke_per_second: float = 3.0
@export var fireball_smoke_per_second: float = 24.0

@export_group("Thicket & overgrown")
## A burning thicket cell lights its 4 neighbours (thicket, touching grass, an
## overgrown cover) after this many seconds (Fire_bending.md §6.1b). Faster than
## grass: thicket is dry fuel. Grass lights a touching thicket cell after
## spread_delay, like any grass neighbour.
@export var thicket_spread_delay: float = 0.15
## How long a thicket cell burns before it crumbles into falling ash and leaves open
## air, seconds (give or take burn_time_jitter).
@export var thicket_burn_time: float = 0.8
## The first part of a thicket cell's burn, as a share of it: the brambles only glow
## from inside along their branches. Harmless. Then the flames break out and the
## cell kills on touch until it crumbles.
@export_range(0.0, 0.9) var thicket_glow_share: float = 0.2
## Ash flakes that shower down from a crumbling thicket cell (glowing and gray).
@export_range(0, 40) var thicket_ash_flakes: int = 10
## Fire reaching any cell of an overgrown cover flashes the whole connected cover
## over in this many seconds: a bright front races across it, it burns as one sheet
## of flame (deadly), then it collapses all at once.
@export var overgrown_flashover_time: float = 0.3
## The collapse: freeze frames (seconds, real time) and a shake, like a cracked wall
## breaking (Fire_bending.md §9.3).
@export var overgrown_freeze_time: float = 0.033
@export var overgrown_shake_strength: float = 2.0
@export var overgrown_shake_time: float = 0.2

@export_group("Ash flakes")
## Ash that stays (after the F6 play-test): burnt grass and crumbled thicket leave
## light gray flakes in the room's PebbleField. Unlike pebbles they fall slowly,
## flutter, ride the wind (updrafts lift them) and swirl round the player.
## Flakes left per grass cell that turns to ash, and per crumbled thicket cell.
@export_range(0, 10) var ash_flakes_per_grass_cell: int = 2
@export_range(0, 20) var ash_flakes_per_thicket_cell: int = 5
## Most ash flakes in one room (separate from the pebble cap); the oldest go first.
@export_range(0, 600) var ash_max_per_room: int = 240
## Gravity on a flake, px/s² (a pebble: 400). With the air drag below it falls at
## about ash_gravity / ash_air_drag px/s.
@export var ash_gravity: float = 70.0
## How fast a flake in the air takes on the air's speed (the wind's, or still air),
## per second. Higher = lighter, floatier.
@export var ash_air_drag: float = 3.0
## Side-to-side flutter of a falling flake, px/s.
@export var ash_flutter_speed: float = 10.0
## A flake moves with this share of the wind's speed (all directions: an updraft
## lifts it, unlike a pebble).
@export_range(0.0, 2.0) var ash_wind_speed_scale: float = 0.9
## Friction on a flake sliding over the ground, per second.
@export var ash_ground_friction: float = 4.0
## The player (or a crate, a wisp) stirs flakes this many px around its body, carrying
## them along with ash_kick_carry of its speed and lifting ground flakes at
## ash_kick_up_speed px/s (± half).
@export var ash_kick_reach: float = 6.0
@export_range(0.0, 2.0) var ash_kick_carry: float = 0.6
@export var ash_kick_up_speed: float = 35.0
## A gust blows flakes this much harder than pebbles (they're light).
@export var ash_gust_strength_scale: float = 1.4

@export_group("Thicket leaves")
## Leaves on thicket's open faces (after the F6 play-test): a bush of the leaf
## piles' diamond leaves. They move like the grass blades: a spring pulls each leaf
## toward where the idle sway, the wind and the player push it. Leaves per face
## (tops get one more); read when the room loads.
@export_range(0, 10) var leaves_per_face: int = 5
## Leaves spread over each thicket tile itself (buried ones too), under the edge
## leaves, so the whole mass looks like a bush. Read when the room loads.
@export_range(0, 10) var leaves_per_cell: int = 4
## An overgrown cover that passes for thicket grows the same bush, its leaves pulled
## this far toward a dry brown (0 = no difference, 1 = all brown): a hint that
## something is hidden behind it. Read when the room loads.
@export_range(0.0, 1.0) var cover_leaf_brownness: float = 0.3
## How far past the tile's edge the bush reaches, px (leaves sit anywhere from a
## little inside the edge to this far out). Read when the room loads.
@export_range(0.0, 8.0) var leaf_bush_reach: float = 3.5
## The spring (higher = snappier) and its damping (higher = less wobble).
@export var leaf_stiffness: float = 90.0
@export var leaf_damping: float = 8.0
## The most a leaf tip moves from rest, px.
@export var leaf_max_bend: float = 3.0
## Idle sway, px and radians per second.
@export var leaf_idle_sway: float = 0.4
@export var leaf_idle_sway_speed: float = 2.4
## Bend per px/s of wind.
@export var leaf_wind_bend_per_speed: float = 0.03
## The player brushing a leaf pushes it this far away from the body, px, and drags it
## by this much per px/s of the player's speed.
@export var leaf_player_push: float = 2.0
@export var leaf_player_drag_per_speed: float = 0.02
## A gust kicks leaves within leaf_gust_reach px of its origin by this much bend
## speed per px/s of gust strength.
@export var leaf_gust_reach: float = 56.0
@export var leaf_gust_kick_per_strength: float = 0.35
