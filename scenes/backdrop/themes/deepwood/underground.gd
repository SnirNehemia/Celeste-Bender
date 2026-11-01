extends BackdropTheme
## DEEPWOOD, UNDERGROUND: among the roots under the old forest. A deep brown dark
## with a green-blue glow; far curtains of fine roots hanging into it, faint earth
## ledges with glowing mushrooms (in the ground's style, BackdropTerrain), great
## roots winding down from the ceiling, a near ceiling and floor of earth, and
## right in front dangling roots and big pale toadstools; daylight falls in
## through gaps in the roof, mushrooms glow on the floor, spores float.
## Layers far to near; see BackdropTheme.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The cavern's air: what far things fade into.
const AIR: Color = Color(0.12, 0.17, 0.16)
const BACK_BANDS: Array[Color] = [Color(0.06, 0.08, 0.08), Color(0.08, 0.11, 0.1), Color(0.11, 0.15, 0.14),
	Color(0.13, 0.19, 0.17), Color(0.11, 0.16, 0.15), Color(0.08, 0.1, 0.1)]
## Daylight from the forest falling in through gaps in the roof.
const SHAFT_COLOR: Color = Color(0.85, 1.0, 0.6, 0.08)
## Glowing mushroom clusters on the near floor: strip x, screen row of their foot.
const NEAR_MUSHROOMS: Array[Vector2] = [Vector2(130.0, 176.0), Vector2(138.0, 177.0), Vector2(146.0, 175.0),
	Vector2(452.0, 178.0), Vector2(460.0, 176.0)]
## Earth in the ground's style (GroundPainter's EARTH, with turf on top).
const EARTH: Array[Color] = [Color(0.74, 0.57, 0.27), Color(0.43, 0.66, 0.3), Color(0.42, 0.24, 0.12),
	Color(0.26, 0.12, 0.09), Color(0.33, 0.17, 0.11), Color(0.07, 0.04, 0.04)]
const ROOT: Array[Color] = [Color(0.48, 0.36, 0.25), Color(0.58, 0.46, 0.3), Color(0.25, 0.16, 0.11),
	Color(0.17, 0.11, 0.08), Color(0.22, 0.14, 0.1), Color(0.06, 0.04, 0.04)]
const ROOTLET: Color = Color(0.3, 0.22, 0.16)
const MUSHROOM_CAP: Color = Color(0.45, 0.85, 0.8)
const MUSHROOM_STEM: Color = Color(0.7, 0.78, 0.7)
const MUSHROOM_GLOW: Color = Color(0.4, 0.9, 0.85, 0.1)
const FRONT_CAP: Color = Color(0.36, 0.3, 0.28)
const FRONT_CAP_LIT: Color = Color(0.5, 0.42, 0.36)
const FRONT_GILLS: Color = Color(0.2, 0.16, 0.15)

const FAR_HAZE: float = 0.65
const LEDGES_HAZE: float = 0.4
const ROOTS_HAZE: float = 0.22
## The glowing mushrooms on the ledges: strip x, screen row of their foot.
const MUSHROOMS: Array[Vector2] = [Vector2(46.0, 92.0), Vector2(58.0, 92.0), Vector2(214.0, 60.0), Vector2(338.0, 112.0),
	Vector2(350.0, 112.0), Vector2(512.0, 74.0)]


func _build_layers() -> void:
	# The band broken through on the way up: [body, lit rim] (BackdropTheme).
	crust_colors = [EARTH[BackdropTerrain.EDGE], EARTH[BackdropTerrain.CRUST]]
	add_painted_layer("Back", Vector2(0.02, 0.01), _paint_back)
	add_painted_layer("FarRoots", Vector2(0.07, 0.025), _paint_far_roots)
	var ledges: BackdropLayer = add_painted_layer("Ledges", Vector2(0.15, 0.05), _paint_ledges)
	ledges.draw_extra = _draw_mushroom_glow
	var shaft_xs: Array[float] = [96.0, 300.0, 520.0]
	add_drawn_layer("Shafts", Vector2(0.2, 0.07), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		BackdropTheme.draw_light_shafts(layer, copy_x, time, shaft_xs, 7.0, 0.18, 220.0, SHAFT_COLOR))
	add_painted_layer("Roots", Vector2(0.26, 0.09), _paint_roots)
	var near: BackdropLayer = add_painted_layer("NearEarth", Vector2(0.4, 0.13), _paint_near_earth)
	near.draw_extra = _draw_near_glow
	add_painted_layer("Front", DeepwoodStyle.FRONT_SCROLL, _paint_front)

	var spores: BackdropMotes = BackdropMotes.new()
	spores.shape = BackdropMotes.Shape.FIREFLY
	spores.mote_count = 20
	spores.colors = [Color(0.5, 1.0, 0.9, 0.9), Color(0.75, 1.0, 0.6, 0.8)]
	spores.velocity = Vector2(1.5, -3.0)
	spores.sway_amplitude = 5.0
	spores.sway_speed = 0.2
	spores.scroll_factor = 0.45
	spores.seed_value = 5401
	add_motes(spores)


## The dark: bands, a faint glow in the middle, far earth walls in the ground's style.
func _paint_back() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, BACK_BANDS, BackdropPaint.row(0), BackdropPaint.row(180))
	var walls: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.STRIP_HEIGHT + 6)
	walls.add_above(BackdropPaint.ridge(BackdropPaint.row(30), [Vector2(120.0, 26.0), Vector2(30.0, 8.0)] as Array[Vector2], 5411, false))
	walls.add_below(BackdropPaint.ridge(BackdropPaint.row(170), [Vector2(140.0, 28.0), Vector2(36.0, 8.0)] as Array[Vector2], 5412, false))
	BackdropTerrain.roughen(walls, 5411)
	BackdropTerrain.paint(image, walls, BackdropTerrain.hazed(EARTH, AIR, FAR_HAZE + 0.1), 3.0, 10.0, 1, 5411)
	return image


## Curtains of fine roots hanging from the far ceiling into the dark.
func _paint_far_roots() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var ceiling: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.row(30))
	ceiling.add_above(BackdropPaint.ridge(BackdropPaint.row(10), [Vector2(80.0, 10.0)] as Array[Vector2], 5421, false))
	BackdropTerrain.roughen(ceiling, 5421)
	BackdropTerrain.paint(image, ceiling, BackdropTerrain.hazed(EARTH, AIR, FAR_HAZE), 3.0, 8.0, 1, 5421)
	BackdropTerrain.paint_hanging(image, ceiling, ROOTLET.lerp(AIR, FAR_HAZE - 0.15), 2, 90, ROOTLET.lerp(AIR, FAR_HAZE - 0.3), 7, 5422)
	return image


## Faint earth ledges at different heights with glowing mushrooms on them.
func _paint_ledges() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var palette: Array[Color] = BackdropTerrain.hazed(EARTH, AIR, LEDGES_HAZE)
	var ledges: Array[Vector3i] = [Vector3i(30, 92, 6), Vector3i(196, 60, 5), Vector3i(320, 112, 7), Vector3i(494, 74, 5)]
	for ledge_index: int in ledges.size():
		var ledge: Vector3i = ledges[ledge_index]
		var top_row: int = BackdropPaint.row(ledge.y)
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(ledge.x - 2, top_row - 10, ledge.z * 6 + 4, 40))
		BackdropTerrain.add_chunk(mask, ledge.x, top_row, ledge.z, 4, 6, 5431 + ledge_index)
		BackdropTerrain.roughen(mask, 5431 + ledge_index)
		BackdropTerrain.paint(image, mask, palette, 3.0, 8.0, 2, 5431 + ledge_index)
		BackdropTerrain.paint_hanging(image, mask, ROOTLET.lerp(AIR, LEDGES_HAZE), 3, 14, ROOTLET.lerp(AIR, LEDGES_HAZE), 0, 5441 + ledge_index)
	for mushroom: Vector2 in MUSHROOMS:
		var foot: int = BackdropPaint.row(mushroom.y)
		BackdropPaint.put_rect(image, Rect2i(roundi(mushroom.x), foot - 5, 1, 5), MUSHROOM_STEM)
		BackdropPaint.put_rect(image, Rect2i(roundi(mushroom.x) - 2, foot - 7, 5, 2), MUSHROOM_CAP)
		BackdropPaint.put_rect(image, Rect2i(roundi(mushroom.x) - 1, foot - 8, 3, 1), MUSHROOM_CAP.lightened(0.3))
	return image


## The mushrooms' glow, pulsing slowly, each out of step.
func _draw_mushroom_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for mushroom_index: int in MUSHROOMS.size():
		var mushroom: Vector2 = MUSHROOMS[mushroom_index]
		var pulse: float = 0.6 + 0.4 * sin(time * 0.9 + mushroom_index * 1.7)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + mushroom.x, BackdropPaint.row(mushroom.y - 7.0)), 12.0, MUSHROOM_GLOW, pulse)


## Great roots winding down from the ceiling in S curves, thinning as they go,
## each putting out a few side roots, with fine rootlets hanging from them.
func _paint_roots() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var roots: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.STRIP_HEIGHT)
	for root_index: int in 6:
		var x: float = (root_index + BackdropPaint.random01(root_index, 1, 5451) * 0.5) * BackdropPaint.STRIP_WIDTH / 6.0
		var length: float = BackdropPaint.row(80) + BackdropPaint.random01(root_index, 3, 5451) * 120.0
		_add_root(roots, Vector2(x, 0.0), 12.0 + BackdropPaint.random01(root_index, 2, 5451) * 6.0, length, root_index, 2)
	BackdropTerrain.roughen(roots, 5453)
	BackdropTerrain.paint(image, roots, BackdropTerrain.hazed(ROOT, AIR, ROOTS_HAZE), 3.0, 6.0, 1, 5453)
	BackdropTerrain.paint_hanging(image, roots, ROOTLET.lerp(AIR, ROOTS_HAZE), 6, 16, ROOTLET, 0, 5454)
	return image


## One root from `start`, `width` px thick, `length` px long: its heading swings
## either side of straight down (smooth noise, not a random walk, so it curves in
## S bends instead of drifting off), and `branches` times it puts out a thinner
## side root of its own.
func _add_root(roots: BackdropTerrain.Mask, start: Vector2, width: float, length: float, root_index: int, branches: int) -> void:
	var point: Vector2 = start
	var travelled: float = 0.0
	var next_branch: float = length * 0.3
	while travelled < length:
		var swing: float = (BackdropPaint.periodic_noise(travelled * 4.0 + root_index * 131.0, 60.0, 5452) - 0.5) * 2.2
		var heading: float = PI * 0.5 + swing
		var next: Vector2 = point + Vector2(cos(heading), sin(heading)) * 4.0
		var width_here: float = maxf(2.0, width * (1.0 - travelled / length * 0.8))
		for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
			roots.add_line(point + Vector2(wrap_offset, 0.0), next + Vector2(wrap_offset, 0.0), width_here)
		point = next
		travelled += 4.0
		if branches > 0 and travelled >= next_branch:
			_add_root(roots, point, width_here * 0.55, length * 0.45, root_index * 7 + branches, branches - 1)
			next_branch += length * 0.3
			branches -= 1


## The near cavern: an earth ceiling across the top and a floor of turf-topped earth
## along the bottom, both in the ground's style, roots hanging from the ceiling.
func _paint_near_earth() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var earth: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.STRIP_HEIGHT + 6)
	earth.add_above(BackdropPaint.ridge(BackdropPaint.row(4), [Vector2(90.0, 12.0), Vector2(24.0, 4.0)] as Array[Vector2], 5461, false))
	earth.add_below(BackdropPaint.ridge(BackdropPaint.row(184), [Vector2(110.0, 12.0), Vector2(26.0, 4.0)] as Array[Vector2], 5462, false))
	BackdropTerrain.roughen(earth, 5461)
	BackdropTerrain.paint(image, earth, EARTH, 5.0, 10.0, 2, 5461)
	BackdropTerrain.paint_blades(image, earth, DeepwoodStyle.BLADES, 3, 3, 5461)
	BackdropTerrain.paint_hanging(image, earth, ROOTLET, 4, 22, ROOT[BackdropTerrain.CRUST], 0, 5463)
	# Glowing mushrooms in clusters on the floor, bigger than the far ones.
	for mushroom_index: int in NEAR_MUSHROOMS.size():
		var mushroom: Vector2 = NEAR_MUSHROOMS[mushroom_index]
		var foot: int = BackdropPaint.row(mushroom.y)
		var height: int = 6 + mushroom_index % 3 * 2
		BackdropPaint.put_rect(image, Rect2i(roundi(mushroom.x), foot - height, 2, height), MUSHROOM_STEM)
		BackdropPaint.put_rect(image, Rect2i(roundi(mushroom.x) - 3, foot - height - 2, 8, 2), MUSHROOM_CAP)
		BackdropPaint.put_rect(image, Rect2i(roundi(mushroom.x) - 2, foot - height - 3, 6, 1), MUSHROOM_CAP.lightened(0.3))
	return image


## The near mushrooms' glow, pulsing.
func _draw_near_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for mushroom_index: int in NEAR_MUSHROOMS.size():
		var mushroom: Vector2 = NEAR_MUSHROOMS[mushroom_index]
		var pulse: float = 0.6 + 0.4 * sin(time * 0.8 + mushroom_index * 2.1)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + mushroom.x + 1.0, BackdropPaint.row(mushroom.y - 9.0)), 16.0, MUSHROOM_GLOW, pulse)


## Right in front: roots dangling from above and two big toadstools in a corner.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	DeepwoodStyle.paint_front_moss(image, 240, 330, 90, 5471)
	# Each: (strip x, cap half width, height).
	for toadstool: Vector3 in [Vector3(500.0, 30.0, 70.0), Vector3(540.0, 20.0, 46.0)]:
		var foot: float = BackdropPaint.STRIP_HEIGHT
		var cap_row: float = foot - toadstool.z
		BackdropPaint.put_rect(image, Rect2i(roundi(toadstool.x - toadstool.y * 0.18), roundi(cap_row), roundi(toadstool.y * 0.36), roundi(toadstool.z)), FRONT_CAP)
		BackdropPaint.put_rect(image, Rect2i(roundi(toadstool.x - toadstool.y * 0.18), roundi(cap_row), 2, roundi(toadstool.z)), FRONT_CAP_LIT)
		# The cap: a flattened dome, gills dark under it.
		for dy: int in roundi(toadstool.y * 0.5):
			var half: float = toadstool.y * sqrt(1.0 - pow(float(dy) / (toadstool.y * 0.5), 2.0))
			BackdropPaint.put_rect(image, Rect2i(roundi(toadstool.x - half), roundi(cap_row) - dy, roundi(half * 2.0), 1), FRONT_CAP)
			BackdropPaint.put_rect(image, Rect2i(roundi(toadstool.x - half), roundi(cap_row) - dy, maxi(1, roundi(half * 0.6)), 1), FRONT_CAP_LIT)
		BackdropPaint.put_rect(image, Rect2i(roundi(toadstool.x - toadstool.y), roundi(cap_row), roundi(toadstool.y * 2.0), 2), FRONT_GILLS)
	return image
