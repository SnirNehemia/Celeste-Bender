class_name SanctumStyle
extends RefCounted
## SanctumStyle: what the three SANCTUM looks (themes/sanctum/*.gd) share, so they
## read as one bright, wild mountain land where the air nomads keep a few small
## temples: sheer cliffs and stone pillars rising out of a misty valley through a
## sea of cloud, grass and wind-bent pines on their tops, waterfalls down their
## faces, and here and there, perched on the highest tops, a little air temple in
## the Tibetan manner (SanctumBuildings: round towers under blue cone roofs,
## whitewashed walls, stupas, prayer flags strung from cliff to cliff). Nature
## first, the temples sparse. Its sunlit undercroft is underground.gd. The light
## counterpart of the dusky TEMPLE look. Not a node: static painters, colors and
## helpers.
##
## Painted in the style of our GROUND (BackdropTerrain): stone with a bright
## crust, grass on its tops and a hatched inside; far things are the same stone
## pulled toward the pale air (hazed).
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer). The surface
## and the skyline share ALL of them, the foreground too, with the same scroll in
## both, so the soft change between the two is one picture scrolling on: nothing
## appears or vanishes at the seam. Every cliff runs from the valley floor up to
## its top, so the same cliff is its foot in one view and its top in the other.
##   Sky        a clear late morning: deep blue high up, cream at the horizon; the
##              sun high in the skyline's sky
##   FarPeaks   a far range of stone pillars, pale with air, a tiny tower on the
##              tallest; low far hills along the surface's horizon
##   CloudSea   the sea of cloud between the two: the skyline looks down on its
##              tops, the surface looks up at its soft underside
##   Cliffs     nearer pillars with pines on top, a stupa and a small tower on two
##              of them, waterfalls down their faces
##   Mist       wisps of cloud drifting round the cliffs where the two views meet
##   Temple     the temple cliff: a great cliff on the left crowned by the air
##              temple (tower, walls, stupa, a blossom tree), a lower cliff with a
##              shrine further on, prayer flags strung between them across the
##              sky, and the valley's meadow along the surface's bottom
##   Shafts     sunbeams falling from the cloud sea's underside
##   Near       a few nearer rocky ledges with pines
##   Front      right in front: an old pine growing from the surface's corner up
##              into the skyline, its flat boughs reaching in; broad leaves at
##              the surface's foot

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "sanctum"

const SKY_BANDS: Array[Color] = [Color(0.33, 0.52, 0.76), Color(0.39, 0.58, 0.8), Color(0.46, 0.64, 0.83),
	Color(0.54, 0.7, 0.86), Color(0.62, 0.75, 0.87), Color(0.7, 0.8, 0.88), Color(0.77, 0.84, 0.88),
	Color(0.84, 0.87, 0.86), Color(0.9, 0.89, 0.82)]
## The air far things fade into (the sky near the horizon), and the bluer air of
## the far range, under the cloud sea's shadow.
const HAZE: Color = Color(0.84, 0.87, 0.88)
const MOUNT_AIR: Color = Color(0.76, 0.82, 0.9)
const SUN_CORE: Color = Color(1.0, 0.99, 0.93)
const SUN_HALO: Color = Color(0.93, 0.95, 0.94)
const SUN_HALO_OUTER: Color = Color(0.8, 0.88, 0.93)
const STREAK: Color = Color(0.72, 0.83, 0.92)
const SHAFT_COLOR: Color = Color(1.0, 0.97, 0.85, 0.1)

## Cliff stone in the ground's style: [crust, rim, edge, inside, hatch, deep]
## (BackdropTerrain). The rim is grass: tops are meadows. Warm gray stone with a
## touch of ochre, a mid tone (a light look: not the ground's near-black).
const ROCK: Array[Color] = [Color(0.93, 0.9, 0.82), Color(0.5, 0.72, 0.34), Color(0.6, 0.53, 0.47),
	Color(0.67, 0.61, 0.55), Color(0.72, 0.66, 0.59), Color(0.56, 0.52, 0.52)]
## Far stone: seen through a lot of air, its shade gone cool and blue (warm stone
## only pulled toward the air turns a dull gray).
const FAR_ROCK: Array[Color] = [Color(0.94, 0.94, 0.93), Color(0.62, 0.8, 0.52), Color(0.6, 0.64, 0.77),
	Color(0.69, 0.75, 0.88), Color(0.74, 0.8, 0.91), Color(0.63, 0.69, 0.85)]
## Things at least this far (haze) get a thinner crust and shorter grass.
const FAR_FROM_HAZE: float = 0.3
## Cliffs at least this far get no strata and cracks on their faces.
const FAR_FACE_HAZE: float = 0.45
## Bare marble (no grass on top): the undercroft.
const BARE_MARBLE: Array[Color] = [Color(0.95, 0.92, 0.85), Color(1.0, 0.98, 0.93), Color(0.7, 0.6, 0.52),
	Color(0.76, 0.68, 0.62), Color(0.81, 0.73, 0.66), Color(0.64, 0.57, 0.56)]
const GRASS_BLADES: Array[Color] = [Color(0.5, 0.72, 0.34), Color(0.62, 0.82, 0.42), Color(0.42, 0.62, 0.3)]
const BLOSSOM: Color = Color(0.96, 0.7, 0.78)
const BLOSSOM_LIT: Color = Color(1.0, 0.86, 0.88)
const BLOSSOM_SHADE: Color = Color(0.82, 0.52, 0.64)
const IVY: Color = Color(0.36, 0.56, 0.3)
const WATERFALL: Color = Color(0.96, 0.98, 1.0)

## Gold for the undercroft's trim (SanctumBuildings has the rest).
const GOLD: Color = SanctumBuildings.GOLD
const GOLD_LIT: Color = SanctumBuildings.GOLD_LIT
const CYPRESS: Color = Color(0.2, 0.36, 0.25)
const CYPRESS_LIT: Color = Color(0.33, 0.5, 0.3)
## The cliff pines: flat pads of needles on crooked trunks.
const PINE: Color = Color(0.2, 0.38, 0.28)
const PINE_LIT: Color = Color(0.36, 0.55, 0.36)
const PINE_SHADE: Color = Color(0.14, 0.27, 0.23)
const PINE_TRUNK: Color = Color(0.36, 0.28, 0.26)

const CLOUD_TOP: Color = Color(1.0, 1.0, 0.98)
const CLOUD_BODY: Color = Color(0.94, 0.95, 0.95)
const CLOUD_SHADE: Color = Color(0.84, 0.87, 0.91)
const CLOUD_UNDER: Color = Color(0.76, 0.81, 0.88)

## The foreground: things right in front, in cool shade (the light is behind them).
const FRONT_BODY: Color = Color(0.3, 0.31, 0.42)
const FRONT_LIT: Color = Color(0.44, 0.45, 0.56)
const FRONT_LEAF: Color = Color(0.2, 0.33, 0.3)
const FRONT_LEAF_LIT: Color = Color(0.3, 0.46, 0.36)
const FRONT_LEAF_RIB: Color = Color(0.26, 0.4, 0.33)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## How far each shared layer is (0 = as near as the ground, 1 = the air itself).
const FAR_PEAKS_HAZE: float = 0.55
const FAR_HILLS_HAZE: float = 0.62
const CLIFFS_HAZE: float = 0.3
const TEMPLE_HAZE: float = 0.12
const NEAR_HAZE: float = 0.06
## The temple cliff (Temple layer): its strip x, half width, and its top's
## skyline screen row; the shrine cliff the prayer flags run to, the same.
const TEMPLE_CLIFF_X: int = 80
const TEMPLE_CLIFF_HALF_WIDTH: int = 36
const TEMPLE_CLIFF_TOP_ROW: int = 112
const SHRINE_CLIFF_X: int = 410
const SHRINE_CLIFF_HALF_WIDTH: int = 26
const SHRINE_CLIFF_TOP_ROW: int = 146
## The valley's meadow along the surface's bottom (surface screen row).
const MEADOW_ROW: int = 158
## The front pine: where its trunk leaves the surface's bottom (strip x).
const FRONT_PINE_X: int = 590
## The cloud sea: its top in the skyline, its underside in the surface (screen rows).
const CLOUD_TOP_SCREEN_ROW: int = 134
const CLOUD_UNDER_SCREEN_ROW: int = 24


## `color` pulled `amount` toward the air: further away.
static func far(color: Color, amount: float) -> Color:
	return color.lerp(HAZE, amount)


## The sky (see the header): bands, high streaks of cirrus, the sun.
static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(140, BackdropTheme.SURFACE_SECTION))
	# High thin streaks of cirrus, in the skyline's sky.
	for streak_index: int in 9:
		var row: int = BackdropPaint.tall_row(10 + (streak_index * 37) % 90, BackdropTheme.SKYLINE_SECTION)
		var left: float = BackdropPaint.random01(streak_index, 1, 4101) * BackdropPaint.STRIP_WIDTH
		var length: int = 30 + roundi(BackdropPaint.random01(streak_index, 2, 4101) * 60.0)
		BackdropPaint.put_rect(tall, Rect2i(roundi(left), row, length, 1), STREAK)
		BackdropPaint.put_rect(tall, Rect2i(roundi(left) + 8, row + 1, length - 16, 1), SUN_HALO_OUTER)
	# The sun, high: a soft halo in two rings, then the core.
	var sun: Vector2 = Vector2(150.0, BackdropPaint.tall_row(34, BackdropTheme.SKYLINE_SECTION))
	BackdropPaint.put_circle(tall, sun, 25.0, SUN_HALO_OUTER)
	BackdropPaint.put_circle(tall, sun, 18.0, SUN_HALO)
	BackdropPaint.put_circle(tall, sun, 12.0, SUN_CORE)


## A waterfall from `top` straight down `height` px: a white ribbon with a pale
## blue shaded side and streaks, a lip where it pours over, a puff of foam where it
## lands.
static func _paint_waterfall(tall: Image, top: Vector2, height: float, haze: float) -> void:
	var water: Color = WATERFALL.lerp(MOUNT_AIR, haze * 0.25)
	var shade: Color = SKY_BANDS[5].lerp(MOUNT_AIR, haze * 0.25)
	var x: int = roundi(top.x)
	var y: int = roundi(top.y)
	BackdropPaint.put_rect(tall, Rect2i(x - 1, y - 1, 6, 2), water)
	for drop: int in roundi(height):
		BackdropPaint.put_rect(tall, Rect2i(x, y + drop, 4, 1), water)
		BackdropPaint.put_pixel(tall, x + 3, y + drop, shade)
		# Streaks running down it, broken.
		if (drop + x * 3) % 7 < 3:
			BackdropPaint.put_pixel(tall, x + 1, y + drop, shade)
	var foot: Vector2 = Vector2(x + 2, y + height)
	BackdropPaint.put_circle(tall, foot + Vector2(-2.0, -1.0), 2.5, water)
	BackdropPaint.put_circle(tall, foot + Vector2(2.0, -1.0), 2.5, water)
	BackdropPaint.put_rect(tall, Rect2i(x - 3, roundi(foot.y), 10, 1), shade)


## The sea of cloud (see the header). Puffy tops, a body that shades toward the
## bottom, and an underside that thins out in a dither instead of ending in a line.
static func paint_cloud_sea(tall: Image) -> void:
	var top_row: float = BackdropPaint.tall_row(CLOUD_TOP_SCREEN_ROW, BackdropTheme.SKYLINE_SECTION)
	var under_row: float = BackdropPaint.tall_row(CLOUD_UNDER_SCREEN_ROW, BackdropTheme.SURFACE_SECTION)
	var tops: PackedFloat32Array = BackdropPaint.bumps(top_row, Vector2(7.0, 15.0), 13, 4121)
	var undersides: PackedFloat32Array = BackdropPaint.bumps(under_row, Vector2(6.0, 14.0), 15, 4122)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		# bumps() rises upward; mirrored around under_row it hangs downward.
		var bottom: int = roundi(2.0 * under_row - undersides[x])
		for y: int in range(top, bottom + 1):
			var from_top: int = y - top
			var to_bottom: int = bottom - y
			var color: Color = CLOUD_BODY
			if from_top <= 1:
				color = CLOUD_TOP
			elif from_top <= 3 and BackdropPaint.checker(x, y):
				color = CLOUD_TOP
			elif to_bottom < 18:
				color = CLOUD_UNDER if to_bottom < 8 else CLOUD_SHADE
			# The underside thins out: the last rows only on a checker, then sparser.
			if to_bottom < 3 and not BackdropPaint.checker(x, y):
				continue
			if to_bottom < 1 and x % 4 != y % 4:
				continue
			BackdropPaint.put_pixel(tall, x, y, color)
	# Lower layers of the sea, shaded, between the bumps (depth in the cloud tops).
	for puff_index: int in 14:
		var center: Vector2 = Vector2((puff_index + BackdropPaint.random01(puff_index, 1, 4123)) * BackdropPaint.STRIP_WIDTH / 14.0,
			top_row + 10.0 + BackdropPaint.random01(puff_index, 2, 4123) * 18.0)
		BackdropPaint.paint_cloud(tall, center, 14.0 + BackdropPaint.random01(puff_index, 3, 4123) * 14.0, CLOUD_BODY, CLOUD_TOP, CLOUD_SHADE, puff_index + 4124)
	# Loose puffs above the sea (skyline) and wisps below it (surface).
	for puff_index: int in 5:
		var above: Vector2 = Vector2((puff_index + 0.3) * BackdropPaint.STRIP_WIDTH / 5.0,
			top_row - 22.0 - (puff_index % 3) * 16.0)
		BackdropPaint.paint_cloud(tall, above, 12.0 + (puff_index % 2) * 8.0, CLOUD_BODY, CLOUD_TOP, CLOUD_SHADE, puff_index + 4130)
		var below: Vector2 = Vector2((puff_index + 0.75) * BackdropPaint.STRIP_WIDTH / 5.0,
			under_row + 26.0 + (puff_index % 2) * 18.0)
		BackdropPaint.paint_cloud(tall, below, 10.0 + (puff_index % 3) * 5.0, CLOUD_SHADE, CLOUD_BODY, CLOUD_UNDER, puff_index + 4140)


## Faint floating platforms in the ground's style, scattered over a picture: `count`
## chunks (BackdropTerrain.add_chunk) with tops between screen rows `row_range` of
## `section` (a BackdropTheme section of a tall picture), `tile` px tiles, `haze`
## far, each topped by grass and hung with ivy. Returns where each platform's top
## is (x = middle, y = top row, z = half width), for props.
static func paint_floating_platforms(image: Image, section: int, count: int, row_range: Vector2, tile: int, haze: float,
		seed_value: int) -> Array[Vector3]:
	var tops: Array[Vector3] = []
	var palette: Array[Color] = rock_palette(haze)
	for chunk_index: int in count:
		var width_tiles: int = 3 + roundi(BackdropPaint.random01(chunk_index, 1, seed_value) * 5.0)
		var depth_tiles: int = 2 + roundi(BackdropPaint.random01(chunk_index, 2, seed_value) * 2.0)
		var left: int = roundi((chunk_index + BackdropPaint.random01(chunk_index, 3, seed_value) * 0.5) * BackdropPaint.STRIP_WIDTH / count)
		var top_row: int = BackdropPaint.tall_row(lerpf(row_range.x, row_range.y, BackdropPaint.random01(chunk_index, 4, seed_value)), section)
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(left - 2, top_row - tile - 2, width_tiles * tile + 4, (depth_tiles + 2) * tile + 4))
		BackdropTerrain.add_chunk(mask, left, top_row, width_tiles, depth_tiles, tile, seed_value + chunk_index)
		BackdropTerrain.roughen(mask, seed_value + chunk_index)
		BackdropTerrain.paint(image, mask, palette, maxf(2.0, tile * 0.45), tile * 1.6, 2 if tile >= 6 else 1, seed_value + chunk_index)
		BackdropTerrain.paint_blades(image, mask, BackdropTerrain.hazed(GRASS_BLADES, HAZE, haze), 4, 2 if tile < 6 else 3, seed_value + chunk_index)
		BackdropTerrain.paint_hanging(image, mask, far(IVY, haze), 6, tile * 2, far(BLOSSOM, haze), 4, seed_value + chunk_index)
		tops.append(Vector3(left + width_tiles * tile / 2, top_row, width_tiles * tile / 2))
	return tops

## The stone palette for something `haze` far: ROCK turning into FAR_ROCK as it
## goes back (all FAR_ROCK from 0.55 on), pulled toward the mountain air.
static func rock_palette(haze: float) -> Array[Color]:
	var to_far: float = clampf((haze - 0.15) / 0.4, 0.0, 1.0)
	var palette: Array[Color] = []
	for index: int in ROCK.size():
		palette.append(ROCK[index].lerp(FAR_ROCK[index], to_far).lerp(MOUNT_AIR, haze * 0.5))
	return palette


## A cliff, a pillar of stone from `bottom_row` up to a flat top at `top_row`
## (tall picture rows), about `half_width` px each side of `center_x`: its sides
## step in and out every few rows (layered rock), it widens a little toward its
## foot, and every step that juts out is a grassy ledge (BackdropTerrain). Ivy
## hangs under the overhangs. `haze` 0-1: how far away. Returns its top as
## (row, left x, right x).
static func paint_cliff(image: Image, center_x: int, top_row: int, bottom_row: int, half_width: int, haze: float,
		seed_value: int) -> Vector3:
	const LAYER_ROWS: int = 7
	var height: int = bottom_row - top_row
	var reach: int = roundi(half_width * 1.7) + 6
	var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(center_x - reach, top_row - 2, reach * 2, height + 4))
	var row: int = top_row
	# Where a side juts out past the layer above: a ledge (x, row), for plants.
	var ledges: Array[Vector2] = []
	var previous_left: float = half_width
	var previous_right: float = half_width
	while row < bottom_row:
		var along: float = float(row - top_row) / height
		# Wider toward the foot, and each layer of rock sticks out by its own amount
		# on each side (two noises: the sides aren't mirrored).
		var widen: float = 1.0 + 0.3 * along
		var left_half: float = half_width * widen * (0.78 + 0.44 * BackdropPaint.periodic_noise(row, 26.0, seed_value))
		var right_half: float = half_width * widen * (0.78 + 0.44 * BackdropPaint.periodic_noise(row, 26.0, seed_value + 1))
		if row == top_row:
			left_half = half_width
			right_half = half_width
		var layer_rows: int = mini(LAYER_ROWS, bottom_row - row)
		mask.add_rect(Rect2i(center_x - roundi(left_half), row, roundi(left_half + right_half), layer_rows))
		if row > top_row and left_half > previous_left + 3.0:
			ledges.append(Vector2(center_x - left_half + 2.0, row))
		if row > top_row and right_half > previous_right + 3.0:
			ledges.append(Vector2(center_x + right_half - 3.0, row))
		previous_left = left_half
		previous_right = right_half
		row += layer_rows
	BackdropTerrain.roughen(mask, seed_value)
	var crust: float = 4.0 if haze < FAR_FROM_HAZE else 2.5
	BackdropTerrain.paint(image, mask, rock_palette(haze), crust, 14.0, 2 if haze < FAR_FROM_HAZE else 1, seed_value)
	BackdropTerrain.paint_blades(image, mask, BackdropTerrain.hazed(GRASS_BLADES, HAZE, haze), 3, 3 if haze < FAR_FROM_HAZE else 2, seed_value)
	# Far off, the face's detail is lost in the air: not worth painting.
	if haze < FAR_FACE_HAZE:
		_paint_cliff_face(image, mask, top_row, rock_palette(haze), seed_value)
	BackdropTerrain.paint_hanging(image, mask, far(IVY, haze), 5, 12, far(BLOSSOM, haze), 0, seed_value)
	# On about half the ledges: a pine leaning out, or a round bush.
	var scale: float = half_width / 24.0
	var colors: Array[Color] = pine_colors(haze + 0.04)
	for ledge_index: int in ledges.size():
		var ledge: Vector2 = ledges[ledge_index]
		var pick: float = BackdropPaint.random01(ledge_index, 1, seed_value)
		var outward: float = -1.0 if ledge.x < center_x else 1.0
		if pick < 0.3:
			paint_pine(image, ledge, (9.0 + pick * 20.0) * scale, outward * 4.0 * scale, 2, colors, seed_value + ledge_index)
		elif pick < 0.55:
			var radius: float = 2.0 + 2.0 * scale
			BackdropPaint.put_circle(image, ledge + Vector2(0.0, -radius + 1.0), radius, colors[0])
			BackdropPaint.put_circle(image, ledge + Vector2(-1.0, -radius), radius - 1.5, colors[1])
	return Vector3(top_row, center_x - half_width, center_x + half_width)


## The face of a cliff (paint_cliff's `mask`, rows from `top_row`), over its plain
## inside: layers of rock (a lit line with a shadow under it every few rows, here
## and there), cracks running down it, and the sunlit left side lighter. Stays
## FACE_INSET px in from the edges, off the crust. Works on each row's solid span
## (a cliff has one per row), worked out once, not pixel by pixel.
static func _paint_cliff_face(image: Image, mask: BackdropTerrain.Mask, top_row: int, palette: Array[Color], seed_value: int) -> void:
	const FACE_INSET: int = 5
	const STRATA_ROWS: int = 15
	const SUNNY_WIDTH: int = 9
	const CRACK_EVERY: int = 900  # one crack per this many px of face
	var lit: Color = palette[BackdropTerrain.INSIDE].lerp(palette[BackdropTerrain.CRUST], 0.4)
	var shade: Color = palette[BackdropTerrain.DEEP].darkened(0.1)
	var sunny: Color = palette[BackdropTerrain.DEEP].lerp(palette[BackdropTerrain.INSIDE], 0.6)
	var width: int = mask.size.x
	var height: int = mask.size.y
	# Each row's span: first and last solid column (local), -1 for an empty row.
	var lefts: PackedInt32Array = PackedInt32Array()
	var rights: PackedInt32Array = PackedInt32Array()
	lefts.resize(height)
	rights.resize(height)
	for local_y: int in height:
		lefts[local_y] = -1
		rights[local_y] = -1
		for local_x: int in width:
			if mask.cells[local_y * width + local_x] != 0:
				if lefts[local_y] < 0:
					lefts[local_y] = local_x
				rights[local_y] = local_x
	# The face's span per row: in from this row's span and the rows FACE_INSET
	# above and below (so it stays off the tops of ledges and undersides too).
	var face_lefts: PackedInt32Array = PackedInt32Array()
	var face_rights: PackedInt32Array = PackedInt32Array()
	face_lefts.resize(height)
	face_rights.resize(height)
	var face_area: int = 0
	for local_y: int in height:
		face_lefts[local_y] = 0
		face_rights[local_y] = -1
		if local_y < FACE_INSET or local_y >= height - FACE_INSET:
			continue
		var near_rows: Array[int] = [local_y - FACE_INSET, local_y, local_y + FACE_INSET]
		var left: int = -1
		var right: int = width
		var is_open: bool = false
		for near_row: int in near_rows:
			if lefts[near_row] < 0:
				is_open = true
				break
			left = maxi(left, lefts[near_row])
			right = mini(right, rights[near_row])
		if is_open:
			continue
		face_lefts[local_y] = left + FACE_INSET
		face_rights[local_y] = right - FACE_INSET
		face_area += maxi(0, face_rights[local_y] - face_lefts[local_y] + 1)
	# Strata: each column's lines are shifted by its own amount (a slow noise), so
	# they tilt and wave instead of running dead level.
	var strata_shifts: PackedInt32Array = PackedInt32Array()
	strata_shifts.resize(width)
	for local_x: int in width:
		strata_shifts[local_x] = roundi(BackdropTerrain.noise_2d(mask.origin.x + local_x, 0.0, 30.0, seed_value) * 4.0)
	for local_y: int in height:
		var left: int = face_lefts[local_y]
		var right: int = face_rights[local_y]
		if right < left:
			continue
		var y: int = mask.origin.y + local_y
		# The sunlit side: solid just in from the left edge, then a checker.
		for local_x: int in range(left, mini(right, left + SUNNY_WIDTH) + 1):
			if local_x - left < SUNNY_WIDTH / 3 or BackdropPaint.checker(local_x, y):
				BackdropPaint.put_pixel(image, mask.origin.x + local_x, y, sunny)
		for local_x: int in range(left, right + 1):
			var stratum: int = posmod(y - top_row + strata_shifts[local_x], STRATA_ROWS)
			if stratum > 1:
				continue
			var x: int = mask.origin.x + local_x
			# Broken lines: only where a noise says this stretch of the layer shows.
			if BackdropTerrain.noise_2d(x, y - stratum, 18.0, seed_value + 2) > 0.58:
				BackdropPaint.put_pixel(image, x, y, lit if stratum == 0 else shade)
	# Cracks: short wandering lines running down the face.
	for crack_index: int in face_area / CRACK_EVERY:
		var local_y: int = roundi(BackdropPaint.random01(crack_index, 1, seed_value) * (height - 1))
		if face_rights[local_y] < face_lefts[local_y]:
			continue
		var local_x: int = face_lefts[local_y] + roundi(BackdropPaint.random01(crack_index, 2, seed_value) * (face_rights[local_y] - face_lefts[local_y]))
		var length: int = 10 + roundi(BackdropPaint.random01(crack_index, 3, seed_value) * 30.0)
		for step: int in length:
			if local_y + step >= height:
				break
			var wander: float = BackdropPaint.random01(crack_index * 64 + step, 4, seed_value)
			local_x += -1 if wander < 0.15 else (1 if wander > 0.85 else 0)
			if local_x >= face_lefts[local_y + step] and local_x <= face_rights[local_y + step]:
				BackdropPaint.put_pixel(image, mask.origin.x + local_x, mask.origin.y + local_y + step, shade)


## A pine as they grow on cliffs, bent by the wind: a crooked trunk from `foot`
## leaning `lean` px sideways over its `height`, and `pads` flat, wide pads of
## needles stacked up it (the widest low, a small one on top), each lit on top and
## shaded underneath, on a short branch from the trunk. In `colors`: [needles,
## lit, shade, trunk].
static func paint_pine(image: Image, foot: Vector2, height: float, lean: float, pads: int, colors: Array[Color],
		seed_value: int) -> void:
	var top: Vector2 = foot + Vector2(lean, -height)
	var control: Vector2 = foot + Vector2(-lean * 0.4, -height * 0.5)
	var thickness: int = maxi(1, roundi(height / 14.0))
	var steps: int = ceili(height)
	for step: int in steps + 1:
		var point: Vector2 = BackdropPaint.curve_point(foot, control, top, float(step) / steps)
		var width: int = maxi(1, roundi(thickness * (1.0 - 0.6 * float(step) / steps)))
		BackdropPaint.put_rect(image, Rect2i(roundi(point.x) - width / 2, roundi(point.y), width, 1), colors[3])
	for pad_index: int in pads:
		var along: float = 0.45 + 0.55 * float(pad_index) / maxf(1.0, pads - 1)
		var stem: Vector2 = BackdropPaint.curve_point(foot, control, top, along)
		# Pads reach out to alternate sides, further low down.
		var side: float = -1.0 if (pad_index + seed_value) % 2 == 0 else 1.0
		var half: float = height * (0.42 - 0.24 * along) * (0.8 + 0.4 * BackdropPaint.random01(pad_index, 1, seed_value))
		var pad: Vector2 = stem + Vector2(side * half * 0.55, -2.0)
		BackdropPaint.put_line(image, stem, pad, colors[3])
		var pad_rows: int = maxi(2, roundi(height / 16.0))
		for lift: int in pad_rows + 1:
			# A flat ellipse: widest in the middle row, rounded ends.
			var row_half: float = half * sqrt(1.0 - pow(float(lift) / (pad_rows + 1), 2.0))
			var color: Color = colors[0]
			if lift == pad_rows:
				color = colors[1]
			elif lift == 0:
				color = colors[2]
			BackdropPaint.put_rect(image, Rect2i(roundi(pad.x - row_half), roundi(pad.y) - lift, roundi(row_half * 2.0) + 1, 1), color)
		# A ragged underside: tufts of needles hanging a px or two.
		for tuft: int in roundi(half / 2.0):
			var tuft_x: int = roundi(pad.x - half * 0.85 + tuft * 4 + BackdropPaint.random01(tuft, pad_index, seed_value) * 2.0)
			BackdropPaint.put_rect(image, Rect2i(tuft_x, roundi(pad.y) + 1, 2, 1), colors[2])


## The pines' colors for something `haze` far ([needles, lit, shade, trunk]).
static func pine_colors(haze: float) -> Array[Color]:
	return [far(PINE, haze), far(PINE_LIT, haze), far(PINE_SHADE, haze), far(PINE_TRUNK, haze)] as Array[Color]


## The FarPeaks layer (see the header): stone pillars far off, some topping out
## above the cloud sea, some under it, their feet in the far hills.
static func paint_far_peaks(tall: Image) -> void:
	var foot_row: int = _surface_row(150)
	for pillar_index: int in 10:
		var center_x: int = roundi((pillar_index + 0.2 + BackdropPaint.random01(pillar_index, 1, 4111) * 0.6) * BackdropPaint.STRIP_WIDTH / 10.0)
		var half_width: int = 8 + roundi(BackdropPaint.random01(pillar_index, 2, 4111) * 9.0)
		# Every other one is tall (its top above the cloud sea, in the skyline).
		var top_row: int = _skyline_row(60.0 + BackdropPaint.random01(pillar_index, 3, 4111) * 60.0) if pillar_index % 2 == 0 \
			else _surface_row(46.0 + BackdropPaint.random01(pillar_index, 3, 4111) * 50.0)
		var top: Vector3 = paint_cliff(tall, center_x, top_row, foot_row, half_width, FAR_PEAKS_HAZE, 4112 + pillar_index)
		var colors: Array[Color] = pine_colors(FAR_PEAKS_HAZE + 0.1)
		paint_pine(tall, Vector2(top.y + 3.0, top.x), 7.0, 2.0, 2, colors, 4120 + pillar_index)
		if pillar_index == 4:
			SanctumBuildings.paint_air_tower(tall, center_x + 2, top_row, top_row - 9, 3, 9, FAR_PEAKS_HAZE + 0.1)
		elif pillar_index == 7:
			SanctumBuildings.paint_stupa(tall, center_x, top_row, 6, FAR_PEAKS_HAZE + 0.1)
	# Low far hills along the surface's horizon, over the pillars' feet.
	var hills: BackdropTerrain.Mask = BackdropTerrain.new_band(_surface_row(110), _surface_row(BackdropPaint.SCREEN_HEIGHT + BackdropPaint.SCREEN_TOP_ROW))
	hills.add_below(BackdropPaint.ridge(_surface_row(140), [Vector2(160.0, 18.0), Vector2(40.0, 6.0)] as Array[Vector2], 4211, false))
	BackdropTerrain.roughen(hills, 4211)
	BackdropTerrain.paint(tall, hills, rock_palette(FAR_HILLS_HAZE), 2.0, 12.0, 1, 4211)
	BackdropTerrain.paint_blades(tall, hills, BackdropTerrain.hazed(GRASS_BLADES, HAZE, FAR_HILLS_HAZE), 4, 1, 4211)


## The Cliffs layer (see the header): four pillars, two topping out above the
## cloud sea (a little tower, a meadow) and two under it, each with its pines.
static func paint_cliffs(tall: Image) -> void:
	var foot_row: int = _surface_row(BackdropPaint.SCREEN_HEIGHT + BackdropPaint.SCREEN_TOP_ROW)
	var colors: Array[Color] = pine_colors(CLIFFS_HAZE + 0.05)
	# 1: tall, a little tower and a stupa on top, a waterfall off its side.
	var tower_top: Vector3 = paint_cliff(tall, 250, _skyline_row(96), foot_row, 24, CLIFFS_HAZE, 4131)
	SanctumBuildings.paint_air_tower(tall, 246, roundi(tower_top.x), roundi(tower_top.x) - 16, 5, 14, CLIFFS_HAZE)
	SanctumBuildings.paint_stupa(tall, 262, roundi(tower_top.x), 8, CLIFFS_HAZE)
	paint_pine(tall, Vector2(tower_top.y + 4.0, tower_top.x), 14.0, -4.0, 3, colors, 4132)
	_paint_waterfall(tall, Vector2(tower_top.z - 6.0, tower_top.x + 1.0), _surface_row(150) - tower_top.x, CLIFFS_HAZE)
	# 2: low, under the cloud sea, pines.
	var low_top: Vector3 = paint_cliff(tall, 360, _surface_row(70), foot_row, 18, CLIFFS_HAZE, 4133)
	paint_pine(tall, Vector2(low_top.y + 6.0, low_top.x), 16.0, 5.0, 3, colors, 4134)
	paint_pine(tall, Vector2(low_top.z - 4.0, low_top.x), 11.0, 3.0, 2, colors, 4135)
	# 3: wide and tall, a meadow with pines and a blossom tree.
	var wide_top: Vector3 = paint_cliff(tall, 540, _skyline_row(124), foot_row, 32, CLIFFS_HAZE, 4136)
	paint_pine(tall, Vector2(wide_top.y + 8.0, wide_top.x), 18.0, -5.0, 3, colors, 4137)
	SanctumBuildings.paint_blossom_tree(tall, roundi(wide_top.z) - 14, roundi(wide_top.x), 12.0, CLIFFS_HAZE, 4138)
	_paint_waterfall(tall, Vector2(wide_top.y + 2.0, wide_top.x + 1.0), _surface_row(150) - wide_top.x, CLIFFS_HAZE)
	# 4: a slim needle under the cloud sea.
	var needle_top: Vector3 = paint_cliff(tall, 640 - 4, _surface_row(96), foot_row, 11, CLIFFS_HAZE, 4139)
	paint_pine(tall, Vector2(needle_top.y + 5.0, needle_top.x), 12.0, 4.0, 2, colors, 4140)


## The Mist layer (see the header): wisps of cloud, see-through (dithered), round
## the cliffs about where the two views meet, and a few low in the valley.
static func paint_mist(tall: Image) -> void:
	for wisp_index: int in 9:
		var center: Vector2 = Vector2((wisp_index + BackdropPaint.random01(wisp_index, 1, 4151)) * BackdropPaint.STRIP_WIDTH / 9.0,
			_skyline_row(150.0 + BackdropPaint.random01(wisp_index, 2, 4151) * 70.0))
		if wisp_index % 3 == 2:
			center.y = _surface_row(118.0 + BackdropPaint.random01(wisp_index, 2, 4151) * 30.0)
		var half_width: float = 22.0 + BackdropPaint.random01(wisp_index, 3, 4151) * 26.0
		var half_height: float = 3.0 + BackdropPaint.random01(wisp_index, 4, 4151) * 3.0
		for dy: int in range(-ceili(half_height), ceili(half_height) + 1):
			# A long, thin lens: widest in the middle row.
			var row_half: float = half_width * sqrt(maxf(0.0, 1.0 - pow(dy / (half_height + 0.5), 2.0)))
			for dx: int in range(-ceili(row_half), ceili(row_half) + 1):
				var x: int = roundi(center.x) + dx
				var y: int = roundi(center.y) + dy
				# Solid in the middle, a checker toward the ends, then every 4th px.
				var edge: float = absf(dx) / maxf(1.0, row_half)
				var keep: bool = edge < 0.45 or (edge < 0.8 and BackdropPaint.checker(x, y)) or x % 4 == y % 4
				if keep:
					BackdropPaint.put_pixel(tall, x, y, CLOUD_TOP if dy < 0 else CLOUD_BODY)


## The Temple layer (see the header).
static func paint_temple(tall: Image) -> void:
	var haze: float = TEMPLE_HAZE
	var foot_row: int = _surface_row(BackdropPaint.SCREEN_HEIGHT + BackdropPaint.SCREEN_TOP_ROW)
	var colors: Array[Color] = pine_colors(haze)
	# The valley's meadow, rolling, in front of the cliffs' feet.
	var meadow: BackdropTerrain.Mask = BackdropTerrain.new_band(_surface_row(MEADOW_ROW - 20), foot_row)
	meadow.add_below(BackdropPaint.ridge(_surface_row(MEADOW_ROW), [Vector2(213.0, 10.0), Vector2(53.0, 4.0)] as Array[Vector2], 4161, false))
	BackdropTerrain.roughen(meadow, 4161)
	BackdropTerrain.paint(tall, meadow, rock_palette(haze), 4.0, 12.0, 2, 4161)
	BackdropTerrain.paint_blades(tall, meadow, BackdropTerrain.hazed(GRASS_BLADES, HAZE, haze), 2, 4, 4161)
	SanctumBuildings.paint_stupa(tall, 250, _surface_row(MEADOW_ROW) + 2, 12, haze)
	paint_pine(tall, Vector2(300.0, _surface_row(MEADOW_ROW) + 3), 26.0, 6.0, 3, colors, 4162)
	paint_pine(tall, Vector2(520.0, _surface_row(MEADOW_ROW) + 2), 20.0, -5.0, 3, colors, 4163)
	# The shrine cliff: a stupa, two junipers, a pine leaning out over the edge.
	var shrine: Vector3 = paint_cliff(tall, SHRINE_CLIFF_X, _skyline_row(SHRINE_CLIFF_TOP_ROW), foot_row, SHRINE_CLIFF_HALF_WIDTH, haze, 4164)
	var shrine_row: int = roundi(shrine.x)
	SanctumBuildings.paint_stupa(tall, SHRINE_CLIFF_X - 4, shrine_row, 16, haze)
	SanctumBuildings.paint_cypress(tall, SHRINE_CLIFF_X + 14, shrine_row, 14, haze)
	SanctumBuildings.paint_cypress(tall, SHRINE_CLIFF_X + 19, shrine_row, 10, haze)
	paint_pine(tall, Vector2(shrine.y + 2.0, shrine_row), 20.0, -12.0, 3, colors, 4165)
	# The temple cliff and the air temple on it: whitewashed walls, the tall tower
	# in the middle, a smaller one, a stupa and a blossom tree at the edge.
	var temple: Vector3 = paint_cliff(tall, TEMPLE_CLIFF_X, _skyline_row(TEMPLE_CLIFF_TOP_ROW), foot_row, TEMPLE_CLIFF_HALF_WIDTH, haze, 4166)
	var temple_row: int = roundi(temple.x)
	SanctumBuildings.paint_dzong(tall, TEMPLE_CLIFF_X - 30, TEMPLE_CLIFF_X + 18, temple_row, temple_row - 16, 0.6, haze)
	SanctumBuildings.paint_air_tower(tall, TEMPLE_CLIFF_X - 8, temple_row - 10, temple_row - 40, 8, 24, haze)
	SanctumBuildings.paint_air_tower(tall, TEMPLE_CLIFF_X + 22, temple_row, temple_row - 22, 5, 15, haze)
	SanctumBuildings.paint_stupa(tall, TEMPLE_CLIFF_X - 36, temple_row, 9, haze)
	SanctumBuildings.paint_blossom_tree(tall, TEMPLE_CLIFF_X + 37, temple_row, 13.0, haze, 4167)
	_paint_waterfall(tall, Vector2(temple.z - 10.0, temple.x + 2.0), _surface_row(MEADOW_ROW) - temple.x, haze)
	# Prayer flags from the tall tower's spire to the shrine's stupa, and on from
	# the shrine round the strip back to the tower (put_pixel wraps x).
	var spire: Vector2 = Vector2(TEMPLE_CLIFF_X - 8, temple_row - 72)
	var stupa_tip: Vector2 = Vector2(SHRINE_CLIFF_X - 4, shrine_row - 22)
	SanctumBuildings.paint_prayer_flags(tall, spire, stupa_tip, (spire + stupa_tip) * 0.5 + Vector2(0.0, 46.0), 9, 4, haze)
	var wrapped_spire: Vector2 = spire + Vector2(BackdropPaint.STRIP_WIDTH, 0.0)
	SanctumBuildings.paint_prayer_flags(tall, stupa_tip, wrapped_spire, (stupa_tip + wrapped_spire) * 0.5 + Vector2(0.0, 40.0), 9, 4, haze)


## The Near layer (see the header): a few nearer rocky ledges with pines, two
## under the cloud sea and one above it.
static func paint_near(tall: Image) -> void:
	var colors: Array[Color] = pine_colors(NEAR_HAZE)
	var surface_tops: Array[Vector3] = paint_floating_platforms(tall, BackdropTheme.SURFACE_SECTION, 2, Vector2(40.0, 80.0), 7, NEAR_HAZE, 4231)
	paint_pine(tall, Vector2(surface_tops[0].x - 4.0, surface_tops[0].y), 26.0, 8.0, 3, colors, 4232)
	paint_pine(tall, Vector2(surface_tops[1].x + 6.0, surface_tops[1].y), 20.0, -7.0, 3, colors, 4233)
	var skyline_tops: Array[Vector3] = paint_floating_platforms(tall, BackdropTheme.SKYLINE_SECTION, 1, Vector2(70.0, 70.0), 7, NEAR_HAZE, 4235)
	SanctumBuildings.paint_blossom_tree(tall, roundi(skyline_tops[0].x), roundi(skyline_tops[0].y), 16.0, NEAR_HAZE, 4236)


## The Front layer (see the header), in cool shade: the old pine and the leaves.
static func paint_front(tall: Image) -> void:
	var colors: Array[Color] = [FRONT_LEAF, FRONT_LEAF_LIT, FRONT_BODY.darkened(0.3), FRONT_BODY] as Array[Color]
	var foot: Vector2 = Vector2(FRONT_PINE_X, _surface_row(BackdropPaint.SCREEN_HEIGHT + BackdropPaint.SCREEN_TOP_ROW))
	var top: Vector2 = Vector2(FRONT_PINE_X - 60, _skyline_row(40))
	var control: Vector2 = Vector2(FRONT_PINE_X + 50, _surface_row(-20))
	# The trunk: thick at the foot, thinning up, lit along its left side.
	var steps: int = ceili(foot.distance_to(top))
	for step: int in steps + 1:
		var along: float = float(step) / steps
		var point: Vector2 = BackdropPaint.curve_point(foot, control, top, along)
		var width: int = maxi(3, roundi(12.0 * (1.0 - 0.7 * along)))
		BackdropPaint.put_rect(tall, Rect2i(roundi(point.x) - width / 2, roundi(point.y), width, 1), FRONT_BODY)
		BackdropPaint.put_pixel(tall, roundi(point.x) - width / 2, roundi(point.y), FRONT_LIT)
		# Bark: short dark lines across it now and then.
		if step % 9 == 0:
			BackdropPaint.put_rect(tall, Rect2i(roundi(point.x) - width / 2 + 1, roundi(point.y), width - 2, 1), FRONT_BODY.darkened(0.25))
	# Boughs: long arms reaching left off the trunk, each ending in flat pads of
	# needles: three in the skyline, one low in the surface. Each is (how far up
	# the trunk it grows 0-1, its length, how far its tip droops); higher pads are
	# a little smaller.
	for bough: Vector3 in [Vector3(0.94, 70.0, -4.0), Vector3(0.8, 110.0, 6.0), Vector3(0.62, 80.0, -2.0), Vector3(0.22, 54.0, 10.0)]:
		var stem: Vector2 = BackdropPaint.curve_point(foot, control, top, bough.x)
		var tip: Vector2 = stem + Vector2(-bough.y, bough.z)
		BackdropPaint.put_line(tall, stem, tip, FRONT_BODY, 3)
		for pad_index: int in 3:
			var pad: Vector2 = stem.lerp(tip, 0.45 + pad_index * 0.27)
			var half: float = 14.0 + pad_index * 3.0 - bough.x * 4.0
			for lift: int in 5:
				var row_half: float = half * sqrt(1.0 - pow(lift / 5.0, 2.0))
				var color: Color = colors[0]
				if lift == 4:
					color = colors[1]
				elif lift == 0:
					color = colors[2]
				BackdropPaint.put_rect(tall, Rect2i(roundi(pad.x - row_half), roundi(pad.y) - lift - 1, roundi(row_half * 2.0) + 1, 1), color)
			for tuft: int in roundi(half / 2.5):
				BackdropPaint.put_rect(tall, Rect2i(roundi(pad.x - half * 0.8) + tuft * 5, roundi(pad.y), 3, 2), colors[2])
	# Broad leaves at the surface's foot.
	var bottom: float = _surface_row(196)
	BackdropPaint.paint_leaf_clump(tall, Vector2(36.0, bottom), 5, -PI * 0.5, 1.7, Vector2(30.0, 54.0), 0.7,
		FRONT_LEAF, FRONT_LEAF_LIT, FRONT_LEAF_RIB, 4243)
	BackdropPaint.paint_leaf_clump(tall, Vector2(FRONT_PINE_X - 30.0, bottom + 6.0), 3, -PI * 0.5, 1.1, Vector2(22.0, 36.0), 0.5,
		FRONT_LEAF, FRONT_LEAF_LIT, FRONT_LEAF_RIB, 4244)


## Adds every shared layer, far to near, to `theme` showing `section`: the surface
## and the skyline both call this, so their layers, scrolls and order are the same
## and the change between them is one picture scrolling on. The light shafts are
## drawn in both too (they start up at the cloud sea's underside and fall through
## the surface), and so are the motes.
static func add_shared_layers(theme: BackdropTheme, section: int) -> void:
	theme.add_tall_layer(NAME, "Sky", Vector2(0.01, 0.0), paint_sky, section)
	theme.add_tall_layer(NAME, "FarPeaks", Vector2(0.03, 0.01), paint_far_peaks, section)
	theme.add_tall_layer(NAME, "CloudSea", Vector2(0.06, 0.02), paint_cloud_sea, section, 2.0)
	theme.add_tall_layer(NAME, "Cliffs", Vector2(0.11, 0.04), paint_cliffs, section)
	theme.add_tall_layer(NAME, "Mist", Vector2(0.13, 0.045), paint_mist, section, 3.0)
	theme.add_tall_layer(NAME, "Temple", Vector2(0.2, 0.07), paint_temple, section)
	# The shafts' tops sit at the cloud sea's underside: on a picture one section
	# lower they'd start a whole screen further down.
	var shaft_top: float = BackdropPaint.SCREEN_TOP_ROW + CLOUD_UNDER_SCREEN_ROW + (BackdropPaint.SCREEN_HEIGHT if section == BackdropTheme.SKYLINE_SECTION else 0)
	var shaft_xs: Array[float] = [60.0, 210.0, 400.0, 520.0]
	theme.add_drawn_layer("Shafts", Vector2(0.2, 0.07), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		BackdropTheme.draw_light_shafts(layer, copy_x, time, shaft_xs, 12.0, -0.32, 200.0, SHAFT_COLOR, shaft_top))
	theme.add_tall_layer(NAME, "Near", Vector2(0.3, 0.1), paint_near, section)
	theme.add_tall_layer(NAME, "Front", FRONT_SCROLL, paint_front, section)

	var petals: BackdropMotes = BackdropMotes.new()
	petals.shape = BackdropMotes.Shape.LEAF
	petals.mote_count = 10
	petals.colors = [Color(1.0, 0.8, 0.86, 0.9), Color(0.96, 0.66, 0.76, 0.85), Color(1.0, 0.94, 0.95, 0.8)]
	petals.velocity = Vector2(9.0, 7.0)
	petals.sway_amplitude = 6.0
	petals.sway_speed = 0.4
	petals.scroll_factor = 0.6
	petals.seed_value = 4201
	theme.add_motes(petals)

	var birds: BackdropMotes = BackdropMotes.new()
	birds.shape = BackdropMotes.Shape.BIRD
	birds.mote_count = 6
	birds.colors = [Color(0.36, 0.42, 0.52, 0.8)]
	birds.velocity = Vector2(-7.0, 0.0)
	birds.sway_amplitude = 3.0
	birds.sway_speed = 0.2
	birds.size_range = Vector2i(1, 2)
	birds.scroll_factor = 0.15
	birds.vertical_range = Vector2(10.0, 90.0)
	birds.seed_value = 4301
	theme.add_motes(birds)


## A skyline screen row as a row of the tall pictures.
static func _skyline_row(screen_y: float) -> int:
	return BackdropPaint.tall_row(screen_y, BackdropTheme.SKYLINE_SECTION)


## A surface screen row as a row of the tall pictures.
static func _surface_row(screen_y: float) -> int:
	return BackdropPaint.tall_row(screen_y, BackdropTheme.SURFACE_SECTION)
