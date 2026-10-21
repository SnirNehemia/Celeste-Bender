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

@export_group("Flame smoke")
## Smoke given off by the flame tips, per second: the whole jet plume, one brazier,
## one fireball. (Licks torn off any flame also turn into smoke as they die.)
@export var jet_plume_smoke_per_second: float = 12.0
@export var brazier_smoke_per_second: float = 3.0
@export var fireball_smoke_per_second: float = 24.0
