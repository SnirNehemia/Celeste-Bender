class_name DesertSkyline
extends BackdropTheme
## DESERT, SKYLINE: high above the desert, among the tops of the rock towers. The
## same dusk sky, clouds and towers as the surface below (DesertStyle): here the
## towers' banded tops and the arch stand against the sky, and the dark banded
## sides of nearer towers rise right in front; warm wind. Layers far to near; see BackdropTheme. (Surface: surface.gd; beneath
## the sand: underground.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")


func _build_layers() -> void:
	DesertStyle.add_shared_layers(self, SKYLINE_SECTION)

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
## the screen (one) or to a broken top (the other), banded like the rest. Their
## feet stand in the surface's foreground (DesertStyle.paint_front_towers).
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	DesertStyle.paint_front_towers(image, false)
	return image
