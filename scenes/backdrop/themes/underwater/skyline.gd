extends BackdropTheme
## UNDERWATER, SKYLINE: right at the sea's surface. The screen is split by the
## waterline: above it a dusk sky with distant islands and their reflections,
## below it the top of the same column of sea as the reef and the deep below
## (UnderwaterStyle): bright water, light rays starting down, the peaks of the
## rock towers; the surface ripples and glitters, and big kelp blades reach up
## right in front. Bubbles stay under the waterline. Layers far to near; see
## BackdropTheme. (Surface: surface.gd, the reef; the deep: underground.gd.)
##
## Every layer here moves only sideways with the camera (vertical factor 0): the
## waterline must stay at the same height in all of them.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The waterline, in screen rows (shared with the rest of the sea).
const WATERLINE_SCREEN_ROW: int = UnderwaterStyle.WATERLINE_SCREEN_ROW

const ISLAND_BODY: Color = Color(0.25, 0.25, 0.38)
const ISLAND_RIM: Color = Color(0.36, 0.34, 0.46)
const REFLECTION_COLOR: Color = Color(0.2, 0.3, 0.42)

const SURFACE_LIGHT: Color = Color(0.55, 0.8, 0.85)
const SURFACE_CREST: Color = Color(0.85, 0.95, 0.95)


func _build_layers() -> void:
	add_tall_layer(UnderwaterStyle.NAME, "Water", Vector2(0.01, 0.0), UnderwaterStyle.paint_water, SKYLINE_SECTION)
	add_painted_layer("Islands", Vector2(0.04, 0.0), _paint_islands)
	add_drawn_layer("Rays", Vector2(0.06, 0.0), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		UnderwaterStyle.draw_rays(layer, copy_x, time, SKYLINE_SECTION))
	add_tall_layer(UnderwaterStyle.NAME, "Spires", Vector2(0.07, 0.0), UnderwaterStyle.paint_spires, SKYLINE_SECTION)
	add_drawn_layer("Surface", Vector2(0.3, 0.0), _draw_surface)
	add_painted_layer("Front", UnderwaterStyle.FRONT_SCROLL, _paint_front)

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


## Right in front: big kelp blades reaching up from the deep toward the light.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for blade: Vector3 in [Vector3(30.0, 120.0, 0.12), Vector3(52.0, 90.0, -0.1), Vector3(400.0, 104.0, 0.08)]:
		UnderwaterStyle.paint_kelp_blade(image, Vector2(blade.x, BackdropPaint.STRIP_HEIGHT), blade.y, blade.z, int(blade.x))
	return image
