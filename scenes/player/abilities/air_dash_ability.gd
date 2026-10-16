class_name AirDashAbility
extends Node
## Air Dash component (GAME_DESIGN.md §5.1). Lives as a child of the Player:
##   Player > AirDashAbility
##
## Responsibilities (and only these):
##   - the dash CHARGES: how many dashes are left, refilling on the ground
##   - the aim direction (8 directions from the held arrows, default = facing)
##   - the dash's look and juice. It should read as AIR BENDING, not a plain dash:
##       start:  freeze frames + shake (FX autoload), a burst of air pushed BACKWARD
##               (the player shoves the air to launch) and a shockwave ring
##       during: the body stretches along the dash and turns translucent ("becomes
##               air"), leaving curved wind streaks behind
##       end:    a soft puff of air; the body eases back to its normal shape
##   - tinting the player pale blue when out of dashes
##
## The dash MOVEMENT is the `Dash` state (states/dash.gd): states own movement,
## abilities own resources and effects. The Dash state calls the begin/trail/end
## functions below at the right moments. Wind crystals call refill().
##
## Shared stamina mode (tuning.dash_uses_stamina): charges are ignored and a dash
## spends GlideAbility stamina instead (tuning.dash_stamina_cost). can_dash() and
## refill() hide the difference, so the states and wind crystals don't care which
## mode is on.
##
## All effects are built in code from placeholder shapes (Line2D, CPUParticles2D),
## per CLAUDE.md. Effects are added to the player's PARENT (the world) so they stay
## where they were made while the player moves on.

## Emitted when the number of dashes left changes (for a future HUD).
signal charges_changed(dashes_remaining: int)

## Player tint with dashes available / out of dashes (GAME_DESIGN.md §2).
const READY_COLOR: Color = Color(1, 1, 1)
const EMPTY_COLOR: Color = Color(0.6, 0.8, 1.0)
## Color of all air effects: very pale cyan-white.
const AIR_COLOR: Color = Color(0.85, 0.95, 1.0, 0.8)
## How long the body takes to ease back to normal after a dash, seconds.
const BODY_RESTORE_TIME: float = 0.08

## Dashes left this airtime.
var dashes_remaining: int = 1
## The player this ability belongs to. The parent node, set in _ready().
var player: Player
## Flips every streak so streaks alternate sides of the path, like a spiral.
var next_streak_side: float = 1.0
## The tween easing the body back to normal; killed if a new dash starts meanwhile.
var body_restore_tween: Tween


func _ready() -> void:
	player = get_parent() as Player
	dashes_remaining = player.tuning.max_dash_charges


## Runs every physics frame. Children run AFTER their parent in the tree, so this
## sees is_on_floor() from the move_and_slide() the player just did this frame.
func _physics_process(_delta: float) -> void:
	# Ground refill, but not mid-dash: a dash along the floor refills when it ENDS,
	# otherwise you'd get your dash back the instant you used it.
	if player.is_on_floor() and not player.is_dashing():
		refill()
	_update_tint()


# --- Charges ---------------------------------------------------------------

func can_dash() -> bool:
	if player.tuning.dash_uses_stamina:
		return player.glide.stamina_remaining >= player.tuning.dash_stamina_cost
	return dashes_remaining > 0


## How many dashes could be done right now (for the debug overlay).
func get_dashes_available() -> int:
	if player.tuning.dash_uses_stamina:
		return floori(player.glide.stamina_remaining / player.tuning.dash_stamina_cost)
	return dashes_remaining


## Restores all charges. Returns true if anything was actually restored, so a
## wind crystal only gets used up when you needed it.
## In shared stamina mode this refills the stamina bar instead.
func refill() -> bool:
	if player.tuning.dash_uses_stamina:
		var stamina_restored: bool = player.glide.refill()
		_update_tint()
		return stamina_restored
	if dashes_remaining >= player.tuning.max_dash_charges:
		return false
	dashes_remaining = player.tuning.max_dash_charges
	charges_changed.emit(dashes_remaining)
	_update_tint()
	return true


## The 8-way aim from the held arrows, as a unit vector. With nothing held, dash
## the way the player faces. normalized() makes diagonals the same speed as
## straight dashes (otherwise (1,1) would be ~1.41x faster).
func get_aim_direction() -> Vector2:
	var aim: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	if aim == Vector2.ZERO:
		return Vector2(player.facing_direction, 0.0)
	return aim.normalized()


# --- Dash lifecycle (called by the Dash state) -----------------------------

## Spends a charge and plays all dash-start effects for a dash toward `direction`.
func begin_dash(direction: Vector2) -> void:
	if player.tuning.dash_uses_stamina:
		player.glide.spend(player.tuning.dash_stamina_cost)
	else:
		dashes_remaining -= 1
		charges_changed.emit(dashes_remaining)
	_update_tint()

	var tuning: PlayerTuning = player.tuning
	FX.shake(tuning.dash_shake_strength, tuning.dash_shake_duration)
	FX.freeze(tuning.dash_freeze_time)

	# Air shoved backward: the reaction that launches us forward.
	_spawn_air_burst(player.get_center(), -direction, 35.0, 14, 50.0, 110.0)
	_spawn_ring(player.get_center(), 3.0, 12.0, 0.2)
	_stretch_body(direction)


## One curved wind streak at the player's current position (called every
## dash_trail_interval seconds during the dash).
func spawn_trail_streak(direction: Vector2) -> void:
	var tuning: PlayerTuning = player.tuning
	# `side` is perpendicular to the dash; streaks alternate left/right of the path.
	var side: Vector2 = direction.orthogonal() * next_streak_side
	next_streak_side = -next_streak_side

	# A small arc: starts on the path, bows out to one side, comes back — like a
	# curl of wind wrapping around the body. Points are relative to the streak node.
	var streak: Line2D = Line2D.new()
	streak.width = 1.0
	streak.default_color = AIR_COLOR
	streak.points = PackedVector2Array([
		-direction * 6.0,
		-direction * 3.0 + side * 2.5,
		side * 3.5,
		direction * 3.0 + side * 2.0,
	])
	_add_effect(streak, player.get_center())

	# Fade out while drifting a little backward and curling outward.
	var fade_tween: Tween = streak.create_tween().set_parallel(true)
	fade_tween.tween_property(streak, "modulate:a", 0.0, tuning.dash_trail_lifetime)
	fade_tween.tween_property(streak, "position",
		streak.position - direction * 4.0 + side * 2.0, tuning.dash_trail_lifetime)
	# chain() makes the next step wait for the parallel ones above.
	fade_tween.chain().tween_callback(streak.queue_free)


## The dash finished normally: a soft puff of air where it stopped.
func finish_dash(direction: Vector2) -> void:
	_spawn_air_burst(player.get_center(), direction, 180.0, 8, 15.0, 35.0)


## Ease the body back to normal. Called from Dash.exit(), so it also runs if the
## dash is cut short (death).
func restore_body() -> void:
	if body_restore_tween != null:
		body_restore_tween.kill()
	body_restore_tween = player.visual.create_tween().set_parallel(true)
	body_restore_tween.tween_property(player.visual, "scale", Vector2.ONE, BODY_RESTORE_TIME)
	body_restore_tween.tween_property(player.visual, "modulate:a", 1.0, BODY_RESTORE_TIME)
	# Rotation snaps back (a spin animation from e.g. 135° would look odd).
	player.visual.rotation = 0.0


# --- Effect builders --------------------------------------------------------

## Stretches the player's rectangle along `direction` and makes it translucent.
## The visual is a ColorRect (a Control): it scales and rotates around
## `pivot_offset`, so we put that at its center.
func _stretch_body(direction: Vector2) -> void:
	if body_restore_tween != null:
		body_restore_tween.kill()
	var visual: ColorRect = player.visual
	visual.pivot_offset = visual.size / 2.0
	# Rotate so the rectangle's local x axis points along the dash, then stretch x.
	visual.rotation = direction.angle()
	visual.scale = player.tuning.dash_stretch
	visual.modulate.a = player.tuning.dash_body_opacity


## One-shot burst of small air particles at `world_position`, flying along
## `direction` within ±`spread_degrees`. CPUParticles2D simulates particles on the
## CPU; one_shot + explosiveness 1 = emit them all at once, then stop.
func _spawn_air_burst(world_position: Vector2, direction: Vector2, spread_degrees: float,
		particle_count: int, speed_min: float, speed_max: float) -> void:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = particle_count
	burst.lifetime = 0.3
	burst.direction = direction
	burst.spread = spread_degrees
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = speed_min
	burst.initial_velocity_max = speed_max
	# Damping slows particles down so they "puff" out and hang, like air, not sparks.
	burst.damping_min = 150.0
	burst.damping_max = 250.0
	# Tangential acceleration curls each particle sideways: a swirl, not straight lines.
	burst.tangential_accel_min = -120.0
	burst.tangential_accel_max = 120.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color = AIR_COLOR
	_add_effect(burst, world_position)
	burst.emitting = true
	# Free it once every particle has died. The timer uses game time, so freeze
	# frames don't cut the effect short.
	get_tree().create_timer(burst.lifetime + 0.1, false).timeout.connect(burst.queue_free)


## An expanding, fading circle outline: a small shockwave.
func _spawn_ring(world_position: Vector2, start_radius: float, end_radius: float,
		duration: float) -> void:
	var ring: Line2D = Line2D.new()
	ring.width = 1.0
	ring.default_color = AIR_COLOR
	ring.closed = true
	# A circle of radius 1; growing it is just scaling the node.
	var circle_points: PackedVector2Array = PackedVector2Array()
	const SEGMENTS: int = 12
	for point_index: int in SEGMENTS:
		circle_points.append(Vector2.from_angle(TAU * point_index / SEGMENTS))
	ring.points = circle_points
	ring.scale = Vector2.ONE * start_radius
	# Line2D width is scaled too; divide so the outline stays ~1 px thick.
	ring.width = 1.0 / start_radius
	_add_effect(ring, world_position)

	var grow_tween: Tween = ring.create_tween().set_parallel(true)
	grow_tween.tween_property(ring, "scale", Vector2.ONE * end_radius, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow_tween.tween_property(ring, "width", 1.0 / end_radius, duration)
	grow_tween.tween_property(ring, "modulate:a", 0.0, duration)
	grow_tween.chain().tween_callback(ring.queue_free)


## Adds an effect node to the world (the player's parent) at `world_position`.
func _add_effect(effect: Node2D, world_position: Vector2) -> void:
	player.get_parent().add_child(effect)
	effect.global_position = world_position


func _update_tint() -> void:
	player.visual.color = READY_COLOR if can_dash() else EMPTY_COLOR
