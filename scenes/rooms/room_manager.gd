class_name RoomManager
extends Node2D
## Root script of a world scene: owns the rooms, and connects player, camera and GameState.
##
## Expected scene layout (see tests/test_world.tscn):
##   World (this script)
##   ├─ RoomA, RoomB, ...   Room scenes, direct children, placed edge to edge
##   ├─ Player              assigned to `player` in the Inspector
##   ├─ RoomCamera          assigned to `camera` in the Inspector
##   └─ DebugOverlay
##
## Responsibilities:
##   - Room tracking: every physics frame, if the player's center has left the current
##     room's bounds, find the room it's now in and slide the camera there. That room's
##     spawn point becomes the checkpoint.
##   - Pits: if the player falls below the current room and no room is down there, they die.
##   - Death: listens to player.died, counts it in GameState, waits
##     tuning.death_respawn_delay seconds, then respawns at the current room's spawn.
##   - Restart (R): kills the player through the same path, so it counts as a death.

@export var player: Player
@export var camera: RoomCamera

## All Room children, collected at startup.
var rooms: Array[Room] = []
## The room the camera is locked to and the player respawns in.
var current_room: Room = null
## True during the camera slide between rooms (player is frozen).
var is_transitioning: bool = false


func _ready() -> void:
	for child: Node in get_children():
		if child is Room:
			rooms.append(child)

	# Signals: connect() means "when player emits died, call _on_player_died".
	player.died.connect(_on_player_died)

	camera.follow_target = player
	current_room = _find_room_containing(_get_player_center())
	if current_room == null:
		push_error("[RoomManager] Player does not start inside any room")
		return
	GameState.current_room = current_room
	camera.snap_to_room(current_room.get_bounds())


func _physics_process(_delta: float) -> void:
	if is_transitioning or player.is_dead() or current_room == null:
		return

	var player_center: Vector2 = _get_player_center()
	if current_room.get_bounds().has_point(player_center):
		return  # still in the same room, nothing to do

	var next_room: Room = _find_room_containing(player_center)
	if next_room != null:
		_transition_to_room(next_room)
	elif player_center.y > current_room.get_bounds().end.y:
		# Fell out of the bottom with no room below: that's a pit.
		player.die()
	# Otherwise (e.g. jumped above the top of the room): allowed, keep going.


## _unhandled_input receives key presses not already used by UI.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_room") and not is_transitioning:
		player.die()


func _transition_to_room(next_room: Room) -> void:
	var previous_room: Room = current_room
	current_room = next_room
	GameState.current_room = next_room
	is_transitioning = true

	# Entering a room above: give an upward kick so we don't arrive at the top of
	# our jump and fall straight back down through the opening.
	if next_room.get_bounds().end.y <= previous_room.get_bounds().position.y:
		player.velocity.y = minf(player.velocity.y, player.tuning.room_transition_up_boost)
		# Switch to Fall so plain gravity acts on the boost. (The Jump state would
		# overwrite it with its held launch speed.)
		player.state_machine.transition_to(&"Fall")

	# Freeze the player (keeping their velocity) while the camera slides, like Celeste.
	player.set_frozen(true)
	await camera.slide_to_room(next_room.get_bounds(), player.tuning.room_transition_time)
	player.set_frozen(false)
	is_transitioning = false


## Teleports the player to `target_room`'s spawn and snaps the camera there, with no
## slide and without counting a death. Used by the debug room picker (F2).
func jump_to_room(target_room: Room) -> void:
	if is_transitioning:
		return
	current_room = target_room
	GameState.current_room = target_room
	player.respawn_at(target_room.get_spawn_position())
	camera.snap_to_room(target_room.get_bounds())


func _on_player_died() -> void:
	GameState.register_death()
	# create_timer() makes a one-off countdown; awaiting its `timeout` signal pauses
	# this function (without blocking the game) until the time is up.
	await get_tree().create_timer(player.tuning.death_respawn_delay).timeout
	player.respawn_at(current_room.get_spawn_position())


func _find_room_containing(point: Vector2) -> Room:
	for room: Room in rooms:
		if room.get_bounds().has_point(point):
			return room
	return null


## Using the player's CENTER (not feet) means you switch rooms when you're halfway
## through the opening.
func _get_player_center() -> Vector2:
	return player.get_center()
