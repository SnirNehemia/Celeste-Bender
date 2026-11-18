class_name ClueLayer
extends NonSolidLayer
## ClueLayer: CLUES painted into a level, tile by tile like terrain: cosmetic
## decorations that hint at something, above all where a HIDDEN CHAMBER's entrance
## is (vines hanging over it, claw marks, cracks), or mark a way worth taking (leaves,
## flowers, footprints). They do nothing in play: no collision, no state.
##
## A TileMapLayer named "Clues" (PaletteCatalog CLUE_LAYER_NAME), painted from the
## editor's Player aid tab: ONE dropdown, one brush per Kind. Each kind is its own
## tile of resources/tiles/clue_tileset.tres (atlas column = Kind); the tiles are
## see-through, so a cell shows only the decoration drawn here. Clues sit ON TOP of
## the terrain: painting a clue never erases the ground under it, and painting ground
## never erases a clue (PaletteCatalog._assign_carving leaves this layer out).
##
## THE LOOK: a child node (ClueLook) draws every cell, placeholder pixel art from a few
## shapes, varied per cell by a hash of its position (so it never looks stamped), and
## joined up with the cells round it of the same kind: vine and root strands run on
## down through the cells below and end in a loose tip, cracks join their neighbours,
## moss gets a ragged edge where it stops. Redrawn when cells change (_update_cells).
##
## DRAWN OVER THE CHAMBER LID: a covered hidden chamber is drawn over everything in the
## room by the GroundPainter's lid, so a clue on its fake wall would vanish. The look's
## z_index is absolute, LOOK_Z_INDEX: above the lid, under the darkness of dark rooms
## (DarkRoomOverlay), so a clue in a dark room is only seen in a light, like the rest.
## The cost: clues also draw over the player and objects (like leaves in front).
##
## Godot concepts used:
##   - _update_cells(): a TileMapLayer's virtual, called with the cells that changed
##     (painting, erasing, undo), so the picture is redrawn only when needed.
##   - z_as_relative = false: the look's z_index isn't added to the room's.

## The decorations, in the editor dropdown's order (the atlas column of each tile).
enum Kind { LEAVES, VINES, MOSS, FLOWERS, ROOTS, CRACKS, CLAW_MARKS, FOOTPRINTS }

## Above the GroundPainter's chamber lid, under the darkness (see the header).
const LOOK_Z_INDEX: int = DarkRoomOverlay.DRAW_Z_INDEX - 1
const TILE: int = 8

## A CLUE ON A HIDDEN CHAMBER lives and dies with its fake wall: it is drawn only while the
## chamber's cell is covered, fades out with the wall as it crumbles or thins to a mist
## (HiddenLayer.get_cover_alpha), and is gone once the chamber is open (back at a reset).
## In the editor chambers show open, so clues there always show. get_clue_alpha() says
## how strong a cell's clue is; the drawing functions multiply it into every color (_put_*).

## Muted scenery colors (GAME_DESIGN.md §2 greens and browns).
const LEAF_COLORS: Array[Color] = [Color(0.66, 0.42, 0.16), Color(0.76, 0.57, 0.2), Color(0.5, 0.52, 0.2), Color(0.58, 0.3, 0.14)]
const VINE_COLOR: Color = Color(0.2, 0.4, 0.17)
const VINE_LEAF_COLORS: Array[Color] = [Color(0.3, 0.55, 0.22), Color(0.38, 0.62, 0.26)]
const MOSS_COLORS: Array[Color] = [Color(0.24, 0.44, 0.19), Color(0.33, 0.54, 0.23), Color(0.19, 0.35, 0.16)]
const STEM_COLOR: Color = Color(0.28, 0.5, 0.2)
const PETAL_COLORS: Array[Color] = [Color(0.95, 0.85, 0.35), Color(0.95, 0.95, 0.9), Color(0.9, 0.55, 0.65), Color(0.65, 0.6, 0.95)]
const ROOT_COLOR: Color = Color(0.4, 0.27, 0.15)
const ROOT_LIGHT_COLOR: Color = Color(0.55, 0.38, 0.22)
const SCRATCH_COLOR: Color = Color(0.08, 0.06, 0.05, 0.8)
const SCRATCH_LIGHT_COLOR: Color = Color(1.0, 0.95, 0.85, 0.3)
const FOOTPRINT_COLOR: Color = Color(0.1, 0.08, 0.06, 0.7)
## How likely two neighbouring crack cells are joined, up-down and sideways.
const CRACK_VERTICAL_LINK_CHANCE: float = 0.85
const CRACK_SIDEWAYS_LINK_CHANCE: float = 0.3
## Claw marks: the gap between the three scratches, px.
const CLAW_SPACING: float = 3.0
## A strand ending in open air (no strand cell below) hangs this far into its cell, px.
const STRAND_MIN_TIP: float = 3.0
const STRAND_MAX_TIP: float = 7.0

var look: Node2D
## The room's hidden-chamber layer, if it has one (found in _ready).
var hidden_layer: HiddenLayer = null
## The opacity of the cell being drawn right now (see get_clue_alpha), used by _put_*.
var current_alpha: float = 1.0


func _ready() -> void:
	look = Node2D.new()
	look.name = "ClueLook"
	look.z_as_relative = false
	look.z_index = LOOK_Z_INDEX
	look.draw.connect(_draw_look)
	add_child(look)
	hidden_layer = get_parent().get_node_or_null(NodePath(PaletteCatalog.HIDDEN_LAYER_NAME)) as HiddenLayer
	if hidden_layer != null:
		hidden_layer.shape_changed.connect(look.queue_redraw)  # a reveal, or a reset
		hidden_layer.crumble_changed.connect(look.queue_redraw)  # the wall crumbling


## Cells changed (see the header): draw again.
func _update_cells(_coords: Array[Vector2i], _forced_cleanup: bool) -> void:
	if look != null:
		look.queue_redraw()


## While a chamber cross-fades (a peek) the cover's alpha changes without a signal of its
## own, so redraw each frame then.
func _process(_delta: float) -> void:
	if hidden_layer != null and not hidden_layer.peek_amounts.is_empty():
		look.queue_redraw()


## How strong the clue at `cell` is, 0..1 (see A CLUE ON A HIDDEN CHAMBER above): 1 where
## there's no chamber under it, or in the editor.
func get_clue_alpha(cell: Vector2i) -> float:
	if hidden_layer == null or hidden_layer.is_editing or hidden_layer.get_cell_source_id(cell) == -1:
		return 1.0
	if hidden_layer.is_covered(cell):
		return hidden_layer.get_cover_alpha(cell) if hidden_layer.is_peeked(cell) else 1.0
	# Opened: only the crumbling cover is left, fading.
	return hidden_layer.get_cover_alpha(cell) if hidden_layer.crumble_clocks.has(cell) else 0.0


## The kind painted at `cell`, or -1 if none.
func get_kind(cell: Vector2i) -> int:
	if get_cell_source_id(cell) == -1:
		return -1
	return get_cell_atlas_coords(cell).x


func _has_kind(cell: Vector2i, kind: Kind) -> bool:
	return get_kind(cell) == kind


## A steady 0..1 number for `cell` (and `salt`, for several per cell): the same on
## every draw, different from cell to cell.
static func cell_random(cell: Vector2i, salt: int) -> float:
	var mixed: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return float(absi(mixed ^ (mixed >> 16)) % 10007) / 10007.0


func _draw_look() -> void:
	for cell: Vector2i in get_used_cells():
		current_alpha = get_clue_alpha(cell)
		if current_alpha <= 0.0:
			continue
		var origin: Vector2 = map_to_local(cell) - Vector2.ONE * TILE / 2.0
		match get_kind(cell):
			Kind.LEAVES:
				_draw_leaves(cell, origin)
			Kind.VINES:
				_draw_strands(cell, origin, Kind.VINES)
			Kind.MOSS:
				_draw_moss(cell, origin)
			Kind.FLOWERS:
				_draw_flowers(cell, origin)
			Kind.ROOTS:
				_draw_strands(cell, origin, Kind.ROOTS)
			Kind.CRACKS:
				_draw_cracks(cell, origin)
			Kind.CLAW_MARKS:
				_draw_claw_marks(cell, origin)
			Kind.FOOTPRINTS:
				_draw_footprints(cell, origin)


## Three fallen leaves: little tilted diamonds in autumn colors.
func _draw_leaves(cell: Vector2i, origin: Vector2) -> void:
	for leaf_index: int in 3:
		var center: Vector2 = origin + Vector2(1.5 + cell_random(cell, leaf_index) * 5.0, 1.5 + cell_random(cell, leaf_index + 10) * 5.0)
		var tilt: float = cell_random(cell, leaf_index + 20) - 0.5
		var color: Color = LEAF_COLORS[int(cell_random(cell, leaf_index + 30) * LEAF_COLORS.size()) % LEAF_COLORS.size()]
		_put_polygon(PackedVector2Array([
			center + Vector2(-1.5, tilt), center + Vector2(0.0, -1.0),
			center + Vector2(1.5, -tilt), center + Vector2(0.0, 1.0)]), color)


## Vines (green, leafy) or roots (brown, twiggy): two strands per column at steady x
## positions, so they run on unbroken through the cells below; where the strand cells
## stop, each strand ends at its own length.
func _draw_strands(cell: Vector2i, origin: Vector2, kind: Kind) -> void:
	var is_vine: bool = kind == Kind.VINES
	var ends_here: bool = not _has_kind(cell + Vector2i.DOWN, kind)
	var column: Vector2i = Vector2i(cell.x, 0)  # per column, not per cell: strands line up
	for strand_index: int in 2:
		var base_x: float = 1.5 + strand_index * 3.5 + cell_random(column, strand_index) * 1.5
		var wobble: float = 0.8 if is_vine else 1.2
		var phase: float = cell_random(column, strand_index + 5) * TAU
		var length: float = TILE
		if ends_here:
			length = lerpf(STRAND_MIN_TIP, STRAND_MAX_TIP, cell_random(cell, strand_index + 40))
		var points: PackedVector2Array = PackedVector2Array()
		for y: int in range(0, int(length) + 1):
			var world_y: float = origin.y + y
			points.append(Vector2(origin.x + base_x + sin(world_y * 0.55 + phase) * wobble, world_y))
		_put_polyline(points, VINE_COLOR if is_vine else ROOT_COLOR, 1.0)
		# Vines: a leaf every few px, side to side; roots: now and then a twig.
		for point_index: int in range(1, points.size(), 3):
			var point: Vector2 = points[point_index]
			var side: float = 1.0 if (int(point_index / 3.0) + strand_index) % 2 == 0 else -2.0
			if is_vine:
				var leaf_color: Color = VINE_LEAF_COLORS[point_index % VINE_LEAF_COLORS.size()]
				_put_rect(Rect2(point + Vector2(side, 0.0), Vector2(1.5, 1.0)), leaf_color)
			elif cell_random(cell, strand_index * 10 + point_index) < 0.35:
				_put_line(point, point + Vector2(side * 1.5, 1.5), ROOT_LIGHT_COLOR, 1.0)
		if is_vine and ends_here:
			_put_rect(Rect2(points[points.size() - 1] + Vector2(-1.0, -0.5), Vector2(2.0, 1.5)), VINE_LEAF_COLORS[1])


## Moss: clumps all over, thinning out at the sides where the moss stops (a ragged edge).
func _draw_moss(cell: Vector2i, origin: Vector2) -> void:
	for clump_index: int in 9:
		var spot: Vector2 = Vector2(cell_random(cell, clump_index) * 7.0, cell_random(cell, clump_index + 50) * 7.0)
		var near_open_side: bool = (spot.x < 2.0 and not _has_kind(cell + Vector2i.LEFT, Kind.MOSS)) \
			or (spot.x > 5.0 and not _has_kind(cell + Vector2i.RIGHT, Kind.MOSS)) \
			or (spot.y < 2.0 and not _has_kind(cell + Vector2i.UP, Kind.MOSS)) \
			or (spot.y > 5.0 and not _has_kind(cell + Vector2i.DOWN, Kind.MOSS))
		if near_open_side and cell_random(cell, clump_index + 70) < 0.6:
			continue
		var size: Vector2 = Vector2(2.0, 1.0) if clump_index % 3 == 0 else Vector2(1.0, 1.0)
		_put_rect(Rect2(origin + spot, size), MOSS_COLORS[clump_index % MOSS_COLORS.size()])


## Two little flowers standing at the bottom of the cell: a stem, a leaf, a bloom.
func _draw_flowers(cell: Vector2i, origin: Vector2) -> void:
	for flower_index: int in 2:
		var x: float = 1.0 + flower_index * 4.0 + cell_random(cell, flower_index) * 2.0
		var height: float = 3.0 + floorf(cell_random(cell, flower_index + 10) * 3.0)
		var foot: Vector2 = origin + Vector2(x, TILE)
		_put_rect(Rect2(foot - Vector2(0.0, height), Vector2(1.0, height)), STEM_COLOR)
		_put_rect(Rect2(foot + Vector2(1.0, -2.0), Vector2(1.0, 1.0)), STEM_COLOR)
		var petal: Color = PETAL_COLORS[int(cell_random(cell, flower_index + 20) * PETAL_COLORS.size()) % PETAL_COLORS.size()]
		var bloom: Vector2 = foot - Vector2(0.0, height + 1.0)
		_put_rect(Rect2(bloom + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), petal)
		_put_rect(Rect2(bloom + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), petal)


## Cracks: from a point near the middle to the shared edge of SOME cracked neighbours
## (the edge point is the same for both cells, so the crack runs on), and a short
## zigzag in a cell on its own. Not every neighbour: joining all four made a patch read
## as a grid. Up-down links are likely, sideways ones rare (CRACK_*_LINK_CHANCE), and
## the choice is hashed from the edge, so both cells agree.
func _draw_cracks(cell: Vector2i, origin: Vector2) -> void:
	var middle: Vector2 = origin + Vector2(3.0 + cell_random(cell, 1) * 2.0, 3.0 + cell_random(cell, 2) * 2.0)
	var joined: int = 0
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour: Vector2i = cell + direction
		if not _has_kind(neighbour, Kind.CRACKS):
			continue
		# The edge's own numbers: hashed from the first of the two cells, so both agree.
		var edge_key: Vector2i = cell if (direction == Vector2i.RIGHT or direction == Vector2i.DOWN) else neighbour
		var link_chance: float = CRACK_SIDEWAYS_LINK_CHANCE if direction.x != 0 else CRACK_VERTICAL_LINK_CHANCE
		if cell_random(edge_key, 9 if direction.x != 0 else 11) >= link_chance:
			continue
		joined += 1
		var along: float = 2.0 + cell_random(edge_key, 7 if direction.x != 0 else 8) * 4.0
		var edge_point: Vector2
		match direction:
			Vector2i.LEFT:
				edge_point = origin + Vector2(0.0, along)
			Vector2i.RIGHT:
				edge_point = origin + Vector2(TILE, along)
			Vector2i.UP:
				edge_point = origin + Vector2(along, 0.0)
			_:
				edge_point = origin + Vector2(along, TILE)
		_draw_scratch(middle, edge_point)
	if joined == 0:
		_draw_scratch(origin + Vector2(1.0, 2.0 + cell_random(cell, 3) * 2.0), middle)
		_draw_scratch(middle, origin + Vector2(7.0, 4.0 + cell_random(cell, 4) * 2.0))
	if cell_random(cell, 5) < 0.4:  # a little branch
		_draw_scratch(middle, middle + Vector2(cell_random(cell, 6) * 4.0 - 2.0, 2.5))


## Three deep claw scratches raking down the whole column of claw-mark cells this
## cell is in (from the top of the painted strip to its bottom, leaning a little), so
## a strip reads as one long set of marks, not a hatch repeated tile by tile.
func _draw_claw_marks(cell: Vector2i, origin: Vector2) -> void:
	var run_top: int = cell.y
	while _has_kind(Vector2i(cell.x, run_top - 1), Kind.CLAW_MARKS):
		run_top -= 1
	var run_bottom: int = cell.y
	while _has_kind(Vector2i(cell.x, run_bottom + 1), Kind.CLAW_MARKS):
		run_bottom += 1
	var run_height: float = (run_bottom - run_top + 1) * TILE - 1.0
	var run_start_y: float = origin.y - (cell.y - run_top) * TILE + 0.5
	# The lean across the whole strip, px: steeper for a short strip.
	var lean: float = clampf(run_height * 0.35, 3.0, 6.0)
	var top_y: float = maxf(origin.y, run_start_y)
	var bottom_y: float = minf(origin.y + TILE, run_start_y + run_height)
	for mark_index: int in 3:
		var top_x: float = origin.x + 1.0 + mark_index * CLAW_SPACING + lean / 2.0
		var x_at_top: float = top_x - lean * (top_y - run_start_y) / run_height
		var x_at_bottom: float = top_x - lean * (bottom_y - run_start_y) / run_height
		# Dark only: with the light edge the three ran together into one band.
		_put_line(Vector2(x_at_top, top_y), Vector2(x_at_bottom, bottom_y), SCRATCH_COLOR, 1.0)


## One footprint per cell at its bottom, left and right feet taking turns.
func _draw_footprints(cell: Vector2i, origin: Vector2) -> void:
	var is_left_foot: bool = posmod(cell.x, 2) == 0
	var foot: Vector2 = origin + Vector2(2.0 if is_left_foot else 4.0, 6.0 if is_left_foot else 7.0)
	_put_rect(Rect2(foot, Vector2(3.0, 1.0)), FOOTPRINT_COLOR)  # the sole
	_put_rect(Rect2(foot + Vector2(2.0, -1.0), Vector2(1.0, 1.0)), FOOTPRINT_COLOR)  # the toes


## A carved line: dark, with a faint light edge beside it.
func _draw_scratch(from: Vector2, to: Vector2) -> void:
	_put_line(from, to, SCRATCH_COLOR, 1.0)
	_put_line(from + Vector2(1.0, 0.0), to + Vector2(1.0, 0.0), SCRATCH_LIGHT_COLOR, 1.0)


# --- Drawing helpers: the look's draw calls with the cell's opacity multiplied in ---

func _faded(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * current_alpha)


func _put_polygon(points: PackedVector2Array, color: Color) -> void:
	look.draw_colored_polygon(points, _faded(color))


func _put_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	look.draw_polyline(points, _faded(color), width)


func _put_rect(rect: Rect2, color: Color) -> void:
	look.draw_rect(rect, _faded(color))


func _put_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	look.draw_line(from, to, _faded(color), width)
