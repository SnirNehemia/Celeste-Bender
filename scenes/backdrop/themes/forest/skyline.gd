class_name ForestSkyline
extends BackdropTheme
## FOREST, SKYLINE: up in the treetops at sunset. The same sky and forest roof as
## the surface below (ForestStyle): here you look down on its crowns, with three
## giant trees standing above them, a sea of crowns far off, a big near branch
## with leaf clumps, and big leaves right in front; leaves blow past. Layers far to
## near; see BackdropTheme. (Surface: surface.gd; under the roots: underground.gd.)

const FAR_BODY: Color = Color(0.28, 0.32, 0.28)
const FAR_RIM: Color = Color(0.38, 0.4, 0.31)


const NEAR_BODY: Color = Color(0.05, 0.08, 0.05)
const NEAR_LIT: Color = Color(0.1, 0.15, 0.08)
const NEAR_BARK: Color = Color(0.08, 0.06, 0.04)


func _build_layers() -> void:
	ForestStyle.add_shared_layers(self, SKYLINE_SECTION)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 16
	leaves.colors = [Color(0.45, 0.55, 0.22, 0.75), Color(0.6, 0.48, 0.2, 0.7), Color(0.35, 0.45, 0.2, 0.7)]
	leaves.velocity = Vector2(28.0, 6.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.35
	leaves.scroll_factor = 0.65
	leaves.seed_value = 811
	add_motes(leaves)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 8
	wind.colors = [Color(1.0, 0.9, 0.7, 0.14)]
	wind.velocity = Vector2(60.0, 2.0)
	wind.size_range = Vector2i(2, 5)
	wind.scroll_factor = 0.5
	wind.seed_value = 812
	add_motes(wind)


static func paint_far_canopy() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(146), Vector2(4.0, 8.0), 7, 821)
	BackdropPaint.fill_below(image, tops, FAR_BODY)
	BackdropPaint.paint_rim(image, tops, FAR_RIM)
	return image


## A thick branch crossing the bottom of the view, with twigs and leaf clumps,
## and leaf clumps hanging in from the top corners of the strip.
static func paint_branch() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var branch_row: float = BackdropPaint.row(172)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var y: float = branch_row + sin(x * TAU / BackdropPaint.STRIP_WIDTH) * 8.0 + BackdropPaint.periodic_noise(x, 40.0, 841) * 4.0
		var thickness: int = 7 + roundi(BackdropPaint.periodic_noise(x, 80.0, 842) * 4.0)
		BackdropPaint.put_rect(image, Rect2i(x, roundi(y), 1, thickness), NEAR_BARK)
		BackdropPaint.put_pixel(image, x, roundi(y), NEAR_LIT)
	for clump_index: int in 9:
		var clump_x: float = (clump_index + BackdropPaint.random01(clump_index, 1, 843)) * BackdropPaint.STRIP_WIDTH / 9.0
		var is_top: bool = clump_index % 3 == 0
		var clump_y: float = float(BackdropPaint.row(4)) if is_top else branch_row - 4.0
		if not is_top:
			# A twig from the branch up to the clump.
			BackdropPaint.put_line(image, Vector2(clump_x - 8.0, branch_row + 2.0), Vector2(clump_x, clump_y), NEAR_BARK, 2)
		for leaf_index: int in 7:
			var offset: Vector2 = Vector2((BackdropPaint.random01(clump_index, leaf_index, 844) - 0.5) * 22.0,
				(BackdropPaint.random01(clump_index, leaf_index + 10, 844) - 0.5) * 12.0)
			var radius: float = 4.0 + BackdropPaint.random01(clump_index, leaf_index + 20, 844) * 3.0
			BackdropPaint.put_circle(image, Vector2(clump_x, clump_y) + offset + Vector2(-1, -1), radius, NEAR_LIT)
			BackdropPaint.put_circle(image, Vector2(clump_x, clump_y) + offset, radius - 1.0, NEAR_BODY)
	return image


## Right in front: big leaves reaching up from below the branch, one corner each.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_leaf_clump(image, Vector2(20.0, BackdropPaint.row(200)), 4, -PI * 0.4, 1.3, Vector2(34.0, 56.0), 0.6,
		ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT, ForestStyle.FRONT_RIB, 851)
	BackdropPaint.paint_leaf_clump(image, Vector2(360.0, BackdropPaint.row(-8)), 3, PI * 0.55, 1.1, Vector2(28.0, 44.0), -0.5,
		ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT, ForestStyle.FRONT_RIB, 852)
	return image
