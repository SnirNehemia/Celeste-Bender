extends BackdropTheme
## TEMPLE, SKYLINE: up on the temple's roofs at dusk. A warm sky with a big low
## sun, distant tiered towers standing on a sea of clouds, and a near roof edge
## with curled-up eaves and paper lanterns swinging below it; petals drift on the
## wind. Layers far to near; see BackdropTheme. (Surface: surface.gd, the hall;
## below: underground.gd, the catacombs.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const SKY_BANDS: Array[Color] = [Color(0.09, 0.12, 0.2), Color(0.14, 0.17, 0.27), Color(0.22, 0.22, 0.31),
	Color(0.34, 0.28, 0.33), Color(0.48, 0.35, 0.34), Color(0.6, 0.43, 0.35)]
const SUN_COLOR: Color = Color(0.92, 0.66, 0.42)
const SUN_RING: Color = Color(0.72, 0.5, 0.37)

const TOWER_BODY: Color = Color(0.27, 0.22, 0.3)
const TOWER_LIT: Color = Color(0.36, 0.28, 0.34)

const CLOUD_BODY: Color = Color(0.46, 0.36, 0.4)
const CLOUD_LIT: Color = Color(0.64, 0.5, 0.46)
const CLOUD_SHADE: Color = Color(0.36, 0.28, 0.34)

const ROOF_BODY: Color = Color(0.1, 0.07, 0.11)
const ROOF_LIT: Color = Color(0.2, 0.13, 0.17)
const ROOF_TILE_LINE: Color = Color(0.06, 0.04, 0.07)
const LANTERN_COLOR: Color = Color(0.8, 0.32, 0.2)
const LANTERN_LIGHT: Color = Color(1.0, 0.72, 0.4)
const LANTERN_GLOW: Color = Color(1.0, 0.55, 0.25, 0.07)

## The near roof's eave: the screen row of its edge; it curls up at every section
## corner, ROOF_SECTION px apart. Lantern strings run from corner to corner.
const EAVE_SCREEN_ROW: int = 150
const ROOF_SECTION: int = 160
## Lanterns per string, and how far each string sags in the middle (px).
const LANTERNS_PER_STRING: int = 3
const STRING_SAG: float = 18.0


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("Towers", Vector2(0.04, 0.02), _paint_towers)
	add_painted_layer("Clouds", Vector2(0.12, 0.05), _paint_clouds, 3.0)
	var roof: BackdropLayer = add_painted_layer("Roof", Vector2(0.42, 0.13), _paint_roof)
	roof.draw_extra = _draw_lanterns

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


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(130))
	var sun_center: Vector2 = Vector2(420.0, BackdropPaint.row(100))
	BackdropPaint.put_circle(image, sun_center, 30.0, SUN_RING)
	BackdropPaint.put_circle(image, sun_center, 23.0, SUN_COLOR)
	return image


## Distant towers: tiers of roofs getting smaller toward the top, each roof wider
## than the walls under it with tips curling up, and a spire on top.
func _paint_towers() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for tower_index: int in 4:
		var center_x: int = roundi((tower_index + 0.2 + BackdropPaint.random01(tower_index, 1, 721) * 0.6) * BackdropPaint.STRIP_WIDTH / 4.0)
		var tier_count: int = 3 + roundi(BackdropPaint.random01(tower_index, 2, 721) * 3.0)
		var y: int = BackdropPaint.row(150)
		var half_width: int = 16
		for tier_index: int in tier_count:
			var wall_height: int = 9
			BackdropPaint.put_rect(image, Rect2i(center_x - half_width + 3, y - wall_height, (half_width - 3) * 2, wall_height), TOWER_BODY)
			y -= wall_height
			# The roof: a flat slab, wider, with up-curled tips.
			BackdropPaint.put_rect(image, Rect2i(center_x - half_width - 2, y - 3, half_width * 2 + 4, 3), TOWER_BODY)
			BackdropPaint.put_rect(image, Rect2i(center_x - half_width - 2, y - 3, half_width * 2 + 4, 1), TOWER_LIT)
			BackdropPaint.put_pixel(image, center_x - half_width - 3, y - 4, TOWER_BODY)
			BackdropPaint.put_pixel(image, center_x + half_width + 2, y - 4, TOWER_BODY)
			y -= 3
			half_width = maxi(5, half_width - 3)
		BackdropPaint.put_rect(image, Rect2i(center_x, y - 10, 1, 10), TOWER_BODY)
	return image


func _paint_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(146), Vector2(5.0, 12.0), 11, 731)
	BackdropPaint.fill_below(image, tops, CLOUD_BODY)
	BackdropPaint.paint_rim(image, tops, CLOUD_LIT, 2)
	for cloud_index: int in 4:
		var center: Vector2 = Vector2((cloud_index + 0.5) * BackdropPaint.STRIP_WIDTH / 4.0, BackdropPaint.row(50 + cloud_index % 2 * 30))
		BackdropPaint.paint_cloud(image, center, 18.0 + cloud_index % 3 * 6.0, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 732)
	return image


## The near roof: a slope of tiles down to an eave that curls up at regular
## points (the corners of the roof sections), and the ridge of the next roof below.
func _paint_roof() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var eave_row: int = BackdropPaint.row(EAVE_SCREEN_ROW)
	var bottoms: PackedFloat32Array = PackedFloat32Array()
	bottoms.resize(BackdropPaint.STRIP_WIDTH)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# The eave curls up toward every section's corner.
		var along: float = float(posmod(x, ROOF_SECTION)) / ROOF_SECTION
		var curl: float = pow(absf(along * 2.0 - 1.0), 6.0) * 10.0
		bottoms[x] = eave_row - curl
	# The roof fills from the eave down (we're above it, looking along it).
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = roundi(bottoms[x]) - 6
		image.fill_rect(Rect2i(x, top, 1, BackdropPaint.STRIP_HEIGHT - top), ROOF_BODY)
		image.set_pixel(x, top, ROOF_LIT)
		# Rows of tiles: a lit lip and a dark groove every few px.
		for y: int in range(top + 4, BackdropPaint.STRIP_HEIGHT, 6):
			image.set_pixel(x, y, ROOF_TILE_LINE)
			if x % 6 == 0:
				image.fill_rect(Rect2i(x, y, 1, 6), ROOF_TILE_LINE)
	return image


## Paper lanterns on strings from one roof corner to the next: each string sags,
## and each lantern hangs from it on a short cord, swinging on its own slow
## pendulum, with a warm light inside and a soft glow.
func _draw_lanterns(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var corner_row: float = BackdropPaint.row(EAVE_SCREEN_ROW) - 16.0
	for section_index: int in BackdropPaint.STRIP_WIDTH / ROOF_SECTION:
		var from: Vector2 = Vector2(copy_x + section_index * ROOF_SECTION, corner_row)
		var to: Vector2 = from + Vector2(ROOF_SECTION, 0.0)
		var previous: Vector2 = from
		for step: int in range(1, 17):
			var point: Vector2 = _string_point(from, to, step / 16.0)
			layer.draw_line(previous, point, ROOF_LIT)
			previous = point
		for lantern_index: int in LANTERNS_PER_STRING:
			var hook: Vector2 = _string_point(from, to, (lantern_index + 1.0) / (LANTERNS_PER_STRING + 1.0))
			var swing: float = sin(time * 1.4 + section_index * 2.0 + lantern_index * 1.1) * 0.3
			var body: Vector2 = (hook + Vector2(sin(swing), cos(swing)) * 9.0).round()
			layer.draw_line(hook, body, ROOF_LIT)
			BackdropTheme.draw_glow(layer, body, 16.0, LANTERN_GLOW, 0.8 + 0.2 * sin(time * 5.0 + lantern_index))
			layer.draw_rect(Rect2(body + Vector2(-3, -1), Vector2(7, 8)), LANTERN_COLOR)
			layer.draw_rect(Rect2(body + Vector2(-2, 0), Vector2(5, 6)), LANTERN_LIGHT)
			layer.draw_rect(Rect2(body + Vector2(-3, 2), Vector2(7, 1)), LANTERN_COLOR)
			layer.draw_rect(Rect2(body + Vector2(-2, -1), Vector2(5, 1)), ROOF_BODY)


## A point `along` (0-1) a string from `from` to `to`, sagging (a parabola).
static func _string_point(from: Vector2, to: Vector2, along: float) -> Vector2:
	return (from.lerp(to, along) + Vector2(0.0, STRING_SAG * 4.0 * along * (1.0 - along))).round()
