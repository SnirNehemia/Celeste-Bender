extends BackdropTheme
## TEMPLE, SKYLINE: up on the temple's roofs at dusk. The same sky, towers, cloud
## sea and roof as the hall below (TempleStyle): distant tiered towers stand on
## the clouds, the hall's roof edge with curled-up eaves runs along the bottom
## with paper lanterns swinging below it, and a big lantern hangs right in front;
## petals drift on the wind. Layers far to near; see BackdropTheme. (Surface:
## surface.gd, the hall; below: underground.gd, the catacombs.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const LANTERN_COLOR: Color = Color(0.8, 0.32, 0.2)
const LANTERN_LIGHT: Color = Color(1.0, 0.72, 0.4)
const LANTERN_GLOW: Color = Color(1.0, 0.55, 0.25, 0.07)

## Lantern strings run from roof corner to corner (TempleStyle.ROOF_SECTION).
## Lanterns per string, and how far each string sags in the middle (px).
const LANTERNS_PER_STRING: int = 3
const STRING_SAG: float = 18.0


func _build_layers() -> void:
	add_tall_layer(TempleStyle.NAME, "Sky", Vector2(0.01, 0.0), TempleStyle.paint_sky, SKYLINE_SECTION)
	add_tall_layer(TempleStyle.NAME, "Towers", Vector2(0.04, 0.02), TempleStyle.paint_towers, SKYLINE_SECTION)
	add_tall_layer(TempleStyle.NAME, "Clouds", Vector2(0.12, 0.05), TempleStyle.paint_clouds, SKYLINE_SECTION, 3.0)
	var roof: BackdropLayer = add_tall_layer(TempleStyle.NAME, "Roof", Vector2(0.42, 0.13), TempleStyle.paint_roof, SKYLINE_SECTION)
	roof.draw_extra = _draw_lanterns
	add_drawn_layer("Front", TempleStyle.FRONT_SCROLL, func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		TempleStyle.draw_big_lantern(layer, Vector2(copy_x + 250.0, BackdropPaint.row(-30)), 56.0, time))

	var petals: BackdropMotes = BackdropMotes.new()
	petals.shape = BackdropMotes.Shape.LEAF
	petals.mote_count = 14
	petals.colors = [Color(0.95, 0.7, 0.75, 0.7), Color(1.0, 0.85, 0.85, 0.6)]
	petals.velocity = Vector2(22.0, 8.0)
	petals.sway_amplitude = 5.0
	petals.sway_speed = 0.4
	petals.scroll_factor = 0.6
	petals.seed_value = 711
	add_motes(petals)


## Paper lanterns on strings from one roof corner to the next: each string sags,
## and each lantern hangs from it on a short cord, swinging on its own slow
## pendulum, with a warm light inside and a soft glow.
func _draw_lanterns(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var corner_row: float = BackdropPaint.row(TempleStyle.EAVE_SCREEN_ROW) - 16.0
	for section_index: int in BackdropPaint.STRIP_WIDTH / TempleStyle.ROOF_SECTION:
		var from: Vector2 = Vector2(copy_x + section_index * TempleStyle.ROOF_SECTION, corner_row)
		var to: Vector2 = from + Vector2(TempleStyle.ROOF_SECTION, 0.0)
		var previous: Vector2 = from
		for step: int in range(1, 17):
			var point: Vector2 = _string_point(from, to, step / 16.0)
			layer.draw_line(previous, point, TempleStyle.ROOF_LIT)
			previous = point
		for lantern_index: int in LANTERNS_PER_STRING:
			var hook: Vector2 = _string_point(from, to, (lantern_index + 1.0) / (LANTERNS_PER_STRING + 1.0))
			var swing: float = sin(time * 1.4 + section_index * 2.0 + lantern_index * 1.1) * 0.3
			var body: Vector2 = (hook + Vector2(sin(swing), cos(swing)) * 9.0).round()
			layer.draw_line(hook, body, TempleStyle.ROOF_LIT)
			BackdropTheme.draw_glow(layer, body, 16.0, LANTERN_GLOW, 0.8 + 0.2 * sin(time * 5.0 + lantern_index))
			layer.draw_rect(Rect2(body + Vector2(-3, -1), Vector2(7, 8)), LANTERN_COLOR)
			layer.draw_rect(Rect2(body + Vector2(-2, 0), Vector2(5, 6)), LANTERN_LIGHT)
			layer.draw_rect(Rect2(body + Vector2(-3, 2), Vector2(7, 1)), LANTERN_COLOR)
			layer.draw_rect(Rect2(body + Vector2(-2, -1), Vector2(5, 1)), TempleStyle.ROOF_BODY)


## A point `along` (0-1) a string from `from` to `to`, sagging (a parabola).
static func _string_point(from: Vector2, to: Vector2, along: float) -> Vector2:
	return (from.lerp(to, along) + Vector2(0.0, STRING_SAG * 4.0 * along * (1.0 - along))).round()
