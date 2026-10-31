extends BackdropTheme
## VOLCANO, SKYLINE: high above the ash cloud. The same sky, cone and ash cloud
## as the slopes below (VolcanoStyle): here the great cone's summit erupts above
## the ash, throwing up a column with lightning flickering in it and lava spraying
## from the top; nearer drifting ash clouds, a jagged rim in front with glowing
## cracks, and black rock spires right in front; embers and ash on the wind.
## Layers far to near; see BackdropTheme. (Surface: surface.gd, the slopes; inside
## the mountain: underground.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const LAVA: Color = Color(1.0, 0.55, 0.15)
const LAVA_CORE: Color = Color(1.0, 0.85, 0.45)
const LIGHTNING: Color = Color(0.85, 0.8, 1.0)
const CRATER_GLOW: Color = Color(1.0, 0.45, 0.1, 0.1)

const CLOUD_BODY: Color = Color(0.12, 0.08, 0.1)
const CLOUD_LIT: Color = Color(0.22, 0.14, 0.15)
const CLOUD_SHADE: Color = Color(0.5, 0.17, 0.09)

const RIM_BODY: Color = Color(0.04, 0.02, 0.03)
const RIM_LIT: Color = Color(0.09, 0.04, 0.05)
const RIM_EDGE: Color = Color(0.62, 0.22, 0.08)
const CRACK: Color = Color(0.95, 0.4, 0.1)
const CRACK_GLOW: Color = Color(1.0, 0.45, 0.1, 0.08)

const SUMMIT_X: int = VolcanoStyle.CRATER_X
const SUMMIT_SCREEN_ROW: int = VolcanoStyle.CRATER_SCREEN_ROW
## How often (s) a lightning bolt may flash in the ash column, and for how long.
const LIGHTNING_PERIOD: float = 2.3
const LIGHTNING_TIME: float = 0.12


func _build_layers() -> void:
	add_tall_layer(VolcanoStyle.NAME, "Sky", Vector2(0.01, 0.0), VolcanoStyle.paint_sky, SKYLINE_SECTION)
	var summit: BackdropLayer = add_tall_layer(VolcanoStyle.NAME, "Volcano", Vector2(0.03, 0.01), VolcanoStyle.paint_volcano, SKYLINE_SECTION)
	summit.draw_extra = _draw_eruption
	add_tall_layer(VolcanoStyle.NAME, "AshBank", Vector2(0.08, 0.03), VolcanoStyle.paint_ash_bank, SKYLINE_SECTION, 2.0)
	add_painted_layer("AshClouds", Vector2(0.2, 0.07), _paint_ash_clouds, 6.0)
	var rim: BackdropLayer = add_painted_layer("CraterRim", Vector2(0.42, 0.13), _paint_crater_rim)
	rim.draw_extra = _draw_crack_glow
	add_painted_layer("Front", VolcanoStyle.FRONT_SCROLL, _paint_front)

	var embers: BackdropMotes = BackdropMotes.new()
	embers.shape = BackdropMotes.Shape.FIREFLY
	embers.mote_count = 18
	embers.colors = [Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.8, 0.35, 0.8)]
	embers.velocity = Vector2(14.0, -12.0)
	embers.sway_amplitude = 3.0
	embers.sway_speed = 0.4
	embers.scroll_factor = 0.55
	embers.seed_value = 2011
	add_motes(embers)

	var ash: BackdropMotes = BackdropMotes.new()
	ash.shape = BackdropMotes.Shape.STREAK
	ash.mote_count = 16
	ash.colors = [Color(0.5, 0.4, 0.42, 0.25), Color(0.35, 0.28, 0.3, 0.35)]
	ash.velocity = Vector2(60.0, 4.0)
	ash.size_range = Vector2i(2, 5)
	ash.scroll_factor = 0.5
	ash.seed_value = 2012
	add_motes(ash)


## The eruption, live: lava sprays up from the crater in arcs and falls back, the
## crater glows, and now and then lightning cracks through the ash column.
func _draw_eruption(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var crater: Vector2 = Vector2(copy_x + SUMMIT_X, BackdropPaint.row(SUMMIT_SCREEN_ROW))
	var pulse: float = 0.6 + 0.3 * sin(time * 1.7) + 0.1 * sin(time * 5.3)
	BackdropTheme.draw_glow(layer, crater + Vector2(0.0, -4.0), 30.0, CRATER_GLOW, pulse)
	for spark_index: int in 14:
		var period: float = 1.2 + BackdropPaint.random01(spark_index, 1, 2025) * 0.9
		var age: float = fmod(time + BackdropPaint.random01(spark_index, 2, 2025) * period, period)
		var launch: Vector2 = Vector2((BackdropPaint.random01(spark_index, 3, 2025) - 0.5) * 30.0, -30.0 - BackdropPaint.random01(spark_index, 4, 2025) * 25.0)
		# A ballistic arc: up with `launch`, pulled back down by "gravity".
		var spot: Vector2 = crater + launch * age + Vector2(0.0, 45.0 * age * age)
		if spot.y < crater.y + 2.0:
			layer.draw_rect(Rect2(spot.round(), Vector2.ONE * (2.0 if age < period * 0.4 else 1.0)), LAVA_CORE if age < period * 0.3 else LAVA)
	# Lightning: in some periods (by hash, the same every run) a bolt flashes briefly.
	var flash_index: int = floori(time / LIGHTNING_PERIOD)
	var flash_age: float = fmod(time, LIGHTNING_PERIOD)
	if flash_age < LIGHTNING_TIME and BackdropPaint.random01(flash_index, 1, 2026) > 0.35:
		var point: Vector2 = crater + Vector2(10.0 + BackdropPaint.random01(flash_index, 2, 2026) * 50.0, -60.0 - BackdropPaint.random01(flash_index, 3, 2026) * 30.0)
		for segment: int in 5:
			var next: Vector2 = point + Vector2((BackdropPaint.random01(flash_index, segment + 10, 2026) - 0.5) * 14.0, 7.0)
			layer.draw_line(point.round(), next.round(), LIGHTNING)
			point = next


func _paint_ash_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for cloud_index: int in 6:
		var center: Vector2 = Vector2((cloud_index + BackdropPaint.random01(cloud_index, 1, 2041) * 0.6) * BackdropPaint.STRIP_WIDTH / 6.0,
			BackdropPaint.row(40 + BackdropPaint.random01(cloud_index, 2, 2041) * 90.0))
		var half_width: float = 16.0 + BackdropPaint.random01(cloud_index, 3, 2041) * 22.0
		BackdropPaint.paint_cloud(image, center, half_width, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 2042)
	return image


## The crater rim in front: jagged black rock, its edges and cracks glowing.
func _paint_crater_rim() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(130.0, 34.0), Vector2(30.0, 10.0), Vector2(8.0, 3.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(196), octaves, 2051, true)
	BackdropPaint.paint_mountains(image, tops, RIM_BODY, RIM_LIT, RIM_EDGE, RIM_EDGE, RIM_EDGE, -100, 14.0, 2052)
	for crack_index: int in 7:
		var point: Vector2 = Vector2(_crack_x(crack_index), 0.0)
		point.y = tops[posmod(roundi(point.x), BackdropPaint.STRIP_WIDTH)] + 3.0
		for segment: int in 6:
			var next: Vector2 = point + Vector2((BackdropPaint.random01(crack_index, segment, 2053) - 0.5) * 8.0, 3.0 + segment)
			BackdropPaint.put_line(image, point, next, CRACK)
			point = next
	return image


static func _crack_x(crack_index: int) -> float:
	return (crack_index + BackdropPaint.random01(crack_index, 1, 2054) * 0.6) * BackdropPaint.STRIP_WIDTH / 7.0


func _draw_crack_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for crack_index: int in 7:
		var pulse: float = 0.5 + 0.5 * sin(time * 1.2 + crack_index * 1.9)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + _crack_x(crack_index), BackdropPaint.row(190)), 16.0, CRACK_GLOW, pulse)


## Right in front: black rock spires rising from below, glowing along their edges.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_crag(image, 40.0, 30.0, 120.0, VolcanoStyle.FRONT_BODY, VolcanoStyle.FRONT_LIT, RIM_EDGE, 2061)
	BackdropPaint.paint_crag(image, 76.0, 18.0, 70.0, VolcanoStyle.FRONT_BODY, VolcanoStyle.FRONT_LIT, RIM_EDGE, 2062)
	BackdropPaint.paint_crag(image, 470.0, 24.0, 86.0, VolcanoStyle.FRONT_BODY, VolcanoStyle.FRONT_LIT, RIM_EDGE, 2063)
	return image
