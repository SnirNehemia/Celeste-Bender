class_name Ricochet
extends RefCounted
## Ricochet (Stage F12): the shared "where would this projectile hit, and which way
## does the surface face?" helper for things that move themselves and BOUNCE: the
## fireball (off bare walls, floors and the Shell) and the sentry orb (off walls,
## floors and the Shell). Both are Area2Ds moved by script, and an Area2D only says
## "I'm overlapping X", never where or at what angle. This asks the physics server.
##
## How: cast_motion() sweeps the projectile's shape along its move and says how far it
## gets before touching something (the safe fraction) and where it first overlaps (the
## unsafe fraction). get_rest_info() at the unsafe spot then gives the surface normal
## (pointing back at the projectile) and what was hit. Vector2.bounce(normal) mirrors
## the velocity off that surface: the angle in equals the angle out.
##
## Godot concepts:
##   - PhysicsDirectSpaceState2D: the physics world's query API (rays, points, shapes),
##     usable any time in _physics_process.
##   - PhysicsShapeQueryParameters2D: "this shape, at this transform, moving by this
##     motion, against these layers".
##   - RID: the physics server's handle for a body; `exclude` takes RIDs.


## The first contact of `shape` moving from `from` by `motion` against bodies on
## `mask`, or an empty Dictionary if it moves freely. Keys:
##   safe_position  where it can go without touching (Vector2)
##   normal         the surface's facing, pointing back at the projectile (Vector2)
##   point          where it touches, world (Vector2)
##   collider       what it touched (Object, may be null if already freed)
## Already overlapping at `from`: the normal is straight back along the motion.
static func find_contact(space: PhysicsDirectSpaceState2D, shape: Shape2D, from: Vector2,
		motion: Vector2, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, from)
	query.motion = motion
	query.collision_mask = mask
	query.exclude = exclude
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() < 2 or fractions[1] >= 1.0:
		return {}
	# Look where it first overlaps: what is it, and which way does that surface face?
	query.transform = Transform2D(0.0, from + motion * fractions[1])
	query.motion = Vector2.ZERO
	var info: Dictionary = space.get_rest_info(query)
	if info.is_empty():
		return {}
	var normal: Vector2 = info["normal"]
	if normal == Vector2.ZERO or fractions[1] <= 0.0:
		normal = -motion.normalized()
	return {
		"safe_position": from + motion * fractions[0],
		"normal": normal,
		"point": info["point"],
		"collider": instance_from_id(info["collider_id"]),
	}


## `velocity` mirrored off a surface facing `normal`, keeping `keep` of its speed.
static func bounce(velocity: Vector2, normal: Vector2, keep: float = 1.0) -> Vector2:
	return velocity.bounce(normal.normalized()) * keep
