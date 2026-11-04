class_name MudLook
extends RefCounted
## MudLook (after the W8c play-tests): how a MUD tile looks (wet earth or wet ash,
## SurfaceGrid). SurfaceGrid draws with it; it keeps nothing itself (static).
##
## Mud is the earth gone wet: the very same ground as the GroundPainter paints it
## (its shape, its dents, the crust's width and wobble, the rim on top, the edge line,
## the hatched inside darkening deeper in), only in a MUD PALETTE: the crust is the wet
## brown of the lumps, darker than dry earth's tan. Then, on each open face, a few
## small smooth mud LUMPS bulge 2-3 px out into the air (half-ellipses), some of the
## biggest with a glossy speck.
##
##   make_tile_texture(): one tile's 8x8 picture (SurfaceGrid keeps it until the
##     terrain changes), from GroundPainter.get_pixel_color_in_palette. In a room with
##     no painter (tiles drawn by their tileset) it layers the tile itself, by the
##     distance to its own open faces.
##   draw_lumps(): the lumps on the open faces of one tile.
##   draw_drip(): the slow drip off an underside (the one moving part; SurfaceGrid's
##     MudDrips child redraws only that every frame).

## The mud palettes, in GroundPainter.PALETTE's order: [crust, rim, edge line, inside,
## hatch stripe]. The crust is the lumps' brown; the inside is the earth's own (wet
## earth is dark inside either way). Ash mud the same in grey-black.
const MUD_PALETTE: Array = [Color("#4A2E1A"), Color("#5C3C24"), Color("#24150C"),
	Color(0.26, 0.12, 0.09), Color(0.33, 0.17, 0.11)]
const ASH_MUD_PALETTE: Array = [Color("#34302F"), Color("#45403E"), Color("#161414"),
	Color(0.12, 0.11, 0.12), Color(0.17, 0.16, 0.17)]
## The glossy speck on the biggest lumps.
const GLOSS_COLOR: Color = Color("#8C6A4A")
const ASH_GLOSS_COLOR: Color = Color("#6A6466")
## Without a painter: crust and edge line widths, px, and how far in the inside
## darkens (the painter's values, without its wobble).
const CRUST_WIDTH: float = GroundPainter.CRUST_WIDTH
const INSIDE_FADE_DEPTH: float = GroundPainter.INSIDE_FADE_DEPTH
const HATCH_PERIOD: int = GroundPainter.HATCH_PERIOD
const HATCH_WIDTH: int = GroundPainter.HATCH_WIDTH
## A lump on a face: this chance per tile face, LUMP_MIN_HEIGHT..LUMP_MAX_HEIGHT px
## out, as wide as its height plus LUMP_WIDTH_EXTRA either side.
const LUMP_CHANCE: float = 0.7
const LUMP_MIN_HEIGHT: int = 2
const LUMP_MAX_HEIGHT: int = 3
const LUMP_WIDTH_EXTRA: int = 2
## Only the tallest lumps get a gloss speck, and of those only this share.
const GLOSS_CHANCE: float = 0.35
## How many points round each lump's half-ellipse.
const LUMP_POINTS: int = 10
## A drip falls this far under the tile, px, once every DRIP_PERIOD seconds.
const DRIP_LENGTH: float = 5.0
const DRIP_PERIOD: float = 2.2
const TILE: int = 8


## The crust color (the lumps and drips are made of it).
static func get_crust_color(is_ash: bool) -> Color:
	return (ASH_MUD_PALETTE if is_ash else MUD_PALETTE)[0]


## One mud tile's picture. `is_open(cell) -> bool`: is that tile open air?
static func make_tile_texture(cell: Vector2i, is_ash: bool, painter: GroundPainter, is_open: Callable) -> ImageTexture:
	var image: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var palette: Array = ASH_MUD_PALETTE if is_ash else MUD_PALETTE
	var has_painter: bool = painter != null and not painter.distances.is_empty()
	for y: int in TILE:
		for x: int in TILE:
			var pixel: Vector2i = cell * TILE + Vector2i(x, y)
			if has_painter and pixel.x >= 0 and pixel.y >= 0 and pixel.x < painter.width and pixel.y < painter.height:
				# The ground's own pixel in the mud palette (air in its dents stays air).
				image.set_pixel(x, y, painter.get_pixel_color_in_palette(pixel, palette))
			else:
				image.set_pixel(x, y, _get_plain_color(cell, x, y, palette, is_open))
	return ImageTexture.create_from_image(image)


## Without a painter: the tile layered by the distance to its own open faces (1 on
## the outermost pixel): rim on top, crust, edge line, hatched inside darkening.
static func _get_plain_color(cell: Vector2i, x: int, y: int, palette: Array, is_open: Callable) -> Color:
	var distance: float = CRUST_WIDTH + 1.0 + INSIDE_FADE_DEPTH  # no open face: deep
	if is_open.call(cell + Vector2i.UP):
		if y == 0:
			return palette[1]  # the rim
		distance = minf(distance, y + 1.0)
	if is_open.call(cell + Vector2i.DOWN):
		distance = minf(distance, TILE - y)
	if is_open.call(cell + Vector2i.LEFT):
		distance = minf(distance, x + 1.0)
	if is_open.call(cell + Vector2i.RIGHT):
		distance = minf(distance, TILE - x)
	if distance <= CRUST_WIDTH:
		return palette[0]
	if distance <= CRUST_WIDTH + 1.0:
		return palette[2]
	var pixel: Vector2i = cell * TILE + Vector2i(x, y)
	var inside: Color = palette[4] if posmod(pixel.x + pixel.y, HATCH_PERIOD) < HATCH_WIDTH else palette[3]
	return inside.darkened(clampf((distance - CRUST_WIDTH - 1.0) / INSIDE_FADE_DEPTH, 0.0, 0.85))


## The lumps on the open faces of `cell`, on `canvas` (room-local px).
static func draw_lumps(canvas: CanvasItem, cell: Vector2i, is_ash: bool, is_open: Callable) -> void:
	var color: Color = get_crust_color(is_ash)
	var gloss: Color = ASH_GLOSS_COLOR if is_ash else GLOSS_COLOR
	var center: Vector2 = Vector2(cell * TILE) + Vector2.ONE * (TILE * 0.5)
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not is_open.call(cell + side):
			continue
		# Three steady rolls per face (a hash of the cell and side): is there a lump,
		# how tall, and where along the face.
		var roll: float = _hash01(cell * 3 + side * 101)
		if roll >= LUMP_CHANCE:
			continue
		# MIN..MAX, each height as likely (the roll is under 1, so floori never reaches
		# one past the range).
		var height: int = LUMP_MIN_HEIGHT + floori(_hash01(cell * 7 + side * 13) * (LUMP_MAX_HEIGHT - LUMP_MIN_HEIGHT + 1))
		var half_width: float = height + LUMP_WIDTH_EXTRA
		var outward: Vector2 = Vector2(side)
		var along: Vector2 = Vector2(-outward.y, outward.x)
		# Its middle somewhere along the face, kept far enough in that it stays on this
		# tile's face (at most 2 px past its ends).
		var slide_room: float = maxf(TILE * 0.5 + 2.0 - half_width, 0.0)
		var slide: float = (_hash01(cell * 11 + side * 29) * 2.0 - 1.0) * slide_room
		var base: Vector2 = center + outward * (TILE * 0.5) + along * slide
		# A half-ellipse from one end of its base round to the other; its base starts
		# 1 px inside the face so it grows out of the mud, no seam.
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in LUMP_POINTS + 1:
			var angle: float = PI * step / LUMP_POINTS
			points.append(base - outward + along * cos(angle) * half_width + outward * sin(angle) * (height + 1.0))
		canvas.draw_colored_polygon(points, color)
		if height >= LUMP_MAX_HEIGHT and _hash01(cell * 5 + side * 41) < GLOSS_CHANCE:
			# A sparse glossy speck near the top of the lump, a little off its middle.
			var speck: Vector2 = (base + outward * (height - 1.0) - along * (half_width * 0.35)).floor()
			canvas.draw_rect(Rect2(speck, Vector2.ONE), gloss)


## The drip under `cell` at `clock` seconds: a drop that stretches, falls and comes
## back. The small primes mixed from the cell's x and y give each tile its own timing
## and spot, so neighbouring tiles never drip in step.
static func draw_drip(canvas: CanvasItem, cell: Vector2i, is_ash: bool, clock: float) -> void:
	var phase: float = fposmod(clock / DRIP_PERIOD + float((cell.x * 7 + cell.y * 3) % 11) / 11.0, 1.0)
	var drip_x: float = cell.x * TILE + 2.0 + float((cell.x * 5 + cell.y) % 4)
	canvas.draw_rect(Rect2(Vector2(drip_x, (cell.y + 1) * TILE), Vector2(1.0, 1.0 + phase * DRIP_LENGTH)),
		get_crust_color(is_ash))


## A steady 0..1 number for a point (the same every run and every redraw).
static func _hash01(point: Vector2i) -> float:
	var hash_value: int = absi(point.x * 73856093 ^ point.y * 19349663)
	return float(hash_value % 1000) / 1000.0
