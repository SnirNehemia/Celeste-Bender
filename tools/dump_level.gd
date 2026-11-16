extends Node
## tools/dump_level.gd: prints an editor level as TEXT, so a level can be studied
## (or checked after a build) without opening the editor: every room as a map of
## characters, one per tile, followed by its objects and their settings.
## LEVEL_DESIGN_GUIDE.md §9 says when to use it.
##
## Run it from the project folder (console build), as a scene so the autoloads exist:
##   godot --headless --path . res://tools/dump_level.tscn -- res://levels/chapter_1_air.tscn > out.txt
## Add room node names after the path to print only those: `-- <level> Room3 Room14`.
## It only reads: the level is instantiated outside the scene tree and freed.
##
## The map uses LevelKit's characters where it has one (see level_kit.gd's header):
##   '#' ground  'E' earth  'g' grass  '~' water  'I' ice  'c' crumbling rock
##   'i' crumbling ice  'F' falling block  'S' storm cloud  'H' hidden chamber
##   'X' cracked wall  'T' thicket  'W' stone wall  '?' a layer this tool doesn't know
##   '^' 'v' '<' '>' spikes  '@' the spawn point  '.' open air
## Objects aren't drawn on the map: they're listed under it with their tile.

const TILE: int = 8
## TileMapLayer node name -> the character its tiles are printed as.
const LAYER_CHARACTERS: Dictionary = {
	"Tiles": "#", "Earth": "E", "Grass": "g", "Water": "~", "Ice": "I", "CrumbleRock": "c",
	"CrumbleIce": "i", "FallingBlock": "F", "StormCloud": "S", "Hidden": "H",
	"CrackedWalls": "X", "Thicket": "T", "StoneWalls": "W",
}
const UNKNOWN_LAYER_CHARACTER: String = "?"
const WATER_CHARACTER: String = "~"
const OPEN_AIR_CHARACTER: String = "."
## Spikes.Facing value -> the character of a spike pointing that way.
const SPIKE_CHARACTERS: Dictionary = {
	Spikes.Facing.UP: "^", Spikes.Facing.DOWN: "v", Spikes.Facing.LEFT: "<", Spikes.Facing.RIGHT: ">",
}
## Exported properties left out of the object list: long and never a design choice.
const SKIPPED_PROPERTIES: Array[String] = ["script", "immunity"]


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		print("[DumpLevel] Usage: -- res://levels/<level>.tscn [RoomName ...]")
		get_tree().quit()
		return
	var wanted_rooms: PackedStringArray = arguments.slice(1)
	var level: Node = LevelStorage.load_level(arguments[0]).instantiate()
	for child: Node in level.get_children():
		var room: Room = child as Room
		if room != null and (wanted_rooms.is_empty() or wanted_rooms.has(String(room.name))):
			_print_room(room)
	level.free()
	get_tree().quit()


## Prints one room: a header line, the tile map, then one line per object.
func _print_room(room: Room) -> void:
	var columns: int = ceili(room.room_size.x / TILE)
	var rows: int = ceili(room.room_size.y / TILE)
	print("\n=== %s \"%s\" map_px=%s size=%dx%d tiles air=%s earth=%s fire=%s water=%s dark=%s" % [
		room.name, room.display_title, room.position, columns, rows,
		room.air_allowed, room.earth_allowed, room.fire_allowed, room.water_allowed, room.is_dark])
	var grid: Array[PackedStringArray] = []
	for row: int in rows:
		var line: PackedStringArray = PackedStringArray()
		line.resize(columns)
		line.fill(OPEN_AIR_CHARACTER)
		grid.append(line)
	_draw_terrain(room, grid)
	var object_lines: PackedStringArray = _draw_and_list_objects(room, grid)
	# A ruler over the map: the tens digit above every tenth column.
	var ruler: String = "     "
	for column: int in columns:
		@warning_ignore("integer_division")
		ruler += str((column / 10) % 10) if column % 10 == 0 else " "
	print(ruler)
	for row: int in rows:
		print("%3d  %s" % [row, "".join(grid[row])])
	for line: String in object_lines:
		print(line)


## Writes every terrain layer's tiles into `grid`. Water never overwrites another
## terrain (a hidden chamber can hold water: the chamber is what matters on a map).
func _draw_terrain(room: Room, grid: Array[PackedStringArray]) -> void:
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null:
			continue
		var character: String = LAYER_CHARACTERS.get(String(layer.name), UNKNOWN_LAYER_CHARACTER)
		for cell: Vector2i in layer.get_used_cells():
			if character == WATER_CHARACTER and _get_character(grid, cell) != OPEN_AIR_CHARACTER:
				continue
			_set_character(grid, cell, character)


## Draws the spawn point and the spikes into `grid`, and returns a text line for
## every other object: name, class, tile, position and its exported settings.
func _draw_and_list_objects(room: Room, grid: Array[PackedStringArray]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for child: Node in room.get_children():
		var node: Node2D = child as Node2D
		if node == null or node is TileMapLayer:
			continue
		var cell: Vector2i = Vector2i((node.position / TILE).floor())
		if node.name == "SpawnPoint":
			# The marker is at the player's feet: the player stands in the cell above.
			_set_character(grid, cell + Vector2i.UP, "@")
			continue
		if node is Spikes:
			var spikes: Spikes = node as Spikes
			var runs_right: bool = spikes.facing == Spikes.Facing.UP or spikes.facing == Spikes.Facing.DOWN
			for index: int in spikes.tile_count:
				var offset: Vector2i = Vector2i(index, 0) if runs_right else Vector2i(0, index)
				_set_character(grid, cell + offset, SPIKE_CHARACTERS.get(spikes.facing, "^"))
			continue
		var script: Script = node.get_script() as Script
		# Scripted objects by their class_name (Sentry), plain nodes by their Godot class.
		var class_label: String = node.get_class()
		if script != null:
			class_label = String(script.get_global_name())
		lines.append("  %s (%s) at tile (%d,%d) px %s  %s" % [
			node.name, class_label, cell.x, cell.y, node.position, _describe_settings(node, script)])
	return lines


## The node's exported script properties as "name=value" pairs. Linked nodes
## (a door's switches) are shown by name.
func _describe_settings(node: Node, script: Script) -> String:
	if script == null:
		return ""
	var pairs: PackedStringArray = PackedStringArray()
	for info: Dictionary in script.get_script_property_list():
		var usage: int = info["usage"]
		var is_exported: bool = (usage & PROPERTY_USAGE_STORAGE) != 0 and (usage & PROPERTY_USAGE_EDITOR) != 0
		if not is_exported or SKIPPED_PROPERTIES.has(info["name"]):
			continue
		var value: Variant = node.get(info["name"])
		if value is Array:
			var names: PackedStringArray = PackedStringArray()
			for item: Variant in value:
				names.append(String((item as Node).name) if item is Node else str(item))
			value = "[" + ", ".join(names) + "]"
		pairs.append("%s=%s" % [info["name"], value])
	return " ".join(pairs)


func _get_character(grid: Array[PackedStringArray], cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size():
		return ""
	return grid[cell.y][cell.x]


## Sets one map character; cells outside the room are ignored.
func _set_character(grid: Array[PackedStringArray], cell: Vector2i, character: String) -> void:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size():
		return
	grid[cell.y][cell.x] = character
