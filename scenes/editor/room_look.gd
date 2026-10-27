class_name RoomLook
extends RefCounted
## RoomLook: keeps a room's drawn ground in step with its tiles while it's being
## edited (Stage L8; plant layers and the FireGrid since Stage L9).
##
## Rooms with an "Earth" layer, or with `painted_ground` on (rooms the editor
## makes), don't show their tiles: Room._ready() adds a GroundPainter that draws
## all their ground as one picture (lumpy earth, turf, stone; Earth_bending.md,
## Stage E4b) and hides the tile layers. The painter works
## out its picture once, from the layers it finds in _ready(); in play only bending
## changes it, through the EarthLayer's signals. In the editor tiles change all the
## time (brush strokes, undo, a resized room), so after each change the editor
## calls refresh(): the old painter goes and a fresh one is built from the room as
## it is now. The first Earth stroke in a room makes its painter this way too.
##
## Plant layers (Stage L9): a grass layer grows blades on its top tiles, a thicket
## (and a cover that passes for one) grows leaves on its open faces, a cover grows
## roots. Each works them out once, in its _ready(), as child nodes. refresh()
## throws those children away and runs the layer's _ready() again, so new grass
## gets its blades at once. The children are never saved (their owner is null).
##
## The FireGrid (Stage L9): Room._ready() gives a room where fire is allowed a
## FireGrid if it has grass, thicket or covers. It belongs to play only (it owns
## the burning), so prepare_for_editing() takes it out of rooms being edited; the
## play-test copy and the saved level get theirs from Room._ready() as always.
##
## The WaterWorld (Stage W1) goes the same way; the water tiles show again.
##
## While a stroke is being painted the picture would lag behind the mouse, so
## show_tiles_while_painting() makes the painted layer's own tiles visible until
## refresh() hides them again.
##
## It calls Room's own _add_ground_painter() / _add_pebble_field(), the ones
## Room._ready() uses, so a room looks the same in the editor as in play.

const PAINTER_NAME: StringName = &"GroundPainter"
const PEBBLE_FIELD_NAME: StringName = &"PebbleField"
const FIRE_GRID_NAME: StringName = &"FireGrid"
## The WaterWorld (Stage W1): like the FireGrid, play only. While editing, the
## "Water" layer's own tiles show where the water is painted.
const WATER_WORLD_NAME: StringName = &"WaterWorld"
const WATER_LAYER_NAME: StringName = &"Water"
## The layer a room needs before it gets a painter (see Room._ready).
const EARTH_LAYER_NAME: StringName = &"Earth"


## A room that just entered the editor (opened, or imported as a copy): its
## FireGrid goes, and its painter and plants are rebuilt without it.
static func prepare_for_editing(room: Room) -> void:
	var water_world: Node = room.get_node_or_null(NodePath(WATER_WORLD_NAME))
	if water_world != null:
		room.remove_child(water_world)
		water_world.queue_free()
		var water_layer: TileMapLayer = room.get_node_or_null(NodePath(WATER_LAYER_NAME)) as TileMapLayer
		if water_layer != null:
			water_layer.self_modulate = Color.WHITE  # the WaterWorld had hidden it
	var fire_grid: Node = room.get_node_or_null(NodePath(FIRE_GRID_NAME))
	if fire_grid == null:
		return
	room.remove_child(fire_grid)
	fire_grid.queue_free()
	refresh(room)


## Rebuilds `room`'s ground picture if it has (or now needs) one, or takes the
## painter away if it no longer needs one (painted_ground switched off). Plant
## layers grow their blades and leaves again.
static func refresh(room: Room) -> void:
	for child: Node in room.get_children():
		if child is GrassLayer or child is ThicketLayer:
			_regrow_plants(child as TileMapLayer)
	var has_earth: bool = room.get_node_or_null(NodePath(EARTH_LAYER_NAME)) is EarthLayer
	var old_painter: Node = room.get_node_or_null(NodePath(PAINTER_NAME))
	if old_painter != null:
		# Out of the room now (its name is free for the new one), freed at frame end.
		room.remove_child(old_painter)
		old_painter.queue_free()
	if not has_earth and not room.painted_ground:
		# No painter: the tiles draw themselves again.
		for child: Node in room.get_children():
			if child is TileMapLayer:
				(child as TileMapLayer).self_modulate = Color.WHITE
		return
	room._add_ground_painter()
	if has_earth and room.get_node_or_null(NodePath(PEBBLE_FIELD_NAME)) == null:
		room._add_pebble_field()


## While painting `layer` in a room with a painter, its tiles show as they are.
static func show_tiles_while_painting(room: Room, layer: TileMapLayer) -> void:
	if room.get_node_or_null(NodePath(PAINTER_NAME)) != null:
		layer.self_modulate = Color.WHITE


## A grass, thicket or cover layer: drops the children its _ready() built (blades,
## gust sensors, leaves, roots: none of them saved) and the blade lists, then runs
## its _ready() again for the tiles it has now. Joining its groups again is harmless.
static func _regrow_plants(layer: TileMapLayer) -> void:
	for child: Node in layer.get_children():
		if child.owner == null:
			layer.remove_child(child)
			child.queue_free()
	var grass: GrassLayer = layer as GrassLayer
	if grass != null:
		grass.blade_bases = PackedVector2Array()
		grass.blade_heights = PackedFloat32Array()
		grass.blade_phases = PackedFloat32Array()
		grass.blade_bends = PackedFloat32Array()
		grass.blade_bend_speeds = PackedFloat32Array()
		grass.blade_winds = PackedVector2Array()
		grass.blade_cells = []
		grass.winds_found = false
		grass.fire_grid = null
		grass.fire_grid_looked_up = false
	layer._ready()
