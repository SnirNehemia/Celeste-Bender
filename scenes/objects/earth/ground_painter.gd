class_name GroundPainter
extends Node2D
## GroundPainter (Stage E4b): draws a room's ground so it looks like lumpy earth, turf
## and stone instead of a grid of tiles, in the style of Celeste's ground: a bright
## CRUST along every surface with a blobby inner edge, and a dark, saturated, HATCHED
## inside. The layout and collision stay tile-based: the room's TileMapLayers ("Tiles"
## gray, "Grass", "Earth") keep their collision, but their own drawing is switched off
## (self_modulate = transparent; children such as the grass blades still draw).
##
## Made by Room._ready() for rooms that have an "Earth" layer (the Earth chapter and
## the mixed rooms): Room adds it right after the tile layers, so objects draw on top.
##
## HOW: the whole room's ground is ONE picture (an Image the size of the room, turned
## into an ImageTexture), computed pixel by pixel in three steps:
##   1. MASK: which pixels are ground, and of which kind (_build_mask). Tiles fill
##      their 8x8 pixels, except along open air: exposed sides get 1-2 px dents (the
##      same every run: a hash of the pixel's world position), bottom convex corners are
##      rounded (top corners stay square, so a platform's edge is where you can stand),
##      concave corners get a small fillet, and borders between kinds (earth against
##      grass or stone) interlock in small teeth.
##   2. DISTANCE: how far each ground pixel is from open air (_compute_distances), with
##      a "distance transform": two sweeps over the picture, each pixel taking the
##      smallest of its neighbours' distances + 1 (+1.41 diagonally). Like a BFS, but
##      cheaper on a pixel grid.
##   3. COLOR (_get_pixel_color), from the distance:
##        crust     the kind's bright body color, a few px thick. Its inner edge wobbles
##                  with smooth "value noise" (random numbers on a coarse grid, blended
##                  between grid points), which makes the blobby, scalloped look.
##                  Top surfaces get a lighter rim (grass: 2 px).
##        edge line a 1 px darker line where the crust ends
##        inside    a dark saturated shade of the kind, with diagonal hatch stripes,
##                  darkening to almost black a few px further in
##      (There used to be FLECKS, crumbs floating above top surfaces: removed after
##      play-testing, they read as stray pixels. E4d's pebbles do that job.)
## EARTH STATES (used: darker plus crack lines, hardened: grayer, shivering: flicker)
## are drawn on a child OVERLAY: each such tile's 8x8 piece of the picture again,
## tinted by EarthLayer.get_cell_modulate(). Only the overlay redraws while a bend
## animates.
##
## HIDDEN CHAMBERS (Stage E4c): cells of the room's "Hidden" layer (HiddenLayer) are
## open air, but drawn as earth while covered, so a buried tunnel looks like deep
## earth. When a dug hole reaches one, we copy the picture first (_on_chamber_revealed),
## redraw the ground with the chamber open, and draw the copied cover on a second
## child, the COVER, fading and sinking cell by cell (HiddenLayer.get_cover_alpha).
##
## BURNT GRASS (Stage F5): in rooms with a FireGrid, grass cells that caught fire are
## painted with other palettes (FIRE_PALETTES): scorched while burning, charred while
## smoldering, ash (dark gray crust with pale flecks) for good. The border between
## burnt and unburnt cells wanders in blobs (_get_fire_state_at), so it never shows
## the tile grid. The shape doesn't change, so only the changed cells' pixels (plus
## a small margin) are repainted (_on_fire_cells_changed).
##
## THICKET and OVERGROWN COVERS (Stage F6): the room's "Thicket" layer (ThicketLayer)
## is drawn as dark tangled brambles: criss-crossing branch strokes through crust and
## inside (_is_bramble_branch), and thorns poking 1-2 px out of its sides and
## underside (_mask_thorns; never on top, where you stand). Burning thicket gets a
## charred palette with ember-red branches (the FireGrid's glow layer adds the inner
## glow on top). Cells that burnt away are gone from the layer, so they're air here.
## "Overgrown" cells (OvergrownLayer) are drawn as grass or thicket (whichever they
## pass for), their crust a shade off (OVERGROWN_TINT): one half of the tell; the
## layer draws the root tendrils itself. A covered HiddenLayer chamber touching a
## cover is drawn in the cover's kind instead of earth.
## Thicket crumbling and covers collapsing change the shape many times in a row, so
## those redraws are batched: one per frame at most (_queue_rebuild).
##
## Updates: when only some cells changed (a tear, an opened chamber, a reset filling
## holes) only the pixels near them are recomputed; the first build does everything.

enum Kind { AIR, GRAY, GRASS, EARTH, THICKET }

## Crust thickness, px (from open air to where the edge line starts)...
const CRUST_WIDTH: float = 5.0
## ...wobbling by up to this much either way, px...
const CRUST_WOBBLE: float = 2.0
## ...with the wobble's random grid this many px apart (bigger = broader blobs).
const CRUST_NOISE_SPACING: int = 5
## Diagonal hatch on the inside: a stripe HATCH_WIDTH px wide every HATCH_PERIOD px.
const HATCH_PERIOD: int = 6
const HATCH_WIDTH: int = 2
## Right past the edge line the inside is this fraction of its palette color...
const INSIDE_EDGE_BRIGHTNESS: float = 0.7
## ...darkening over this many px further in...
const INSIDE_FADE_DEPTH: float = 10.0
## ...down to this fraction: almost black, so deep ground reads as solid mass and a
## hidden chamber opening up in it (Stage E4c) stands out. The hatch stays faintly
## visible.
const INSIDE_DEEPEST_BRIGHTNESS: float = 0.12
## Chance (0..1) that a 2 px stretch of an exposed side is dented 1 px in...
const EDGE_DENT_CHANCE: float = 0.35
## ...and 2 px in. Never 2 on TOP surfaces: feet would look like they float.
const DEEP_DENT_CHANCE: float = 0.15
## Bottom convex corners: pixels with (distance from the corner along x + along y)
## below this are cut off. 3 = a 6-pixel rounding.
const CORNER_CUT: int = 3
## A tear recomputes the pixels within this many tiles of the hole (enough to cover
## the crust and the inside's fade).
const TEAR_REDRAW_RADIUS: int = 5
## Thicket burning away (Stage F6) redraws only this many tiles around the change:
## colors stop changing ~17 px in (crust + its wobble + the inside's fade), and a
## smaller area keeps the redraw short, since it runs several times a second while
## thicket burns (~25-45 ms at 5 tiles, too long for one frame).
const BURN_REDRAW_RADIUS: int = 3

## Palette per kind (Celeste-like: bright crust, deep saturated inside).
## [crust, rim (top surfaces), edge line, inside, hatch stripe]
const PALETTE: Dictionary = {
	Kind.EARTH: [Color(0.74, 0.57, 0.27), Color(0.88, 0.72, 0.42), Color(0.42, 0.24, 0.12),
		Color(0.26, 0.12, 0.09), Color(0.33, 0.17, 0.11)],
	Kind.GRASS: [Color(0.33, 0.6, 0.25), GrassLayer.BLADE_COLOR, Color(0.1, 0.3, 0.13),
		Color(0.05, 0.19, 0.11), Color(0.08, 0.26, 0.14)],
	Kind.GRAY: [Color(0.36, 0.37, 0.43), Color(0.52, 0.52, 0.58), Color(0.18, 0.18, 0.23),
		Color(0.1, 0.1, 0.15), Color(0.14, 0.14, 0.2)],
}
## Thicket (Stage F6): [crust, rim, edge line, inside, hatch stripe, branch, thorn].
const THICKET_PALETTE: Array[Color] = [Color(0.15, 0.3, 0.15), Color(0.22, 0.4, 0.18), Color(0.04, 0.1, 0.05),
	Color(0.05, 0.12, 0.07), Color(0.07, 0.16, 0.08), Color(0.27, 0.39, 0.16), Color(0.36, 0.27, 0.14)]
## Burning thicket, same order: charred, its branches ember red.
const THICKET_BURNING_PALETTE: Array[Color] = [Color(0.14, 0.09, 0.06), Color(0.3, 0.13, 0.05), Color(0.05, 0.03, 0.02),
	Color(0.06, 0.04, 0.03), Color(0.09, 0.05, 0.03), Color(0.55, 0.2, 0.05), Color(0.22, 0.1, 0.05)]
## Overgrown covers' crust is pulled this far toward OVERGROWN_TINT (a dry, yellowish
## shade): the cover's subtle tell. 0 = no difference.
const OVERGROWN_TINT: Color = Color(0.55, 0.52, 0.2)
const OVERGROWN_TINT_AMOUNT: float = 0.14
## Thorns: about one 2 px stretch of a thicket side in this many gets one.
const THORN_EVERY: int = 3

## Burnt grass, per FireGrid.State (Stage F5), in the same order as PALETTE, plus a
## sixth color for ash: its pale flecks (Fire_bending.md §9.1).
const FIRE_PALETTES: Dictionary = {
	FireGrid.State.BURNING: [Color(0.36, 0.27, 0.12), Color(0.52, 0.24, 0.08), Color(0.16, 0.1, 0.05),
		Color(0.05, 0.12, 0.07), Color(0.08, 0.16, 0.09)],
	FireGrid.State.SMOLDERING: [Color(0.12, 0.1, 0.1), Color(0.2, 0.12, 0.09), Color(0.06, 0.05, 0.05),
		Color(0.06, 0.07, 0.06), Color(0.08, 0.09, 0.08)],
	FireGrid.State.ASH: [Color("#4A4545"), Color("#5E5858"), Color(0.2, 0.19, 0.19),
		Color(0.1, 0.1, 0.1), Color(0.13, 0.12, 0.12), Color("#7A7470")],
}
## On ash, about one crust pixel in this many is a pale fleck.
const ASH_FLECK_EVERY: int = 7
## The border between burnt and unburnt grass wanders up to this many px either side
## of the tile edge (smooth noise), so burnt ground is blobby, not square.
const FIRE_EDGE_RAGGEDNESS: float = 3.0
## Crack lines on used earth (overlay).
const CRACK_COLOR: Color = Color(0.15, 0.09, 0.05)

## The room we draw (our parent) and its layers.
var room: Room
var earth_layer: EarthLayer
var gray_layer: TileMapLayer
var grass_layer: TileMapLayer
var hidden_layer: HiddenLayer
## Thicket and overgrown covers (Stage F6), or null.
var thicket_layer: ThicketLayer
var overgrown_layer: OvergrownLayer
## Cells drawn as part of an overgrown cover (a set), for OVERGROWN_TINT.
var overgrown_cells: Dictionary = {}
## True while a batched rebuild waits for the end of the frame (_queue_rebuild).
var is_rebuild_queued: bool = false
## The room's FireGrid (Stage F5), or null: burnt grass gets FIRE_PALETTES.
var fire_grid: FireGrid
## True while a repainted picture waits to be uploaded (see _on_fire_cells_changed).
var is_upload_queued: bool = false
var tile_size: int = 8
## The room's cells: (0, 0) to room_size / tile_size. Outside counts as solid ground.
var cell_bounds: Rect2i
## Picture size, px (whole tiles).
var width: int = 0
var height: int = 0
## Solid cells -> Kind.
var kinds: Dictionary = {}
## Per pixel (index = y * width + x): the Kind there (0 = air), and the distance to
## the nearest open-air pixel (0 for air).
var pixel_kinds: PackedByteArray = PackedByteArray()
var distances: PackedFloat32Array = PackedFloat32Array()
## The crust's wobble: random -1..1 values on a coarse grid (see CRUST_NOISE_SPACING).
var noise_grid: PackedFloat32Array = PackedFloat32Array()
var noise_columns: int = 0
## The picture and the texture drawn from it.
var image: Image
var texture: ImageTexture
## Child node drawing the earth states on top (see the header).
var overlay: Node2D
## Child node drawing a hidden chamber's crumbling cover, from a copy of the picture
## taken just before the chamber opened (see the header).
var cover: Node2D
var cover_image: Image
var cover_texture: ImageTexture


func _ready() -> void:
	room = get_parent() as Room
	earth_layer = room.get_node_or_null("Earth") as EarthLayer
	gray_layer = room.get_node_or_null("Tiles") as TileMapLayer
	grass_layer = room.get_node_or_null("Grass") as TileMapLayer
	hidden_layer = room.get_node_or_null("Hidden") as HiddenLayer
	thicket_layer = room.get_node_or_null("Thicket") as ThicketLayer
	overgrown_layer = room.get_node_or_null("Overgrown") as OvergrownLayer
	fire_grid = room.get_node_or_null("FireGrid") as FireGrid
	if earth_layer != null:
		tile_size = earth_layer.tile_set.tile_size.x
	cell_bounds = Rect2i(Vector2i.ZERO, Vector2i((room.room_size / tile_size).ceil()))
	width = cell_bounds.size.x * tile_size
	height = cell_bounds.size.y * tile_size
	# Hide the layers' own tiles (collision stays). self_modulate tints only the node
	# itself, not its children, so the grass blades (a child of "Grass") still draw.
	for layer: TileMapLayer in [gray_layer, grass_layer, earth_layer, hidden_layer, thicket_layer, overgrown_layer]:
		if layer != null:
			layer.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_build_noise_grid()
	overlay = Node2D.new()
	overlay.name = "EarthStates"
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	# Added after the overlay, so it draws on top of it.
	cover = Node2D.new()
	cover.name = "ChamberCover"
	add_child(cover)
	cover.draw.connect(_draw_cover)
	if earth_layer != null:
		earth_layer.shape_changed.connect(rebuild)
		earth_layer.look_changed.connect(overlay.queue_redraw)
	if hidden_layer != null:
		hidden_layer.chamber_revealed.connect(_on_chamber_revealed)
		hidden_layer.shape_changed.connect(rebuild)
		hidden_layer.crumble_changed.connect(cover.queue_redraw)
	if fire_grid != null:
		fire_grid.cells_changed.connect(_on_fire_cells_changed)
	if thicket_layer != null:
		thicket_layer.shape_changed.connect(_queue_rebuild)
	if overgrown_layer != null:
		overgrown_layer.shape_changed.connect(_queue_rebuild)
	rebuild()


# --- Questions (tests, debugging) ----------------------------------------------------

## The ground's color at a pixel of the room (local px), or transparent for air.
func get_pixel_color(pixel: Vector2i) -> Color:
	return image.get_pixelv(pixel)


## Distance (px) from a room pixel to the nearest open air: 0 for air.
func get_pixel_distance(pixel: Vector2i) -> float:
	return distances[pixel.y * width + pixel.x]


# --- Rebuilding ----------------------------------------------------------------------

## Recomputes the picture. When some cells changed (a tear, an opened chamber, holes
## filled by a reset) only the pixels within TEAR_REDRAW_RADIUS tiles of them are
## redone; the first build (or a rebuild with nothing changed) redoes it all, unless
## `only_if_changed` (then nothing changed = nothing to do). `redraw_radius`: how many
## tiles around the changed cells are redone.
func rebuild(only_if_changed: bool = false, redraw_radius: int = TEAR_REDRAW_RADIUS) -> void:
	var previous_kinds: Dictionary = kinds.duplicate()
	_find_kinds()
	var region: Rect2i = Rect2i(0, 0, width, height)
	if image != null:
		# Which cells changed since last time (appeared, disappeared, another kind)?
		var changed: Array[Vector2i] = []
		for cell: Vector2i in previous_kinds:
			if not kinds.has(cell) or kinds[cell] != previous_kinds[cell]:
				changed.append(cell)
		for cell: Vector2i in kinds:
			if not previous_kinds.has(cell):
				changed.append(cell)
		if changed.is_empty() and only_if_changed:
			return
		if not changed.is_empty():
			# The smallest rectangle of cells holding every change, grown by the radius.
			var changed_cells: Rect2i = Rect2i(changed[0], Vector2i.ONE)
			for cell: Vector2i in changed:
				changed_cells = changed_cells.expand(cell).expand(cell + Vector2i.ONE)
			changed_cells = changed_cells.grow(redraw_radius)
			region = Rect2i(changed_cells.position * tile_size, changed_cells.size * tile_size) \
				.intersection(Rect2i(0, 0, width, height))
	if region.size == Vector2i(width, height) or image == null:
		_build_mask(Rect2i(Vector2i.ZERO, cell_bounds.size))
		_compute_distances(Rect2i(0, 0, width, height))
		image = Image.create(width, height, false, Image.FORMAT_RGBA8)
		_paint(Rect2i(0, 0, width, height))
		texture = ImageTexture.create_from_image(image)
	else:
		var cell_region: Rect2i = Rect2i(region.position / tile_size, region.size / tile_size)
		_build_mask(cell_region)
		_compute_distances(region)
		_paint(region)
		texture.update(image)
	queue_redraw()
	overlay.queue_redraw()


## Thicket burnt away or a cover collapsed or came back: redraw once at the end of
## the frame, however many times it changed (call_deferred).
func _queue_rebuild() -> void:
	if is_rebuild_queued:
		return
	is_rebuild_queued = true
	_run_queued_rebuild.call_deferred()


func _run_queued_rebuild() -> void:
	is_rebuild_queued = false
	rebuild(true, BURN_REDRAW_RADIUS)


## Which kind fills each cell: earth wins over grass over gray over thicket over a
## cover (drawn as what it passes for). A covered hidden chamber is drawn as earth,
## or as the cover it touches.
func _find_kinds() -> void:
	kinds.clear()
	overgrown_cells.clear()
	for x: int in range(cell_bounds.position.x, cell_bounds.end.x):
		for y: int in range(cell_bounds.position.y, cell_bounds.end.y):
			var cell: Vector2i = Vector2i(x, y)
			var kind: Kind = Kind.AIR
			if earth_layer != null and earth_layer.is_earth(cell):
				kind = Kind.EARTH
			elif grass_layer != null and grass_layer.get_cell_source_id(cell) != -1:
				kind = Kind.GRASS
			elif gray_layer != null and gray_layer.get_cell_source_id(cell) != -1:
				kind = Kind.GRAY
			elif thicket_layer != null and thicket_layer.has_thicket(cell):
				kind = Kind.THICKET
			elif overgrown_layer != null and overgrown_layer.has_cover(cell):
				kind = Kind.THICKET if overgrown_layer.is_thicket_look(cell) else Kind.GRASS
				overgrown_cells[cell] = true
			elif hidden_layer != null and hidden_layer.is_covered(cell):
				kind = Kind.EARTH
			if kind != Kind.AIR:
				kinds[cell] = kind
	_give_chambers_their_cover_look()


## Covered hidden chambers behind an overgrown cover take the cover's kind (a flood
## fill from the cover through the covered cells), so a thicket cover doesn't have
## earth behind it.
func _give_chambers_their_cover_look() -> void:
	if hidden_layer == null or overgrown_cells.is_empty():
		return
	var queue: Array[Vector2i] = []
	var looks: Dictionary = {}
	for cover_cell: Vector2i in overgrown_cells:
		for direction: Vector2i in EarthLayer.FACE_NORMALS:
			var neighbour: Vector2i = cover_cell + direction
			if hidden_layer.is_covered(neighbour) and not looks.has(neighbour):
				looks[neighbour] = kinds[cover_cell]
				queue.append(neighbour)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction: Vector2i in EarthLayer.FACE_NORMALS:
			var neighbour: Vector2i = cell + direction
			if hidden_layer.is_covered(neighbour) and not looks.has(neighbour):
				looks[neighbour] = looks[cell]
				queue.append(neighbour)
	for cell: Vector2i in looks:
		kinds[cell] = looks[cell]


## True for open cells inside the room. Outside the room counts as solid, so the
## room's outer walls don't get edges on their far side.
func _is_air(cell: Vector2i) -> bool:
	return cell_bounds.has_point(cell) and not kinds.has(cell)


# --- 1. Mask ---------------------------------------------------------------------------

## Fills pixel_kinds for the cells in `cell_region` (plus fillets reaching into it).
func _build_mask(cell_region: Rect2i) -> void:
	if pixel_kinds.size() != width * height:
		pixel_kinds.resize(width * height)
	for x: int in range(cell_region.position.x, cell_region.end.x):
		for y: int in range(cell_region.position.y, cell_region.end.y):
			_mask_cell(Vector2i(x, y))
	# Teeth and fillets reach across cell borders, so do them after every cell is filled.
	for x: int in range(cell_region.position.x, cell_region.end.x):
		for y: int in range(cell_region.position.y, cell_region.end.y):
			var cell: Vector2i = Vector2i(x, y)
			if kinds.has(cell):
				_mask_material_teeth(cell)
			else:
				_mask_fillets(cell)
				_mask_thorns(cell)


## One cell's pixels: all its kind if buried; dented and cut if it touches open air.
func _mask_cell(cell: Vector2i) -> void:
	var kind: int = kinds.get(cell, Kind.AIR)
	var exposed: Dictionary = {}
	if kind != Kind.AIR:
		for direction: Vector2i in EarthLayer.FACE_NORMALS:
			if _is_air(cell + direction):
				exposed[direction] = true
	var inside: Callable = _make_inside_test(cell, exposed)
	var origin: Vector2i = cell * tile_size
	for y: int in tile_size:
		for x: int in tile_size:
			var is_ground: bool = kind != Kind.AIR and (exposed.is_empty() or inside.call(x, y))
			pixel_kinds[(origin.y + y) * width + origin.x + x] = kind if is_ground else Kind.AIR


## A function (x, y) -> bool, pixel coordinates 0..tile_size-1 inside `cell`: is
## this pixel ground? Exposed sides are dented and bottom corners rounded.
## Callable = a function stored in a variable, like a Python lambda; it "captures"
## the arrays below, so later calls still see them.
func _make_inside_test(cell: Vector2i, exposed: Dictionary) -> Callable:
	var last: int = tile_size - 1
	# Dent depth per pixel along each side: top/bottom per column x, left/right per row y.
	var top: Array[int] = []
	var bottom: Array[int] = []
	var left: Array[int] = []
	var right: Array[int] = []
	var world_pixel: Vector2i = cell * tile_size
	for i: int in tile_size:
		top.append(_get_dent(exposed.has(Vector2i.UP), world_pixel.x + i, world_pixel.y, 0))
		bottom.append(_get_dent(exposed.has(Vector2i.DOWN), world_pixel.x + i, world_pixel.y + tile_size, 1))
		left.append(_get_dent(exposed.has(Vector2i.LEFT), world_pixel.y + i, world_pixel.x, 2))
		right.append(_get_dent(exposed.has(Vector2i.RIGHT), world_pixel.y + i, world_pixel.x + tile_size, 3))
	# No dents on the two outermost pixels of a top surface at a platform's edge:
	# that's exactly where an edge-standing player's feet are.
	if exposed.has(Vector2i.UP):
		if exposed.has(Vector2i.LEFT):
			top[0] = 0
			top[1] = 0
		if exposed.has(Vector2i.RIGHT):
			top[last] = 0
			top[last - 1] = 0
	# Only BOTTOM corners are rounded: a rounded top corner shaves the very edge of a
	# platform, and a player standing on it looked like they stood on air.
	var cut_bottom_left: bool = exposed.has(Vector2i.DOWN) and exposed.has(Vector2i.LEFT)
	var cut_bottom_right: bool = exposed.has(Vector2i.DOWN) and exposed.has(Vector2i.RIGHT)
	return func(x: int, y: int) -> bool:
		if y < top[x] or last - y < bottom[x] or x < left[y] or last - x < right[y]:
			return false
		if cut_bottom_left and x + (last - y) < CORNER_CUT:
			return false
		if cut_bottom_right and (last - x) + (last - y) < CORNER_CUT:
			return false
		return true


## How deep (0, 1 or 2 px) one pixel of an exposed side is dented, the same every
## run: a hash of its world position. `along` = the pixel's position along the side,
## `line` = the side's own coordinate, `side` = 0 top, 1 bottom, 2 left, 3 right.
## along / 2: dents are 2 px wide. Neighbouring cells on the same straight edge agree.
func _get_dent(is_exposed: bool, along: int, line: int, side: int) -> int:
	if not is_exposed:
		return 0
	var roll: int = hash(Vector3i(along / 2, line, side)) % 1000
	if side != 0 and roll < int(DEEP_DENT_CHANCE * 1000.0):
		return 2
	return 1 if roll < int(EDGE_DENT_CHANCE * 1000.0) else 0


## Borders between kinds interlock: along an edge between this cell and a neighbour
## of another kind, each 2 px stretch either stays straight or lets one side poke
## 1-2 px into the other (a hash decides; both cells ask the same question). Here we
## only paint the neighbour's teeth that poke INTO this cell, on ground pixels.
func _mask_material_teeth(cell: Vector2i) -> void:
	var kind: int = kinds[cell]
	var last: int = tile_size - 1
	var origin: Vector2i = cell * tile_size
	for direction: Vector2i in EarthLayer.FACE_NORMALS:
		var neighbour: Vector2i = cell + direction
		if not kinds.has(neighbour) or kinds[neighbour] == kind:
			continue
		var is_vertical_edge: bool = direction.x != 0
		var line: int = 0
		if is_vertical_edge:
			line = origin.x + (tile_size if direction.x > 0 else 0)
		else:
			line = origin.y + (tile_size if direction.y > 0 else 0)
		# "Low" side = the left / top cell of the pair; a positive tooth pokes from the
		# low side into the high side. We're the high side when the neighbour is left/up.
		var we_are_high_side: bool = direction.x < 0 or direction.y < 0
		for i: int in tile_size:
			var along: int = (origin.y if is_vertical_edge else origin.x) + i
			var tooth: int = _get_tooth(along, line, is_vertical_edge)
			var depth_into_us: int = tooth if we_are_high_side else -tooth
			for step: int in depth_into_us:
				var pixel: Vector2i
				if is_vertical_edge:
					pixel = Vector2i(step if direction.x < 0 else last - step, i)
				else:
					pixel = Vector2i(i, step if direction.y < 0 else last - step)
				var index: int = (origin.y + pixel.y) * width + origin.x + pixel.x
				if pixel_kinds[index] != Kind.AIR:
					pixel_kinds[index] = kinds[neighbour]


## How far (and which way) the material border pokes at one 2 px stretch of an edge:
## -2..2 px; positive = the left/top side pokes into the right/bottom side.
func _get_tooth(along: int, line: int, is_vertical_edge: bool) -> int:
	var roll: int = hash(Vector3i(along / 2, line, 10 if is_vertical_edge else 11)) % 100
	if roll < 30:
		return 0
	if roll < 55:
		return 1
	if roll < 80:
		return -1
	return 2 if roll < 90 else -2


## Concave (inner) corners: an open cell with ground on two sides that meet (a floor
## and a wall) gets a small 3-pixel fillet of the floor's (or ceiling's) ground.
func _mask_fillets(cell: Vector2i) -> void:
	if not cell_bounds.has_point(cell):
		return
	var last: int = tile_size - 1
	var origin: Vector2i = cell * tile_size
	for vertical: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
		if not kinds.has(cell + vertical):
			continue
		for horizontal: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if not kinds.has(cell + horizontal):
				continue
			var corner: Vector2i = Vector2i(0 if horizontal.x < 0 else last, 0 if vertical.y < 0 else last)
			for pixel: Vector2i in [corner, corner - Vector2i(horizontal.x, 0), corner - Vector2i(0, vertical.y)]:
				pixel_kinds[(origin.y + pixel.y) * width + origin.x + pixel.x] = kinds[cell + vertical]


## Thorns (Stage F6): an open cell with thicket on its left, right or top side (the
## thicket's right side, left side or underside) gets a few thorns poking 1-2 px
## into it, 1 px wide, at hashed spots. Never above thicket: its top is ground you
## stand on, and thorns there would read as spikes.
func _mask_thorns(cell: Vector2i) -> void:
	if not cell_bounds.has_point(cell):
		return
	var last: int = tile_size - 1
	var origin: Vector2i = cell * tile_size
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if kinds.get(cell + direction, Kind.AIR) != Kind.THICKET:
			continue
		for i: int in tile_size:
			var along: int = (origin.y if direction.x != 0 else origin.x) + i
			# & 0x7FFFFFFF keeps the hash positive, so % never goes negative.
			var roll: int = hash(Vector3i(along / 2, origin.x * 3 + origin.y * 7, direction.x + direction.y * 3)) & 0x7FFFFFFF
			# Only the even pixel of a chosen 2 px stretch: thorns stay 1 px thin.
			if roll % THORN_EVERY != 0 or along % 2 != 0:
				continue
			var length: int = 2 if (roll >> 4) % 2 == 0 else 1
			for step: int in length:
				var pixel: Vector2i
				match direction:
					Vector2i.LEFT:
						pixel = Vector2i(step, i)
					Vector2i.RIGHT:
						pixel = Vector2i(last - step, i)
					_:
						pixel = Vector2i(i, step)
				var index: int = (origin.y + pixel.y) * width + origin.x + pixel.x
				if pixel_kinds[index] == Kind.AIR:
					pixel_kinds[index] = Kind.THICKET


# --- 2. Distance -----------------------------------------------------------------------

## Distance from every ground pixel in `region` to the nearest open air, by a two-pass
## distance transform: a forward sweep (top-left to bottom-right) lets each pixel take
## "my up/left neighbour's distance + 1", a backward sweep does the same from the
## other side; together every pixel gets (close to) its true distance. Pixels outside
## `region` keep their old values and act as known borders. Outside the room = solid.
func _compute_distances(region: Rect2i) -> void:
	if distances.size() != width * height:
		distances.resize(width * height)
	var far: float = 9999.0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var index: int = y * width + x
			distances[index] = 0.0 if pixel_kinds[index] == Kind.AIR else far
	var diagonal: float = 1.414
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var index: int = y * width + x
			var best: float = distances[index]
			if best == 0.0:
				continue
			if x > 0:
				best = minf(best, distances[index - 1] + 1.0)
			if y > 0:
				best = minf(best, distances[index - width] + 1.0)
				if x > 0:
					best = minf(best, distances[index - width - 1] + diagonal)
				if x < width - 1:
					best = minf(best, distances[index - width + 1] + diagonal)
			distances[index] = best
	for y: int in range(region.end.y - 1, region.position.y - 1, -1):
		for x: int in range(region.end.x - 1, region.position.x - 1, -1):
			var index: int = y * width + x
			var best: float = distances[index]
			if best == 0.0:
				continue
			if x < width - 1:
				best = minf(best, distances[index + 1] + 1.0)
			if y < height - 1:
				best = minf(best, distances[index + width] + 1.0)
				if x < width - 1:
					best = minf(best, distances[index + width + 1] + diagonal)
				if x > 0:
					best = minf(best, distances[index + width - 1] + diagonal)
			distances[index] = best


# --- 3. Color --------------------------------------------------------------------------

## Writes the colors of every pixel in `region` into the image.
func _paint(region: Rect2i) -> void:
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			image.set_pixel(x, y, _get_pixel_color(x, y))


## One pixel's color (see the header, step 3).
func _get_pixel_color(x: int, y: int) -> Color:
	var index: int = y * width + x
	var kind: int = pixel_kinds[index]
	if kind == Kind.AIR:
		return Color(0.0, 0.0, 0.0, 0.0)
	if kind == Kind.THICKET:
		return _get_thicket_pixel_color(x, y, index)
	var colors: Array = PALETTE[kind]
	var is_ash: bool = false
	if kind == Kind.GRASS and fire_grid != null:
		var fire_state: FireGrid.State = _get_fire_state_at(x, y)
		if FIRE_PALETTES.has(fire_state):
			colors = FIRE_PALETTES[fire_state]
			is_ash = fire_state == FireGrid.State.ASH
	return _tint_if_overgrown(x, y, index, _get_layered_color(x, y, index, kind, colors, is_ash))


## A ground pixel's crust / edge line / hatched inside, in the palette `colors` (the
## header's step 3).
func _get_layered_color(x: int, y: int, index: int, kind: int, colors: Array, is_ash: bool) -> Color:
	var depth: float = distances[index] - 1.0  # 0 on the outermost ground pixel
	var crust_end: float = CRUST_WIDTH + _get_noise(x, y) * CRUST_WOBBLE
	if depth < crust_end - 1.0:
		# Rim along top surfaces: the outermost pixel(s) with open air right above.
		var rim_thickness: int = 2 if kind == Kind.GRASS else 1
		for lift: int in range(1, rim_thickness + 1):
			if y - lift >= 0 and pixel_kinds[index - width * lift] == Kind.AIR:
				return colors[1]
		# Ash: pale flecks scattered through its crust.
		if is_ash and hash(Vector2i(x * 5, y * 11)) % ASH_FLECK_EVERY == 0:
			return colors[5]
		# A few darker specks in the crust.
		if hash(Vector2i(x * 7, y * 13)) % 29 == 0:
			return (colors[0] as Color).darkened(0.18)
		return colors[0]
	if depth < crust_end:
		return colors[2]  # the edge line where the crust ends
	# Inside: dark, hatched, a little darker the deeper it goes.
	var inside: Color = colors[4] if (x + y) % HATCH_PERIOD < HATCH_WIDTH else colors[3]
	var fade: float = smoothstep(0.0, INSIDE_FADE_DEPTH, depth - crust_end)
	# darkened(), not `inside * factor`: multiplying a Color scales its alpha too, which
	# made the deep inside see-through.
	return inside.darkened(1.0 - lerpf(INSIDE_EDGE_BRIGHTNESS, INSIDE_DEEPEST_BRIGHTNESS, fade))


## One thicket pixel (Stage F6): thorns (pixels poking into an open cell) in the
## thorn color, branch strokes in the branch color (darker deeper in), the rest
## layered like any ground. Burning thicket uses the charred palette.
func _get_thicket_pixel_color(x: int, y: int, index: int) -> Color:
	var colors: Array = THICKET_PALETTE
	if fire_grid != null and _get_fire_state_at(x, y) == FireGrid.State.BURNING:
		colors = THICKET_BURNING_PALETTE
	if not kinds.has(Vector2i(x / tile_size, y / tile_size)):
		return colors[6]  # a thorn, poking into an open cell
	var color: Color = _get_layered_color(x, y, index, Kind.THICKET, colors, false)
	if _is_bramble_branch(x, y):
		var depth_past_crust: float = distances[index] - 1.0 - CRUST_WIDTH
		color = (colors[5] as Color).darkened(clampf(depth_past_crust / INSIDE_FADE_DEPTH, 0.0, 0.8))
	return _tint_if_overgrown(x, y, index, color)


## Tangled brambles: two families of diagonal strokes that wobble on the crust noise
## and cross each other, the same every run. Each stroke is broken into short pieces
## (a hash per stroke and 3-4 px stretch decides which pieces exist), so the pattern
## reads as a tangle of separate stems, not a lattice. posmod = a % that is never
## negative.
func _is_bramble_branch(x: int, y: int) -> bool:
	var shifted: int = x + y + int(_get_noise(x, y) * 4.0)
	if posmod(shifted, 9) == 0 and (hash(Vector2i(floori(shifted / 9.0), y / 3)) & 0x7FFFFFFF) % 5 < 3:
		return true
	var other_shifted: int = x - y + int(_get_noise((x + 31) % width, y) * 4.0)
	return posmod(other_shifted, 11) == 0 and (hash(Vector2i(floori(other_shifted / 11.0) + 500, y / 4)) & 0x7FFFFFFF) % 5 < 3


## A cover's crust is a shade off (OVERGROWN_TINT): half of its tell.
func _tint_if_overgrown(x: int, y: int, index: int, color: Color) -> Color:
	if overgrown_cells.is_empty() or not overgrown_cells.has(Vector2i(x / tile_size, y / tile_size)):
		return color
	if distances[index] - 1.0 > CRUST_WIDTH:
		return color  # only the crust: deep inside, everything is dark anyway
	return color.lerp(OVERGROWN_TINT, OVERGROWN_TINT_AMOUNT)


## Some grass cells caught fire, smoldered, turned to ash or were reset: repaint just
## their pixels (the ground's shape is the same, so the mask and distances still
## hold), then upload the picture once.
## (Grown by the edge raggedness: a changed cell's look reaches into its neighbours.)
## The upload to the GPU (texture.update, the whole picture) waits until the end of
## the frame and happens once, however many cells changed: a fire front changes
## several cells in the same frame.
func _on_fire_cells_changed(cells: Array[Vector2i]) -> void:
	if image == null:
		return
	var picture: Rect2i = Rect2i(0, 0, width, height)
	var margin: int = ceili(FIRE_EDGE_RAGGEDNESS) + 1
	for cell: Vector2i in cells:
		_paint(Rect2i(cell * tile_size, Vector2i.ONE * tile_size).grow(margin).intersection(picture))
	if not is_upload_queued:
		is_upload_queued = true
		# call_deferred = run it later this frame, after the current code is done.
		_upload_picture.call_deferred()


func _upload_picture() -> void:
	is_upload_queued = false
	texture.update(image)
	queue_redraw()


## The fire state that colors pixel (x, y): the state of the cell under a point
## nudged by smooth noise (FIRE_EDGE_RAGGEDNESS), so the border between burnt and
## unburnt cells wanders in blobs. A nudge that lands off anything burnable, or on
## another material than the pixel's own cell, keeps the pixel's own cell (grass
## never borrows a thicket cell's state or the other way round).
func _get_fire_state_at(x: int, y: int) -> FireGrid.State:
	var nudge_x: float = _get_noise((x + 53) % width, y) * FIRE_EDGE_RAGGEDNESS
	var nudge_y: float = _get_noise(x, (y + 71) % height) * FIRE_EDGE_RAGGEDNESS
	if fire_grid.cell_states.is_empty():
		return FireGrid.State.GRASS  # nothing has burnt: skip the lookups (fast path)
	var cell: Vector2i = Vector2i(floori((x + nudge_x) / tile_size), floori((y + nudge_y) / tile_size))
	var own_cell: Vector2i = Vector2i(x / tile_size, y / tile_size)
	var own_material: int = _get_material_class(own_cell)
	var nudged_material: int = _get_material_class(cell)
	if nudged_material == Kind.AIR or (own_material != Kind.AIR and nudged_material != own_material):
		cell = own_cell
	return fire_grid.get_state(cell)


## A number that is the same for cells of the same material: their Kind, made
## different for overgrown covers. Read from our own `kinds` (one lookup) instead of
## asking the tile layers (FireGrid.get_fuel: up to three lookups) for every pixel.
func _get_material_class(cell: Vector2i) -> int:
	var kind: int = kinds.get(cell, Kind.AIR)
	if kind != Kind.AIR and overgrown_cells.has(cell):
		return kind + 100
	return kind


## Random numbers (-1..1) on a coarse grid, the same every run (seeded).
func _build_noise_grid() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1234
	noise_columns = width / CRUST_NOISE_SPACING + 2
	var rows: int = height / CRUST_NOISE_SPACING + 2
	noise_grid.resize(noise_columns * rows)
	for index: int in noise_grid.size():
		noise_grid[index] = random.randf_range(-1.0, 1.0)


## Smooth "value noise" at a pixel: the four grid values around it, blended with
## smoothstep weights so the result curves gently between grid points.
func _get_noise(x: int, y: int) -> float:
	var grid_x: float = float(x) / CRUST_NOISE_SPACING
	var grid_y: float = float(y) / CRUST_NOISE_SPACING
	var column: int = int(grid_x)
	var row: int = int(grid_y)
	var u: float = smoothstep(0.0, 1.0, grid_x - column)
	var v: float = smoothstep(0.0, 1.0, grid_y - row)
	var top: float = lerpf(noise_grid[row * noise_columns + column], noise_grid[row * noise_columns + column + 1], u)
	var bottom: float = lerpf(noise_grid[(row + 1) * noise_columns + column], noise_grid[(row + 1) * noise_columns + column + 1], u)
	return lerpf(top, bottom, v)


# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	if texture != null:
		draw_texture(texture, Vector2.ZERO)


## The overlay: earth cells with a state (used, hardened, shivering) drawn again on
## top, tinted by EarthLayer.get_cell_modulate(), and cracks on used earth.
func _draw_overlay() -> void:
	if earth_layer == null or texture == null:
		return
	for cell: Vector2i in earth_layer.get_state_cells():
		if not kinds.has(cell):
			continue  # torn out (open air now)
		var rect: Rect2 = Rect2(Vector2(cell * tile_size), Vector2.ONE * tile_size)
		# draw_texture_rect_region(texture, where, which part of the texture, tint)
		overlay.draw_texture_rect_region(texture, rect, rect, earth_layer.get_cell_modulate(cell))
		if earth_layer.used_fade_progress.has(cell) and float(earth_layer.used_fade_progress[cell]) >= 0.5:
			_draw_cracks(cell)


## Two short crack lines (3 px, diagonal) on a used cell, at seeded spots in its middle
## (pixels 2..5: never on a dented edge or rounded corner).
func _draw_cracks(cell: Vector2i) -> void:
	var seed_value: int = hash(cell + Vector2i(7, 13))
	var origin: Vector2 = Vector2(cell * tile_size)
	for crack_index: int in 2:
		var start: Vector2i = Vector2i(2 + (seed_value >> (crack_index * 6)) % 2, 2 + (seed_value >> (crack_index * 6 + 2)) % 2)
		var step_x: int = 1 if (seed_value >> (crack_index * 6 + 4)) % 2 == 0 else -1
		if step_x < 0:
			start.x += 2
		for step: int in 3:
			overlay.draw_rect(Rect2(origin + Vector2(start + Vector2i(step_x * step, step)), Vector2.ONE), CRACK_COLOR)


## A hidden chamber is about to open (the picture still shows it covered): keep a copy
## of the picture to draw the crumbling cover from. A chamber still crumbling from an
## earlier reveal is already open in the picture, so its cells are copied over from
## the previous cover copy.
func _on_chamber_revealed(_cells: Array[Vector2i]) -> void:
	var snapshot: Image = image.duplicate() as Image
	if cover_image != null:
		for cell: Vector2i in hidden_layer.get_crumbling_cells():
			var rect: Rect2i = Rect2i(cell * tile_size, Vector2i.ONE * tile_size)
			snapshot.blit_rect(cover_image, rect, rect.position)
	cover_image = snapshot
	cover_texture = ImageTexture.create_from_image(cover_image)


## The cover: each crumbling chamber cell's piece of the copied picture, fading out
## and sinking up to 2 px as it goes (whole pixels, so it stays crisp).
func _draw_cover() -> void:
	if hidden_layer == null or cover_texture == null:
		return
	for cell: Vector2i in hidden_layer.get_crumbling_cells():
		var alpha: float = hidden_layer.get_cover_alpha(cell)
		if alpha <= 0.0:
			continue
		var source: Rect2 = Rect2(Vector2(cell * tile_size), Vector2.ONE * tile_size)
		var sink: float = roundf((1.0 - alpha) * 2.0)
		cover.draw_texture_rect_region(cover_texture, Rect2(source.position + Vector2(0.0, sink), source.size),
			source, Color(1.0, 1.0, 1.0, alpha))
