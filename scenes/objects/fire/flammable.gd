class_name Flammable
extends RefCounted
## The "Flammable" contract (Fire_bending.md §10): how any object says "fire can
## light me". The fire twin of Pushable (scenes/objects/pushable.gd): duck typing
## plus a group, since GDScript has no interfaces.
##
## To be flammable, an object:
##   1. joins the group "flammable" (add_to_group(Flammable.GROUP) in _ready())
##   2. has these methods:
##        func ignite(source: Node) -> void   catch fire (`source`: what lit it, e.g. a
##                                            Fireball or the player's FlameJetAbility)
##        func is_burning() -> bool
##        func snuff() -> void                a gust blew on it (Stage F10). Objects the
##                                            wind can't put out just ignore it.
##      ignite() is called again and again while a flame keeps touching (the jet plume
##      does it every frame), so it must be cheap and play its "lit" effects only the
##      first time.
##   3. optional: func get_fire_rect() -> Rect2   the part that can catch, in world
##      coordinates. ignite_near() uses it; without it, only global_position counts.
##   4. for fireballs to HIT it (not only splash it): an Area2D (the object itself or a
##      child) on physics layer 6, "flammable" (LAYER_BIT below).
##   5. optional (Stage F5): func ignite_at(world_point: Vector2, radius: float,
##      source: Node) -> bool   for things made of many parts that burn separately
##      (the FireGrid's grass cells): light the parts near the point, return true if
##      any caught. When present, the helpers below use it instead of the fire rect.
##   6. optional (F7 play-test, ahead of Stage F10): func snuff_in(world_polygon:
##      PackedVector2Array, direction: Vector2) -> int   a GUST blew over this area
##      (its cone, or the circle of an all-around gust; direction ZERO for that one):
##      put out the parts burning in it, return how many. The FireGrid does (burning
##      grass turns to ash at once, burning thicket crumbles). snuff_in_area() below
##      calls it; GustAbility calls that with its cone.
##
## Fire sources only ever call the static helpers here, so new flammable things
## (leaf piles, vines, crates in later stages) need no change to the fireball or jet.

const GROUP: StringName = &"flammable"
const METHOD_IGNITE: StringName = &"ignite"
const METHOD_IS_BURNING: StringName = &"is_burning"
const METHOD_SNUFF: StringName = &"snuff"
const METHOD_FIRE_RECT: StringName = &"get_fire_rect"
const METHOD_IGNITE_AT: StringName = &"ignite_at"
const METHOD_SNUFF_IN: StringName = &"snuff_in"
## Bit value of physics layer 6, "flammable" (layer n = bit 1 << (n - 1)).
const LAYER_BIT: int = 32
## ignite_in_rect() lights a FireGrid at points this many px apart along a flame's edge.
const IN_RECT_STEP: float = 4.0


## The flammable node for something a flame touched, or null. Checks the node, then
## its parent (a flammable's catch area is often a child Area2D).
static func find_flammable(touched: Node) -> Node:
	for candidate: Node in [touched, touched.get_parent()]:
		if candidate != null and candidate.is_in_group(GROUP) and candidate.has_method(METHOD_IGNITE):
			return candidate
	return null


## Lights `touched` if it is flammable. Returns true if it was.
static func try_ignite(touched: Node, source: Node) -> bool:
	var target: Node = find_flammable(touched)
	if target == null:
		return false
	target.call(METHOD_IGNITE, source)
	return true


## Lights every flammable within `radius` px of `world_point` (its fire rect grown by
## the radius contains the point). Returns how many were lit. Used for a fireball's
## splash and for the jet plume, which is sampled as a few points along its length.
static func ignite_near(tree: SceneTree, world_point: Vector2, radius: float, source: Node) -> int:
	var lit_count: int = 0
	for target: Node in tree.get_nodes_in_group(GROUP):
		if ignite_if_near(target, world_point, radius, source):
			lit_count += 1
	return lit_count


## Lights `target` if a flame at `world_point` reaching `radius` px touches it: its
## ignite_at() if it has one (the FireGrid), else its fire rect grown by the radius.
## Returns true if anything caught.
static func ignite_if_near(target: Node, world_point: Vector2, radius: float, source: Node) -> bool:
	if target.has_method(METHOD_IGNITE_AT):
		return bool(target.call(METHOD_IGNITE_AT, world_point, radius, source))
	if target.has_method(METHOD_IGNITE) and get_fire_rect(target).grow(radius).has_point(world_point):
		target.call(METHOD_IGNITE, source)
		return true
	return false


## Lights every flammable touching `world_rect` (a flame's area), except `skip`.
## Things with a fire rect catch if it overlaps; things that burn in parts (the
## FireGrid) are lit along the rectangle's bottom and sides every IN_RECT_STEP px,
## reaching `grid_reach` px: that's where a flame standing on the ground meets grass.
## Used by fires that stand still and light what they touch (a bonfire, a burning
## leaf pile). Returns how many caught.
static func ignite_in_rect(tree: SceneTree, world_rect: Rect2, source: Node, skip: Node = null,
		grid_reach: float = 2.0) -> int:
	var lit_count: int = 0
	for target: Node in tree.get_nodes_in_group(GROUP):
		if target == skip:
			continue
		if target.has_method(METHOD_IGNITE_AT):
			var any_caught: bool = false
			for point: Vector2 in _get_rect_edge_points(world_rect):
				if bool(target.call(METHOD_IGNITE_AT, point, grid_reach, source)):
					any_caught = true
			if any_caught:
				lit_count += 1
		elif target.has_method(METHOD_IGNITE) and get_fire_rect(target).intersects(world_rect, true):
			target.call(METHOD_IGNITE, source)
			lit_count += 1
	return lit_count


## Points along a rectangle's bottom edge and both sides, IN_RECT_STEP px apart.
static func _get_rect_edge_points(rect: Rect2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var x: float = rect.position.x
	while x <= rect.end.x:
		points.append(Vector2(x, rect.end.y))
		x += IN_RECT_STEP
	var y: float = rect.position.y
	while y < rect.end.y:
		points.append(Vector2(rect.position.x, y))
		points.append(Vector2(rect.end.x, y))
		y += IN_RECT_STEP
	return points


## The catching area of a flammable node in world coordinates: its get_fire_rect()
## if it has one, else a zero-size rect at its position.
static func get_fire_rect(target: Node) -> Rect2:
	if target.has_method(METHOD_FIRE_RECT):
		return target.call(METHOD_FIRE_RECT)
	var node_2d: Node2D = target as Node2D
	return Rect2(node_2d.global_position, Vector2.ZERO) if node_2d != null else Rect2()


## A gust blew over `world_polygon` (direction ZERO = all around): every flammable
## with snuff_in() puts out what burns in it. Returns how many parts went out.
static func snuff_in_area(tree: SceneTree, world_polygon: PackedVector2Array, direction: Vector2) -> int:
	var snuffed_count: int = 0
	for target: Node in tree.get_nodes_in_group(GROUP):
		if target.has_method(METHOD_SNUFF_IN):
			snuffed_count += int(target.call(METHOD_SNUFF_IN, world_polygon, direction))
	return snuffed_count


static func is_burning(target: Node) -> bool:
	return target.has_method(METHOD_IS_BURNING) and bool(target.call(METHOD_IS_BURNING))
