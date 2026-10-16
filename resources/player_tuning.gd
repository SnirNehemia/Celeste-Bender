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
## (Editing the .tres file itself while the game runs does NOT reach the running game;
## use the Remote tab, then copy the values you like back into the .tres.)

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
## Seconds between the curved gust arcs drawn under the player while gliding.
@export var glide_gust_interval: float = 0.09

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
