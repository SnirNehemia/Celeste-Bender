extends CanvasLayer
## TouchControls (autoload): on-screen controls for phones, so the game can be played
## without a keyboard (the web build on a phone, https://snirnehemia.github.io/Celeste-Bender/).
##
## How it plugs in: the game reads only InputMap ACTIONS (`jump`, `move_left`...),
## never keys. A touch on a button here sends the same action a key would, as an
## InputEventAction through Input.parse_input_event(). That both sets the held state
## (Input.is_action_pressed) and reaches _unhandled_input, so menus that wait for
## `event.is_action_pressed("jump")` (the end screen) react too. Nothing in the
## player, abilities or rooms knows touches exist.
##
## Layout (TouchLayout, sizes in TouchTuning): action buttons on the left, one row
## per element; the 8-way d-pad on the right; pause / restart / full screen top right.
##
## Fingers (multi-touch): each touch has an index; `holds` remembers what each one
## is doing. A finger that lands on a grid button keeps that button held until it
## lifts, and SLIDING it onto another grid button presses that one too, released
## when it slides off again. That's how one thumb holds Jump to glide and taps Gust
## (hold C, press Z on a keyboard), or holds Hand and slides onto Ice.
## A finger that lands on the right side is a d-pad finger until it lifts, however
## far it slides. Several fingers can hold the same action: `held_counts` counts
## them, and the action is released when the last one lets go.
##
## Shown only with a touchscreen (or TouchTuning.show_without_touchscreen), while a
## player is actually playing (not in menus or the level editor's view), and hidden
## while the pause menu is open (its buttons are tapped directly).
##
## Full screen (web only): the first tap anywhere asks the browser for full screen
## (browsers only allow that right after a tap or key) and then locks landscape;
## the [ ] button switches it back on after the phone's Back gesture leaves it.
##
## CanvasLayer: draws on its own layer, fixed to the screen, unaffected by the
## camera. process_mode ALWAYS: it keeps working while the tree is paused (freeze
## frames pause the tree for a few frames).

const TUNING_PATH: String = "res://resources/touch_tuning.tres"
## Above the game and the debug overlay, below the end screen (15) and menus.
const CANVAS_LAYER_INDEX: int = 14
## Seconds after asking for full screen before locking landscape: the lock is only
## allowed once the page really is full screen.
const ORIENTATION_LOCK_DELAY: float = 0.6

enum HoldKind { GRID, DPAD, SMALL }


## What one finger is doing.
class TouchHold:
	var kind: HoldKind = HoldKind.GRID
	## The button the finger landed on (GRID and SMALL).
	var origin: TouchControlButton = null
	## The other grid button the finger has slid onto, if any (GRID).
	var passby: TouchControlButton = null
	## The move actions it presses now (DPAD).
	var dpad_actions: Array[StringName] = []
	## Its offset from the d-pad center (DPAD), for the knob.
	var dpad_offset: Vector2 = Vector2.ZERO


var tuning: TouchTuning = null
var drawing: TouchDrawing = null
var grid_buttons: Array[TouchControlButton] = []
var small_buttons: Array[TouchControlButton] = []
## Touch index -> TouchHold, for every finger on a control right now.
var holds: Dictionary = {}
## Action -> how many fingers hold it. Present = held.
var held_counts: Dictionary = {}
## True once the first tap has asked for full screen (web), so it only happens once.
var has_requested_auto_fullscreen: bool = false


func _ready() -> void:
	layer = CANVAS_LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	tuning = load(TUNING_PATH) as TouchTuning
	drawing = TouchDrawing.new()
	add_child(drawing)
	visible = false


func _process(_delta: float) -> void:
	var should_show: bool = _should_show()
	if should_show != visible:
		visible = should_show
		if not should_show:
			release_all()
	if not visible:
		return
	# Rebuilt every frame (a handful of rects): tuning edits and screen size changes
	# apply at once.
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	grid_buttons = TouchLayout.make_grid_buttons(tuning, screen_size)
	small_buttons = TouchLayout.make_small_buttons(tuning, screen_size, OS.has_feature("web"))
	_refresh_hold_buttons()
	drawing.tuning = tuning
	drawing.buttons = grid_buttons + small_buttons
	drawing.held_actions = held_counts
	drawing.dpad_center = TouchLayout.get_dpad_center(tuning, screen_size)
	drawing.has_knob = false
	for hold: TouchHold in holds.values():
		if hold.kind == HoldKind.DPAD:
			drawing.has_knob = true
			drawing.knob_offset = hold.dpad_offset
	drawing.queue_redraw()


## _input sees every event first, before the GUI and _unhandled_input, so a touch
## on a control is caught here and marked handled.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var just_went_fullscreen: bool = touch.pressed and _auto_fullscreen()
		if not visible:
			return
		if touch.pressed:
			if _on_touch_down(touch.index, touch.position, just_went_fullscreen):
				get_viewport().set_input_as_handled()
		elif holds.has(touch.index):
			_on_touch_up(touch.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and visible:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if holds.has(drag.index):
			_on_touch_move(drag.index, drag.position)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Switching apps or tabs: fingers lift without a release event reaching us.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()


## Lets go of everything every finger holds (hiding, losing focus).
func release_all() -> void:
	for index: int in holds.keys():
		_on_touch_up(index)
	holds.clear()


func _should_show() -> bool:
	if tuning == null or not (DisplayServer.is_touchscreen_available() or tuning.show_without_touchscreen):
		return false
	if FX.is_menu_open:
		return false
	var player: Node = get_tree().get_first_node_in_group(Player.GROUP)
	if player == null:
		return false
	# A freeze frame (or the play-test's pause) pauses the whole tree for a moment:
	# keep things as they are instead of flickering.
	if get_tree().paused:
		return visible
	# False in the level editor's view, which keeps the level with processing off.
	return player.can_process()


## A finger lands. Returns true if it landed on a control.
func _on_touch_down(index: int, position: Vector2, just_went_fullscreen: bool) -> bool:
	for button: TouchControlButton in small_buttons:
		if button.hit_rect.has_point(position):
			var small_hold: TouchHold = TouchHold.new()
			small_hold.kind = HoldKind.SMALL
			small_hold.origin = button
			holds[index] = small_hold
			if button.action == &"":
				# The tap that just switched full screen on must not switch it off.
				if not just_went_fullscreen:
					toggle_fullscreen()
			else:
				_press(button.action)
			return true
	var grid_button: TouchControlButton = _get_grid_button_at(position)
	if grid_button != null:
		var grid_hold: TouchHold = TouchHold.new()
		grid_hold.kind = HoldKind.GRID
		grid_hold.origin = grid_button
		holds[index] = grid_hold
		_press(grid_button.action)
		return true
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if position.x >= screen_size.x - tuning.dpad_capture_width:
		var dpad_hold: TouchHold = TouchHold.new()
		dpad_hold.kind = HoldKind.DPAD
		holds[index] = dpad_hold
		_update_dpad(dpad_hold, position)
		return true
	return false


func _on_touch_move(index: int, position: Vector2) -> void:
	var hold: TouchHold = holds[index]
	match hold.kind:
		HoldKind.DPAD:
			_update_dpad(hold, position)
		HoldKind.GRID:
			var under: TouchControlButton = _get_grid_button_at(position)
			if under != null and under.action == hold.origin.action:
				under = null  # back on its own button: that one is held anyway
			var old_action: StringName = hold.passby.action if hold.passby != null else &""
			var new_action: StringName = under.action if under != null else &""
			if new_action != old_action:
				if old_action != &"":
					_release(old_action)
				if new_action != &"":
					_press(new_action)
			hold.passby = under


func _on_touch_up(index: int) -> void:
	var hold: TouchHold = holds.get(index)
	if hold == null:
		return
	if hold.origin != null and hold.origin.action != &"":
		_release(hold.origin.action)
	if hold.passby != null:
		_release(hold.passby.action)
	for action: StringName in hold.dpad_actions:
		_release(action)
	holds.erase(index)


## Moves a d-pad finger: releases the directions it left, presses the new ones.
func _update_dpad(hold: TouchHold, position: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	hold.dpad_offset = position - TouchLayout.get_dpad_center(tuning, screen_size)
	var wanted: Array[StringName] = TouchLayout.get_dpad_actions(tuning, hold.dpad_offset)
	for action: StringName in hold.dpad_actions:
		if not wanted.has(action):
			_release(action)
	for action: StringName in wanted:
		if not hold.dpad_actions.has(action):
			_press(action)
	hold.dpad_actions = wanted


## The layout is rebuilt every frame, so a finger's buttons are swapped for the
## new objects with the same action (same place unless the tuning changed).
func _refresh_hold_buttons() -> void:
	for hold: TouchHold in holds.values():
		if hold.kind == HoldKind.GRID:
			hold.origin = _find_by_action(grid_buttons, hold.origin.action, hold.origin)
			if hold.passby != null:
				hold.passby = _find_by_action(grid_buttons, hold.passby.action, hold.passby)


func _find_by_action(buttons: Array[TouchControlButton], action: StringName, fallback: TouchControlButton) -> TouchControlButton:
	for button: TouchControlButton in buttons:
		if button.action == action:
			return button
	return fallback


func _get_grid_button_at(position: Vector2) -> TouchControlButton:
	for button: TouchControlButton in grid_buttons:
		if button.hit_rect.has_point(position):
			return button
	return null


func _press(action: StringName) -> void:
	var count: int = held_counts.get(action, 0)
	held_counts[action] = count + 1
	if count == 0:
		_send_action(action, true)


func _release(action: StringName) -> void:
	var count: int = held_counts.get(action, 0)
	if count <= 0:
		return
	if count == 1:
		held_counts.erase(action)
		_send_action(action, false)
	else:
		held_counts[action] = count - 1


## InputEventAction = an input event that names an action instead of a key. Fed
## through Input.parse_input_event, the game can't tell it from a key press.
func _send_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


## The first tap of a web build on a touchscreen asks for full screen. Returns true
## if this tap did.
func _auto_fullscreen() -> bool:
	if has_requested_auto_fullscreen or not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return false
	has_requested_auto_fullscreen = true
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return false
	toggle_fullscreen()
	return true


## Full screen on/off. Also the level editor's [ ] button (EditorUI).
func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# create_timer(time, process_always...): runs even while the tree is paused.
	get_tree().create_timer(ORIENTATION_LOCK_DELAY, true).timeout.connect(_lock_landscape)


## Asks the browser to keep the page in landscape (only works in full screen; on
## anything but the web, JavaScriptBridge.eval does nothing).
func _lock_landscape() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('landscape').catch(function () {}); }", true)
