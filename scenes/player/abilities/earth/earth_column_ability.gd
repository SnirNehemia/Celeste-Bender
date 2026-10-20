class_name EarthColumnAbility
extends EarthMoveAbility
## Earth Column, move 1 of Earth (Earth_bending.md §5, Stage E3). Lives under the
## player:  Player > EarthColumnAbility
##
## Flow: hold A on fresh earth -> EarthBend state + shadow (EarthBendAbility) ->
## release A -> EarthBendAbility.release_bend() calls erupt() here with the face
## under the shadow -> a column (EarthColumn) rises out of it.
## A quick tap (release before the shadow starts crawling) erupts right under the
## player's feet: the column throws you up, the super jump.
##
## This component only starts columns. The column itself (rising, pushing, launching
## things, being a platform) is scenes/objects/earth/earth_column.gd, and the
## player's flight after a launch is the Launched state.


func get_bend_action() -> StringName:
	return &"earth_column"


## Spends the tile and raises a column out of `face`, with a burst of gravel and
## a small shake (Earth_bending.md §8: "at the target").
func erupt(face: EarthFace) -> void:
	var tuning: EarthTuning = player.earth_tuning
	face.layer.mark_used(face.cell)
	var column: EarthColumn = EarthColumn.new()
	column.setup(face, tuning)
	# A child of the ROOM (the earth layer's parent), not of the player: it stays in
	# the world, and the room's reset removes it.
	face.layer.get_parent().add_child(column)
	# Pebble fraction 0: the pebbles go by the ground used (one tile), just below.
	FX.spawn_gravel(face.get_global_center(), tuning.eruption_gravel_count, Vector2(face.normal), 0.0)
	PebbleField.leave_pebbles_for_tiles(get_tree(), face.get_global_center(), 1, Vector2(face.normal))
	FX.shake(tuning.eruption_shake_strength, tuning.eruption_shake_time)
	FX.play_sfx(&"earth_column")
