class_name TouchLayout
extends RefCounted
## Where every touch control sits, worked out from TouchTuning and the screen size.
## Static helpers only (call TouchLayout.make_grid_buttons(...) without an object).
##
## Left side: a grid of action buttons, one ROW PER ELEMENT, matching the keyboard's
## rows (Water 1/2, Fire Q/W, Earth A/S, Air Z/C): the left column is the left key.
## Air is the bottom row, nearest the resting thumb, since it's used the most.
## Right side: the 8-way d-pad. Top right: pause, restart room, full screen.

## Element colors (GAME_DESIGN.md §2 color key, lightened to read over the game).
const AIR_COLOR: Color = Color(0.65, 0.92, 1.0)
const EARTH_COLOR: Color = Color(0.82, 0.62, 0.4)
const FIRE_COLOR: Color = Color(1.0, 0.6, 0.25)
const WATER_COLOR: Color = Color(0.45, 0.65, 1.0)
const NEUTRAL_COLOR: Color = Color(0.9, 0.9, 0.9)

## The grid, TOP row first: [left action, left label, right action, right label, color].
const GRID_ROWS: Array = [
	[&"water_hands", "Hand", &"water_freeze", "Ice", WATER_COLOR],
	[&"fireball", "Ball", &"flame_jet", "Jet", FIRE_COLOR],
	[&"earth_column", "Col", &"earth_boulder", "Rock", EARTH_COLOR],
	[&"gust", "Gust", &"jump", "Jump", AIR_COLOR],
]
## How far a hit area reaches past the screen's edge (into the black bars).
const OFF_SCREEN_REACH: float = 200.0


## The left-side grid for a screen of `screen_size` game pixels.
static func make_grid_buttons(tuning: TouchTuning, screen_size: Vector2) -> Array[TouchControlButton]:
	var buttons: Array[TouchControlButton] = []
	var step: float = tuning.button_size + tuning.button_gap
	var half_gap: float = tuning.button_gap / 2.0
	var row_count: int = GRID_ROWS.size()
	for row_index: int in row_count:
		var row: Array = GRID_ROWS[row_index]
		# Rows counted up from the bottom edge, so the bottom row hugs the thumb.
		var rows_below: int = row_count - 1 - row_index
		var top: float = screen_size.y - tuning.button_margin - tuning.button_size - rows_below * step
		for column: int in 2:
			var button: TouchControlButton = TouchControlButton.new(row[column * 2], row[column * 2 + 1], row[4])
			var left: float = tuning.button_margin + column * step
			button.rect = Rect2(left, top, tuning.button_size, tuning.button_size)
			# Grow by half a gap on every side: the gaps split evenly, no dead spots.
			var hit: Rect2 = button.rect.grow(half_gap)
			if column == 0:
				hit = hit.grow_side(SIDE_LEFT, OFF_SCREEN_REACH)
			if rows_below == 0:
				hit = hit.grow_side(SIDE_BOTTOM, OFF_SCREEN_REACH)
			button.hit_rect = hit
			buttons.append(button)
	return buttons


## The top-right buttons, right to left: pause, restart room, and full screen when
## `with_fullscreen` (web builds: a browser tab can leave full screen).
static func make_small_buttons(tuning: TouchTuning, screen_size: Vector2, with_fullscreen: bool) -> Array[TouchControlButton]:
	var buttons: Array[TouchControlButton] = [
		TouchControlButton.new(&"pause", "II", NEUTRAL_COLOR),
		TouchControlButton.new(&"restart_room", "R", NEUTRAL_COLOR),
	]
	if with_fullscreen:
		buttons.append(TouchControlButton.new(&"", "[ ]", NEUTRAL_COLOR))
	var size: float = tuning.small_button_size
	var gap: float = tuning.small_button_gap
	for index: int in buttons.size():
		var left: float = screen_size.x - gap - size - index * (size + gap)
		buttons[index].rect = Rect2(left, gap, size, size)
		var hit: Rect2 = buttons[index].rect.grow(gap / 2.0)
		hit = hit.grow_side(SIDE_TOP, OFF_SCREEN_REACH)
		if index == 0:
			hit = hit.grow_side(SIDE_RIGHT, OFF_SCREEN_REACH)
		buttons[index].hit_rect = hit
	return buttons


## The d-pad ring's center: its radius plus margin in from the bottom-right corner.
static func get_dpad_center(tuning: TouchTuning, screen_size: Vector2) -> Vector2:
	var inset: float = tuning.dpad_margin + tuning.dpad_radius
	return Vector2(screen_size.x - inset, screen_size.y - inset)


## The move actions a thumb at `offset` from the d-pad's center presses: none in
## the dead zone, else one or two (a diagonal). Each axis counts once the offset's
## direction leans past dpad_axis_threshold along it, which splits the ring into
## 8 slices (4 straight, 4 diagonal) like the 8 arrow-key combinations.
static func get_dpad_actions(tuning: TouchTuning, offset: Vector2) -> Array[StringName]:
	var actions: Array[StringName] = []
	if offset.length() < tuning.dpad_dead_zone * tuning.dpad_radius:
		return actions
	var direction: Vector2 = offset.normalized()
	if direction.x > tuning.dpad_axis_threshold:
		actions.append(&"move_right")
	elif direction.x < -tuning.dpad_axis_threshold:
		actions.append(&"move_left")
	# Screen y grows downward, so a positive y is Down.
	if direction.y > tuning.dpad_axis_threshold:
		actions.append(&"move_down")
	elif direction.y < -tuning.dpad_axis_threshold:
		actions.append(&"move_up")
	return actions
