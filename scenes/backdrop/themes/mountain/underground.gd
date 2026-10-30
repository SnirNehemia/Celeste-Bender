extends BackdropTheme
## MOUNTAIN, UNDERGROUND: an ice cavern inside the mountain. Dark blue depths, far
## cave walls with icicles, clusters of glowing ice crystals, and a near ceiling of
## dark rock with long icicles; water drips and the crystals glint. Layers far to
## near; see BackdropTheme. (Surface: surface.gd; high up: skyline.gd.)

const DEPTH_BANDS: Array[Color] = [Color(0.03, 0.05, 0.1), Color(0.05, 0.08, 0.14), Color(0.07, 0.12, 0.19),
	Color(0.05, 0.09, 0.15), Color(0.03, 0.05, 0.1)]

const FAR_BODY: Color = Color(0.08, 0.13, 0.2)
const FAR_RIM: Color = Color(0.15, 0.25, 0.33)

const CRYSTAL_BODY: Color = Color(0.3, 0.52, 0.64)
const CRYSTAL_LIT: Color = Color(0.58, 0.82, 0.9)
const CRYSTAL_GLOW: Color = Color(0.5, 0.85, 1.0, 0.05)
const MID_ROCK: Color = Color(0.05, 0.09, 0.15)
const MID_RIM: Color = Color(0.1, 0.18, 0.26)

const NEAR_BODY: Color = Color(0.02, 0.04, 0.08)
const NEAR_RIM: Color = Color(0.1, 0.19, 0.27)

## Where the crystal clusters stand (strip x) and whether on the floor (1) or
## hanging from the ceiling (-1).
const CLUSTERS: Array[Vector2] = [Vector2(40, 1), Vector2(130, -1), Vector2(210, 1), Vector2(300, -1), Vector2(380, 1),
	Vector2(460, -1), Vector2(540, 1), Vector2(610, -1)]


func _build_layers() -> void:
	add_painted_layer("Depths", Vector2(0.01, 0.0), _paint_depths)
	add_painted_layer("FarCave", Vector2(0.07, 0.03), _paint_far_cave)
	var crystals: BackdropLayer = add_painted_layer("Crystals", Vector2(0.2, 0.07), _paint_crystals)
	crystals.draw_extra = _draw_crystal_glow
	add_painted_layer("NearRock", Vector2(0.42, 0.13), _paint_near_rock)

	var drips: BackdropMotes = BackdropMotes.new()
	drips.mote_count = 6
	drips.colors = [Color(0.6, 0.85, 1.0, 0.5)]
	drips.velocity = Vector2(0.0, 70.0)
	drips.scroll_factor = 0.4
	drips.seed_value = 111
	add_motes(drips)

	var glints: BackdropMotes = BackdropMotes.new()
	glints.shape = BackdropMotes.Shape.FIREFLY
	glints.mote_count = 14
	glints.colors = [Color(0.7, 0.95, 1.0, 0.8)]
	glints.velocity = Vector2(1.0, 1.0)
	glints.sway_speed = 0.4
	glints.scroll_factor = 0.3
	glints.seed_value = 112
	add_motes(glints)


func _paint_depths() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, DEPTH_BANDS, 0, BackdropPaint.STRIP_HEIGHT)
	return image


func _paint_far_cave() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_cave(image, BackdropPaint.row(30), BackdropPaint.row(148), 22.0, FAR_BODY, FAR_RIM, 44, 26.0, 121)
	# Small far crystals glinting in the walls.
	for shard_index: int in 18:
		var x: float = BackdropPaint.random01(shard_index, 1, 122) * BackdropPaint.STRIP_WIDTH
		var y: float = BackdropPaint.row(30 + BackdropPaint.random01(shard_index, 2, 122) * 120.0)
		if image.get_pixel(posmod(roundi(x), BackdropPaint.STRIP_WIDTH), clampi(roundi(y), 0, BackdropPaint.STRIP_HEIGHT - 1)).a > 0.0:
			BackdropPaint.paint_shard(image, Vector2(x, y), -PI * 0.5 + (BackdropPaint.random01(shard_index, 3, 122) - 0.5), 6.0, 1.5, FAR_RIM, CRYSTAL_BODY)
	return image


func _paint_crystals() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var edges: Array[PackedFloat32Array] = BackdropPaint.paint_cave(image, BackdropPaint.row(4), BackdropPaint.row(168), 14.0, MID_ROCK, MID_RIM, 16, 14.0, 131)
	for cluster_index: int in CLUSTERS.size():
		var cluster: Vector2 = CLUSTERS[cluster_index]
		var x: int = int(cluster.x)
		var is_floor: bool = cluster.y > 0.0
		var root_row: float = edges[1][x] + 2.0 if is_floor else edges[0][x] - 2.0
		# A fan of shards: the middle one longest, leaning out to both sides.
		for shard_index: int in 5:
			var spread: float = (shard_index - 2) * 0.32
			var angle: float = (-PI * 0.5 if is_floor else PI * 0.5) + spread
			var length: float = (26.0 - absf(shard_index - 2) * 7.0) * (0.8 + BackdropPaint.random01(cluster_index, shard_index, 132) * 0.4)
			var foot: Vector2 = Vector2(x + (shard_index - 2) * 3, root_row)
			BackdropPaint.paint_shard(image, foot, angle, length, 3.0, CRYSTAL_BODY, CRYSTAL_LIT)
	return image


## A slow pulse of light around each crystal cluster.
func _draw_crystal_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for cluster_index: int in CLUSTERS.size():
		var cluster: Vector2 = CLUSTERS[cluster_index]
		var center_row: float = BackdropPaint.row(150) if cluster.y > 0.0 else BackdropPaint.row(22)
		var pulse: float = 0.6 + 0.4 * sin(time * 0.9 + cluster_index * 1.7)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + cluster.x, center_row), 30.0, CRYSTAL_GLOW, pulse)


func _paint_near_rock() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(160.0, 16.0), Vector2(40.0, 6.0)]
	var bottoms: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(-2), octaves, 141, false)
	BackdropPaint.fill_above(image, bottoms, NEAR_BODY)
	BackdropPaint.paint_bottom_rim(image, bottoms, NEAR_RIM)
	# Long icicles: rock-colored roots, pale tips (painted as two spikes).
	BackdropPaint.paint_spikes(image, bottoms, 1, 22, 34.0, NEAR_BODY, NEAR_RIM, 142)
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(190), octaves, 143, false)
	BackdropPaint.fill_below(image, floor_tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, floor_tops, NEAR_RIM)
	return image
