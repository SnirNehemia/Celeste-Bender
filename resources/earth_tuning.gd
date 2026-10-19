class_name EarthTuning
extends Resource
## Every number that affects how EARTH bending feels lives here (Earth_bending.md).
## The Earth twin of PlayerTuning: the player holds one (resources/earth_tuning.tres)
## in its `earth_tuning` field, and the earth code reads it fresh every frame, so
## Remote-tab edits while the game runs take effect at once.
##
## Earth_bending.md §4 asks for the aim timers to run in REAL time (not slowed by the
## bend's slow motion), so aiming feels the same every time. Values marked
## "real seconds" / "real px/s" follow that rule.

@export_group("Earth tiles")
## How long a tile takes to darken from fresh to used, seconds.
## Fading (instead of snapping) lets the eye follow where the earth was spent.
@export var used_fade_time: float = 0.2
## How long a tile shivers when the shadow passes through it, real seconds.
@export var shiver_time: float = 0.25
## Shiver flicker: the tile's colors are multiplied by this on the bright beats.
@export var shiver_brightness: float = 1.25
## How often the shiver flips between bright and normal, real seconds. Smaller = buzzier.
@export var shiver_flip_interval: float = 0.04

@export_group("Bend: slow motion & shadow")
## World speed while bending (aiming). 0.3 = enemies, orbs and objects at 30% speed.
@export var bend_time_scale: float = 0.3
## The shadow waits under the feet this long before crawling, real seconds.
## Releasing before then is a "quick tap": the move fires right under the player.
@export var shadow_start_delay: float = 0.5
## Shadow crawl speed along the earth surface, real px/s.
@export var shadow_speed: float = 60.0
## The aim phase ends by itself after this long and the move fires, real seconds.
## Stops slow motion from being used to hang around.
@export var bend_max_time: float = 2.5
## Body scale while in the bending stance (x = width, y = height): a slight crouch.
@export var bend_squash: Vector2 = Vector2(1.25, 0.8)

@export_group("Gravel")
## Bits popped off at the feet when a bend starts.
@export var feet_gravel_count: int = 5
## Bits dropped behind the shadow on each tile it enters.
@export var path_gravel_count: int = 2
## The shadow sheds a bit or two this often while it is moving, real seconds.
@export var shadow_gravel_interval: float = 0.12
## Bits in the burst where a bend erupts.
@export var eruption_gravel_count: int = 12
## Screen shake when a bend erupts: strength (px) and duration (s).
@export var eruption_shake_strength: float = 1.5
@export var eruption_shake_time: float = 0.12

@export_group("Earth Column")
## Column size, px: width across the surface, length out of it (1 x 3 tiles).
## Under a low ceiling the column only grows as far as the open space allows.
@export var column_width: float = 8.0
@export var column_length: float = 24.0
## How long the column takes to rise to full length, seconds (game time).
@export var column_rise_time: float = 0.1
## The RISING tip throws what it hits at this speed, px/s: crates and enemies in any
## direction, the player when the column comes out of a wall or a ceiling.
## Once risen, the column is a plain platform and throws nothing.
@export var column_launch_speed: float = 220.0
## A column rising under the PLAYER throws them up at this speed instead: the super
## jump. 320 px/s climbs about 2x a full regular jump (320² / (2 × 900) ≈ 57 px,
## against ~28 px).
@export var column_super_jump_speed: float = 320.0
## A sideways launch also throws the player UP at this speed, px/s (like Celeste's
## side springs): without it you'd skim the floor and land after a few px.
@export var column_side_launch_lift: float = 140.0
## After a sideways launch, the arrows don't steer for this long, seconds. Without
## it, normal air control would eat the 220 px/s within about 0.2 s.
@export var launch_steer_lock_time: float = 0.15
## After the lock, speed above max run speed fades at this gentle rate, px/s²,
## unless you steer against it. Keeps the throw feeling like a throw.
@export var launch_overspeed_deceleration: float = 300.0
## Gravel bits where the rising tip hits something.
@export var column_hit_gravel_count: int = 6
