extends BackdropTheme
## SHORE, UNDERGROUND: a sea cave. Through arches in the dark rock you see the
## bright sea and sky outside; inside, the grotto's ceiling bristles with
## stalactites and wavering light bounces up onto it from the water; the cave's
## own water fills the floor, and near rocks hold tide pools with starfish and
## shells; drips fall. Layers far to near; see BackdropTheme. (Surface:
## surface.gd, the beach; high up: skyline.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const OUTSIDE_SKY: Array[Color] = [Color(0.5, 0.68, 0.84), Color(0.62, 0.77, 0.87), Color(0.76, 0.85, 0.88)]
const OUTSIDE_SEA: Array[Color] = [Color(0.22, 0.5, 0.64), Color(0.2, 0.44, 0.6), Color(0.17, 0.38, 0.55)]
const OUTSIDE_HORIZON_SCREEN_ROW: int = 104

const MOUTH_BODY: Color = Color(0.09, 0.11, 0.15)
const MOUTH_RIM: Color = Color(0.32, 0.44, 0.5)
const MOUTH_LIT: Color = Color(0.16, 0.2, 0.25)
const CAUSTIC: Color = Color(0.55, 0.85, 0.9, 0.12)

const GROTTO_BODY: Color = Color(0.05, 0.07, 0.1)
const GROTTO_RIM: Color = Color(0.16, 0.25, 0.3)

const WATER_BANDS: Array[Color] = [Color(0.1, 0.3, 0.36), Color(0.07, 0.23, 0.3), Color(0.05, 0.16, 0.22)]
const WATER_LINE: Color = Color(0.4, 0.7, 0.72)
const WATER_SCREEN_ROW: int = 160

const NEAR_BODY: Color = Color(0.03, 0.04, 0.06)
const NEAR_RIM: Color = Color(0.13, 0.18, 0.22)
const POOL_COLOR: Color = Color(0.1, 0.28, 0.32)
const STARFISH: Color = Color(0.85, 0.42, 0.25)
const SHELL: Color = Color(0.85, 0.78, 0.68)

## The cave mouth's arches: strip x of the middle, half width, top (screen row).
const ARCHES: Array[Vector3] = [Vector3(150, 56, 36), Vector3(460, 40, 52)]


func _build_layers() -> void:
	add_painted_layer("Outside", Vector2(0.01, 0.0), _paint_outside)
	var mouth: BackdropLayer = add_painted_layer("CaveMouth", Vector2(0.05, 0.0), _paint_cave_mouth)
	mouth.draw_extra = _draw_bounced_light
	add_painted_layer("Grotto", Vector2(0.18, 0.06), _paint_grotto)
	var water: BackdropLayer = add_painted_layer("Water", Vector2(0.28, 0.0), _paint_water)
	water.draw_extra = _draw_ripples
	add_painted_layer("TidePools", Vector2(0.45, 0.14), _paint_tide_pools)

	var drips: BackdropMotes = BackdropMotes.new()
	drips.mote_count = 6
	drips.colors = [Color(0.7, 0.9, 1.0, 0.5)]
	drips.velocity = Vector2(0.0, 75.0)
	drips.scroll_factor = 0.4
	drips.seed_value = 1611
	add_motes(drips)

	var glints: BackdropMotes = BackdropMotes.new()
	glints.shape = BackdropMotes.Shape.FIREFLY
	glints.mote_count = 10
	glints.colors = [Color(0.7, 0.95, 1.0, 0.6)]
	glints.velocity = Vector2(1.0, 0.0)
	glints.sway_amplitude = 2.0
	glints.sway_speed = 0.3
	glints.scroll_factor = 0.3
	glints.seed_value = 1612
	add_motes(glints)


## The bright day outside: sky over a sea.
func _paint_outside() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var horizon: int = BackdropPaint.row(OUTSIDE_HORIZON_SCREEN_ROW)
	BackdropPaint.paint_bands(image, OUTSIDE_SEA, horizon, BackdropPaint.STRIP_HEIGHT)
	var sky: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(sky, OUTSIDE_SKY, BackdropPaint.row(10), horizon)
	image.blit_rect(sky, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, horizon), Vector2i.ZERO)
	image.fill_rect(Rect2i(0, horizon, BackdropPaint.STRIP_WIDTH, 1), Color(0.75, 0.88, 0.9))
	return image


## The open part of `arch` (an ARCHES entry) on strip row `y`: Vector2(left,
## right) strip x, or Vector2.ZERO above it. A half-ellipse on top of straight
## sides; the sides wobble a little with the rock.
static func _arch_span(arch: Vector3, y: int) -> Vector2:
	var half_width: float = arch.y + (BackdropPaint.periodic_noise(y * 3.0, 20.0, 1621) - 0.5) * 6.0
	var top: float = BackdropPaint.row(arch.z)
	var spring: float = top + arch.y * 0.7  # where the round top meets the sides
	if y < top:
		return Vector2.ZERO
	if y < spring:
		# In the round top: the ellipse's half width at this height.
		var height_up: float = (spring - y) / (spring - top)
		half_width *= sqrt(maxf(0.0, 1.0 - height_up * height_up))
	return Vector2(roundf(arch.x - half_width), roundf(arch.x + half_width))


## The rock around the arches, with a lit rim along every opening's edge: fill
## it all, cut each arch out row by row, then edge what was cut.
func _paint_cave_mouth() -> Image:
	var image: Image = BackdropPaint.new_strip()
	image.fill(MOUTH_BODY)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	for arch: Vector3 in ARCHES:
		for y: int in BackdropPaint.STRIP_HEIGHT:
			var span: Vector2 = _arch_span(arch, y)
			if span != Vector2.ZERO:
				BackdropPaint.put_rect(image, Rect2i(int(span.x), y, int(span.y - span.x) + 1, 1), clear)
	for arch: Vector3 in ARCHES:
		for y: int in BackdropPaint.STRIP_HEIGHT:
			var span: Vector2 = _arch_span(arch, y)
			if span == Vector2.ZERO:
				continue
			# The sides: the rim right next to the opening, a lit band behind it.
			for side: int in [-1, 1]:
				var edge: int = int(span.x) - 1 if side < 0 else int(span.y) + 1
				_edge_pixel(image, edge, y, MOUTH_RIM)
				_edge_pixel(image, edge + side, y, MOUTH_LIT)
				_edge_pixel(image, edge + side * 2, y, MOUTH_LIT)
			# The round top: rock just above an open pixel.
			for x: int in range(int(span.x), int(span.y) + 1):
				_edge_pixel(image, x, y - 1, MOUTH_RIM)
				_edge_pixel(image, x, y - 2, MOUTH_LIT)
	return image


## Paints `color` at (x, y) only if that pixel is rock (not open, not a rim yet).
static func _edge_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if y < 0 or y >= BackdropPaint.STRIP_HEIGHT:
		return
	var wrapped_x: int = posmod(x, BackdropPaint.STRIP_WIDTH)
	var there: Color = image.get_pixel(wrapped_x, y)
	if there == MOUTH_BODY or (there == MOUTH_LIT and color == MOUTH_RIM):
		image.set_pixel(wrapped_x, y, color)


## Wavering light bounced up from the water onto the rock around the arches.
func _draw_bounced_light(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for arch_index: int in ARCHES.size():
		var arch: Vector3 = ARCHES[arch_index]
		for line_index: int in 6:
			var y: float = BackdropPaint.row(arch.z) + 4.0 + line_index * 9.0
			var wave: float = sin(time * 1.3 + line_index * 1.7 + arch_index)
			var left: float = copy_x + arch.x - arch.y - 26.0 + wave * 6.0
			layer.draw_rect(Rect2(left, y + roundf(wave), 14.0 + wave * 4.0, 1.0), CAUSTIC)
			layer.draw_rect(Rect2(left + arch.y * 2.0 + 30.0, y - roundf(wave), 12.0 - wave * 4.0, 1.0), CAUSTIC)


## The grotto: stalactites from the ceiling, low rock along the sides.
func _paint_grotto() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(120.0, 18.0), Vector2(30.0, 7.0), Vector2(9.0, 2.0)]
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(18), octaves, 1631, true)
	BackdropPaint.fill_above(image, ceiling, GROTTO_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, GROTTO_RIM)
	BackdropPaint.paint_spikes(image, ceiling, 1, 30, 28.0, GROTTO_BODY, GROTTO_RIM, 1632)
	var ledges: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(164), octaves, 1633, false)
	BackdropPaint.fill_below(image, ledges, GROTTO_BODY)
	BackdropPaint.paint_rim(image, ledges, GROTTO_RIM)
	return image


## The cave's water: dark bands with a light line along the top.
func _paint_water() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var waterline: int = BackdropPaint.row(WATER_SCREEN_ROW)
	var water: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(water, WATER_BANDS, waterline, BackdropPaint.STRIP_HEIGHT)
	image.blit_rect(water, Rect2i(0, waterline, BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT - waterline), Vector2i(0, waterline))
	return image


## Ripples on the water and the reflected glow of the arches on it.
func _draw_ripples(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var waterline: float = BackdropPaint.row(WATER_SCREEN_ROW)
	for x: int in range(0, BackdropPaint.STRIP_WIDTH, 2):
		var wave: float = roundf(sin(x * 0.08 + time * 1.2) * 0.8)
		layer.draw_rect(Rect2(copy_x + x, waterline + wave, 2.0, 1.0), WATER_LINE)
	for ripple_index: int in 14:
		var x: float = BackdropPaint.random01(ripple_index, 1, 1641) * BackdropPaint.STRIP_WIDTH
		var y: float = waterline + 4.0 + floorf(BackdropPaint.random01(ripple_index, 2, 1641) * 8.0) * 2.0
		var stretch: float = 4.0 + 3.0 * sin(time * 0.9 + ripple_index * 1.9)
		layer.draw_rect(Rect2(copy_x + x - stretch, y, stretch * 2.0, 1.0), Color(WATER_LINE, 0.35))


## Near rocks along the bottom with tide pools, starfish and shells, and a near
## ceiling edge at the top.
func _paint_tide_pools() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var rocks: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(196), Vector2(10.0, 24.0), 46, 1651)
	BackdropPaint.fill_below(image, rocks, NEAR_BODY)
	BackdropPaint.paint_rim(image, rocks, NEAR_RIM)
	for pool_index: int in 5:
		var center_x: int = roundi((pool_index + 0.5) * BackdropPaint.STRIP_WIDTH / 5.0)
		var top: int = ceili(rocks[center_x]) + 3
		BackdropPaint.put_rect(image, Rect2i(center_x - 6, top, 13, 2), POOL_COLOR)
		BackdropPaint.put_rect(image, Rect2i(center_x - 5, top, 6, 1), WATER_LINE)
	for spot_index: int in 9:
		var x: int = floori(BackdropPaint.random01(spot_index, 1, 1652) * BackdropPaint.STRIP_WIDTH)
		var y: int = ceili(rocks[x]) + 1
		if spot_index % 3 == 0:
			# A starfish: a plus with longer arms and a dot of a middle.
			BackdropPaint.put_rect(image, Rect2i(x - 2, y + 1, 5, 1), STARFISH)
			BackdropPaint.put_rect(image, Rect2i(x, y - 1, 1, 4), STARFISH)
			BackdropPaint.put_pixel(image, x - 1, y + 3, STARFISH)
			BackdropPaint.put_pixel(image, x + 1, y + 3, STARFISH)
		else:
			BackdropPaint.put_rect(image, Rect2i(x, y, 3, 2), SHELL)
			BackdropPaint.put_pixel(image, x + 1, y, SHELL.darkened(0.3))
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(-6), [Vector2(140.0, 12.0), Vector2(30.0, 5.0)] as Array[Vector2], 1653, true)
	BackdropPaint.fill_above(image, ceiling, NEAR_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, NEAR_RIM)
	return image
