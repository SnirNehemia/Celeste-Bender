extends PlayerState
## EarthBend: rooted in the bending stance while the bend shadow picks a target
## (Earth_bending.md §4). Shared by all three earth moves.
##
## Entered from Idle, Run or WallSlide when player.wants_to_bend() (an earth key
## pressed while touching fresh earth). While here:
##   - the world runs at earth_tuning.bend_time_scale (FX slow motion)
##   - the player doesn't move at all (rooted: no gravity, no steering), so bending
##     from a wall holds you on the wall
##   - EarthBendAbility runs the shadow in real time
## Ways out:
##   - the earth key is released, or the aim time (bend_max_time, real seconds;
##     shadow_steer_max_time when you steer the shadow yourself) runs out  -> the move fires at the shadow (release_bend). If the move then
##     asks for a follow-up state (EarthMoveAbility.get_follow_up_state: the snake's
##     SnakeSteer), we go there; otherwise back to normal movement
##   - Jump is pressed -> cancel, no earth used, and the press is spent so it doesn't
##     also jump
##   - death (Dead state) -> exit() cancels
##
## Release is checked with is_action_pressed (not just_released) for the same reason
## as GustAim: in slow motion physics ticks are rare, and the held state can't miss
## a release that happened between two ticks.

func enter() -> void:
	var earth_bend: EarthBendAbility = player.earth_bend
	# Found by player.wants_to_bend() in the previous state (Idle/Run/WallSlide).
	var start_face: EarthFace = earth_bend.queued_start_face
	var action: StringName = earth_bend.queued_action
	if start_face == null or action == &"":
		# Shouldn't happen (wants_to_bend just queued both), but never get stuck
		# rooted with no bend running.
		transition_requested.emit(&"Fall")
		return
	player.velocity = Vector2.ZERO
	var tuning: EarthTuning = player.earth_tuning
	# Safety limit a little past our own, like GustAim: we clear it ourselves in exit().
	FX.set_slow_motion(tuning.bend_time_scale, earth_bend.get_max_bend_time() + 0.3)
	earth_bend.begin_bend(action, start_face)


func exit() -> void:
	# Runs on every way out, including death, so slow motion never sticks.
	FX.clear_slow_motion()
	player.earth_bend.cancel_bend()


func physics_update(_delta: float) -> void:
	var earth_bend: EarthBendAbility = player.earth_bend
	if not earth_bend.is_bending:
		_leave()
		return
	# Rooted: hold perfectly still, on the floor or on the wall.
	player.velocity = Vector2.ZERO

	# Jump cancels. jump_buffer_remaining is set the frame Jump is pressed.
	if player.jump_buffer_remaining > 0.0:
		player.consume_jump_press()
		earth_bend.cancel_bend()
		_leave()
		return

	var time_is_up: bool = earth_bend.bend_real_time >= earth_bend.get_max_bend_time()
	if not Input.is_action_pressed(earth_bend.bend_action) or time_is_up:
		earth_bend.release_bend()
		# Some moves keep the player busy afterwards (the snake: steering it). Asked of
		# the move that actually fired (in the one-key experiment A can fire a snake).
		var move: EarthMoveAbility = earth_bend.fired_move
		var follow_up_state: StringName = move.get_follow_up_state() if move != null else &""
		if follow_up_state != &"":
			transition_requested.emit(follow_up_state)
		else:
			_leave()


## Back to normal movement: Idle on the floor, Fall otherwise (Fall turns into
## WallSlide by itself if you're still holding into the wall).
func _leave() -> void:
	transition_requested.emit(&"Idle" if player.is_on_floor() else &"Fall")
