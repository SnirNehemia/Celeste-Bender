class_name HighlandsSkyline
extends BackdropTheme
## HIGHLANDS, SKYLINE: up among the cliffs that wall the green valley in, at
## midday. The deep blue top of the sky with drifting clouds, the far massifs'
## grassy summits stepping down in terraces (shared with the other two
## altitudes: HighlandsStyle); nearer, sheer pillars of pale rock rising out of
## the valley's haze, grass on their flat tops, a log cabin on some with smoke
## from its chimney and a lone tree on others; floating islands of earth hung
## with roots; a near cliff edge on the left with a bigger cabin and a crag on
## the right; a bank of mist over the valley along the bottom; and in front
## leafy boughs hanging in from above.
## The wind streaks by and birds wheel past. Everything solid is painted the way
## our ground is (BackdropTerrain). Every layer is shared with the surface
## (HighlandsStyle.add_shared_layers), so climbing between the two is one picture
## scrolling on. Layers far to near; see BackdropTheme.
## (Below: surface.gd, over the hills; lower still: underground.gd, the meadows.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The near pillars (layer Peaks): Vector4(strip x of the middle, half width at
## the top, screen row of the flat top, cabin width in px; 0: a lone tree instead).
const PEAKS: Array[Vector4] = [Vector4(110.0, 34.0, 70.0, 14.0), Vector4(268.0, 22.0, 104.0, 0.0),
	Vector4(420.0, 40.0, 58.0, 12.0), Vector4(566.0, 26.0, 92.0, 0.0)]
const PEAKS_HAZE: float = 0.3
## The pillars sink into the valley's haze from this screen row down to the
## bottom of the screen, by this much at most (HighlandsStyle.sink_into_haze).
const PEAKS_SINK_FROM_ROW: int = 80
const PEAKS_SINK: float = 0.55
## A cabin stands this share of the half width left of its pillar's middle.
const CABIN_OFFSET: float = 0.3
const PEAK_TREE_RADIUS: float = 6.0

## Well into the haze, so they don't read as platforms (see the surface's).
const ISLANDS_HAZE: float = 0.52
## The floating islands: Vector3i(left strip x, top screen row, width in tiles).
const ISLANDS: Array[Vector3i] = [Vector3i(186, 44, 5), Vector3i(330, 124, 4), Vector3i(500, 30, 6), Vector3i(10, 140, 3)]

## The near cliff edge (left) and crag (right): Vector4(strip x of the middle,
## half width at the top, screen row of the top, cabin width; 0: a tree).
const NEAR_CLIFFS: Array[Vector4] = [Vector4(60.0, 70.0, 128.0, 22.0), Vector4(470.0, 34.0, 146.0, 0.0)]
const NEAR_HAZE: float = 0.08
const NEAR_TREE_RADIUS: float = 11.0
const NEAR_SINK_FROM_ROW: int = 150
const NEAR_SINK: float = 0.3


func _build_layers() -> void:
	HighlandsStyle.add_shared_layers(self, SKYLINE_SECTION)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 16
	wind.colors = [Color(1.0, 1.0, 1.0, 0.22), Color(1.0, 1.0, 1.0, 0.36)]
	wind.velocity = Vector2(80.0, 2.0)
	wind.sway_amplitude = 2.0
	wind.sway_speed = 0.4
	wind.size_range = Vector2i(3, 8)
	wind.scroll_factor = 0.5
	wind.seed_value = 8301
	add_motes(wind)

	var birds: BackdropMotes = BackdropMotes.new()
	birds.shape = BackdropMotes.Shape.BIRD
	birds.mote_count = 6
	birds.colors = [Color(0.22, 0.3, 0.45, 0.85)]
	birds.velocity = Vector2(-9.0, 0.0)
	birds.sway_amplitude = 4.0
	birds.sway_speed = 0.25
	birds.size_range = Vector2i(1, 2)
	birds.scroll_factor = 0.2
	birds.vertical_range = Vector2(10.0, 110.0)
	birds.seed_value = 8302
	add_motes(birds)


## The near pillars (PEAKS): sheer rock with grass on top, cracked faces, a cabin
## or a lone tree on each, sinking into the valley's haze toward the bottom.
static func paint_peaks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	_paint_cliffs(image, PEAKS, PEAKS_HAZE, PEAK_TREE_RADIUS, 8311)
	HighlandsStyle.sink_into_haze(image, BackdropPaint.row(PEAKS_SINK_FROM_ROW), BackdropPaint.row(BackdropPaint.SCREEN_HEIGHT),
		PEAKS_SINK)
	return image


## Smoke from the pillars' cabins (a draw_extra of the Peaks layer).
static func draw_peak_smoke(layer: BackdropLayer, copy_x: float, time: float) -> void:
	HighlandsStyle.draw_smoke(layer, copy_x, time, _chimneys(PEAKS))


## Floating islands among the pillars (HighlandsStyle.paint_islands).
static func paint_islands() -> Image:
	return HighlandsStyle.paint_islands(ISLANDS, ISLANDS_HAZE, 8351)


## The near cliff edge with a bigger cabin, and a crag with a tree (NEAR_CLIFFS).
static func paint_near() -> Image:
	var image: Image = BackdropPaint.new_strip()
	_paint_cliffs(image, NEAR_CLIFFS, NEAR_HAZE, NEAR_TREE_RADIUS, 8361)
	HighlandsStyle.sink_into_haze(image, BackdropPaint.row(NEAR_SINK_FROM_ROW), BackdropPaint.row(BackdropPaint.SCREEN_HEIGHT),
		NEAR_SINK)
	return image


## Smoke from the near cliff's cabin (a draw_extra of the Near layer).
static func draw_near_smoke(layer: BackdropLayer, copy_x: float, time: float) -> void:
	HighlandsStyle.draw_smoke(layer, copy_x, time, _chimneys(NEAR_CLIFFS))


## Right in front: leafy boughs hanging in from the top (only from the top: the
## bottom is the mist over the valley, where anything rising would end in a cut).
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_leaf_clump(image, Vector2(24.0, BackdropPaint.row(-14)), 6, PI * 0.5, 1.8, Vector2(30.0, 50.0), -0.6,
		HighlandsStyle.FRONT_BODY, HighlandsStyle.FRONT_LIT, HighlandsStyle.FRONT_RIB, 8396)
	BackdropPaint.paint_leaf_clump(image, Vector2(470.0, BackdropPaint.row(-12)), 4, PI * 0.5, 1.5, Vector2(24.0, 38.0), -0.6,
		HighlandsStyle.FRONT_BODY, HighlandsStyle.FRONT_LIT, HighlandsStyle.FRONT_RIB, 8397)
	return image


## Paints `cliffs` (Vector4: middle x, half width, top screen row, cabin width or
## 0 for a tree; HighlandsStyle.add_pillar) on `image`: trees first (the rock
## covers their trunks' feet), the rock, cracks, then the cabins on top.
static func _paint_cliffs(image: Image, cliffs: Array[Vector4], haze: float, tree_radius: float, seed_value: int) -> void:
	var bottom_row: int = BackdropPaint.STRIP_HEIGHT + 24
	for cliff_index: int in cliffs.size():
		var cliff: Vector4 = cliffs[cliff_index]
		if cliff.w <= 0.0:
			HighlandsStyle.paint_tree(image, Vector2(cliff.x + cliff.y * 0.2, BackdropPaint.row(cliff.z)), tree_radius, haze,
				seed_value + cliff_index)
	var rock: Array[Color] = BackdropTerrain.hazed(HighlandsStyle.ROCK, HighlandsStyle.AIR, haze)
	for cliff_index: int in cliffs.size():
		var cliff: Vector4 = cliffs[cliff_index]
		var top_row: int = BackdropPaint.row(cliff.z)
		# The box: wider than the pillar widens and its ledges step out.
		var reach: int = ceili(cliff.y * 1.6) + 24
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(roundi(cliff.x) - reach, top_row - 2, reach * 2, bottom_row - top_row + 2))
		HighlandsStyle.add_pillar(mask, cliff.x, cliff.y, top_row, bottom_row, seed_value + 10 + cliff_index)
		BackdropTerrain.roughen(mask, seed_value + 10 + cliff_index)
		BackdropTerrain.paint(image, mask, rock, 4.0, 12.0, 2, seed_value + 10 + cliff_index)
		BackdropTerrain.paint_blades(image, mask, BackdropTerrain.hazed(HighlandsStyle.BLADES, HighlandsStyle.AIR, haze), 2, 3,
			seed_value + 20 + cliff_index)
		HighlandsStyle.paint_cracks(image, mask, HighlandsStyle.far(HighlandsStyle.CRACK_COLOR, haze), roundi(cliff.y / 3.0),
			seed_value + 30 + cliff_index)
		if cliff.w > 0.0:
			HighlandsStyle.paint_cabin(image, _cabin_foot(cliff), roundi(cliff.w), haze)


## Where a cliff's cabin stands (the middle of its floor, strip px).
static func _cabin_foot(cliff: Vector4) -> Vector2:
	return Vector2(roundf(cliff.x - cliff.y * CABIN_OFFSET), BackdropPaint.row(cliff.z))


## The chimney tops of the cabins on `cliffs` (strip px), for the smoke.
static func _chimneys(cliffs: Array[Vector4]) -> Array[Vector2]:
	var chimneys: Array[Vector2] = []
	for cliff: Vector4 in cliffs:
		if cliff.w > 0.0:
			chimneys.append(HighlandsStyle.cabin_chimney(_cabin_foot(cliff), roundi(cliff.w)))
	return chimneys
