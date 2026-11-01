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
##   - Restart (R, or the pause menu): kills the player through the same path, so
##     it counts as a death.
##   - Reset: on every respawn, EVERY room's objects go back to their start
##     (Room.reset_objects()), so a misplaced crate can't leave a room unsolvable.
##     All rooms, not only the current one (play-test): a fire that had spread over
##     the border into the next room kept burning there, and lit your room again
##     after every reset.
##   - Freezing: only the rooms near the player run. Every other room is set to
##     PROCESS_MODE_DISABLED, which pauses its whole branch of the tree (no _process,
##     no _physics_process, particles stop, bodies leave the physics world) and keeps
##     everything exactly as it was, so a fire left burning picks up where it stopped
##     when you come back. Without this, all rooms of a level ran every frame, and a
##     long level got slower the more fires you'd left behind.

## How far around the player's hitbox a room counts as "near" and stays awake, in
## pixels. A room wakes up a little BEFORE the player reaches it, so its doors,
## platforms and hazards are back in the physics world in time (the player moves
## at most a few pixels per frame), and the room you just left keeps running until
## you're clear of its edge. Tile collision doesn't need this: TileMapLayers stay
## solid even in a frozen room.
const AWAKE_MARGIN: float = 16.0

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
	_add_backdrop()
	GameState.current_room = current_room
	camera.snap_to_room(current_room.get_bounds())
	_update_awake_rooms()


func _physics_process(_delta: float) -> void:
	if current_room == null:
		return
	# Every frame, even during a slide or a death: the player keeps moving through
	# rooms' edges then too.
	_update_awake_rooms()
	if is_transitioning or player.is_dead():
		return

	var player_center: Vector2 = _get_player_center()
	if current_room.get_bounds().has_point(player_center):
		return  # still in the same room, nothing to do

	var next_room: Room = _find_room_containing(player_center)
	if next_room != null:
		_transition_to_room(next_room)
	elif player_center.y > current_room.get_bounds().end.y:
		# Fell out of the bottom with no room below: that's a pit (even for a
		# play-test's invincible player, who would otherwise fall forever).
		player.die(true)
	# Otherwise (e.g. jumped above the top of the room): allowed, keep going.


## Adds the parallax background (Backdrop) behind the rooms. Before the first room
## is set, so it hears GameState.room_entered and shows that room's look at once.
## Its start room (AUTO backdrop altitudes are measured from it) is the level's
## LevelInfo.start_room in editor levels, else the room the player starts in.
## It paints every look the level's rooms use right away (Backdrop.paint_ahead):
## a pause while loading instead of a stall on entering a room. Also adds the
## BackRoomView, which shows a room's back room (Room.back_room) behind it.
func _add_backdrop() -> void:
	var backdrop: Backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	backdrop.camera = camera
	backdrop.start_room = current_room
	var level_info: LevelInfo = get_node_or_null(NodePath(LevelInfo.NODE_NAME)) as LevelInfo
	if level_info != null and level_info.start_room != null:
		backdrop.start_room = level_info.start_room
	backdrop.paint_ahead(rooms)
	add_child(backdrop)
	# Rooms seen behind rooms (Room.back_room), between the backdrop and the rooms.
	var back_room_view: BackRoomView = BackRoomView.new()
	back_room_view.name = "BackRoomView"
	back_room_view.camera = camera
	back_room_view.rooms = rooms
	add_child(back_room_view)


## _unhandled_input receives key presses not already used by UI.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_room"):
		restart_room()


## Restarts the current room by killing the player (counts as a death, like
## Celeste's Retry). Ignored during a room slide and after the Goal: the run is
## over then, and a restart must not add a death to the final score.
func restart_room() -> void:
	if not is_transitioning and not GameState.is_run_finished:
		player.die(true)  # R works even with the play-test's invincibility on


func _transition_to_room(next_room: Room) -> void:
	var previous_room: Room = current_room
	# Wake it before anything else touches it (it's near the player, so it should be
	# awake already; this makes sure).
	_set_room_awake(next_room, true)
	# Enemies start where they were placed every time you walk in (they sleep while
	# you're elsewhere, see Room.reset_enemies).
	next_room.reset_enemies()
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
	target_room.reset_objects()
	player.respawn_at(target_room.get_spawn_position())
	camera.snap_to_room(target_room.get_bounds())
	# Right away, not next frame: whoever called this (the room picker, a smoke test)
	# may use the room's objects in the same frame.
	_update_awake_rooms()


func _on_player_died() -> void:
	GameState.register_death()
	# create_timer() makes a one-off countdown; awaiting its `timeout` signal pauses
	# this function (without blocking the game) until the time is up.
	await get_tree().create_timer(player.tuning.death_respawn_delay).timeout
	# Reset at respawn time, not at death: during the death effect the room still
	# shows what happened.
	for room: Room in rooms:
		room.reset_objects()
	player.respawn_at(current_room.get_spawn_position())
	_update_awake_rooms()
	# A soft white flash (alpha 0.35, not a full white-out) hides the teleport.
	FX.flash_screen(Color(1.0, 1.0, 1.0, 0.35), player.tuning.respawn_flash_time)


## Wakes the current room and every room within AWAKE_MARGIN of the player's
## hitbox; freezes all the others. Cheap: one rectangle test per room.
func _update_awake_rooms() -> void:
	var near_player: Rect2 = player.get_hitbox_rect().grow(AWAKE_MARGIN)
	for room: Room in rooms:
		var is_near: bool = room == current_room or room.get_bounds().intersects(near_player)
		_set_room_awake(room, is_near)


## True: the room runs normally (INHERIT: it follows this node, so pausing the game
## still pauses it). False: frozen (DISABLED). Only writes on a change, since
## setting process_mode notifies every node in the room.
func _set_room_awake(room: Room, awake: bool) -> void:
	var wanted_mode: ProcessMode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	if room.process_mode != wanted_mode:
		room.process_mode = wanted_mode


func _find_room_containing(point: Vector2) -> Room:
	for room: Room in rooms:
		if room.get_bounds().has_point(point):
			return room
	return null


## Using the player's CENTER (not feet) means you switch rooms when you're halfway
## through the opening.
func _get_player_center() -> Vector2:
	return player.get_center()
