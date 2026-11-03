class_name BackdropMotes
extends Node2D
## Small things floating in front of a backdrop's layers but behind the rooms: snow,
## wind streaks, dust, fireflies, falling leaves, blowing sand, bubbles. Made by a
## theme script (themes/*.gd), which sets the fields below and then calls setup().
##
## Each mote lives in SCREEN coordinates and wraps around the screen's edges, so a
## fixed number of them is always on screen. When the camera moves, the motes move
## the other way by `scroll_factor` of that (parallax, like BackdropLayer), so they
## sit at a depth instead of sticking to the glass.

enum Shape {
	DOT,      ## a square speck (snow, dust, marine snow)
	STREAK,   ## a short horizontal line (wind, blowing sand)
	BUBBLE,   ## a small ring with a bright pixel (underwater)
	LEAF,     ## a 2x1 speck that flips while it tumbles down
	FIREFLY,  ## a dot with a soft glow that blinks on and off
	BIRD,     ## a tiny far bird: a "v" whose wings flap up and down
	BAT,      ## a little bat (BAT_FRAMES), wings beating (give it sway: bats flutter); size is ignored
}

## The BAT's pictures, 11 x 5 px, its body in the middle: ears and a head on
## top, wings with a scalloped trailing edge. 0 wings raised, 1 level, 2 swept down.
const BAT_FRAMES: Array[Array] = [
	["x...x.x...x", "xx..xxx..xx", ".xxxxxxxxx.", "..x.xxx.x..", ".....x....."],
	["....x.x....", "....xxx....", "xxxxxxxxxxx", ".x.x.x.x.x.", ".....x....."],
	["....x.x....", "....xxx....", "..xxxxxxx..", ".xx.xxx.xx.", "x....x....x"],
]
## One beat: raised, level, down, level.
const BAT_FLAP_ORDER: Array[int] = [0, 1, 2, 1]
const BAT_HALF_WIDTH: int = 5
## How fast the frames turn over, per radian of a mote's sway phase (the phase
## turns TAU * sway_speed radians a second).
const BAT_FRAMES_PER_RADIAN: float = 1.2

## Margin around the screen, px, where motes may wander before wrapping.
const SCREEN_MARGIN: float = 12.0

var shape: Shape = Shape.DOT
var mote_count: int = 30
## Colors picked at random per mote.
var colors: Array[Color] = [Color(1.0, 1.0, 1.0, 0.5)]
## Average movement in px per second; each mote gets 60-140% of it.
var velocity: Vector2 = Vector2(0.0, 10.0)
## Side-to-side sway: px and cycles per second (snow, bubbles wobble).
var sway_amplitude: float = 0.0
var sway_speed: float = 1.0
## Smallest and largest size in px (a dot's side, a streak's length unit, a ring's radius).
var size_range: Vector2i = Vector2i(1, 1)
## Parallax: how much of the camera's movement the motes follow (0 = none).
var scroll_factor: float = 0.6
## Screen rows the motes stay between (e.g. only under a waterline); ZERO = all of it.
var vertical_range: Vector2 = Vector2.ZERO
## Seed: the same backdrop always starts with the same motes.
var seed_value: int = 1

var _positions: PackedVector2Array = PackedVector2Array()
var _speed_scales: PackedFloat32Array = PackedFloat32Array()
var _phases: PackedFloat32Array = PackedFloat32Array()
var _sizes: PackedInt32Array = PackedInt32Array()
var _color_indices: PackedInt32Array = PackedInt32Array()
var _elapsed_time: float = 0.0
var _last_camera_offset: Vector2 = Vector2.ZERO


## Scatters the motes over the screen. Call once, after setting the fields.
func setup() -> void:
	# A RandomNumberGenerator with a fixed seed: random-looking, but the same every run.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var area: Rect2 = _get_wrap_area()
	for index: int in mote_count:
		_positions.append(Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)))
		_speed_scales.append(rng.randf_range(0.6, 1.4))
		_phases.append(rng.randf() * TAU)
		_sizes.append(rng.randi_range(size_range.x, size_range.y))
		_color_indices.append(rng.randi() % colors.size())


func follow_camera(camera_offset: Vector2, delta: float) -> void:
	_elapsed_time += delta
	var camera_shift: Vector2 = (camera_offset - _last_camera_offset) * scroll_factor
	_last_camera_offset = camera_offset
	var area: Rect2 = _get_wrap_area()
	for index: int in _positions.size():
		var position_now: Vector2 = _positions[index] + velocity * _speed_scales[index] * delta - camera_shift
		# Wrap around the screen (plus margin): what leaves one side enters the other.
		position_now.x = area.position.x + fposmod(position_now.x - area.position.x, area.size.x)
		position_now.y = area.position.y + fposmod(position_now.y - area.position.y, area.size.y)
		_positions[index] = position_now
	queue_redraw()


func _draw() -> void:
	for index: int in _positions.size():
		var phase: float = _phases[index] + _elapsed_time * sway_speed * TAU
		var sway: float = sin(phase) * sway_amplitude
		# Sway sideways for falling things, up and down for things moving sideways.
		var offset: Vector2 = Vector2(sway, 0.0) if absf(velocity.y) >= absf(velocity.x) else Vector2(0.0, sway)
		var spot: Vector2 = (_positions[index] + offset).round()
		var size: int = _sizes[index]
		var color: Color = colors[_color_indices[index]]
		match shape:
			Shape.DOT:
				draw_rect(Rect2(spot, Vector2(size, size)), color)
			Shape.STREAK:
				draw_rect(Rect2(spot, Vector2(size * 3 + 2, 1)), color)
			Shape.BUBBLE:
				draw_arc(spot, size, 0.0, TAU, 8, color, 1.0)
				draw_rect(Rect2(spot + Vector2(-size * 0.5, -size * 0.5).round(), Vector2.ONE), Color(1.0, 1.0, 1.0, color.a))
			Shape.LEAF:
				# Tumbling: wide when the sine is up, tall when it's down.
				var leaf_size: Vector2 = Vector2(2, 1) if sin(phase * 1.7) > 0.0 else Vector2(1, 2)
				draw_rect(Rect2(spot, leaf_size), color)
			Shape.FIREFLY:
				# Blink: lit for part of each cycle, smoothly in and out.
				var glow: float = clampf(sin(phase * 0.6) * 1.6 - 0.4, 0.0, 1.0)
				if glow > 0.0:
					draw_rect(Rect2(spot - Vector2.ONE, Vector2(3, 3)), Color(color, color.a * 0.25 * glow))
					draw_rect(Rect2(spot, Vector2.ONE), Color(color, color.a * glow))
			Shape.BIRD:
				# Wing tips up (a "v") for half of each flap, level-and-down for the other.
				var tip_lift: float = -float(size) if sin(phase * 4.0) > 0.0 else 1.0
				draw_line(spot + Vector2(-size - 1, tip_lift), spot, color)
				draw_line(spot, spot + Vector2(size + 1, tip_lift), color)
			Shape.BAT:
				# A little pixel bat (BAT_FRAMES): wings raised, level, swept down,
				# level again (BAT_FLAP_ORDER); a faster sway_speed beats faster.
				var frame_index: int = posmod(floori(phase * BAT_FRAMES_PER_RADIAN), BAT_FLAP_ORDER.size())
				var frame: Array = BAT_FRAMES[BAT_FLAP_ORDER[frame_index]]
				for row: int in frame.size():
					var line: String = frame[row]
					for column: int in line.length():
						if line[column] == "x":
							draw_rect(Rect2(spot + Vector2(column - BAT_HALF_WIDTH, row - 2), Vector2.ONE), color)


## The screen (from the viewport, so it's right in any window size) plus the margin,
## or only vertical_range's rows.
func _get_wrap_area() -> Rect2:
	var screen_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(320, 180)
	if vertical_range != Vector2.ZERO:
		return Rect2(-SCREEN_MARGIN, vertical_range.x, screen_size.x + SCREEN_MARGIN * 2.0, vertical_range.y - vertical_range.x)
	return Rect2(-SCREEN_MARGIN, -SCREEN_MARGIN, screen_size.x + SCREEN_MARGIN * 2.0, screen_size.y + SCREEN_MARGIN * 2.0)
