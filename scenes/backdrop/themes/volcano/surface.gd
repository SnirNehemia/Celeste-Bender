extends BackdropTheme
## VOLCANO, SURFACE: the slopes of a lava mountain. A dark ash-red sky with a dim
## sun, the volcano far off with lava running down its flanks under a plume of
## smoke and a glowing crater, black basalt ridges, a river of lava that flows
## and glows, and near jagged rock split by glowing cracks; embers rise and ash
## falls. Layers far to near; see BackdropTheme. (Under it: underground.gd, the
## magma chamber; high up: skyline.gd, above the ash cloud.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const SKY_BANDS: Array[Color] = [Color(0.08, 0.05, 0.09), Color(0.14, 0.07, 0.1), Color(0.23, 0.09, 0.11),
	Color(0.35, 0.12, 0.1), Color(0.5, 0.19, 0.1)]
const SUN_COLOR: Color = Color(0.68, 0.3, 0.17)

const CONE_BODY: Color = Color(0.17, 0.08, 0.1)
const CONE_LIT: Color = Color(0.25, 0.11, 0.12)
const CONE_RIM: Color = Color(0.48, 0.18, 0.11)
const FAR_RIDGE: Color = Color(0.22, 0.09, 0.1)
const LAVA_EDGE: Color = Color(0.95, 0.38, 0.08)
const LAVA_CORE: Color = Color(1.0, 0.75, 0.3)
const SMOKE_BODY: Color = Color(0.2, 0.14, 0.15)
const SMOKE_LIT: Color = Color(0.32, 0.2, 0.19)
const CRATER_GLOW: Color = Color(1.0, 0.45, 0.1, 0.1)

const RIDGE_BODY: Color = Color(0.09, 0.05, 0.07)
const RIDGE_LIT: Color = Color(0.15, 0.07, 0.08)
const RIDGE_RIM: Color = Color(0.52, 0.17, 0.08)

const RIVER_CRUST: Color = Color(0.32, 0.08, 0.05)
const RIVER_GLOW: Color = Color(1.0, 0.45, 0.1, 0.08)

const NEAR_BODY: Color = Color(0.04, 0.025, 0.035)
const NEAR_LIT: Color = Color(0.08, 0.04, 0.05)
const NEAR_RIM: Color = Color(0.6, 0.2, 0.08)
const CRACK: Color = Color(0.92, 0.36, 0.08)

## The volcano's crater, strip x; the lava river's top row (screen).
const CRATER_X: int = 190
const CRATER_SCREEN_ROW: int = 34
const RIVER_SCREEN_ROW: int = 160


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	var volcano: BackdropLayer = add_painted_layer("Volcano", Vector2(0.03, 0.01), _paint_volcano)
	volcano.draw_extra = _draw_crater_glow
	add_painted_layer("Ridges", Vector2(0.14, 0.05), _paint_ridges)
	var river: BackdropLayer = add_painted_layer("LavaRiver", Vector2(0.24, 0.08), _paint_river)
	river.draw_extra = _draw_river_flow
	var near: BackdropLayer = add_painted_layer("NearRock", Vector2(0.45, 0.14), _paint_near_rock)
	near.draw_extra = _draw_crack_glow

	var embers: BackdropMotes = BackdropMotes.new()
	embers.shape = BackdropMotes.Shape.FIREFLY
	embers.mote_count = 22
	embers.colors = [Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.8, 0.35, 0.8)]
	embers.velocity = Vector2(5.0, -18.0)
	embers.sway_amplitude = 3.0
	embers.sway_speed = 0.4
	embers.scroll_factor = 0.55
	embers.seed_value = 1811
	add_motes(embers)

	var ash: BackdropMotes = BackdropMotes.new()
	ash.mote_count = 30
	ash.colors = [Color(0.45, 0.4, 0.42, 0.45), Color(0.3, 0.27, 0.3, 0.5)]
	ash.velocity = Vector2(6.0, 9.0)
	ash.sway_amplitude = 3.0
	ash.sway_speed = 0.2
	ash.scroll_factor = 0.4
	ash.seed_value = 1812
	add_motes(ash)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(150))
	BackdropPaint.put_circle(image, Vector2(520.0, BackdropPaint.row(56)), 11.0, SUN_COLOR)
	return image


func _paint_volcano() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Lower ridges behind and around it.
	var ridges: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(150), [Vector2(160.0, 26.0), Vector2(40.0, 8.0)] as Array[Vector2], 1821, true)
	BackdropPaint.fill_below(image, ridges, FAR_RIDGE)
	var tops: PackedFloat32Array = BackdropPaint.flat_line(BackdropPaint.STRIP_HEIGHT + 4.0)
	BackdropPaint.cone(tops, CRATER_X, BackdropPaint.row(CRATER_SCREEN_ROW), BackdropPaint.row(160), 12.0, 190.0, 1822)
	BackdropPaint.paint_mountains(image, tops, CONE_BODY, CONE_LIT, CONE_RIM, CONE_RIM, CONE_RIM, -100, 40.0, 1823)
	# Lava flows: wandering lines from the crater lip down the flanks.
	for flow_index: int in 4:
		var side: float = -1.0 if flow_index % 2 == 0 else 1.0
		var x: float = CRATER_X + side * (4.0 + flow_index * 2.0)
		var length: int = 50 + roundi(BackdropPaint.random01(flow_index, 1, 1824) * 60.0)
		for step: int in length:
			x += side * (0.55 + BackdropPaint.random01(flow_index, step, 1825) * 0.5) * (1.0 - float(step) / length * 0.5)
			var y: int = ceili(tops[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)]) + 2
			BackdropPaint.put_rect(image, Rect2i(roundi(x), y, 2, 1), LAVA_EDGE)
			if step < length * 0.6:
				BackdropPaint.put_pixel(image, roundi(x), y, LAVA_CORE)
	# The crater's lip, glowing.
	BackdropPaint.put_rect(image, Rect2i(CRATER_X - 11, BackdropPaint.row(CRATER_SCREEN_ROW), 23, 2), LAVA_EDGE)
	BackdropPaint.put_rect(image, Rect2i(CRATER_X - 6, BackdropPaint.row(CRATER_SCREEN_ROW), 13, 1), LAVA_CORE)
	# The plume: puffs of smoke rising from the crater, leaning with the wind.
	for puff_index: int in 7:
		var center: Vector2 = Vector2(CRATER_X + puff_index * puff_index * 2.5, BackdropPaint.row(CRATER_SCREEN_ROW - 8 - puff_index * 10))
		BackdropPaint.paint_puff(image, center, 7.0 + puff_index * 2.5, SMOKE_BODY, SMOKE_LIT, puff_index + 1826)
	return image


## The crater's glow, breathing.
func _draw_crater_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var pulse: float = 0.6 + 0.25 * sin(time * 1.3) + 0.15 * sin(time * 3.7)
	BackdropTheme.draw_glow(layer, Vector2(copy_x + CRATER_X, BackdropPaint.row(CRATER_SCREEN_ROW) - 4.0), 34.0, CRATER_GLOW, pulse)


## Basalt ridges, lit red along their tops by the lava below them.
func _paint_ridges() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(120.0, 30.0), Vector2(30.0, 10.0), Vector2(8.0, 3.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(166), octaves, 1831, true)
	BackdropPaint.paint_mountains(image, tops, RIDGE_BODY, RIDGE_LIT, RIDGE_RIM, RIDGE_RIM, RIDGE_RIM, -100, 22.0, 1832)
	BackdropPaint.paint_hatch(image, tops, RIDGE_LIT, 7, 8)
	return image


## The lava river: glowing bands with dark crust floating on it.
func _paint_river() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(RIVER_SCREEN_ROW), [Vector2(160.0, 4.0), Vector2(30.0, 2.0)] as Array[Vector2], 1841, false)
	BackdropPaint.fill_below(image, tops, LAVA_EDGE)
	BackdropPaint.paint_rim(image, tops, LAVA_CORE, 2)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		for y: int in range(top + 3, BackdropPaint.STRIP_HEIGHT):
			# Crust: long dark plates where a slow noise is high, dithered at their
			# edges; each 4-row band has its own plates, shifted along.
			var crust: float = BackdropPaint.periodic_noise(x + (y / 4) * 37.0, 26.0, 1842 + y / 4)
			if crust > 0.68 or (crust > 0.62 and BackdropPaint.checker(x, y)):
				image.set_pixel(x, y, RIVER_CRUST)
	return image


## Bright streaks drifting along the river, and its glow.
func _draw_river_flow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var river_top: float = BackdropPaint.row(RIVER_SCREEN_ROW)
	for streak_index: int in 18:
		var lane: float = floorf(BackdropPaint.random01(streak_index, 1, 1843) * 8.0)
		var speed: float = 6.0 + lane * 1.5
		var x: float = fposmod(BackdropPaint.random01(streak_index, 2, 1843) * BackdropPaint.STRIP_WIDTH + time * speed, BackdropPaint.STRIP_WIDTH)
		layer.draw_rect(Rect2(copy_x + roundf(x), river_top + 4.0 + lane * 3.0, 6.0 - lane * 0.4, 1.0), LAVA_CORE)
	for glow_index: int in 5:
		var pulse: float = 0.6 + 0.4 * sin(time * 0.8 + glow_index * 1.7)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + 64.0 + glow_index * 128.0, river_top), 40.0, RIVER_GLOW, pulse)


## Near jagged rock with glowing cracks running through it.
func _paint_near_rock() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(110.0, 30.0), Vector2(26.0, 10.0), Vector2(8.0, 4.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(198), octaves, 1851, true)
	BackdropPaint.paint_mountains(image, tops, NEAR_BODY, NEAR_LIT, NEAR_RIM, NEAR_RIM, NEAR_RIM, -100, 14.0, 1852)
	for crack_index: int in 9:
		var point: Vector2 = Vector2(_crack_x(crack_index), 0.0)
		point.y = tops[posmod(roundi(point.x), BackdropPaint.STRIP_WIDTH)] + 4.0
		for segment: int in 6:
			var next: Vector2 = point + Vector2((BackdropPaint.random01(crack_index, segment, 1853) - 0.5) * 8.0, 3.0 + segment)
			BackdropPaint.put_line(image, point, next, CRACK)
			point = next
	return image


## Where crack `crack_index` starts (strip x).
static func _crack_x(crack_index: int) -> float:
	return (crack_index + BackdropPaint.random01(crack_index, 1, 1854) * 0.6) * BackdropPaint.STRIP_WIDTH / 9.0


## Each crack glows, out of step with the others.
func _draw_crack_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for crack_index: int in 9:
		var pulse: float = 0.5 + 0.5 * sin(time * 1.1 + crack_index * 2.1)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + _crack_x(crack_index), BackdropPaint.row(188)), 16.0, RIVER_GLOW, pulse)
