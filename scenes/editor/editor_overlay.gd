class_name EditorOverlay
extends Node2D
## EditorOverlay: what the level editor draws ON TOP of the level (Level_editor.md §4).
## In the map view (M, Stage L7) only the map: room outlines, names, the start
## room's star, each room's backdrop (look and altitude, "auto" when guessed),
## green openings and the room being dragged (_draw_map). In the room
## view, rooms other than the current one are dimmed, and then:
## room outlines and names, the 8 px grid (G), spawn points, stand-ins for objects
## that draw nothing while editing (a wind zone is only moving particles, frozen
## here) with an arrow for their direction, the selected object, the tile or
## object under the mouse (for terrain and the eraser: the whole brush square,
## [ and ]), the rectangle or spike strip being dragged, and links:
## a line from each door to each of its switches (dim; bright for the selected
## object), and in link mode an outline round everything that can be linked.
## Vines (after the L10 play-test): a pivot mark on each vine's anchor (the point
## everything it holds swings round), and for a crate or plank hanging on ONE vine,
## the arc its knot swings along when let go (from where it is to the same height
## on the other side).
## Also: the Select tool's region (dashed cyan) and where a paste would land, the
## last play-test's trail and this level's deaths (PlaytestRecord, T), and while J
## is held the jump's reach from the tile under the mouse (JumpReach).
## Hidden chambers: wide diagonal purple stripes over every chamber cell (the room
## shows the tunnel open while editing), a purple outline round each chamber, and
## a thick RED edge where a chamber touches open air (RoomLook.get_exposed_chamber_edges).
##
## It draws in level coordinates (it's a Node2D in the same world as the rooms),
## so the editor camera moves and zooms it with everything else. Lines use width
## -1: Godot then draws them one screen pixel thin at every zoom.
## It reads what to draw from `editor` (its LevelEditor) and redraws every frame:
## cheap for a few rooms, and nothing can get out of date.

const ROOM_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)
const ROOM_NAME_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
## Green: GAME_DESIGN.md §2 colors checkpoints / exits green.
const SPAWN_COLOR: Color = Color(0.3, 0.85, 0.4)
const HOVER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
## Yellow: stands out against every placeholder color in GAME_DESIGN.md §2.
const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.2)
## A selected sentry's sight range: a faint purple disc with a slightly stronger rim.
const SIGHT_FILL_COLOR: Color = Color(0.5, 0.24, 0.7, 0.08)
const SIGHT_RING_COLOR: Color = Color(0.6, 0.35, 0.85, 0.35)
const HANDLE_FILL_COLOR: Color = Color(0.1, 0.1, 0.12)
## The eraser outlines what it would remove in red.
const ERASER_HOVER_COLOR: Color = Color(1.0, 0.35, 0.3, 0.95)
## Links: the selection's yellow, see-through when not involving the selection.
const LINK_COLOR: Color = Color(1.0, 0.85, 0.2, 0.3)
const LINK_BRIGHT_COLOR: Color = Color(1.0, 0.85, 0.2, 0.95)
## Link mode: what can be clicked (cyan, clearly not the selection's yellow).
const LINK_TARGET_COLOR: Color = Color(0.3, 0.9, 1.0, 0.9)
## The dot on a link's target end, screen pixels.
const LINK_DOT_SCREEN_RADIUS: float = 2.0
## Outlines sit this many level pixels outside the object, so they don't hide it.
const OUTLINE_MARGIN: float = 1.0
## Direction arrows (a wind zone's wind): length and head size, level pixels.
const ARROW_LENGTH: float = 12.0
const ARROW_HEAD: float = 3.0
const ARROW_COLOR: Color = Color(0.75, 0.92, 1.0, 0.9)
## Room names are drawn this many SCREEN pixels tall, whatever the zoom.
const NAME_FONT_SIZE: int = 8
## Vine anchors and swing arcs: a vine-ish green, bright; the arc see-through.
const PIVOT_COLOR: Color = Color(0.55, 0.95, 0.35, 0.95)
const SWING_ARC_COLOR: Color = Color(0.55, 0.95, 0.35, 0.45)
## The pivot mark's ring and the bar it hangs from, screen pixels.
const PIVOT_SCREEN_RADIUS: float = 3.0
const PIVOT_BAR_SCREEN_HALF_WIDTH: float = 5.0
## A knot hanging (almost) straight down still gets an arc this wide each way.
const MIN_SWING_ARC: float = 0.26  # about 15 degrees
## Room view: drawn over the rooms you're not editing.
const NEIGHBOUR_DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
## Map view (Stage L7): openings (exits) green like the spawn point (GAME_DESIGN.md
## §2: exits are green), refused places red, the start room's star yellow.
const OPENING_COLOR: Color = Color(0.3, 0.95, 0.4)
const REFUSED_COLOR: Color = Color(1.0, 0.25, 0.2)
const PREVIEW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const STAR_COLOR: Color = Color(1.0, 0.85, 0.2)
## Map lines and the star, in SCREEN pixels.
const OPENING_SCREEN_WIDTH: float = 3.0
const MAP_OUTLINE_SCREEN_WIDTH: float = 2.0
const STAR_SCREEN_RADIUS: float = 6.0
## The map's backdrop line under each room's name, tinted by altitude, and a
## strip of the same tint along the room's bottom edge, so a level's climb from
## caves to sky reads at a glance.
const ALTITUDE_COLORS: Dictionary = {
	Backdrop.Altitude.UNDERGROUND: Color(0.85, 0.6, 0.35),
	Backdrop.Altitude.SURFACE: Color(0.55, 0.9, 0.5),
	Backdrop.Altitude.SKYLINE: Color(0.55, 0.8, 1.0),
}
const ALTITUDE_STRIP_SCREEN_HEIGHT: float = 3.0
## The depth behind (Level_editor.md §5a): its rooms' outlines and names, brighter
## behind the room under the mouse; gate markers (linked, or red with no twin).
const DEPTH_BEHIND_COLOR: Color = Color(0.35, 0.85, 0.9, 0.55)
const DEPTH_BEHIND_BRIGHT_COLOR: Color = Color(0.45, 0.95, 1.0, 0.95)
const DEPTH_LABEL_COLOR: Color = Color(0.45, 0.95, 1.0, 0.95)
const GATE_LINKED_COLOR: Color = Color(0.45, 0.95, 1.0, 0.95)
const GATE_NO_TWIN_COLOR: Color = Color(1.0, 0.25, 0.2, 0.95)
const GATE_MARK_SCREEN_RADIUS: float = 4.0
## The depth in front of the shown one, on the map: only faint outlines, to find
## your way (it isn't drawn in play: from depth N you never see N-1).
const DEPTH_IN_FRONT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.14)
## Hidden chambers: purple, the tint tools/build_earth_rooms.gd gives them. The
## stripes repeat every STRIPE_PERIOD_TILES tiles, STRIPE_WIDTH level pixels wide,
## so neighbouring cells' stripes join into long diagonal bands.
const CHAMBER_STRIPE_COLOR: Color = Color(0.72, 0.4, 1.0, 0.5)
const CHAMBER_GAP_COLOR: Color = Color(0.72, 0.4, 1.0, 0.12)
const CHAMBER_EDGE_COLOR: Color = Color(0.8, 0.5, 1.0, 0.9)
const CHAMBER_EXPOSED_COLOR: Color = Color(1.0, 0.25, 0.2)
const STRIPE_PERIOD_TILES: int = 2
const STRIPE_PERIOD: int = STRIPE_PERIOD_TILES * LevelEditor.TILE
const STRIPE_WIDTH: int = 7
## The red edge, screen pixels thick.
const EXPOSED_EDGE_SCREEN_WIDTH: float = 3.0

## The map's element letters (_draw_room_elements): Room property, letter, color.
## Air cyan (wind zones), Earth brown (crates, earth), Fire orange, Water blue.
const MAP_ELEMENT_MARKS: Array[Array] = [
	[&"air_allowed", "A", Color(0.55, 0.95, 1.0)],
	[&"earth_allowed", "E", Color(0.8, 0.6, 0.35)],
	[&"fire_allowed", "F", Color(1.0, 0.55, 0.15)],
	[&"water_allowed", "W", Color(0.35, 0.6, 1.0)],
]

## Play-test record (PlaytestRecord): the trail see-through yellow-green, deaths red.
const TRAIL_COLOR: Color = Color(0.85, 1.0, 0.3, 0.55)
const DEATH_COLOR: Color = Color(1.0, 0.2, 0.2, 0.95)
## Deaths of earlier play-tests fade: the last one full, then each older one this
## much fainter, down to OLDEST_DEATH_ALPHA (PlaytestRecord.death_runs).
const DEATH_FADE_PER_RUN: float = 0.25
const OLDEST_DEATH_ALPHA: float = 0.2
## A death X's half size, screen pixels, and how far above the feet it's drawn, px.
const DEATH_MARK_SCREEN_SIZE: float = 2.5
const DEATH_MARK_LIFT: float = 6.0
## The Select tool's region and the paste preview: cyan, like link mode's targets.
const REGION_COLOR: Color = Color(0.3, 0.9, 1.0, 0.95)
## Jump reach (hold J): the jump white, the jump-and-glide light blue; traced
## until this many tiles below the start.
const JUMP_REACH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const GLIDE_REACH_COLOR: Color = Color(0.6, 0.85, 1.0, 0.7)
## The jump with one gust (dashed): a whiter blue than the glide.
const GUST_REACH_COLOR: Color = Color(0.82, 0.93, 1.0, 0.85)
## Gust arcs' dash and gap length, screen pixels.
const GUST_REACH_DASH_SCREEN: float = 3.0
const JUMP_REACH_DROP_TILES: int = 6

var editor: LevelEditor
## The stripe picture (one period square), made on first use (_get_stripe_texture).
var stripe_texture: ImageTexture = null
## The jump reach arcs for one start point: tracing the gusts tries every frame of
## the jump, too much to redo each frame while J is held. [jump, glide, gusts...]
## per direction, keyed by direction (-1.0 / 1.0).
var jump_reach_start: Vector2 = Vector2.INF
var jump_reach_arcs: Dictionary = {}


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if editor == null or editor.level_root == null:
		return
	if editor.map_view.is_open:
		_draw_map(editor.map_view)
		return
	var shown_depth: int = editor.get_shown_depth()
	_draw_depth_behind(shown_depth, null, 1.0 / editor.camera.get_zoom_factor())
	for room: Room in editor.get_rooms():
		if room.get_depth() != shown_depth:
			continue  # another band, far off screen
		# Rooms other than the one being edited are dimmed: you see what's next
		# door, but the room you're working on stands out (Level_editor.md §5).
		# Under the dimming: a neighbour's chambers are dimmed with it.
		_draw_hidden_chambers(room)
		if room != editor.current_room:
			draw_rect(room.get_bounds(), NEIGHBOUR_DIM_COLOR)
		var bounds: Rect2 = room.get_bounds()
		if editor.grid_visible:
			_draw_grid(bounds)
		draw_rect(bounds, ROOM_OUTLINE_COLOR, false, -1.0)
		_draw_room_name(room, bounds)
		var spawn_point: Marker2D = room.get_node_or_null("SpawnPoint") as Marker2D
		if spawn_point != null:
			_draw_spawn_marker(spawn_point.global_position)
		_draw_stand_ins(room)
		_draw_lonely_gates(room)

	_draw_links()
	_draw_pivots()
	if editor.link_source != null:
		_draw_link_targets()
	if editor.play_record.is_shown:
		_draw_play_record(editor.play_record)
	_draw_region_and_paste()
	if Input.is_action_pressed("editor_jump_reach") and editor.hover_room != null:
		_draw_jump_reach()

	# A crumbling patch picked with the Select tool: its outline.
	if editor.selected_patch != null and editor.selected_patch.is_valid():
		for loop: PackedVector2Array in editor.selected_patch.get_world_loops():
			draw_polyline(loop, SELECTED_COLOR, -1.0)

	# is_inside_tree(): an undo can take the selected object out of the level.
	var selected: Node2D = editor.selected_object
	if selected != null and is_instance_valid(selected) and selected.is_inside_tree():
		draw_rect(PaletteCatalog.get_bounds(selected).grow(OUTLINE_MARGIN), SELECTED_COLOR, false, -1.0)
		_draw_handles(selected)
		# A selected sentry shows how far it can see: a faint purple circle around its eye.
		var selected_sentry: Sentry = selected as Sentry
		if selected_sentry != null:
			var eye: Vector2 = selected_sentry.get_eye_position()
			draw_circle(eye, selected_sentry.sight_range, SIGHT_FILL_COLOR)
			draw_arc(eye, selected_sentry.sight_range, 0.0, TAU, 96, SIGHT_RING_COLOR, -1.0)

	for cell_rect: Rect2 in editor.preview_cell_rects:  # a spike drag's cells so far
		draw_rect(cell_rect, editor.preview_color)
	if editor.preview_active:
		draw_rect(editor.preview_rect, editor.preview_color)
	elif editor.hover_object != null:
		var is_eraser: bool = editor.current_entry != null and editor.current_entry.kind == PaletteCatalog.Kind.ERASER
		draw_rect(PaletteCatalog.get_bounds(editor.hover_object).grow(OUTLINE_MARGIN),
			ERASER_HOVER_COLOR if is_eraser else HOVER_COLOR, false, -1.0)
	elif editor.hover_room != null:
		var kind: int = editor.current_entry.kind if editor.current_entry != null else -1
		if kind == PaletteCatalog.Kind.TERRAIN or kind == PaletteCatalog.Kind.ERASER:
			# The whole brush square ([ and ]), so you see what a stroke will cover.
			draw_rect(editor.get_brush_outline(),
				ERASER_HOVER_COLOR if kind == PaletteCatalog.Kind.ERASER else HOVER_COLOR, false, -1.0)
		else:
			var cell_rect: Rect2 = Rect2(editor.hover_room.global_position + Vector2(editor.hover_cell * LevelEditor.TILE),
				Vector2.ONE * LevelEditor.TILE)
			draw_rect(cell_rect, HOVER_COLOR, false, -1.0)


## The last play-test's trail (thin lines) and every death of this level (red X,
## fainter the more play-tests ago it was).
func _draw_play_record(record: PlaytestRecord) -> void:
	for segment: PackedVector2Array in record.trail:
		if segment.size() >= 2:
			draw_polyline(segment, TRAIL_COLOR, -1.0)
	var arm: float = DEATH_MARK_SCREEN_SIZE / editor.camera.get_zoom_factor()
	for index: int in record.deaths.size():
		# Drawn at the middle of the body, not the feet: that's where you see it die.
		var center: Vector2 = record.deaths[index] + Vector2(0, -DEATH_MARK_LIFT)
		# The last play-test's deaths stand out; each older one is fainter.
		var alpha: float = maxf(OLDEST_DEATH_ALPHA, 1.0 - record.get_death_age(index) * DEATH_FADE_PER_RUN)
		var color: Color = Color(DEATH_COLOR, DEATH_COLOR.a * alpha)
		draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, -1.0)
		draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, -1.0)


## The Select tool's region (dashed), and with the Select tool on and something
## copied, where Ctrl+V would paste it (the clipboard's size at the mouse's tile).
func _draw_region_and_paste() -> void:
	var region: Rect2 = editor.get_region_rect()
	if region.size != Vector2.ZERO:
		_draw_dashed_rect(region, REGION_COLOR)
	var is_select: bool = editor.current_entry != null and editor.current_entry.kind == PaletteCatalog.Kind.SELECT
	if is_select and editor.clipboard != null and not editor.clipboard.is_empty() and editor.hover_room != null:
		var paste_cells: Rect2i = Rect2i(editor.hover_cell, editor.clipboard.size_cells)
		var paste_rect: Rect2 = Rect2(editor.hover_room.global_position + Vector2(paste_cells.position * LevelEditor.TILE),
			Vector2(paste_cells.size * LevelEditor.TILE))
		draw_rect(paste_rect, Color(REGION_COLOR, 0.12))
		_draw_dashed_rect(paste_rect, Color(REGION_COLOR, 0.5))


## Hold J: the full jump's arc from the tile under the mouse, each way, the same
## with a glide from the top, and dashed, with one gust at its farthest-reaching
## moment: aimed back (shoves you on), back-and-down, and down (JumpReach).
## Labelled with how high and far the plain jump goes.
func _draw_jump_reach() -> void:
	var room: Room = editor.hover_room
	var cell: Vector2i = editor.hover_cell
	# Standing ON the tile under the mouse if it's solid, else on the tile below it.
	var feet_cell_bottom: int = cell.y if editor.is_solid_cell(room, cell) else cell.y + 1
	var start: Vector2 = room.global_position + Vector2((cell.x + 0.5) * LevelEditor.TILE, feet_cell_bottom * LevelEditor.TILE)
	if start != jump_reach_start:
		_trace_jump_reach(start)
	var pixel: float = 1.0 / editor.camera.get_zoom_factor()
	for direction: float in [-1.0, 1.0]:
		var arcs: Array = jump_reach_arcs[direction]
		var jump_arc: PackedVector2Array = arcs[0]
		draw_polyline(arcs[1], GLIDE_REACH_COLOR, -1.0)
		for gust_index: int in range(2, arcs.size()):
			_draw_dashed_polyline(arcs[gust_index], GUST_REACH_COLOR, GUST_REACH_DASH_SCREEN * pixel)
		draw_polyline(jump_arc, JUMP_REACH_COLOR, -1.0)
		if direction > 0.0:
			# How high, and how far across at the start height, in tiles.
			var reach: Vector2 = JumpReach.summary(jump_arc) / LevelEditor.TILE
			var text: String = "jump %.1f up, %.1f across" % [reach.y, reach.x]
			draw_set_transform(start + Vector2(4, -4) * pixel, 0.0, Vector2.ONE * pixel)
			draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, JUMP_REACH_COLOR)
			draw_set_transform(Vector2.ZERO)
	draw_circle(start, 1.5 * pixel, JUMP_REACH_COLOR)


## Works out (and keeps) the reach arcs from `start`. For a jump to the right the
## gusts blow left, left-and-down and down: the air goes the other way to you.
func _trace_jump_reach(start: Vector2) -> void:
	var tuning: PlayerTuning = editor.player_tuning
	var max_drop: float = JUMP_REACH_DROP_TILES * LevelEditor.TILE
	jump_reach_start = start
	jump_reach_arcs.clear()
	for direction: float in [-1.0, 1.0]:
		var arcs: Array = [
			JumpReach.trace(tuning, start, direction, false, max_drop),
			JumpReach.trace(tuning, start, direction, true, max_drop),
		]
		for gust_aim: Vector2 in [Vector2(-direction, 0.0), Vector2(-direction, 1.0).normalized(), Vector2.DOWN]:
			arcs.append(JumpReach.trace_gust(tuning, start, direction, gust_aim, max_drop))
		jump_reach_arcs[direction] = arcs


## A polyline drawn as dashes `dash` long with gaps as long, measured along the line
## (its points are a frame apart, far shorter than a dash, so per-segment dashes
## like draw_dashed_line's wouldn't show).
func _draw_dashed_polyline(points: PackedVector2Array, color: Color, dash: float) -> void:
	var distance: float = 0.0
	for index: int in range(1, points.size()):
		var from: Vector2 = points[index - 1]
		var to: Vector2 = points[index]
		# Even dash periods are drawn, odd ones are the gaps (by where the segment starts).
		if int(distance / dash) % 2 == 0:
			draw_line(from, to, color, -1.0)
		distance += from.distance_to(to)


## A rectangle outline of dashes (draw_dashed_line per side).
func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side: int in 4:
		draw_dashed_line(corners[side], corners[(side + 1) % 4], color, -1.0, 3.0)


## A line from each linking object to each of its targets, with a dot at the
## target. Bright when it involves the selected object (or the one being linked).
func _draw_links() -> void:
	var focus: Node2D = editor.link_source if editor.link_source != null else editor.selected_object
	var dot_radius: float = LINK_DOT_SCREEN_RADIUS / editor.camera.get_zoom_factor()
	for link: Array in editor.get_links():
		var source: Node2D = link[0]
		var target: Node2D = link[1]
		var color: Color = LINK_BRIGHT_COLOR if focus == source or focus == target else LINK_COLOR
		var target_center: Vector2 = PaletteCatalog.get_bounds(target).get_center()
		draw_line(PaletteCatalog.get_bounds(source).get_center(), target_center, color, -1.0)
		draw_circle(target_center, dot_radius, color)


## Every vine's anchor (catalog LINE_TO_POINT: the origin), and the swing arc of
## each holder (catalog tie_kind) that hangs on exactly one vine.
func _draw_pivots() -> void:
	var pixel: float = 1.0 / editor.camera.get_zoom_factor()
	for object: Node2D in editor.get_objects():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(object)
		if entry.bounds == PaletteCatalog.Bounds.LINE_TO_POINT:
			var anchor: Vector2 = object.global_position
			var bar: Vector2 = Vector2(PIVOT_BAR_SCREEN_HALF_WIDTH * pixel, 0.0)
			draw_line(anchor - bar, anchor + bar, PIVOT_COLOR, -1.0)
			draw_arc(anchor, PIVOT_SCREEN_RADIUS * pixel, 0.0, TAU, 12, PIVOT_COLOR, -1.0)
		elif entry.tie_kind != PaletteCatalog.TieKind.NONE:
			var vines: Array[Node2D] = []
			for target: Variant in object.get(entry.link_property):
				if target != null and is_instance_valid(target) and (target as Node).is_inside_tree():
					vines.append(target as Node2D)
			if vines.size() == 1:
				_draw_swing_arc(object, vines[0])


## The arc a holder's knot swings along round `vine`'s anchor: from its angle to the
## mirror angle (a swing let go from rest rises as high on the other side).
## Angles as Godot draws arcs: 0 = right, PI/2 = straight down.
func _draw_swing_arc(holder: Node2D, vine: Node2D) -> void:
	var anchor: Vector2 = vine.global_position
	var end: Vector2 = anchor + (vine.get(PaletteCatalog.entry_for_node(vine).point_properties[0]) as Vector2)
	var knot: Vector2 = PaletteCatalog.get_tie_point(holder, PaletteCatalog.get_tie_fraction(holder, end))
	var radius: float = anchor.distance_to(knot)
	if radius < 1.0:
		return
	var from_down: float = wrapf((knot - anchor).angle() - PI / 2.0, -PI, PI)
	var reach: float = maxf(absf(from_down), MIN_SWING_ARC)
	draw_arc(anchor, radius, PI / 2.0 - reach, PI / 2.0 + reach, 32, SWING_ARC_COLOR, -1.0)


## The map view: every room's outline (yellow if selected, bright if under the
## mouse), its name, a star on the start room, the green openings on shared
## edges, the room being made, moved, resized or imported (red if refused), and
## the selection box while one is dragged (yellow, never refused).
func _draw_map(map: MapView) -> void:
	var pixel: float = 1.0 / editor.camera.get_zoom_factor()  # one screen pixel, in level pixels
	var start_room: Room = editor.get_start_room()
	_draw_depth_behind(map.shown_depth, map.hovered_room, pixel)
	_draw_depth_in_front(map.shown_depth, pixel)
	_draw_depth_label(map)
	for room: Room in editor.get_rooms():
		if room.get_depth() != map.shown_depth:
			continue  # another depth: its own band, far away
		var bounds: Rect2 = MapView.room_rect(room)
		var color: Color = ROOM_OUTLINE_COLOR
		if map.selected_rooms.has(room):
			color = SELECTED_COLOR
		elif room == map.hovered_room:
			color = HOVER_COLOR
		draw_rect(bounds, color, false, MAP_OUTLINE_SCREEN_WIDTH * pixel)
		# Inside the room: above it, the name would cover the room on top.
		_draw_room_name(room, bounds, true)
		_draw_room_backdrop(room, bounds, start_room, pixel)
		_draw_room_elements(room, bounds)
		if room == start_room:
			var star_offset: float = (STAR_SCREEN_RADIUS + 3.0) * pixel
			_draw_star(Vector2(bounds.end.x - star_offset, bounds.position.y + star_offset), STAR_SCREEN_RADIUS * pixel)
		_draw_gate_marks(room, pixel)
	# The edge under the mouse, so you see what a drag would resize.
	if map.hovered_edges != 0 and map.hovered_room != null and map.drag == MapView.Drag.NONE:
		_draw_edges(MapView.room_rect(map.hovered_room), map.hovered_edges, MAP_OUTLINE_SCREEN_WIDTH * 2.0 * pixel)
	for opening: Array in map.get_openings():
		draw_line(opening[0], opening[1], OPENING_COLOR, OPENING_SCREEN_WIDTH * pixel)
	if map.drag == MapView.Drag.SELECT:
		draw_rect(map.preview_rect, Color(SELECTED_COLOR, 0.12))
		draw_rect(map.preview_rect, SELECTED_COLOR, false, MAP_OUTLINE_SCREEN_WIDTH * pixel)
		return
	var is_dragging: bool = map.drag != MapView.Drag.NONE and map.preview_rect.size.x > 0.0
	if is_dragging or map.importing_room != null:
		var preview_color: Color = PREVIEW_COLOR if map.preview_valid else REFUSED_COLOR
		draw_rect(map.preview_rect, Color(preview_color, 0.15))
		draw_rect(map.preview_rect, preview_color, false, MAP_OUTLINE_SCREEN_WIDTH * pixel)
		# The other selected rooms moving along with it.
		for group_rect: Rect2 in map.get_group_preview_rects():
			draw_rect(group_rect, Color(preview_color, 0.15))
			draw_rect(group_rect, preview_color, false, MAP_OUTLINE_SCREEN_WIDTH * pixel)
		if map.importing_room != null:
			_draw_room_name(map.importing_room, map.preview_rect, true)


## The depth behind `shown_depth` (Level_editor.md §5a), over its hazed picture
## (EditorDepthView): each room's outline at its map spot, moved into the shown
## band, thin and in the depth color, and its name; brighter where it's behind
## `hovered_room`, so you see which room is behind which.
func _draw_depth_behind(shown_depth: int, hovered_room: Room, pixel: float) -> void:
	var shift: Vector2 = Room.depth_offset(shown_depth) - Room.depth_offset(shown_depth + 1)
	var hovered_rect: Rect2 = MapView.room_rect(hovered_room) if hovered_room != null else Rect2()
	for room: Room in editor.get_rooms():
		if room.get_depth() != shown_depth + 1:
			continue
		var bounds: Rect2 = Rect2(MapView.room_rect(room).position + shift, room.room_size)
		var is_behind_hovered: bool = hovered_room != null and bounds.intersects(hovered_rect)
		var color: Color = DEPTH_BEHIND_BRIGHT_COLOR if is_behind_hovered else DEPTH_BEHIND_COLOR
		_draw_dashed_rect_width(bounds, color, (2.0 if is_behind_hovered else 1.0) * pixel, 6.0 * pixel)
		var zoom_factor: float = editor.camera.get_zoom_factor()
		draw_set_transform(Vector2(bounds.position.x, bounds.end.y) + Vector2(4.0, -4.0) / zoom_factor, 0.0, Vector2.ONE / zoom_factor)
		var title: String = room.display_title if room.display_title != "" else String(room.name)
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, "behind: " + title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, color)
		draw_set_transform(Vector2.ZERO)


## The depth in front of `shown_depth` (none for the front): each room's outline at
## its map spot, moved into the shown band, faint.
func _draw_depth_in_front(shown_depth: int, pixel: float) -> void:
	if shown_depth == 0:
		return
	var shift: Vector2 = Room.depth_offset(shown_depth) - Room.depth_offset(shown_depth - 1)
	for room: Room in editor.get_rooms():
		if room.get_depth() == shown_depth - 1:
			draw_rect(Rect2(MapView.room_rect(room).position + shift, room.room_size), DEPTH_IN_FRONT_COLOR, false, pixel)


## A dashed rectangle with lines `width` thick and dashes `dash` long (level px).
func _draw_dashed_rect_width(rect: Rect2, color: Color, width: float, dash: float) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side: int in 4:
		draw_dashed_line(corners[side], corners[(side + 1) % 4], color, width, dash)


## The map's depth label, top-left of the free space: "Depth 1 of 3" and the keys.
func _draw_depth_label(map: MapView) -> void:
	var zoom_factor: float = editor.camera.get_zoom_factor()
	var visible_world: Rect2 = editor._visible_world_rect()
	var corner: Vector2 = visible_world.position + Vector2(EditorUI.PALETTE_WIDTH + 6.0, EditorUI.BAR_HEIGHT + 14.0) / zoom_factor
	var depth_count: int = map.get_deepest_depth() + 1
	var text: String = "Depth %d of %d%s   %s: deeper  %s: shallower" % [map.shown_depth, depth_count,
		" (front)" if map.shown_depth == 0 else ("" if map.shown_depth < depth_count else " (new)"),
		EditorHelp.key_text("editor_depth_deeper"), EditorHelp.key_text("editor_depth_shallower")]
	draw_set_transform(corner, 0.0, Vector2.ONE / zoom_factor)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, DEPTH_LABEL_COLOR)
	draw_set_transform(Vector2.ZERO)


## On the map: a ring at each of the room's depth gates, in the depth color when
## it has a twin (they're at the same spot, so the ring IS the pair), red without.
func _draw_gate_marks(room: Room, pixel: float) -> void:
	for child: Node in room.get_children():
		var gate: DepthGate = child as DepthGate
		if gate == null:
			continue
		var color: Color = GATE_LINKED_COLOR if gate.find_twin() != null else GATE_NO_TWIN_COLOR
		var center: Vector2 = gate.get_gate_rect().get_center()
		draw_arc(center, GATE_MARK_SCREEN_RADIUS * pixel, 0.0, TAU, 16, color, 2.0 * pixel)
		draw_circle(center, GATE_MARK_SCREEN_RADIUS * 0.4 * pixel, color)


## In the room view: a depth gate with no twin gets a red outline and "no twin".
func _draw_lonely_gates(room: Room) -> void:
	for child: Node in room.get_children():
		var gate: DepthGate = child as DepthGate
		if gate == null or gate.find_twin() != null:
			continue
		var outline: Rect2 = gate.get_gate_rect().grow(OUTLINE_MARGIN)
		draw_rect(outline, GATE_NO_TWIN_COLOR, false, -1.0)
		var zoom_factor: float = editor.camera.get_zoom_factor()
		draw_set_transform(outline.position + Vector2(0.0, -2.0) / zoom_factor, 0.0, Vector2.ONE / zoom_factor)
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, "no twin", HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, GATE_NO_TWIN_COLOR)
		draw_set_transform(Vector2.ZERO)


## The `edges` (MapView.EDGE_* bits) of `rect`, drawn thick.
func _draw_edges(rect: Rect2, edges: int, width: float) -> void:
	if edges & MapView.EDGE_LEFT:
		draw_line(rect.position, Vector2(rect.position.x, rect.end.y), HOVER_COLOR, width)
	if edges & MapView.EDGE_RIGHT:
		draw_line(Vector2(rect.end.x, rect.position.y), rect.end, HOVER_COLOR, width)
	if edges & MapView.EDGE_TOP:
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), HOVER_COLOR, width)
	if edges & MapView.EDGE_BOTTOM:
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, HOVER_COLOR, width)


## A five-pointed star: 10 corners, alternating the outer and an inner radius.
func _draw_star(center: Vector2, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for corner: int in 10:
		var corner_radius: float = radius if corner % 2 == 0 else radius * 0.45
		# -PI/2: the first point straight up.
		var angle: float = -PI / 2.0 + corner * PI / 5.0
		points.append(center + Vector2.from_angle(angle) * corner_radius)
	draw_colored_polygon(points, STAR_COLOR)


## Link mode: outlines everything the link source can be linked to.
func _draw_link_targets() -> void:
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(editor.link_source)
	for candidate: Node2D in editor.get_objects():
		if candidate != editor.link_source and PaletteCatalog.is_link_target(entry, candidate):
			draw_rect(PaletteCatalog.get_bounds(candidate).grow(OUTLINE_MARGIN + 1.0), LINK_TARGET_COLOR, false, -1.0)


## Filled outlines (and arrows) for the room's objects whose catalog entry asks for one.
func _draw_stand_ins(room: Room) -> void:
	for child: Node in room.get_children():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(child)
		if entry == null or entry.editor_color.a <= 0.0:
			continue
		var outline: Rect2 = PaletteCatalog.get_bounds(child as Node2D)
		draw_rect(outline, entry.editor_color)
		draw_rect(outline, Color(entry.editor_color, 0.6), false, -1.0)
		if entry.arrow_property != &"":
			var direction: Vector2 = (child.get(entry.arrow_property) as Vector2).normalized()
			_draw_arrow(outline.get_center(), direction)


## The room's hidden chambers (see the header).
func _draw_hidden_chambers(room: Room) -> void:
	var hidden_layer: TileMapLayer = room.get_node_or_null(NodePath(RoomLook.HIDDEN_LAYER_NAME)) as TileMapLayer
	if hidden_layer == null:
		return
	var tile: int = LevelEditor.TILE
	var texture: ImageTexture = _get_stripe_texture()
	for cell: Vector2i in hidden_layer.get_used_cells():
		# The part of the stripe picture this cell shows: where it sits in the
		# repeating pattern (posmod: also right for negative cells).
		var source: Rect2 = Rect2(Vector2(posmod(cell.x, STRIPE_PERIOD_TILES), posmod(cell.y, STRIPE_PERIOD_TILES)) * tile,
			Vector2.ONE * tile)
		draw_texture_rect_region(texture, Rect2(room.global_position + Vector2(cell * tile), Vector2.ONE * tile), source)
		# The chamber's outline: each side that doesn't lead into more chamber.
		for step: Vector2i in RoomLook.NEIGHBOUR_STEPS:
			if hidden_layer.get_cell_source_id(cell + step) == -1:
				var side: Array[Vector2] = _cell_side(room, cell, step)
				draw_line(side[0], side[1], CHAMBER_EDGE_COLOR, -1.0)
	var red_width: float = EXPOSED_EDGE_SCREEN_WIDTH / editor.camera.get_zoom_factor()
	for edge: Array in RoomLook.get_exposed_chamber_edges(room):
		var side: Array[Vector2] = _cell_side(room, edge[0], edge[1])
		draw_line(side[0], side[1], CHAMBER_EXPOSED_COLOR, red_width)


## The two ends of `cell`'s side facing `step` (one of the 4 ways), in level pixels.
func _cell_side(room: Room, cell: Vector2i, step: Vector2i) -> Array[Vector2]:
	var tile: float = LevelEditor.TILE
	var center: Vector2 = room.global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * tile
	var out: Vector2 = Vector2(step) * tile / 2.0
	# Along the side: the step turned a quarter.
	var along: Vector2 = Vector2(-step.y, step.x) * tile / 2.0
	return [center + out - along, center + out + along]


## One STRIPE_PERIOD square of diagonal stripes: a pixel is in a stripe when
## (x + y) mod STRIPE_PERIOD < STRIPE_WIDTH, so the bands run corner to corner and
## the square repeats seamlessly.
func _get_stripe_texture() -> ImageTexture:
	if stripe_texture == null:
		var image: Image = Image.create(STRIPE_PERIOD, STRIPE_PERIOD, false, Image.FORMAT_RGBA8)
		for y: int in STRIPE_PERIOD:
			for x: int in STRIPE_PERIOD:
				var in_stripe: bool = (x + y) % STRIPE_PERIOD < STRIPE_WIDTH
				image.set_pixel(x, y, CHAMBER_STRIPE_COLOR if in_stripe else CHAMBER_GAP_COLOR)
		stripe_texture = ImageTexture.create_from_image(image)
	return stripe_texture


## The selected object's drag handles (EditorHandles): small squares, the same
## size on screen at every zoom; a point handle also gets a dashed line from
## the object's origin, so you see what it belongs to.
func _draw_handles(node: Node2D) -> void:
	var half_size: float = EditorHandles.HANDLE_SCREEN_SIZE / editor.camera.get_zoom_factor() / 2.0
	for handle: Dictionary in EditorHandles.get_handles(node):
		var handle_position: Vector2 = handle["position"]
		# (A rail's corners need no line: the rail itself joins them.)
		if handle["kind"] == EditorHandles.Kind.POINT:
			draw_dashed_line(node.global_position, handle_position, Color(SELECTED_COLOR, 0.7), -1.0, 2.0)
		var square: Rect2 = Rect2(handle_position - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0)
		draw_rect(square, HANDLE_FILL_COLOR)
		draw_rect(square, SELECTED_COLOR, false, -1.0)


## An arrow from `center` pointing along `direction` (a unit vector).
func _draw_arrow(center: Vector2, direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var tail: Vector2 = center - direction * ARROW_LENGTH / 2.0
	var tip: Vector2 = center + direction * ARROW_LENGTH / 2.0
	draw_line(tail, tip, ARROW_COLOR, -1.0)
	# Two short lines back from the tip, each turned 30 degrees off the shaft.
	draw_line(tip, tip - direction.rotated(PI / 6.0) * ARROW_HEAD, ARROW_COLOR, -1.0)
	draw_line(tip, tip - direction.rotated(-PI / 6.0) * ARROW_HEAD, ARROW_COLOR, -1.0)


## One line per tile column and row inside the room.
func _draw_grid(bounds: Rect2) -> void:
	var x: float = bounds.position.x + LevelEditor.TILE
	while x < bounds.end.x:
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), GRID_COLOR, -1.0)
		x += LevelEditor.TILE
	var y: float = bounds.position.y + LevelEditor.TILE
	while y < bounds.end.y:
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), GRID_COLOR, -1.0)
		y += LevelEditor.TILE


## The room's title just above its top-left corner (`inside`: just inside it).
## draw_set_transform() scales the text by 1/zoom, so it stays the same size on
## screen when you zoom.
func _draw_room_name(room: Room, bounds: Rect2, inside: bool = false) -> void:
	var title: String = room.display_title if room.display_title != "" else String(room.name)
	var zoom_factor: float = editor.camera.get_zoom_factor()
	# The text's baseline, in screen pixels from the corner.
	var baseline: Vector2 = Vector2(4.0, NAME_FONT_SIZE + 3.0) if inside else Vector2(0.0, -2.0)
	draw_set_transform(bounds.position + baseline / zoom_factor, 0.0, Vector2.ONE / zoom_factor)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, ROOM_NAME_COLOR)
	draw_set_transform(Vector2.ZERO)


## Under the room's name on the map: its backdrop, e.g. "Forest, skyline", with
## "(auto)" when the room leaves it to Room's guess, in the altitude's tint; and a
## thin strip of that tint along the room's bottom edge.
func _draw_room_backdrop(room: Room, bounds: Rect2, start_room: Room, pixel: float) -> void:
	var look: Backdrop.Look = room.get_backdrop_theme()
	var altitude: Backdrop.Altitude = room.get_backdrop_altitude(start_room)
	var text: String = Backdrop.describe(look, altitude)
	if look != Backdrop.Look.NONE and (room.backdrop_theme == Backdrop.Look.AUTO or room.backdrop_altitude == Backdrop.Altitude.AUTO):
		text += " (auto)"
	var color: Color = ALTITUDE_COLORS.get(altitude, ROOM_NAME_COLOR) if look != Backdrop.Look.NONE else ROOM_NAME_COLOR
	var zoom_factor: float = editor.camera.get_zoom_factor()
	draw_set_transform(bounds.position + Vector2(4.0, NAME_FONT_SIZE * 2.0 + 5.0) / zoom_factor, 0.0, Vector2.ONE / zoom_factor)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, Color(color, 0.85))
	draw_set_transform(Vector2.ZERO)
	var strip_height: float = ALTITUDE_STRIP_SCREEN_HEIGHT * pixel
	draw_rect(Rect2(bounds.position.x, bounds.end.y - strip_height, bounds.size.x, strip_height), Color(color, 0.5))


## Third line inside a room on the map: a letter per element the room allows
## (A E F W, each in its element's color), and "dark" for a dark room, so you
## see at a glance which rooms let the player do what.
func _draw_room_elements(room: Room, bounds: Rect2) -> void:
	var zoom_factor: float = editor.camera.get_zoom_factor()
	var font: Font = ThemeDB.fallback_font
	var pen: Vector2 = Vector2.ZERO  # where the next letter goes, screen pixels
	draw_set_transform(bounds.position + Vector2(4.0, NAME_FONT_SIZE * 3.0 + 7.0) / zoom_factor, 0.0, Vector2.ONE / zoom_factor)
	for element: Array in MAP_ELEMENT_MARKS:
		if not bool(room.get(element[0])):
			continue
		draw_string(font, pen, element[1], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, element[2])
		pen.x += font.get_string_size(element[1] + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
	if room.is_dark:
		draw_string(font, pen, "dark", HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, ROOM_NAME_COLOR)
	draw_set_transform(Vector2.ZERO)


## A small green figure standing where the player's feet go.
func _draw_spawn_marker(feet: Vector2) -> void:
	var size: Vector2 = PaletteCatalog.SPAWN_MARKER_SIZE
	var marker: Rect2 = Rect2(feet - Vector2(size.x / 2.0, size.y), size)
	draw_rect(marker, Color(SPAWN_COLOR, 0.35))
	draw_rect(marker, SPAWN_COLOR, false, -1.0)
