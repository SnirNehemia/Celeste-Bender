class_name MovementEffects
extends Node
## Game-feel effects for basic movement (GAME_DESIGN.md §9): squash and stretch
## on jump / wall jump / landing / respawn, and dust puffs at the feet.
##
## A child of the Player (see player.tscn). It has no logic of its own: the Player
## calls on_jumped(), on_wall_jumped(), on_landed() and on_respawned() at the moment
## those things happen, and this node only plays effects. Turning it off (or
## deleting it) changes nothing about how the player moves.
##
## Squash vs. the dash stretch: the body rectangle (Visual) sits under a Node2D
## called SquashPivot whose origin is at the player's FEET. We squash by scaling
## SquashPivot, so the body squashes onto the ground instead of around its middle.
## The dash stretches and rotates Visual itself (AirDashAbility). Two different
## nodes = the two effects multiply together instead of overwriting each other.
##
## All amounts live in PlayerTuning ("Feel: squash & dust" group).

## Dust color: a pale warm gray, readable on the dark background and the dark-gray
## ground, and clearly not the cyan of air effects.
const DUST_COLOR: Color = Color(0.78, 0.75, 0.7, 0.9)

## The Player, set in _ready (we're its direct child).
var player: Player
## The node we scale. Its origin is at the feet (see header).
var squash_pivot: Node2D
## The tween easing the body back to normal size. Kept so a new squash can cancel
## the old one instead of both fighting over the scale.
var squash_tween: Tween


func _ready() -> void:
	player = get_parent() as Player
	squash_pivot = player.get_node("SquashPivot") as Node2D


## A ground jump just started: stretch tall and thin, kick a little dust.
func on_jumped() -> void:
	play_squash(player.tuning.jump_squash)
	_spawn_dust(player.global_position, Vector2.UP, 70.0, player.tuning.jump_dust_count, 15.0, 35.0)
	FX.play_sfx(&"jump")


## A wall jump just started off a wall on side `wall_direction` (-1 left, +1 right):
## stretch, and puff dust off the wall, blowing away from it.
func on_wall_jumped(wall_direction: float) -> void:
	play_squash(player.tuning.jump_squash)
	# The wall's surface: the edge of the 8 px wide body on the wall's side.
	var wall_contact: Vector2 = player.get_center() + Vector2(wall_direction * 4.0, 0.0)
	_spawn_dust(wall_contact, Vector2(-wall_direction, 0.0), 50.0, player.tuning.jump_dust_count, 20.0, 45.0)
	FX.play_sfx(&"wall_jump")


## Touched the ground after being airborne, falling at `impact_speed` px/s.
## Soft landings (a tiny hop, stepping off a slope) get nothing, so the effect
## means "that was a real fall". Harder landings squash more, up to the max.
func on_landed(impact_speed: float) -> void:
	var tuning: PlayerTuning = player.tuning
	if impact_speed < tuning.land_effect_min_speed:
		return
	# inverse_lerp maps min..full speed to 0..1 (clamped), so the squash grows with the fall.
	var hardness: float = clampf(inverse_lerp(tuning.land_effect_min_speed,
		tuning.land_squash_full_speed, impact_speed), 0.0, 1.0)
	# lerp from no squash (1,1) toward the full landing squash.
	play_squash(Vector2.ONE.lerp(tuning.land_squash, hardness))
	# Two puffs rolling out sideways along the floor, more dust for harder landings.
	var dust_count: int = maxi(2, roundi(tuning.land_dust_count * (0.5 + 0.5 * hardness)))
	for side: float in [-1.0, 1.0]:
		_spawn_dust(player.global_position, Vector2(side, -0.15), 20.0, dust_count, 20.0, 50.0)
	FX.play_sfx(&"land")


## Just reappeared at the spawn point: a quick "pop" into existence.
func on_respawned() -> void:
	play_squash(player.tuning.respawn_squash)
	FX.play_sfx(&"respawn")


## Sets the body to `squash_scale` (x = width, y = height factor) right now, then
## eases it back to normal over tuning.squash_recover_time. Public so other code
## (e.g. future abilities) can squash the body too.
func play_squash(squash_scale: Vector2) -> void:
	if squash_tween != null:
		squash_tween.kill()
	squash_pivot.scale = squash_scale
	# create_tween() makes a Tween owned by this node: it animates a property over
	# time. TRANS_BACK + EASE_OUT overshoots a little past 1.0 before settling, which
	# reads as a springy body rather than a rubber sheet.
	squash_tween = create_tween()
	squash_tween.tween_property(squash_pivot, "scale", Vector2.ONE, player.tuning.squash_recover_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Holds the body at `squash_scale` until release_squash() (no easing back). Used for
## stances, like the crouch while earth bending.
func hold_squash(squash_scale: Vector2) -> void:
	if squash_tween != null:
		squash_tween.kill()
	squash_pivot.scale = squash_scale


## Ends a hold_squash(): springs back to normal from wherever the body is now.
func release_squash() -> void:
	play_squash(squash_pivot.scale)


## One-shot puff of `particle_count` dust specks at `world_position`, flying along
## `direction` within ±`spread_degrees`. Added to the world (the player's parent),
## not the player, so the dust stays where it was kicked up.
func _spawn_dust(world_position: Vector2, direction: Vector2, spread_degrees: float,
		particle_count: int, speed_min: float, speed_max: float) -> void:
	var dust: CPUParticles2D = CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 1.0  # all specks at once
	dust.amount = particle_count
	dust.lifetime = 0.3
	dust.direction = direction
	dust.spread = spread_degrees
	# A slight upward pull: dust drifts up and hangs instead of falling like gravel.
	dust.gravity = Vector2(0.0, -15.0)
	dust.initial_velocity_min = speed_min
	dust.initial_velocity_max = speed_max
	# Damping slows the specks quickly, so they puff out and stop.
	dust.damping_min = 80.0
	dust.damping_max = 140.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	dust.color = DUST_COLOR
	player.get_parent().add_child(dust)
	dust.global_position = world_position
	dust.emitting = true
	# Free it once every speck has faded. Game-time timer (process_always = false),
	# so a freeze frame doesn't cut the puff short.
	get_tree().create_timer(dust.lifetime + 0.1, false).timeout.connect(dust.queue_free)
