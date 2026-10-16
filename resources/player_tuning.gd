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

@export_group("Assists")
## How many pixels we may nudge sideways to slip around a ceiling corner
## instead of bonking our head on it.
@export var corner_correction_pixels: int = 4
