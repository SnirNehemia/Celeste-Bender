extends PlayerState
## SnakeSteer: rooted while steering the Earth Snake (Earth_bending.md §7, §11, Stage E5).
##
## Entered from EarthBend right after a long A bend was released and a snake came out
## (EarthMoveAbility.get_follow_up_state). While here:
##   - the world runs in slow motion at snake_time_scale (0.2x, a bit slower than
##     the bend's 0.3x), for at most snake_max_time real seconds (the snake hardens
##     by itself by then)
##   - the player doesn't move at all (rooted, on the floor or on a wall)
##   - the arrows steer the snake's head (4 directions): a newly pressed arrow turns
##     it at the next tile; holding a single arrow keeps asking for that direction
## Ways out:
##   - A pressed again (the key that brought it out) -> the snake hardens
##   - Jump -> the snake hardens too (its earth is already spent, so there's nothing
##     to cancel), and the press is spent so it doesn't also jump
##   - the snake hardened by itself (budget, solid, time) -> just leave
##   - the snake's head ran into us: it throws us off (Launched) or crushes us (Dead)
##   - death (Dead state) -> exit() hardens it (the room reset removes it anyway)

## Arrow actions and the head direction each one asks for.
const STEER_ACTIONS: Dictionary = {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}


func enter() -> void:
	player.velocity = Vector2.ZERO
	var tuning: EarthTuning = player.earth_tuning
	# Keep the bending crouch while steering.
	player.movement_effects.hold_squash(tuning.bend_squash)
	# EarthBend.exit() just cleared the bend's slow motion: start the (slower) steering
	# one. The safety limit is a little past the snake's own time limit, like EarthBend's.
	FX.set_slow_motion(tuning.snake_time_scale, tuning.snake_max_time + 0.3)


func exit() -> void:
	# Runs on every way out, including death, so slow motion never sticks.
	player.movement_effects.release_squash()
	FX.clear_slow_motion()
	player.earth_snake.harden_active("key")


func physics_update(_delta: float) -> void:
	var snake_ability: EarthSnakeAbility = player.earth_snake
	# Rooted: hold perfectly still, on the floor or on the wall.
	player.velocity = Vector2.ZERO
	if not snake_ability.is_steering():
		_leave()
		return
	# Jump hardens. jump_buffer_remaining is set the frame Jump is pressed.
	if player.jump_buffer_remaining > 0.0:
		player.consume_jump_press()
		snake_ability.harden_active("key")
		_leave()
		return
	# A again hardens. The release that brought the snake out was a release, so the
	# next just-pressed A is a new press.
	if Input.is_action_just_pressed(player.earth_column.get_bend_action()):
		snake_ability.harden_active("key")
		_leave()
		return
	_steer(snake_ability)


## A newly pressed arrow turns the head; otherwise a single held arrow keeps asking
## for its direction (so an arrow held since before the snake came out still counts).
func _steer(snake_ability: EarthSnakeAbility) -> void:
	var held_directions: Array[Vector2i] = []
	for action: StringName in STEER_ACTIONS:
		if Input.is_action_just_pressed(action):
			snake_ability.queue_turn(STEER_ACTIONS[action])
			return
		if Input.is_action_pressed(action):
			held_directions.append(STEER_ACTIONS[action])
	if held_directions.size() == 1:
		snake_ability.queue_turn(held_directions[0])


## Back to normal movement: Idle on the floor, Fall otherwise (Fall turns into
## WallSlide by itself if you're still holding into the wall).
func _leave() -> void:
	transition_requested.emit(&"Idle" if player.is_on_floor() else &"Fall")
