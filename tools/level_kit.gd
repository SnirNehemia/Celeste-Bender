class_name LevelKit
extends RefCounted
## LevelKit: builds or edits an EDITOR level (a file in res://levels/) from code,
## the way tools/build_rooms.gd builds chapter rooms. Used by the tools that write
## whole levels (tools/build_basics_level.gd, tools/build_element_levels.gd).
##
## It does what the level editor does, through the same pieces, so the files it
## writes open in the editor like any hand-made level:
##   - rooms come from LevelTemplate.build_empty_room (painted_ground on)
##   - terrain is painted through the PaletteCatalog's terrain entries (layer name,
##     tileset, script, tiles), one terrain per cell like the editor's brush
##   - objects are instances of the PaletteCatalog's object entries
##   - every node is adopted (LevelStorage.adopt), so save() writes all of it
## The level is never added to the scene tree: nothing runs _ready(), exactly like
## LevelStorage.duplicate_level.
##
## Units: tiles (8 px), (column, row) from a room's top-left tile, unless a name
## ends in _px. A one-screen room is 40 x 23 tiles (row 22 is half off screen).
##
## ROOM MAPS (paint_map): a room drawn as text, one character per tile.
##   ' ' keep what's there        '.' clear every terrain layer
##   '#' ground   'E' earth   'g' grass   '~' water   'I' ice
##   'c' crumbling rock   'i' crumbling ice   'F' falling block   'S' storm cloud
##   'H' hidden chamber   'X' cracked wall   'T' thicket   'o' grass cover   'O' thicket cover
##   '^' 'v' '<' '>' spikes pointing up / down / left / right (runs become strips)
##   '@' the spawn point: the player stands IN this cell, on the tile below it

const TILE: int = 8
## Map character -> PaletteCatalog terrain entry id.
const TERRAIN_OF: Dictionary = {
	"#": &"ground", "E": &"earth", "g": &"grass", "~": &"water", "I": &"ice",
	"c": &"crumble_rock", "i": &"crumble_ice", "F": &"falling_block", "S": &"storm_cloud",
	"H": &"hidden_chamber", "X": &"cracked_wall", "T": &"thicket", "o": &"overgrown_grass",
	"O": &"overgrown_thicket",
}
## Map character -> the way those spikes point.
const SPIKES_OF: Dictionary = {
	"^": Spikes.Facing.UP, "v": Spikes.Facing.DOWN, "<": Spikes.Facing.LEFT, ">": Spikes.Facing.RIGHT,
}
const WATER_LAYER: StringName = &"Water"
const HIDDEN_LAYER: StringName = &"Hidden"

## The level being built: a RoomManager root outside the scene tree.
var level: RoomManager = null
## Counts the spike strips made so far, for unique node names.
var _spike_count: int = 0


## A brand-new level titled `title`. LevelTemplate's boxed first room is taken out:
## the caller adds its own rooms and calls set_start_room.
static func create(title: String) -> LevelKit:
	var kit: LevelKit = LevelKit.new()
	kit.level = LevelTemplate.build_new_level(title)
	var first_room: Node = kit.level.get_node("Room1")
	kit.level.remove_child(first_room)
	first_room.free()
	return kit


## The level saved at `path`, to change and save again (under another path).
static func open(path: String) -> LevelKit:
	var kit: LevelKit = LevelKit.new()
	kit.level = LevelStorage.load_level(path).instantiate() as RoomManager
	return kit


## The level's LevelInfo node (title and start room).
func get_info() -> LevelInfo:
	return level.get_node(NodePath(LevelInfo.NODE_NAME)) as LevelInfo


func set_title(title: String) -> void:
	get_info().level_title = title


## The room node called `node_name`.
func get_room(node_name: String) -> Room:
	return level.get_node(node_name) as Room


## A new empty room, `size_px` big (one screen is 320 x 180: 40 x 22.5 tiles), its
## top-left corner at `map_px` on the map, `depth` layers behind the front
## (Room.DEPTH_SPACING). Elements are all off: turn on what the room needs.
func add_room(node_name: String, title: String, map_px: Vector2, size_px: Vector2, depth: int = 0) -> Room:
	var room: Room = LevelTemplate.build_empty_room(node_name, title, size_px)
	room.position = map_px + Room.depth_offset(depth)
	room.air_allowed = false
	room.earth_allowed = false
	level.add_child(room)
	# Before the Player: rooms first in the tree, like the editor's levels.
	level.move_child(room, _last_room_index() + 1)
	LevelStorage.adopt(room, level)
	return room


func _last_room_index() -> int:
	var last_index: int = -1
	for child: Node in level.get_children():
		if child is Room:
			last_index = child.get_index()
	return last_index


## Makes `room` the level's start room and stands the player on its spawn point.
func set_start_room(room: Room) -> void:
	get_info().start_room = room
	level.player.position = room.position + (room.get_node("SpawnPoint") as Marker2D).position


## Moves the room's spawn point: the player stands in tile (column, row).
func set_spawn(room: Room, column: int, row: int) -> void:
	(room.get_node("SpawnPoint") as Marker2D).position = Vector2(column * TILE + TILE / 2.0, (row + 1) * TILE)


# --- Terrain -----------------------------------------------------------------------

## Paints a rectangle of the terrain `entry_id` (a PaletteCatalog id). Like the
## editor's brush, it takes every other terrain out of those cells (water only
## stays inside a hidden chamber).
func fill(room: Room, entry_id: StringName, column: int, row: int, width: int, height: int) -> void:
	var entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(entry_id)
	var layer: TileMapLayer = _get_layer(room, entry)
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			var cell: Vector2i = Vector2i(x, y)
			if entry.layer_name != WATER_LAYER:
				_clear_cell(room, cell, entry.layer_name, entry.layer_name == HIDDEN_LAYER)
			var tile: Vector2i = entry.tile_plain
			if entry.tile_odd_column != TileBrush.NO_TILE and posmod(x, 2) == 1:
				tile = entry.tile_odd_column
			layer.set_cell(cell, TileBrush.SOURCE_ID, tile)
	for setting: StringName in entry.room_settings_on_create:
		room.set(setting, entry.room_settings_on_create[setting])
	_refresh_edges(room)


## Clears every terrain layer in a rectangle (open air).
func clear(room: Room, column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			_clear_cell(room, Vector2i(x, y), &"", false)
	_refresh_edges(room)


## Paints a room map (see the header), its top-left character at tile `origin`.
func paint_map(room: Room, rows: PackedStringArray, origin: Vector2i = Vector2i.ZERO) -> void:
	for row_index: int in rows.size():
		var line: String = rows[row_index]
		for column_index: int in line.length():
			var character: String = line[column_index]
			var cell: Vector2i = origin + Vector2i(column_index, row_index)
			if character == " ":
				continue
			if TERRAIN_OF.has(character):
				fill(room, TERRAIN_OF[character], cell.x, cell.y, 1, 1)
				continue
			_clear_cell(room, cell, &"", false)
			if character == "@":
				set_spawn(room, cell.x, cell.y)
	_add_spike_strips(room, rows, origin)
	_refresh_edges(room)


## Empties `cell` on every terrain layer but `keep_layer` (and water, with `keep_water`).
func _clear_cell(room: Room, cell: Vector2i, keep_layer: StringName, keep_water: bool) -> void:
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null or layer.name == keep_layer or (keep_water and layer.name == WATER_LAYER):
			continue
		layer.erase_cell(cell)


## The room's layer for a terrain entry, made the way TileBrush.get_layer makes it.
func _get_layer(room: Room, entry: PaletteCatalog.Entry) -> TileMapLayer:
	var brush: TileBrush = TileBrush.new(entry.layer_name, entry.tile_set, entry.layer_script,
		entry.tile_plain, entry.tile_top_edge, entry.tile_odd_column)
	return brush.get_layer(room, level, true)


## Gives ground and grass their "top edge" tile where nothing of the same layer is
## above, the plain tile elsewhere (what TileBrush does cell by cell while painting).
func _refresh_edges(room: Room) -> void:
	for entry_id: StringName in [&"ground", &"grass"]:
		var entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(entry_id)
		var layer: TileMapLayer = room.get_node_or_null(NodePath(entry.layer_name)) as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var is_surface: bool = layer.get_cell_source_id(cell + Vector2i.UP) == -1
			layer.set_cell(cell, TileBrush.SOURCE_ID, entry.tile_top_edge if is_surface else entry.tile_plain)


## Turns the map's spike characters into Spikes strips: up and down spikes run
## along a row, left and right spikes down a column.
func _add_spike_strips(room: Room, rows: PackedStringArray, origin: Vector2i) -> void:
	var taken: Dictionary = {}
	for row_index: int in rows.size():
		for column_index: int in rows[row_index].length():
			var character: String = rows[row_index][column_index]
			var start: Vector2i = Vector2i(column_index, row_index)
			if not SPIKES_OF.has(character) or taken.has(start):
				continue
			var facing: Spikes.Facing = SPIKES_OF[character]
			var step: Vector2i = Vector2i.RIGHT if (facing == Spikes.Facing.UP or facing == Spikes.Facing.DOWN) else Vector2i.DOWN
			var count: int = 0
			var cursor: Vector2i = start
			while cursor.y < rows.size() and cursor.x < rows[cursor.y].length() and rows[cursor.y][cursor.x] == character:
				taken[cursor] = true
				count += 1
				cursor += step
			spikes(room, origin.x + start.x, origin.y + start.y, count, facing)


## A strip of `count` spikes starting at tile (column, row): up and down strips
## run right, left and right strips run down.
func spikes(room: Room, column: int, row: int, count: int, facing: Spikes.Facing = Spikes.Facing.UP) -> Node2D:
	_spike_count += 1
	return place(room, &"spikes", "KitSpikes%d" % _spike_count, Vector2(column * TILE, row * TILE),
		{&"facing": facing, &"tile_count": count})


# --- Objects -----------------------------------------------------------------------

## Adds an instance of the PaletteCatalog object `entry_id` to `room`, at
## `position_px` (the object's own origin: see each entry's comment in the
## catalog), with `settings` {property: value}. The room settings that come with
## the object (a brazier turns Fire on) are set like in the editor.
func place(room: Room, entry_id: StringName, node_name: String, position_px: Vector2, settings: Dictionary = {}) -> Node2D:
	var entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(entry_id)
	var node: Node2D = entry.scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	node.name = node_name
	node.position = position_px
	for property: StringName in settings:
		node.set(property, settings[property])
	room.add_child(node)
	LevelStorage.adopt(node, level)
	for setting: StringName in entry.room_settings_on_create:
		room.set(setting, entry.room_settings_on_create[setting])
	return node


## Links `targets` into `holder`'s Array property `property` (a door's switches, an
## enemy gate's enemies). The property's own typed array is copied and filled, so
## its element type stays what the script declared.
func link(holder: Node, property: StringName, targets: Array) -> void:
	var list: Array = (holder.get(property) as Array).duplicate()
	for target: Variant in targets:
		list.append(target)
	holder.set(property, list)


## Removes the child `node_name` of `room` (a stray object of a room being reworked).
func remove(room: Room, node_name: String) -> void:
	var node: Node = room.get_node_or_null(node_name)
	if node != null:
		room.remove_child(node)
		node.free()


## A depth gate standing on the floor row `floor_row`, its left edge on `column`.
## Its twin is the gate at the same map spot one depth away: place both.
func depth_gate(room: Room, node_name: String, column: int, floor_row: int) -> Node2D:
	return place(room, &"depth_gate", node_name, Vector2(column * TILE, floor_row * TILE - DepthGate.GATE_SIZE.y))


## Feet position (px) of something standing on `floor_row` in the middle of `column`.
static func on_floor(column: int, floor_row: int) -> Vector2:
	return Vector2(column * TILE + TILE / 2.0, floor_row * TILE)


## The tile corner at (column, row), px: where 2x2-tile pick-ups (orbs, shards,
## the feather) and floor-standing 2x2 things (braziers, key lights) go.
static func corner(column: int, row: int) -> Vector2:
	return Vector2(column * TILE, row * TILE)


# --- Checks and saving -------------------------------------------------------------

## Problems a play-test would trip over, as text lines (empty = none found):
## a spawn point inside something solid or with no floor under it, a room with no
## title, a start room that isn't set, relic slots used twice or missing.
func find_problems() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if get_info().start_room == null:
		problems.append("no start room")
	var slots_by_element: Dictionary = {}
	var feather_count: int = 0
	var goal_count: int = 0
	for child: Node in level.get_children():
		var room: Room = child as Room
		if room == null:
			continue
		var spawn: Marker2D = room.get_node("SpawnPoint") as Marker2D
		var feet_cell: Vector2i = Vector2i((spawn.position / TILE).floor())
		if _is_solid(room, feet_cell + Vector2i.UP):
			problems.append("%s: spawn point inside a solid tile" % room.name)
		# A spawn point may float a tile above its floor (the player drops onto it).
		var has_floor: bool = _is_solid(room, feet_cell) or _is_solid(room, feet_cell + Vector2i.DOWN)
		if not has_floor and not _has_platform_under(room, spawn.position):
			problems.append("%s: spawn point has no floor under it" % room.name)
		for node: Node in room.get_children():
			if node is RelicShard:
				var shard: RelicShard = node as RelicShard
				var slots: Array = slots_by_element.get(shard.element, [])
				if slots.has(shard.slot):
					problems.append("%s: relic slot %d placed twice" % [room.name, shard.slot])
				slots.append(shard.slot)
				slots_by_element[shard.element] = slots
			elif node is GoldenFeather:
				feather_count += 1
			elif node is Goal:
				goal_count += 1
	for element: Variant in slots_by_element:
		if (slots_by_element[element] as Array).size() != 4:
			problems.append("relic of element %s has %d of 4 slots" % [element, (slots_by_element[element] as Array).size()])
	if feather_count > 1:
		problems.append("%d golden feathers (one per level)" % feather_count)
	if goal_count == 0:
		problems.append("no Goal")
	return problems


## True if `cell` holds a solid tile on any layer of `room` (water, storm clouds
## and hidden chambers aren't solid).
func _is_solid(room: Room, cell: Vector2i) -> bool:
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null or layer.name == WATER_LAYER or layer.name == HIDDEN_LAYER or layer is NonSolidLayer:
			continue
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


## True if a one-way platform's top is right under `feet_px` (a spawn on a girder).
func _has_platform_under(room: Room, feet_px: Vector2) -> bool:
	for node: Node in room.get_children():
		if node is MetalPlatform or node is RailPlatform:
			var platform: Node2D = node as Node2D
			var half_width: float = float(platform.get(&"platform_width")) / 2.0
			if absf(feet_px.x - platform.position.x) <= half_width and absf(feet_px.y - platform.position.y) <= TILE:
				return true
	return false


## Writes the level to `path` and frees its nodes. Returns OK or an error code.
func save(path: String) -> Error:
	var error: Error = LevelStorage.save_level(level, path)
	level.free()
	level = null
	return error
