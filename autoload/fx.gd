extends Node
## FX: global "game feel" helpers — screen shake and freeze frames.
##
## AUTOLOAD (registered in project.godot as `FX`), so any script can call
##   FX.shake(2.0, 0.12)     — jiggle the camera for a moment
##   FX.freeze(0.05)         — pause the whole game for a few frames ("hit stop")
##   FX.set_slow_motion(0.25, 0.5) / FX.clear_slow_motion() — slow the game down
## without needing a reference to the camera or the scene tree.
##
## Who calls it: AirDashAbility, GustAbility, the GustAim state (slow motion);
## enemy hits and death later.
##
## Freeze PAUSES the scene tree (get_tree().paused); slow motion uses
## Engine.time_scale. They're separate switches, so they never fight.
## Why not freeze with time_scale = 0? Physics frames keep running with delta = 0,
## and a moving platform (AnimatableBody2D: sail, leaf) computes its velocity as
## motion / delta = 0 / 0 = NaN. A player standing on it got a NaN position and
## the screen went blank. A paused tree runs no physics frames at all.
## No class_name on purpose (the autoload name `FX` is already global).

## Current shake strength in pixels (max offset). Fades to 0 over the shake duration.
var shake_strength_remaining: float = 0.0
## Strength at the moment shake() was called, used to fade out linearly.
var shake_start_strength: float = 0.0
## Seconds of shake left / total, for the linear fade.
var shake_time_remaining: float = 0.0
var shake_total_time: float = 0.0
## True while a freeze is running, so overlapping freezes don't unpause too early.
var is_frozen: bool = false
## The game speed when not frozen: 1.0 normally, lower during slow motion.
var slow_motion_scale: float = 1.0
## Bumped on every set/clear, so an old safety timer can tell it's out of date.
var slow_motion_id: int = 0


## Shakes the active camera: random offset up to `strength` px, fading to 0 over
## `duration` seconds. A stronger shake replaces a weaker one already running.
func shake(strength: float, duration: float) -> void:
	if strength < shake_strength_remaining:
		return
	shake_start_strength = strength
	shake_strength_remaining = strength
	shake_total_time = duration
	shake_time_remaining = duration


## Freeze frames: stops the game for `seconds` (real time), then resumes.
## get_tree().paused = true stops _process/_physics_process (and physics itself)
## for every node whose process_mode is PAUSABLE, the default: the whole game
## holds still, exactly like the F2 room picker does.
func freeze(seconds: float) -> void:
	# Already frozen, or the game is paused by a menu: don't touch the pause.
	if is_frozen or get_tree().paused:
		return
	is_frozen = true
	get_tree().paused = true
	# create_timer(time, process_always, process_in_physics, ignore_time_scale):
	# process_always = true keeps it counting while the tree is paused, and
	# ignore_time_scale = true makes it count REAL seconds even in slow motion.
	await get_tree().create_timer(seconds, true, false, true).timeout
	get_tree().paused = false
	is_frozen = false


## Slows the whole game to `time_scale` (0.25 = quarter speed) until
## clear_slow_motion() is called. As a safety net it also ends by itself after
## `max_real_seconds` of REAL time, so a missed clear can't leave the game slow.
func set_slow_motion(time_scale: float, max_real_seconds: float) -> void:
	slow_motion_scale = time_scale
	slow_motion_id += 1
	var my_id: int = slow_motion_id
	Engine.time_scale = slow_motion_scale
	# Real-time timer (last argument): it isn't slowed down by the slow motion itself.
	await get_tree().create_timer(max_real_seconds, true, false, true).timeout
	# Only clear if no newer set/clear happened in the meantime.
	if my_id == slow_motion_id:
		clear_slow_motion()


## Back to normal speed. Safe to call when no slow motion is running.
func clear_slow_motion() -> void:
	slow_motion_scale = 1.0
	slow_motion_id += 1
	Engine.time_scale = 1.0


## _process runs every rendered frame. During a freeze this node is paused too
## (it's PAUSABLE), so the shake simply holds and continues afterwards.
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
