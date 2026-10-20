extends Node
## FX: global "game feel" helpers — screen shake, freeze frames, screen flash,
## menu pausing and the (silent for now) sound hook.
##
## AUTOLOAD (registered in project.godot as `FX`), so any script can call
##   FX.shake(2.0, 0.12)     — jiggle the camera for a moment
##   FX.freeze(0.05)         — pause the whole game for a few frames ("hit stop")
##   FX.set_slow_motion(0.25, 0.5) / FX.clear_slow_motion() — slow the game down
##   FX.flash_screen(Color.WHITE, 0.15) — full-screen flash that fades out
##   FX.set_menu_pause(true)  — pause for a menu (pause menu, F2 room picker)
##   FX.play_sfx(&"jump")     — the one place sounds will be played (Milestone 2)
##   FX.spawn_gravel(pos, 6, Vector2.UP) — earth bits that pop out and fall (Earth chapter),
##                                         leaving a few pebbles on the ground
## without needing a reference to the camera or the scene tree.
##
## Who calls it: AirDashAbility, GustAbility, the GustAim state (slow motion);
## enemy hits and death later.
##
## Freeze PAUSES the scene tree (get_tree().paused); slow motion uses
## Engine.time_scale. They're separate switches, so they never fight.
## Menus pause the tree too, so pausing goes through this node: it remembers WHY
## the tree is paused (a freeze, a menu, or both) and only unpauses when neither
## wants it. Otherwise a freeze ending while the pause menu is open would unpause it.
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
## True while a menu (pause menu, room picker) has the game paused.
var is_menu_open: bool = false
## The game speed when not frozen: 1.0 normally, lower during slow motion.
var slow_motion_scale: float = 1.0
## Bumped on every set/clear, so an old safety timer can tell it's out of date.
var slow_motion_id: int = 0
## Debug: print every play_sfx() call as "[SFX] name", to check the hooks fire.
var log_sfx_calls: bool = false

## Full-screen rectangle used by flash_screen(), on its own CanvasLayer so it
## covers the game but ignores the camera. Built in _ready().
var flash_rect: ColorRect
var flash_tween: Tween

## How long a gravel bit lives, seconds.
const GRAVEL_LIFETIME: float = 0.45
## Gradients for spawn_gravel(), built once in _ready() and shared by every burst.
var gravel_color_gradient: Gradient
var gravel_fade_gradient: Gradient


func _ready() -> void:
	# A CanvasLayer draws its children fixed on screen, above the game world.
	# Layer 10: above the game, below the end screen (15) and room picker (20).
	var flash_layer: CanvasLayer = CanvasLayer.new()
	flash_layer.layer = 10
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# MOUSE_FILTER_IGNORE: an invisible full-screen Control would otherwise eat clicks.
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_layer.add_child(flash_rect)

	# A Gradient maps 0..1 to colors. Two points: fresh earth -> a darker brown.
	gravel_color_gradient = Gradient.new()
	gravel_color_gradient.set_color(0, EarthLayer.FRESH_COLOR)
	gravel_color_gradient.set_color(1, EarthLayer.FRESH_COLOR.lerp(EarthLayer.USED_COLOR, 0.6))
	# White (no tint) staying opaque for 60% of the life, then fading out.
	gravel_fade_gradient = Gradient.new()
	gravel_fade_gradient.set_color(0, Color.WHITE)
	gravel_fade_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gravel_fade_gradient.add_point(0.6, Color.WHITE)


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
	is_frozen = false
	# A menu opened during the freeze keeps the game paused.
	get_tree().paused = is_menu_open


## Pauses (true) or resumes (false) the game for a menu. Menus call this instead
## of setting get_tree().paused themselves (see the header for why).
func set_menu_pause(open: bool) -> void:
	is_menu_open = open
	get_tree().paused = is_menu_open or is_frozen


## Covers the screen with `color` and fades it to transparent over `duration`
## seconds (game time). Only `color`'s alpha at the start matters for strength.
func flash_screen(color: Color, duration: float) -> void:
	if duration <= 0.0:
		return
	if flash_tween != null:
		flash_tween.kill()
	flash_rect.color = color
	flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "color:a", 0.0, duration)


## Gravel (Earth_bending.md §8): `amount` tiny earth-colored squares (1-2 px) pop out
## of `world_position` toward `direction` (±40°), fall under gravity and fade out.
## The ONE helper every earth effect uses: bend start, shadow trail, eruptions,
## impacts. `direction` = ZERO sprays all around. Added to the current scene (the
## world), so the bits stay where they were made.
## They run on game time, so during a bend's slow motion they drift slowly too.
## The gravel fades, but some pebbles STAY (Stage E4d): the room's PebbleField adds
## about amount × EarthTuning.pebbles_per_gravel × `pebble_fraction` of them.
## Pass a smaller fraction (or 0) for effects that fire very often.
func spawn_gravel(world_position: Vector2, amount: int, direction: Vector2,
		pebble_fraction: float = 1.0) -> void:
	var world: Node = get_tree().current_scene
	if world == null or amount <= 0:
		return
	if pebble_fraction > 0.0:
		PebbleField.leave_pebbles(get_tree(), world_position, amount, direction, pebble_fraction)
	var gravel: CPUParticles2D = CPUParticles2D.new()
	gravel.one_shot = true
	gravel.explosiveness = 1.0  # all bits at once
	gravel.amount = amount
	gravel.lifetime = GRAVEL_LIFETIME
	gravel.direction = direction if direction != Vector2.ZERO else Vector2.UP
	gravel.spread = 40.0 if direction != Vector2.ZERO else 180.0
	gravel.gravity = Vector2(0.0, 420.0)  # heavier than dust: gravel drops
	gravel.initial_velocity_min = 25.0
	gravel.initial_velocity_max = 70.0
	gravel.scale_amount_min = 1.0
	gravel.scale_amount_max = 2.0
	# color_initial_ramp: each bit picks a random color along this gradient (fresh
	# earth to a darker brown), so the gravel isn't one flat color.
	gravel.color_initial_ramp = gravel_color_gradient
	# color_ramp: color over each bit's life; here only alpha, fading 1 -> 0 at the end.
	gravel.color_ramp = gravel_fade_gradient
	gravel.z_index = 5  # in front of tiles and objects
	world.add_child(gravel)
	gravel.global_position = world_position
	gravel.emitting = true
	# Game-time timer (process_always = false): a pause doesn't free it mid-fall.
	get_tree().create_timer(GRAVEL_LIFETIME + 0.1, false).timeout.connect(gravel.queue_free)


## THE sound hook (GAME_DESIGN.md §9): every game event that will make a sound
## calls this with a short name. Sound is out of scope for Milestone 1, so it does
## nothing yet; adding audio later means filling in only this function (e.g. look
## up an AudioStream by name and play it on a pooled AudioStreamPlayer).
## Names used so far: jump, wall_jump, land, dash, gust, death, respawn, crystal,
## wisp_defeated, sentry_destroyed, orb_reflected, goal, pause, unpause.
func play_sfx(sound_name: StringName) -> void:
	if log_sfx_calls:
		print("[SFX] %s" % sound_name)


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
