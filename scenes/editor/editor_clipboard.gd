class_name EditorClipboard
extends RefCounted
## EditorClipboard: what the level editor's Ctrl+C / Ctrl+X copied, and how it's
## pasted back (Ctrl+V, or Ctrl+Shift+V mirrored left-right). LevelEditor owns one
## (its `clipboard`); the region comes from the Select tool's Shift+drag.
##
## What it holds:
##   - tiles: every terrain tile in the region, as [offset cell, layer name, value]
##     (the value is TileBrush's Vector3i: source id, atlas x, atlas y). Only filled
##     cells: pasting never erases what's already there, it lays the copy on top.
##   - objects: a loose COPY of every object whose outline lies inside the region
##     (made with PaletteCatalog.copy_settings, so later edits to the original don't
##     change the clipboard), its origin's offset from the region's corner, and the
##     links it has to other copied objects (a door and its switch stay linked; links
##     to things outside the region are dropped). Spawn points are never copied.
## The region may cross rooms, and a paste may too: cells and objects go to the
## room they land in (LevelEditor.route_cell), and anything landing outside every
## room is dropped.
##
## Mirrored paste flips the cells and objects left-right inside the region's
## width, and mirrors what has a direction: ice slope tiles (IceLayer), spikes
## facing left / right, arrow and point properties (wind, rails, a vine's end),
## turned objects (a plank on a slant), a sentry on a side wall.
##
## The object copies are Nodes outside the tree, which nothing frees by itself:
## LevelEditor calls free_templates() when it replaces or drops the clipboard.

const TILE: int = 8
## Int properties that are a side, -1 or 1 (0 = none): mirrored by flipping the sign.
const SIDE_PROPERTIES: Array[StringName] = [&"wall_side"]

## The region's size in tiles.
var size_cells: Vector2i = Vector2i.ZERO
## [Vector2i offset, StringName layer name, Vector3i value] per copied tile.
var tiles: Array[Array] = []
## [Node2D copy, Vector2 origin offset from the region's corner (px),
##  Array[int] indexes of the copied objects it links to] per copied object.
var objects: Array[Array] = []


func is_empty() -> bool:
	return tiles.is_empty() and objects.is_empty()


## Copies the region `cells` of `grid_room`'s grid (it may reach into the rooms
## next door) from `editor`'s level.
static func copy_from(editor: LevelEditor, grid_room: Room, cells: Rect2i) -> EditorClipboard:
	var copied: EditorClipboard = EditorClipboard.new()
	copied.size_cells = cells.size
	var layer_names: Array[StringName] = _terrain_layer_names()
	for y: int in range(cells.position.y, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			var target: Array = editor.route_cell(grid_room, Vector2i(x, y))
			if target.is_empty():
				continue
			var room: Room = target[0]
			for layer_name: StringName in layer_names:
				var layer: TileMapLayer = room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
				if layer == null:
					continue
				var value: Vector3i = TileBrush.read_cell(layer, target[1])
				if value != TileBrush.EMPTY:
					copied.tiles.append([Vector2i(x, y) - cells.position, layer_name, value])
	# Objects wholly inside the region, in every room it touches.
	var region: Rect2 = Rect2(grid_room.global_position + Vector2(cells.position * TILE), Vector2(cells.size * TILE))
	var sources: Array[Node2D] = []
	for room: Room in editor.get_rooms():
		if not room.get_bounds().intersects(region):
			continue
		for child: Node in room.get_children():
			var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(child)
			if entry == null or entry.scene == null:
				continue  # the spawn point (no scene), or not a catalog object
			if region.encloses(PaletteCatalog.get_bounds(child as Node2D)):
				sources.append(child as Node2D)
	for source: Node2D in sources:
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(source)
		var template: Node2D = PaletteCatalog.instantiate(entry)
		PaletteCatalog.copy_settings(source, template)
		template.rotation = source.rotation  # a node setting, not a script one: copy_settings skips it
		var linked: Array[int] = []
		if entry.link_property != &"":
			for target: Variant in source.get(entry.link_property):
				var index: int = sources.find(target)
				if index != -1:
					linked.append(index)
		copied.objects.append([template, source.global_position - region.position, linked])
	return copied


## Pastes with the region's top-left on the cell `top_left` of `grid_room`'s grid,
## as one undo step. Returns false if nothing landed inside a room.
func paste(editor: LevelEditor, grid_room: Room, top_left: Vector2i, mirrored: bool) -> bool:
	editor.begin_paste(grid_room)
	for tile: Array in tiles:
		var offset: Vector2i = tile[0]
		var value: Vector3i = tile[2]
		if mirrored:
			offset.x = size_cells.x - 1 - offset.x
			value = _mirrored_value(tile[1], value)
		editor.paste_tile(top_left + offset, tile[1], value)
	var corner: Vector2 = grid_room.global_position + Vector2(top_left * TILE)
	var copies: Array[Node2D] = []
	var new_objects: Array[Array] = []
	for object: Array in objects:
		var template: Node2D = object[0]
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(template)
		var copy: Node2D = PaletteCatalog.instantiate(entry)
		PaletteCatalog.copy_settings(template, copy)
		copy.rotation = template.rotation
		var origin: Vector2 = corner + (object[1] as Vector2)
		if mirrored:
			origin = _mirror_object(copy, template, origin, corner)
		copies.append(copy)
		var bounds: Rect2 = PaletteCatalog.get_local_bounds(copy)
		var room: Room = editor.room_at(origin + bounds.get_center())
		if room == null:
			continue  # landed outside every room: dropped (and freed below)
		copy.position = origin - room.global_position
		new_objects.append([room, copy])
	# Links between copies point at the new copies; links to anything else are gone.
	for index: int in objects.size():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(copies[index])
		if entry.link_property == &"":
			continue
		# duplicate() then clear(): keeps the list's type (a door's Array[Switch]).
		var links: Array = (copies[index].get(entry.link_property) as Array).duplicate()
		links.clear()
		for target_index: int in (objects[index][2] as Array):
			if _is_placed(copies[target_index], new_objects):
				links.append(copies[target_index])
		copies[index].set(entry.link_property, links)
	for copy: Node2D in copies:
		if not _is_placed(copy, new_objects):
			copy.free()
	return editor.finish_paste(new_objects)


## Frees the loose object copies (see the header).
func free_templates() -> void:
	for object: Array in objects:
		var template: Node2D = object[0]
		if is_instance_valid(template):
			template.free()
	objects.clear()


## The terrain layer names of the catalog, each once.
static func _terrain_layer_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.kind == PaletteCatalog.Kind.TERRAIN and not names.has(entry.layer_name):
			names.append(entry.layer_name)
	return names


## A tile value seen in a mirror: only the ice slopes look different.
static func _mirrored_value(layer_name: StringName, value: Vector3i) -> Vector3i:
	if layer_name != &"Ice":
		return value
	var atlas: Vector2i = IceLayer.get_mirrored_tile(Vector2i(value.y, value.z))
	return Vector3i(value.x, atlas.x, atlas.y)


## Mirrors `copy`'s directions, and returns its origin mirrored inside the region
## (whose left edge is at `corner`.x): its OUTLINE flips round the region's middle.
func _mirror_object(copy: Node2D, template: Node2D, origin: Vector2, corner: Vector2) -> Vector2:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(copy)
	var spikes: Spikes = copy as Spikes
	if spikes != null:
		if spikes.facing == Spikes.Facing.LEFT:
			spikes.facing = Spikes.Facing.RIGHT
		elif spikes.facing == Spikes.Facing.RIGHT:
			spikes.facing = Spikes.Facing.LEFT
	if entry.arrow_property != &"":
		var arrow: Vector2 = copy.get(entry.arrow_property)
		copy.set(entry.arrow_property, Vector2(-arrow.x, arrow.y))
	for point_property: StringName in entry.point_properties:
		var point: Vector2 = copy.get(point_property)
		copy.set(point_property, Vector2(-point.x, point.y))
	if entry.uses_rotation:
		copy.rotation_degrees = -template.rotation_degrees
	for side_property: StringName in SIDE_PROPERTIES:
		if side_property in copy:
			copy.set(side_property, -int(copy.get(side_property)))
	# The template's outline, where it was in the region; the copy's (its directions
	# now mirrored) goes where that outline lands in the mirror.
	var old_bounds: Rect2 = PaletteCatalog.get_local_bounds(template)
	var new_bounds: Rect2 = PaletteCatalog.get_local_bounds(copy)
	var old_left: float = origin.x + old_bounds.position.x
	var mirrored_left: float = corner.x + size_cells.x * TILE - (old_left - corner.x) - old_bounds.size.x
	return Vector2(mirrored_left - new_bounds.position.x, origin.y + old_bounds.position.y - new_bounds.position.y)


static func _is_placed(copy: Node2D, new_objects: Array[Array]) -> bool:
	for room_and_node: Array in new_objects:
		if room_and_node[1] == copy:
			return true
	return false
