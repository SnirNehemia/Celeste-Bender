class_name RoomImport
extends RefCounted
## RoomImport: copies a room out of any existing world into the level being edited
## (Level_editor.md §5 "Import room as a copy", Stage L7).
##
## Where rooms come from (list_sources): the chapter and test worlds the main menu
## lists (MainMenu.CHAPTERS, so a Fire chapter added there shows up here too), the
## Air test rooms, and every other editor level (LevelStorage).
##
## What "a copy" means: the new room belongs to this level, node by node, and is
## never linked to the original again. Editing the copy can't change Earth room 3,
## and rebuilding Earth room 3 can't change the copy.
##   - A room that is its own scene file in its world (room_03.tscn placed in
##     earth_world.tscn, an "instance") is built fresh from that file, as the file's
##     ROOT, then its scene_file_path is cleared. Taking the instance node out of the
##     world instead would keep a hidden tie to room_03.tscn, which Godot uses when
##     saving to leave out every value that matches the file: those values would be
##     lost. The world's own changes to the room's settings (its title...) are copied
##     over; its position isn't (the copy goes where you click).
##   - A room written straight into its world (an editor level's rooms) is taken out
##     of a fresh copy of that world.
## Objects inside the room (crates, enemies...) stay instances of THEIR scenes, like
## objects the editor places. Links to things outside the room (a door wired to a
## plate next door) are dropped, because those things aren't copied.
##
## Everything is static: RoomImport.list_rooms(path), RoomImport.copy_room(...).
## Nothing here enters the scene tree: worlds are built, read and freed.

## Worlds that aren't in the main menu's chapter list, but have rooms worth copying.
const EXTRA_SOURCES: Array = [
	["Air  -  test rooms", "res://tests/test_world.tscn"],
]


## Every world rooms can be imported from: [[title, scene path], ...]. The level
## at `except_path` (the one being edited) is left out.
static func list_sources(except_path: String = "") -> Array:
	var sources: Array = []
	for chapter: Array in MainMenu.CHAPTERS + EXTRA_SOURCES:
		sources.append([String(chapter[0]), String(chapter[1])])
	for level_path: String in LevelStorage.list_levels():
		if level_path != except_path:
			sources.append(["Level  -  " + LevelStorage.read_title(level_path), level_path])
	return sources


## The rooms of the world at `world_path`: [[node name, title], ...] in world order.
## Empty if the world can't be loaded.
static func list_rooms(world_path: String) -> Array:
	var rooms: Array = []
	var world: Node = _instantiate(world_path)
	if world == null:
		return rooms
	for child: Node in world.get_children():
		var room: Room = child as Room
		if room != null:
			rooms.append([String(room.name), room.display_title if room.display_title != "" else String(room.name)])
	world.free()  # never entered the tree: free() at once
	return rooms


## A copy of the room named `room_name` in the world at `world_path`, owned by
## nothing and outside the tree (the editor adds and adopts it). Null if not found.
static func copy_room(world_path: String, room_name: String) -> Room:
	var world: Node = _instantiate(world_path)
	if world == null:
		return null
	var original: Room = world.get_node_or_null(NodePath(room_name)) as Room
	if original == null:
		world.free()
		return null
	var copy: Room
	if original.scene_file_path != "":
		# Its own scene file: build it again as a root (see the header).
		var room_scene: PackedScene = load(original.scene_file_path) as PackedScene
		copy = room_scene.instantiate() as Room
		PaletteCatalog.copy_settings(original, copy)  # the world's own settings for it
		copy.scene_file_path = ""
	else:
		copy = original
		_drop_outside_links(copy, copy)
		world.remove_child(copy)
	copy.position = Vector2.ZERO
	world.free()
	return copy


## Removes every reference from the nodes under `node` to nodes outside `room`
## (links to doors, plates or vines in other rooms): they're not copied. Arrays
## of nodes lose those entries; a single node reference becomes null.
static func _drop_outside_links(node: Node, room: Room) -> void:
	for property: Dictionary in node.get_property_list():
		var usage: int = property["usage"]
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(property["name"])
		if value is Node and not _is_inside(value, room):
			node.set(property["name"], null)
		elif value is Array:
			# duplicate() keeps the array's type (a typed Array[Switch] stays typed).
			var kept: Array = (value as Array).duplicate()
			var changed: bool = false
			for item: Variant in value:
				if item is Node and not _is_inside(item, room):
					kept.erase(item)
					changed = true
			if changed:
				node.set(property["name"], kept)
	for child: Node in node.get_children():
		_drop_outside_links(child, room)


static func _is_inside(node: Node, room: Room) -> bool:
	return node == room or room.is_ancestor_of(node)


## Builds a world's nodes outside the tree. Editor levels go through LevelStorage
## (it re-reads the file, so a level saved a moment ago is up to date).
static func _instantiate(world_path: String) -> Node:
	var packed: PackedScene = LevelStorage.load_level(world_path)
	return packed.instantiate() if packed != null else null
