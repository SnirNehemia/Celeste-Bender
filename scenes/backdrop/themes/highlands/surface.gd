class_name HighlandsSurface
extends BackdropTheme
## HIGHLANDS, SURFACE: over the hills of a green valley at midday, seen from
## platforms floating above the ground. A big blue sky with drifting clouds, the
## pale feet of the far cliffs, four hills in a few big soft waves, each nearer
## one greener, with a tree here and there (all shared with the other two
## altitudes: HighlandsStyle); faint floating islands of earth and grass hung
## with roots, a near swell of meadow with trees and a fence along the bottom,
## and right in front tall grass bent by the wind and broad leaves;
## the wind streaks by, leaves blow past, birds cross far off. Everything solid
## is painted the way our ground is (BackdropTerrain). Layers far to near; see
## BackdropTheme. (Below: underground.gd, the meadows; above: skyline.gd, the cliffs.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const ISLANDS_HAZE: float = 0.42
## The floating islands: Vector3i(left strip x, top screen row, width in tiles).
const ISLANDS: Array[Vector3i] = [Vector3i(30, 66, 6), Vector3i(170, 36, 4), Vector3i(290, 92, 8), Vector3i(450, 52, 5),
	Vector3i(560, 100, 4)]

## The near swell: its lowest point (screen row) and how high its waves rise.
const NEAR_BASE_ROW: int = 188
const NEAR_WAVE_HEIGHT: float = 32.0
const NEAR_WAVE_COUNT: int = 2
const NEAR_WAVE_PHASE: float = 1.2
const NEAR_HAZE: float = 0.08
## The near swell's trees: Vector2(strip x, crown radius).
const NEAR_TREES: Array[Vector2] = [Vector2(120.0, 13.0), Vector2(520.0, 10.0)]
## The fence along the near swell: from and to strip x, a post every so many px.
const FENCE_FROM_X: int = 300
const FENCE_TO_X: int = 420
const FENCE_POST_EVERY: int = 12


func _build_layers() -> void:
	HighlandsStyle.add_shared_layers(self, SURFACE_SECTION)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 10
	wind.colors = [Color(1.0, 1.0, 1.0, 0.2), Color(1.0, 1.0, 1.0, 0.32)]
	wind.velocity = Vector2(60.0, 3.0)
	wind.sway_amplitude = 2.0
	wind.sway_speed = 0.4
	wind.size_range = Vector2i(3, 7)
	wind.scroll_factor = 0.5
	wind.seed_value = 8201
	add_motes(wind)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 8
	leaves.colors = [Color(0.5, 0.78, 0.3, 0.85), Color(0.7, 0.86, 0.36, 0.8), Color(0.95, 0.85, 0.4, 0.75)]
	leaves.velocity = Vector2(26.0, 5.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.35
	leaves.scroll_factor = 0.65
	leaves.seed_value = 8202
	add_motes(leaves)

	var birds: BackdropMotes = BackdropMotes.new()
	birds.shape = BackdropMotes.Shape.BIRD
	birds.mote_count = 4
	birds.colors = [Color(0.3, 0.4, 0.55, 0.8)]
	birds.velocity = Vector2(-7.0, 0.0)
	birds.sway_amplitude = 3.0
	birds.sway_speed = 0.2
	birds.size_range = Vector2i(1, 2)
	birds.scroll_factor = 0.15
	birds.vertical_range = Vector2(10.0, 80.0)
	birds.seed_value = 8203
	add_motes(birds)


## Faint floating islands far back (HighlandsStyle.paint_islands): the kind of
## platform the level itself is made of.
static func paint_islands() -> Image:
	return HighlandsStyle.paint_islands(ISLANDS, ISLANDS_HAZE, 8211)


## The near swell of meadow along the bottom: two trees, a stretch of fence, tall
## grass and flowers on its top.
static func paint_near() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = HighlandsStyle.hill_tops(BackdropPaint.row(NEAR_BASE_ROW), NEAR_WAVE_HEIGHT, NEAR_WAVE_COUNT,
		NEAR_WAVE_PHASE, 8231)
	for tree_index: int in NEAR_TREES.size():
		var tree: Vector2 = NEAR_TREES[tree_index]
		HighlandsStyle.paint_tree(image, Vector2(tree.x, tops[int(tree.x)]), tree.y, NEAR_HAZE, 8232 + tree_index)
	HighlandsStyle.paint_fence(image, tops, FENCE_FROM_X, FENCE_TO_X, FENCE_POST_EVERY, 1.0, NEAR_HAZE)
	var turf: Array[Color] = BackdropTerrain.hazed(HighlandsStyle.TURF, HighlandsStyle.AIR, NEAR_HAZE)
	var swell: BackdropTerrain.Mask = HighlandsStyle.paint_swell(image, tops, BackdropPaint.STRIP_HEIGHT + 40, turf, 5.0, 14.0, 2, 8231)
	BackdropTerrain.paint_blades(image, swell, BackdropTerrain.hazed(HighlandsStyle.BLADES, HighlandsStyle.AIR, NEAR_HAZE), 2, 4, 8235)
	BackdropTerrain.paint_blades(image, swell, HighlandsStyle.FLOWERS, 12, 2, 8236)
	return image


## Right in front, all rising from the bottom (anything hanging in from the top
## would cross the seam to the skyline): tufts of tall grass bent by the wind and
## a clump of broad leaves.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var bottom: float = BackdropPaint.row(200)
	HighlandsStyle.paint_grass_tuft(image, Vector2(34.0, bottom), 84.0, 8241)
	HighlandsStyle.paint_grass_tuft(image, Vector2(388.0, bottom), 60.0, 8242)
	BackdropPaint.paint_leaf_clump(image, Vector2(586.0, bottom + 4.0), 5, -PI * 0.5, 1.5, Vector2(30.0, 46.0), 0.6,
		HighlandsStyle.FRONT_BODY, HighlandsStyle.FRONT_LIT, HighlandsStyle.FRONT_RIB, 8243)
	return image
