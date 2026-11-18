class_name ShipTuning
extends Resource
## Every number that affects how the SKY SHIP feels (scenes/objects/sky_ship.gd).
## The ship twin of PlayerTuning / FireTuning: every ship holds the same one
## (resources/ship_tuning.tres, preloaded) and reads it fresh every frame, so edits in
## the F5 tuning panel ("Ship" tab) or the Remote tab take effect at once, and F4
## saves them with the others.
##
## The feel aimed for: a HEAVY vessel on LOW friction. Each gust adds a little speed
## (it never sets it), the speed fades slowly, and wind takes a while to get it going.
## All speeds are px/s, accelerations px/s². A tile is 8 px.

@export_group("Gusts aboard")
## Standing aboard and gusting: the share of the gust's push (PlayerTuning.
## gust_push_strength, 160) ADDED to the ship's sideways speed. The course sails fill.
## 160 x 0.35 = 56 px/s per gust.
@export var side_push_share: float = 0.35
## The same for an UP gust (the topsail fills): added to the rising speed.
@export var lift_push_share: float = 0.4
## The same for a DOWN gust (the topsail spills its air): added to the falling speed.
@export var descend_push_share: float = 0.3
## Gusting from the CROW'S NEST (up among the sails) pushes this many times as hard
## as from the deck: the nest is the helm, the deck is for walking about.
@export var nest_push_multiplier: float = 1.4
## A NEUTRAL gust (no arrow) blown from aboard brakes the ship by this much, px/s,
## both axes, toward standing still.
@export var neutral_brake: float = 60.0

@export_group("Gusts from outside")
## A gust that hits the ship from off it pushes it this share of what the same gust
## would do from aboard (you're only hitting part of the sails).
@export var outside_push_share: float = 0.6

@export_group("Limits")
## Top sideways speed. Gust after gust adds up to this.
@export var max_side_speed: float = 110.0
## Top rising speed and top falling speed.
@export var max_rise_speed: float = 90.0
@export var max_fall_speed: float = 90.0

@export_group("Drift")
## Sideways speed lost every second in the air: LOW, so it coasts a long way.
## 56 px/s coasts 56² / (2 x 12) ≈ 130 px (16 tiles).
@export var air_drag: float = 12.0
## Sideways speed lost every second while its keel rests on the ground (it drags).
@export var ground_friction: float = 140.0
## With nothing lifting it, it settles to sinking at this speed (gravity, gently).
@export var sink_speed: float = 10.0
## How fast its vertical speed eases toward that sink speed. A rise from an up gust
## dies off at this rate: 72 px/s takes about 1.4 s to stop, rising ~5 tiles.
@export var vertical_drag: float = 50.0

@export_group("Wind zones")
## Inside a wind zone, how fast its speed is pulled toward the wind's speed. Low: it's
## heavy, a current takes a while to get it going (and to slow it down).
@export var wind_acceleration: float = 60.0
## Share of a wind zone's speed the ship ends up at (1 = as fast as the wind).
@export var wind_speed_share: float = 0.8

@export_group("Jumping off")
## Leaving the ship (a jump, mostly), you keep its sideways speed: for this long, s,
## it counts like a tailwind (Player.start_floor_carry): let go of the arrows and you
## keep pace with the ship, hold one and you run on top of its speed, so you don't
## fall behind it. Godot already adds the ship's speed as you leave it; without this,
## air control braked it back to run speed at once.
@export var rider_carry_time: float = 0.6
## After that, the carried speed fades out at this rate, px/s².
@export var rider_carry_fade: float = 150.0

@export_group("Bumps")
## Hitting a wall, the ceiling, the ground or the room's edge faster than this, it
## bounces back with wall_bounce of its speed; slower, it just stops.
@export var bounce_min_speed: float = 25.0
@export var wall_bounce: float = 0.25
