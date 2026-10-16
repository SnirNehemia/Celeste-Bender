extends PlayerState
## Glide: falling slowly while holding jump (GAME_DESIGN.md §5.2).
##
## Entered from Fall when jump is PRESSED again in the air (not just held from the
## jump: that keeps the Stage 2 jump feel untouched) and stamina is left.
## Leaves when you release jump, run out of stamina, land, dash, wall-slide or wall-jump.
##
## Movement: horizontal control is the normal air control (wind included); vertical
## speed blends toward GlideAbility.get_target_vertical_speed(): a slow 30 px/s fall,
## or a rise inside an updraft. The GlideAbility component owns stamina and effects.


func enter() -> void:
	player.glide.begin_glide()


func exit() -> void:
	player.glide.end_glide()


func physics_update(delta: float) -> void:
	# Dash beats everything else this frame (Dash.enter() sets the velocity).
	if player.wants_to_dash():
		transition_requested.emit(&"Dash")
		return
	player.apply_horizontal_movement(delta)

	# move_toward eases toward the target instead of snapping, so a fast fall is
	# "caught" over a few frames (900 px/s² stops a 300 px/s fall in ~0.3 s).
	player.velocity.y = move_toward(player.velocity.y,
		player.glide.get_target_vertical_speed(),
		player.tuning.glide_vertical_acceleration * delta)

	player.glide.drain(delta)
	player.glide.update_glide_effects(delta)

	if player.can_wall_jump():
		player.start_wall_jump(player.get_wall_direction())
		transition_requested.emit(&"Jump")
	elif player.is_on_floor():
		transition_requested.emit(&"Run" if player.velocity.x != 0.0 else &"Idle")
	elif not Input.is_action_pressed("jump") or not player.glide.can_glide():
		transition_requested.emit(&"Fall")
	elif player.velocity.y > 0.0 and player.is_pressing_into_wall():
		transition_requested.emit(&"WallSlide")
