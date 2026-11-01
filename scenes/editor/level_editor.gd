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
##     [ and ] size the free-hand brush. Strokes and rectangles carry on into the
##     rooms next door (each tile goes to the room it lies in; one undo step); the
##     Fill tool stays in its room.
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
##     Shift+click: every matching cell of the room, connected or not.
##   - Brush (B): back to painting with the last terrain. P: eyedropper (pick_at).
##     Ctrl+F searches the palette; 1-9 choose the quick bar's recent things.
##   - Select + Shift+drag marks a region; Ctrl+C / Ctrl+X / Ctrl+V (+Shift:
##     mirrored) copy, cut and paste it through EditorClipboard (begin_paste,
##     paste_tile, finish_paste: one undo step).
##   - Play-tests leave a trail and death markers (PlaytestRecord, T / Ctrl+T) and
##     get cheats (PlaytestCheats). Hold J: the jump's reach (JumpReach, drawn
##     by EditorOverlay).
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
	&"fire_allowed", &"fire_start_pips", &"one_key_column_snake", &"painted_ground", &"backdrop_theme",
	&"backdrop_altitude", &"back_room"]
## How close to a zone's edge a click must be to pick the zone, screen pixels.
const EDGE_PICK_SCREEN_PIXELS: float = 3.0
## Seconds the play-test keeps running after the goal, so you see you made it.
const GOAL_RETURN_DELAY: float = 0.6
## R turns spikes a quarter turn clockwise: up -> right -> down -> left.
const SPIKE_TURN_ORDER: Array[Spikes.Facing] = [Spikes.Facing.UP, Spikes.Facing.RIGHT, Spikes.Facing.DOWN, Spikes.Facing.LEFT]


## One room's share of a terrain stroke (see stroke_parts): which brushes paint
## or erase there. The brushes themselves live in stroke_layer_brushes.
class StrokePart:
	var room: Room
	## The chosen terrain's brush (and those of the layers it carves), or, for the
	## eraser, one per terrain layer the room has.
	var brushes: Array[TileBrush] = []
	## Brushes that erase while the stroke paints: the layers a carving terrain
	## cuts its shape out of (catalog `carves_layers`, a hidden chamber).
	var carving_brushes: Array[TileBrush] = []

	func _init(new_room: Room) -> void:
		room = new_room

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
## Width and height, in tiles, of the free-hand terrain / eraser brush ([ and ]).
const MAX_BRUSH_SIZE: int = 8
var brush_size: int = 1
## The object under the mouse while an object tool is chosen, or null.
var hover_object: Node2D = null
## A preview the overlay draws: the rectangle or spike strip being dragged.
var preview_active: bool = false
var preview_rect: Rect2 = Rect2()
var preview_color: Color = PAINT_PREVIEW_COLOR

## A terrain stroke (free-hand, rectangle, fill). It can cross into the rooms next
## door: each room it reaches gets a StrokePart, and end_stroke makes ONE undo step.
## stroke_room: the room it began in (null = no stroke going); room-local cells
## (_stroke_cell) and a brush outside every room use its tile grid.
var stroke_room: Room = null
## {Room: StrokePart}, made as the stroke reaches each room (_stroke_part).
var stroke_parts: Dictionary = {}
## {TileMapLayer: TileBrush}: one brush per layer the stroke touches, in any room
## (also a room below whose top edge changed), so each cell's undo is recorded once.
var stroke_layer_brushes: Dictionary = {}
var stroke_painting: bool = true
## The eraser's stroke: it erases on every terrain layer each room has.
var stroke_every_layer: bool = false
## The terrain the stroke paints (unused by the eraser's).
var stroke_terrain: PaletteCatalog.Entry = null
## {Room: how many chamber edges touched open air before the stroke} (RoomLook):
## more after it, and the status line warns.
var stroke_exposed_edges_before: Dictionary = {}
## Room settings the stroke's first paint of a new layer changes, per room:
## {Room: {setting: [before, after]}} (PaletteCatalog.Entry.room_settings_on_create).
var stroke_room_settings: Dictionary = {}
## The tool to go back to when E switches the eraser off again.
var tool_before_eraser: PaletteCatalog.Entry = null
## True while the eraser is held down and dragged.
var is_erasing: bool = false
## Where the mouse was at the free-hand stroke's last stamp (level pixels).
var last_stroke_point: Vector2 = Vector2.ZERO
## Shift-drag rectangle in progress: its room, start cell, and paint or erase.
var rectangle_active: bool = false
var rectangle_room: Room = null
var rectangle_start_cell: Vector2i = Vector2i.ZERO
var rectangle_painting: bool = true
## The rectangle is the eraser's (Shift+drag): it clears every layer and the
## objects inside, not one terrain.
var rectangle_erases_block: bool = false
## The Select tool's region (Shift+drag): the cells of `region_room`'s grid it
## covers (it may reach into the rooms next door). null room = no region.
var region_room: Room = null
var region_cells: Rect2i = Rect2i()
## A region being dragged out: from this cell of region_room's grid.
var region_dragging: bool = false
var region_start_cell: Vector2i = Vector2i.ZERO
## What Ctrl+C / Ctrl+X copied last (EditorClipboard), or null.
var clipboard: EditorClipboard = null
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
## The play-test's cheats (I, N, O, P, .), inside the play copy; null when not playing.
var play_cheats: PlaytestCheats = null
## The trail of the last play-test and this level's deaths (T, Ctrl+T).
var play_record: PlaytestRecord = PlaytestRecord.new()
## The player's tuning, for the jump-reach overlay (hold J).
var player_tuning: PlayerTuning = preload("res://resources/player_tuning.tres")

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
	ui.property_panel.property_changed.connect(_on_panel_property_changed)
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
	if clipboard != null:
		clipboard.free_templates()  # loose copies of objects: nothing else frees them
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
	play_record.load_level(path)  # this level's death markers from earlier play-tests
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
	# The Brush tool is a way back: it IS the last terrain chosen (Ground at first).
	if entry.kind == PaletteCatalog.Kind.BRUSH:
		entry = last_terrain_entry if last_terrain_entry != null else PaletteCatalog.get_entry(&"ground")
		if current_entry != null and current_entry.kind == PaletteCatalog.Kind.FILL:
			current_entry = null  # so the terrain below is chosen, not kept as Fill's
	ui.quick_bar.note_chosen(entry)
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


## P, the eyedropper: the object under the mouse, else the top terrain on the
## tile there, becomes the current tool. Returns what was picked, or null.
func pick_at(world_point: Vector2) -> PaletteCatalog.Entry:
	var picked: PaletteCatalog.Entry = null
	var hit: Node2D = object_at(world_point, true)
	if hit != null:
		picked = PaletteCatalog.entry_for_node(hit)
	else:
		var room: Room = room_at(world_point)
		if room != null:
			picked = terrain_entry_at(room, cell_at(room, world_point))
	if picked == null:
		ui.show_message("Nothing to pick there.")
		return null
	# Fill keeps its tool and takes the terrain (as a palette click does).
	choose_entry(picked)
	ui.show_message("Picked %s." % picked.display_name)
	return picked


## The terrain entry of the top layer with a tile at `room`'s `cell`, or null.
## Two entries can share a layer (the Overgrown looks, the ice slopes): the one
## whose tiles match the cell's tile wins.
func terrain_entry_at(room: Room, cell: Vector2i) -> PaletteCatalog.Entry:
	var children: Array[Node] = room.get_children()
	children.reverse()  # later children draw on top
	for child: Node in children:
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null or layer.get_cell_source_id(cell) == -1:
			continue
		var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
		var first_on_layer: PaletteCatalog.Entry = null
		for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
			if entry.kind != PaletteCatalog.Kind.TERRAIN or entry.layer_name != layer.name:
				continue
			if atlas == entry.tile_plain or atlas == entry.tile_top_edge or atlas == entry.tile_odd_column:
				return entry
			if first_on_layer == null:
				first_on_layer = entry
		if first_on_layer != null:
			return first_on_layer
	return null


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
	if stroke_room != null:
		_continue_stroke(world_point)  # also into the next room: the same stroke
		return
	var room: Room = room_at(world_point)
	if room == null:
		return
	begin_stroke(room, false, true)
	last_stroke_point = world_point
	_stamp(world_point)


# --- Terrain (also what the smoke test calls) ---

## Paints (or erases) `cells` in `room` with the Ground brush as ONE undo step.
## `terrain`: the brush to use (the current terrain tool if null). Only `room`'s
## own cells: the others are ignored (strokes and rectangles cross rooms, this doesn't).
func paint_cells(room: Room, cells: Array[Vector2i], painting: bool, terrain: PaletteCatalog.Entry = null) -> void:
	begin_stroke(room, painting, false, terrain)
	for cell: Vector2i in cells:
		_stroke_cell(cell)
	end_stroke()


## Fills (or clears) the rectangle between two cells of `room`'s grid as one undo
## step. It may reach past the room: those cells go to the rooms next door.
func fill_rectangle(room: Room, corner_a: Vector2i, corner_b: Vector2i, painting: bool) -> void:
	var cells: Rect2i = _rect_between(corner_a, corner_b)
	begin_stroke(room, painting)
	for y: int in range(cells.position.y, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			_stroke_routed(room, Vector2i(x, y))
	end_stroke()


## Starts a stroke in `room` with the current terrain entry's brush (Ground if the
## current tool isn't terrain, e.g. when the smoke test paints). `every_layer` (the
## eraser): erase on every terrain layer each room has, making none. Rooms the
## stroke reaches later join it then (_stroke_part).
func begin_stroke(room: Room, painting: bool, every_layer: bool = false, terrain_entry: PaletteCatalog.Entry = null) -> void:
	stroke_room = room
	stroke_painting = painting
	stroke_every_layer = every_layer
	stroke_terrain = terrain_entry if terrain_entry != null else current_entry
	if stroke_terrain == null or stroke_terrain.kind != PaletteCatalog.Kind.TERRAIN:
		stroke_terrain = PaletteCatalog.get_entry(&"ground")
	stroke_parts = {}
	stroke_layer_brushes = {}
	stroke_room_settings = {}
	stroke_exposed_edges_before = {}
	_stroke_part(room)


## `room`'s part of the current stroke, set up the first time the stroke reaches it.
func _stroke_part(room: Room) -> StrokePart:
	if stroke_parts.has(room):
		return stroke_parts[room]
	var part: StrokePart = StrokePart.new(room)
	stroke_parts[room] = part
	stroke_exposed_edges_before[room] = RoomLook.get_exposed_chamber_edges(room).size()
	if stroke_every_layer:
		# Two brushes can share a layer (the two Overgrown looks): one brush each.
		var layer_names: Array[StringName] = []
		for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
			if entry.kind != PaletteCatalog.Kind.TERRAIN or layer_names.has(entry.layer_name):
				continue
			layer_names.append(entry.layer_name)
			var layer: TileMapLayer = _brush_for(entry).get_layer(room, level_root, false)
			if layer != null:
				part.brushes.append(_layer_brush(_brush_for(entry), room, layer))
		return part
	var terrain: PaletteCatalog.Entry = stroke_terrain
	var had_layer: bool = _brush_for(terrain).get_layer(room, level_root, false) != null
	# Only painting makes the layer: erasing in a room without it has nothing to do.
	var terrain_layer: TileMapLayer = _brush_for(terrain).get_layer(room, level_root, stroke_painting)
	if terrain_layer == null:
		return part
	# The room's first stroke of this terrain: the room settings it implies
	# (painting Earth turns Earth on, Stage L8), kept for end_stroke's undo step.
	if not had_layer:
		var settings: Dictionary = {}
		for setting: StringName in terrain.room_settings_on_create:
			settings[setting] = [room.get(setting), terrain.room_settings_on_create[setting]]
		stroke_room_settings[room] = settings
	part.brushes.append(_layer_brush(_brush_for(terrain), room, terrain_layer))
	RoomLook.show_tiles_while_painting(room, terrain_layer)
	# A carving terrain (a hidden chamber) erases the solid layers where it paints.
	if stroke_painting:
		for carved_name: StringName in terrain.carves_layers:
			var carved_entry: PaletteCatalog.Entry = _terrain_entry_for_layer(carved_name)
			var carved_layer: TileMapLayer = _brush_for(carved_entry).get_layer(room, level_root, false) if carved_entry != null else null
			if carved_layer != null:
				var carved_brush: TileBrush = _layer_brush(_brush_for(carved_entry), room, carved_layer)
				part.brushes.append(carved_brush)
				part.carving_brushes.append(carved_brush)
	return part


## The stroke's brush for `layer` (in `room`): made the first time, as a twin of
## `template` (the terrain's brush), its stroke begun and told how to read the room above.
func _layer_brush(template: TileBrush, room: Room, layer: TileMapLayer) -> TileBrush:
	if stroke_layer_brushes.has(layer):
		return stroke_layer_brushes[layer]
	var brush: TileBrush = template.make_twin()
	brush.begin_stroke(layer)
	brush.room_cells = room_cell_rect(room)
	# bind(): the Callable gets these two after the cell the brush passes.
	brush.outside_reader = _read_neighbour_cell.bind(room, layer.name)
	stroke_layer_brushes[layer] = brush
	return brush


## For TileBrush.outside_reader: the value of the cell at `room`'s cell `cell`
## (just outside the room) on the layer named `layer_name` of the room that's there.
func _read_neighbour_cell(cell: Vector2i, room: Room, layer_name: StringName) -> Vector3i:
	var point: Vector2 = _cell_center(room, cell)
	var other: Room = room_at(point)
	if other == null or other == room:
		return TileBrush.EMPTY
	var layer: TileMapLayer = other.get_node_or_null(NodePath(layer_name)) as TileMapLayer
	if layer == null:
		return TileBrush.EMPTY
	return TileBrush.read_cell(layer, cell_at(other, point))


## Ends the stroke and records it as one undo step (if anything changed).
func end_stroke() -> void:
	if stroke_room == null:
		return
	var rooms: Array = stroke_parts.keys()
	var changes: Array[Array] = _finish_stroke()
	if changes.is_empty():
		stroke_room_settings = {}
		for room: Room in rooms:
			RoomLook.refresh(room)  # hides the layer shown while painting again
		return
	undo_redo.create_action("Paint tiles" if stroke_painting else "Erase tiles")
	_add_stroke_steps(changes)
	# true: run the "do" now. The cells are already painted (setting them again
	# changes nothing), but the room settings and the room's look need it.
	undo_redo.commit_action(true)
	_warn_if_chamber_exposed()


## After a change to the stroke's rooms' tiles: if more hidden-chamber edges touch
## open air in one than before the stroke, the status line says what the red edges mean.
func _warn_if_chamber_exposed() -> void:
	for room: Room in stroke_exposed_edges_before:
		if RoomLook.get_exposed_chamber_edges(room).size() > stroke_exposed_edges_before[room]:
			ui.show_message("Red edge: this hidden chamber touches open air there, so its cover is a wall you can walk through before anyone digs. Wall it in, unless that's meant.")
			return


## Ends the stroke's brushes. Returns [brush, layer, {"before", "after"}] for each
## layer it changed (TileBrush.end_stroke), in any room.
func _finish_stroke() -> Array[Array]:
	stroke_room = null
	var changes: Array[Array] = []
	for layer: TileMapLayer in stroke_layer_brushes:
		var brush: TileBrush = stroke_layer_brushes[layer]
		var change: Dictionary = brush.end_stroke()
		if not change.is_empty():
			changes.append([brush, layer, change])
	stroke_parts = {}
	stroke_layer_brushes = {}
	return changes


## Inside the undo action being made: the stroke's tile changes (both ways) and
## the room settings its first paint of a new layer implies, in every room.
func _add_stroke_steps(changes: Array[Array]) -> void:
	for brush_change: Array in changes:
		var brush: TileBrush = brush_change[0]
		undo_redo.add_do_method(_set_layer_cells.bind(brush, brush_change[1], brush_change[2]["after"]))
		undo_redo.add_undo_method(_set_layer_cells.bind(brush, brush_change[1], brush_change[2]["before"]))
	for room: Room in stroke_room_settings:
		var settings: Dictionary = stroke_room_settings[room]
		for setting: StringName in settings:
			var values: Array = settings[setting]  # [before, after]
			if values[0] != values[1]:
				undo_redo.add_do_property(room, setting, values[1])
				undo_redo.add_undo_property(room, setting, values[0])
	stroke_room_settings = {}


## The eraser's Shift+drag: clears the block of cells between two cells of `room`'s
## grid on every terrain layer, and deletes the objects whose outline lies inside
## it (not the spawn point). The block may reach into the rooms next door. One undo step.
func erase_block(room: Room, corner_a: Vector2i, corner_b: Vector2i) -> void:
	var cells: Rect2i = _rect_between(corner_a, corner_b)
	begin_stroke(room, false, true)
	for y: int in range(cells.position.y, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			_stroke_routed(room, Vector2i(x, y))
	var changes: Array[Array] = _finish_stroke()
	var block: Rect2 = Rect2(room.global_position + Vector2(cells.position * TILE), Vector2(cells.size * TILE))
	var doomed: Array[Node2D] = []
	for block_room: Room in get_rooms():
		if not block_room.get_bounds().intersects(block):
			continue
		for child: Node in block_room.get_children():
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
	_add_stroke_steps(changes)
	for node: Node2D in doomed:
		_add_delete_steps(node)
	undo_redo.commit_action(true)
	_warn_if_chamber_exposed()


## The terrain the Fill tool uses: the last terrain brush chosen, else Ground.
func _get_fill_terrain() -> PaletteCatalog.Entry:
	return last_terrain_entry if last_terrain_entry != null else PaletteCatalog.get_entry(&"ground")


## The Fill tool at `start_cell` of `room` (room-local cell), as ONE undo step.
## The area is every cell connected to it (up, down, left, right, inside the room)
## that holds the same terrain layers: the same tiles, or the same empty air.
## `painting`: it becomes the fill terrain (other terrain there is erased);
## else it's cleared. Returns how many cells the area had (0 = nothing changed).
## `everywhere` (Shift+click): every cell of the room holding the same layers,
## connected or not: "replace all Ground in this room with Earth".
func fill_region(room: Room, start_cell: Vector2i, painting: bool, everywhere: bool = false) -> int:
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
	# The connected area (breadth-first search over the 4 neighbours), or, for
	# `everywhere`, every matching cell of the room.
	var area: Array[Vector2i] = [start_cell]
	var seen: Dictionary = {start_cell: true}
	if everywhere:
		for y: int in range(bounds.position.y, bounds.end.y):
			for x: int in range(bounds.position.x, bounds.end.x):
				var cell: Vector2i = Vector2i(x, y)
				if not seen.has(cell) and _cell_contents(layers, cell) == start_contents:
					seen[cell] = true
					area.append(cell)
	var next: int = area.size() if everywhere else 0
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
	# A stroke made by hand: the room's part erases these layers only.
	_begin_manual_stroke(room, false)
	var erase_part: StrokePart = StrokePart.new(room)
	stroke_parts[room] = erase_part
	for layer_index: int in layers.size():
		if painting and layers[layer_index].name == terrain.layer_name:
			continue  # the fill's own layer: painted below, not erased first
		erase_part.brushes.append(_layer_brush(layer_brushes[layer_index], room, layers[layer_index]))
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
	_add_stroke_steps(changes)
	undo_redo.commit_action(true)
	stroke_exposed_edges_before = {room: exposed_edges_before}
	_warn_if_chamber_exposed()
	return area.size()


## A stroke whose brushes the caller sets up itself (the Fill tool, a paste):
## nothing made in any room yet.
func _begin_manual_stroke(room: Room, painting: bool) -> void:
	stroke_room = room
	stroke_painting = painting
	stroke_every_layer = false
	stroke_parts = {}
	stroke_layer_brushes = {}
	stroke_room_settings = {}
	stroke_exposed_edges_before = {}


# --- Paste (EditorClipboard calls these) ---

## Starts a paste whose cells are in `grid_room`'s grid. Then paste_tile() for each
## tile and finish_paste() with the new objects: all of it is one undo step.
func begin_paste(grid_room: Room) -> void:
	end_stroke()
	_begin_manual_stroke(grid_room, true)


## Puts `value` on the layer named `layer_name` at the cell `cell` of the paste's
## grid, in whichever room that is; the room gets the layer if it has none (and the
## room settings that come with it, like a stroke's first paint).
func paste_tile(cell: Vector2i, layer_name: StringName, value: Vector3i) -> void:
	var target: Array = route_cell(stroke_room, cell)
	var entry: PaletteCatalog.Entry = _terrain_entry_for_layer(layer_name)
	if target.is_empty() or entry == null:
		return
	var room: Room = target[0]
	var room_cell: Vector2i = target[1]
	var had_layer: bool = _brush_for(entry).get_layer(room, level_root, false) != null
	var layer: TileMapLayer = _brush_for(entry).get_layer(room, level_root, true)
	if not stroke_parts.has(room):
		stroke_parts[room] = StrokePart.new(room)
		stroke_exposed_edges_before[room] = RoomLook.get_exposed_chamber_edges(room).size()
	if not had_layer:
		var settings: Dictionary = stroke_room_settings.get(room, {})
		for setting: StringName in entry.room_settings_on_create:
			settings[setting] = [room.get(setting), entry.room_settings_on_create[setting]]
		stroke_room_settings[room] = settings
	var part: StrokePart = stroke_parts[room]
	var brush: TileBrush = _layer_brush(_brush_for(entry), room, layer)
	if not part.brushes.has(brush):
		part.brushes.append(brush)
	brush.write_value(room_cell, value)
	if room_cell.y == room_cell_rect(room).end.y - 1:
		_refresh_edge_below(room, room_cell, part)


## Ends the paste: its tiles and `new_objects` ([room, node] pairs, not in the
## tree yet) become one undo step. Returns false if there was nothing to paste.
func finish_paste(new_objects: Array[Array]) -> bool:
	var changes: Array[Array] = _finish_stroke()
	if changes.is_empty() and new_objects.is_empty():
		stroke_room_settings = {}
		return false
	undo_redo.create_action("Paste")
	_add_stroke_steps(changes)
	for room_and_node: Array in new_objects:
		_add_object_steps(room_and_node[0], room_and_node[1])
	undo_redo.commit_action(true)
	_warn_if_chamber_exposed()
	return true


## True if there's a region (its room may have been deleted or undone away since).
func has_region() -> bool:
	return region_room != null and is_instance_valid(region_room) and region_room.is_inside_tree()


## The Select tool's region (Shift+drag) as a level rectangle, or an empty Rect2.
func get_region_rect() -> Rect2:
	if not has_region():
		return Rect2()
	return _cells_to_world(region_room, region_cells, false)


## Ctrl+C / Ctrl+X: the region's tiles and objects go on the clipboard; `cut`
## also erases them (one undo step, the eraser's block).
func copy_region(cut: bool) -> bool:
	if not has_region():
		ui.show_message("Mark a region first: Select tool, Shift+drag.", true)
		return false
	var copied: EditorClipboard = EditorClipboard.copy_from(self, region_room, region_cells)
	if copied.is_empty():
		copied.free_templates()
		ui.show_message("Nothing in that region to copy.")
		return false
	if clipboard != null:
		clipboard.free_templates()
	clipboard = copied
	if cut:
		erase_block(region_room, region_cells.position, region_cells.end - Vector2i.ONE)
	ui.show_message("%s %d tiles and %d objects. Ctrl+V pastes at the mouse, Ctrl+Shift+V mirrored." %
		["Cut" if cut else "Copied", clipboard.tiles.size(), clipboard.objects.size()])
	return true


## Ctrl+V / Ctrl+Shift+V: the clipboard with its top-left corner on the tile
## under the mouse (mirrored left-right with `mirrored`). The pasted area becomes
## the region, so it can be copied again or moved.
func paste_at(world_point: Vector2, mirrored: bool) -> bool:
	if clipboard == null or clipboard.is_empty():
		ui.show_message("The clipboard is empty: Shift+drag a region with Select, then Ctrl+C.", true)
		return false
	var grid_room: Room = room_at(world_point)
	if grid_room == null:
		ui.show_message("Paste: point the mouse inside a room.", true)
		return false
	var top_left: Vector2i = cell_at(grid_room, world_point)
	if not clipboard.paste(self, grid_room, top_left, mirrored):
		return false
	region_room = grid_room
	region_cells = Rect2i(top_left, clipboard.size_cells)
	ui.show_message("Pasted%s." % (" mirrored" if mirrored else ""))
	return true


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


## Free-hand strokes stamp a brush_size x brush_size square around the mouse's
## tile, in the grid of the room under it (the stroke's first room when it's
## between rooms); each tile goes to the room it lies in.
func _stamp(world_point: Vector2) -> void:
	var grid_room: Room = room_at(world_point)
	if grid_room == null:
		grid_room = stroke_room
	var square: Rect2i = brush_cells_at(cell_at(grid_room, world_point))
	for y: int in range(square.position.y, square.end.y):
		for x: int in range(square.position.x, square.end.x):
			_stroke_routed(grid_room, Vector2i(x, y))


## The brush_size square of room-local cells a free-hand stroke at `cell` covers.
## For an even size it leans down-right, so size 2 covers cell..cell+1.
func brush_cells_at(cell: Vector2i) -> Rect2i:
	var first_offset: int = -((brush_size - 1) >> 1)
	return Rect2i(cell + Vector2i.ONE * first_offset, Vector2i.ONE * brush_size)


## The overlay's hover outline for terrain and the eraser: the brush square
## under the mouse, in level pixels (it may reach into the next room, as the
## stroke does). Empty without a hovered room.
func get_brush_outline() -> Rect2:
	if hover_room == null:
		return Rect2()
	return _cells_to_world(hover_room, brush_cells_at(hover_cell), false)


## [ and ]: changes the free-hand brush size and says what it is now.
func change_brush_size(delta: int) -> void:
	brush_size = clampi(brush_size + delta, 1, MAX_BRUSH_SIZE)
	ui.show_message("Brush size: %d x %d tiles" % [brush_size, brush_size])


## Paints or erases one cell of the stroke's first room, if it's inside it
## (paint_cells, the Fill tool and the smoke test: they stay in one room).
func _stroke_cell(cell: Vector2i) -> void:
	_stroke_cell_in(stroke_room, cell)


## Paints or erases the cell `cell` of `grid_room`'s grid in whichever room it
## lies in: its own cells in `grid_room`, others by their center (rooms next to
## each other can have grids half a tile apart: a 180 px room is 22.5 tiles tall).
## Cells outside every room are dropped.
func _stroke_routed(grid_room: Room, cell: Vector2i) -> void:
	var target: Array = route_cell(grid_room, cell)
	if not target.is_empty():
		_stroke_cell_in(target[0], target[1])


## Where the cell `cell` of `grid_room`'s grid really is: [room, room-local cell],
## its own cells in `grid_room`, others by their center (see _stroke_routed), or
## [] outside every room.
func route_cell(grid_room: Room, cell: Vector2i) -> Array:
	if room_cell_rect(grid_room).has_point(cell):
		return [grid_room, cell]
	var point: Vector2 = _cell_center(grid_room, cell)
	var room: Room = room_at(point)
	if room == null:
		return []
	return [room, cell_at(room, point)]


## Paints or erases `room`'s cell `cell` (room-local), if it's inside the room.
func _stroke_cell_in(room: Room, cell: Vector2i) -> void:
	var room_cells: Rect2i = room_cell_rect(room)
	if not room_cells.has_point(cell):
		return
	var part: StrokePart = _stroke_part(room)
	for brush: TileBrush in part.brushes:
		if stroke_painting and not part.carving_brushes.has(brush):
			brush.paint_cell(cell)
		else:
			brush.erase_cell(cell)
	if cell.y == room_cells.end.y - 1:
		_refresh_edge_below(room, cell, part)


## `room`'s bottom-row cell `cell` just changed: the tile under it is the top row
## of the room below (if there is one), whose top edge depends on it.
func _refresh_edge_below(room: Room, cell: Vector2i, part: StrokePart) -> void:
	# Half a tile down: a 180 px room's last row is centered ON the border, and
	# a whole tile down would skip the next room's top row.
	var below_point: Vector2 = _cell_center(room, cell) + Vector2(0, TILE / 2.0)
	var below_room: Room = room_at(below_point)
	if below_room == null or below_room == room:
		return
	var below_cell: Vector2i = cell_at(below_room, below_point)
	for brush: TileBrush in part.brushes:
		# Only a layer the room below already has: an edge fix never makes one.
		var below_layer: TileMapLayer = below_room.get_node_or_null(NodePath(brush.stroke_layer.name)) as TileMapLayer
		if below_layer != null:
			_layer_brush(brush, below_room, below_layer).refresh_edge(below_cell)


## The center of `room`'s cell `cell` (room-local, may be outside it), in level pixels.
func _cell_center(room: Room, cell: Vector2i) -> Vector2:
	return room.global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _brush_for(entry: PaletteCatalog.Entry) -> TileBrush:
	if not brushes.has(entry.id):
		brushes[entry.id] = TileBrush.new(entry.layer_name, entry.tile_set, entry.layer_script,
			entry.tile_plain, entry.tile_top_edge, entry.tile_odd_column)
	return brushes[entry.id]


## The first terrain entry painting the layer named `layer_name` (only erasing is
## asked of its brush, so which of two entries sharing a layer doesn't matter).
func _terrain_entry_for_layer(layer_name: StringName) -> PaletteCatalog.Entry:
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.kind == PaletteCatalog.Kind.TERRAIN and entry.layer_name == layer_name:
			return entry
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


## The property panel changed a setting. A room setting with several rooms
## selected on the map goes to all of them; anything else to its own target.
func _on_panel_property_changed(target: Object, property: StringName, value: Variant) -> void:
	var rooms: Array[Room] = _get_panel_rooms()
	if target is Room and rooms.size() > 1 and rooms.has(target):
		set_rooms_property(rooms, property, value)
	else:
		set_property(target, property, value)


## The rooms the room panel stands for: the map's selection when the map is open,
## else only the current room.
func _get_panel_rooms() -> Array[Room]:
	if map_view != null and map_view.is_open and not map_view.selected_rooms.is_empty():
		return map_view.selected_rooms
	var rooms: Array[Room] = []
	if current_room != null and is_instance_valid(current_room):
		rooms.append(current_room)
	return rooms


## Sets `property` to `value` on every room of `rooms`, as ONE undo step (one
## Ctrl+Z puts all of them back). For the map's selection.
func set_rooms_property(rooms: Array[Room], property: StringName, value: Variant) -> void:
	undo_redo.create_action("Set %s of %d rooms" % [property, rooms.size()])
	for room: Room in rooms:
		undo_redo.add_do_method(_apply_property.bind(room, property, value))
		undo_redo.add_undo_method(_apply_property.bind(room, property, room.get(property)))
	undo_redo.commit_action()
	if rooms.size() > 1:
		ui.show_message("%s set in %d rooms." % [String(property).capitalize(), rooms.size()])


## K: the backdrop preview, starting on the look of the room(s) the panel shows;
## Enter there sets that look and altitude in them (one undo step).
func open_backdrop_preview() -> void:
	var rooms: Array[Room] = _get_panel_rooms().duplicate()
	if rooms.is_empty():
		ui.backdrop_preview.open(Backdrop.Look.MOUNTAIN, Backdrop.Altitude.SURFACE)
		return
	var start_room: Room = get_start_room()
	var target_text: String = room_title(rooms[0]) if rooms.size() == 1 else "the %d selected rooms" % rooms.size()
	ui.backdrop_preview.open(rooms[0].get_backdrop_theme(), rooms[0].get_backdrop_altitude(start_room),
		func(look: Backdrop.Look, altitude: Backdrop.Altitude) -> void:
			set_rooms_property(rooms, &"backdrop_theme", look)
			set_rooms_property(rooms, &"backdrop_altitude", altitude)
			ui.show_message("%s for %s." % [Backdrop.describe(look, altitude), target_text]),
		target_text)


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
		var title: String = "Room\n%s" % room_title(current_room)
		var room_count: int = _get_panel_rooms().size()
		if room_count > 1:
			title = "%d rooms selected\n(changes go to all)" % room_count
		ui.property_panel.show_target(current_room, title, ROOM_SETTINGS)
		ui.property_panel.add_button("Preview backdrops (%s)" % EditorHelp.key_text("editor_backdrop_preview"),
			open_backdrop_preview)
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
		while cell.y > 0 and cell.y < room_rows - 1 and is_solid_cell(room, cell):
			cell.y -= step  # out of the tile, on the side away from the search
	while cell.y >= 0 and cell.y < room_rows:
		if is_solid_cell(room, cell):
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
		if is_solid_cell(room, Vector2i(column, y)) and not is_solid_cell(room, Vector2i(column, y - 1)):
			var floor_origin: Vector2 = Vector2(side_x, y * TILE)
			candidates.append([floor_origin, Rect2(floor_origin + Vector2(-size.x / 2.0, -size.y), size), false, 0])
		if is_solid_cell(room, Vector2i(column, y - 1)) and not is_solid_cell(room, Vector2i(column, y)):
			var ceiling_origin: Vector2 = Vector2(side_x, y * TILE)
			candidates.append([ceiling_origin, Rect2(ceiling_origin + Vector2(-size.x / 2.0, 0.0), size), true, 0])
	for x: int in range(1, room_size.x - 1):
		if is_solid_cell(room, Vector2i(x - 1, row)) and not is_solid_cell(room, Vector2i(x, row)):
			var left_origin: Vector2 = Vector2(x * TILE, side_y)
			candidates.append([left_origin, Rect2(left_origin + Vector2(0.0, -size.y / 2.0), size), false, -1])
		if is_solid_cell(room, Vector2i(x, row)) and not is_solid_cell(room, Vector2i(x - 1, row)):
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
			if is_solid_cell(room, Vector2i(x, y)):
				return false
	return true


## True if any terrain layer of `room` has a tile at `cell`.
func is_solid_cell(room: Room, cell: Vector2i) -> bool:
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
	_add_object_steps(room, node)
	undo_redo.commit_action()
	selected_object = node


## Inside the undo action being made: adds `node` (not in the tree yet) to `room`,
## with the room settings it comes with; undo takes it out again.
func _add_object_steps(room: Room, node: Node2D) -> void:
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
	# The cheats live in the play copy, so they go when it's freed.
	play_cheats = PlaytestCheats.new(play_root.player)
	play_root.add_child(play_cheats)
	play_record.begin_trail()
	play_root.player.died.connect(_on_playtest_player_died)
	is_playtesting = true
	return true


## Every physics frame of a play-test: the player's feet join the trail.
func _physics_process(_delta: float) -> void:
	if is_playtesting and play_root != null and is_instance_valid(play_root.player):
		play_record.add_point(play_root.player.global_position)


func _on_playtest_player_died() -> void:
	if is_playtesting and play_root != null:
		play_record.add_death(play_root.player.global_position)


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
	# The pause, freeze and slow motion are global: switch them all off (the
	# cheats' pause and speed too).
	if is_instance_valid(play_cheats):
		play_cheats.switch_all_off()
	play_cheats = null
	FX.set_menu_pause(false)
	FX.clear_slow_motion()
	play_record.save()
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
	if level_root == null or ui.prompt.visible or ui.help.visible or ui.import_picker.visible \
			or ui.backdrop_preview.visible:
		return  # those handle their own keys (H and Esc close the help)
	var mouse_world: Vector2 = get_global_mouse_position()

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if is_panning:
			camera.pan_by(motion.relative)
		elif map_view.is_open:
			map_view.mouse_moved(mouse_world)
		elif region_dragging:
			region_cells = _rect_between(region_start_cell, cell_at(region_room, mouse_world))
		elif is_erasing:
			erase_at(mouse_world, true)
		elif stroke_room != null:
			_continue_stroke(mouse_world)
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

	var quick_slot: int = _quick_slot_pressed(event)
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
	elif event.is_action_pressed("editor_backdrop_preview"):
		open_backdrop_preview()
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
	elif event.is_action_pressed("editor_brush_bigger"):
		change_brush_size(1)
	elif event.is_action_pressed("editor_brush_smaller"):
		change_brush_size(-1)
	# The Ctrl (and Ctrl+Shift) keys before plain keys on the same letter: a plain
	# key's action also matches with Ctrl held.
	elif event.is_action_pressed("editor_search"):
		ui.search.focus()
	elif event.is_action_pressed("editor_paste_mirrored"):
		paste_at(mouse_world, true)
	elif event.is_action_pressed("editor_paste"):
		paste_at(mouse_world, false)
	elif event.is_action_pressed("editor_copy"):
		copy_region(false)
	elif event.is_action_pressed("editor_cut"):
		copy_region(true)
	elif event.is_action_pressed("editor_clear_deaths"):
		ui.show_message("Cleared %d death markers." % play_record.clear_deaths())
	elif event.is_action_pressed("editor_toggle_trail"):
		play_record.is_shown = not play_record.is_shown
		ui.show_message("Play-test trail and deaths %s." % ("shown" if play_record.is_shown else "hidden"))
	elif event.is_action_pressed("editor_brush_tool"):
		end_link_mode()
		choose_entry(PaletteCatalog.get_entry(&"brush"))
	elif event.is_action_pressed("editor_fill_tool"):
		end_link_mode()
		choose_entry(PaletteCatalog.get_entry(&"fill"))
	elif event.is_action_pressed("editor_pick"):
		end_link_mode()
		pick_at(mouse_world)
	elif quick_slot != -1:
		ui.quick_bar.choose_slot(quick_slot)
	elif event.is_action_pressed("editor_back"):
		if link_source != null:
			end_link_mode()  # Esc first leaves link mode, then the region, then the editor
		elif has_region():
			region_room = null
		else:
			request_leave()
	else:
		return
	viewport.set_input_as_handled()


## The quick bar slot (0-8) whose key (editor_quick_1 ... _9) `event` presses, or -1.
func _quick_slot_pressed(event: InputEvent) -> int:
	for slot: int in QuickBar.SLOT_COUNT:
		if event.is_action_pressed("editor_quick_%d" % (slot + 1)):
			return slot
	return -1


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
		var everywhere: bool = Input.is_action_pressed("editor_rectangle")  # Shift: the whole room
		if room != null and fill_region(room, cell_at(room, mouse_world), true, everywhere) == 0:
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
		if Input.is_action_pressed("editor_rectangle") and room != null:
			# Shift+drag: mark a region to copy (Ctrl+C) or cut (Ctrl+X).
			region_dragging = true
			region_room = room
			region_start_cell = cell_at(room, mouse_world)
			region_cells = Rect2i(region_start_cell, Vector2i.ONE)
			return
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
			fill_region(fill_room, cell_at(fill_room, mouse_world), false, Input.is_action_pressed("editor_rectangle"))
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
	if region_dragging:
		region_dragging = false
		region_cells = _rect_between(region_start_cell, cell_at(region_room, mouse_world))
		ui.show_message("Region %d x %d tiles: Ctrl+C copies, Ctrl+X cuts, Esc drops it." % [region_cells.size.x, region_cells.size.y])
	elif is_erasing:
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
		last_stroke_point = mouse_world
		_stamp(mouse_world)


## Starts a Shift-drag rectangle in `room` from the mouse's cell.
func _start_rectangle(room: Room, mouse_world: Vector2, painting: bool, erases_block: bool) -> void:
	rectangle_active = true
	rectangle_room = room
	rectangle_start_cell = cell_at(room, mouse_world)
	rectangle_painting = painting
	rectangle_erases_block = erases_block


## Stamps the brush along the line from the last mouse point to `world_point`, at
## most a tile apart: a fast mouse skips tiles between two motion events, and this
## fills the gap. Works in level pixels, so the line runs on into the next room.
func _continue_stroke(world_point: Vector2) -> void:
	var travel: Vector2 = world_point - last_stroke_point
	var steps: int = ceili(maxf(absf(travel.x), absf(travel.y)) / TILE)
	for step: int in range(1, steps + 1):
		_stamp(last_stroke_point.lerp(world_point, float(step) / steps))
	last_stroke_point = world_point


## What the overlay previews this frame: the rectangle or spike strip being dragged.
func _update_preview() -> void:
	preview_active = rectangle_active or strip_active
	if rectangle_active:
		# Not cut to the room: the rectangle carries on into the rooms next door.
		preview_rect = _cells_to_world(rectangle_room, _rect_between(rectangle_start_cell,
			cell_at(rectangle_room, get_global_mouse_position())), false)
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


## Room-local cells -> a level rectangle, cut to the room unless `cut_to_room` is false.
func _cells_to_world(room: Room, cells: Rect2i, cut_to_room: bool = true) -> Rect2:
	var rect: Rect2 = Rect2(room.global_position + Vector2(cells.position * TILE), Vector2(cells.size * TILE))
	return rect.intersection(room.get_bounds()) if cut_to_room else rect


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
