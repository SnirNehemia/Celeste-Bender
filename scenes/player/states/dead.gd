extends PlayerState
## Dead: the player has been killed. Shows the death effect and does nothing else.
##
## Entered via player.die() (never by another state). Left via player.respawn_at(),
## which RoomManager calls after tuning.death_respawn_delay seconds.

func enter() -> void:
	player.velocity = Vector2.ZERO
	player.set_body_hidden(true)
	# restart() plays the one-shot particle burst from the beginning.
	player.death_burst.restart()


func exit() -> void:
	player.set_body_hidden(false)


func physics_update(_delta: float) -> void:
	# Stay frozen in place, ignore all input. Velocity stays zero, so
	# move_and_slide() in Player doesn't move us.
	pass
