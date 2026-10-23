class_name EditorCamera
extends Camera2D
## EditorCamera: the level editor's view (Level_editor.md §4). Pans and zooms; the
## LevelEditor calls it from its input handling.
##
## Zoom only goes in whole steps. While editing, the window draws at 640x360 and is
## scaled up 2x to 1280x720 (see LevelEditor), so one level pixel covers
## 2 x zoom screen pixels. Every step below makes that a whole number (1, 2, 3, 4,
## 6, 8), so pixel art stays crisp, with no uneven, smeared pixels.
## The two smallest steps (1/8 and 1/4) are for the map of rooms (Stage L7), where
## seeing the whole level matters more than crisp pixels.
## (Godot 4's Camera2D: zoom 2 = things look twice as big.)

const ZOOM_LEVELS: Array[float] = [0.125, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0]
const START_ZOOM_INDEX: int = 4

var zoom_index: int = START_ZOOM_INDEX


func _ready() -> void:
	zoom = Vector2.ONE * ZOOM_LEVELS[zoom_index]
	# Take over from any other camera, so the view is ours.
	make_current()


## The zoom factor now (zoom.x == zoom.y always).
func get_zoom_factor() -> float:
	return ZOOM_LEVELS[zoom_index]


## Zooms `steps` levels in (+) or out (-), keeping the level point under the mouse
## where it is on screen, so you zoom "into" what you're pointing at.
## `mouse_screen` is the mouse in the viewport's coordinates (640x360 space).
func zoom_by(steps: int, mouse_screen: Vector2) -> void:
	var new_index: int = clampi(zoom_index + steps, 0, ZOOM_LEVELS.size() - 1)
	if new_index == zoom_index:
		return
	# The camera's position is the level point at the CENTER of the screen.
	# A screen point `from_center` pixels from the center shows level point
	#   position + from_center / zoom
	# Solve for the new position that keeps the mouse's level point fixed.
	# (Not called `offset`: Camera2D already has an `offset` property.)
	var screen_center: Vector2 = get_viewport_rect().size / 2.0
	var from_center: Vector2 = mouse_screen - screen_center
	var point_under_mouse: Vector2 = position + from_center / get_zoom_factor()
	zoom_index = new_index
	zoom = Vector2.ONE * get_zoom_factor()
	position = point_under_mouse - from_center / get_zoom_factor()


## Moves the view by a mouse drag of `screen_delta` pixels: the level follows the
## mouse, so the camera moves the other way, scaled by zoom.
func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / get_zoom_factor()


## Picks the largest zoom step at which `rect` fits in `available_size` screen
## pixels (the space between the panels), then centers it like focus_on().
func zoom_to_fit(rect: Rect2, available_size: Vector2, screen_offset: Vector2 = Vector2.ZERO) -> void:
	zoom_index = 0
	for index: int in ZOOM_LEVELS.size():
		if rect.size.x * ZOOM_LEVELS[index] <= available_size.x and rect.size.y * ZOOM_LEVELS[index] <= available_size.y:
			zoom_index = index
	zoom = Vector2.ONE * get_zoom_factor()
	focus_on(rect, screen_offset)


## Centers `rect` (a room's bounds) on screen without changing the zoom, moved by
## `screen_offset` pixels (e.g. to center it in the space beside the palette).
func focus_on(rect: Rect2, screen_offset: Vector2 = Vector2.ZERO) -> void:
	position = rect.get_center() - screen_offset / get_zoom_factor()
