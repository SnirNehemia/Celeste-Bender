extends BackdropTheme
## DESERT, SKYLINE: high above the desert, among the tops of the rock towers. The
## same dusk sky, clouds and towers as the surface below (DesertStyle): here the
## towers' banded tops and the arch stand against the sky, and the dark banded
## sides of nearer towers rise right in front; warm wind. Layers far to near; see BackdropTheme. (Surface: surface.gd; beneath
## the sand: underground.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")


func _build_layers() -> void:
	add_tall_layer(DesertStyle.NAME, "Sky", Vector2(0.01, 0.0), DesertStyle.paint_sky, SKYLINE_SECTION)
	add_tall_layer(DesertStyle.NAME, "Clouds", Vector2(0.03, 0.01), DesertStyle.paint_clouds, SKYLINE_SECTION, 3.0)
	add_tall_layer(DesertStyle.NAME, "Spires", Vector2(0.1, 0.04), DesertStyle.paint_spires, SKYLINE_SECTION)
	add_painted_layer("Front", DesertStyle.FRONT_SCROLL, _paint_front)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 18
	wind.colors = [Color(1.0, 0.8, 0.6, 0.16), Color(1.0, 0.8, 0.6, 0.24)]
	wind.velocity = Vector2(80.0, 2.0)
	wind.sway_amplitude = 2.0
	wind.sway_speed = 0.5
	wind.size_range = Vector2i(2, 6)
	wind.scroll_factor = 0.55
	wind.seed_value = 911
	add_motes(wind)


## Right in front: the sides of two near towers, rising from far below up past
## the screen (one) or to a broken top (the other), banded like the rest.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for tower: Vector3 in [Vector3(14.0, 26.0, -40.0), Vector3(350.0, 16.0, 96.0)]:
		var top: float = BackdropPaint.row(tower.z)
		for dx: int in range(-roundi(tower.y), roundi(tower.y) + 1):
			var x: int = roundi(tower.x) + dx
			var column_top: int = roundi(top + (BackdropPaint.periodic_noise(x, 6.0, 951) - 0.5) * 8.0 + absf(dx) * 0.25)
			BackdropPaint.put_rect(image, Rect2i(x, column_top, 1, BackdropPaint.STRIP_HEIGHT - column_top), DesertStyle.FRONT_BODY)
			BackdropPaint.put_pixel(image, x, column_top, DesertStyle.FRONT_RIM)
		BackdropPaint.put_rect(image, Rect2i(roundi(tower.x - tower.y), roundi(top) + 4, 2, BackdropPaint.STRIP_HEIGHT), DesertStyle.FRONT_LIT)
	BackdropPaint.paint_strata(image, BackdropPaint.flat_line(-10.0), DesertStyle.FRONT_LIT, 953)
	return image
