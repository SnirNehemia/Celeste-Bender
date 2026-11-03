class_name Wettable
extends RefCounted
## The "Wettable" contract (Stage W8a, Water_bending.md §8.2): how any object says
## "water changes me". The water twin of Flammable (scenes/objects/fire/flammable.gd):
## duck typing plus a group, since GDScript has no interfaces.
##
## To be wettable, an object:
##   1. joins the group "wettable" (add_to_group(Wettable.GROUP) in _ready())
##   2. has these methods:
##        func wet() -> void        water landed on it (called again and again while
##                                  water keeps landing: cheap, effects only once)
##        func is_wet() -> bool
##   3. optional: func get_wet_rect() -> Rect2   the part water can reach, in world
##      coordinates. Without it, only global_position counts.
## No object is wettable yet (crates and the rest come with later stages). The room's
## TILES are wet through its SurfaceGrid, which wet_near() also asks.
##
## Water only ever calls the static helpers here.

const GROUP: StringName = &"wettable"
const METHOD_WET: StringName = &"wet"
const METHOD_IS_WET: StringName = &"is_wet"
const METHOD_WET_RECT: StringName = &"get_wet_rect"


## Water at `world_point`, reaching `radius` px: wets the room's tiles there (its
## SurfaceGrid) and every wettable object it touches. Returns how many tiles and
## objects turned wet.
static func wet_near(tree: SceneTree, world_point: Vector2, radius: float) -> int:
	var count: int = 0
	var grid: SurfaceGrid = SurfaceGrid.find_at(tree, world_point)
	if grid != null:
		count += grid.wet_at(world_point, radius)
	return count + wet_objects_near(tree, world_point, radius)


## Only the wettable OBJECTS near the point (not tiles). Cheap when there are none:
## the WaterWorld calls it wherever a drop hits something.
static func wet_objects_near(tree: SceneTree, world_point: Vector2, radius: float) -> int:
	if not tree.has_group(GROUP):
		return 0
	var count: int = 0
	for target: Node in tree.get_nodes_in_group(GROUP):
		if not target.has_method(METHOD_WET) or not get_wet_rect(target).grow(radius).has_point(world_point):
			continue
		var was_wet: bool = target.has_method(METHOD_IS_WET) and bool(target.call(METHOD_IS_WET))
		target.call(METHOD_WET)
		if not was_wet:
			count += 1
	return count


## The part of `target` water can reach, world coordinates: its get_wet_rect() if it
## has one, else a zero-size rect at its position.
static func get_wet_rect(target: Node) -> Rect2:
	if target.has_method(METHOD_WET_RECT):
		return target.call(METHOD_WET_RECT)
	var node_2d: Node2D = target as Node2D
	return Rect2(node_2d.global_position, Vector2.ZERO) if node_2d != null else Rect2()
