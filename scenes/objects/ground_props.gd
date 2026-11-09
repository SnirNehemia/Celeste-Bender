class_name GroundProps
extends RefCounted
## GroundProps: the PROPS that stand on painted crumbling ground and go down with it
## (after the W8c play-test: "stuff like crates and braziers placed on the platform
## should not start the timer, and fall alongside the platform"). Static helpers, not
## a node.
##
## Which props: braziers (their node sits where the post meets the floor) and fire
## diamonds (they float; their FOOT is FIRE_DIAMOND_FOOT px below the middle). Crates
## don't need this: they have their own gravity. Leaf piles don't either: their
## leaves already land on whatever is under them; wake_leaf_piles() just tells them
## to look again.
##
## Who uses it:
##   - CrumblePatches.break_patches (crumbling rock and ice): find_on, then
##     GroundPropFall drops them with gravity until they land.
##   - FallingBlock (the basalt that falls as one solid piece): find_on, then the
##     block carries them down with it.
## A moved prop remembers where it was placed (remember_home), and the room's reset
## puts it back (restore_homes, called by the crumbling layers' reset()).

## A fire diamond floats: its foot is this far below its middle, px (its half height
## plus a little air).
const FIRE_DIAMOND_FOOT: float = 8.0
## A prop counts as standing on a cell when its foot is at most this far above the
## cell's top edge, px (or this far into it).
const STAND_REACH: float = 3.0
## The meta key a moved prop keeps its placed position under (global px).
const HOME_META: StringName = &"ground_prop_home"


## The props of `layer`'s room standing on any of `cells` (the layer's map coords).
static func find_on(layer: TileMapLayer, cells: Array) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	var tile_height: float = float(layer.tile_set.tile_size.y)
	for child: Node in layer.get_parent().get_children():
		var prop: Node2D = child as Node2D
		if not is_prop(prop):
			continue
		var foot: Vector2 = layer.to_local(get_foot(prop))
		# The cell just under the foot (a foot ON a top edge belongs to the cell below it).
		var cell: Vector2i = layer.local_to_map(foot + Vector2(0.0, STAND_REACH))
		var cell_top: float = cell.y * tile_height
		if cell_set.has(cell) and absf(foot.y - cell_top) <= STAND_REACH:
			found.append(prop)
	return found


## Is `node` a prop that goes down with its ground?
static func is_prop(node: Node2D) -> bool:
	return node is Brazier or node is FireDiamond


## Where `prop` touches the ground, global px.
static func get_foot(prop: Node2D) -> Vector2:
	if prop is FireDiamond:
		return prop.global_position + Vector2(0.0, FIRE_DIAMOND_FOOT)
	return prop.global_position


## Remembers where `prop` was placed, before it's first moved.
static func remember_home(prop: Node2D) -> void:
	if not prop.has_meta(HOME_META):
		prop.set_meta(HOME_META, prop.global_position)


## Room reset: every prop of `room` that moved goes back where it was placed.
static func restore_homes(room: Node) -> void:
	for child: Node in room.get_children():
		var prop: Node2D = child as Node2D
		if prop != null and prop.has_meta(HOME_META):
			prop.global_position = prop.get_meta(HOME_META)
			prop.remove_meta(HOME_META)


## The ground changed under `room`'s leaf piles: resting leaves check what's under them.
static func wake_leaf_piles(room: Node) -> void:
	for child: Node in room.get_children():
		if child is LeafPile:
			(child as LeafPile).ground_changed()
