class_name EarthBaseLook
extends RefCounted
## Earth base look (Stage E5 follow-up): draws where an earth creation (a snake, a
## pillar) GROWS OUT OF THE GROUND, so there's no seam between it and the face it came
## from:
##   - a ragged ROOT: each pixel column reaches 2-3 px down into the ground tile,
##     covering the GroundPainter's dented edge with the creation's own earth
##   - FILLETS: a small slope of earth in each corner where the creation meets the
##     surface, on the sides where there's open air beside it and ground to slope onto
## The creation itself must leave out its outline on the ground side.
##
## Used by EarthSnake and EarthColumn from their _draw(). It's a class of static
## functions only (like Pushable), so there's nothing to create: EarthBaseLook.draw(...).
##
## Drawn in "base space": x runs ACROSS the face (0 = its middle), y runs along the
## face's normal, OUT of the ground (y < 0 is inside the ground tile). A transform
## maps that onto the canvas, so the same code works for floors, walls and ceilings.

## The fillet's pixels, counted from the creation's edge column (x 0) outward, and
## from the surface (y 0) out: earth, then its outline stepping diagonally down.
const FILLET_FILL_PIXELS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]
const FILLET_OUTLINE_PIXELS: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 1), Vector2i(3, 0)]
## Each root column reaches this deep into the ground, px (random, inclusive).
const ROOT_MIN_DEPTH: int = 2
const ROOT_MAX_DEPTH: int = 3


## Draws the base on `canvas` (from inside its _draw()). `face` = the face the creation
## came out of, `width` = the creation's width across the face (px), `blocked_cells` =
## cells beside the base that aren't open air even though no tile is there (the
## snake's own tiles), so no fillet is drawn into them.
static func draw(canvas: CanvasItem, face: EarthFace, width: float, fill_color: Color,
		outline_color: Color, blocked_cells: Array[Vector2i]) -> void:
	var layer: EarthLayer = face.layer
	var normal: Vector2 = Vector2(face.normal)
	var across: Vector2 = Vector2(-normal.y, normal.x)
	var surface_center: Vector2 = (canvas as Node2D).to_local(face.get_global_center())
	# Transform2D(x axis, y axis, origin): base space -> the canvas's coordinates.
	canvas.draw_set_transform_matrix(Transform2D(across, normal, surface_center))
	var half: int = int(width / 2.0)
	# The root, seeded by the face so it looks the same every frame (no flicker).
	var root_random: RandomNumberGenerator = RandomNumberGenerator.new()
	root_random.seed = hash(face.cell * 31 + face.normal)
	for pixel_x: int in range(-half, half):
		var root_depth: int = root_random.randi_range(ROOT_MIN_DEPTH, ROOT_MAX_DEPTH)
		canvas.draw_rect(Rect2(pixel_x, -root_depth, 1.0, root_depth), fill_color)
	# The fillets, one per side that has open air beside the base and ground under it.
	var first_cell: Vector2i = face.cell + face.normal
	for side: int in [-1, 1]:
		var side_offset: Vector2i = Vector2i(across) * side
		var beside_cell: Vector2i = first_cell + side_offset
		if layer.is_solid(beside_cell) or blocked_cells.has(beside_cell) \
				or not layer.is_solid(face.cell + side_offset):
			continue
		var edge_x: int = half - 1 if side > 0 else -half  # the creation's outermost column
		for fill_pixel: Vector2i in FILLET_FILL_PIXELS:
			canvas.draw_rect(Rect2(edge_x + fill_pixel.x * side, fill_pixel.y, 1.0, 1.0), fill_color)
		for outline_pixel: Vector2i in FILLET_OUTLINE_PIXELS:
			canvas.draw_rect(Rect2(edge_x + outline_pixel.x * side, outline_pixel.y, 1.0, 1.0), outline_color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
