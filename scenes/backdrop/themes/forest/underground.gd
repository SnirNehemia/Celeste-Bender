extends BackdropTheme
## FOREST, UNDERGROUND: caves among the roots under the forest. Dark earthy
## depths, far cave walls, tangled roots hanging from the ceiling, and near rock
## with clumps of glowing mushrooms; great roots hang right in front; spores
## drift up. Layers far to near; see BackdropTheme. (Surface: surface.gd; high up:
## skyline.gd, the treetops; shared: ForestStyle.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const DEPTH_BANDS: Array[Color] = [Color(0.03, 0.04, 0.03), Color(0.05, 0.06, 0.04), Color(0.07, 0.08, 0.05),
	Color(0.05, 0.06, 0.04), Color(0.03, 0.04, 0.03)]

const FAR_BODY: Color = Color(0.08, 0.09, 0.06)
const FAR_RIM: Color = Color(0.13, 0.14, 0.09)

const ROOT_COLOR: Color = Color(0.13, 0.1, 0.07)
const ROOT_LIT: Color = Color(0.2, 0.15, 0.09)
const MID_ROCK: Color = Color(0.06, 0.07, 0.05)
const MID_RIM: Color = Color(0.11, 0.12, 0.08)

const NEAR_BODY: Color = Color(0.025, 0.03, 0.02)
const NEAR_RIM: Color = Color(0.08, 0.09, 0.06)
const STEM_COLOR: Color = Color(0.2, 0.22, 0.2)
const CAP_COLOR: Color = Color(0.2, 0.55, 0.55)
const CAP_LIT: Color = Color(0.45, 0.85, 0.8)
const CAP_GLOW: Color = Color(0.3, 0.9, 0.85, 0.06)

## Mushroom clumps on the near floor: strip x of each clump.
const CLUMP_XS: Array[int] = [60, 190, 340, 470, 590]


func _build_layers() -> void:
	crust_colors = [ForestStyle.GROUND_BODY, ForestStyle.GROUND_RIM]
	add_painted_layer("Depths", Vector2(0.01, 0.0), _paint_depths)
	add_painted_layer("FarCave", Vector2(0.07, 0.03), _paint_far_cave)
	add_painted_layer("Roots", Vector2(0.2, 0.07), _paint_roots)
	var near: BackdropLayer = add_painted_layer("Mushrooms", Vector2(0.42, 0.13), _paint_mushrooms)
	near.draw_extra = _draw_mushroom_glow
	add_painted_layer("Front", ForestStyle.FRONT_SCROLL, _paint_front)

	var spores: BackdropMotes = BackdropMotes.new()
	spores.shape = BackdropMotes.Shape.FIREFLY
	spores.mote_count = 18
	spores.colors = [Color(0.5, 1.0, 0.85, 0.8), Color(0.75, 1.0, 0.6, 0.7)]
	spores.velocity = Vector2(1.0, -4.0)
	spores.sway_amplitude = 3.0
	spores.sway_speed = 0.2
	spores.scroll_factor = 0.5
	spores.seed_value = 311
	add_motes(spores)


func _paint_depths() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, DEPTH_BANDS, 0, BackdropPaint.STRIP_HEIGHT)
	return image


func _paint_far_cave() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_cave(image, BackdropPaint.row(22), BackdropPaint.row(152), 16.0, FAR_BODY, FAR_RIM, 24, 16.0, 321)
	return image


func _paint_roots() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var edges: Array[PackedFloat32Array] = BackdropPaint.paint_cave(image, BackdropPaint.row(8), BackdropPaint.row(170), 10.0, MID_ROCK, MID_RIM, 0, 4.0, 331)
	# Roots: from the ceiling, each a wiggly line that splits as it goes down.
	for root_index: int in 14:
		var root_x: float = (root_index + BackdropPaint.random01(root_index, 1, 332)) * BackdropPaint.STRIP_WIDTH / 14.0
		var start: Vector2 = Vector2(root_x, edges[0][posmod(roundi(root_x), BackdropPaint.STRIP_WIDTH)] - 2.0)
		var length: float = 20.0 + BackdropPaint.random01(root_index, 2, 332) * 40.0
		_paint_root(image, start, PI * 0.5, length, 3, root_index * 7)
	return image


## One root: a line wandering downward, splitting in two `depth` more times, each
## part thinner and shorter. The tips are plain lines; thicker parts get a lit edge.
func _paint_root(image: Image, start: Vector2, angle: float, length: float, depth: int, seed_value: int) -> void:
	var bend: float = (BackdropPaint.random01(seed_value, depth, 333) - 0.5) * 0.6
	var middle: Vector2 = start + Vector2(cos(angle + bend), sin(angle + bend)) * length * 0.5
	var end: Vector2 = middle + Vector2(cos(angle - bend), sin(angle - bend)) * length * 0.5
	var width: int = 1 + depth / 2
	BackdropPaint.put_line(image, start, middle, ROOT_COLOR, width)
	BackdropPaint.put_line(image, middle, end, ROOT_COLOR, width)
	if width > 1:
		BackdropPaint.put_line(image, start + Vector2(-1, 0), middle + Vector2(-1, 0), ROOT_LIT)
	if depth == 0:
		return
	for side: int in [-1, 1]:
		_paint_root(image, end, angle + side * 0.45, length * 0.6, depth - 1, seed_value * 3 + side + 5)


func _paint_mushrooms() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(120.0, 14.0), Vector2(30.0, 5.0)]
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(-4), octaves, 341, false)
	BackdropPaint.fill_above(image, ceiling, NEAR_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, NEAR_RIM)
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(186), octaves, 342, false)
	BackdropPaint.fill_below(image, floor_tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, floor_tops, NEAR_RIM)
	for clump_index: int in CLUMP_XS.size():
		for mushroom_index: int in 4:
			var x: int = CLUMP_XS[clump_index] + mushroom_index * 6 - 9 + roundi(BackdropPaint.random01(clump_index, mushroom_index, 343) * 4.0)
			var foot_row: int = ceili(floor_tops[posmod(x, BackdropPaint.STRIP_WIDTH)]) + 1
			var height: int = 5 + roundi(BackdropPaint.random01(clump_index, mushroom_index + 10, 343) * 9.0)
			var cap_radius: int = 2 + height / 4
			BackdropPaint.put_rect(image, Rect2i(x, foot_row - height, 1 + height / 8, height), STEM_COLOR)
			# Cap: a flat dome, lit on top.
			for dy: int in cap_radius:
				var half_width: int = cap_radius - dy / 2 - (1 if dy == cap_radius - 1 else 0)
				var y: int = foot_row - height - dy
				BackdropPaint.put_rect(image, Rect2i(x - half_width, y, half_width * 2 + 1, 1), CAP_COLOR if dy < cap_radius - 1 else CAP_LIT)
	return image


## Each clump pulses with a cold glow, out of step with the others.
func _draw_mushroom_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for clump_index: int in CLUMP_XS.size():
		var pulse: float = 0.55 + 0.45 * sin(time * 0.7 + clump_index * 2.3)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + CLUMP_XS[clump_index], BackdropPaint.row(172)), 26.0, CAP_GLOW, pulse)


## Right in front: great roots hanging from above the screen, thick and twisting,
## splitting as they go down (_paint_root, drawn bigger and darker).
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for root: Vector3 in [Vector3(30.0, 70.0, 0.25), Vector3(250.0, 50.0, -0.2), Vector3(470.0, 84.0, 0.15)]:
		_paint_big_root(image, Vector2(root.x, BackdropPaint.row(-30)), PI * 0.5 + root.z, root.y, 4, int(root.x))
	return image


## One great root: like _paint_root, but each part `depth` + 2 px thick with a
## lit left edge.
func _paint_big_root(image: Image, start: Vector2, angle: float, length: float, depth: int, seed_value: int) -> void:
	var bend: float = (BackdropPaint.random01(seed_value, depth, 344) - 0.5) * 0.7
	var middle: Vector2 = start + Vector2(cos(angle + bend), sin(angle + bend)) * length * 0.5
	var end: Vector2 = middle + Vector2(cos(angle - bend), sin(angle - bend)) * length * 0.5
	var width: int = depth + 2
	BackdropPaint.put_line(image, start, middle, ForestStyle.FRONT_BODY, width)
	BackdropPaint.put_line(image, middle, end, ForestStyle.FRONT_BODY, width)
	BackdropPaint.put_line(image, start - Vector2(width * 0.5, 0.0), middle - Vector2(width * 0.5, 0.0), ForestStyle.FRONT_LIT)
	if depth == 0:
		return
	for side: int in [-1, 1]:
		_paint_big_root(image, end, angle + side * 0.4, length * 0.62, depth - 1, seed_value * 3 + side + 5)
