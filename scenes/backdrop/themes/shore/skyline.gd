extends BackdropTheme
## SHORE, SKYLINE: on top of the sea cliffs, high over the ocean. The same blue
## sky and sea as the beach below (ShoreStyle), the sea reaching to a high
## horizon with tiny sea stacks far out, the low cloud bank beneath us, a grassy
## cliff top in front with a lighthouse whose beam sweeps round, and tall dune
## grass bending in the wind right in front; gulls and wind. Layers far to near;
## see BackdropTheme. (Surface: surface.gd, the beach; under it: underground.gd,
## a sea cave.)
##
## The sea's layers move only sideways (vertical factor 0), so the horizon stays put.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const HORIZON_SCREEN_ROW: int = ShoreStyle.SKYLINE_HORIZON_SCREEN_ROW

const STACK_BODY: Color = Color(0.3, 0.36, 0.5)
const STACK_RIM: Color = Color(0.48, 0.5, 0.6)
const FOAM: Color = Color(0.85, 0.88, 0.9)

const NEAR_GRASS: Color = Color(0.13, 0.22, 0.14)
const NEAR_GRASS_LIT: Color = Color(0.24, 0.36, 0.2)
const NEAR_ROCK: Color = Color(0.1, 0.1, 0.13)
const TOWER_WHITE: Color = Color(0.82, 0.8, 0.76)
const TOWER_SHADE: Color = Color(0.62, 0.6, 0.6)
const TOWER_RED: Color = Color(0.66, 0.24, 0.22)
const TOWER_RED_SHADE: Color = Color(0.5, 0.18, 0.18)
const LANTERN: Color = Color(1.0, 0.92, 0.6)
const BEAM_COLOR: Color = Color(1.0, 0.95, 0.7, 0.13)

## The lighthouse: strip x of its middle and the screen row of its lamp.
const TOWER_X: int = 470
const LAMP_SCREEN_ROW: int = 64
const CLIFF_SCREEN_ROW: int = 160
## Where the headland's cliff top starts (strip x); it runs to the strip's end.
const CLIFF_EDGE_X: int = 250


func _build_layers() -> void:
	add_tall_layer(ShoreStyle.NAME, "SkyAndSea", Vector2(0.01, 0.0), ShoreStyle.paint_sky_and_sea, SKYLINE_SECTION)
	var stacks: BackdropLayer = add_painted_layer("SeaStacks", Vector2(0.03, 0.0), _paint_sea_stacks)
	stacks.draw_extra = _draw_stack_foam
	add_tall_layer(ShoreStyle.NAME, "CloudBank", Vector2(0.05, 0.0), ShoreStyle.paint_cloud_bank, SKYLINE_SECTION, 4.0)
	var cliff: BackdropLayer = add_painted_layer("CliffTop", Vector2(0.42, 0.13), _paint_cliff_top)
	cliff.draw_extra = _draw_lighthouse_beam
	add_painted_layer("Front", ShoreStyle.FRONT_SCROLL, _paint_front)

	var gulls: BackdropMotes = BackdropMotes.new()
	gulls.shape = BackdropMotes.Shape.BIRD
	gulls.mote_count = 5
	gulls.colors = [Color(0.97, 0.95, 0.9, 0.9), Color(0.3, 0.3, 0.38, 0.8)]
	gulls.velocity = Vector2(-12.0, 0.0)
	gulls.sway_amplitude = 6.0
	gulls.sway_speed = 0.12
	gulls.size_range = Vector2i(1, 2)
	gulls.scroll_factor = 0.3
	gulls.vertical_range = Vector2(20.0, 130.0)
	gulls.seed_value = 1711
	add_motes(gulls)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 12
	wind.colors = [Color(1.0, 0.95, 0.85, 0.18)]
	wind.velocity = Vector2(70.0, 2.0)
	wind.size_range = Vector2i(2, 5)
	wind.scroll_factor = 0.5
	wind.seed_value = 1712
	add_motes(wind)


## Tiny sea stacks and islets far out on the water.
func _paint_sea_stacks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var horizon: float = BackdropPaint.row(HORIZON_SCREEN_ROW)
	for stack_index: int in 7:
		var x: int = roundi((stack_index + BackdropPaint.random01(stack_index, 1, 1721) * 0.7) * BackdropPaint.STRIP_WIDTH / 7.0)
		var foot: int = roundi(horizon + 6.0 + BackdropPaint.random01(stack_index, 2, 1721) * 40.0)
		var height: int = 3 + roundi(BackdropPaint.random01(stack_index, 3, 1721) * 6.0) + (foot - int(horizon)) / 8
		var half_width: int = 1 + roundi(BackdropPaint.random01(stack_index, 4, 1721) * 3.0)
		# Narrower toward the top, a step in each side; the top rim catches the sun.
		for dy: int in height:
			var narrowing: int = roundi(float(dy) / height * half_width * 0.7)
			var row_y: int = foot - 1 - dy
			BackdropPaint.put_rect(image, Rect2i(x - half_width + narrowing, row_y, (half_width - narrowing) * 2 + 1, 1),
				STACK_RIM if dy == height - 1 else STACK_BODY)
	return image


## A blinking ring of foam round each stack's foot.
func _draw_stack_foam(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var horizon: float = BackdropPaint.row(HORIZON_SCREEN_ROW)
	for stack_index: int in 7:
		var x: float = roundf((stack_index + BackdropPaint.random01(stack_index, 1, 1721) * 0.7) * BackdropPaint.STRIP_WIDTH / 7.0)
		var foot: float = roundf(horizon + 6.0 + BackdropPaint.random01(stack_index, 2, 1721) * 40.0)
		var half_width: float = 1.0 + roundf(BackdropPaint.random01(stack_index, 4, 1721) * 3.0)
		var swell: float = 1.0 + roundf(sin(time * 1.5 + stack_index) + 1.0)
		layer.draw_rect(Rect2(copy_x + x - half_width - swell, foot, half_width * 2.0 + 1.0 + swell * 2.0, 1.0), FOAM)


## The cliff top we stand on, its grass, a rocky edge, and the lighthouse.
func _paint_cliff_top() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(CLIFF_SCREEN_ROW + 14), [Vector2(200.0, 18.0), Vector2(40.0, 5.0)] as Array[Vector2], 1751, false)
	# A headland, not a shelf: the cliff top runs from CLIFF_EDGE_X to the strip's
	# end; before it the ground drops away out of view (the sea and clouds show).
	for x: int in BackdropPaint.STRIP_WIDTH:
		if x < CLIFF_EDGE_X:
			tops[x] = BackdropPaint.STRIP_HEIGHT + 4.0
		elif x < CLIFF_EDGE_X + 16:
			tops[x] = lerpf(BackdropPaint.row(CLIFF_SCREEN_ROW + 40), tops[x], (x - CLIFF_EDGE_X) / 16.0)
	var foot_row: int = ceili(tops[TOWER_X]) + 2
	var lamp_row: int = BackdropPaint.row(LAMP_SCREEN_ROW)
	# The tower: tapering, red and white bands, the right side in shade.
	for y: int in range(lamp_row + 6, foot_row):
		var along: float = float(y - lamp_row) / (foot_row - lamp_row)
		var half_width: int = 4 + roundi(along * 4.0)
		var is_red: bool = ((y - lamp_row) / 14) % 2 == 1
		BackdropPaint.put_rect(image, Rect2i(TOWER_X - half_width, y, half_width * 2 + 1, 1), TOWER_RED if is_red else TOWER_WHITE)
		BackdropPaint.put_rect(image, Rect2i(TOWER_X + 1, y, half_width, 1), TOWER_RED_SHADE if is_red else TOWER_SHADE)
	# The lamp room and its cap.
	BackdropPaint.put_rect(image, Rect2i(TOWER_X - 6, lamp_row + 5, 13, 2), NEAR_ROCK)
	BackdropPaint.put_rect(image, Rect2i(TOWER_X - 3, lamp_row - 2, 7, 7), LANTERN)
	BackdropPaint.put_rect(image, Rect2i(TOWER_X - 4, lamp_row - 4, 9, 2), TOWER_RED_SHADE)
	BackdropPaint.put_rect(image, Rect2i(TOWER_X - 1, lamp_row - 6, 3, 2), TOWER_RED_SHADE)
	BackdropPaint.fill_below(image, tops, NEAR_GRASS)
	BackdropPaint.paint_rim(image, tops, NEAR_GRASS_LIT, 2)
	# Grass blades along the top.
	for blade_index: int in 60:
		var x: int = floori(BackdropPaint.random01(blade_index, 1, 1754) * BackdropPaint.STRIP_WIDTH)
		BackdropPaint.put_line(image, Vector2(x, tops[x]), Vector2(x + 2, tops[x] - 4.0), NEAR_GRASS_LIT)
	return image


## The lamp's beam sweeping round: a long wedge that is widest when it points
## sideways at us and thins to nothing as it turns away, plus the lamp's glow.
func _draw_lighthouse_beam(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var lamp: Vector2 = Vector2(copy_x + TOWER_X + 0.5, BackdropPaint.row(LAMP_SCREEN_ROW) + 1.5)
	var turn: float = time * 0.9
	var facing: float = cos(turn)  # +1 pointing right, -1 left, 0 toward or away from us
	var strength: float = absf(facing)
	if strength > 0.08:
		var direction: float = signf(facing)
		var length: float = 240.0 * strength
		var spread: float = 4.0 + 10.0 * strength
		layer.draw_colored_polygon(PackedVector2Array([lamp + Vector2(0.0, -2.0), lamp + Vector2(0.0, 2.0),
			lamp + Vector2(direction * length, spread), lamp + Vector2(direction * length, -spread)]),
			Color(BEAM_COLOR, BEAM_COLOR.a * strength))
	BackdropTheme.draw_glow(layer, lamp, 10.0, Color(LANTERN, 0.12), 0.6 + 0.4 * (1.0 - strength))


## Right in front: tall tufts of dune grass in the bottom corners, every blade
## bending the same way in the wind.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for tuft: Vector2 in [Vector2(30.0, 30.0), Vector2(70.0, 18.0), Vector2(380.0, 26.0)]:
		for blade: int in 9:
			var root: Vector2 = Vector2(tuft.x + (blade - 4) * 3.0, BackdropPaint.STRIP_HEIGHT)
			var height: float = tuft.y + 30.0 + BackdropPaint.random01(int(tuft.x), blade, 1761) * 30.0
			var control: Vector2 = root + Vector2(4.0, -height * 0.7)
			var tip: Vector2 = root + Vector2(16.0 + blade * 1.5, -height)
			var steps: int = roundi(height)
			for step: int in steps:
				var point: Vector2 = BackdropPaint.curve_point(root, control, tip, float(step) / steps)
				BackdropPaint.put_rect(image, Rect2i(roundi(point.x), roundi(point.y), 2 if step < steps * 0.6 else 1, 1),
					ShoreStyle.FRONT_LIT if blade % 3 == 0 else ShoreStyle.FRONT_BODY)
	return image
