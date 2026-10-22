class_name Heat
extends RefCounted
## Hot updrafts (Fire_bending.md §5.3, §10): the "heat" contracts, written out like
## Flammable (flammable.gd): duck typing plus groups, since GDScript has no interfaces.
##
## HEAT SOURCES make hot air rise. To be one, a node:
##   1. joins the group "heat_sources" (Heat.SOURCE_GROUP)
##   2. has  func get_heat_lift_at(world_point: Vector2) -> float
##      the upward push at that point, px/s (0 = no heat there)
##   3. every physics frame, calls apply_heat(lift, delta) on each heat receiver it
##      holds (Heat.heat_receivers_in(...) helps)
## Today: a WindZone with `heat` on (a bonfire's column) and the FireGrid (each burning
## cell gives a short, weak updraft).
##
## HEAT RECEIVERS are the light things hot air lifts (§5.3: balloons, heat sails,
## windmills, leaflings, in later stages). To be one, a node:
##   1. joins the group "heat_receiver" (Heat.RECEIVER_GROUP)
##   2. has  func apply_heat(strength: float, delta: float) -> void
##      called once per physics frame per source it is inside; `strength` = px/s
##   3. optional: func get_heat_point() -> Vector2   where it feels heat (a balloon's
##      mouth); without it, its global_position counts
##
## The PLAYER is not a receiver: only a gliding player rises, so the glide asks
## Heat.get_lift_at() itself (GlideAbility.get_target_vertical_speed). Walking,
## jumping or jetting through hot air does nothing, and neither do crates, rocks or
## other enemies: they never ask.

const SOURCE_GROUP: StringName = &"heat_sources"
const RECEIVER_GROUP: StringName = &"heat_receiver"
const METHOD_LIFT_AT: StringName = &"get_heat_lift_at"
const METHOD_APPLY_HEAT: StringName = &"apply_heat"
const METHOD_HEAT_POINT: StringName = &"get_heat_point"


## The total hot-air lift at `world_point`, px/s: every source's, added up.
static func get_lift_at(tree: SceneTree, world_point: Vector2) -> float:
	var total_lift: float = 0.0
	for source: Node in tree.get_nodes_in_group(SOURCE_GROUP):
		total_lift += float(source.call(METHOD_LIFT_AT, world_point))
	return total_lift


## Where a receiver feels heat: its get_heat_point() if it has one, else its position.
static func get_receiver_point(receiver: Node) -> Vector2:
	if receiver.has_method(METHOD_HEAT_POINT):
		return receiver.call(METHOD_HEAT_POINT)
	var node_2d: Node2D = receiver as Node2D
	return node_2d.global_position if node_2d != null else Vector2.INF


## For a source: gives every receiver its share of `source`'s heat this frame.
static func heat_receivers(tree: SceneTree, source: Node, delta: float) -> void:
	for receiver: Node in tree.get_nodes_in_group(RECEIVER_GROUP):
		if not receiver.has_method(METHOD_APPLY_HEAT):
			continue
		var lift: float = float(source.call(METHOD_LIFT_AT, get_receiver_point(receiver)))
		if lift > 0.0:
			receiver.call(METHOD_APPLY_HEAT, lift, delta)
