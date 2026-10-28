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
## Hidden chambers (HiddenLayer): while editing they're OPEN (open_for_editing), so
## the painter draws the tunnel and nothing inside is hidden; their own tiles never
## show (EditorOverlay stripes them purple instead). get_exposed_chamber_edges()
## finds where a chamber touches open air, for the overlay's red edges.
##
## Walls (WallLayer): painted as terrain, built into wall nodes by the layer; refresh()
## builds them again. A level saved before walls were terrain has wall OBJECTS:
## prepare_for_editing() turns each into tiles of its layer (saved with the level).
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
const HIDDEN_LAYER_NAME: StringName = &"Hidden"
## The four ways out of a cell (the chamber edges' directions).
const NEIGHBOUR_STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## A room that just entered the editor (opened, or imported as a copy): its
## FireGrid goes, and its painter and plants are rebuilt without it.
static func prepare_for_editing(room: Room) -> void:
	_convert_wall_objects(room)
	_open_hidden_chambers(room)
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
		elif child is WallLayer:
			(child as WallLayer).build_walls()
	# Before the painter is built: it reads which chamber cells are covered.
	_open_hidden_chambers(room)
	var has_earth: bool = room.get_node_or_null(NodePath(EARTH_LAYER_NAME)) is EarthLayer
	var old_painter: Node = room.get_node_or_null(NodePath(PAINTER_NAME))
	if old_painter != null:
		# Out of the room now (its name is free for the new one), freed at frame end.
		room.remove_child(old_painter)
		old_painter.queue_free()
	if not has_earth and not room.painted_ground:
		# No painter: the tiles draw themselves again (a chamber's never: it's air).
		for child: Node in room.get_children():
			if child is TileMapLayer and not child is HiddenLayer and not child is WallLayer:
				(child as TileMapLayer).self_modulate = Color.WHITE
		return
	room._add_ground_painter()
	if has_earth and room.get_node_or_null(NodePath(PEBBLE_FIELD_NAME)) == null:
		room._add_pebble_field()


## While painting `layer` in a room with a painter, its tiles show as they are.
## Not a hidden chamber: its tiles are earth tiles, and the overlay's stripes
## already show the stroke as it goes.
## A wall layer's tiles show even without a painter: its walls are built after the stroke.
static func show_tiles_while_painting(room: Room, layer: TileMapLayer) -> void:
	var has_painter: bool = room.get_node_or_null(NodePath(PAINTER_NAME)) != null
	if (has_painter or layer is WallLayer) and not layer is HiddenLayer:
		layer.self_modulate = Color.WHITE


## Wall objects (a CrackedWall or StoneWall placed straight in the room, from before
## walls were terrain, or in an imported room) become tiles of the room's wall layer.
static func _convert_wall_objects(room: Room) -> void:
	for child: Node in room.get_children():
		var entry_id: StringName = &""
		if child is CrackedWall:
			entry_id = &"cracked_wall"
		elif child is StoneWall:
			entry_id = &"stone_wall"
		else:
			continue
		var entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(entry_id)
		var layer: TileMapLayer = room.get_node_or_null(NodePath(entry.layer_name)) as TileMapLayer
		if layer == null:
			layer = TileMapLayer.new()
			layer.name = entry.layer_name
			layer.set_script(entry.layer_script)
			layer.tile_set = entry.tile_set
			room.add_child(layer)
			room.move_child(layer, 0)
			layer.owner = room.owner if room.owner != null else room
		var wall: Node2D = child as Node2D
		var corner: Vector2i = Vector2i((wall.position / PaletteCatalog.TILE).round())
		var cells: Array[Vector2i] = wall.call(&"get_cells")
		for cell: Vector2i in cells:
			layer.set_cell(corner + cell, TileBrush.SOURCE_ID, entry.tile_plain)
			# One terrain per cell: the wall replaces what was painted under it.
			for carved_name: StringName in entry.carves_layers:
				var carved: TileMapLayer = room.get_node_or_null(NodePath(carved_name)) as TileMapLayer
				if carved != null:
					carved.erase_cell(corner + cell)
		room.remove_child(wall)
		wall.queue_free()
		(layer as WallLayer).build_walls()


## The room's hidden chambers, opened for editing (see the header), their tiles unseen.
static func _open_hidden_chambers(room: Room) -> void:
	var hidden_layer: HiddenLayer = room.get_node_or_null(NodePath(HIDDEN_LAYER_NAME)) as HiddenLayer
	if hidden_layer != null:
		hidden_layer.open_for_editing()
		hidden_layer.self_modulate = Color.TRANSPARENT


## Where `room`'s hidden chambers touch open air: [cell, step] pairs (room-local
## cells; step = which way the air is). Open air: inside the room, not a chamber
## cell, and no solid tile (a layer with collision) there. Outside the room counts
## as closed: an exit through the room's edge is the next room's business.
static func get_exposed_chamber_edges(room: Room) -> Array[Array]:
	var edges: Array[Array] = []
	var hidden_layer: TileMapLayer = room.get_node_or_null(NodePath(HIDDEN_LAYER_NAME)) as TileMapLayer
	if hidden_layer == null:
		return edges
	var chamber_cells: Array[Vector2i] = hidden_layer.get_used_cells()
	if chamber_cells.is_empty():
		return edges
	var solid_layers: Array[TileMapLayer] = []
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		# Same test as MapView's openings: a layer that collides is solid. A wall
		# layer doesn't (its wall nodes do), but its cells are solid until broken.
		if layer != null and (layer is WallLayer or (layer.collision_enabled and layer.tile_set != null \
				and layer.tile_set.get_physics_layers_count() > 0)):
			solid_layers.append(layer)
	var room_cells: Rect2i = Rect2i(Vector2i.ZERO, Vector2i((room.room_size / LevelEditor.TILE).ceil()))
	for cell: Vector2i in chamber_cells:
		for step: Vector2i in NEIGHBOUR_STEPS:
			var neighbour: Vector2i = cell + step
			if not room_cells.has_point(neighbour) or hidden_layer.get_cell_source_id(neighbour) != -1:
				continue
			var is_solid: bool = false
			for layer: TileMapLayer in solid_layers:
				if layer.get_cell_source_id(neighbour) != -1:
					is_solid = true
					break
			if not is_solid:
				edges.append([cell, step])
	return edges


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
