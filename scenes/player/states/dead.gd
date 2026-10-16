extends PlayerState
## Dead: the player has been killed. Shows the death effect and does nothing else.
##
## Entered via player.die() (never by another state). Left via player.respawn_at(),
## which RoomManager calls after tuning.death_respawn_delay seconds.

func enter() -> void:
	player.velocity = Vector2.ZERO
	player.visual.visible = false
	# restart() plays the one-shot particle burst from the beginning.
	player.death_burst.restart()


func exit() -> void:
	player.visual.visible = true


func physics_update(_delta: float) -> void:
	# Stay frozen in place, ignore all input. Velocity stays zero, so
	# move_and_slide() in Player doesn't move us.
	pass
