extends PlayerState
## BoulderHold: rooted while the rock we just tore out rumbles out and hops, waiting
## for the throw (Earth_bending.md §6, §11, Stages E4 + E4a).
##
## Entered from Idle, Run or WallSlide when player.try_tear_rock() tore a rock out
## (S pressed on earth). The world runs in slow motion (boulder_time_scale) from the
## tear until the throw, for at most boulder_slow_motion_max_time real seconds. The
## rock moves in game time, so its perfect window stretches with the slow motion.
## While here the player doesn't move (rooted, on the floor or on a wall) and the
## arrows only aim. Holding S from the tear until the rock is out of its hole grows it
## into a big rock (BoulderAbility, Stage E4c2). Ways out:
##   - S pressed again -> BoulderAbility.throw(), away from the player
##     (BoulderAbility.get_throw_direction: the arrows, 8 directions, or toward the
##     rock's side with none; never into the wall you're on). In HOVER AIM mode the
##     arrows aim while the rock hovers and the throw goes the way last aimed
##     (BoulderAbility.update_hover_aim / get_chosen_throw_direction).
##   - the rock can't be thrown any more (it settled loose, or boulder_hold_time ran
##     out) -> just leave
##   - Jump -> let go: the rock lies loose once it lands, and the press is spent (no
##     jump), like cancelling a bend
##   - death (Dead state) -> exit() lets go too


func enter() -> void:
	player.velocity = Vector2.ZERO
	# Keep the bending crouch while holding the boulder up.
	player.movement_effects.hold_squash(player.earth_tuning.bend_squash)
	# Slow motion until the throw. FX ends it by itself after the real-time limit
	# (its safety timer), and exit() ends it at once on the throw. A HOVERING rock gets
	# its own, slower speed (you aim and time it), and the limit is its whole hold time
	# in real seconds, so the slow motion lasts as long as the rock can be thrown.
	var tuning: EarthTuning = player.earth_tuning
	if player.boulder.is_hover_aiming():
		var hover_scale: float = maxf(tuning.boulder_hover_time_scale, 0.05)
		FX.set_slow_motion(hover_scale, tuning.boulder_hover_hold_time / hover_scale + 0.2)
	else:
		FX.set_slow_motion(tuning.boulder_time_scale, tuning.boulder_slow_motion_max_time)


func exit() -> void:
	player.movement_effects.release_squash()
	FX.clear_slow_motion()
	# Any way out without a throw (death, a respawn) drops the boulder.
	player.boulder.let_go()


func physics_update(_delta: float) -> void:
	var boulder: BoulderAbility = player.boulder
	# Rooted: hold perfectly still, on the floor or on the wall.
	player.velocity = Vector2.ZERO
	if not boulder.is_holding():
		_leave()
		return
	# Big rock (Stage E4c2): S held since the tear keeps the charge going; the moment
	# it's up, the rock stays small.
	if not Input.is_action_pressed(boulder.get_action()):
		boulder.stop_charging()
	# Hover aim: the arrows aim the hovering rock (the forgiving read keeps diagonals
	# when one of their two keys comes up a moment early, like the gust's aim).
	if boulder.is_hover_aiming():
		boulder.update_hover_aim(player.get_forgiving_aim_input())
	# Jump lets go. jump_buffer_remaining is set the frame Jump is pressed.
	if player.jump_buffer_remaining > 0.0:
		player.consume_jump_press()
		boulder.let_go()
		_leave()
		return
	# The press that tore the rock out was on an earlier frame (before enter()).
	# In slow motion physics still ticks at its normal rate (only each tick's delta is
	# scaled), so is_action_just_pressed doesn't miss presses.
	if Input.is_action_just_pressed(boulder.get_action()):
		boulder.throw(boulder.get_chosen_throw_direction())
		_leave()


## Back to normal movement: Idle on the floor, Fall otherwise.
func _leave() -> void:
	transition_requested.emit(&"Idle" if player.is_on_floor() else &"Fall")
