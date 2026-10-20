class_name EarthSnakeAbility
extends EarthMoveAbility
## Earth Snake, move 3 of Earth (Earth_bending.md §7, §11, Stage E5). Lives under the
## player:  Player > EarthSnakeAbility
##
## Flow (ONE KEY, decided after the E5 play-test): hold A on fresh earth -> EarthBend
## state + shadow (EarthBendAbility) -> the shadow crawls off the feet -> release A ->
## EarthBendAbility.release_bend() picks this move (get_release_move) and calls
## erupt() here with the face under the shadow -> a snake (EarthSnake) comes out of
## it -> EarthBend asks get_follow_up_state() and switches to SnakeSteer, where the
## arrows steer it and A (or Jump) hardens it. (A quick tap of A is still a column.)
## The snake has no key of its own: D is free for now.
##
## The BUDGET: the snake may spend the fresh earth connected to the face's tile, up
## to snake_max_tiles, in order outward from that tile (a breadth-first search: the
## tile itself, then its neighbours, then theirs...). So the patch darkens outward
## from the emergence point as the snake grows, and a small patch makes a short snake.
##
## This component only starts snakes and hands steering commands on. The snake itself
## (moving, pushing, hardening, being a platform) is scenes/objects/earth/earth_snake.gd.

## The 4 neighbours of a tile, for the patch search.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

## The snake being steered right now, or null.
var active_snake: EarthSnake = null


## No key of its own (D is free): the snake isn't registered with the bend by key;
## EarthBendAbility.snake_move points here instead.
func get_bend_action() -> StringName:
	return &""


## While a snake is being steered, the player goes to the SnakeSteer state instead of
## back to normal movement.
func get_follow_up_state() -> StringName:
	return &"SnakeSteer" if is_steering() else &""


## True while our snake is still moving (being steered).
func is_steering() -> bool:
	return active_snake != null and is_instance_valid(active_snake) and active_snake.is_moving()


## A snake comes out of `face`. If its first tile isn't free (a quick tap right under
## your own feet: you're standing in it), it fizzles and uses no earth.
func erupt(face: EarthFace) -> void:
	var tuning: EarthTuning = player.earth_tuning
	if not EarthSnake.can_emerge_at(face):
		FX.play_sfx(&"earth_fizzle")
		return
	var snake: EarthSnake = EarthSnake.new()
	snake.setup(face, tuning, collect_patch(face, tuning.snake_max_tiles))
	# A child of the ROOM (the earth layer's parent), not of the player: it stays in
	# the world, and the room's reset removes it.
	face.layer.get_parent().add_child(snake)
	if snake.segment_cells.is_empty():
		# Something unmovable sat in its first tile: nothing came out, no earth used.
		snake.queue_free()
		FX.play_sfx(&"earth_fizzle")
		return
	active_snake = snake
	# Pebble fraction 0: the pebbles go by the ground used, just below (one tile's
	# worth at the emergence point; the head drops more gravel as it grows).
	FX.spawn_gravel(face.get_global_center(), tuning.eruption_gravel_count, Vector2(face.normal), 0.0)
	PebbleField.leave_pebbles_for_tiles(get_tree(), face.get_global_center(), 1, Vector2(face.normal))
	FX.shake(tuning.eruption_shake_strength, tuning.eruption_shake_time)
	FX.play_sfx(&"earth_snake")


## The earth a snake out of `face` may spend: fresh earth tiles connected to the
## face's tile (sharing a side), nearest first, at most `max_tiles`. Public for tests.
func collect_patch(face: EarthFace, max_tiles: int) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	if not face.layer.is_fresh(face.cell):
		return patch
	# Breadth-first search: a queue of tiles to look at, oldest first. `seen` (a
	# Dictionary used as a set) keeps a tile from being added twice.
	var queue: Array[Vector2i] = [face.cell]
	var seen: Dictionary = {face.cell: true}
	while not queue.is_empty() and patch.size() < max_tiles:
		var cell: Vector2i = queue.pop_front()
		patch.append(cell)
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = cell + offset
			if not seen.has(neighbour) and face.layer.is_fresh(neighbour):
				seen[neighbour] = true
				queue.append(neighbour)
	return patch


## Steering: the head turns toward `direction` at the next tile. From SnakeSteer.
func queue_turn(direction: Vector2i) -> void:
	if is_steering():
		active_snake.queue_turn(direction)


## Hardens the snake being steered (D again, Jump, or leaving SnakeSteer any way).
func harden_active(reason: String) -> void:
	if is_steering():
		active_snake.harden(reason)
	active_snake = null
