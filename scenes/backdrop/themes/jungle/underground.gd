extends BackdropTheme
## JUNGLE, UNDERGROUND: a cenote, a sinkhole cave under the rainforest. Daylight
## pours through holes in the ceiling in shafts, vines hang down through them and
## sway, mossy rocks and stalactites fill the middle, and a still green pool lies
## at the bottom, glinting; fireflies and drips. Layers far to near; see
## BackdropTheme. (Surface: surface.gd; high up: skyline.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const DEPTH_BANDS: Array[Color] = [Color(0.03, 0.07, 0.07), Color(0.04, 0.1, 0.09), Color(0.06, 0.13, 0.11),
	Color(0.05, 0.11, 0.1), Color(0.04, 0.08, 0.08)]
const SKY_LIGHT: Color = Color(0.62, 0.8, 0.6)
const SKY_BRIGHT: Color = Color(0.82, 0.92, 0.7)

const FAR_BODY: Color = Color(0.07, 0.14, 0.12)
const FAR_RIM: Color = Color(0.22, 0.38, 0.26)
const SHAFT_COLOR: Color = Color(0.85, 1.0, 0.7, 0.08)
const VINE_COLOR: Color = Color(0.13, 0.27, 0.15)
const VINE_LEAF: Color = Color(0.2, 0.38, 0.18)

const MID_ROCK: Color = Color(0.05, 0.1, 0.09)
const MID_RIM: Color = Color(0.13, 0.2, 0.15)
const MOSS: Color = Color(0.2, 0.36, 0.17)

const POOL_BANDS: Array[Color] = [Color(0.12, 0.3, 0.26), Color(0.09, 0.24, 0.22), Color(0.06, 0.17, 0.17)]
const POOL_LINE: Color = Color(0.4, 0.62, 0.45)
const NEAR_BODY: Color = Color(0.02, 0.05, 0.05)
const NEAR_RIM: Color = Color(0.08, 0.16, 0.12)

## The holes in the ceiling: strip x of their middles and half widths.
const HOLES: Array[Vector2] = [Vector2(170, 48), Vector2(470, 34)]
const POOL_SCREEN_ROW: int = 164


func _build_layers() -> void:
	add_painted_layer("Depths", Vector2(0.01, 0.0), _paint_depths)
	var far: BackdropLayer = add_painted_layer("Sinkhole", Vector2(0.06, 0.02), _paint_sinkhole)
	far.draw_extra = _draw_light_and_vines
	add_painted_layer("MossyRocks", Vector2(0.2, 0.07), _paint_mossy_rocks)
	var pool: BackdropLayer = add_painted_layer("Pool", Vector2(0.42, 0.13), _paint_pool)
	pool.draw_extra = _draw_pool_glints

	var fireflies: BackdropMotes = BackdropMotes.new()
	fireflies.shape = BackdropMotes.Shape.FIREFLY
	fireflies.mote_count = 16
	fireflies.colors = [Color(0.8, 1.0, 0.5, 0.85), Color(0.6, 1.0, 0.7, 0.75)]
	fireflies.velocity = Vector2(2.0, -1.0)
	fireflies.sway_amplitude = 4.0
	fireflies.sway_speed = 0.25
	fireflies.scroll_factor = 0.45
	fireflies.seed_value = 1311
	add_motes(fireflies)

	var drips: BackdropMotes = BackdropMotes.new()
	drips.mote_count = 5
	drips.colors = [Color(0.7, 0.95, 0.85, 0.5)]
	drips.velocity = Vector2(0.0, 75.0)
	drips.scroll_factor = 0.4
	drips.seed_value = 1312
	add_motes(drips)


## Dark cave air, with the daylight beyond the ceiling holes.
func _paint_depths() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, DEPTH_BANDS, 0, BackdropPaint.STRIP_HEIGHT)
	for hole: Vector2 in HOLES:
		BackdropPaint.put_circle(image, Vector2(hole.x, BackdropPaint.row(-14)), hole.y + 8.0, SKY_LIGHT)
		BackdropPaint.put_circle(image, Vector2(hole.x - 6.0, BackdropPaint.row(-20)), hole.y - 8.0, SKY_BRIGHT)
	return image


## How far `x` is inside a ceiling hole: 1 in its middle, 0 outside it.
static func _hole_openness(x: int) -> float:
	var openness: float = 0.0
	for hole: Vector2 in HOLES:
		var distance: float = absf(wrapf(x - hole.x, -BackdropPaint.STRIP_WIDTH / 2.0, BackdropPaint.STRIP_WIDTH / 2.0))
		openness = maxf(openness, 1.0 - smoothstep(hole.y - 14.0, hole.y, distance))
	return openness


## The sinkhole's walls: a ceiling with holes in it (lit rims where the daylight
## catches them), stalactites, and a far floor.
func _paint_sinkhole() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(110.0, 18.0), Vector2(30.0, 6.0), Vector2(9.0, 2.0)]
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(30), octaves, 1321, true)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# Inside a hole the ceiling pulls up out of the strip: open sky.
		ceiling[x] = lerpf(ceiling[x], -4.0, _hole_openness(x))
	BackdropPaint.fill_above(image, ceiling, FAR_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, FAR_RIM, 2)
	BackdropPaint.paint_spikes(image, ceiling, 1, 18, 20.0, FAR_BODY, FAR_RIM, 1322)
	var ground: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(156), octaves, 1323, false)
	BackdropPaint.fill_below(image, ground, FAR_BODY)
	BackdropPaint.paint_rim(image, ground, FAR_RIM)
	return image


## Light shafts down from each hole, and vines hanging through it, swaying.
func _draw_light_and_vines(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for hole: Vector2 in HOLES:
		BackdropTheme.draw_light_shafts(layer, copy_x, time, [hole.x - hole.y * 0.7, hole.x + 4.0] as Array[float],
			hole.y * 0.55, 0.12, 190.0, SHAFT_COLOR)
	for hole_index: int in HOLES.size():
		var hole: Vector2 = HOLES[hole_index]
		for vine_index: int in 6:
			var top: Vector2 = Vector2(copy_x + hole.x - hole.y + vine_index * hole.y * 0.4, BackdropPaint.row(-2))
			var length: float = 40.0 + BackdropPaint.random01(hole_index, vine_index, 1324) * 70.0
			var previous: Vector2 = top
			for step: int in range(4, roundi(length), 4):
				var along: float = step / length
				# Swaying more toward the bottom, like a hanging rope.
				var sway: float = sin(time * 0.7 + vine_index * 1.3 + hole_index) * 4.0 * along * along
				var point: Vector2 = (top + Vector2(sway, step)).round()
				layer.draw_line(previous, point, VINE_COLOR)
				if step % 8 == 0:
					layer.draw_rect(Rect2(point + Vector2(-1.0 if (step / 8) % 2 == 0 else 1.0, 0.0), Vector2(1.0, 1.0)), VINE_LEAF)
				previous = point


## Rock in the middle distance with thick moss on every top, and roots of rock.
func _paint_mossy_rocks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var edges: Array[PackedFloat32Array] = BackdropPaint.paint_cave(image, BackdropPaint.row(-6), BackdropPaint.row(158), 18.0,
		MID_ROCK, MID_RIM, 14, 22.0, 1331)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# Moss: a 2-row cap on the floor rock, its lower edge dithered.
		var top: int = ceili(edges[1][x])
		BackdropPaint.put_pixel(image, x, top, MOSS)
		if BackdropPaint.checker(x, top + 1):
			BackdropPaint.put_pixel(image, x, top + 1, MOSS)
		# Moss hangs off the ceiling's edge here and there in short beards.
		if BackdropPaint.periodic_noise(x, 20.0, 1332) > 0.65:
			var beard: int = 2 + roundi(BackdropPaint.random01(x, 1, 1332) * 5.0)
			BackdropPaint.put_rect(image, Rect2i(x, floori(edges[0][x]), 1, beard), MOSS)
	return image


## The still pool along the bottom, near rocks rising out of it, and a near ceiling.
func _paint_pool() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var waterline: int = BackdropPaint.row(POOL_SCREEN_ROW)
	var water: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(water, POOL_BANDS, waterline, BackdropPaint.STRIP_HEIGHT)
	image.blit_rect(water, Rect2i(0, waterline, BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT - waterline), Vector2i(0, waterline))
	image.fill_rect(Rect2i(0, waterline, BackdropPaint.STRIP_WIDTH, 1), POOL_LINE)
	var rocks: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(POOL_SCREEN_ROW + 24), Vector2(10.0, 22.0), 70, 1341)
	BackdropPaint.fill_below(image, rocks, NEAR_BODY)
	BackdropPaint.paint_rim(image, rocks, MOSS)
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(-6), [Vector2(140.0, 14.0), Vector2(30.0, 5.0)] as Array[Vector2], 1342, false)
	for x: int in BackdropPaint.STRIP_WIDTH:
		ceiling[x] = lerpf(ceiling[x], -4.0, _hole_openness(x))
	BackdropPaint.fill_above(image, ceiling, NEAR_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, NEAR_RIM)
	return image


## The pool's surface glints where the light shafts land, on and off.
func _draw_pool_glints(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var waterline: float = BackdropPaint.row(POOL_SCREEN_ROW)
	for glint_index: int in 24:
		var x: float = BackdropPaint.random01(glint_index, 1, 1343) * BackdropPaint.STRIP_WIDTH
		var shimmer: float = sin(time * 2.0 + glint_index * 2.7)
		if shimmer > 0.4:
			var y: float = waterline + 2.0 + floorf(BackdropPaint.random01(glint_index, 2, 1343) * 6.0) * 2.0
			layer.draw_rect(Rect2(copy_x + x, y, 3.0 + roundf(shimmer * 3.0), 1.0), Color(POOL_LINE, 0.7))
