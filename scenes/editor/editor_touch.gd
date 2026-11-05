class_name EditorTouch
extends Node
## EditorTouch: turns fingers on the level editor's canvas into mouse clicks, pans
## and zooms, so the editor works on a phone. Made by LevelEditor, which hands it
## every canvas event first (LevelEditor._unhandled_input -> handle_input).
##
## ONE FINGER. A phone turns the first touch into an emulated mouse click (Godot's
## "emulate mouse from touch"; those events have device InputEvent.DEVICE_ID_EMULATION).
## Passed on as they are, a finger could only ever left-click. So a touch is held
## back until it's clear what it is:
##   - TAP (lifted before LONG_PRESS_SECONDS, barely moved): a left click.
##   - DRAG (moved more than MOVE_THRESHOLD first): a left press where the finger
##     is, then the drag goes on as usual: paint strokes, dragging objects, the map.
##   - LONG PRESS (held still LONG_PRESS_SECONDS): a RIGHT press (erase, delete,
##     the map's room menu), released when the finger lifts. The phone buzzes once.
## The clicks it decides on are handed straight back to the editor's input
## handler (`replay_target`, LevelEditor._unhandled_input), marked with
## REPLAY_DEVICE so they aren't held back a second time. The editor then handles
## them exactly like real mouse clicks: nothing else in the editor knows about
## touches. Straight back, not through the viewport later: a quick drag's moves
## and release would otherwise arrive before its press.
##
## TWO FINGERS (read from the raw touches in _input, InputEventScreenTouch/Drag:
## the emulated mouse only follows the first finger):
##   - moving together PANS the view (the level follows the fingers' midpoint);
##   - spreading or pinching ZOOMS one camera step in or out each time their
##     distance grows or shrinks by PINCH_STEP_RATIO, around their midpoint (the
##     camera only has whole zoom steps, EditorCamera.ZOOM_LEVELS).
## A second finger landing cancels whatever the first was about to do (a pending
## tap or long press never happens; a stroke already started ends there), and the
## fingers do nothing else until ALL of them have lifted, so the last one left
## doesn't paint.

## How long a finger must stay still to count as a right click, seconds.
const LONG_PRESS_SECONDS: float = 0.5
## How far (editor-screen pixels, 640x360 space) a finger may wander and still be a
## tap or long press. A resting thumb jitters by a few pixels.
const MOVE_THRESHOLD: float = 8.0
## Device id the replayed clicks carry. Any id but DEVICE_ID_EMULATION works: the
## editor's mouse actions accept every device (InputMap device -1).
const REPLAY_DEVICE: int = 0
## Buzz length on a long press, milliseconds.
const LONG_PRESS_VIBRATION_MS: int = 30
## How much the two fingers' distance must change for one zoom step (1.25 = a
## quarter further apart zooms in one step, a fifth closer zooms out one).
const PINCH_STEP_RATIO: float = 1.25

## What the decided clicks are passed to: a function taking an InputEvent.
var replay_target: Callable = Callable()
## The camera two fingers pan and zoom.
var camera: EditorCamera = null
## Called after a pinch changed the zoom (the editor updates its zoom label).
var on_zoom_changed: Callable = Callable()
## A function taking a screen point (Vector2), true if a finger landing there is on
## the level canvas (not on a panel, menu or dialog, and not in a play-test).
var is_canvas_point: Callable = Callable()

## True while a finger is down and not decided yet.
var is_pending: bool = false
## The held-back press (its position is in the viewport's own coordinates).
var pending_press: InputEventMouseButton = null
var hold_time_left: float = 0.0
## Which button the finger turned into: MOUSE_BUTTON_NONE until decided.
var committed_button: MouseButton = MOUSE_BUTTON_NONE

## Touch index -> position, for every finger that landed on the canvas.
var fingers: Dictionary = {}
## True from the moment a second finger lands until every finger has lifted.
var is_gesturing: bool = false
## The two fingers' midpoint at the last pan, and their distance at the last zoom step.
var gesture_midpoint: Vector2 = Vector2.ZERO
var gesture_reference_distance: float = 0.0


## Returns true if it took the event (the editor must then ignore it).
func handle_input(event: InputEvent) -> bool:
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		return false  # a real mouse, or one of our own replays
	if is_gesturing:
		return true  # the first finger's mouse events, during a pan or pinch
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			is_pending = true
			pending_press = click.duplicate() as InputEventMouseButton
			hold_time_left = LONG_PRESS_SECONDS
			committed_button = MOUSE_BUTTON_NONE
		elif is_pending:
			# A tap: left press and release at once, in that order.
			_replay(MOUSE_BUTTON_LEFT, true)
			_replay(MOUSE_BUTTON_LEFT, false)
			is_pending = false
		elif committed_button != MOUSE_BUTTON_NONE:
			_replay(committed_button, false)
			committed_button = MOUSE_BUTTON_NONE
		return true
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and is_pending:
		if motion.position.distance_to(pending_press.position) <= MOVE_THRESHOLD:
			return true  # jitter: still a tap or a long press
		# A drag: press now, then let this motion through to carry the drag on.
		is_pending = false
		committed_button = MOUSE_BUTTON_LEFT
		_replay(MOUSE_BUTTON_LEFT, true)
		return false
	return false


## The raw touches, every finger (the mouse emulation only reports the first one).
## _input runs before the GUI, so lifts are seen even over a panel.
func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if is_canvas_point.is_valid() and is_canvas_point.call(touch.position):
				fingers[touch.index] = touch.position
				if fingers.size() >= 2 and not is_gesturing:
					_start_gesture()
		else:
			fingers.erase(touch.index)
			if fingers.size() < 2:
				# Restart from the fingers still down, so a pinch can pick up again.
				gesture_reference_distance = 0.0
			if fingers.is_empty():
				is_gesturing = false
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and fingers.has(drag.index):
		fingers[drag.index] = drag.position
		if is_gesturing and fingers.size() >= 2:
			_move_gesture()


func _process(delta: float) -> void:
	if not is_pending:
		return
	hold_time_left -= delta
	if hold_time_left <= 0.0:
		is_pending = false
		committed_button = MOUSE_BUTTON_RIGHT
		Input.vibrate_handheld(LONG_PRESS_VIBRATION_MS)
		_replay(MOUSE_BUTTON_RIGHT, true)


## Forgets every finger that's down (leaving the editor, starting a play-test).
func cancel() -> void:
	is_pending = false
	committed_button = MOUSE_BUTTON_NONE
	fingers.clear()
	is_gesturing = false


## A second finger landed: whatever the first one was doing stops here.
func _start_gesture() -> void:
	is_gesturing = true
	is_pending = false  # a tap or long press that hadn't happened yet never will
	if committed_button != MOUSE_BUTTON_NONE:
		_replay(committed_button, false)  # ends the stroke or drag already started
		committed_button = MOUSE_BUTTON_NONE
	gesture_reference_distance = 0.0


## Two fingers moved: pan by their midpoint's movement, zoom by their spread.
func _move_gesture() -> void:
	var points: Array = fingers.values()
	var first: Vector2 = points[0]
	var second: Vector2 = points[1]
	var midpoint: Vector2 = (first + second) / 2.0
	var distance: float = first.distance_to(second)
	if gesture_reference_distance <= 0.0:
		# First move with these two fingers: just remember where they are.
		gesture_midpoint = midpoint
		gesture_reference_distance = distance
		return
	if camera != null:
		camera.pan_by(midpoint - gesture_midpoint)
	gesture_midpoint = midpoint
	var ratio: float = distance / maxf(gesture_reference_distance, 1.0)
	var steps: int = 0
	if ratio >= PINCH_STEP_RATIO:
		steps = 1
	elif ratio <= 1.0 / PINCH_STEP_RATIO:
		steps = -1
	if steps != 0 and camera != null:
		camera.zoom_by(steps, midpoint)
		# Measure the next step from here, so a long spread zooms step by step.
		gesture_reference_distance = distance
		if on_zoom_changed.is_valid():
			on_zoom_changed.call()


## Hands the editor a click of `button` (the editor reads where from the mouse
## position, which follows the finger).
func _replay(button: MouseButton, pressed: bool) -> void:
	var click: InputEventMouseButton = pending_press.duplicate() as InputEventMouseButton
	click.device = REPLAY_DEVICE
	click.button_index = button
	click.pressed = pressed
	click.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	if replay_target.is_valid():
		replay_target.call(click)
