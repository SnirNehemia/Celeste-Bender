class_name MountainSkyline
extends BackdropTheme
## MOUNTAIN, SKYLINE: above the clouds, near the summit. The same dusk sky, range
## and bank of cloud as the surface below (MountainStyle): here the summits stand
## above the cloud tops. Nearer puffy clouds drift by, a rocky summit ridge is
## strung with prayer flags that flutter, and dark crags rise in front; strong
## wind. Layers far to near; see BackdropTheme. (Surface: surface.gd; inside the
## mountain: underground.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const CLOUD_BODY: Color = Color(0.46, 0.42, 0.62)
const CLOUD_LIT: Color = Color(0.68, 0.65, 0.82)
const CLOUD_SHADE: Color = Color(0.36, 0.32, 0.52)

const SUMMIT_BODY: Color = Color(0.07, 0.07, 0.15)
const SUMMIT_RIM: Color = Color(0.2, 0.2, 0.32)
const SUMMIT_SNOW: Color = Color(0.42, 0.42, 0.56)
const FLAG_COLORS: Array[Color] = [Color(0.35, 0.45, 0.7), Color(0.75, 0.72, 0.62), Color(0.65, 0.3, 0.3),
	Color(0.35, 0.55, 0.38), Color(0.75, 0.62, 0.3)]
## The flag line: from pole to pole, strip px (screen rows), sagging in the middle.
const FLAG_LINE_FROM: Vector2 = Vector2(120.0, 128.0)
const FLAG_LINE_TO: Vector2 = Vector2(300.0, 140.0)
const FLAG_COUNT: int = 14


func _build_layers() -> void:
	MountainStyle.add_shared_layers(self, SKYLINE_SECTION)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 22
	wind.colors = [Color(0.8, 0.82, 1.0, 0.16), Color(0.8, 0.82, 1.0, 0.26)]
	wind.velocity = Vector2(95.0, 3.0)
	wind.sway_amplitude = 2.0
	wind.sway_speed = 0.5
	wind.size_range = Vector2i(3, 7)
	wind.scroll_factor = 0.55
	wind.seed_value = 611
	add_motes(wind)


static func paint_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for cloud_index: int in 7:
		var center: Vector2 = Vector2((cloud_index + BackdropPaint.random01(cloud_index, 1, 623) * 0.6) * BackdropPaint.STRIP_WIDTH / 7.0,
			BackdropPaint.row(30 + BackdropPaint.random01(cloud_index, 2, 623) * 100.0))
		var half_width: float = 14.0 + BackdropPaint.random01(cloud_index, 3, 623) * 22.0
		BackdropPaint.paint_cloud(image, center, half_width, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 624)
	return image


static func paint_summit() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(160.0, 26.0), Vector2(40.0, 10.0), Vector2(10.0, 3.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(196), octaves, 631, true)
	BackdropPaint.paint_mountains(image, tops, SUMMIT_BODY, SUMMIT_RIM, SUMMIT_RIM, SUMMIT_SNOW, SUMMIT_RIM, BackdropPaint.row(190), 20.0, 631)
	# Two poles for the flag line.
	for pole: Vector2 in [FLAG_LINE_FROM, FLAG_LINE_TO]:
		var foot_row: int = ceili(tops[roundi(pole.x)]) + 2
		var top_row: int = BackdropPaint.row(pole.y) - 3
		BackdropPaint.put_rect(image, Rect2i(roundi(pole.x), top_row, 1, foot_row - top_row), SUMMIT_RIM)
	return image


## The prayer flags: small squares hanging from a sagging line, each flapping
## sideways in the wind a little out of step with its neighbours.
static func draw_flags(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var from: Vector2 = Vector2(copy_x + FLAG_LINE_FROM.x, BackdropPaint.row(FLAG_LINE_FROM.y) - 3)
	var to: Vector2 = Vector2(copy_x + FLAG_LINE_TO.x, BackdropPaint.row(FLAG_LINE_TO.y) - 3)
	var previous: Vector2 = from
	for flag_index: int in FLAG_COUNT + 1:
		var along: float = float(flag_index) / FLAG_COUNT
		# Sag: a parabola, deepest in the middle.
		var point: Vector2 = from.lerp(to, along) + Vector2(0.0, 10.0 * 4.0 * along * (1.0 - along))
		point = point.round()
		layer.draw_line(previous, point, SUMMIT_RIM)
		previous = point
		if flag_index == FLAG_COUNT:
			break
		var flap: float = roundf(sin(time * 7.0 + flag_index * 0.8) * 1.5)
		var flag_color: Color = FLAG_COLORS[flag_index % FLAG_COLORS.size()]
		layer.draw_rect(Rect2(point.x + 2.0 + maxf(flap, 0.0), point.y + 1.0, 5.0 - absf(flap), 5.0), flag_color)


## Right in front: two dark crags with snow on their ledges, rising from below.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	MountainStyle.paint_crag(image, 70.0, 56.0, 70.0, 641)
	MountainStyle.paint_crag(image, 400.0, 38.0, 48.0, 642)
	return image
