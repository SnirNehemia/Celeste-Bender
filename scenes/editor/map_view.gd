class_name MapView
extends RefCounted
## MapView: the level editor's map of rooms (Level_editor.md §5, Stage L7). M opens
## and closes it. The camera zooms out until the whole level fits; the rooms are
## drawn as they really are (that's the "tiny tile drawing"), with their outlines,
## names, the start room's star and, on shared edges, the openings (exits) in green.
## EditorOverlay draws all of that from what this object says.
##
## Mouse, in the map:
##   - drag on empty space: a new, empty room at the dragged size (only a spawn
##     point; the room panel's "Fill edges" button walls it in)
##   - drag a room: move it          - drag its edge or corner: resize it
##   - click a room: select it (its settings show in the property panel)
##   - double-click a room: close the map and edit that room
## Keys: S makes the selected room the start room, Delete deletes it, I imports a
## room from another world (RoomImport; a ghost follows the mouse until you click),
## Esc cancels an import or closes the map.
## Right-click (after the L11 play-test): a menu (EditorUI.show_menu) to copy the
## room under the mouse, paste the copied one (a ghost follows the mouse like an
## import, a click puts it down), edit it, make it the start room or delete it.
## Copying packs the level as it is now (unsaved changes too) and keeps that
## (`clipboard`), so later changes to the original don't change the copy. Links to
## things outside the room are dropped, as with an import.
##
## Snapping ("180 + whole tiles", decided in Stage L7):
##   - widths are whole tiles, at least one screen (320)
##   - heights are 180 + whole tiles (180, 188, 196...): like every existing room,
##     the last tile row always hangs half below the room's bottom edge
##   - positions are on the 8 px grid, or on a neighbour's edge when close to it
##     (a room under a 180 px room starts at y = 180, half a tile off the grid);
##     a room beside another then lines its tile rows up with that neighbour's
##     (_align_to_side_neighbours), so walls and exits meet across the edge
##   - dragging the LEFT or TOP edge keeps the room's contents where they are in
##     the level; it moves in whole tiles of the room's own grid, so its tiles stay
##     on cells. Tiles left outside a smaller room are cut off (undo brings them back).
## Overlaps are refused: the preview turns red and letting go puts the room back.
##
## Every change is one UndoRedo step on the editor's undo_redo.

enum Drag { NONE, CREATE, MOVE, RESIZE }

## Edge bits for resizing: a corner is two of them.
const EDGE_LEFT: int = 1
const EDGE_RIGHT: int = 2
const EDGE_TOP: int = 4
const EDGE_BOTTOM: int = 8
const TILE: int = 8
const MIN_ROOM_SIZE: Vector2 = Vector2(320, 180)
## How close (screen pixels) the mouse must be to an edge to grab it.
const EDGE_PICK_SCREEN_PIXELS: float = 4.0
## How close (screen pixels) a dragged edge must come to a neighbour's to snap to it.
const SNAP_SCREEN_PIXELS: float = 8.0
## Openings are found by looking at both sides of a shared edge every this many px.
const OPENING_SAMPLE_STEP: float = 4.0

var editor: LevelEditor
var is_open: bool = false
## The room clicked last in the map (S and Delete act on it), or null.
var selected_room: Room = null
## The room and edges under the mouse (for the overlay and the cursor).
var hovered_room: Room = null
var hovered_edges: int = 0

## The drag in progress.
var drag: Drag = Drag.NONE
var drag_room: Room = null
var drag_edges: int = 0
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_rect: Rect2 = Rect2()
## Where the dragged (or new, or imported) room would go, and whether it can.
var preview_rect: Rect2 = Rect2()
var preview_valid: bool = true
## A copied room waiting to be placed with a click (I, or Paste), or null.
var importing_room: Room = null
## The copied room: the level packed when Copy was chosen, and the room's name in
## it. Null = nothing copied yet.
var clipboard: PackedScene = null
var clipboard_room_name: String = ""
var clipboard_title: String = ""

## The room view's camera, to come back to when the map closes.
var room_view_zoom_index: int = 0
var room_view_position: Vector2 = Vector2.ZERO


func _init(owner_editor: LevelEditor) -> void:
	editor = owner_editor


# --- Opening and closing ---

## Shows the map: zooms out until every room fits between the panels.
func open() -> void:
	if is_open:
		return
	is_open = true
	room_view_zoom_index = editor.camera.zoom_index
	room_view_position = editor.camera.position
	selected_room = editor.current_room
	editor.fit_view(get_level_bounds())


## Back to the room view: on `focus_room` (zoomed to fit it) or where it was.
func close(focus_room: Room = null) -> void:
	cancel_import()
	if not is_open:
		return
	drag = Drag.NONE
	is_open = false
	hovered_room = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if focus_room != null:
		editor.current_room = focus_room
		editor.fit_view(focus_room.get_bounds())
	else:
		editor.camera.zoom_index = room_view_zoom_index
		editor.camera.zoom = Vector2.ONE * editor.camera.get_zoom_factor()
		editor.camera.position = room_view_position
	editor.ui.set_zoom(editor.camera.get_zoom_factor())


## Every room's rectangle together (the first room's if there's only one).
func get_level_bounds() -> Rect2:
	var rooms: Array[Room] = editor.get_rooms()
	if rooms.is_empty():
		return Rect2(Vector2.ZERO, MIN_ROOM_SIZE)
	var bounds: Rect2 = room_rect(rooms[0])
	for room: Room in rooms:
		bounds = bounds.merge(room_rect(room))
	return bounds


## A room's rectangle in level coordinates.
static func room_rect(room: Room) -> Rect2:
	return Rect2(room.position, room.room_size)


# --- Input (LevelEditor passes the map's events here) ---

## Handles one map event. Returns true if it was used.
func handle_input(event: InputEvent, mouse_world: Vector2) -> bool:
	if event.is_action_pressed("editor_paint"):
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		_on_press(mouse_world, mouse_button != null and mouse_button.double_click)
	elif event.is_action_released("editor_paint"):
		_on_release()
	elif event.is_action_pressed("editor_erase"):
		if importing_room != null:
			cancel_import()  # right-click drops a room you were about to place
		else:
			_open_room_menu(mouse_world)
	elif event.is_action_pressed("editor_delete"):
		if selected_room != null:
			delete_room(selected_room)
	# Exact match (no Ctrl): Ctrl+S must still save, not pick the start room.
	elif event.is_action_pressed("editor_start_room", false, true):
		if selected_room != null:
			set_start_room(selected_room)
		else:
			editor.ui.show_message("Click a room first, then S makes it the start room.", true)
	elif event.is_action_pressed("editor_import"):
		editor.ui.import_picker.open(editor.level_path)
	elif event.is_action_pressed("editor_back"):
		if importing_room != null:
			cancel_import()
		else:
			close()
	else:
		return false
	return true


## The mouse moved: update the drag's preview, or what's under the mouse.
func mouse_moved(mouse_world: Vector2) -> void:
	var snap_distance: float = SNAP_SCREEN_PIXELS / editor.camera.get_zoom_factor()
	match drag:
		Drag.CREATE:
			preview_rect = snap_new_room(drag_start_mouse, mouse_world, snap_distance)
		Drag.MOVE:
			preview_rect = snap_moved(Rect2(drag_start_rect.position + mouse_world - drag_start_mouse, drag_start_rect.size),
				drag_room, snap_distance)
		Drag.RESIZE:
			preview_rect = snap_resized(drag_start_rect, drag_edges, mouse_world, drag_room, snap_distance)
		Drag.NONE:
			if importing_room != null:
				preview_rect = snap_moved(Rect2(mouse_world - importing_room.room_size / 2.0, importing_room.room_size),
					null, snap_distance)
	if drag != Drag.NONE or importing_room != null:
		preview_valid = is_free(preview_rect, drag_room)
	_update_hover(mouse_world)


func _on_press(mouse_world: Vector2, is_double_click: bool) -> void:
	if importing_room != null:
		mouse_moved(mouse_world)
		place_import(preview_rect.position)
		return
	var room: Room = editor.room_at(mouse_world)
	var edges: int = edges_at(mouse_world)
	if is_double_click and room != null:
		close(room)
		return
	drag_start_mouse = mouse_world
	if edges != 0:
		drag = Drag.RESIZE
		drag_room = hovered_room
		drag_edges = edges
	elif room != null:
		drag = Drag.MOVE
		drag_room = room
	else:
		drag = Drag.CREATE
		drag_room = null
		select_room(null)
		preview_rect = Rect2(mouse_world, Vector2.ZERO)
		preview_valid = true
		return
	select_room(drag_room)
	drag_start_rect = room_rect(drag_room)
	preview_rect = drag_start_rect
	preview_valid = true


func _on_release() -> void:
	var finished: Drag = drag
	drag = Drag.NONE
	match finished:
		Drag.CREATE:
			# A click (not a drag) on empty space only clears the selection.
			if preview_rect.size.x > 0.0 and preview_rect.size.y > 0.0:
				create_room(preview_rect)
		Drag.MOVE, Drag.RESIZE:
			set_room_rect(drag_room, preview_rect, finished == Drag.RESIZE)
	drag_room = null


func select_room(room: Room) -> void:
	selected_room = room
	if room != null:
		editor.current_room = room


func _update_hover(mouse_world: Vector2) -> void:
	hovered_edges = 0
	hovered_room = editor.room_at(mouse_world)
	if drag == Drag.NONE and importing_room == null:
		hovered_edges = edges_at(mouse_world)
	var cursor: Input.CursorShape = Input.CURSOR_ARROW
	var edges: int = drag_edges if drag == Drag.RESIZE else hovered_edges
	if edges == EDGE_LEFT or edges == EDGE_RIGHT:
		cursor = Input.CURSOR_HSIZE
	elif edges == EDGE_TOP or edges == EDGE_BOTTOM:
		cursor = Input.CURSOR_VSIZE
	elif edges == EDGE_LEFT | EDGE_TOP or edges == EDGE_RIGHT | EDGE_BOTTOM:
		cursor = Input.CURSOR_FDIAGSIZE
	elif edges != 0:
		cursor = Input.CURSOR_BDIAGSIZE
	elif drag == Drag.MOVE:
		cursor = Input.CURSOR_MOVE
	Input.set_default_cursor_shape(cursor)


## The edges (EDGE_* bits) of a room near `point`, and sets hovered_room to that
## room. 0 if no room edge is near.
func edges_at(point: Vector2) -> int:
	var reach: float = EDGE_PICK_SCREEN_PIXELS / editor.camera.get_zoom_factor()
	for room: Room in editor.get_rooms():
		var rect: Rect2 = room_rect(room)
		if not rect.grow(reach).has_point(point):
			continue
		var edges: int = 0
		if absf(point.x - rect.position.x) <= reach:
			edges |= EDGE_LEFT
		elif absf(point.x - rect.end.x) <= reach:
			edges |= EDGE_RIGHT
		if absf(point.y - rect.position.y) <= reach:
			edges |= EDGE_TOP
		elif absf(point.y - rect.end.y) <= reach:
			edges |= EDGE_BOTTOM
		if edges != 0:
			hovered_room = room
			return edges
	return 0


# --- Snapping (static: the smoke test checks them directly) ---

## A width in whole tiles, at least one screen.
static func snap_width(width: float) -> float:
	return maxf(MIN_ROOM_SIZE.x, roundf(width / TILE) * TILE)


## A height of 180 + whole tiles (see the header).
static func snap_height(height: float) -> float:
	return MIN_ROOM_SIZE.y + maxf(0.0, roundf((height - MIN_ROOM_SIZE.y) / TILE)) * TILE


## The rectangle of a new room dragged from `start` to `end`: snapped sizes,
## growing from `start` toward the mouse, placed like a moved room.
func snap_new_room(start: Vector2, end: Vector2, snap_distance: float) -> Rect2:
	var dragged: Vector2 = end - start
	if dragged.length() < TILE:
		return Rect2(start, Vector2.ZERO)  # not a drag yet
	var size: Vector2 = Vector2(snap_width(absf(dragged.x)), snap_height(absf(dragged.y)))
	var corner: Vector2 = start.snapped(Vector2.ONE * TILE)
	var top_left: Vector2 = Vector2(corner.x if dragged.x >= 0.0 else corner.x - size.x,
		corner.y if dragged.y >= 0.0 else corner.y - size.y)
	return snap_moved(Rect2(top_left, size), null, snap_distance)


## `rect` (a room being moved) with its position on the grid, or on a
## neighbour's edge when one is within `snap_distance`. `ignore`: the moved room.
func snap_moved(rect: Rect2, ignore: Room, snap_distance: float) -> Rect2:
	var snapped_position: Vector2 = rect.position.snapped(Vector2.ONE * TILE)
	var best_x: float = snap_distance
	var best_y: float = snap_distance
	for room: Room in editor.get_rooms():
		if room == ignore:
			continue
		var other: Rect2 = room_rect(room)
		# Side by side (my left on its right...) and lined up (left on left...).
		for x: float in [other.end.x, other.position.x - rect.size.x, other.position.x, other.end.x - rect.size.x]:
			if absf(x - rect.position.x) <= best_x:
				best_x = absf(x - rect.position.x)
				snapped_position.x = x
		for y: float in [other.end.y, other.position.y - rect.size.y, other.position.y, other.end.y - rect.size.y]:
			if absf(y - rect.position.y) <= best_y:
				best_y = absf(y - rect.position.y)
				snapped_position.y = y
	return Rect2(_align_to_side_neighbours(Rect2(snapped_position, rect.size), ignore), rect.size)


## Tile rows line up across a shared side wall (play-test round 4). Heights are
## 180 + whole tiles, so a room under another starts half a tile off the 8 px world
## grid (180 = 22.5 tiles), and a room put beside it on the plain grid had its rows
## 4 px off its neighbour's: walls and exits couldn't meet. So a room touching
## another's left or right edge takes that neighbour's row offset (its y modulo a
## tile); one touching a top or bottom edge takes its column offset. Returns the
## corrected position.
func _align_to_side_neighbours(rect: Rect2, ignore: Room) -> Vector2:
	var aligned: Vector2 = rect.position
	for room: Room in editor.get_rooms():
		if room == ignore:
			continue
		var other: Rect2 = room_rect(room)
		var beside: bool = (is_equal_approx(rect.position.x, other.end.x) or is_equal_approx(rect.end.x, other.position.x)) \
			and rect.position.y < other.end.y and rect.end.y > other.position.y
		var above_or_below: bool = (is_equal_approx(rect.position.y, other.end.y) or is_equal_approx(rect.end.y, other.position.y)) \
			and rect.position.x < other.end.x and rect.end.x > other.position.x
		if beside:
			aligned.y = _snap_to_phase(aligned.y, other.position.y)
		elif above_or_below:
			aligned.x = _snap_to_phase(aligned.x, other.position.x)
	return aligned


## `value` moved to the nearest spot a whole number of tiles from `grid_origin`.
static func _snap_to_phase(value: float, grid_origin: float) -> float:
	return grid_origin + roundf((value - grid_origin) / TILE) * TILE


## `start_rect` with the `edges` dragged to `mouse`: snapped sizes, and a
## neighbour's edge when one is close. A left or top edge moves in whole tiles of
## the room's own grid, so its contents (kept in place) stay on their cells.
func snap_resized(start_rect: Rect2, edges: int, mouse: Vector2, ignore: Room, snap_distance: float) -> Rect2:
	var rect: Rect2 = start_rect
	var neighbour_edges_x: Array[float] = []
	var neighbour_edges_y: Array[float] = []
	for room: Room in editor.get_rooms():
		if room != ignore:
			neighbour_edges_x.append_array([room_rect(room).position.x, room_rect(room).end.x])
			neighbour_edges_y.append_array([room_rect(room).position.y, room_rect(room).end.y])
	if edges & EDGE_RIGHT:
		var width: float = snap_width(mouse.x - rect.position.x)
		rect.size.x = _snap_to_neighbour(rect.position.x + width, neighbour_edges_x, snap_distance,
			func(edge: float) -> bool: return snap_width(edge - rect.position.x) == edge - rect.position.x) - rect.position.x
	elif edges & EDGE_LEFT:
		var right: float = start_rect.end.x
		var left: float = _grow_in_tiles(start_rect.position.x, mouse.x, right - MIN_ROOM_SIZE.x)
		left = _snap_to_neighbour(left, neighbour_edges_x, snap_distance,
			func(edge: float) -> bool: return right - edge >= MIN_ROOM_SIZE.x and is_zero_approx(fmod(edge - start_rect.position.x, TILE)))
		rect = Rect2(left, rect.position.y, right - left, rect.size.y)
	if edges & EDGE_BOTTOM:
		var height: float = snap_height(mouse.y - rect.position.y)
		rect.size.y = _snap_to_neighbour(rect.position.y + height, neighbour_edges_y, snap_distance,
			func(edge: float) -> bool: return snap_height(edge - rect.position.y) == edge - rect.position.y) - rect.position.y
	elif edges & EDGE_TOP:
		var bottom: float = start_rect.end.y
		var top: float = _grow_in_tiles(start_rect.position.y, mouse.y, bottom - MIN_ROOM_SIZE.y)
		top = _snap_to_neighbour(top, neighbour_edges_y, snap_distance,
			func(edge: float) -> bool: return bottom - edge >= MIN_ROOM_SIZE.y and is_zero_approx(fmod(edge - start_rect.position.y, TILE)))
		rect = Rect2(rect.position.x, top, rect.size.x, bottom - top)
	return rect


## A left or top edge moved from `start` toward `mouse` in whole tiles, never
## past `limit` (where the room would get smaller than one screen).
static func _grow_in_tiles(start: float, mouse: float, limit: float) -> float:
	var edge: float = start + roundf((mouse - start) / TILE) * TILE
	while edge > limit:
		edge -= TILE
	return edge


## `edge`, or the nearest neighbour edge within `snap_distance` that `is_allowed`.
static func _snap_to_neighbour(edge: float, neighbour_edges: Array[float], snap_distance: float, is_allowed: Callable) -> float:
	var best: float = edge
	var best_distance: float = snap_distance
	for neighbour_edge: float in neighbour_edges:
		var distance: float = absf(neighbour_edge - edge)
		if distance <= best_distance and is_allowed.call(neighbour_edge):
			best = neighbour_edge
			best_distance = distance
	return best


## True if `rect` overlaps no room (`ignore` aside). Touching edges is fine:
## that's how rooms are meant to sit.
func is_free(rect: Rect2, ignore: Room = null) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	for room: Room in editor.get_rooms():
		# intersects() without borders: rooms sharing an edge don't count.
		if room != ignore and rect.intersects(room_rect(room)):
			return false
	return true


# --- Openings (the green exits) ---

## The openings on every shared edge: [[from, to], ...] line segments in level
## coordinates. An opening is where neither room has solid ground right next to
## the shared edge, so the player can walk (or fall, or fly) from one into the other.
func get_openings() -> Array[Array]:
	var openings: Array[Array] = []
	var rooms: Array[Room] = editor.get_rooms()
	for a_index: int in rooms.size():
		for b_index: int in range(a_index + 1, rooms.size()):
			_add_openings(rooms[a_index], rooms[b_index], openings)
			_add_openings(rooms[b_index], rooms[a_index], openings)
	return openings


## Openings where `first`'s right or bottom edge touches `second`.
func _add_openings(first: Room, second: Room, openings: Array[Array]) -> void:
	var a: Rect2 = room_rect(first)
	var b: Rect2 = room_rect(second)
	var half: float = OPENING_SAMPLE_STEP / 2.0
	if is_equal_approx(a.end.x, b.position.x):
		# Side by side: walk down the shared part of the edge.
		var top: float = maxf(a.position.y, b.position.y)
		var bottom: float = minf(a.end.y, b.end.y)
		_scan_edge(top, bottom, openings, func(y: float) -> bool:
			return not is_solid_at(first, Vector2(a.end.x - half, y)) and not is_solid_at(second, Vector2(a.end.x + half, y)),
			func(along: float) -> Vector2: return Vector2(a.end.x, along))
	if is_equal_approx(a.end.y, b.position.y):
		# One above the other: walk along the shared part of the edge.
		var left: float = maxf(a.position.x, b.position.x)
		var right: float = minf(a.end.x, b.end.x)
		_scan_edge(left, right, openings, func(x: float) -> bool:
			return not is_solid_at(first, Vector2(x, a.end.y - half)) and not is_solid_at(second, Vector2(x, a.end.y + half)),
			func(along: float) -> Vector2: return Vector2(along, a.end.y))


## Samples an edge from `start` to `end` every OPENING_SAMPLE_STEP px and adds a
## segment for each run of open samples. `to_point` turns a distance along the
## edge into a level point.
func _scan_edge(start: float, end: float, openings: Array[Array], is_open_at: Callable, to_point: Callable) -> void:
	var run_start: float = NAN
	var along: float = start
	while along < end:
		var sample_open: bool = is_open_at.call(along + OPENING_SAMPLE_STEP / 2.0)
		if sample_open and is_nan(run_start):
			run_start = along
		elif not sample_open and not is_nan(run_start):
			openings.append([to_point.call(run_start), to_point.call(along)])
			run_start = NAN
		along += OPENING_SAMPLE_STEP
	if not is_nan(run_start):
		openings.append([to_point.call(run_start), to_point.call(minf(along, end))])


## True if `room` has solid ground at `point` (level coordinates): a tile on any
## of its colliding tile layers, or one of an old test room's solid_rects.
static func is_solid_at(room: Room, point: Vector2) -> bool:
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		# A layer without collision (a hidden chamber) is open air.
		if layer == null or layer.tile_set == null or not layer.collision_enabled or layer.tile_set.get_physics_layers_count() == 0:
			continue
		if layer.get_cell_source_id(layer.local_to_map(point - room.position - layer.position)) != -1:
			return true
	for solid: Rect2 in room.solid_rects:
		if solid.has_point(point - room.position):
			return true
	return false


# --- Changing rooms (each one undo step) ---

## Makes an empty room filling `rect` (LevelTemplate). Undoable. Null if it overlaps.
func create_room(rect: Rect2) -> Room:
	if not is_free(rect):
		editor.ui.show_message("Rooms can't overlap.", true)
		return null
	var number: int = editor.get_rooms().size() + 1
	var room: Room = LevelTemplate.build_empty_room("Room%d" % number, "Room %d" % number, rect.size)
	room.position = rect.position
	_add_room_undoable(room, "Make room")
	return room


## Moves `room` to `rect`, or (`is_resize`) changes its size too, keeping its
## contents where they are in the level. Undoable. False if refused (overlap).
func set_room_rect(room: Room, rect: Rect2, is_resize: bool = true) -> bool:
	var old_rect: Rect2 = room_rect(room)
	if rect == old_rect:
		return true
	if not is_free(rect, room):
		editor.ui.show_message("Rooms can't overlap: %s went back." % editor.room_title(room), true)
		return false
	# Resizing from the left or top: the room's origin moves, so its contents move
	# the other way inside it, and stay put in the level.
	var shift: Vector2 = (old_rect.position - rect.position) if is_resize else Vector2.ZERO
	var cells_before: Dictionary = {}
	var cells_after: Dictionary = {}
	if is_resize:
		var cell_shift: Vector2i = Vector2i((shift / TILE).round())
		var cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i((rect.size / TILE).ceil()))
		for layer: TileMapLayer in _owned_layers(room):
			cells_before[layer] = _read_cells(layer)
			var kept: Dictionary = {}
			for cell: Vector2i in cells_before[layer]:
				if cell_bounds.has_point(cell + cell_shift):
					kept[cell + cell_shift] = cells_before[layer][cell]
			cells_after[layer] = kept
	editor.undo_redo.create_action("Resize room" if is_resize else "Move room")
	editor.undo_redo.add_do_method(_apply_room_rect.bind(room, rect, shift, cells_after))
	editor.undo_redo.add_undo_method(_apply_room_rect.bind(room, old_rect, -shift, cells_before))
	editor.undo_redo.commit_action()
	return true


## Puts `room` at `rect`, moves its own objects by `object_shift` and sets its
## layers to `layer_cells` ({layer: {cell: value}}, {} = leave the tiles alone).
func _apply_room_rect(room: Room, rect: Rect2, object_shift: Vector2, layer_cells: Dictionary) -> void:
	room.position = rect.position
	room.room_size = rect.size
	if object_shift != Vector2.ZERO:
		for child: Node in room.get_children():
			# Only the level's own nodes: things rooms build for themselves (the
			# GroundPainter, FireGrid...) sit at the room's origin and stay there.
			if child is Node2D and not child is TileMapLayer and child.owner == editor.level_root:
				LevelEditor.set_on_node(child, &"position", (child as Node2D).position + object_shift)
				PaletteCatalog.sync_start_positions(child as Node2D)
		var shifted_solids: Array[Rect2] = []
		for solid: Rect2 in room.solid_rects:
			shifted_solids.append(Rect2(solid.position + object_shift, solid.size))
		room.solid_rects = shifted_solids
	for layer: TileMapLayer in layer_cells:
		layer.clear()
		for cell: Vector2i in layer_cells[layer]:
			var value: Vector3i = layer_cells[layer][cell]
			layer.set_cell(cell, value.x, Vector2i(value.y, value.z))
	RoomLook.refresh(room)


## Deletes `room` with everything in it. Undoable. Refused (false) for the start
## room and the last room.
func delete_room(room: Room) -> bool:
	if editor.get_rooms().size() <= 1:
		editor.ui.show_message("A level needs at least one room.", true)
		return false
	if room == editor.get_start_room():
		editor.ui.show_message("That's the start room: make another room the start (S) first.", true)
		return false
	var index: int = room.get_index()
	editor.undo_redo.create_action("Delete room %s" % room.name)
	editor.add_unlink_steps(room)  # links from other rooms into this one go too
	editor.undo_redo.add_do_method(_detach_room.bind(room))
	editor.undo_redo.add_undo_method(editor.attach_node.bind(editor.level_root, room, index))
	editor.undo_redo.add_undo_reference(room)
	editor.undo_redo.commit_action()
	return true


func _detach_room(room: Room) -> void:
	if selected_room == room:
		selected_room = null
	if editor.current_room == room:
		editor.current_room = editor.get_start_room()
	editor.detach_node(room)


## Makes `room` the start room: the Player starts at its spawn point. Undoable.
func set_start_room(room: Room) -> void:
	if editor.level_info == null:
		return
	editor.set_property(editor.level_info, &"start_room", room, null, false)
	editor.ui.show_message("%s is the start room." % editor.room_title(room))


func _add_room_undoable(room: Room, action_name: String) -> void:
	editor.undo_redo.create_action(action_name)
	editor.undo_redo.add_do_method(editor.attach_node.bind(editor.level_root, room, -1))
	editor.undo_redo.add_undo_method(_detach_room.bind(room))
	editor.undo_redo.add_do_reference(room)
	editor.undo_redo.commit_action()
	select_room(room)


# --- The right-click menu: copy and paste ---

## The right-click menu for the room under `mouse_world` (or empty space).
func _open_room_menu(mouse_world: Vector2) -> void:
	var room: Room = editor.room_at(mouse_world)
	var rows: Array[String] = []
	var actions: Array[Callable] = []
	if room != null:
		select_room(room)
		rows.append("Copy %s" % editor.room_title(room))
		actions.append(copy_room.bind(room))
	if clipboard != null:
		rows.append("Paste %s" % clipboard_title)
		actions.append(begin_paste)
	if room != null:
		rows.append("Edit room")
		actions.append(close.bind(room))
		rows.append("Make it the start room")
		actions.append(set_start_room.bind(room))
		rows.append("Delete room")
		actions.append(delete_room.bind(room))
	if rows.is_empty():
		editor.ui.show_message("Right-click a room to copy it, then right-click anywhere to paste it.")
		return
	editor.ui.show_menu(rows, editor.get_viewport().get_mouse_position(),
		func(index: int) -> void: actions[index].call())


## Copy: remembers `room` as it is now (see the header).
func copy_room(room: Room) -> void:
	editor._make_level_whole()
	var packed: PackedScene = LevelStorage.pack_level(editor.level_root)
	editor._set_level_aside(true)
	if packed == null:
		editor.ui.show_message("Could not copy %s." % editor.room_title(room), true)
		return
	clipboard = packed
	clipboard_room_name = String(room.name)
	clipboard_title = editor.room_title(room)
	editor.ui.show_message("Copied %s. Right-click and Paste to place a copy." % editor.room_title(room))


## Paste: a new copy of the copied room follows the mouse until a click puts it
## down (place_import), like an imported room. False if nothing is copied.
func begin_paste() -> bool:
	if clipboard == null:
		return false
	cancel_import()
	importing_room = RoomImport.take_room(clipboard.instantiate(), clipboard_room_name)
	if importing_room == null:
		editor.ui.show_message("Could not paste %s." % clipboard_room_name, true)
		return false
	if importing_room.display_title != "":
		importing_room.display_title += " copy"
	preview_rect = Rect2(Vector2.ZERO, importing_room.room_size)
	preview_valid = false
	editor.ui.show_message("Click where the copy goes.  Esc or right-click: cancel.")
	return true


# --- Importing a copy ---

## Starts placing a copy of the room `room_name` of `world_path`: a ghost of it
## follows the mouse until a click puts it down. False if it can't be copied.
func begin_import(world_path: String, room_name: String) -> bool:
	cancel_import()
	importing_room = RoomImport.copy_room(world_path, room_name)
	if importing_room == null:
		editor.ui.show_message("Could not copy %s." % room_name, true)
		return false
	preview_rect = Rect2(Vector2.ZERO, importing_room.room_size)
	preview_valid = false
	editor.ui.show_message("Click where %s goes.  Esc or right-click: cancel." % editor.room_title(importing_room))
	return true


## Puts the room being imported down with its top-left at `position`. Undoable.
## Null if it would overlap (it stays on the mouse, to try elsewhere).
func place_import(position: Vector2) -> Room:
	if importing_room == null:
		return null
	var rect: Rect2 = Rect2(position, importing_room.room_size)
	if not is_free(rect):
		editor.ui.show_message("Rooms can't overlap: pick an empty spot.", true)
		return null
	var room: Room = importing_room
	importing_room = null
	room.position = position
	_add_room_undoable(room, "Import room %s" % room.name)
	editor.ui.show_message("Imported %s: it's this level's own copy now." % editor.room_title(room))
	return room


func cancel_import() -> void:
	if importing_room != null:
		importing_room.free()  # never entered the tree
		importing_room = null


# --- Helpers ---

## The room's tile layers that belong to the level (saved with it).
func _owned_layers(room: Room) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for child: Node in room.get_children():
		if child is TileMapLayer and child.owner == editor.level_root:
			layers.append(child)
	return layers


## Every cell of `layer`: {cell: Vector3i(source, atlas x, atlas y)}.
static func _read_cells(layer: TileMapLayer) -> Dictionary:
	var cells: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		cells[cell] = TileBrush.read_cell(layer, cell)
	return cells
