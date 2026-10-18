class_name PlayerTuning
extends Resource
## Every number that affects how the player FEELS lives here (GAME_DESIGN.md §4).
##
## A Resource is a Godot data container that can be saved to a file (.tres).
## The player holds a reference to one of these (resources/player_tuning.tres).
## The player code reads these values fresh every physics frame (it never copies
## them at startup), so editing them while the game runs takes effect immediately:
## in the editor, open the Scene dock's "Remote" tab, select Player, and expand
## its `tuning` field in the Inspector.
## (Editing the .tres file itself while the game runs does NOT reach the running game,
## and Remote tab edits are lost when the game stops. To keep them, press F4 in game:
## the debug overlay writes the live values into player_tuning.tres.)

@export_group("Run")
## Top horizontal speed on the ground, px/s.
@export var max_run_speed: float = 90.0
## How fast we speed up toward max_run_speed while a direction is held, px/s².
## High value = snappy start.
@export var run_acceleration: float = 1000.0
## How fast we slow down on the ground when no direction is held, px/s². Gives a short slide.
@export var run_deceleration_ground: float = 400.0
## Multiplier on acceleration/deceleration while airborne (<1 = less air control).
@export var air_acceleration_multiplier: float = 0.65

@export_group("Gravity")
## Downward acceleration, px/s².
@export var gravity: float = 900.0
## Terminal falling speed, px/s.
@export var max_fall_speed: float = 300.0
## Terminal falling speed while holding Down (fast-fall), px/s.
@export var fast_fall_max_speed: float = 500.0

@export_group("Jump")
## Initial upward speed of a jump, px/s (negative = up in Godot's 2D coordinates).
@export var jump_velocity: float = -105.0
## While jump is HELD, upward speed is kept at the launch speed for up to this long
## instead of decaying under gravity. Releasing early cuts the hold short, which is
## what makes jump height variable: tap = ~7 px hop, full hold = ~30 px jump (incl. apex half-gravity).
@export var variable_jump_time: float = 0.2
## While |vertical speed| is below this (near the top of an arc) and jump is held,
## gravity is reduced, giving a floaty, controllable apex. px/s.
@export var apex_gravity_threshold: float = 40.0
## Gravity multiplier used near the apex (see apex_gravity_threshold).
@export var apex_gravity_multiplier: float = 0.5
## Can still jump this long after walking off a ledge, seconds.
@export var coyote_time: float = 0.1
## A jump pressed this long before it becomes possible (landing, touching a wall)
## still happens, seconds.
@export var jump_buffer_time: float = 0.1

@export_group("Wall")
## Max downward speed while sliding on a wall (holding toward it), px/s.
@export var wall_slide_max_speed: float = 40.0
## Horizontal push away from the wall on a wall jump, px/s.
@export var wall_jump_horizontal_speed: float = 130.0
## Upward speed of a wall jump, px/s. Held like a normal jump (variable_jump_time).
@export var wall_jump_vertical_speed: float = -105.0
## After a wall jump, horizontal input is ignored this long so the push away
## isn't instantly cancelled by still holding toward the wall, seconds.
@export var wall_jump_input_lock_time: float = 0.15
## A wall within this many pixels counts as "touching" for wall jumps and wall
## slides, so you don't need pixel-perfect contact (or to press into the wall).
@export var wall_jump_check_distance: float = 2.0

@export_group("Air Dash")
## Speed of the dash in the aimed direction, px/s. Gravity is ignored during it.
@export var dash_speed: float = 240.0
## How long the dash lasts, seconds. Distance = dash_speed * dash_duration (36 px).
@export var dash_duration: float = 0.15
## Dashes available per airtime. Refilled on the ground or by a wind crystal.
@export var max_dash_charges: int = 1
## When the dash ends, horizontal speed is multiplied by this (1 = keep it all; air
## control then eases it back to max_run_speed). Keeps the dash flowing into the arc.
@export var dash_end_horizontal_multiplier: float = 1.0
## When the dash ends, UPWARD speed is multiplied by this so an up-dash doesn't
## launch you sky-high but still rises a little before falling.
@export var dash_end_upward_multiplier: float = 0.6
## Freeze frames at dash start, seconds (0.05 ≈ 3 frames at 60 fps).
@export var dash_freeze_time: float = 0.05
## Screen shake at dash start: max offset in px, and how long it fades, seconds.
@export var dash_shake_strength: float = 2.0
@export var dash_shake_duration: float = 0.12
## Seconds between wind-trail streaks during a dash, and how long each one takes to fade.
@export var dash_trail_interval: float = 0.03
@export var dash_trail_lifetime: float = 0.25
## How much the player's rectangle stretches along the dash (x) and thins across it (y)
## while dashing, so the body reads as a gust of air rather than a solid block.
@export var dash_stretch: Vector2 = Vector2(1.6, 0.6)
## Opacity of the player during the dash (1 = solid). Partly "turns into air".
@export_range(0.0, 1.0) var dash_body_opacity: float = 0.55
## The dash leaves a WAKE: a small gust blown backward from where the dash starts
## (the air shoved to launch you). When on, it also pushes Pushable things behind you,
## like a gust. Off = a plain backward puff, no push.
@export var dash_wake_enabled: bool = true
## Length of the wake cone, px (the gust's is 40). Same opening angle as the gust.
@export var dash_wake_range: float = 24.0
## Push strength of the wake, px/s (the gust's is 160).
@export var dash_wake_push_strength: float = 120.0
## Defeating a stunned enemy by dashing into it gives the dash back (and the gust's
## down-boosts, like a wind crystal), so you can chain a kill into the next move.
@export var dash_defeat_refills: bool = true

@export_group("Air Dash: Ride the Current (experimental)")
## EXPERIMENT: the dash bursts out fast and eases off (same total distance), then
## for a short window afterwards you "ride" your own wind: lighter gravity and more
## air control. Turn on/off live in the Remote tab to compare with the rigid dash.
@export var ride_current_enabled: bool = true
## Dash speed multiplier at the START and END of the dash. The speed slides linearly
## between them; with an average of 1.0 the dash covers the same distance as normal.
@export var ride_current_dash_start_multiplier: float = 1.3
@export var ride_current_dash_end_multiplier: float = 0.7
## How long the "riding" window lasts after the dash ends, seconds.
@export var ride_current_time: float = 0.5
## Gravity multiplier during the riding window (<1 = floatier).
@export var ride_current_gravity_multiplier: float = 0.4
## Air acceleration multiplier during the riding window (>1 = more steering).
@export var ride_current_air_control_multiplier: float = 1.6

@export_group("Glide")
## Fall speed while gliding, px/s (GAME_DESIGN.md §5.2: 30).
@export var glide_max_fall_speed: float = 30.0
## How fast vertical speed blends toward the glide speed, px/s². High = the glide
## "catches" you almost at once; low = a softer, floatier catch.
@export var glide_vertical_acceleration: float = 900.0
## Seconds of gliding per airtime. Refills on the ground.
@export var glide_stamina_time: float = 1.5
## In an updraft, the zone's upward wind speed is multiplied by this while gliding.
## Example: updraft strength 60 x 2.0 = 120 px/s of lift, minus the 30 px/s glide fall
## = rising at 90 px/s.
@export var glide_updraft_lift_multiplier: float = 2.0
## Stamina drain multiplier inside an updraft (0 = riding an updraft is free, so
## updrafts work as "elevators" of any height; 1 = drains like normal gliding).
@export var glide_updraft_stamina_drain: float = 0.0
## Shared air stamina (experimental): when on, the dash costs glide stamina instead
## of using dash charges. Dash and glide then spend ONE "breath" bar; wind crystals
## and the ground refill it. Off = classic GAME_DESIGN.md §5.1 dash charges.
@export var dash_uses_stamina: bool = true
## Stamina one dash costs, in glide-seconds (0.9 of 1.5 = 60% of the bar, so only
## one dash fits in a full bar; a second needs a crystal or the ground).
@export var dash_stamina_cost: float = 0.9
## Seconds between the curved gust arcs drawn under the player while gliding.
@export var glide_gust_interval: float = 0.09
## Gliding keeps momentum: horizontal speed ABOVE max_run_speed (from a gust, dash or
## wind) only fades at this rate, px/s², instead of being pulled back by normal air
## control (~650 px/s²). Holding the opposite direction still brakes normally.
## 100 = a 200 px/s gust shove takes ~1.1 s to fade to run speed.
@export var glide_overspeed_deceleration: float = 100.0

@export_group("Gust")
## Length of the gust cone from the player's center, px (GAME_DESIGN.md §5.3: ~40;
## was 32, raised after play-testing enemies).
@export var gust_range: float = 40.0
## Half the cone's opening angle, degrees. 30 = a 60° wedge, 46 px wide at the far end.
@export var gust_cone_half_angle_degrees: float = 30.0
## Half-width of the cone right at the player, px, so things touching the body
## still get hit (a pure point would miss them).
@export var gust_cone_near_half_width: float = 3.0
## Seconds before the next gust is allowed.
@export var gust_cooldown: float = 0.6
## Speed the player is shoved the OPPOSITE way of the gust, px/s.
@export var gust_recoil_speed: float = 120.0
## Gusting while standing on the ground: the recoil is multiplied by this (0.5 = half),
## so you can shove an enemy off a platform without shoving yourself off too.
@export_range(0.0, 1.0) var gust_ground_recoil_multiplier: float = 0.5
## Extra friction on that ground recoil, px/s². It brakes the shove during the
## recoil's input lock (normally nothing slows you then). 1200 stops a 100 px/s
## shove in ~0.08 s, after ~4 px.
@export var gust_ground_recoil_friction: float = 1200.0
## Upward speed from a down-gust in mid-air ("extra jump"), px/s.
## It SETS the vertical speed (doesn't add to it), so it works even mid-fall.
## 120 under full gravity rises ~8 px; holding jump (apex half-gravity) gives a bit more.
@export var gust_down_boost_speed: float = 120.0
## How many down-gusts per airtime give the extra-jump lift (refilled on the ground).
## Gusts past this still blow and push things, they just don't lift you.
## 0 = unlimited (only cooldown and breath limit it).
@export var gust_down_boosts_per_airtime: int = 2
## NEUTRAL gust (no arrow held): a burst in ALL directions instead of a cone.
## Radius of the circle it pushes, px. Things are pushed straight away from you.
@export var gust_neutral_radius: float = 28.0
## A neutral gust is an AIR BRAKE: for this long, gravity is off and your speed
## (both axes) slows toward a stop. Seconds.
@export var gust_neutral_brake_time: float = 0.2
## How hard the air brake slows you, px/s². 1500 stops a 300 px/s fall in 0.2 s.
@export var gust_neutral_brake_deceleration: float = 1500.0
## After the brake (mid-air only), you FLOAT on the air cushion for this long:
## light gravity, a slow fall cap, and full steering. Seconds.
@export var gust_neutral_float_time: float = 0.4
## Gravity multiplier while floating (0.25 = a quarter of normal gravity).
@export var gust_neutral_float_gravity_multiplier: float = 0.25
## Fall speed cap while floating, px/s. At the end of the float you leave at about
## this speed, so normal gravity picks up from a gentle drift, not a standstill drop.
@export var gust_neutral_float_max_fall_speed: float = 25.0
## After a gust, horizontal input is ignored this long so the recoil isn't cancelled
## at once. (Aiming right means holding Right, which would steer you back right.)
@export var gust_recoil_input_lock_time: float = 0.12
## Push strength handed to Pushable objects, px/s. Each object decides what to do with it.
@export var gust_push_strength: float = 160.0
## Small screen shake on every gust (GAME_DESIGN.md §9).
@export var gust_shake_strength: float = 1.0
@export var gust_shake_duration: float = 0.08
## Debug hitbox (F3): how long the cone flash stays visible after a gust, seconds.
@export var gust_debug_flash_time: float = 0.25
## Gust costs breath: when on, a gust spends gust_stamina_cost of the shared
## glide/dash stamina bar. The bar refills on the ground, so ground gusts stay free;
## only airborne gusts compete with dash and glide. Off = gusts are free.
@export var gust_uses_stamina: bool = true
## Stamina one gust costs, in glide-seconds (0.3 of 1.5 = 20% of the bar).
@export var gust_stamina_cost: float = 0.3
## Diagonal grace, REAL seconds: after aiming a diagonal (e.g. Down+Right), releasing
## one of its two keys still counts as the diagonal for this long. Fixes diagonals
## turning sideways because one key came up a moment before the gust key.
## Hold the remaining key longer than this to really switch to it. 0 = off.
@export var gust_diagonal_grace_time: float = 0.12

@export_group("Gust: Hold to Aim (experimental)")
## EXPERIMENT: when on, pressing gust slows time and the arrows only AIM (you don't
## move); releasing gust fires. A quick tap fires almost at once, like the normal
## gust. Off = the gust fires the instant you press it. Toggle live to compare.
@export var gust_hold_to_aim: bool = true
## Game speed while aiming (0.25 = quarter speed).
@export_range(0.05, 1.0) var gust_aim_time_scale: float = 0.25
## The gust fires by itself after this many REAL seconds of aiming, so holding Z
## can't be used to hang in slow motion.
@export var gust_aim_max_real_time: float = 0.4

@export_group("Death & rooms")
## How long the death effect plays before the player reappears at the spawn, seconds.
## Short on purpose: dying should cost almost nothing (design pillar "fail fast").
@export var death_respawn_delay: float = 0.4
## How long the camera takes to slide to a new room, seconds. The player is frozen
## during the slide.
@export var room_transition_time: float = 0.3
## Upward speed given when entering a room ABOVE (like Celeste), px/s. Without it you
## would arrive at the very top of your jump and drop straight back into the old room.
@export var room_transition_up_boost: float = -160.0

@export_group("Assists")
## How many pixels we may nudge sideways to slip around a ceiling corner
## instead of bonking our head on it.
@export var corner_correction_pixels: int = 4
