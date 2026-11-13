class_name TriggerLamps
extends RefCounted
## TriggerLamps: shows the player how far along a door or switch wall is, so the
## switches they flip visibly add up to it opening. Shared by Door and SwitchWall,
## which each own one and call it (it's not a node: it draws on its owner's canvas).
##
## Two parts:
##   - LAMPS: a small lamp on the owner per linked switch, lit while that switch is
##     where the owner wants it ("progress": on, or OFF for a door that opens while
##     its switches are off). Shown only when they tell you something: ALL mode with
##     2+ switches. With ANY mode or a single switch, one switch opens it at once.
##   - PULSE: whenever a lamp lights (progress went up), the owner shudders 1 px for
##     PULSE_TIME and the new lamp flashes white, then settles to green. Every door
##     and switch wall pulses, lamps or not.
##
## The owner calls:
##   update(states, is_all_mode)  when a linked switch changes (and in _ready/reset);
##   advance(delta) -> bool       every frame; true = it needs a redraw;
##   get_shake_offset()           and draws itself moved by it;
##   draw(canvas, area, clip)     in its _draw, after its own body.
## quiet(): for a moment no pulses (start-up and room reset: a plate whose crate is
## put back turns off and on again, which isn't the player's doing).
##
## Godot concept, RefCounted: a plain object freed when nothing refers to it any
## more; the base of helpers that aren't in the scene tree.

## Pulse: how long, and how often the 1 px shudder flips side, s.
const PULSE_TIME: float = 0.25
const SHAKE_FLIP_TIME: float = 0.05
## A newly lit lamp's white flash, s.
const FLASH_TIME: float = 0.35
## Start-up and reset: pulses are held back this long, s.
const QUIET_TIME: float = 0.15
## A lamp is LAMP_SIZE px square, in a dark socket SOCKET_SIZE px square; sockets
## are SOCKET_STEP px apart, centre to centre.
const LAMP_SIZE: float = 2.0
const SOCKET_SIZE: float = 4.0
const SOCKET_STEP: float = 5.0
## When the normal sockets don't fit (many switches on a small wall or door): 3 px
## sockets touching each other, a 1 px lamp in each.
const COMPACT_STEP: float = 3.0
const COMPACT_SOCKET_SIZE: float = 3.0
const COMPACT_LAMP_SIZE: float = 1.0
## The lamps keep this far from the owner's edge, px (its outline is there).
const AREA_MARGIN: float = 1.0
const SOCKET_COLOR: Color = Color(0.12, 0.14, 0.2)
const LAMP_COLOR_OFF: Color = Color(0.25, 0.3, 0.4)
## The pressed plate's green: "this one is done".
const LAMP_COLOR_ON: Color = Color(0.4, 0.95, 0.5)
const LAMP_COLOR_FLASH: Color = Color(1.0, 1.0, 1.0)

## One per linked switch, in the owner's `switches` order: done (progress) or not.
var lamp_states: Array[bool] = []
## Seconds of white flash left, per lamp.
var lamp_flash: Array[float] = []
var shows_lamps: bool = false
var pulse_remaining: float = 0.0
var quiet_remaining: float = 0.0


## The progress of each linked switch: done = on, or off when `wanted_on` is false
## (a door that opens while its switches are off). Empty slots are left out.
static func progress_of(switches: Array[Switch], wanted_on: bool = true) -> Array[bool]:
	var states: Array[bool] = []
	for linked_switch: Switch in switches:
		if linked_switch != null:
			states.append(linked_switch.is_on() == wanted_on)
	return states


## The switches changed (or the owner is starting / resetting): new `states`; a lamp
## that just lit flashes and, unless quiet, the owner pulses.
func update(states: Array[bool], is_all_mode: bool) -> void:
	shows_lamps = is_all_mode and states.size() >= 2
	if states.size() != lamp_states.size():
		# A new list (start-up): take it as it is, nothing "just" lit.
		lamp_states = states.duplicate()
		lamp_flash.resize(states.size())
		lamp_flash.fill(0.0)
		return
	for index: int in states.size():
		if states[index] and not lamp_states[index] and quiet_remaining <= 0.0:
			lamp_flash[index] = FLASH_TIME
			pulse_remaining = PULSE_TIME
	lamp_states = states.duplicate()


## Holds pulses back for QUIET_TIME, and stops any running one.
func quiet() -> void:
	quiet_remaining = QUIET_TIME
	pulse_remaining = 0.0
	lamp_flash.fill(0.0)


## Counts the timers down. True while something is animating (the owner redraws).
func advance(delta: float) -> bool:
	quiet_remaining = maxf(quiet_remaining - delta, 0.0)
	var is_animating: bool = pulse_remaining > 0.0
	pulse_remaining = maxf(pulse_remaining - delta, 0.0)
	for index: int in lamp_flash.size():
		if lamp_flash[index] > 0.0:
			is_animating = true
			lamp_flash[index] = maxf(lamp_flash[index] - delta, 0.0)
	return is_animating


## The owner's drawing offset while pulsing: 1 px left, then right, then left...
## Whole pixels, so the pixel art stays crisp.
func get_shake_offset() -> Vector2:
	if pulse_remaining <= 0.0:
		return Vector2.ZERO
	var flip: int = int(pulse_remaining / SHAKE_FLIP_TIME) % 2
	return Vector2(1.0 if flip == 0 else -1.0, 0.0)


## Draws the lamps on `canvas`, centred in `area` (the owner's local px), as a grid
## that fits inside it: as few columns as fit when the area is taller than wide (a
## door: a column), as few rows when it's wider. If they don't fit even then, the
## sockets shrink (COMPACT_*) and touch. Only sockets wholly inside `clip` are drawn
## (a door's closed part: lamps go with the slab as it opens).
func draw(canvas: CanvasItem, area: Rect2, clip: Rect2) -> void:
	if not shows_lamps:
		return
	var count: int = lamp_states.size()
	var layout: Dictionary = _fit_layout(count, area.size - Vector2.ONE * 2.0 * AREA_MARGIN)
	var step: float = layout[&"step"]
	var socket_size: float = layout[&"socket"]
	var lamp_size: float = layout[&"lamp"]
	var columns: int = layout[&"columns"]
	var rows: int = ceili(float(count) / float(columns))
	var grid_size: Vector2 = Vector2(step * float(columns - 1), step * float(rows - 1))
	var first: Vector2 = area.get_center() - grid_size / 2.0
	for index: int in count:
		# Row by row, left to right (switch order). The socket's corner is rounded so
		# it sits on whole pixels; the lamp is centred in it ((4-2)/2 = (3-1)/2 = 1 px in).
		var grid_cell: Vector2 = Vector2(float(index % columns), floorf(float(index) / float(columns)))
		var socket_corner: Vector2 = (first + grid_cell * step - Vector2.ONE * socket_size / 2.0).round()
		var socket: Rect2 = Rect2(socket_corner, Vector2.ONE * socket_size)
		if not clip.encloses(socket):
			continue
		canvas.draw_rect(socket, SOCKET_COLOR)
		var color: Color = LAMP_COLOR_ON if lamp_states[index] else LAMP_COLOR_OFF
		if lamp_flash[index] > 0.0:
			color = color.lerp(LAMP_COLOR_FLASH, lamp_flash[index] / FLASH_TIME)
		var lamp_inset: float = (socket_size - lamp_size) / 2.0
		canvas.draw_rect(Rect2(socket_corner + Vector2.ONE * lamp_inset, Vector2.ONE * lamp_size), color)


## How `count` lamps fit in `room` (px): {step, socket, lamp, columns}. Tries the
## normal sockets, then the compact ones; in each, the fewest columns (taller than
## wide) or rows (wider) that fit. Nothing fits: compact, as square a grid as can be
## (some sockets may then fall outside and are skipped).
static func _fit_layout(count: int, room: Vector2) -> Dictionary:
	var is_column: bool = room.y > room.x
	for sizes: Array in [[SOCKET_STEP, SOCKET_SIZE, LAMP_SIZE], [COMPACT_STEP, COMPACT_SOCKET_SIZE, COMPACT_LAMP_SIZE]]:
		var step: float = sizes[0]
		var socket_size: float = sizes[1]
		for lines: int in range(1, count + 1):
			var per_line: int = ceili(float(count) / float(lines))
			var columns: int = lines if is_column else per_line
			var rows: int = per_line if is_column else lines
			var needed: Vector2 = Vector2(step * float(columns - 1), step * float(rows - 1)) + Vector2.ONE * socket_size
			if needed.x <= room.x and needed.y <= room.y:
				return {&"step": step, &"socket": socket_size, &"lamp": sizes[2], &"columns": columns}
	return {&"step": COMPACT_STEP, &"socket": COMPACT_SOCKET_SIZE, &"lamp": COMPACT_LAMP_SIZE,
		&"columns": ceili(sqrt(float(count)))}
