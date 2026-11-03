class_name CavernSkyline
extends BackdropTheme
## CAVERN, SKYLINE: out of the cave, up on the ridge of the mountains it runs
## through, in daylight. A clear sky with a few clouds; a far range pale with
## air; nearer, brown crags and rock towers; the ridge you stand on along the
## bottom, rocky, with tufts of dry grass; dark crags right in front. All the rock
## is the cave's own brown (CavernStyle.ROCK) in the ground's style, so breaking
## out of the cave (Backdrop.BREAK_SKYLINE_LOOKS: a band of that rock between the
## two) lands in the same mountains. Birds wheel and the wind blows streaks.
## Layers far to near; see BackdropTheme.
## (Below it, through the rock: surface.gd, the upper cave.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const SKY_BANDS: Array[Color] = [Color(0.32, 0.47, 0.72), Color(0.38, 0.53, 0.76), Color(0.46, 0.6, 0.8),
	Color(0.56, 0.67, 0.83), Color(0.66, 0.73, 0.86), Color(0.76, 0.79, 0.87), Color(0.84, 0.82, 0.86)]
## The air far rock fades into: the sky's pale lavender horizon.
const HORIZON: Color = Color(0.8, 0.8, 0.87)
const CLOUD_BODY: Color = Color(0.92, 0.92, 0.95)
const CLOUD_LIT: Color = Color(1.0, 1.0, 1.0)
const CLOUD_SHADE: Color = Color(0.78, 0.78, 0.86)
const SUN: Color = Color(1.0, 0.98, 0.88)
const SUN_RING: Color = Color(0.92, 0.9, 0.86)
## Dry grass on the ridge.
const BLADES: Array[Color] = [Color(0.74, 0.66, 0.38), Color(0.62, 0.56, 0.32), Color(0.82, 0.74, 0.46)]
## Dark brown crags in front, in the ground's style: [crust, rim, edge, inside, hatch, deep].
const FRONT_ROCK: Array[Color] = [Color(0.3, 0.19, 0.15), Color(0.42, 0.29, 0.21), Color(0.1, 0.06, 0.06),
	Color(0.08, 0.05, 0.05), Color(0.11, 0.07, 0.07), Color(0.05, 0.03, 0.04)]
## The front crags: Vector3(strip x, half width, height).
const FRONT_CRAGS: Array[Vector3] = [Vector3(20.0, 50.0, 124.0), Vector3(300.0, 30.0, 66.0), Vector3(470.0, 42.0, 98.0)]

const FAR_HAZE: float = 0.62
const MID_HAZE: float = 0.36
const TOWERS_HAZE: float = 0.2
## The rock towers: Vector3(strip x, half width, screen row of the top).
const TOWERS: Array[Vector3] = [Vector3(90.0, 13.0, 62.0), Vector3(118.0, 8.0, 88.0), Vector3(300.0, 16.0, 48.0),
	Vector3(470.0, 11.0, 74.0), Vector3(495.0, 7.0, 96.0)]
## Where the ridge you stand on is, as a screen row.
const RIDGE_ROW: float = 152.0


func _build_layers() -> void:
	# The rock band of the break down into the cave (Backdrop.BREAK_SKYLINE_LOOKS).
	crust_colors = [CavernStyle.ROCK[BackdropTerrain.INSIDE], CavernStyle.ROCK[BackdropTerrain.CRUST]]
	add_painted_layer("Sky", Vector2(0.01, 0.0), paint_sky)
	add_painted_layer("Clouds", Vector2(0.03, 0.0), paint_clouds, 2.0)
	add_painted_layer("FarRange", Vector2(0.06, 0.02), paint_far_range)
	add_painted_layer("Crags", Vector2(0.12, 0.04), paint_crags)
	add_painted_layer("Towers", Vector2(0.2, 0.07), paint_towers)
	add_painted_layer("Ridge", Vector2(0.34, 0.11), paint_ridge)
	add_painted_layer("Front", CavernStyle.FRONT_SCROLL, paint_front)

	var birds: BackdropMotes = BackdropMotes.new()
	birds.shape = BackdropMotes.Shape.BIRD
	birds.mote_count = 5
	birds.colors = [Color(0.2, 0.16, 0.2, 0.85)]
	birds.velocity = Vector2(9.0, -1.0)
	birds.sway_amplitude = 4.0
	birds.sway_speed = 0.2
	birds.size_range = Vector2i(1, 2)
	birds.scroll_factor = 0.3
	birds.vertical_range = Vector2(10.0, 90.0)
	birds.seed_value = 6601
	add_motes(birds)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 7
	wind.colors = [Color(1.0, 1.0, 1.0, 0.18)]
	wind.velocity = Vector2(40.0, 0.0)
	wind.size_range = Vector2i(2, 4)
	wind.scroll_factor = 0.6
	wind.seed_value = 6602
	add_motes(wind)


## The sky: bands, and the sun high up.
static func paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(140))
	var sun: Vector2 = Vector2(420.0, BackdropPaint.row(34))
	BackdropPaint.put_circle(image, sun, 13.0, SUN_RING)
	BackdropPaint.put_circle(image, sun, 9.0, SUN)
	return image


## A few flat-bottomed clouds, drifting.
static func paint_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var clouds: Array[Vector3] = [Vector3(60.0, 36.0, 22.0), Vector3(250.0, 22.0, 14.0), Vector3(380.0, 58.0, 26.0),
		Vector3(560.0, 30.0, 18.0)]  # (x, screen row, half width)
	for cloud_index: int in clouds.size():
		var cloud: Vector3 = clouds[cloud_index]
		BackdropPaint.paint_cloud(image, Vector2(cloud.x, BackdropPaint.row(cloud.y)), cloud.z, CLOUD_BODY, CLOUD_LIT,
			CLOUD_SHADE, 6611 + cloud_index)
	return image


## Ground-style rock under `tops`, from there to the strip's bottom, in the cave's
## brown pulled `haze` toward the horizon.
static func _paint_rock_band(image: Image, tops: PackedFloat32Array, from_row: int, haze: float, crust: float,
		seed_value: int) -> BackdropTerrain.Mask:
	var mask: BackdropTerrain.Mask = BackdropTerrain.new_band(from_row, BackdropPaint.STRIP_HEIGHT)
	mask.add_below(tops)
	BackdropTerrain.roughen(mask, seed_value)
	BackdropTerrain.paint(image, mask, BackdropTerrain.hazed(CavernStyle.ROCK, HORIZON, haze), crust, 10.0, 1, seed_value)
	return mask


## The far range: peaks pale with air along the horizon.
static func paint_far_range() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(100), [Vector2(160.0, 34.0), Vector2(48.0, 12.0),
		Vector2(14.0, 3.0)] as Array[Vector2], 6621, true)
	_paint_rock_band(image, tops, BackdropPaint.row(40), FAR_HAZE, 2.0, 6621)
	return image


## Brown crags, nearer: a jagged line of rock.
static func paint_crags() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(122), [Vector2(110.0, 26.0), Vector2(30.0, 10.0),
		Vector2(9.0, 3.0)] as Array[Vector2], 6631, true)
	_paint_rock_band(image, tops, BackdropPaint.row(70), MID_HAZE, 3.0, 6631)
	return image


## Rock towers: weathered stacks of layered rock (each layer its own width) rising
## out of a band of broken rock.
static func paint_towers() -> Image:
	const LAYER_ROWS: int = 5
	var image: Image = BackdropPaint.new_strip()
	var foot_row: int = BackdropPaint.row(142)
	var mask: BackdropTerrain.Mask = BackdropTerrain.new_band(BackdropPaint.row(30), BackdropPaint.STRIP_HEIGHT)
	mask.add_below(BackdropPaint.ridge(foot_row, [Vector2(90.0, 10.0), Vector2(22.0, 4.0)] as Array[Vector2], 6641, false))
	for tower_index: int in TOWERS.size():
		var tower: Vector3 = TOWERS[tower_index]
		var row: int = BackdropPaint.row(tower.z)
		while row < foot_row + 4:
			var along: float = float(row - BackdropPaint.row(tower.z)) / (foot_row - BackdropPaint.row(tower.z))
			var half_width: float = tower.y * (0.85 + 0.4 * along) * (0.65 + 0.7 * BackdropPaint.periodic_noise(row, 11.0, 6642 + tower_index))
			mask.add_rect(Rect2i(roundi(tower.x - half_width), row, roundi(half_width * 2.0), LAYER_ROWS))
			row += LAYER_ROWS
	BackdropTerrain.roughen(mask, 6643)
	BackdropTerrain.paint(image, mask, BackdropTerrain.hazed(CavernStyle.ROCK, HORIZON, TOWERS_HAZE), 3.5, 12.0, 2, 6643)
	return image


## The ridge you stand on: rocky, with tufts of dry grass and a few boulders on it.
static func paint_ridge() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(RIDGE_ROW), [Vector2(140.0, 22.0), Vector2(36.0, 8.0),
		Vector2(10.0, 2.0)] as Array[Vector2], 6651, false)
	var mask: BackdropTerrain.Mask = BackdropTerrain.new_band(BackdropPaint.row(RIDGE_ROW - 40.0), BackdropPaint.STRIP_HEIGHT)
	mask.add_below(tops)
	# Boulders sitting on the crest.
	for boulder: int in 5:
		var x: float = 40.0 + boulder * 130.0 + BackdropPaint.random01(boulder, 1, 6652) * 50.0
		var radius: float = 4.0 + BackdropPaint.random01(boulder, 2, 6652) * 6.0
		mask.add_circle(Vector2(x, tops[roundi(x) % BackdropPaint.STRIP_WIDTH] - radius * 0.5), radius)
	BackdropTerrain.roughen(mask, 6651)
	BackdropTerrain.paint(image, mask, CavernStyle.ROCK, 4.0, 12.0, 2, 6651)
	BackdropTerrain.paint_blades(image, mask, BLADES, 4, 4, 6651)
	return image


## Right in front: dark crags rising from the bottom (FRONT_CRAGS), jagged, in the
## ground's style.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var bottom: float = BackdropPaint.STRIP_HEIGHT + 4.0
	var tops: PackedFloat32Array = BackdropPaint.flat_line(bottom)
	for crag_index: int in FRONT_CRAGS.size():
		var crag: Vector3 = FRONT_CRAGS[crag_index]
		for dx: int in range(-ceili(crag.y), ceili(crag.y) + 1):
			var shape: float = 1.0 - pow(absf(dx) / crag.y, 1.4)
			# Peaky noise: broken ledges and points along the crag's outline.
			var jag: float = (1.0 - absf(BackdropPaint.periodic_noise(crag.x + dx, 9.0, 6661 + crag_index) * 2.0 - 1.0)) * 14.0
			var column: int = posmod(roundi(crag.x) + dx, BackdropPaint.STRIP_WIDTH)
			tops[column] = minf(tops[column], bottom - (crag.z - jag) * shape)
	var mask: BackdropTerrain.Mask = BackdropTerrain.new_band(BackdropPaint.row(20), BackdropPaint.STRIP_HEIGHT)
	mask.add_below(tops)
	BackdropTerrain.roughen(mask, 6664)
	BackdropTerrain.paint(image, mask, FRONT_ROCK, 3.0, 9.0, 1, 6664)
	return image
