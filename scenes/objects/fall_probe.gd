class_name FallProbe
extends RefCounted
## FallProbe: "how far down is the floor from here?" for small things that fall
## without a physics body of their own:
## props whose ground went away (GroundPropFall). Not a node: one static function.
##
## It casts a ray straight down on physics layer 1 ("world"). Floors are tiles and
## static or moving solids (doors, platforms, a falling block); characters (you,
## crates, enemies: CharacterBody2D) are skipped, so a pebble never lands on your head.
##
## Godot concept, direct space state: the physics world can be asked questions at
## any time during _physics_process (a ray, a point, a shape), without making a node.

## A ray skips at most this many characters before it gives up.
const MAX_SKIPS: int = 4


## The distance from the global point `from` down to the first floor, at most
## `max_distance` px; -1 if there's none that close.
static func find_floor(canvas: CanvasItem, from: Vector2, max_distance: float) -> float:
	var space: PhysicsDirectSpaceState2D = canvas.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, max_distance), 1)
	query.hit_from_inside = false
	var skipped: Array[RID] = []
	for attempt: int in MAX_SKIPS + 1:
		query.exclude = skipped
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return -1.0
		if hit["collider"] is CharacterBody2D:
			skipped.append(hit["rid"])
			continue
		return (hit["position"] as Vector2).y - from.y
	return -1.0
