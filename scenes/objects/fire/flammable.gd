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
##
## Fire sources only ever call the static helpers here, so new flammable things
## (leaf piles, vines, crates in later stages) need no change to the fireball or jet.

const GROUP: StringName = &"flammable"
const METHOD_IGNITE: StringName = &"ignite"
const METHOD_IS_BURNING: StringName = &"is_burning"
const METHOD_SNUFF: StringName = &"snuff"
const METHOD_FIRE_RECT: StringName = &"get_fire_rect"
## Bit value of physics layer 6, "flammable" (layer n = bit 1 << (n - 1)).
const LAYER_BIT: int = 32


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
		if target.has_method(METHOD_IGNITE) and get_fire_rect(target).grow(radius).has_point(world_point):
			target.call(METHOD_IGNITE, source)
			lit_count += 1
	return lit_count


## The catching area of a flammable node in world coordinates: its get_fire_rect()
## if it has one, else a zero-size rect at its position.
static func get_fire_rect(target: Node) -> Rect2:
	if target.has_method(METHOD_FIRE_RECT):
		return target.call(METHOD_FIRE_RECT)
	var node_2d: Node2D = target as Node2D
	return Rect2(node_2d.global_position, Vector2.ZERO) if node_2d != null else Rect2()


static func is_burning(target: Node) -> bool:
	return target.has_method(METHOD_IS_BURNING) and bool(target.call(METHOD_IS_BURNING))
