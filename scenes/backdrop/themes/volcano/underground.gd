extends BackdropTheme
## VOLCANO, UNDERGROUND: the magma chamber inside the mountain. Everything is lit
## from below: a lake of lava along the bottom bubbles and glows, lava pours from
## cracks in the ceiling, rock edges catch the orange light on their undersides,
## and black glassy obsidian juts from the floor; embers rise. Layers far to near;
## see BackdropTheme. (Surface: surface.gd, the slopes; high up: skyline.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## Brighter toward the bottom, where the lava is.
const DEPTH_BANDS: Array[Color] = [Color(0.05, 0.02, 0.03), Color(0.09, 0.03, 0.04), Color(0.14, 0.05, 0.04),
	Color(0.21, 0.07, 0.04), Color(0.3, 0.1, 0.05)]

const FAR_BODY: Color = Color(0.11, 0.04, 0.05)
const FAR_RIM: Color = Color(0.4, 0.13, 0.06)

const FALL_EDGE: Color = Color(0.92, 0.36, 0.08)
const FALL_CORE: Color = Color(1.0, 0.72, 0.3)
const FALL_GLOW: Color = Color(1.0, 0.45, 0.1, 0.07)

const MID_BODY: Color = Color(0.07, 0.03, 0.04)
const MID_RIM: Color = Color(0.55, 0.18, 0.07)
const OBSIDIAN: Color = Color(0.1, 0.08, 0.15)
const OBSIDIAN_LIT: Color = Color(0.32, 0.28, 0.44)

const LAKE_BANDS: Array[Color] = [Color(1.0, 0.7, 0.28), Color(0.98, 0.5, 0.12), Color(0.85, 0.32, 0.07),
	Color(0.6, 0.18, 0.05)]
const LAKE_CRUST: Color = Color(0.3, 0.08, 0.05)
const BUBBLE: Color = Color(1.0, 0.85, 0.45)

const NEAR_BODY: Color = Color(0.03, 0.015, 0.02)
const NEAR_RIM: Color = Color(0.7, 0.24, 0.08)

const LAKE_SCREEN_ROW: int = 166
## The lava falls: strip x of each.
const FALLS: Array[float] = [110.0, 350.0, 520.0]


func _build_layers() -> void:
	crust_colors = [VolcanoStyle.GROUND_BODY, VolcanoStyle.GROUND_RIM]
	add_painted_layer("Depths", Vector2(0.01, 0.0), _paint_depths)
	add_painted_layer("FarCave", Vector2(0.06, 0.02), _paint_far_cave)
	add_drawn_layer("LavaFalls", Vector2(0.12, 0.04), _draw_lava_falls)
	add_painted_layer("Chamber", Vector2(0.2, 0.07), _paint_chamber)
	var lake: BackdropLayer = add_painted_layer("LavaLake", Vector2(0.3, 0.0), _paint_lake)
	lake.draw_extra = _draw_lake_bubbles
	add_painted_layer("NearRock", Vector2(0.45, 0.14), _paint_near_rock)
	add_painted_layer("Front", VolcanoStyle.FRONT_SCROLL, _paint_front)

	var embers: BackdropMotes = BackdropMotes.new()
	embers.shape = BackdropMotes.Shape.FIREFLY
	embers.mote_count = 24
	embers.colors = [Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.85, 0.4, 0.8)]
	embers.velocity = Vector2(2.0, -16.0)
	embers.sway_amplitude = 4.0
	embers.sway_speed = 0.35
	embers.scroll_factor = 0.5
	embers.seed_value = 1911
	add_motes(embers)


func _paint_depths() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, DEPTH_BANDS, 0, BackdropPaint.STRIP_HEIGHT)
	return image


func _paint_far_cave() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_cave(image, BackdropPaint.row(28), BackdropPaint.row(150), 20.0, FAR_BODY, FAR_RIM, 30, 24.0, 1921)
	return image


## Lava pouring from the ceiling: a stream with bright bands sliding down it, and
## a glow where it lands.
func _draw_lava_falls(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var top: float = BackdropPaint.row(8)
	var bottom: float = BackdropPaint.row(LAKE_SCREEN_ROW)
	for fall_index: int in FALLS.size():
		var x: float = copy_x + FALLS[fall_index]
		layer.draw_rect(Rect2(x - 2.0, top, 5.0, bottom - top), FALL_EDGE)
		var offset: float = fmod(time * 70.0 + fall_index * 23.0, 14.0)
		var y: float = top - 14.0 + offset
		while y < bottom:
			layer.draw_rect(Rect2(x - 1.0, maxf(y, top), 2.0, 6.0), FALL_CORE)
			y += 14.0
		var pulse: float = 0.6 + 0.4 * sin(time * 2.0 + fall_index)
		BackdropTheme.draw_glow(layer, Vector2(x, bottom), 24.0, FALL_GLOW, pulse)


## The chamber's rock: lit from below, so the CEILING's undersides glow orange
## and the floor's tops stay dark; obsidian shards stand on the floor.
func _paint_chamber() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(110.0, 18.0), Vector2(30.0, 7.0), Vector2(9.0, 2.0)]
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(6), octaves, 1931, true)
	BackdropPaint.fill_above(image, ceiling, MID_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, MID_RIM, 2)
	BackdropPaint.paint_spikes(image, ceiling, 1, 16, 22.0, MID_BODY, MID_RIM, 1932)
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(170), octaves, 1933, true)
	BackdropPaint.fill_below(image, floor_tops, MID_BODY)
	BackdropPaint.paint_rim(image, floor_tops, MID_RIM.darkened(0.5))
	for cluster_index: int in 5:
		var x: float = (cluster_index + 0.4) * BackdropPaint.STRIP_WIDTH / 5.0
		var root: float = floor_tops[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)] + 3.0
		for shard_index: int in 3:
			var angle: float = -PI * 0.5 + (shard_index - 1) * 0.35
			var length: float = 12.0 + BackdropPaint.random01(cluster_index, shard_index, 1934) * 14.0
			BackdropPaint.paint_shard(image, Vector2(x + (shard_index - 1) * 4, root), angle, length, 3.0, OBSIDIAN, OBSIDIAN_LIT)
	return image


## The lava lake: hot bands, darker deeper down, with crust plates on it.
func _paint_lake() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var surface: int = BackdropPaint.row(LAKE_SCREEN_ROW)
	var lake: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(lake, LAKE_BANDS, surface, BackdropPaint.STRIP_HEIGHT)
	image.blit_rect(lake, Rect2i(0, surface, BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT - surface), Vector2i(0, surface))
	for x: int in BackdropPaint.STRIP_WIDTH:
		for y: int in range(surface + 3, BackdropPaint.STRIP_HEIGHT):
			# Long plates, a band of them every 4 rows (see the surface's river).
			var crust: float = BackdropPaint.periodic_noise(x + (y / 4) * 41.0, 30.0, 1941 + y / 4)
			if crust > 0.72 or (crust > 0.66 and BackdropPaint.checker(x, y)):
				image.set_pixel(x, y, LAKE_CRUST)
	return image


## Bubbles that swell on the lake's surface and pop, each on its own clock.
func _draw_lake_bubbles(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var surface: float = BackdropPaint.row(LAKE_SCREEN_ROW)
	for bubble_index: int in 10:
		var period: float = 2.0 + BackdropPaint.random01(bubble_index, 1, 1942) * 2.5
		var age: float = fmod(time + BackdropPaint.random01(bubble_index, 2, 1942) * period, period) / period
		if age > 0.5:
			continue  # popped, waiting for the next one
		var x: float = copy_x + BackdropPaint.random01(bubble_index, 3, 1942) * BackdropPaint.STRIP_WIDTH
		var radius: float = 1.0 + age * 6.0
		layer.draw_arc(Vector2(roundf(x), surface + 1.0), radius, PI, TAU, 8, BUBBLE, 1.0)


## Near rock: a ceiling edge and floor rocks, their edges glowing from the lava.
func _paint_near_rock() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(140.0, 16.0), Vector2(30.0, 6.0)]
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(-4), octaves, 1951, true)
	BackdropPaint.fill_above(image, ceiling, NEAR_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, NEAR_RIM, 2)
	BackdropPaint.paint_spikes(image, ceiling, 1, 10, 26.0, NEAR_BODY, NEAR_RIM, 1952)
	var rocks: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(200), Vector2(8.0, 20.0), 60, 1953)
	BackdropPaint.fill_below(image, rocks, NEAR_BODY)
	BackdropPaint.paint_rim(image, rocks, NEAR_RIM)
	return image


## Right in front: huge shards of obsidian, black glass, in a bottom corner, and
## a dark rock fang hanging from above with a glowing drip on its tip.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for shard: Vector3 in [Vector3(460.0, 90.0, -0.25), Vector3(482.0, 60.0, 0.15), Vector3(440.0, 46.0, -0.6), Vector3(500.0, 36.0, 0.5)]:
		BackdropPaint.paint_shard(image, Vector2(shard.x, BackdropPaint.STRIP_HEIGHT), -PI * 0.5 + shard.z, shard.y, 9.0,
			VolcanoStyle.FRONT_BODY, OBSIDIAN_LIT.darkened(0.5))
	var fang_x: int = 150
	for step: int in 70:
		var half_width: int = roundi(12.0 * (1.0 - step / 70.0))
		BackdropPaint.put_rect(image, Rect2i(fang_x - half_width, step, half_width * 2 + 1, 1), VolcanoStyle.FRONT_BODY)
		BackdropPaint.put_pixel(image, fang_x + half_width, step, NEAR_RIM.darkened(0.3))
	BackdropPaint.put_rect(image, Rect2i(fang_x - 1, 70, 2, 3), FALL_CORE)
	return image
