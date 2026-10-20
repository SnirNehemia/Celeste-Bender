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
## The pillar's FOOT: when a column rises, the earth under its base hardens in a
## pyramid this many rows deep (1, 3, 5... tiles wide), into the ground or wall it
## rose from. Hardened earth can't be torn out by rocks, so a pillar can't be dug
## loose and left floating. (It can still be bent: columns, snake.)
@export var column_foot_rows: int = 3

@export_group("Boulder (rock)")
## Rock size, px: one tile (Stage E4a). It's torn out of one earth tile, which
## becomes open air until the room resets.
@export var boulder_size: float = 8.0
## Tear phase: the rock rumbles and slowly works its way out of its hole (one tile
## along the surface's normal) over this long, seconds (game time).
@export var boulder_tear_time: float = 0.15
## Rumble while tearing: the rock jitters up to this far sideways, px (drawn only).
@export var boulder_tear_rumble: float = 0.75
## Then it HOPS: up this high above where it came out, px. 22 px puts the rock's
## bottom well above the player's head (11 px tall), so it arcs over in front of you.
@export var boulder_hop_height: float = 22.0
## ...and drifts AWAY from the player at this speed, px/s, while hopping.
@export var boulder_hop_away_speed: float = 30.0
## A rock torn out of the WALL you slide on hops away from the wall this fast, px/s,
## so it clears the wall instead of rising along it.
@export var boulder_wall_hop_away_speed: float = 90.0
## World speed from the tear until the throw (slow motion, like a bend). The rock moves
## in game time, so the perfect window lasts 1 / this longer in real time.
@export var boulder_time_scale: float = 0.5
## ...but the slow motion ends after this many REAL seconds, throw or not.
@export var boulder_slow_motion_max_time: float = 2.0
## Perfect throw window: within this many seconds (game time) of the moment the
## rock's middle comes back DOWN level with the player's middle.
@export var boulder_perfect_window: float = 0.08
## An un-thrown rock that lands thuds and rests this long (still throwable) before it
## crumbles. A floor rock lands almost exactly at the player's middle height, so
## without the rest the perfect window would be cut off by the landing.
@export var boulder_land_rest_time: float = 0.2
## Outside the window, the throw quality drops linearly to 0 over this many more
## seconds. Quality 0 = boulder_min_throw_speed with normal gravity (a throw at the
## top of the hop, ~0.2 s before the window, is already the weakest).
@export var boulder_throw_falloff_time: float = 0.12
## Throw speed for a perfect throw / the worst throw, px/s. Off-peak throws are
## in between, by quality.
@export var boulder_perfect_throw_speed: float = 320.0
@export var boulder_min_throw_speed: float = 180.0
## A perfect throw ignores gravity for this long, seconds; off-peak throws for
## (this x quality), so a late throw droops right away.
@export var boulder_perfect_float_time: float = 0.3
## Rock gravity and max fall speed (the hop, and after a throw's float time).
@export var boulder_gravity: float = 900.0
@export var boulder_max_fall_speed: float = 300.0
## The player stays rooted holding the boulder at most this long (game time). No throw
## by then = the boulder drops and shatters.
@export var boulder_hold_time: float = 1.0
## A boulder hitting a risen column bounces off it at least this fast along the
## column's face, px/s (the column's spring speed, Earth_bending.md §5).
@export var boulder_column_bounce_speed: float = 220.0
## Gravel bits when it shatters / when it sticks into earth.
@export var boulder_shatter_gravel_count: int = 10
@export var boulder_stick_gravel_count: int = 6
## Screen shake when it sticks or shatters: strength (px) and duration (s).
@export var boulder_impact_shake_strength: float = 1.0
@export var boulder_impact_shake_time: float = 0.1
## A flying boulder that never hits anything (thrown out of the room) shatters after
## this long, seconds.
@export var boulder_max_flight_time: float = 3.0

@export_group("Big rock (hold S)")
## Holding S until the rock is out of its hole (boulder_tear_time) grows it into a big
## rock this size, px (Stage E4c2): 2x2 tiles, torn out of a 2x2 block.
@export var big_rock_size: float = 16.0
## A big rock is heavier: its throw speed (perfect or not) is multiplied by this.
@export var big_rock_throw_speed_scale: float = 0.85
## Gravel bits and screen shake (strength px, duration s) when it grows.
@export var big_rock_grow_gravel_count: int = 14
@export var big_rock_grow_shake_strength: float = 1.5
@export var big_rock_grow_shake_time: float = 0.15

@export_group("Hidden chambers")
## When a dug hole reaches a hidden chamber (Stage E4c), its cover crumbles away:
## each cell fades out over this many REAL seconds...
@export var hidden_crumble_time: float = 0.25
## ...starting this much later per cell step away from the breach, so the crumble
## spreads along the tunnel instead of vanishing all at once.
@export var hidden_crumble_step_delay: float = 0.03
## Gravel bits each crumbling cell drops.
@export var hidden_crumble_gravel_count: int = 3
## Screen shake when a chamber opens: strength (px) and duration (s).
@export var hidden_crumble_shake_strength: float = 1.5
@export var hidden_crumble_shake_time: float = 0.2
