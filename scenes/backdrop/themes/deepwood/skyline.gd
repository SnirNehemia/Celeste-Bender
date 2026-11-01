class_name DeepwoodSkyline
extends BackdropTheme
## DEEPWOOD, SKYLINE: up on the roof of the dense forest at dawn. The same sky,
## rows of trees and mist as the forest floor below (DeepwoodStyle): here the
## low sun glows through the far crowns, row after row of rounded crowns roll
## away into the mist with mist lying in the valleys between them, one giant tree
## rises above the rest, the nearest crowns fill the bottom, and right in front
## big leaves hang in from above; birds cross the sky. Layers far to near; see
## BackdropTheme.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The giant tree rising above the canopy: strip x, crown half width, crown top (screen row).
const GIANT_X: int = 150
const GIANT_HALF_WIDTH: float = 44.0
const GIANT_TOP_ROW: int = 40
const NEAR_CANOPY_ROW: int = 158


func _build_layers() -> void:
	DeepwoodStyle.add_shared_layers(self, SKYLINE_SECTION)

	var birds: BackdropMotes = BackdropMotes.new()
	birds.shape = BackdropMotes.Shape.BIRD
	birds.mote_count = 6
	birds.colors = [Color(0.1, 0.18, 0.16, 0.85)]
	birds.velocity = Vector2(8.0, -1.0)
	birds.sway_amplitude = 3.0
	birds.sway_speed = 0.25
	birds.size_range = Vector2i(1, 2)
	birds.scroll_factor = 0.15
	birds.vertical_range = Vector2(12.0, 90.0)
	birds.seed_value = 5301
	add_motes(birds)

	var spores: BackdropMotes = BackdropMotes.new()
	spores.shape = BackdropMotes.Shape.FIREFLY
	spores.mote_count = 10
	spores.colors = [Color(1.0, 0.95, 0.6, 0.8)]
	spores.velocity = Vector2(5.0, -2.0)
	spores.sway_amplitude = 4.0
	spores.sway_speed = 0.2
	spores.scroll_factor = 0.4
	spores.seed_value = 5302
	add_motes(spores)


## The giant: a huge crown standing above the canopy on a trunk you see only
## between the nearer crowns, a few bare branches poking out of its top.
static func paint_giant() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var haze: float = 0.12
	var top_row: int = BackdropPaint.row(GIANT_TOP_ROW)
	var trunk: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(GIANT_X - 30, top_row, 60, BackdropPaint.STRIP_HEIGHT - top_row))
	trunk.add_rect(Rect2i(GIANT_X - 8, top_row + 40, 16, BackdropPaint.STRIP_HEIGHT))
	trunk.add_line(Vector2(GIANT_X, top_row + 60.0), Vector2(GIANT_X - 24, top_row + 30.0), 5.0)
	trunk.add_line(Vector2(GIANT_X + 2, top_row + 50.0), Vector2(GIANT_X + 22, top_row + 18.0), 4.0)
	BackdropTerrain.roughen(trunk, 5311)
	BackdropTerrain.paint(image, trunk, BackdropTerrain.hazed(DeepwoodStyle.BARK, DeepwoodStyle.AIR, haze), 3.0, 8.0, 1, 5311)
	# The crown: a broad heap of clumps, highest in the middle, the lower ones in front.
	var crown: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(GIANT_X - 80, top_row - 4, 160, 110))
	var clumps: Array[Vector3] = []
	for tier: int in 4:
		var count: int = 2 + tier
		for clump: int in count:
			var spread: float = GIANT_HALF_WIDTH * (0.35 + tier * 0.2)
			var along: float = (clump + 0.5) / count * 2.0 - 1.0
			var center: Vector2 = Vector2(GIANT_X + along * spread + (BackdropPaint.random01(clump, tier, 5312) - 0.5) * 8.0,
				top_row + 10.0 + tier * 13.0 + absf(along) * 6.0)
			clumps.append(Vector3(center.x, center.y, 10.0 + BackdropPaint.random01(clump, tier + 9, 5312) * 4.0))
	for clump: Vector3 in clumps:
		crown.add_circle(Vector2(clump.x, clump.y), clump.z)
	BackdropTerrain.roughen(crown, 5312, 1)
	var leaves: Array[Color] = BackdropTerrain.hazed(DeepwoodStyle.LEAVES, DeepwoodStyle.AIR, haze)
	BackdropTerrain.paint(image, crown, leaves, 4.0, 14.0, 2, 5312)
	BackdropTerrain.paint_clump_tops(image, crown, clumps, leaves, 3.0)
	BackdropTerrain.paint_hanging(image, crown, DeepwoodStyle.far(DeepwoodStyle.MOSS, haze), 3, 12,
		DeepwoodStyle.far(DeepwoodStyle.MOSS_TIP, haze), 3, 5313)
	return image


## The nearest crowns, filling the bottom: big rounded clumps in full color.
static func paint_near_canopy() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var canopy: BackdropTerrain.Mask = BackdropTerrain.new_band(BackdropPaint.row(NEAR_CANOPY_ROW - 40), BackdropPaint.STRIP_HEIGHT + 6)
	var clumps: Array[Vector3] = []
	for clump: int in 26:
		var x: float = (clump + BackdropPaint.random01(clump, 1, 5321) * 0.6) * BackdropPaint.STRIP_WIDTH / 26.0
		var radius: float = 16.0 + BackdropPaint.random01(clump, 2, 5321) * 14.0
		var row: float = BackdropPaint.row(NEAR_CANOPY_ROW) + BackdropPaint.random01(clump, 3, 5321) * 16.0
		for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
			clumps.append(Vector3(x + wrap_offset, row + radius * 0.4, radius))
			canopy.add_circle(Vector2(x + wrap_offset, row + radius * 0.4), radius)
	# Smaller clumps on the big ones' shoulders.
	for clump: int in 40:
		var x: float = BackdropPaint.random01(clump, 4, 5321) * BackdropPaint.STRIP_WIDTH
		var row: float = BackdropPaint.row(NEAR_CANOPY_ROW + 12) + BackdropPaint.random01(clump, 5, 5321) * 20.0
		var radius: float = 8.0 + BackdropPaint.random01(clump, 6, 5321) * 6.0
		for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
			clumps.append(Vector3(x + wrap_offset, row, radius))
			canopy.add_circle(Vector2(x + wrap_offset, row), radius)
	canopy.add_rect(Rect2i(-BackdropTerrain.BAND_SPARE, BackdropPaint.row(NEAR_CANOPY_ROW + 20), BackdropPaint.STRIP_WIDTH + BackdropTerrain.BAND_SPARE * 2, BackdropPaint.STRIP_HEIGHT))
	BackdropTerrain.roughen(canopy, 5322, 1)
	BackdropTerrain.paint(image, canopy, DeepwoodStyle.LEAVES, 5.0, 14.0, 2, 5322)
	BackdropTerrain.paint_clump_tops(image, canopy, clumps, DeepwoodStyle.LEAVES, 3.0)
	return image


## Right in front: big leaves hanging in from the top corners, a fern frond
## poking up from below.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_leaf_clump(image, Vector2(40.0, BackdropPaint.row(-10)), 6, PI * 0.5, 1.9, Vector2(30.0, 50.0), -0.6,
		DeepwoodStyle.FRONT_BODY, DeepwoodStyle.FRONT_LIT, DeepwoodStyle.FRONT_RIB, 5331)
	BackdropPaint.paint_leaf_clump(image, Vector2(420.0, BackdropPaint.row(-10)), 4, PI * 0.5, 1.4, Vector2(26.0, 40.0), -0.5,
		DeepwoodStyle.FRONT_BODY, DeepwoodStyle.FRONT_LIT, DeepwoodStyle.FRONT_RIB, 5332)
	DeepwoodStyle.paint_big_fern(image, Vector2(560.0, BackdropPaint.row(200)), 60.0, 5333)
	return image
