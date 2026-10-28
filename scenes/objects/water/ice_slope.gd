class_name IceSlope
extends RefCounted
## IceSlope (Stage W6, Water_bending.md §7.2): the slope math shared by everything
## that slides down ice: the player's Sliding state, crates and ice blocks (Crate),
## and shells (Shell). Pure helpers; no nodes, never instanced.
##
## Slopes exist only as ice (frozen snakes and ribbons lying at an angle). A body
## on one is pulled down it by gravity's share along the slope, g x sin(angle).
## Everything here works on the floor NORMAL that move_and_slide() reports (the
## unit vector pointing out of the surface, up-ish for a floor):
##   - the slope's TANGENT, pointing to the right along the surface:
##     tangent = (-normal.y, normal.x). On flat ground (0, -1) that's (1, 0); on a
##     slope going down to the right it points right AND down.
##   - gravity along it: g x tangent.y (tangent.y is sin(angle), signed: positive
##     means "the right is downhill").
##
## move_and_slide() itself has two floor settings that fight sliding:
##   - floor_stop_on_slope (on by default): a body standing still on a slope
##     doesn't creep down it. A sliding body turns it off.
##   - floor_snap_length: how far down the floor pulls a body that was on it, so it
##     follows the surface going downhill. Sliding bodies use slide_snap_length (4 px).
##     Godot never snaps a body moving UP, so a ramp's lip still launches you.
##
## Two Godot details shape the code:
##   - After a move that ends on the floor (not moving up), move_and_slide() drops
##     the velocity's vertical part ("reset the gravity accumulation"). Going down a
##     slope the velocity is then (speed x cos(angle), 0): reading the speed along
##     the slope back with a dot product would lose a factor cos(angle) every frame.
##     So the speed along the slope is read back from the HORIZONTAL speed:
##     along = velocity.x / tangent.x, which is exact either way (get_speed_along).
##   - A box resting on the rounded END of a frozen snake touches it at one corner,
##     and the contact's normal is flat: it would stand on the peak. So for ice that
##     knows its own surface (get_slide_top_y: IceBlock, IcePiece) the slope is taken
##     from that surface around the body's x (get_surface_normal).

## The Water tuning (the same resource the player and the WaterWorlds use: Godot
## loads a .tres once, so the F5 panel reaches this too).
const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## A floor normal must point at least this much up to be a floor (45°, as the player).
const MIN_FLOOR_NORMAL_UP: float = 0.7
## The surface's slope is measured between this far left and right of the body, px.
const SURFACE_SAMPLE_DISTANCE: float = 3.0


## The slope's tangent for a floor `normal`, pointing right along the surface.
static func get_tangent(normal: Vector2) -> Vector2:
	return Vector2(-normal.y, normal.x)


## How steep a floor with this `normal` is, degrees (0 = flat).
static func get_angle_degrees(normal: Vector2) -> float:
	return rad_to_deg(normal.angle_to(Vector2.UP)) if normal != Vector2.ZERO else 0.0


## Is a floor with this `normal` steep enough to slide on (slide_min_angle)?
static func is_slide_steep(normal: Vector2) -> bool:
	return absf(get_angle_degrees(normal)) >= WATER_TUNING.slide_min_angle


## The ice floor `body` stands on, as its normal, or ZERO when it isn't on ice (or
## isn't on the floor). Looks through last frame's contacts for the one that faces
## up and belongs to IceBlock.ICE_GROUP.
static func get_ice_floor_normal(body: CharacterBody2D) -> Vector2:
	var collision: KinematicCollision2D = get_floor_contact(body)
	if collision == null:
		return Vector2.ZERO
	var collider: Node = collision.get_collider() as Node
	if collider == null or not collider.is_in_group(IceBlock.ICE_GROUP):
		return Vector2.ZERO
	return get_surface_normal(collider, body.global_position.x, collision.get_normal())


## The contact with the floor `body` stands on (its collider and normal), or null
## in the air. Usually one of last frame's slide collisions; but a body kept on the
## floor only by FLOOR SNAPPING (going down a slope) has none, so then a short test
## move down finds it.
static func get_floor_contact(body: CharacterBody2D) -> KinematicCollision2D:
	if not body.is_on_floor():
		return null
	for index: int in body.get_slide_collision_count():
		var collision: KinematicCollision2D = body.get_slide_collision(index)
		if collision.get_normal().dot(Vector2.UP) > MIN_FLOOR_NORMAL_UP:
			return collision
	var probe: KinematicCollision2D = KinematicCollision2D.new()
	if body.test_move(body.global_transform, Vector2(0.0, body.floor_snap_length + 1.0), probe) 			and probe.get_normal().dot(Vector2.UP) > MIN_FLOOR_NORMAL_UP:
		return probe
	return null


## The normal of `ice`'s top surface at global `x`, from its own outline (see the
## header), or `fallback` (the contact's normal) for ice that doesn't know its
## surface (painted tiles) or where it has none under both samples.
static func get_surface_normal(ice: Object, x: float, fallback: Vector2) -> Vector2:
	if not ice.has_method(&"get_slide_top_y"):
		return fallback
	var left_y: float = ice.call(&"get_slide_top_y", x - SURFACE_SAMPLE_DISTANCE)
	var right_y: float = ice.call(&"get_slide_top_y", x + SURFACE_SAMPLE_DISTANCE)
	if left_y == INF or right_y == INF:
		return fallback
	var along: Vector2 = Vector2(2.0 * SURFACE_SAMPLE_DISTANCE, right_y - left_y).normalized()
	var normal: Vector2 = Vector2(along.y, -along.x)  # the tangent turned a quarter, to point up
	# Steeper than a floor (a pillar's side): that's a wall, keep the contact's.
	return normal if normal.dot(Vector2.UP) > MIN_FLOOR_NORMAL_UP else fallback


## The speed along the slope `tangent` (signed, + = to the right) of a body moving
## at `velocity` on it: from the horizontal part (see the header).
static func get_speed_along(velocity: Vector2, tangent: Vector2) -> float:
	return velocity.x / tangent.x


## For crates, ice blocks and shells: if `body` stands on an ice slope steep enough,
## sets its velocity for this frame (along the slope: gravity pulls it down, it
## slows by slope_object_friction, `gravity` is its own) and the floor settings for
## sliding, and returns true; the caller then skips its usual ground movement.
## Otherwise puts the floor settings back and returns false.
static func slide_object(body: CharacterBody2D, gravity: float, delta: float) -> bool:
	var normal: Vector2 = get_ice_floor_normal(body)
	if normal == Vector2.ZERO or not is_slide_steep(normal):
		body.floor_stop_on_slope = true
		body.floor_snap_length = 1.0
		return false
	body.floor_stop_on_slope = false
	body.floor_snap_length = WATER_TUNING.slide_snap_length
	var tangent: Vector2 = get_tangent(normal)
	# The speed along the slope, from the horizontal speed (see the header).
	var along: float = get_speed_along(body.velocity, tangent)
	along += gravity * tangent.y * WATER_TUNING.slide_gravity_scale * delta
	along = move_toward(along, 0.0, WATER_TUNING.slope_object_friction * delta)
	along = clampf(along, -WATER_TUNING.slide_max_speed, WATER_TUNING.slide_max_speed)
	body.velocity = tangent * along
	return true
