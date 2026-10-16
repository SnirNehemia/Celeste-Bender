extends Node
## FX: global "game feel" helpers — screen shake and freeze frames.
##
## AUTOLOAD (registered in project.godot as `FX`), so any script can call
##   FX.shake(2.0, 0.12)     — jiggle the camera for a moment
##   FX.freeze(0.05)         — pause the whole game for a few frames ("hit stop")
## without needing a reference to the camera or the scene tree.
##
## Who calls it: AirDashAbility now; gust, enemy hits and death later.
## No class_name on purpose (the autoload name `FX` is already global).

## Current shake strength in pixels (max offset). Fades to 0 over the shake duration.
var shake_strength_remaining: float = 0.0
## Strength at the moment shake() was called, used to fade out linearly.
var shake_start_strength: float = 0.0
## Seconds of shake left / total, for the linear fade.
var shake_time_remaining: float = 0.0
var shake_total_time: float = 0.0
## True while a freeze is running, so overlapping freezes don't restore time too early.
var is_frozen: bool = false


## Shakes the active camera: random offset up to `strength` px, fading to 0 over
## `duration` seconds. A stronger shake replaces a weaker one already running.
func shake(strength: float, duration: float) -> void:
	if strength < shake_strength_remaining:
		return
	shake_start_strength = strength
	shake_strength_remaining = strength
	shake_total_time = duration
	shake_time_remaining = duration


## Freeze frames: stops game time for `seconds` (real time), then resumes.
## Engine.time_scale scales the `delta` every node receives AND how often physics
## ticks; at 0, nothing that uses delta moves — the whole game holds still.
func freeze(seconds: float) -> void:
	if is_frozen:
		return
	is_frozen = true
	Engine.time_scale = 0.0
	# create_timer(time, process_always, process_in_physics, ignore_time_scale):
	# the last `true` makes this timer count REAL seconds, otherwise it would
	# be frozen by the very time_scale it is supposed to restore.
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	is_frozen = false


## _process runs every rendered frame. During a freeze delta is 0, so the shake
## simply holds and continues afterwards.
func _process(delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	if shake_time_remaining <= 0.0:
		camera.offset = Vector2.ZERO
		return
	shake_time_remaining = maxf(shake_time_remaining - delta, 0.0)
	# Linear fade: full strength at the start, 0 at the end.
	shake_strength_remaining = shake_start_strength * (shake_time_remaining / shake_total_time)
	# Camera2D.offset shifts the view without moving the camera's real position, so
	# RoomCamera's room clamping isn't disturbed. Rounded to whole pixels (pixel art).
	camera.offset = Vector2(
		randf_range(-shake_strength_remaining, shake_strength_remaining),
		randf_range(-shake_strength_remaining, shake_strength_remaining)).round()
