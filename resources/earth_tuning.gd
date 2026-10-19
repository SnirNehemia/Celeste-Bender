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
