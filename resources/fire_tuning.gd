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
## (The HUD draws only the pips held, not empty slots: Stage F13.)
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
## Ricochets (Stage F12): a fireball BOUNCES off anything that doesn't burn (bare
## earth, stone, crates that won't catch, the Shell) and flies on until its range is
## used up. It keeps this share of its speed per bounce. A bounce that would leave it
## slower than fireball_min_bounce_speed px/s off the surface (skimming, rolling)
## bursts it there instead. fireball_max_bounces caps the count (-1 = no cap).
@export_range(0.0, 1.0) var fireball_bounce_keep: float = 0.85
@export var fireball_min_bounce_speed: float = 40.0
@export var fireball_max_bounces: int = -1

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

@export_group("Hot updrafts")
## Upward speed a hot updraft adds to a GLIDING player, px/s (Fire_bending.md §5.3).
## The glide steers toward glide_max_fall_speed (30) minus this, so 160 rises at
## 130 px/s: stronger than an Air updraft (60 x glide_updraft_lift_multiplier 2 = 120).
## Only the glide and heat receivers feel it; nothing else is lifted.
@export var hot_updraft_lift: float = 160.0
## A burning grass or thicket cell's short, weak updraft: its lift, px/s, and how
## high above the cell's top it reaches, px (§5.3: 16 px).
@export var grass_updraft_lift: float = 60.0
@export var grass_updraft_height: float = 16.0

@export_group("Burning leaves")
## The LEAVES burn, not the pile (F7 play-test): each leaf is its own little fire.
## A lone burning leaf is a harmless ember that lasts this long (± leaf_burn_jitter,
## a share), then it's gone. Leaves inside a bonfire don't burn out (see Bonfire).
## Long enough for most leaves gusted up to fall back down still burning (the ember
## rain lights the grass it lands on); some burn out on the way, which looks right.
@export var leaf_burn_time: float = 3.5
@export_range(0.0, 0.5) var leaf_burn_jitter: float = 0.25
## A burning leaf lights unlit leaves within leaf_spread_radius px of it,
## leaf_spread_delay seconds after it caught (± 50%): fire runs through a heap fast,
## and through a cloud of falling leaves as a chain of embers.
@export var leaf_spread_radius: float = 4.0
@export var leaf_spread_delay: float = 0.06
## Every leaf_ignite_interval seconds a burning leaf (resting or falling) lights the
## flammables within leaf_ignite_reach px of it: grass, air diamonds, other piles.
@export var leaf_ignite_reach: float = 2.0
@export var leaf_ignite_interval: float = 0.2
## A burning leaf curls up and drops faster: its flutter fall speed is multiplied by
## this (3 = a cloud gusted ~90 px up comes down in ~3 s instead of ~7: a fluttering
## leaf averages only ~0.7 x fall_speed).
@export_range(1.0, 5.0) var leaf_ember_fall_scale: float = 3.0
## Leaves the flame JET touches catch this many seconds later (they glow
## meanwhile), so you can jet along a floor of leaves and leave the fire behind you
## (play-test). Like crate_jet_catch_delay. Fireballs light leaves at once.
@export var leaf_jet_catch_delay: float = 0.4

@export_group("Bonfire")
## A bonfire forms where at least bonfire_min_leaves burning leaves LIE together
## (resting, not falling). "Together" = in touching cells of bonfire_cluster_cell px.
@export_range(2, 40) var bonfire_min_leaves: int = 6
@export var bonfire_cluster_cell: float = 6.0
## Its flame (and kill zone and updraft) is as wide as the burning heap, within these.
@export var bonfire_min_width: float = 12.0
## A heap much wider than this gets a row of bonfires, one per bonfire_max_width px
## of the pile (LeafFire._split_wide_heap), so a long pile burns all along.
@export var bonfire_max_width: float = 48.0
## A tongue reaches the full flame height where the heap has this many leaves per
## px of width; thinner parts of the heap burn lower (down to 0.3 of the height).
## A default 60-leaf, 36 px pile has ~2.5/px in its middle and ~0.5 near its ends.
@export var bonfire_full_density: float = 1.5
## How it grows (F7 play-test): first AMBER (glowing leaves, harmless, no lift) for
## bonfire_amber_time, then a LOW flame (bonfire_low_height_share of full height,
## kills, lifts) for bonfire_low_time, then it rises to full height over
## bonfire_grow_time. So you can light it from above and ride its hot air up.
@export var bonfire_amber_time: float = 0.5
@export var bonfire_low_time: float = 0.6
@export_range(0.1, 1.0) var bonfire_low_height_share: float = 0.35
@export var bonfire_grow_time: float = 0.8
## Full flame height, px (Fire_bending.md §6.2: 20).
@export var bonfire_flame_height: float = 20.0
## The hot updraft column above the flame, px tall (§5.3: 48). A glider hovers near
## its top, so this sets how high a bonfire elevator takes you.
@export var bonfire_updraft_height: float = 48.0
## A bonfire burns this long, seconds, holding its leaves; then they burn out.
## 0 = until death or R (§6.2).
@export var bonfire_duration: float = 0.0
## The bonfire lights flammables within this many px of its base and flame, checked
## every few frames while it burns.
@export var bonfire_ignite_reach: float = 4.0
## Sparks popping upward in bursts every bonfire_spark_interval seconds (random in the
## range), bonfire_spark_count sparks each (§9.3).
@export var bonfire_spark_interval: Vector2 = Vector2(0.5, 1.2)
@export var bonfire_spark_count: int = 6
@export var bonfire_smoke_per_second: float = 6.0
## Its flame first breaking out of the amber: a short shake and a flash (§9.4).
@export var bonfire_light_shake: float = 2.0

@export_group("Air diamond conversion")
## How long the orange wipe takes to cross a wind crystal or gust diamond, seconds,
## before it flares into a fire diamond (Fire_bending.md §4.3, §9.3).
@export var conversion_wipe_time: float = 0.25
@export var conversion_spark_count: int = 10

@export_group("Burning objects")
## A vine lit at any point burns through THERE after vine_cut_time seconds and snaps
## (what it held is let go); meanwhile the fire runs outward both ways along the two
## hanging halves at vine_burn_speed px/s. Each burnt piece glows, chars and drops
## off vine_char_time seconds after the fire reached it (Fire_bending.md §6.2, F8
## play-test).
@export var vine_cut_time: float = 0.15
@export var vine_burn_speed: float = 110.0
@export var vine_char_time: float = 0.25
## A burning crate is a deadly flame for this long, seconds, then collapses into ash
## and is gone until R (§6.2: 1.5 s).
@export var crate_burn_time: float = 1.5
## While it burns, a crate lights flammables (grass under it) within this many px.
@export var crate_ignite_reach: float = 3.0
## A crate lit by the JET catches this many seconds later (it smokes and glows
## meanwhile), like grass does (spread_delay) but a little longer: jetting up off a
## crate must not kill you on the spot (F8 play-test). Fireballs light it at once.
@export var crate_jet_catch_delay: float = 0.45
## A leaf platform burns away in this many seconds (§6.2: 0.8 s). It is harmless
## while it burns: that's your time to jump off.
@export var leaf_platform_burn_time: float = 0.8
## A sail's cloth burns away in this many seconds; then it no longer catches wind and
## the platform coasts to the end of its rail (§6.2).
@export var sail_burn_time: float = 0.6

@export_group("Vine monkey")
## Walking (running) speed on its route, px/s (Fire_bending.md §7.2, Stage F11).
@export var monkey_run_speed: float = 45.0
## Its route hops gaps up to this wide, px (between the two rims); wider ones turn it
## back. The far rim may be up to monkey_hop_max_rise px higher, never lower (a lower
## floor would be the gap's own bottom; dropping down ledges waits for routes, F11a).
@export var monkey_hop_max_gap: float = 24.0
@export var monkey_hop_max_rise: float = 16.0
## Upward speed of a hop, px/s. The sideways speed is worked out to land on the far rim.
@export var monkey_hop_speed: float = 170.0
## Lit, it panics this long, seconds (§7.2: 1.5 s, tune), running at
## monkey_torch_speed px/s and turning at walls and ledges, then crumbles to ash.
@export var leafling_torch_time: float = 1.5
@export var monkey_torch_speed: float = 120.0
## While it burns it lights flammables within monkey_ignite_reach px of its body,
## every monkey_ignite_interval seconds.
@export var monkey_ignite_reach: float = 3.0
@export var monkey_ignite_interval: float = 0.1
## A gust snuffs a burning monkey: it smolders, stunned (harmless) for this long.
@export var monkey_snuff_stun_time: float = 1.0
## Pushed (gust, rock, column, snake): stunned and harmless this long, seconds.
@export var monkey_push_stun_time: float = 1.0
## It's light: a gust throws it this many times harder than a wisp, a big rock this
## many times harder than a small one.
@export var monkey_gust_multiplier: float = 1.6
@export var monkey_big_rock_multiplier: float = 1.6
## Hot air lifts it (a heat receiver, §5.3): it rises toward the updraft's lift x
## monkey_heat_lift_multiplier px/s, changing speed at most monkey_heat_accel px/s²
## (its sideways speed dies down at the same rate: the hot air carries it straight
## up, so it doesn't sail through the column).
@export var monkey_heat_lift_multiplier: float = 0.6
@export var monkey_heat_accel: float = 900.0
## How much of a wind zone's wind carries it (1 = all of it).
@export_range(0.0, 2.0) var monkey_wind_carry: float = 1.0

@export_group("Thicket elephant")
## Walking speed on its patrol, px/s (Fire_bending.md §7.2, Stage F11b: slow).
@export var elephant_walk_speed: float = 9.0
## It charges whenever it can hit you: you're in front of it, on its level (your feet
## within its height of its feet), within this many px, in clear view, and its last
## charge ended at least elephant_charge_cooldown seconds ago.
@export var elephant_sight_range: float = 200.0
@export var elephant_charge_cooldown: float = 1.5
## Before a charge it REARS for this long, seconds (the tell; also after a trunk burn).
@export var elephant_rear_time: float = 0.6
## Charge top speed, px/s, and how fast it gets there, px/s². A charge set off by a
## hit (trunk or tail burnt) is elephant_hit_charge_multiplier times faster.
@export var elephant_charge_speed: float = 90.0
@export var elephant_charge_accel: float = 300.0
@export var elephant_hit_charge_multiplier: float = 2.0
## Braking at a ledge, px/s²: it looks this far ahead (v²/2a) and stops at the edge.
@export var elephant_brake_decel: float = 500.0
## A charge into a wall: stunned this long, seconds, with a shake.
@export var elephant_wall_stun_time: float = 1.0
## A spot burns this long, seconds (deadly flames, lighting what it touches), then
## stays burnt until R.
@export var elephant_spot_burn_time: float = 1.4
## The tail whip, every elephant_whip_interval seconds while it walks: it WIGGLES,
## then is RAISED high (the tell), then STRIKES down behind it like a whip (deadly).
@export var elephant_whip_interval: float = 2.6
@export var elephant_whip_wiggle_time: float = 0.6
@export var elephant_whip_raise_time: float = 0.4
@export var elephant_whip_strike_time: float = 0.2
## Its back burning, or anyone standing on its BURNT back this long (seconds), makes
## the tail rise and strike forward over its back instead.
@export var elephant_back_strike_delay: float = 0.25
## A thrown big rock pushes it back at this speed, px/s (stopping a charge); a gust
## nudges it at this one. Both slide out at elephant_push_decel px/s².
@export var elephant_rock_push_speed: float = 120.0
@export var elephant_gust_nudge_speed: float = 18.0
@export var elephant_push_decel: float = 260.0

@export_group("Shell")
## The Shell's slow patrol, px/s (Fire_bending.md §7.2, Stage F12).
@export var shell_walk_speed: float = 25.0
## A small rock staggers it: it stops this long, seconds, knocked back this far, px.
@export var shell_stagger_time: float = 0.5
@export var shell_stagger_knockback: float = 4.0
## A small rock's knockback slides it at this speed, px/s. A wall within
## shell_crush_reach px (one tile) behind it when the rock hits: crushed instead.
## (The snake's head carries it a tile itself; a wall in the way crushes it there.)
@export var shell_shove_speed: float = 80.0
@export var shell_crush_reach: float = 8.0
## A gust nudges it at this speed, px/s (it's heavy), sliding out at shell_push_decel.
@export var shell_gust_nudge_speed: float = 14.0
@export var shell_push_decel: float = 200.0

@export_group("Fire look")
## Stage F13 (Fire_bending.md §9). HEAT GLOW: every fire throws a soft additive light
## on what's around it (HeatGlow). This scales all of them: 0 = no glows at all.
@export_range(0.0, 2.0) var heat_glow_strength: float = 1.0
## A fire's own glow (FlameMerge: braziers, bonfires, fireballs, the jet, burning
## enemies and vines): its brightness (alpha) and its reach, as a multiple of the
## flames' length beyond where they stand.
@export var heat_glow_alpha: float = 0.16
@export var heat_glow_reach: float = 1.4
## Burning grass and thicket light the room around them too: a wide faint glow per
## burning cell, this many px across (radius) and this bright.
@export var grass_room_glow_radius: float = 20.0
@export var grass_room_glow_alpha: float = 0.05
## The FIRE FRONT: a cell that just caught flashes along its open sides for this many
## seconds (on top of its new flames' flare), so the eye follows the spread.
@export var grass_front_flash_time: float = 0.12
## Thicket about to break into flame: over the last share of its glow phase its glow
## pulses faster and it spits sparks this often (per second), a warning.
@export var thicket_warning_share: float = 0.4
@export var thicket_warning_sparks_per_second: float = 6.0
## A bonfire's SMOKE COLUMN (SmokeColumn): a gust across it pushes it sideways this
## hard (px/s², eased out over smoke_column_gust_time seconds).
@export var smoke_column_gust_push: float = 140.0
@export var smoke_column_gust_time: float = 0.9
## A gust snuffing burning grass: the flames bend downwind and blow off over this
## many seconds, trailing smoke and a few sparks.
@export var snuff_blow_off_time: float = 0.15
@export var snuff_spark_count: int = 3
## The PARTICLE CAP (FireFxBudget): past fire_fx_soft_cap fire particles alive, fewer
## embers are made (down to fire_fx_min_share of them at fire_fx_hard_cap); past the
## hard cap, less smoke too.
@export var fire_fx_soft_cap: int = 300
@export var fire_fx_hard_cap: int = 600
@export_range(0.0, 1.0) var fire_fx_min_share: float = 0.25

@export_group("Dark rooms")
## DARK ROOMS (Room.is_dark, DarkRoomOverlay): how black the dark is (1 = pitch black).
@export_range(0.0, 1.0) var dark_room_darkness: float = 1.0
## The faint, small glow the player always carries in the dark: radius px, strength.
@export var dark_player_light_radius: float = 22.0
@export_range(0.0, 1.0) var dark_player_light_strength: float = 0.5
## A fire's light: this many times its heat glow's radius (a fireball's glimpse ahead).
@export var dark_fire_light_scale: float = 3.0
## Steady fires light a larger area: a brazier's and a bonfire's light, times this.
@export var dark_brazier_light_scale: float = 1.8
@export var dark_bonfire_light_scale: float = 1.6
## Burning grass and thicket: the light of one burning block of cells, radius px.
@export var dark_grass_light_radius: float = 30.0
## A light that goes out (a fireball bursting) fades over this many seconds.
@export var dark_light_fade_time: float = 0.5
## How many steps the light falls off in (pixel-art banding, dithered between steps).
@export_range(1, 16) var dark_light_steps: int = 5
