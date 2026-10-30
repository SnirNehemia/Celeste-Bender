extends BackdropTheme
## UNDERWATER, SKYLINE: right at the sea's surface. The screen is split by the
## waterline: above it a dusk sky with distant islands and their reflections,
## below it bright shallow water with light rays and swaying sea grass on a sandy
## bed far down; the surface itself ripples and glitters. Bubbles stay under the
## waterline. Layers far to near; see BackdropTheme. (Surface: surface.gd, the
## reef; the deep: underground.gd.)
##
## Every layer here moves only sideways with the camera (vertical factor 0): the
## waterline must stay at the same height in all of them.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The waterline, in screen rows.
const WATERLINE_SCREEN_ROW: int = 64

const SKY_BANDS: Array[Color] = [Color(0.16, 0.2, 0.36), Color(0.26, 0.28, 0.44), Color(0.4, 0.37, 0.5),
	Color(0.56, 0.47, 0.52), Color(0.7, 0.56, 0.5)]
const WATER_BANDS: Array[Color] = [Color(0.15, 0.4, 0.48), Color(0.12, 0.34, 0.43), Color(0.1, 0.28, 0.38),
	Color(0.08, 0.23, 0.33), Color(0.06, 0.18, 0.28)]
const SUN_COLOR: Color = Color(0.95, 0.75, 0.5)

const ISLAND_BODY: Color = Color(0.25, 0.25, 0.38)
const ISLAND_RIM: Color = Color(0.36, 0.34, 0.46)
const REFLECTION_COLOR: Color = Color(0.2, 0.3, 0.42)

const SURFACE_LIGHT: Color = Color(0.55, 0.8, 0.85)
const SURFACE_CREST: Color = Color(0.85, 0.95, 0.95)
const RAY_COLOR: Color = Color(0.7, 0.95, 1.0, 0.07)

const BED_BODY: Color = Color(0.07, 0.2, 0.25)
const BED_RIM: Color = Color(0.13, 0.3, 0.33)
const GRASS_COLOR: Color = Color(0.08, 0.26, 0.24)

const GRASS_BLADES: int = 40


func _build_layers() -> void:
	add_painted_layer("SkyAndSea", Vector2(0.01, 0.0), _paint_sky_and_sea)
	add_painted_layer("Islands", Vector2(0.04, 0.0), _paint_islands)
	add_drawn_layer("Rays", Vector2(0.08, 0.0), _draw_rays)
	var bed: BackdropLayer = add_painted_layer("SeaBed", Vector2(0.22, 0.0), _paint_sea_bed)
	bed.draw_extra = _draw_sea_grass
	add_drawn_layer("Surface", Vector2(0.3, 0.0), _draw_surface)

	var bubbles: BackdropMotes = BackdropMotes.new()
	bubbles.shape = BackdropMotes.Shape.BUBBLE
	bubbles.mote_count = 12
	bubbles.colors = [Color(0.7, 0.95, 1.0, 0.35), Color(0.7, 0.95, 1.0, 0.2)]
	bubbles.velocity = Vector2(0.0, -14.0)
	bubbles.sway_amplitude = 2.0
	bubbles.sway_speed = 0.8
	bubbles.size_range = Vector2i(1, 2)
	bubbles.scroll_factor = 0.5
	bubbles.vertical_range = Vector2(WATERLINE_SCREEN_ROW + 4, 190)
	bubbles.seed_value = 1011
	add_motes(bubbles)


func _paint_sky_and_sea() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var waterline: int = BackdropPaint.row(WATERLINE_SCREEN_ROW)
	BackdropPaint.paint_bands(image, WATER_BANDS, waterline, BackdropPaint.row(185))
	# The sky above the waterline: its own bands, painted on a separate strip and copied in.
	var sky: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(sky, SKY_BANDS, BackdropPaint.row(-10), waterline)
	image.blit_rect(sky, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, waterline), Vector2i.ZERO)
	# A sun about to touch the sea, and its glittering path on the water below it.
	var sun_center: Vector2 = Vector2(250.0, waterline - 8)
	BackdropPaint.put_circle(image, sun_center, 13.0, SUN_COLOR)
	for y: int in range(waterline, waterline + 26, 2):
		var half_width: int = 10 - (y - waterline) / 4
		for x: int in range(250 - half_width, 250 + half_width):
			if (x + y / 2) % 3 != 0:
				BackdropPaint.blend_pixel(image, x, y, Color(SUN_COLOR, 0.5))
	return image


func _paint_islands() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var waterline: float = BackdropPaint.row(WATERLINE_SCREEN_ROW)
	var tops: PackedFloat32Array = BackdropPaint.mesas(waterline + 1.0, 5, Vector2(4.0, 22.0), Vector2(6.0, 20.0), 1021)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		if top >= waterline:
			continue
		image.fill_rect(Rect2i(x, top, 1, int(waterline) - top), ISLAND_BODY)
		image.set_pixel(x, top, ISLAND_RIM)
		# The reflection: the same height upside down, broken into dashes.
		for y: int in range(int(waterline) + 1, int(waterline) + 1 + (int(waterline) - top) / 2):
			if (x + y) % 3 != 0 and y % 2 == 0:
				image.set_pixel(x, y, REFLECTION_COLOR)
	return image


## Light rays from the surface down into the water, swaying.
func _draw_rays(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var waterline: float = BackdropPaint.row(WATERLINE_SCREEN_ROW) + 2.0
	for ray_index: int in 6:
		var top_x: float = copy_x + ray_index * 106.0 + 20.0
		var sway: float = sin(time * 0.4 + ray_index * 1.3) * 8.0
		var breathing: float = 0.6 + 0.4 * sin(time * 0.6 + ray_index * 2.1)
		var top_width: float = 14.0 + ray_index % 3 * 6.0
		layer.draw_colored_polygon(PackedVector2Array([
			Vector2(top_x, waterline), Vector2(top_x + top_width, waterline),
			Vector2(top_x + top_width * 2.0 + sway + 30.0, BackdropPaint.row(190)),
			Vector2(top_x + sway + 30.0, BackdropPaint.row(190))]), Color(RAY_COLOR, RAY_COLOR.a * breathing))


func _paint_sea_bed() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(176), [Vector2(160.0, 12.0), Vector2(40.0, 4.0)] as Array[Vector2], 1031, false)
	BackdropPaint.fill_below(image, tops, BED_BODY)
	BackdropPaint.paint_rim(image, tops, BED_RIM)
	return image


## Sea grass: short blades from the bed, leaning with the swell.
func _draw_sea_grass(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for blade_index: int in GRASS_BLADES:
		var x: float = copy_x + (blade_index + BackdropPaint.random01(blade_index, 1, 1032) * 0.8) * BackdropPaint.STRIP_WIDTH / GRASS_BLADES
		var height: float = 6.0 + BackdropPaint.random01(blade_index, 2, 1032) * 10.0
		var foot: Vector2 = Vector2(x, BackdropPaint.row(170))
		var lean: float = sin(time * 1.1 + x * 0.05) * 3.0
		layer.draw_line(foot.round(), (foot + Vector2(lean, -height)).round(), GRASS_COLOR)


## The surface: a rippling bright line along the waterline, with crests that
## glitter on and off as the waves pass.
func _draw_surface(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var waterline: float = BackdropPaint.row(WATERLINE_SCREEN_ROW)
	for x: int in range(0, BackdropPaint.STRIP_WIDTH, 2):
		var wave: float = roundf(sin(x * 0.07 + time * 1.6) * 1.0 + sin(x * 0.023 - time * 0.9) * 1.0)
		layer.draw_rect(Rect2(copy_x + x, waterline + wave, 2.0, 1.0), SURFACE_LIGHT)
		# Glitter: a crest pixel where two waves line up, blinking.
		if sin(x * 0.31 + time * 3.0) > 0.92:
			layer.draw_rect(Rect2(copy_x + x, waterline + wave - 1.0, 1.0, 1.0), SURFACE_CREST)
