class_name GlideAbility
extends Node2D
## Glide component (GAME_DESIGN.md §5.2). Lives as a child of the Player:
##   Player > GlideAbility
##
## Responsibilities (and only these):
##   - glide STAMINA: seconds of gliding left this airtime, refilled on the ground.
##     With tuning.dash_uses_stamina on, the dash spends it too (see AirDashAbility):
##     one shared "breath" bar, with a notch marking the dash cost.
##   - the small stamina bar above the player's head (drawn by this node)
##   - the glide's look. It should read as AIR BENDING: the player pushes air DOWN
##     to hold themself up:
##       start:  a puff of air shoved downward
##       during: a steady jet of air particles under the feet, plus curved "cupped"
##               gust arcs that peel off downward
##   - the vertical speed the glide aims for (normal glide, or lift in an updraft)
##
## The glide MOVEMENT is the `Glide` state (states/glide.gd), same split as the dash:
## states own movement, abilities own resources and effects.
##
## Why a Node2D and not a plain Node (like AirDashAbility)? A Node2D has a position
## and can draw. It sits just above the player's head, so the bar drawn in _draw()
## follows the player for free.

## Color of all air effects (same pale cyan-white as the dash, so they read as one power).
const AIR_COLOR: Color = Color(0.85, 0.95, 1.0, 0.8)
## Stamina bar look: size in px, and colors.
const BAR_SIZE: Vector2 = Vector2(12, 2)
const BAR_BACK_COLOR: Color = Color(0.1, 0.1, 0.15, 0.8)
const BAR_FULL_COLOR: Color = Color(0.6, 0.9, 1.0)
const BAR_LOW_COLOR: Color = Color(1.0, 0.35, 0.3)
## Below this fraction of stamina, the bar blinks as a warning.
const BAR_LOW_FRACTION: float = 0.3
## The dash-cost notch on the bar (shared stamina mode).
const BAR_NOTCH_COLOR: Color = Color(1, 1, 1, 0.9)
## Where the player's feet are, relative to this node (this node sits 15 px above them).
const FEET_OFFSET: Vector2 = Vector2(0, 15)

## Emitted when stamina changes (for a future HUD).
signal stamina_changed(stamina_remaining: float)

## Seconds of glide left this airtime.
var stamina_remaining: float = 0.0
## The player this ability belongs to. The parent node, set in _ready().
var player: Player
## True between begin_glide() and end_glide().
var is_gliding: bool = false
## Counts down to the next gust arc.
var gust_time_remaining: float = 0.0
## Flips every arc so arcs alternate slightly left/right of center.
var next_arc_side: float = 1.0
## Drives the bar's low-stamina blink.
var blink_time: float = 0.0

## Steady jet of air under the feet while gliding (built in _ready()).
var cushion_particles: CPUParticles2D


func _ready() -> void:
	player = get_parent() as Player
	position = -FEET_OFFSET  # above the head (player origin is at the feet)
	stamina_remaining = player.tuning.glide_stamina_time
	_build_cushion_particles()


## Runs every physics frame, after the player's move_and_slide() (children run after
## their parent), so is_on_floor() is up to date.
func _physics_process(delta: float) -> void:
	# Same rule as dash charges: no ground refill mid-dash, otherwise a dash along
	# the floor would cost nothing.
	if player.is_on_floor() and not player.is_dashing():
		refill()
	blink_time += delta
	# queue_redraw() asks Godot to call _draw() again this frame.
	queue_redraw()


# --- Stamina -----------------------------------------------------------------

func can_glide() -> bool:
	return stamina_remaining > 0.0


## Fills the bar. Returns true if anything was restored (a wind crystal is only
## used up if it actually helped).
func refill() -> bool:
	if stamina_remaining >= player.tuning.glide_stamina_time:
		return false
	stamina_remaining = player.tuning.glide_stamina_time
	stamina_changed.emit(stamina_remaining)
	return true


## Spends a lump of stamina at once (used by the dash in shared stamina mode).
func spend(amount: float) -> void:
	stamina_remaining = maxf(stamina_remaining - amount, 0.0)
	stamina_changed.emit(stamina_remaining)


## Spends `delta` seconds of stamina (less inside an updraft, see tuning).
func drain(delta: float) -> void:
	var drain_rate: float = 1.0
	if player.get_wind_velocity().y < 0.0:
		drain_rate = player.tuning.glide_updraft_stamina_drain
	stamina_remaining = maxf(stamina_remaining - delta * drain_rate, 0.0)
	stamina_changed.emit(stamina_remaining)


## The vertical speed the glide steers toward, px/s (positive = down).
## Wind adds to it: an updraft (negative wind.y), scaled up by the lift multiplier,
## overpowers the slow glide fall, so the player rises.
func get_target_vertical_speed() -> float:
	var wind_y: float = player.get_wind_velocity().y
	if wind_y < 0.0:
		wind_y *= player.tuning.glide_updraft_lift_multiplier
	return player.tuning.glide_max_fall_speed + wind_y


# --- Glide lifecycle (called by the Glide state) -----------------------------

func begin_glide() -> void:
	is_gliding = true
	gust_time_remaining = 0.0  # first arc right away
	# The bend: shove a puff of air down. That push is what "catches" the fall.
	_spawn_air_puff(player.global_position, Vector2.DOWN)
	cushion_particles.emitting = true


## Called every frame of the glide: spawns gust arcs on a timer.
func update_glide_effects(delta: float) -> void:
	gust_time_remaining -= delta
	if gust_time_remaining <= 0.0:
		_spawn_gust_arc()
		gust_time_remaining = player.tuning.glide_gust_interval


func end_glide() -> void:
	is_gliding = false
	# Stop emitting; particles already in the air finish their life naturally.
	cushion_particles.emitting = false


# --- Drawing -----------------------------------------------------------------

## _draw() is where a Node2D (or Control) draws itself with draw_* calls. Godot
## caches the result until queue_redraw() is called. Coordinates are local to this node.
func _draw() -> void:
	var max_stamina: float = player.tuning.glide_stamina_time
	var fraction: float = stamina_remaining / max_stamina if max_stamina > 0.0 else 0.0
	# Only show the bar when it says something: while gliding or not yet refilled.
	if fraction >= 1.0 and not is_gliding:
		return
	# Blink when low (on for 0.08 s, off for 0.08 s).
	if fraction < BAR_LOW_FRACTION and fmod(blink_time, 0.16) > 0.08:
		return
	var bar_origin: Vector2 = Vector2(-BAR_SIZE.x / 2.0, 0.0)
	draw_rect(Rect2(bar_origin, BAR_SIZE), BAR_BACK_COLOR)
	var fill_color: Color = BAR_LOW_COLOR.lerp(BAR_FULL_COLOR, fraction)
	draw_rect(Rect2(bar_origin, Vector2(BAR_SIZE.x * fraction, BAR_SIZE.y)), fill_color)
	# Shared stamina: a notch where the dash cost is. Fill right of the notch = you
	# can dash; left of it = glide only. Drawn 1 px taller than the bar to stand out.
	if player.tuning.dash_uses_stamina and max_stamina > 0.0:
		var notch_x: float = bar_origin.x + BAR_SIZE.x * (player.tuning.dash_stamina_cost / max_stamina)
		draw_rect(Rect2(notch_x, -1.0, 1.0, BAR_SIZE.y + 2.0), BAR_NOTCH_COLOR)


# --- Effect builders ----------------------------------------------------------

## The steady downward jet under the feet. local_coords = false means particles,
## once emitted, live in WORLD space: they stay behind as the player drifts on,
## leaving a little wake instead of sliding along glued to the body.
func _build_cushion_particles() -> void:
	cushion_particles = CPUParticles2D.new()
	cushion_particles.position = FEET_OFFSET  # back down at the feet
	cushion_particles.local_coords = false
	cushion_particles.emitting = false
	cushion_particles.amount = 16
	cushion_particles.lifetime = 0.35
	cushion_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cushion_particles.emission_rect_extents = Vector2(4, 1)
	cushion_particles.direction = Vector2.DOWN
	cushion_particles.spread = 35.0
	cushion_particles.gravity = Vector2.ZERO
	cushion_particles.initial_velocity_min = 30.0
	cushion_particles.initial_velocity_max = 60.0
	# Damping makes the air slow and hang (air, not sparks); tangential acceleration
	# curls particles sideways so the jet swirls outward like real displaced air.
	cushion_particles.damping_min = 80.0
	cushion_particles.damping_max = 140.0
	cushion_particles.tangential_accel_min = -100.0
	cushion_particles.tangential_accel_max = 100.0
	cushion_particles.color = AIR_COLOR
	add_child(cushion_particles)


## One cupped arc (a "︶" shape) under the feet that sinks and spreads while fading:
## a visible ring of air being pushed down. Added to the world so it stays behind.
func _spawn_gust_arc() -> void:
	var arc: Line2D = Line2D.new()
	arc.width = 1.0
	arc.default_color = AIR_COLOR
	var half_width: float = 5.0
	arc.points = PackedVector2Array([
		Vector2(-half_width, -1.0),
		Vector2(-half_width * 0.5, 1.0),
		Vector2(0.0, 1.5),
		Vector2(half_width * 0.5, 1.0),
		Vector2(half_width, -1.0),
	])
	var side_offset: Vector2 = Vector2(next_arc_side * 1.5, 2.0)
	next_arc_side = -next_arc_side
	player.get_parent().add_child(arc)
	arc.global_position = player.global_position + side_offset

	var lifetime: float = 0.3
	var arc_tween: Tween = arc.create_tween().set_parallel(true)
	arc_tween.tween_property(arc, "position", arc.position + Vector2(0, 8), lifetime) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	arc_tween.tween_property(arc, "scale", Vector2(1.8, 1.2), lifetime)
	arc_tween.tween_property(arc, "modulate:a", 0.0, lifetime)
	arc_tween.chain().tween_callback(arc.queue_free)


## One-shot burst of air particles flying along `direction` (±50°).
func _spawn_air_puff(world_position: Vector2, direction: Vector2) -> void:
	var puff: CPUParticles2D = CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 10
	puff.lifetime = 0.3
	puff.direction = direction
	puff.spread = 50.0
	puff.gravity = Vector2.ZERO
	puff.initial_velocity_min = 40.0
	puff.initial_velocity_max = 80.0
	puff.damping_min = 150.0
	puff.damping_max = 250.0
	puff.tangential_accel_min = -120.0
	puff.tangential_accel_max = 120.0
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	puff.color = AIR_COLOR
	player.get_parent().add_child(puff)
	puff.global_position = world_position
	puff.emitting = true
	get_tree().create_timer(puff.lifetime + 0.1, false).timeout.connect(puff.queue_free)
