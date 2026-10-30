class_name LevelEditor
extends Node2D
## LevelEditor: the level editor screen (Level_editor.md §4). Opened from the level
## library with a level's path in `path_to_open`.
##
## Scene layout (built in _ready):
##   LevelEditor (this)
##   ├─ Backdrop         Node2D: dark outside, the game's background color inside rooms
##   ├─ <level root>     the level being edited (see "Showing without running")
##   ├─ EditorOverlay    grid, outlines, spawn points, selection, hover, previews
##   ├─ EditorCamera     pan and zoom
##   └─ EditorUI         panels + the PromptPanel (a CanvasLayer)
## Helpers, each with one job: PaletteCatalog (what can be placed, and how),
## TileBrush (painting + undo records), EditorCamera, EditorOverlay, EditorUI,
## and LevelStorage for the file.
##
## Tools: the palette's chosen entry (`current_entry`) decides what the mouse does.
##   - Terrain (Ground): left paints, right erases, Shift+drag fills a rectangle.
##   - Objects (spawn point, goal, Air objects): left on an object selects and
##     drags it (by whole tiles), left on empty ground places one (its outline
##     snapped to the grid, see PaletteCatalog.placement_position), right deletes.
##     Holding Alt places and drags freely, to the pixel. Ctrl+D copies the
##     selected object to the mouse.
##   - Zones (wind, no-glide: catalog `is_area`) are picked by their outline's
##     edge only, so clicks inside reach whatever sits in them, unless the zone's
##     own tool is chosen (then anywhere inside works).
##   - Eraser (E): click or drag; removes the object under the mouse (zones
##     anywhere inside), or else the tiles of every terrain layer there.
##   - Select: a click selects the object under the mouse and drags it; where
##     several overlap (a crate in a wind zone on a plate), a list (EditorUI.
##     show_menu) asks which one. Empty space selects nothing (the room's settings).
##   - Fill: a click floods the connected area of the same tiles (or of empty air)
##     with the last terrain brush chosen (fill_region); right-click clears it.
##     Choosing a terrain while Fill is on keeps Fill, with that terrain.
##   - H: the quick reference (EditorHelp), every key, read from the InputMap.
##   - Strips (spikes): drag along a row or column; facing comes from the ground
##     next to them; R turns the selected strip.
##   - Link mode (L, Stage L6): with a door (or anything whose catalog entry has a
##     `link_property`) selected, L starts it; clicking a switch links or unlinks
##     it; L or Esc ends it. Links are the door's own `switches` list, node
##     references that the saved scene stores as paths.
##   - Any tool: the selected object's handles (EditorHandles) resize it or move
##     its points. Its settings are in the property panel on the right; with
##     nothing selected, the panel shows the current room's settings (the room
##     last clicked in). Every change there is one undo step.
##   - Map view (M, Stage L7): MapView takes the mouse over: make, move, resize,
##     delete and import rooms, pick the start room, double-click to edit a room.
##     In the room view, rooms other than the current one are drawn dimmed.
## Every change is one UndoRedo action, so Ctrl+Z undoes it.
##
## Earth rooms (Stage L8): a room with an "Earth" layer is drawn by its
## GroundPainter, not by its tiles. After every tile change the editor has
## RoomLook rebuild that picture, so the room looks as it will in play.
## Fire rooms (Stage L9): RoomLook also regrows the plant layers' blades and leaves,
## and takes each room's FireGrid out while editing (it only belongs in play).
##
## Showing without running: the level file is a whole world (RoomManager, Player,
## camera, pause menu...). Added to the tree as is, it would start PLAYING: the
## player falls, and the pause menu (which runs even while paused) grabs Esc.
## So before the level enters the tree, the editor:
##   1. sets aside every child that isn't a Room or LevelInfo (Player, camera,
##      UI), keeping them as loose nodes (they keep their saved settings),
##   2. takes the RoomManager script off the root, remembering its saved values
##      (`player`, `camera`), so RoomManager._ready() never runs,
##   3. disables processing (PROCESS_MODE_DISABLED): no physics, no _process.
## Rooms and their objects still run _ready(), so they look as they do in play.
## Saving (and play-testing) puts all of it back for a moment, packs it, then sets
## it aside again (_make_level_whole / _set_level_aside).
##
## Play-test (Tab, Level_editor.md §8): the level is packed IN MEMORY (no save
## needed) and a fresh copy of it runs next to the editor, at the game's own
## 320x180. The editor hides and waits, keeping its view, selection and undo
## history. The copy's EndScreen is removed (it would reload the current scene,
## which is the editor); reaching the goal instead brings you back here with the
## time and deaths. Tab, or "Back to editor" in the pause menu, also comes back.
##
## Ownership: PackedScene.pack() saves only nodes owned by the level root
## (see LevelStorage). The set-aside nodes drop their owner while they're loose and
## get it back (LevelStorage.adopt) when they're added back before packing.
## Objects added by the editor are adopted the same way.
##
## Undo/redo: Godot's UndoRedo object stores "actions", each a pair of method
## calls or property changes (do + undo). UndoRedo counts a "version" that goes up
## and down with commits, undos and redos; the unsaved dot compares it with the
## version at the last save. A deleted object isn't freed: the action keeps it
## (add_undo_reference) so undo can put the very same node back.
##
## Input: every key and mouse button is an InputMap action named editor_*
## (project.godot). Clicks on panels are eaten by the UI first, so
## _unhandled_input() only sees clicks on the level itself.

## The level the editor opens in _ready(). The library sets it before switching
## scenes: a static var is shared by the class, so it survives the scene change.
static var path_to_open: String = ""

const LEVEL_LIBRARY_SCENE: String = "res://scenes/ui/level_library.tscn"
## The editor draws at 640x360 (twice the game's 320x180), stretched with
## "canvas_items": UI text is drawn at full window resolution, so it's sharp,
## and the camera can zoom the level freely. Play-tests use the game's settings.
const EDITOR_VIEW_SIZE: Vector2i = Vector2i(640, 360)
const TILE: int = 8
const OUTSIDE_COLOR: Color = Color(0.05, 0.05, 0.07)
## Inside rooms: the game's own background color, so the level looks as in play.
const ROOM_BACKGROUND_SETTING: String = "rendering/environment/defaults/default_clear_color"
const PAINT_PREVIEW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const ERASE_PREVIEW_COLOR: Color = Color(1.0, 0.35, 0.3, 0.3)
const STRIP_PREVIEW_COLOR: Color = Color(0.9, 0.2, 0.2, 0.4)
## The Room settings the property panel shows when nothing is selected
## (Level_editor.md §5). The room's size is changed on the map (Stage L7).
const ROOM_SETTINGS: Array[StringName] = [&"display_title", &"air_allowed", &"earth_allowed",
	&"fire_allowed", &"fire_start_pips", &"one_key_column_snake", &"painted_ground"]
## How close to a zone's edge a click must be to pick the zone, screen pixels.
const EDGE_PICK_SCREEN_PIXELS: float = 3.0
## Seconds the play-test keeps running after the goal, so you see you made it.
const GOAL_RETURN_DELAY: float = 0.6
## R turns spikes a quarter turn clockwise: up -> right -> down -> left.
const SPIKE_TURN_ORDER: Array[Spikes.Facing] = [Spikes.Facing.UP, Spikes.Facing.RIGHT, Spikes.Facing.DOWN, Spikes.Facing.LEFT]

## The file being edited.
var level_path: String = ""
## The level's root node, in the tree, without its script (see above).
var level_root: Node2D = null
var level_info: LevelInfo = null
## The root's children that are set aside while editing (Player, camera, UI).
var set_aside_nodes: Array[Node] = []
## The root's script and its saved values, put back for saving.
var level_script: Script = null
var level_script_values: Dictionary = {}
var level_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT

var undo_redo: UndoRedo = UndoRedo.new()
## undo_redo's version at the last save (or at opening): equal = nothing unsaved.
var saved_version: int = 0
## The palette entry the mouse works with.
var current_entry: PaletteCatalog.Entry = null
## The terrain brush chosen last: the room panel's "Fill edges" button uses it.
var last_terrain_entry: PaletteCatalog.Entry = null
## One TileBrush per terrain entry id, made on first use.
var brushes: Dictionary = {}

var camera: EditorCamera
var overlay: EditorOverlay
var ui: EditorUI
var backdrop: Node2D
var grid_visible: bool = true
## The map of rooms (M). While it's open, it gets the mouse and the map keys.
var map_view: MapView = null

## The selected object (outlined; Delete and R act on it), or null. A setter:
## code that runs whenever it's assigned, here to show it in the property panel.
var selected_object: Node2D = null:
	set(value):
		selected_object = value
		_show_selection_in_panel()
## The room last clicked in: its settings show in the panel when nothing is selected.
var current_room: Room = null:
	set(value):
		var changed: bool = value != current_room
		current_room = value
		if changed and selected_object == null:
			_show_selection_in_panel()
## Link mode: the object whose links are being edited (null = not in link mode).
var link_source: Node2D = null
## A handle being dragged ({} = none), and its property's value when the drag began.
var dragged_handle: Dictionary = {}
var dragged_handle_start_value: Variant = null
## The room and tile (room-local cell) under the mouse; null when outside rooms.
var hover_room: Room = null
var hover_cell: Vector2i = Vector2i.ZERO
## The object under the mouse while an object tool is chosen, or null.
var hover_object: Node2D = null
## A preview the overlay draws: the rectangle or spike strip being dragged.
var preview_active: bool = false
var preview_rect: Rect2 = Rect2()
var preview_color: Color = PAINT_PREVIEW_COLOR

## A free-hand terrain stroke: its room and brush, paint or erase, the last cell.
var stroke_room: Room = null
## The brushes the stroke works with: the chosen terrain's, or, for the eraser,
## one per terrain layer the room has.
var stroke_brushes: Array[TileBrush] = []
var stroke_painting: bool = true
## Brushes of the stroke that erase while it paints: the layers a carving terrain
## cuts its shape out of (catalog `carves_layers`, a hidden chamber).
var stroke_carving_brushes: Array[TileBrush] = []
## How many chamber edges touched open air before the stroke (RoomLook): more after
## it, and the status line warns.
var stroke_exposed_edges_before: int = 0
## Room settings the stroke's first paint of a new layer changes:
## {setting: [before, after]} (PaletteCatalog.Entry.room_settings_on_create).
var stroke_room_settings: Dictionary = {}
## The tool to go back to when E switches the eraser off again.
var tool_before_eraser: PaletteCatalog.Entry = null
## True while the eraser is held down and dragged.
var is_erasing: bool = false
var last_stroke_cell: Vector2i = Vector2i.ZERO
## Shift-drag rectangle in progress: its room, start cell, and paint or erase.
var rectangle_active: bool = false
var rectangle_room: Room = null
var rectangle_start_cell: Vector2i = Vector2i.ZERO
var rectangle_painting: bool = true
## The rectangle is the eraser's (Shift+drag): it clears every layer and the
## objects inside, not one terrain.
var rectangle_erases_block: bool = false
## A spike strip being dragged out: its room and first cell.
var strip_active: bool = false
var strip_room: Room = null
var strip_start_cell: Vector2i = Vector2i.ZERO
## An object being dragged: where it and the mouse were when the drag began.
var dragged_object: Node2D = null
var drag_start_position: Vector2 = Vector2.ZERO
var drag_start_mouse: Vector2 = Vector2.ZERO
var is_panning: bool = false

## Play-test state: the running copy of the level, and the warnings found before it.
var is_playtesting: bool = false
var play_root: RoomManager = null
var playtest_warnings: Array[String] = []

## The window's stretch settings before the editor changed them (the game's).
var game_scale_mode: Window.ContentScaleMode
var game_scale_size: Vector2i


func _ready() -> void:
	var window: Window = get_window()
	game_scale_mode = window.content_scale_mode
	game_scale_size = window.content_scale_size
	_use_editor_window(true)

	backdrop = Node2D.new()
	backdrop.name = "Backdrop"
	# The `draw` signal lets another script draw on a node: the callback's
	# draw_* calls must go through that node (backdrop.draw_rect...).
	backdrop.draw.connect(_draw_backdrop)
	add_child(backdrop)
	overlay = EditorOverlay.new()
	overlay.name = "EditorOverlay"
	overlay.editor = self
	add_child(overlay)
	camera = EditorCamera.new()
	camera.name = "EditorCamera"
	add_child(camera)
	ui = EditorUI.new()
	ui.name = "EditorUI"
	add_child(ui)
	ui.entry_chosen.connect(choose_entry)
	ui.property_panel.property_changed.connect(set_property)
	map_view = MapView.new(self)
	ui.import_picker.room_chosen.connect(_on_import_room_chosen)
	# version_changed: UndoRedo's signal for any commit, undo or redo. Values the
	# panel shows may have changed, so it re-reads them.
	undo_redo.version_changed.connect(ui.property_panel.refresh)
	undo_redo.version_changed.connect(_update_link_footer)
	ui.set_zoom(camera.get_zoom_factor())
	choose_entry(PaletteCatalog.get_entry(&"ground"))

	if path_to_open != "":
		open_level(path_to_open)
		path_to_open = ""


## Undoes the window change and frees what the tree doesn't own.
func _exit_tree() -> void:
	if is_playtesting:
		stop_playtest()
	map_view.close()  # also frees a room copy still waiting to be placed
	_use_editor_window(false)
	for node: Node in set_aside_nodes:
		node.free()  # loose nodes: nothing else would ever free them
	set_aside_nodes.clear()
	undo_redo.free()  # UndoRedo is an Object, not reference-counted


func _process(_delta: float) -> void:
	if is_playtesting:
		return
	# The object being linked was deleted (or undone away): leave link mode.
	if link_source != null and (not is_instance_valid(link_source) or not link_source.is_inside_tree()):
		end_link_mode()
	_update_hover()
	_update_preview()
	backdrop.queue_redraw()
	ui.set_dirty(is_dirty())


# --- Opening and saving ---

## Loads the level at `path` and shows it for editing. Returns OK or an error code.
func open_level(path: String) -> Error:
	var packed: PackedScene = LevelStorage.load_level(path)
	if packed == null:
		ui.show_message("Could not load %s" % path, true)
		return ERR_FILE_NOT_FOUND
	level_path = path
	level_root = packed.instantiate() as Node2D
	level_info = level_root.get_node_or_null(NodePath(LevelInfo.NODE_NAME)) as LevelInfo
	level_script = level_root.get_script()
	level_process_mode = level_root.process_mode
	# Remember the script's saved values (RoomManager's `player`, `camera`).
	level_script_values = {}
	for property: Dictionary in level_root.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			level_script_values[property["name"]] = level_root.get(property["name"])
	# Set aside everything that isn't a room or the level's info.
	for child: Node in level_root.get_children():
		if not (child is Room or child is LevelInfo):
			set_aside_nodes.append(child)
	_set_level_aside(false)
	for room: Room in get_rooms():
		RoomLook.prepare_for_editing(room)  # no FireGrid while editing (Stage L9)

	undo_redo.clear_history()
	saved_version = undo_redo.get_version()
	selected_object = null
	ui.set_title(_level_title())
	var start_room: Room = get_start_room()
	current_room = start_room
	if start_room != null:
		fit_view(start_room.get_bounds())
	ui.show_message("Opened %s" % path.get_file())
	return OK


## Zooms the camera to the largest step at which `rect` fits, centered in the free
## space between the palette and the property panel, below the top bar and above
## the status line.
func fit_view(rect: Rect2) -> void:
	var free_size: Vector2 = Vector2(EDITOR_VIEW_SIZE) - Vector2(EditorUI.PALETTE_WIDTH + EditorUI.PROPERTY_PANEL_WIDTH, 2.0 * EditorUI.BAR_HEIGHT)
	camera.zoom_to_fit(rect, free_size, Vector2((EditorUI.PALETTE_WIDTH - EditorUI.PROPERTY_PANEL_WIDTH) / 2.0, 0.0))
	ui.set_zoom(camera.get_zoom_factor())


## Writes the level to its file. Returns OK or an error code.
func save() -> Error:
	_make_level_whole()
	var error: Error = LevelStorage.save_level(level_root, level_path)
	_set_level_aside(true)
	if error == OK:
		saved_version = undo_redo.get_version()
		ui.show_message("Saved %s" % level_path)
	else:
		ui.show_message("Could not save: %s" % error_string(error), true)
	return error


## True if there are changes since the last save.
func is_dirty() -> bool:
	return undo_redo.get_version() != saved_version


## Back to the level library; asks first if there are unsaved changes.
func request_leave() -> void:
	if not is_dirty():
		_leave()
		return
	ui.prompt.ask("This level has unsaved changes.", [
		["Save and leave", func(_text: String) -> void:
			if save() == OK:
				_leave()],
		["Leave without saving", func(_text: String) -> void: _leave()],
	])


func _leave() -> void:
	LevelLibrary.path_to_select = level_path
	get_tree().change_scene_to_file(LEVEL_LIBRARY_SCENE)


## Puts the set-aside nodes and the script back, out of the tree, so the root is
## the complete world again, ready to pack. The set-aside nodes never run.
func _make_level_whole() -> void:
	remove_child(level_root)
	level_root.process_mode = level_process_mode
	level_root.set_script(level_script)
	for property_name: String in level_script_values:
		level_root.set(property_name, level_script_values[property_name])
	for node: Node in set_aside_nodes:
		level_root.add_child(node)
		LevelStorage.adopt(node, level_root)
	_place_player_at_start()


## The opposite of _make_level_whole(): set aside, script off, processing off,
## into the tree, drawn behind the overlay. `was_whole`: the nodes are children now.
func _set_level_aside(was_whole: bool) -> void:
	for node: Node in set_aside_nodes:
		if was_whole or node.get_parent() == level_root:
			level_root.remove_child(node)
		# A loose node may not keep an owner it isn't under (Godot warns when
		# it's added back); _make_level_whole() adopts it again.
		node.owner = null
	level_root.set_script(null)
	level_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(level_root)
	move_child(level_root, backdrop.get_index() + 1)


# --- Rooms and cells ---

## The rooms of the level, in tree order.
func get_rooms() -> Array[Room]:
	var rooms: Array[Room] = []
	if level_root == null:
		return rooms
	for child: Node in level_root.get_children():
		if child is Room:
			rooms.append(child)
	return rooms


## The room whose bounds contain `world_point`, or null.
func room_at(world_point: Vector2) -> Room:
	for room: Room in get_rooms():
		if room.get_bounds().has_point(world_point):
			return room
	return null


## The room-local tile cell that holds `world_point`.
func cell_at(room: Room, world_point: Vector2) -> Vector2i:
	return Vector2i(((world_point - room.global_position) / TILE).floor())


## Every cell inside the room: the room's size in tiles, counting a partly
## covered last row or column (180 px = 22.5 tiles -> 23 rows).
func room_cell_rect(room: Room) -> Rect2i:
	return Rect2i(Vector2i.ZERO, Vector2i((room.room_size / TILE).ceil()))


## Makes `entry` the mouse's tool (the palette calls this).
func choose_entry(entry: PaletteCatalog.Entry) -> void:
	if entry.kind == PaletteCatalog.Kind.ERASER and current_entry != null and current_entry.kind != PaletteCatalog.Kind.ERASER:
		tool_before_eraser = current_entry
	# A terrain picked while Fill is on: Fill stays, and fills with that terrain.
	var keeps_fill: bool = entry.kind == PaletteCatalog.Kind.TERRAIN and current_entry != null \
		and current_entry.kind == PaletteCatalog.Kind.FILL
	if keeps_fill:
		last_terrain_entry = entry
		ui.show_chosen_entry(current_entry, entry)
		ui.show_message("Fill with %s." % entry.display_name)
		return
	current_entry = entry
	ui.show_chosen_entry(entry, _get_fill_terrain() if entry.kind == PaletteCatalog.Kind.FILL else null)
	if entry.hint != "":
		ui.show_message("%s: %s" % [entry.display_name, entry.hint])
	if entry.kind == PaletteCatalog.Kind.TERRAIN and entry != last_terrain_entry:
		last_terrain_entry = entry
		if selected_object == null:
			_show_selection_in_panel()  # the Fill edges button names the terrain


## E: the eraser on, or back off to the tool chosen before it.
func toggle_eraser() -> void:
	if current_entry.kind == PaletteCatalog.Kind.ERASER:
		choose_entry(tool_before_eraser if tool_before_eraser != null else PaletteCatalog.get_entry(&"ground"))
	else:
		choose_entry(PaletteCatalog.get_entry(&"eraser"))


## The eraser at `world_point`: the object there (zones anywhere inside), or
## else the tiles there, on every terrain layer. `is_drag`: part of a drag, where
## the spawn point is skipped quietly instead of saying it can't go.
func erase_at(world_point: Vector2, is_drag: bool = false) -> void:
	var hit: Node2D = object_at(world_point, true)
	if hit != null:
		if PaletteCatalog.entry_for_node(hit).kind == PaletteCatalog.Kind.SPAWN_POINT:
			if not is_drag:
				delete_object(hit)  # refuses, with the message why
			return
		delete_object(hit)
		return
	var room: Room = room_at(world_point)
	if room == null:
		return
	if stroke_room != room:
		end_stroke()
		begin_stroke(room, false, true)
		last_stroke_cell = cell_at(room, world_point)
		_stroke_cell(last_stroke_cell)
	else:
		_continue_stroke(cell_at(room, world_point))


# --- Terrain (also what the smoke test calls) ---

## Paints (or erases) `cells` in `room` with the Ground brush as ONE undo step.
## `terrain`: the brush to use (the current terrain tool if null).
func paint_cells(room: Room, cells: Array[Vector2i], painting: bool, terrain: PaletteCatalog.Entry = null) -> void:
	begin_stroke(room, painting, false, terrain)
	for cell: Vector2i in cells:
		_stroke_cell(cell)
	end_stroke()


## Fills (or clears) the rectangle between two room-local cells as one undo step.
func fill_rectangle(room: Room, corner_a: Vector2i, corner_b: Vector2i, painting: bool) -> void:
	var cells: Array[Vector2i] = []
	var top_left: Vector2i = Vector2i(mini(corner_a.x, corner_b.x), mini(corner_a.y, corner_b.y))
	var bottom_right: Vector2i = Vector2i(maxi(corner_a.x, corner_b.x), maxi(corner_a.y, corner_b.y))
	for y: int in range(top_left.y, bottom_right.y + 1):
		for x: int in range(top_left.x, bottom_right.x + 1):
			cells.append(Vector2i(x, y))
	paint_cells(room, cells, painting)


## Starts a stroke with the current terrain entry's brush (Ground if the current
## tool isn't terrain, e.g. when the smoke test paints). `every_layer` (the
## eraser): erase on every terrain layer the room has, making none.
func begin_stroke(room: Room, painting: bool, every_layer: bool = false, terrain_entry: PaletteCatalog.Entry = null) -> void:
	stroke_room = room
	stroke_painting = painting
	stroke_brushes = []
	stroke_carving_brushes = []
	stroke_room_settings = {}
	stroke_exposed_edges_before = RoomLook.get_exposed_chamber_edges(room).size()
	if every_layer:
		# Two brushes can share a layer (the two Overgrown looks): one brush each.
		var layer_names: Array[StringName] = []
		for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
			if entry.kind != PaletteCatalog.Kind.TERRAIN or layer_names.has(entry.layer_name):
				continue
			layer_names.append(entry.layer_name)
			var brush: TileBrush = _brush_for(entry)
			var layer: TileMapLayer = brush.get_layer(room, level_root, false)
			if layer != null:
				brush.begin_stroke(layer)
				stroke_brushes.append(brush)
		return
	var terrain: PaletteCatalog.Entry = terrain_entry if terrain_entry != null else current_entry
	if terrain == null or terrain.kind != PaletteCatalog.Kind.TERRAIN:
		terrain = PaletteCatalog.get_entry(&"ground")
	var terrain_brush: TileBrush = _brush_for(terrain)
	var had_layer: bool = terrain_brush.get_layer(room, level_root, false) != null
	var terrain_layer: TileMapLayer = terrain_brush.get_layer(room, level_root, true)
	# The room's first stroke of this terrain: the room settings it implies
	# (painting Earth turns Earth on, Stage L8), kept for end_stroke's undo step.
	if not had_layer:
		for setting: StringName in terrain.room_settings_on_create:
			stroke_room_settings[setting] = [room.get(setting), terrain.room_settings_on_create[setting]]
	terrain_brush.begin_stroke(terrain_layer)
	RoomLook.show_tiles_while_painting(room, terrain_layer)
	stroke_brushes.append(terrain_brush)
	# A carving terrain (a hidden chamber) erases the solid layers where it paints.
	if painting:
		for carved_name: StringName in terrain.carves_layers:
			var carved_brush: TileBrush = _brush_for_layer(carved_name)
			var carved_layer: TileMapLayer = carved_brush.get_layer(room, level_root, false) if carved_brush != null else null
			if carved_layer != null:
				carved_brush.begin_stroke(carved_layer)
				stroke_brushes.append(carved_brush)
				stroke_carving_brushes.append(carved_brush)


## Ends the stroke and records it as one undo step (if anything changed).
func end_stroke() -> void:
	if stroke_room == null:
		return
	var room: Room = stroke_room
	var changes: Array[Array] = _finish_stroke()
	if changes.is_empty():
		stroke_room_settings = {}
		RoomLook.refresh(room)  # hides the layer shown while painting again
		return
	undo_redo.create_action("Paint tiles" if stroke_painting else "Erase tiles")
	_add_stroke_steps(room, changes)
	# true: run the "do" now. The cells are already painted (setting them again
	# changes nothing), but the room settings and the room's look need it.
	undo_redo.commit_action(true)
	_warn_if_chamber_exposed(room)


## After a change to `room`'s tiles: if more hidden-chamber edges touch open air
## than before the stroke, the status line says what the red edges mean.
func _warn_if_chamber_exposed(room: Room) -> void:
	if RoomLook.get_exposed_chamber_edges(room).size() > stroke_exposed_edges_before:
		ui.show_message("Red edge: this hidden chamber touches open air there, so its cover is a wall you can walk through before anyone digs. Wall it in, unless that's meant.")


## Ends the stroke's brushes. Returns [brush, layer, {"before", "after"}] for each
## layer it changed (TileBrush.end_stroke).
func _finish_stroke() -> Array[Array]:
	stroke_room = null
	var changes: Array[Array] = []
	for brush: TileBrush in stroke_brushes:
		var layer: TileMapLayer = brush.stroke_layer
		var change: Dictionary = brush.end_stroke()
		if not change.is_empty():
			changes.append([brush, layer, change])
	stroke_brushes = []
	stroke_carving_brushes = []
	return changes


## Inside the undo action being made: the stroke's tile changes (both ways) and
## the room settings its first paint of a new layer implies.
func _add_stroke_steps(room: Room, changes: Array[Array]) -> void:
	for brush_change: Array in changes:
		var brush: TileBrush = brush_change[0]
		undo_redo.add_do_method(_set_layer_cells.bind(brush, brush_change[1], brush_change[2]["after"]))
		undo_redo.add_undo_method(_set_layer_cells.bind(brush, brush_change[1], brush_change[2]["before"]))
	for setting: StringName in stroke_room_settings:
		var values: Array = stroke_room_settings[setting]  # [before, after]
		if values[0] != values[1]:
			undo_redo.add_do_property(room, setting, values[1])
			undo_redo.add_undo_property(room, setting, values[0])
	stroke_room_settings = {}


## The eraser's Shift+drag: clears the block of cells between two room-local cells
## on every terrain layer, and deletes the objects whose outline lies inside it
## (not the spawn point). One undo step.
func erase_block(room: Room, corner_a: Vector2i, corner_b: Vector2i) -> void:
	var cells: Rect2i = _rect_between(corner_a, corner_b)
	begin_stroke(room, false, true)
	for y: int in range(cells.position.y, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			_stroke_cell(Vector2i(x, y))
	var changes: Array[Array] = _finish_stroke()
	var block: Rect2 = Rect2(room.global_position + Vector2(cells.position * TILE), Vector2(cells.size * TILE))
	var doomed: Array[Node2D] = []
	for child: Node in room.get_children():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(child)
		var is_inside: bool = entry != null and block.encloses(PaletteCatalog.get_bounds(child as Node2D))
		if is_inside and entry.kind != PaletteCatalog.Kind.SPAWN_POINT:
			doomed.append(child)
	if changes.is_empty() and doomed.is_empty():
		return
	# Last child first: removing it doesn't shift the indices of the ones before
	# it, and undo (which runs backwards) puts them back first-child first.
	doomed.reverse()
	undo_redo.create_action("Erase block")
	_add_stroke_steps(room, changes)
	for node: Node2D in doomed:
		_add_delete_steps(node)
	undo_redo.commit_action(true)
	_warn_if_chamber_exposed(room)


## The terrain the Fill tool uses: the last terrain brush chosen, else Ground.
func _get_fill_terrain() -> PaletteCatalog.Entry:
	return last_terrain_entry if last_terrain_entry != null else PaletteCatalog.get_entry(&"ground")


## The Fill tool at `start_cell` of `room` (room-local cell), as ONE undo step.
## The area is every cell connected to it (up, down, left, right, inside the room)
## that holds the same terrain layers: the same tiles, or the same empty air.
## `painting`: it becomes the fill terrain (other terrain there is erased);
## else it's cleared. Returns how many cells the area had (0 = nothing changed).
func fill_region(room: Room, start_cell: Vector2i, painting: bool) -> int:
	var bounds: Rect2i = room_cell_rect(room)
	if not bounds.has_point(start_cell):
		return 0
	var terrain: PaletteCatalog.Entry = _get_fill_terrain()
	# Counted now: begin_stroke() below counts again, halfway through the fill.
	var exposed_edges_before: int = RoomLook.get_exposed_chamber_edges(room).size()
	# The room's terrain layers, one per layer name (two brushes share Overgrown's).
	var layers: Array[TileMapLayer] = []
	var layer_brushes: Array[TileBrush] = []
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.kind != PaletteCatalog.Kind.TERRAIN:
			continue
		var brush: TileBrush = _brush_for(entry)
		var layer: TileMapLayer = brush.get_layer(room, level_root, false)
		if layer != null and not layers.has(layer):
			layers.append(layer)
			layer_brushes.append(brush)
	var start_contents: int = _cell_contents(layers, start_cell)
	if not painting and start_contents == 0:
		return 0  # clearing empty air: nothing to do
	# The connected area (breadth-first search over the 4 neighbours).
	var area: Array[Vector2i] = [start_cell]
	var seen: Dictionary = {start_cell: true}
	var next: int = 0
	while next < area.size():
		var cell: Vector2i = area[next]
		next += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbour: Vector2i = cell + step
			if not seen.has(neighbour) and bounds.has_point(neighbour) \
					and _cell_contents(layers, neighbour) == start_contents:
				seen[neighbour] = true
				area.append(neighbour)
	# 1. Erase the other layers in the area (all of them when clearing).
	stroke_room = room
	stroke_painting = false
	stroke_brushes = []
	for layer_index: int in layers.size():
		if painting and layers[layer_index].name == terrain.layer_name:
			continue  # the fill's own layer: painted below, not erased first
		layer_brushes[layer_index].begin_stroke(layers[layer_index])
		stroke_brushes.append(layer_brushes[layer_index])
	for cell: Vector2i in area:
		_stroke_cell(cell)
	var changes: Array[Array] = _finish_stroke()
	# 2. Paint the fill terrain. A different layer than step 1, so the two steps
	# can be undone in any order.
	if painting:
		begin_stroke(room, true, false, terrain)
		for cell: Vector2i in area:
			_stroke_cell(cell)
		changes.append_array(_finish_stroke())
	if changes.is_empty():
		stroke_room_settings = {}
		RoomLook.refresh(room)
		return 0
	undo_redo.create_action("Fill" if painting else "Clear area")
	_add_stroke_steps(room, changes)
	undo_redo.commit_action(true)
	stroke_exposed_edges_before = exposed_edges_before
	_warn_if_chamber_exposed(room)
	return area.size()


## What a cell holds, for fill_region: one bit per layer with a tile there.
func _cell_contents(layers: Array[TileMapLayer], cell: Vector2i) -> int:
	var bits: int = 0
	for layer_index: int in layers.size():
		if layers[layer_index].get_cell_source_id(cell) != -1:
			bits |= 1 << layer_index
	return bits


## Every catalog object under `world_point`, the one drawn on top first. Zones
## count anywhere inside (the Select tool lists them too).
func objects_at(world_point: Vector2) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for object: Node2D in _objects_top_first():
		var outline: Rect2 = PaletteCatalog.get_bounds(object)
		if PaletteCatalog.entry_for_node(object).bounds == PaletteCatalog.Bounds.LINE_TO_POINT:
			outline = outline.grow(1.0)
		if outline.has_point(world_point):
			found.append(object)
	return found


## The Select tool's click: one object there is selected (and can be dragged);
## several open a list to pick from; none selects nothing.
func _select_at(mouse_world: Vector2) -> void:
	var found: Array[Node2D] = objects_at(mouse_world)
	if found.size() == 1:
		select(found[0])
		dragged_object = found[0]
		drag_start_position = found[0].position
		drag_start_mouse = mouse_world
		return
	if found.is_empty():
		select(null)
		return
	var names: Array[String] = []
	for object: Node2D in found:
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(object)
		names.append("%s  (%s)" % [entry.display_name, object.name])
	ui.show_menu(names, get_viewport().get_mouse_position(), _select_from_list.bind(found))


## The Select list's answer: the object at `index` of `found`.
func _select_from_list(index: int, found: Array[Node2D]) -> void:
	if index >= 0 and index < found.size() and is_instance_valid(found[index]) and found[index].is_inside_tree():
		select(found[index])


## Sets cells on a layer (undo and redo of a stroke) and redraws the room's ground.
func _set_layer_cells(brush: TileBrush, layer: TileMapLayer, values: Dictionary) -> void:
	brush.set_cells(layer, values)
	RoomLook.refresh(Room.find_room_of(layer))


## Paints or erases one cell of the current stroke, if it's inside the room.
func _stroke_cell(cell: Vector2i) -> void:
	if not room_cell_rect(stroke_room).has_point(cell):
		return
	for brush: TileBrush in stroke_brushes:
		if stroke_painting and not stroke_carving_brushes.has(brush):
			brush.paint_cell(cell)
		else:
			brush.erase_cell(cell)


func _brush_for(entry: PaletteCatalog.Entry) -> TileBrush:
	if not brushes.has(entry.id):
		brushes[entry.id] = TileBrush.new(entry.layer_name, entry.tile_set, entry.layer_script,
			entry.tile_plain, entry.tile_top_edge, entry.tile_odd_column)
	return brushes[entry.id]


## The brush of the first terrain entry painting the layer named `layer_name` (only
## erasing is asked of it, so which of two brushes sharing a layer doesn't matter).
func _brush_for_layer(layer_name: StringName) -> TileBrush:
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.kind == PaletteCatalog.Kind.TERRAIN and entry.layer_name == layer_name:
			return _brush_for(entry)
	return null


# --- Objects (also what the smoke test calls) ---

## The catalog object under `world_point` (the topmost one), or null.
## Things that sit inside zones come first. A zone (catalog `is_area`) counts
## only near its outline's edge, unless `area_insides` is true (the eraser,
## right-click delete) or its own tool is chosen: then anywhere inside.
func object_at(world_point: Vector2, area_insides: bool = false) -> Node2D:
	var areas: Array[Node2D] = []
	# Lines (vines) come after solid things: a vine's end lies on the plank or crate
	# it holds, and a click there means that. The rest of the vine still picks it.
	var lines: Array[Node2D] = []
	for object: Node2D in _objects_top_first():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(object)
		if entry.is_area:
			areas.append(object)
		elif entry.bounds == PaletteCatalog.Bounds.LINE_TO_POINT:
			lines.append(object)
		elif PaletteCatalog.get_bounds(object).has_point(world_point):
			return object
	for line: Node2D in lines:
		if PaletteCatalog.get_bounds(line).has_point(world_point):
			return line
	# The edge is EDGE_PICK_SCREEN_PIXELS wide on screen, inside and outside the outline.
	var edge: float = EDGE_PICK_SCREEN_PIXELS / camera.get_zoom_factor()
	for area: Node2D in areas:
		var outline: Rect2 = PaletteCatalog.get_bounds(area)
		if not outline.grow(edge).has_point(world_point):
			continue
		var inside_counts: bool = area_insides or PaletteCatalog.entry_for_node(area) == current_entry
		if inside_counts or not outline.grow(-edge).has_point(world_point):
			return area
	return null


## Every catalog object, the one drawn on top first (last room, last child).
func _objects_top_first() -> Array[Node2D]:
	var objects: Array[Node2D] = get_objects()
	objects.reverse()
	return objects


func select(node: Node2D) -> void:
	selected_object = node


## Changes `property` of `target` (an object or a room) to `value`, as one undo
## step. `old_value`: what to undo to, if it already changed (a handle drag).
## Quick changes to the same setting merge into one step (MERGE_ENDS: Godot
## joins actions with the same name made within a moment of each other), so
## scrubbing a number is one Ctrl+Z, not fifty.
func set_property(target: Object, property: StringName, value: Variant, old_value: Variant = null,
		merge: bool = true) -> void:
	var from: Variant = target.get(property) if old_value == null else old_value
	if from == value:
		return
	undo_redo.create_action("Set %s %s" % [_target_name(target), property],
		UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE)
	undo_redo.add_do_method(_apply_property.bind(target, property, value))
	undo_redo.add_undo_method(_apply_property.bind(target, property, from))
	undo_redo.commit_action()


## Sets the property and keeps what depends on it in step: start-up positions
## (a sail's rail ends follow `rail_start`) and the drawing.
func _apply_property(target: Object, property: StringName, value: Variant) -> void:
	# A holder resized or turned keeps its vines tied (not for its link list: linking
	# ties in toggle_link). A vine's own end moved by hand isn't pulled back.
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(target as Node) if target is Node2D else null
	var ties: Array[Array] = []
	if entry != null and entry.tie_kind != PaletteCatalog.TieKind.NONE and property != entry.link_property:
		ties = _capture_ties(target as Node)
	set_on_node(target, property, value)
	_apply_ties(ties)
	# A sentry flipped to the ceiling (or back) moves up to the ceiling above it (or
	# down to the ground below). Undo flips it back and it snaps back down the same way.
	if entry != null and entry.snaps_to_ground and property == entry.hang_property:
		set_on_node(target, &"position", get_grounded_position(target as Node2D, Room.find_room_of(target as Node), true))
	if target is Node2D:
		PaletteCatalog.sync_start_positions(target)
	if target is CanvasItem:
		(target as CanvasItem).queue_redraw()
	if target is Room and property == &"painted_ground":
		RoomLook.refresh(target)  # the painter comes or goes
	# Pips alone do nothing: fire works only where it's allowed (off by default).
	if target is Room and property == &"fire_start_pips" and int(value) > 0 and not (target as Room).fire_allowed:
		ui.show_message("Fire Allowed is off in this room: tick it, or the pips can't be used.", true)


## Shows the selected object's settings in the panel, or the current room's.
func _show_selection_in_panel() -> void:
	if ui == null:
		return
	var selected: Node2D = selected_object
	if selected != null and is_instance_valid(selected):
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(selected)
		var direction_properties: Array[StringName] = []
		if entry.arrow_property != &"":
			direction_properties.append(entry.arrow_property)
		ui.property_panel.show_target(selected, "%s\n%s" % [entry.display_name, selected.name],
			entry.editable_properties, direction_properties, entry.hint)
		if entry.link_property != &"":
			# The same as L: starts link mode, or ends it if it's on.
			ui.property_panel.add_button("Link / unlink (L)", toggle_link_mode)
		_update_link_footer()
	elif current_room != null and is_instance_valid(current_room):
		ui.property_panel.show_target(current_room, "Room\n%s" % room_title(current_room), ROOM_SETTINGS)
		# Walls in the room's edges with the terrain chosen last (Ground at first).
		var terrain: PaletteCatalog.Entry = last_terrain_entry if last_terrain_entry != null else PaletteCatalog.get_entry(&"ground")
		var room: Room = current_room
		ui.property_panel.add_button("Fill edges: %s" % terrain.display_name, func() -> void: fill_room_edges(room, terrain))
	else:
		ui.property_panel.show_target(null, "", [])


## The panel's last line for a linkable object: how many links, and the key.
func _update_link_footer() -> void:
	var selected: Node2D = selected_object
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(selected) if selected != null and is_instance_valid(selected) else null
	if entry == null or entry.link_property == &"":
		ui.property_panel.set_footer("")
		return
	var link_count: int = (selected.get(entry.link_property) as Array).size()
	ui.property_panel.set_footer("Links: %d %s\nL: link / unlink" % [link_count, PaletteCatalog.link_target_name(entry)])


# --- Links (Stage L6) ---

## Starts link mode for `source` (the selected object), if it has links.
## Returns false (with a message) if it can't.
func start_link_mode(source: Node2D) -> bool:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(source) if source != null else null
	if entry == null or entry.link_property == &"":
		ui.show_message("Select something that links first (a door, a hanging platform, a crate, an enemy gate), then L.", true)
		return false
	link_source = source
	ui.set_tool("Linking %s to %s" % [source.name, PaletteCatalog.link_target_name(entry)])
	ui.show_message("Click a %s to link or unlink it.  L or Esc: done." % PaletteCatalog.link_target_name(entry))
	return true


## L, or the panel's Link button: link mode on for the selected object, or off.
func toggle_link_mode() -> void:
	if link_source != null:
		end_link_mode()
	else:
		start_link_mode(selected_object)


func end_link_mode() -> void:
	if link_source == null:
		return
	link_source = null
	ui.show_chosen_entry(current_entry)  # the tool label goes back to the palette's
	ui.show_message("")


## Links `target` to `source` if it isn't yet, else unlinks it. One undo step
## each (never merged). Returns false (with a message) if `target` doesn't fit.
func toggle_link(source: Node2D, target: Node2D) -> bool:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(source)
	if target == source or not PaletteCatalog.is_link_target(entry, target):
		ui.show_message("%s can't be linked to %s: it needs a %s." % [source.name, target.name, PaletteCatalog.link_target_name(entry)], true)
		return false
	# duplicate(): a new list, so undo can put the old one back as it was.
	var old_links: Array = (source.get(entry.link_property) as Array).duplicate()
	var links: Array = old_links.duplicate()
	var was_linked: bool = links.has(target)
	if was_linked:
		links.erase(target)
	else:
		links.append(target)
	var end_property: StringName = _get_tie_end_property(target)
	if entry.tie_kind == PaletteCatalog.TieKind.NONE or end_property == &"":
		set_property(source, entry.link_property, links, null, false)
	else:
		# A holder and its vine: linking ties the vine's end onto it (the nearest
		# spot), unlinking unties it. Both in the one undo step.
		var old_end: Vector2 = target.get(end_property)
		var fraction: float = PaletteCatalog.get_tie_fraction(source, target.global_position + old_end)
		var tie_point: Vector2 = PaletteCatalog.get_tie_point(source, fraction)
		var tie_axis: Vector2 = PaletteCatalog.get_tie_axis(source, fraction)
		var tie: Callable = _tie_vine.bind(target, tie_point, tie_axis, entry.tie_thickness)
		var untie: Callable = _untie_vine.bind(target, old_end)
		undo_redo.create_action("%s %s" % ["Unlink" if was_linked else "Link", target.name], UndoRedo.MERGE_DISABLE)
		undo_redo.add_do_method(_apply_property.bind(source, entry.link_property, links))
		undo_redo.add_do_method(untie if was_linked else tie)
		undo_redo.add_undo_method(_apply_property.bind(source, entry.link_property, old_links))
		undo_redo.add_undo_method(tie if was_linked else untie)
		undo_redo.commit_action()
	ui.show_message("%s %s %s." % ["Unlinked" if was_linked else "Linked", target.name, "from " + String(source.name) if was_linked else "to " + String(source.name)])
	return true


## Every link in the level as [source, target] pairs (the overlay draws them).
## Links to objects that are out of the level (deleted, undone) are skipped.
func get_links() -> Array[Array]:
	var links: Array[Array] = []
	for source: Node2D in get_objects():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(source)
		if entry.link_property == &"":
			continue
		for target: Variant in source.get(entry.link_property):
			if target != null and is_instance_valid(target) and (target as Node).is_inside_tree():
				links.append([source, target])
	return links


## Every catalog object in every room.
func get_objects() -> Array[Node2D]:
	var objects: Array[Node2D] = []
	for room: Room in get_rooms():
		for child: Node in room.get_children():
			if child is Node2D and PaletteCatalog.entry_for_node(child) != null:
				objects.append(child)
	return objects


func _target_name(target: Object) -> String:
	return String((target as Node).name) if target is Node else str(target)


## Places an object of an OBJECT entry on `cell` of `room` (as if clicked in the
## tile's middle). Undoable.
func place_object(entry: PaletteCatalog.Entry, room: Room, cell: Vector2i) -> Node2D:
	return place_object_at(entry, room, Vector2(cell * TILE) + Vector2.ONE * TILE / 2.0)


## Places an object of an OBJECT entry clicked at `room_point` (room-local pixels):
## snapped to the grid, or, with `free`, centered right on the point. Undoable.
func place_object_at(entry: PaletteCatalog.Entry, room: Room, room_point: Vector2, free: bool = false) -> Node2D:
	var node: Node2D = PaletteCatalog.instantiate(entry)
	node.position = PaletteCatalog.placement_position(entry, node, room_point, free)
	node.position = get_grounded_position(node, room)
	_add_object_undoable(room, node, "Place %s" % entry.display_name)
	return node


## Copies `node` (with all its settings) to `room_point` in `room`, placed like a
## new object. Spawn points can't be copied (one per room). Undoable.
func duplicate_object(node: Node2D, room: Room, room_point: Vector2, free: bool = false) -> Node2D:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(node)
	if entry == null or entry.kind == PaletteCatalog.Kind.SPAWN_POINT:
		ui.show_message("A room has one spawn point: it can't be copied.", true)
		return null
	var copy: Node2D = PaletteCatalog.instantiate(entry)
	PaletteCatalog.copy_settings(node, copy)
	copy.position = PaletteCatalog.placement_position(entry, copy, room_point, free)
	copy.position = get_grounded_position(copy, room)
	# Its _ready() runs as it's added, already at its new place, so its start-up
	# positions (PaletteCatalog.sync_start_positions) come out right by themselves.
	_add_object_undoable(room, copy, "Copy %s" % entry.display_name)
	return copy


## Moves the room's spawn point to `cell` (one per room), or makes one if the
## room has none. Undoable.
func place_spawn_point(room: Room, cell: Vector2i) -> Node2D:
	var spawn_point: Marker2D = room.get_node_or_null(NodePath(PaletteCatalog.SPAWN_POINT_NAME)) as Marker2D
	var new_position: Vector2 = PaletteCatalog.spawn_position(cell)
	if spawn_point != null:
		move_object(spawn_point, new_position)
		return spawn_point
	spawn_point = Marker2D.new()
	spawn_point.name = PaletteCatalog.SPAWN_POINT_NAME
	spawn_point.position = new_position
	_add_object_undoable(room, spawn_point, "Place spawn point")
	return spawn_point


## Lays a STRIP entry (spikes) from `start_cell` toward `end_cell`: along the row
## if the drag was more sideways, else along the column. Facing comes from the
## ground next to the first cell. Undoable.
func place_strip(entry: PaletteCatalog.Entry, room: Room, start_cell: Vector2i, end_cell: Vector2i) -> Node2D:
	var cells: Rect2i = _strip_cells(start_cell, end_cell)
	var is_horizontal: bool = cells.size.y == 1  # a single tile counts as a row
	var spikes: Spikes = PaletteCatalog.instantiate(entry) as Spikes
	spikes.position = Vector2(cells.position * TILE)
	spikes.facing = _auto_facing(room, cells.position, is_horizontal)
	spikes.tile_count = maxi(cells.size.x, cells.size.y)
	_add_object_undoable(room, spikes, "Place spikes")
	return spikes


## Catalog `snaps_to_ground`: the position (room-local) at which `node` in `room`
## stands on the first solid tile (any terrain layer) straight below its middle, or,
## with its `hang_property` on, hangs from the first one above. Anything else, or
## nothing solid that way inside the room: its position as it is. `node` may not be
## in the room yet (it's being placed): only its position and outline are used.
## The search starts at its middle; if that's inside a tile (clicked on the floor)
## it first climbs out on the open side. `from_mount`: it was just flipped between
## floor and ceiling, so its origin is still on the old surface: the search starts
## right beside that, toward the new one.
func get_grounded_position(node: Node2D, room: Room, from_mount: bool = false) -> Vector2:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(node)
	if entry == null or not entry.snaps_to_ground or room == null:
		return node.position
	if node is Sentry and not from_mount:
		return _snap_sentry_to_nearest_wall(node as Sentry, room)
	var outline: Rect2 = PaletteCatalog.get_local_bounds(node)
	outline.position += node.position
	var hangs: bool = entry.hang_property != &"" and bool(node.get(entry.hang_property))
	var room_rows: int = room_cell_rect(room).size.y
	var step: int = -1 if hangs else 1
	var cell: Vector2i
	if from_mount:
		cell = Vector2i(((node.position + Vector2(0.0, 0.5 * step)) / TILE).floor())
	else:
		cell = Vector2i((outline.get_center() / TILE).floor())
		cell.y = clampi(cell.y, 0, room_rows - 1)
		while cell.y > 0 and cell.y < room_rows - 1 and _is_solid_cell(room, cell):
			cell.y -= step  # out of the tile, on the side away from the search
	while cell.y >= 0 and cell.y < room_rows:
		if _is_solid_cell(room, cell):
			# Its top meets the tile's bottom (hanging), or its bottom the tile's top.
			if hangs:
				return node.position + Vector2(0.0, (cell.y + 1) * TILE - outline.position.y)
			return node.position + Vector2(0.0, cell.y * TILE - outline.end.y)
		cell.y += step
	return node.position


## A sentry bolts itself to the surface closest to its middle: floor, ceiling or a
## side wall. Every surface on the column and row through its middle is a candidate
## (a free cell next to a solid one); a candidate counts only if the 2x2-tile body
## fits there without overlapping any tile, and the closest one wins (ties: floor,
## ceiling, left wall, right wall). Sets mounted_on_ceiling / wall_side to match and
## returns the position (room-local) that puts the body flush against the surface.
## No candidate fits: it stays as it is.
func _snap_sentry_to_nearest_wall(sentry: Sentry, room: Room) -> Vector2:
	var outline: Rect2 = PaletteCatalog.get_local_bounds(sentry)
	outline.position += sentry.position
	var center: Vector2 = outline.get_center()
	var size: Vector2 = sentry.body_size
	var room_size: Vector2i = room_cell_rect(room).size
	var column: int = clampi(floori(center.x / TILE), 0, room_size.x - 1)
	var row: int = clampi(floori(center.y / TILE), 0, room_size.y - 1)
	var side_y: float = snappedf(center.y, TILE)
	var side_x: float = snappedf(sentry.position.x, TILE)
	# Each candidate: [origin, body rectangle, ceiling?, wall_side].
	var candidates: Array = []
	for y: int in range(1, room_size.y - 1):
		if _is_solid_cell(room, Vector2i(column, y)) and not _is_solid_cell(room, Vector2i(column, y - 1)):
			var floor_origin: Vector2 = Vector2(side_x, y * TILE)
			candidates.append([floor_origin, Rect2(floor_origin + Vector2(-size.x / 2.0, -size.y), size), false, 0])
		if _is_solid_cell(room, Vector2i(column, y - 1)) and not _is_solid_cell(room, Vector2i(column, y)):
			var ceiling_origin: Vector2 = Vector2(side_x, y * TILE)
			candidates.append([ceiling_origin, Rect2(ceiling_origin + Vector2(-size.x / 2.0, 0.0), size), true, 0])
	for x: int in range(1, room_size.x - 1):
		if _is_solid_cell(room, Vector2i(x - 1, row)) and not _is_solid_cell(room, Vector2i(x, row)):
			var left_origin: Vector2 = Vector2(x * TILE, side_y)
			candidates.append([left_origin, Rect2(left_origin + Vector2(0.0, -size.y / 2.0), size), false, -1])
		if _is_solid_cell(room, Vector2i(x, row)) and not _is_solid_cell(room, Vector2i(x - 1, row)):
			var right_origin: Vector2 = Vector2(x * TILE, side_y)
			candidates.append([right_origin, Rect2(right_origin + Vector2(-size.x, -size.y / 2.0), size), false, 1])
	var best: Array = []
	var best_distance: float = INF
	for candidate: Array in candidates:
		var body: Rect2 = candidate[1]
		if not _is_body_free(room, body, room_size):
			continue
		var distance: float = body.get_center().distance_to(center)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	if best.is_empty():
		return sentry.position
	sentry.mounted_on_ceiling = best[2]
	sentry.wall_side = best[3]
	return best[0]


## True if `body` (room-local pixels) lies inside the room and covers no solid cell.
func _is_body_free(room: Room, body: Rect2, room_size: Vector2i) -> bool:
	var first: Vector2i = Vector2i((body.position / TILE).floor())
	var last: Vector2i = Vector2i(((body.end - Vector2.ONE * 0.01) / TILE).floor())
	if first.x < 0 or first.y < 0 or last.x >= room_size.x or last.y >= room_size.y:
		return false
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			if _is_solid_cell(room, Vector2i(x, y)):
				return false
	return true


## True if any terrain layer of `room` has a tile at `cell`.
func _is_solid_cell(room: Room, cell: Vector2i) -> bool:
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer is HiddenLayer:
			continue  # a hidden chamber is open space (a gap in the wall), not a surface
		if layer != null and layer.get_cell_source_id(cell) != -1:
			return true
	return false


## Moves an object to `new_position` (room-local). Undoable.
func move_object(node: Node2D, new_position: Vector2, old_position: Variant = null) -> void:
	var from: Vector2 = node.position if old_position == null else old_position
	if from == new_position:
		return
	undo_redo.create_action("Move %s" % node.name)
	undo_redo.add_do_method(_set_object_position.bind(node, new_position))
	undo_redo.add_undo_method(_set_object_position.bind(node, from))
	undo_redo.commit_action()


## Moves an object and keeps its drawn path / rail with it. A holder's vines stay
## tied to it; a vine that holds something keeps its end on it.
func _set_object_position(node: Node2D, new_position: Vector2) -> void:
	var ties: Array[Array] = _capture_ties(node)
	set_on_node(node, &"position", new_position)
	PaletteCatalog.sync_start_positions(node)
	_apply_ties(ties)


# --- Vines tied to what they hold (catalog `tie_kind`) ---

## The ties to keep through a change of `node`: [holder, vine, fraction] for every
## vine linked to `node` if it's a holder, and for every holder of `node` if it's a
## vine. The fraction is where along the holder the vine's end is now.
func _capture_ties(node: Node) -> Array[Array]:
	var ties: Array[Array] = []
	if not node is Node2D or level_root == null:
		return ties
	for holder: Node2D in get_objects():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(holder)
		if entry.tie_kind == PaletteCatalog.TieKind.NONE:
			continue
		for target: Variant in holder.get(entry.link_property):
			var vine: Node2D = target as Node2D
			if vine == null or not is_instance_valid(vine) or not vine.is_inside_tree() or (holder != node and vine != node):
				continue
			var end_property: StringName = _get_tie_end_property(vine)
			if end_property != &"":
				var end: Vector2 = vine.global_position + (vine.get(end_property) as Vector2)
				ties.append([holder, vine, PaletteCatalog.get_tie_fraction(holder, end)])
	return ties


## Puts every captured vine's end back on its holder, at the same fraction.
func _apply_ties(ties: Array[Array]) -> void:
	for tie: Array in ties:
		var holder: Node2D = tie[0]
		var fraction: float = tie[2]
		_tie_vine(tie[1], PaletteCatalog.get_tie_point(holder, fraction), PaletteCatalog.get_tie_axis(holder, fraction),
			PaletteCatalog.entry_for_node(holder).tie_thickness)


## Moves `vine`'s free end to `world_point` and has it draw its knot there (Vine's
## own tie_to(), what holders call every frame in play).
func _tie_vine(vine: Node2D, world_point: Vector2, axis: Vector2, thickness: float) -> void:
	vine.set(_get_tie_end_property(vine), world_point - vine.global_position)
	if vine.has_method(&"tie_to"):
		vine.call(&"tie_to", world_point, axis, thickness)
	vine.queue_redraw()


## Unlinked: the end goes back to `end` (relative) and the knot goes.
func _untie_vine(vine: Node2D, end: Vector2) -> void:
	if &"is_tied" in vine:
		vine.set(&"is_tied", false)
	vine.set(_get_tie_end_property(vine), end)
	vine.queue_redraw()


## The property that's a link target's free end (its catalog entry's first point
## property, a vine's end_point), or &"" if it has none.
func _get_tie_end_property(target: Node) -> StringName:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(target)
	if entry == null or entry.point_properties.is_empty():
		return &""
	return entry.point_properties[0]


## node.set(property, value), also for a body moved by script (AnimatableBody2D:
## leaf and hanging platforms, the elephant). With `sync_to_physics` on, such a
## body puts its last physics-step transform back when it's moved or turned between
## steps, and the editor's disabled level never steps. So the sync goes off for the
## change, as in ThicketElephant.reset(), and the physics server is told the new
## transform before it comes back on.
static func set_on_node(node: Object, property: StringName, value: Variant) -> void:
	var body: AnimatableBody2D = node as AnimatableBody2D
	if body == null or not body.sync_to_physics:
		node.set(property, value)
		return
	body.sync_to_physics = false
	body.set(property, value)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
	body.sync_to_physics = true


## Deletes an object (undoable). Spawn points can only be moved: every room
## needs one (Room looks it up as $SpawnPoint). Returns false if refused.
func delete_object(node: Node2D) -> bool:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(node)
	if entry == null:
		return false
	if entry.kind == PaletteCatalog.Kind.SPAWN_POINT:
		ui.show_message("Every room needs its spawn point: drag it, or click elsewhere to move it.", true)
		return false
	undo_redo.create_action("Delete %s" % node.name)
	_add_delete_steps(node)
	undo_redo.commit_action()
	return true


## Inside the undo action being made: removes `node` from its room, and undo
## puts the very same node back where it was.
func _add_delete_steps(node: Node) -> void:
	# Anything linked to it loses that link, in the same step (undo restores both).
	add_unlink_steps(node)
	undo_redo.add_do_method(detach_node.bind(node))
	undo_redo.add_undo_method(attach_node.bind(node.get_parent(), node, node.get_index()))
	# The undo side holds the removed node: kept alive while undo may need it,
	# freed by UndoRedo once that can no longer happen.
	undo_redo.add_undo_reference(node)


## The room panel's "Fill edges" button: paints `terrain` along all of the room's
## edges (1-tile walls and ceiling, a 2-row floor; LevelTemplate.get_edge_cells).
## One undo step. Erase the exits you want afterwards.
func fill_room_edges(room: Room, terrain: PaletteCatalog.Entry) -> void:
	paint_cells(room, LevelTemplate.get_edge_cells(room.room_size), true, terrain)
	ui.show_message("Filled the edges of %s with %s." % [room_title(room), terrain.display_name])


## Inside the undo action being made: drops `removed` (an object, or a room and
## everything in it) from every link list that holds it, and undo puts it back.
func add_unlink_steps(removed: Node) -> void:
	for linker: Node2D in get_objects():
		var linker_entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(linker)
		if linker_entry.link_property == &"" or removed.is_ancestor_of(linker):
			continue
		var old_links: Array = linker.get(linker_entry.link_property)
		# Walking the list (not has()): a typed Array[Switch] refuses, with an
		# error, even to be asked whether it holds a non-Switch.
		var new_links: Array = old_links.duplicate()
		for target: Variant in old_links:
			if target == removed or (target is Node and removed.is_ancestor_of(target)):
				new_links.erase(target)
		if new_links.size() != old_links.size():
			undo_redo.add_do_method(_apply_property.bind(linker, linker_entry.link_property, new_links))
			undo_redo.add_undo_method(_apply_property.bind(linker, linker_entry.link_property, old_links.duplicate()))


## R: turns the selected spikes a quarter turn, or an object whose catalog entry
## has `rotate_step_degrees` by that much (a hanging platform). Returns false if
## it can't turn.
func rotate_object(node: Node2D) -> bool:
	var spikes: Spikes = node as Spikes
	if spikes == null:
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(node)
		if entry == null or is_zero_approx(entry.rotate_step_degrees):
			return false
		# wrapf keeps it in -180..180, so turning round and round never grows the number.
		set_property(node, &"rotation_degrees", wrapf(node.rotation_degrees + entry.rotate_step_degrees, -180.0, 180.0), null, false)
		return true
	var next_facing: Spikes.Facing = SPIKE_TURN_ORDER[(SPIKE_TURN_ORDER.find(spikes.facing) + 1) % SPIKE_TURN_ORDER.size()]
	undo_redo.create_action("Turn spikes")
	undo_redo.add_do_property(spikes, &"facing", next_facing)
	undo_redo.add_undo_property(spikes, &"facing", spikes.facing)
	undo_redo.commit_action()
	return true


func undo() -> void:
	# Read the name first: after undo() the "current" action is the one before it.
	var action_name: String = undo_redo.get_current_action_name()
	if undo_redo.undo():
		ui.show_message("Undid: %s" % action_name)


func redo() -> void:
	if undo_redo.redo():
		ui.show_message("Redid: %s" % undo_redo.get_current_action_name())


func toggle_grid() -> void:
	grid_visible = not grid_visible


func _add_object_undoable(room: Room, node: Node2D, action_name: String) -> void:
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(attach_node.bind(room, node, -1))
	undo_redo.add_undo_method(detach_node.bind(node))
	# Room settings the object comes with (a brazier turns Fire on), in the same step.
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(node)
	var room_settings: Dictionary = entry.room_settings_on_create if entry != null else {}
	for setting: StringName in room_settings:
		if room.get(setting) != room_settings[setting]:
			undo_redo.add_do_property(room, setting, room_settings[setting])
			undo_redo.add_undo_property(room, setting, room.get(setting))
	# The do side holds the new node: if the placing is undone and then dropped
	# from the history, UndoRedo frees the node.
	undo_redo.add_do_reference(node)
	undo_redo.commit_action()
	selected_object = node


## Puts `node` into `parent` (at `index`, or last if -1) as part of the saved level.
## The first time, the nodes to save are listed BEFORE it enters the tree: its
## _ready() (or its children's) may build helper nodes (a grass layer's blades, a
## room's FireGrid), and adopting those would save them, and get them built twice
## on the next load. Later times (undo / redo) it keeps the owners it had.
func attach_node(parent: Node, node: Node, index: int) -> void:
	var is_first_time: bool = not node.is_node_ready()
	var nodes_to_save: Array[Node] = []
	if is_first_time:
		nodes_to_save = LevelStorage.nodes_to_adopt(node)
	# true: if the name is taken, Godot picks a readable one ("Goal2").
	parent.add_child(node, true)
	if index >= 0:
		parent.move_child(node, index)
	for saved_node: Node in nodes_to_save:
		saved_node.owner = level_root
	if not is_first_time and node.owner != level_root:
		LevelStorage.adopt(node, level_root)  # ready but never adopted: the old way
	if is_first_time and node is Room:
		RoomLook.prepare_for_editing(node)  # a copied fire room: no FireGrid while editing


func detach_node(node: Node) -> void:
	if selected_object == node:
		selected_object = null  # the setter shows the room's settings instead
	node.get_parent().remove_child(node)


## The cells a strip covers: a 1-tile-thick line from `start_cell` toward `end_cell`.
func _strip_cells(start_cell: Vector2i, end_cell: Vector2i) -> Rect2i:
	var delta: Vector2i = end_cell - start_cell
	if absi(delta.x) >= absi(delta.y):
		return Rect2i(Vector2i(mini(start_cell.x, end_cell.x), start_cell.y), Vector2i(absi(delta.x) + 1, 1))
	return Rect2i(Vector2i(start_cell.x, mini(start_cell.y, end_cell.y)), Vector2i(1, absi(delta.y) + 1))


## Which way spikes on `cell` should point: away from the ground they're stuck to.
## Along a row: floor below -> up, ceiling above -> down. Along a column: wall on
## the left -> right, wall on the right -> left.
func _auto_facing(room: Room, cell: Vector2i, is_horizontal: bool) -> Spikes.Facing:
	var ground: TileMapLayer = room.get_node_or_null(NodePath(PaletteCatalog.get_entry(&"ground").layer_name)) as TileMapLayer
	var is_solid: Callable = func(at: Vector2i) -> bool:
		return ground != null and ground.get_cell_source_id(at) != -1
	if is_horizontal:
		if not is_solid.call(cell + Vector2i.DOWN) and is_solid.call(cell + Vector2i.UP):
			return Spikes.Facing.DOWN
		return Spikes.Facing.UP
	if not is_solid.call(cell + Vector2i.LEFT) and is_solid.call(cell + Vector2i.RIGHT):
		return Spikes.Facing.LEFT
	return Spikes.Facing.RIGHT


# --- Map of rooms (Stage L7) ---

## M: the map view on or off. Anything half-done in the room view ends first.
func toggle_map() -> void:
	if map_view.is_open:
		map_view.close()
		ui.show_chosen_entry(current_entry)  # the tool label and key hints come back
		return
	end_link_mode()
	end_stroke()
	dragged_object = null
	dragged_handle = {}
	select(null)
	map_view.open()
	ui.set_tool("Map")
	ui.set_key_hints(EditorUI.MAP_HINTS)


## The import list picked a room: it follows the mouse on the map until a click.
func _on_import_room_chosen(world_path: String, room_name: String) -> void:
	if not map_view.is_open:
		toggle_map()
	map_view.begin_import(world_path, room_name)


# --- Play-test ---

## Plays the level from the start room, or, with `start_point` (a level point),
## from there. Returns false (with a message) if it can't start.
func start_playtest(start_point: Variant = null) -> bool:
	var blocker: String = get_play_blocker(start_point)
	if blocker != "":
		ui.show_message(blocker, true)
		return false
	playtest_warnings = get_play_warnings()
	_make_level_whole()
	var packed: PackedScene = LevelStorage.pack_level(level_root)
	_set_level_aside(true)
	if packed == null:
		ui.show_message("Could not pack the level to play it.", true)
		return false

	play_root = packed.instantiate() as RoomManager
	# The end screen would reload the current scene (the editor!): remove it.
	var end_screen: Node = play_root.get_node_or_null("EndScreen")
	if end_screen != null:
		play_root.remove_child(end_screen)
		end_screen.free()
	var pause_menu: PauseMenu = play_root.get_node_or_null("PauseMenu") as PauseMenu
	if pause_menu != null:
		pause_menu.back_to_editor = stop_playtest  # set before _ready builds its buttons
	if start_point != null:
		play_root.player.position = start_point

	GameState.reset_run()
	_use_editor_window(false)
	# The editor's own copy leaves the tree while the play copy runs. Hidden is not
	# enough: lookups by GROUP (EarthLayer.find_layer_at, room resets, enemies...)
	# go through every node in the tree, and would find the editor's earth tiles,
	# lying at the same place as the play copy's, first. Nodes out of the tree
	# aren't listed in their groups.
	# Deferred: calls the editor's rooms already queued with call_deferred (a
	# PebbleField looking for wind zones, a room just imported) run first, while
	# they're still in the tree. Deferred calls run in the order they were made.
	_take_level_out_while_playing.call_deferred()
	visible = false  # hides the backdrop and overlay (all Node2D children)
	ui.visible = false  # a CanvasLayer has its own visibility
	# Next to the editor, not inside it: the editor's level is disabled, and the
	# copy must run normally.
	get_tree().root.add_child(play_root)
	play_root.camera.make_current()
	GameState.run_finished.connect(_on_playtest_goal_reached)
	is_playtesting = true
	return true


## See start_playtest. Skipped if the play-test already ended meanwhile.
func _take_level_out_while_playing() -> void:
	if is_playtesting and level_root.get_parent() == self:
		remove_child(level_root)


## Ends the play-test and shows the editor again, as it was.
func stop_playtest() -> void:
	if not is_playtesting:
		return
	is_playtesting = false
	if GameState.run_finished.is_connected(_on_playtest_goal_reached):
		GameState.run_finished.disconnect(_on_playtest_goal_reached)
	# The pause, freeze and slow motion are global: switch them all off.
	FX.set_menu_pause(false)
	FX.clear_slow_motion()
	play_root.queue_free()
	play_root = null
	if level_root.get_parent() == null:
		add_child(level_root)  # back, behind the overlay (see start_playtest)
		move_child(level_root, backdrop.get_index() + 1)
	_use_editor_window(true)
	visible = true
	ui.visible = true
	camera.make_current()
	if not playtest_warnings.is_empty():
		ui.show_message("Note: " + "  ".join(playtest_warnings), true)


## Why the level can't be played from there, or "" if it can. A room you start or
## respawn in must have a spawn point.
func get_play_blocker(start_point: Variant = null) -> String:
	var room: Room = get_start_room() if start_point == null else room_at(start_point)
	if room == null:
		return "The level has no rooms." if start_point == null else "Play here: point the mouse inside a room."
	if room.get_node_or_null(NodePath(PaletteCatalog.SPAWN_POINT_NAME)) == null:
		return "%s has no spawn point: place one first." % room_title(room)
	return ""


## Things worth knowing before playing, which don't stop it.
func get_play_warnings() -> Array[String]:
	var warnings: Array[String] = []
	var has_goal: bool = false
	for room: Room in get_rooms():
		if room.get_node_or_null(NodePath(PaletteCatalog.SPAWN_POINT_NAME)) == null:
			warnings.append("%s has no spawn point." % room_title(room))
		var has_fire_diamond: bool = false
		for child: Node in room.get_children():
			if child is Goal:
				has_goal = true
			if child is FireDiamond:
				has_fire_diamond = true
		# Fire objects turn Fire on, but without pips the player can't light anything.
		if room.fire_allowed and room.fire_start_pips == 0 and not has_fire_diamond:
			warnings.append("%s allows Fire but has no fire pips (set Fire Start Pips, or place a fire diamond)." % room_title(room))
	if not has_goal:
		warnings.append("No goal yet: the level can't be finished.")
	return warnings


func _on_playtest_goal_reached() -> void:
	var summary: String = "Goal reached: %s, %d deaths." % [GameState.get_formatted_time(), GameState.death_count]
	await get_tree().create_timer(GOAL_RETURN_DELAY).timeout
	if not is_playtesting:
		return
	stop_playtest()
	ui.show_message(summary)


## true: the editor's 640x360 canvas_items view. false: the game's own settings.
func _use_editor_window(use_editor: bool) -> void:
	var window: Window = get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if use_editor else game_scale_mode
	window.content_scale_size = EDITOR_VIEW_SIZE if use_editor else game_scale_size


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	# Fetched first, while this node is surely in the tree: Esc can leave the editor
	# (change_scene_to_file takes the editor out of the tree AT ONCE, and frees it
	# at the end of the frame), and get_viewport() would then return null.
	var viewport: Viewport = get_viewport()
	if is_playtesting:
		# Only Tab (with or without Shift) matters: back to the editor.
		if event.is_action_pressed("editor_playtest") or event.is_action_pressed("editor_playtest_here"):
			stop_playtest()
			viewport.set_input_as_handled()
		return
	if level_root == null or ui.prompt.visible or ui.help.visible or ui.import_picker.visible:
		return  # those handle their own keys (H and Esc close the help)
	var mouse_world: Vector2 = get_global_mouse_position()

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if is_panning:
			camera.pan_by(motion.relative)
		elif map_view.is_open:
			map_view.mouse_moved(mouse_world)
		elif is_erasing:
			erase_at(mouse_world, true)
		elif stroke_room != null:
			_continue_stroke(cell_at(stroke_room, mouse_world))
		elif not dragged_handle.is_empty():
			var value: Variant = EditorHandles.value_for_drag(selected_object, dragged_handle, mouse_world,
				Input.is_action_pressed("editor_free_place"))
			_apply_property(selected_object, dragged_handle["property"], value)
			ui.property_panel.refresh()
		elif dragged_object != null:
			# Moves by whole tiles, so a grid-aligned object stays on the grid;
			# with Alt held, by the exact pixels the mouse moved.
			var moved: Vector2 = mouse_world - drag_start_mouse
			if not Input.is_action_pressed("editor_free_place"):
				moved = (moved / TILE).round() * TILE
			_set_object_position(dragged_object, drag_start_position + moved)
		return

	if event.is_action_pressed("editor_zoom_in") or event.is_action_pressed("editor_zoom_out"):
		var steps: int = 1 if event.is_action_pressed("editor_zoom_in") else -1
		camera.zoom_by(steps, get_viewport().get_mouse_position())
		ui.set_zoom(camera.get_zoom_factor())
	# Pan: middle drag, or Space + left drag.
	elif event.is_action_pressed("editor_pan") or (event.is_action_pressed("editor_paint") and Input.is_action_pressed("editor_pan_hold")):
		is_panning = true
	elif is_panning and (event.is_action_released("editor_pan") or event.is_action_released("editor_paint")):
		is_panning = false
	elif event.is_action_pressed("editor_map"):
		toggle_map()
	# The map takes its own clicks and keys (its handle_input says if it used this one).
	elif map_view.is_open and map_view.handle_input(event, mouse_world):
		pass
	elif event.is_action_pressed("editor_paint"):
		_on_left_pressed(mouse_world)
	elif event.is_action_pressed("editor_erase"):
		_on_right_pressed(mouse_world)
	elif event.is_action_released("editor_paint") or event.is_action_released("editor_erase"):
		_on_mouse_released(mouse_world)
	# Shift+Tab before Tab: plain Tab's action would also match with Shift held.
	elif event.is_action_pressed("editor_playtest_here"):
		end_link_mode()
		start_playtest(mouse_world)
	elif event.is_action_pressed("editor_playtest"):
		end_link_mode()
		start_playtest()
	elif event.is_action_pressed("editor_eraser"):
		end_link_mode()
		toggle_eraser()
	elif event.is_action_pressed("editor_help"):
		ui.help.open()
	elif event.is_action_pressed("editor_import"):
		# Imports happen on the map, where you see where the copy fits.
		toggle_map()
		ui.import_picker.open(level_path)
	elif event.is_action_pressed("editor_link"):
		toggle_link_mode()
	# Redo before undo: Ctrl+Shift+Z is redo, and would also match plain Ctrl+Z.
	elif event.is_action_pressed("editor_redo"):
		redo()
	elif event.is_action_pressed("editor_undo", false, true):  # exact: no Shift
		undo()
	elif event.is_action_pressed("editor_save"):
		save()
	elif event.is_action_pressed("editor_delete"):
		if selected_object != null:
			delete_object(selected_object)
	elif event.is_action_pressed("editor_duplicate"):
		_duplicate_selected(mouse_world)
	elif event.is_action_pressed("editor_rotate"):
		if selected_object != null and not rotate_object(selected_object):
			ui.show_message("Only spikes and hanging platforms can be turned.", true)
	elif event.is_action_pressed("editor_toggle_grid"):
		toggle_grid()
	elif event.is_action_pressed("editor_back"):
		if link_source != null:
			end_link_mode()  # Esc first leaves link mode, then the editor
		else:
			request_leave()
	else:
		return
	viewport.set_input_as_handled()


func _on_left_pressed(mouse_world: Vector2) -> void:
	# A click on the level ends typing in a panel field (and applies it).
	get_viewport().gui_release_focus()
	if link_source != null:
		# Link mode: a click only links or unlinks what's under the mouse.
		var target: Node2D = object_at(mouse_world)
		if target != null and target != link_source:
			toggle_link(link_source, target)
		return
	var room: Room = room_at(mouse_world)
	if room != null:
		current_room = room
	if current_entry.kind == PaletteCatalog.Kind.ERASER:
		_start_erasing(room, mouse_world)
		return
	if current_entry.kind == PaletteCatalog.Kind.FILL:
		if room != null and fill_region(room, cell_at(room, mouse_world), true) == 0:
			ui.show_message("Already %s there." % _get_fill_terrain().display_name)
		return
	# The selected object's handles come first: they can sit on top of anything.
	if selected_object != null and is_instance_valid(selected_object) and selected_object.is_inside_tree():
		var handle: Dictionary = EditorHandles.handle_at(selected_object, mouse_world, camera.get_zoom_factor())
		if not handle.is_empty():
			dragged_handle = handle
			dragged_handle_start_value = selected_object.get(handle["property"])
			return
	if current_entry.kind == PaletteCatalog.Kind.TERRAIN:
		if room != null:
			_start_terrain(room, mouse_world, true)
		return
	if current_entry.kind == PaletteCatalog.Kind.SELECT:
		_select_at(mouse_world)
		return
	# Object tools: an object under the mouse is picked up, else a new one is placed.
	var hit: Node2D = object_at(mouse_world)
	if hit != null:
		select(hit)
		dragged_object = hit
		drag_start_position = hit.position
		drag_start_mouse = mouse_world
		return
	if room == null:
		select(null)
		return
	var cell: Vector2i = cell_at(room, mouse_world)
	match current_entry.kind:
		PaletteCatalog.Kind.SPAWN_POINT:
			select(place_spawn_point(room, cell))
		PaletteCatalog.Kind.OBJECT:
			place_object_at(current_entry, room, mouse_world - room.global_position,
				Input.is_action_pressed("editor_free_place"))
		PaletteCatalog.Kind.STRIP:
			strip_active = true
			strip_room = room
			strip_start_cell = cell


func _on_right_pressed(mouse_world: Vector2) -> void:
	get_viewport().gui_release_focus()
	if current_entry.kind == PaletteCatalog.Kind.ERASER:
		_start_erasing(room_at(mouse_world), mouse_world)
		return
	if current_entry.kind == PaletteCatalog.Kind.FILL:
		var fill_room: Room = room_at(mouse_world)
		if fill_room != null:
			fill_region(fill_room, cell_at(fill_room, mouse_world), false)
		return
	if current_entry.kind == PaletteCatalog.Kind.SELECT:
		return  # right-click does nothing with Select (it never deletes by surprise)
	if current_entry.kind == PaletteCatalog.Kind.TERRAIN:
		var room: Room = room_at(mouse_world)
		if room != null:
			_start_terrain(room, mouse_world, false)
		return
	var hit: Node2D = object_at(mouse_world, true)  # right-click deletes a zone from inside too
	if hit != null:
		delete_object(hit)


func _on_mouse_released(mouse_world: Vector2) -> void:
	if is_erasing:
		is_erasing = false
		end_stroke()
	elif not dragged_handle.is_empty():
		# The drag already changed it live; record the whole drag as one step.
		var property: StringName = dragged_handle["property"]
		dragged_handle = {}
		set_property(selected_object, property, selected_object.get(property), dragged_handle_start_value)
	elif rectangle_active:
		rectangle_active = false
		if rectangle_erases_block:
			erase_block(rectangle_room, rectangle_start_cell, cell_at(rectangle_room, mouse_world))
		else:
			fill_rectangle(rectangle_room, rectangle_start_cell, cell_at(rectangle_room, mouse_world), rectangle_painting)
	elif stroke_room != null:
		end_stroke()
	elif strip_active:
		strip_active = false
		place_strip(current_entry, strip_room, strip_start_cell, cell_at(strip_room, mouse_world))
	elif dragged_object != null:
		# The drag already moved it; record the move (from the start) as one step.
		# Things bolted down (a sentry) drop onto the ground under where it was let go.
		var moved_object: Node2D = dragged_object
		dragged_object = null
		move_object(moved_object, get_grounded_position(moved_object, Room.find_room_of(moved_object)), drag_start_position)


## Ctrl+D: copies the selected object to the mouse, or, with the mouse outside
## every room, one tile right of the original.
func _duplicate_selected(mouse_world: Vector2) -> void:
	if selected_object == null:
		ui.show_message("Select an object first, then Ctrl+D copies it to the mouse.", true)
		return
	var room: Room = room_at(mouse_world)
	var room_point: Vector2
	if room != null:
		room_point = mouse_world - room.global_position
	else:
		room = Room.find_room_of(selected_object)
		room_point = PaletteCatalog.get_bounds(selected_object).get_center() + Vector2(TILE, 0) - room.global_position
	duplicate_object(selected_object, room, room_point, Input.is_action_pressed("editor_free_place"))


## An eraser press: with Shift held, a block (erase_block on release), else
## erasing what's under the mouse as it drags.
func _start_erasing(room: Room, mouse_world: Vector2) -> void:
	if Input.is_action_pressed("editor_rectangle") and room != null:
		_start_rectangle(room, mouse_world, false, true)
		return
	is_erasing = true
	erase_at(mouse_world)


## A terrain press: a rectangle with Shift held, else a free-hand stroke.
func _start_terrain(room: Room, mouse_world: Vector2, painting: bool) -> void:
	if Input.is_action_pressed("editor_rectangle"):
		_start_rectangle(room, mouse_world, painting, false)
	else:
		begin_stroke(room, painting)
		last_stroke_cell = cell_at(room, mouse_world)
		_stroke_cell(last_stroke_cell)


## Starts a Shift-drag rectangle in `room` from the mouse's cell.
func _start_rectangle(room: Room, mouse_world: Vector2, painting: bool, erases_block: bool) -> void:
	rectangle_active = true
	rectangle_room = room
	rectangle_start_cell = cell_at(room, mouse_world)
	rectangle_painting = painting
	rectangle_erases_block = erases_block


## Paints every cell on the line from the last cell to `cell`: a fast mouse
## skips cells between two motion events, and this fills the gap.
func _continue_stroke(cell: Vector2i) -> void:
	var steps: int = maxi(absi(cell.x - last_stroke_cell.x), absi(cell.y - last_stroke_cell.y))
	for step: int in range(1, steps + 1):
		var point: Vector2 = Vector2(last_stroke_cell).lerp(Vector2(cell), float(step) / steps)
		_stroke_cell(Vector2i(point.round()))
	last_stroke_cell = cell


## What the overlay previews this frame: the rectangle or spike strip being dragged.
func _update_preview() -> void:
	preview_active = rectangle_active or strip_active
	if rectangle_active:
		preview_rect = _cells_to_world(rectangle_room, _rect_between(rectangle_start_cell, cell_at(rectangle_room, get_global_mouse_position())))
		preview_color = PAINT_PREVIEW_COLOR if rectangle_painting else ERASE_PREVIEW_COLOR
	elif strip_active:
		preview_rect = _cells_to_world(strip_room, _strip_cells(strip_start_cell, cell_at(strip_room, get_global_mouse_position())))
		preview_color = STRIP_PREVIEW_COLOR


func _update_hover() -> void:
	hover_room = null
	hover_object = null
	if level_root == null or ui.is_over_panels(get_viewport().get_mouse_position()):
		ui.set_cursor_info("")
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	if map_view.is_open:
		# The map shows rooms, not tiles: the room under the mouse and its size.
		var room: Room = room_at(mouse_world)
		ui.set_cursor_info("" if room == null else "%s  %dx%d" % [room_title(room), room.room_size.x, room.room_size.y])
		return
	if link_source != null or (current_entry != null and current_entry.kind != PaletteCatalog.Kind.TERRAIN
			and current_entry.kind != PaletteCatalog.Kind.FILL):
		hover_object = object_at(mouse_world, current_entry.kind == PaletteCatalog.Kind.ERASER)
	hover_room = room_at(mouse_world)
	if hover_room == null:
		ui.set_cursor_info("")
		return
	hover_cell = cell_at(hover_room, mouse_world)
	var info: String = "%s  tile %d, %d" % [room_title(hover_room), hover_cell.x, hover_cell.y]
	if hover_object != null:
		info += "  " + String(hover_object.name)
	ui.set_cursor_info(info)


# --- Helpers ---

func _rect_between(corner_a: Vector2i, corner_b: Vector2i) -> Rect2i:
	var top_left: Vector2i = Vector2i(mini(corner_a.x, corner_b.x), mini(corner_a.y, corner_b.y))
	return Rect2i(top_left, (corner_a - corner_b).abs() + Vector2i.ONE)


## Room-local cells -> a level rectangle, cut to the room.
func _cells_to_world(room: Room, cells: Rect2i) -> Rect2:
	var rect: Rect2 = Rect2(room.global_position + Vector2(cells.position * TILE), Vector2(cells.size * TILE))
	return rect.intersection(room.get_bounds())


func _draw_backdrop() -> void:
	var visible_world: Rect2 = _visible_world_rect()
	backdrop.draw_rect(visible_world, OUTSIDE_COLOR)
	var room_color: Color = ProjectSettings.get_setting(ROOM_BACKGROUND_SETTING, Color(0.3, 0.3, 0.3))
	for room: Room in get_rooms():
		backdrop.draw_rect(room.get_bounds(), room_color)


## The part of the level the camera shows right now.
func _visible_world_rect() -> Rect2:
	var view_size: Vector2 = get_viewport_rect().size / camera.get_zoom_factor()
	return Rect2(camera.position - view_size / 2.0, view_size)


func _level_title() -> String:
	if level_info != null and level_info.level_title != "":
		return level_info.level_title
	return level_path.get_file().get_basename()


func room_title(room: Room) -> String:
	return room.display_title if room.display_title != "" else String(room.name)


## The room the level starts in: LevelInfo's start room, else the first room.
func get_start_room() -> Room:
	if level_info != null and level_info.start_room != null:
		return level_info.start_room
	var rooms: Array[Room] = get_rooms()
	return rooms[0] if not rooms.is_empty() else null


## The level starts with the Player on the start room's SpawnPoint.
func _place_player_at_start() -> void:
	var player: Node2D = level_script_values.get("player") as Node2D
	var start_room: Room = get_start_room()
	if player == null or start_room == null:
		return
	var spawn_point: Marker2D = start_room.get_node_or_null(NodePath(PaletteCatalog.SPAWN_POINT_NAME)) as Marker2D
	if spawn_point != null:
		player.position = start_room.position + spawn_point.position
