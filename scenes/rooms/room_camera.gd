class_name RoomCamera
extends Camera2D
## Celeste-style room-locked camera.
##
## Every physics frame it centers on the player, then clamps that position so the view
## never shows anything outside the current room's bounds. Result:
##   - a 320x180 room: the clamp pins the camera in place (no scrolling at all)
##   - a wider/taller room: it scrolls with the player, stopping at the room's edges
##
## When the player enters a new room, RoomManager calls slide_to_room(), which tweens
## the camera to its position in the new room. Following resumes when the slide ends.
##
## A Camera2D shows the part of the world around its position (with the default
## anchor mode, its position is the CENTER of the screen).

## What to follow. Set by RoomManager.
var follow_target: Node2D = null
## The rectangle the view must stay inside (the current room), in world coordinates.
var room_bounds: Rect2 = Rect2()
## True while a slide tween is running; following is paused meanwhile.
var is_sliding: bool = false


func _ready() -> void:
	# Update in the physics step, in sync with the player's movement; otherwise the
	# camera and player update at different moments and the player appears to jitter.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _physics_process(_delta: float) -> void:
	if is_sliding or follow_target == null:
		return
	global_position = _get_clamped_center(room_bounds)


## Jumps the camera instantly to `bounds` (used at game start).
func snap_to_room(bounds: Rect2) -> void:
	room_bounds = bounds
	global_position = _get_clamped_center(bounds)
	# Skip Camera2D's built-in smoothing/drag so the first frame is already correct.
	reset_smoothing()


## Slides the camera to `bounds` over `duration` seconds. Use with `await` to wait
## for the slide to finish:  await camera.slide_to_room(bounds, 0.3)
func slide_to_room(bounds: Rect2, duration: float) -> void:
	room_bounds = bounds
	is_sliding = true
	# A Tween animates a property from its current value to a target over time.
	var slide_tween: Tween = create_tween()
	slide_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# Ease out: fast at first, settling gently into place.
	slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_tween.tween_property(self, "global_position", _get_clamped_center(bounds), duration)
	await slide_tween.finished
	is_sliding = false


## Where the camera center should be: on the target, but clamped so the screen
## stays inside `bounds`. Rounded to whole pixels so pixel art doesn't shimmer.
func _get_clamped_center(bounds: Rect2) -> Vector2:
	var half_screen: Vector2 = get_viewport_rect().size / 2.0
	var desired_center: Vector2 = follow_target.global_position if follow_target != null else bounds.get_center()
	# The center can range from (left edge + half a screen) to (right edge - half a screen).
	# If the room is exactly one screen wide, min == max, so the camera can't move.
	var min_center: Vector2 = bounds.position + half_screen
	var max_center: Vector2 = bounds.end - half_screen
	var clamped_center: Vector2 = Vector2(
		clampf(desired_center.x, min_center.x, maxf(min_center.x, max_center.x)),
		clampf(desired_center.y, min_center.y, maxf(min_center.y, max_center.y)))
	return clamped_center.round()
