class_name EditorOverlay
extends Node2D
## EditorOverlay: what the level editor draws ON TOP of the level (Level_editor.md §4).
## In the map view (M, Stage L7) only the map: room outlines, names, the start
## room's star, green openings and the room being dragged (_draw_map). In the room
## view, rooms other than the current one are dimmed, and then:
## room outlines and names, the 8 px grid (G), spawn points, stand-ins for objects
## that draw nothing while editing (a wind zone is only moving particles, frozen
## here) with an arrow for their direction, the selected object, the tile or
## object under the mouse, the rectangle or spike strip being dragged, and links:
## a line from each door to each of its switches (dim; bright for the selected
## object), and in link mode an outline round everything that can be linked.
## Vines (after the L10 play-test): a pivot mark on each vine's anchor (the point
## everything it holds swings round), and for a crate or plank hanging on ONE vine,
## the arc its knot swings along when let go (from where it is to the same height
## on the other side).
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

var editor: LevelEditor
## The stripe picture (one period square), made on first use (_get_stripe_texture).
var stripe_texture: ImageTexture = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if editor == null or editor.level_root == null:
		return
	if editor.map_view.is_open:
		_draw_map(editor.map_view)
		return
	for room: Room in editor.get_rooms():
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

	_draw_links()
	_draw_pivots()
	if editor.link_source != null:
		_draw_link_targets()

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

	if editor.preview_active:
		draw_rect(editor.preview_rect, editor.preview_color)
	elif editor.hover_object != null:
		var is_eraser: bool = editor.current_entry != null and editor.current_entry.kind == PaletteCatalog.Kind.ERASER
		draw_rect(PaletteCatalog.get_bounds(editor.hover_object).grow(OUTLINE_MARGIN),
			ERASER_HOVER_COLOR if is_eraser else HOVER_COLOR, false, -1.0)
	elif editor.hover_room != null:
		var cell_rect: Rect2 = Rect2(editor.hover_room.global_position + Vector2(editor.hover_cell * LevelEditor.TILE),
			Vector2.ONE * LevelEditor.TILE)
		draw_rect(cell_rect, HOVER_COLOR, false, -1.0)


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
## edges, and the room being made, moved, resized or imported (red if refused).
func _draw_map(map: MapView) -> void:
	var pixel: float = 1.0 / editor.camera.get_zoom_factor()  # one screen pixel, in level pixels
	var start_room: Room = editor.get_start_room()
	for room: Room in editor.get_rooms():
		var bounds: Rect2 = MapView.room_rect(room)
		var color: Color = ROOM_OUTLINE_COLOR
		if room == map.selected_room:
			color = SELECTED_COLOR
		elif room == map.hovered_room:
			color = HOVER_COLOR
		draw_rect(bounds, color, false, MAP_OUTLINE_SCREEN_WIDTH * pixel)
		# Inside the room: above it, the name would cover the room on top.
		_draw_room_name(room, bounds, true)
		if room == start_room:
			var star_offset: float = (STAR_SCREEN_RADIUS + 3.0) * pixel
			_draw_star(Vector2(bounds.end.x - star_offset, bounds.position.y + star_offset), STAR_SCREEN_RADIUS * pixel)
	# The edge under the mouse, so you see what a drag would resize.
	if map.hovered_edges != 0 and map.hovered_room != null and map.drag == MapView.Drag.NONE:
		_draw_edges(MapView.room_rect(map.hovered_room), map.hovered_edges, MAP_OUTLINE_SCREEN_WIDTH * 2.0 * pixel)
	for opening: Array in map.get_openings():
		draw_line(opening[0], opening[1], OPENING_COLOR, OPENING_SCREEN_WIDTH * pixel)
	var is_dragging: bool = map.drag != MapView.Drag.NONE and map.preview_rect.size.x > 0.0
	if is_dragging or map.importing_room != null:
		var preview_color: Color = PREVIEW_COLOR if map.preview_valid else REFUSED_COLOR
		draw_rect(map.preview_rect, Color(preview_color, 0.15))
		draw_rect(map.preview_rect, preview_color, false, MAP_OUTLINE_SCREEN_WIDTH * pixel)
		if map.importing_room != null:
			_draw_room_name(map.importing_room, map.preview_rect, true)


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


## A small green figure standing where the player's feet go.
func _draw_spawn_marker(feet: Vector2) -> void:
	var size: Vector2 = PaletteCatalog.SPAWN_MARKER_SIZE
	var marker: Rect2 = Rect2(feet - Vector2(size.x / 2.0, size.y), size)
	draw_rect(marker, Color(SPAWN_COLOR, 0.35))
	draw_rect(marker, SPAWN_COLOR, false, -1.0)
