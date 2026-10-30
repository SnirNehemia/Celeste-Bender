class_name BackdropPreview
extends ColorRect
## BackdropPreview: a screen that shows every backdrop look (scenes/backdrop/) on
## its own, so you can browse them without making rooms and walking through them.
## The level editor opens it (K, the map's right-click menu, or the room panel's
## "Preview backdrops" button); it covers the editor until closed.
##
## Keys (action names, see project.godot):
##   move_left / move_right   the previous / next look   (scrolls sideways)
##   move_up / move_down      higher / lower altitude    (scrolls up / down)
##   backdrop_preview_drift   camera drift on / off (Space): see the parallax
##   ui_accept                use this look on the selected rooms (Enter; only
##                            when opened with rooms to set, see open())
##   ui_cancel or editor_backdrop_preview   close (Esc, K)
## The scrolls are the same ones a level shows between rooms (Backdrop.show_look).
##
## How it's built: a SubViewport is a separate little screen with its own 2D
## world, camera and CanvasLayers. This one is 320x180 like the game, holds a
## Camera2D and a Backdrop, and a SubViewportContainer shows it here, scaled up in
## whole steps (crisp pixels) to fit. Like EditorHelp, the whole thing is a dim
## full-screen ColorRect: mouse_filter STOP keeps clicks from reaching the level.

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const GAME_SIZE: Vector2i = Vector2i(320, 180)
## The two text lines sit on a dark band over the picture's bottom edge.
const TEXT_BAND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const HINT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const FONT_SIZE: int = 12
## How the camera wanders while drifting: px per second sideways, and an up and
## down sway (px, cycles per second) so the vertical parallax shows too.
const DRIFT_SPEED: float = 40.0
const SWAY_HEIGHT: float = 30.0
const SWAY_SPEED: float = 0.08

## Called with (look, altitude) when Enter is pressed; invalid = Enter does nothing.
var on_apply: Callable = Callable()
## What Enter would change, for the hint line ("3 selected rooms").
var apply_target_text: String = ""
var is_drifting: bool = true

var _container: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera2D
var _backdrop: Backdrop
var _text_band: ColorRect
var _name_label: Label
var _hint_label: Label
## The looks in the order Left / Right walks through them.
var _looks: Array = []
var _look_index: int = 0
var _altitude: Backdrop.Altitude = Backdrop.Altitude.SURFACE
var _drift_time: float = 0.0


func _ready() -> void:
	color = DIM_COLOR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_looks = Backdrop.THEME_SCRIPTS.keys()

	_container = SubViewportContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.size = GAME_SIZE
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_container.add_child(_viewport)
	_camera = Camera2D.new()
	_viewport.add_child(_camera)

	_text_band = ColorRect.new()
	_text_band.color = TEXT_BAND_COLOR
	_text_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_band)
	_name_label = _make_label(TEXT_COLOR)
	_hint_label = _make_label(HINT_COLOR)
	resized.connect(_lay_out)


## Shows the preview, starting on `look` at `altitude`. `apply` (optional):
## func(look, altitude) for Enter, which then closes the preview; `target_text`
## names what it changes, for the hint line.
func open(look: Backdrop.Look, altitude: Backdrop.Altitude, apply: Callable = Callable(), target_text: String = "") -> void:
	on_apply = apply
	apply_target_text = target_text
	_look_index = maxi(0, _looks.find(look))
	_altitude = altitude if altitude != Backdrop.Altitude.AUTO else Backdrop.Altitude.SURFACE
	# A fresh Backdrop each time: it starts on the look with no scroll.
	_backdrop = Backdrop.new()
	_backdrop.camera = _camera
	_viewport.add_child(_backdrop)
	_camera.position = Vector2.ZERO
	_drift_time = 0.0
	_backdrop.show_look(_looks[_look_index], _altitude)
	visible = true
	_lay_out()
	_update_text()


func close() -> void:
	visible = false
	if _backdrop != null:
		_backdrop.queue_free()
		_backdrop = null


func _process(delta: float) -> void:
	if not visible or not is_drifting:
		return
	_drift_time += delta
	_camera.position = Vector2(_drift_time * DRIFT_SPEED, sin(_drift_time * SWAY_SPEED * TAU) * SWAY_HEIGHT)


## _input runs before the editor sees the key, so arrows and Esc stay here.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("editor_backdrop_preview"):
		close()
	elif event.is_action_pressed("move_left"):
		_step_look(-1)
	elif event.is_action_pressed("move_right"):
		_step_look(1)
	elif event.is_action_pressed("move_up"):
		_step_altitude(1)
	elif event.is_action_pressed("move_down"):
		_step_altitude(-1)
	elif event.is_action_pressed("backdrop_preview_drift"):
		is_drifting = not is_drifting
	elif event.is_action_pressed("ui_accept") and on_apply.is_valid():
		on_apply.call(_looks[_look_index], _altitude)
		close()
	else:
		return
	get_viewport().set_input_as_handled()
	_update_text()


## The look `step` places along (wrapping), scrolling sideways that way.
func _step_look(step: int) -> void:
	_look_index = posmod(_look_index + step, _looks.size())
	_backdrop.show_look(_looks[_look_index], _altitude, Vector2.RIGHT * step)
	_update_text()


## One altitude up (`step` 1) or down, scrolling that way; stops at the ends.
func _step_altitude(step: int) -> void:
	var next: int = clampi(_altitude + step, Backdrop.Altitude.UNDERGROUND, Backdrop.Altitude.SKYLINE)
	if next == _altitude:
		return
	_altitude = next as Backdrop.Altitude
	_backdrop.show_look(_looks[_look_index], _altitude, Vector2.UP if step > 0 else Vector2.DOWN)
	_update_text()


## Scales the picture up in whole steps to fit the screen, centered, with the
## text band along its bottom.
func _lay_out() -> void:
	var scale_factor: int = maxi(1, floori(minf(size.x / GAME_SIZE.x, size.y / GAME_SIZE.y)))
	_container.size = Vector2(GAME_SIZE)
	_container.scale = Vector2.ONE * scale_factor
	var shown_size: Vector2 = Vector2(GAME_SIZE * scale_factor)
	_container.position = ((size - shown_size) / 2.0).floor()
	var line_height: float = FONT_SIZE + 4.0
	var text_top: float = _container.position.y + shown_size.y - line_height * 2.0 - 4.0
	_text_band.position = Vector2(_container.position.x, text_top - 2.0)
	_text_band.size = Vector2(shown_size.x, line_height * 2.0 + 6.0)
	for label: Label in [_name_label, _hint_label]:
		label.position = Vector2(_container.position.x, text_top)
		label.size = Vector2(shown_size.x, line_height)
		text_top += line_height


func _update_text() -> void:
	_name_label.text = "%s   (%d / %d looks)" % [Backdrop.describe(_looks[_look_index], _altitude),
		_look_index + 1, _looks.size()]
	var hints: String = "Left / Right: look    Up / Down: altitude    Space: drift %s    Esc: close" \
		% ("on" if is_drifting else "off")
	if on_apply.is_valid():
		hints += "    Enter: use it for %s" % apply_target_text
	_hint_label.text = hints


func _make_label(text_color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", text_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
