class_name GateStep
extends Node
## GateStep: the animation of going through a depth gate (Level_editor.md §5a), from
## the moment the player presses Up in it until they can move again in its twin's
## room. RoomManager makes one (in _add_backdrop, next to the BackRoomView it
## drives), checks that the gate leads somewhere, and awaits run(); everything
## between is here.
##
## The player freezes for the step, and the backdrop zooms to the new depth's size
## all through it (Backdrop.zoom_to). Then:
##   GOING IN (_step_in): the rooms of this depth fade out while the layer behind
##     loses its haze and grows to full size; then the swap (below), and the camera
##     starts where the view behind was looking and glides to settle.
##   GOING OUT (_step_out), the same backwards: the swap first; the room we left
##     shows behind, clear and full size, exactly where we were looking, and hazes
##     and shrinks back while the rooms of the new depth fade in over it; then the
##     view behind and the camera glide to settle.
## The swap: the player moves by the band difference (so they stand in the twin
## exactly where they stood in the gate), and swapped is emitted: RoomManager makes
## the twin's room the current room there (GameState.room_entered: the backdrop and
## the view behind follow).

## Emitted halfway through the step, once the player stands in the twin: `twin_room`
## must become the current room now (the rest of the step relies on it).
signal swapped(twin_room: Room)

## Seconds of the step: the front fades while the layer behind clears, or
## backwards for a gate leading to the front. A look, not feel, so not in PlayerTuning.
const STEP_TIME: float = 0.3
## Seconds the camera glides from the view behind to where it settles in the new
## room, after the step.
const SETTLE_TIME: float = 0.2

# What the step moves, all handed over by RoomManager (setup).
var _player: Player = null
var _camera: RoomCamera = null
var _backdrop: Backdrop = null
var _back_room_view: BackRoomView = null
## Every room of the level (RoomManager.rooms: the same array, not a copy).
var _rooms: Array[Room] = []


func setup(player: Player, camera: RoomCamera, backdrop: Backdrop, back_room_view: BackRoomView,
		rooms: Array[Room]) -> void:
	_player = player
	_camera = camera
	_backdrop = backdrop
	_back_room_view = back_room_view
	_rooms = rooms


## The whole step from `gate` (in the current room) to its `twin` (in `twin_room`).
## Await it: it returns once the player is free to move again.
func run(gate: DepthGate, twin: DepthGate, twin_room: Room) -> void:
	_player.velocity = Vector2.ZERO
	_player.set_frozen(true)
	FX.play_sfx(&"gate")
	# The backdrop zooms to the new depth's size during the step (Backdrop.ZOOM_PER_DEPTH).
	_backdrop.zoom_to(Backdrop.zoom_for_depth(twin.get_depth()), STEP_TIME + SETTLE_TIME)
	if twin.get_depth() > gate.get_depth():
		await _step_in(gate, twin, twin_room)
	else:
		await _step_out(gate, twin, twin_room)
	_player.set_frozen(false)


## Into the layer behind (see the header).
func _step_in(gate: DepthGate, twin: DepthGate, twin_room: Room) -> void:
	var old_rooms: Array[Room] = _rooms_at_depth(gate.get_depth())
	# set_parallel: every tween_property below runs at the same time, not one by one.
	var step: Tween = create_tween().set_parallel(true)
	for room: Room in old_rooms:
		step.tween_property(room, "modulate:a", 0.0, STEP_TIME)
	var behind_step: Tween = _back_room_view.begin_step(STEP_TIME)
	await step.finished
	# The view behind's tween may already be done (same length), or invalid if
	# it had nothing to animate: only wait for one that's still running.
	if behind_step.is_valid() and behind_step.is_running():
		await behind_step.finished
	var view_start: Vector2 = _back_room_view.get_view_center()
	_back_room_view.end_step()
	_swap(gate, twin, twin_room)
	for room: Room in old_rooms:
		room.modulate.a = 1.0  # off in their own band now
	# Whole pixels: the 320x180 view would shimmer on a half-pixel camera.
	_camera.global_position = view_start.round()
	_camera.reset_smoothing()
	await _camera.slide_to_room(twin_room.get_bounds(), SETTLE_TIME)


## Back out to the layer in front (see the header).
func _step_out(gate: DepthGate, twin: DepthGate, twin_room: Room) -> void:
	var left_depth: int = gate.get_depth()
	var old_view: Vector2 = _camera.get_screen_center_position()
	var band_shift: Vector2 = twin.global_position - gate.global_position
	_swap(gate, twin, twin_room)
	# The camera looks straight through the gate at the same spot, held there
	# (rounded to whole pixels, like the step in).
	_camera.hold_at((old_view + band_shift).round())
	var behind_step: Tween = _back_room_view.begin_return(left_depth, old_view, STEP_TIME)
	var arrive: Tween = create_tween().set_parallel(true)
	for room: Room in _rooms_at_depth(twin_room.get_depth()):
		room.modulate.a = 0.0
		arrive.tween_property(room, "modulate:a", 1.0, STEP_TIME)
	await arrive.finished
	if behind_step.is_valid() and behind_step.is_running():
		await behind_step.finished
	_back_room_view.release_view()
	await _camera.slide_to_room(twin_room.get_bounds(), SETTLE_TIME)


## The step's swap (see the header).
func _swap(gate: DepthGate, twin: DepthGate, twin_room: Room) -> void:
	_player.global_position += twin.global_position - gate.global_position
	swapped.emit(twin_room)


## Every room at `depth`.
func _rooms_at_depth(depth: int) -> Array[Room]:
	var found: Array[Room] = []
	for room: Room in _rooms:
		if room.get_depth() == depth:
			found.append(room)
	return found
