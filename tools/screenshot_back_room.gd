extends Node
## tools/screenshot_back_room.gd: shows what the depth behind a room looks like
## (Level_editor.md §5a: BackRoomView, depth gates), without editing any level.
## Not part of the game.
##
## Run it WINDOWED (headless has no renderer):
##   godot --path . res://tools/screenshot_back_room.tscn -- <level.tscn> <front room> <back room> <output folder> [<deeper room>]
## Loads the level and, in memory only (the file is untouched), moves `<back room>`
## to depth 1 right behind `<front room>` (top-left on top-left) and puts a depth
## gate pair at the front room's spawn point; a `<deeper room>` goes to depth 2,
## behind both (BackRoomView.DEEPER_LAYERS shows it fainter). Then saves, 3x:
##   <front>_gate.png      standing in the gate (its twin lines up behind it)
##   <front>_nobehind.png  the same with the layer behind hidden, to compare
##   <front>_moved.png     100 px to the left (the layer behind slides slower)
##   <front>_in_1..3.png   during the step in (a third, two thirds, the end of the fade)
##   <front>_through.png   after Up in the gate: in the back room, at depth 1
##   <front>_out_1..3.png  during the step back out, the same moments
##   <front>_back.png      back out at depth 0
## and prints how far the twin is from the gate on screen in the first shot.

const SCALE: int = 3
## How far the player is moved for the second shot, px (left: rooms end in walls
## less often than they start in spikes).
const MOVE_DISTANCE: float = -100.0
## Frames to wait so the camera, backdrop and fades settle.
const SETTLE_FRAMES: int = 60
const GATE_SCENE: PackedScene = preload("res://scenes/objects/depth_gate.tscn")


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() < 4:
		push_error("[BackRoomShot] usage: -- <level.tscn> <front room> <back room> <output folder>")
		get_tree().quit()
		return
	var output_folder: String = arguments[3]
	DirAccess.make_dir_recursive_absolute(output_folder)
	var level: Node = (load(arguments[0]) as PackedScene).instantiate()
	var front: Room = level.get_node(NodePath(arguments[1])) as Room
	var back: Room = level.get_node(NodePath(arguments[2])) as Room
	back.position = front.position + Room.depth_offset(1)
	if arguments.size() > 4:
		var deeper: Room = level.get_node(NodePath(arguments[4])) as Room
		deeper.position = front.position + Room.depth_offset(2)
	# A gate pair standing on the spawn point's floor, one in each room.
	var gate_spot: Vector2 = front.get_node("SpawnPoint").position - Vector2(DepthGate.GATE_SIZE.x / 2.0, DepthGate.GATE_SIZE.y)
	var gate: DepthGate = GATE_SCENE.instantiate() as DepthGate
	gate.position = gate_spot
	front.add_child(gate)
	var twin: DepthGate = GATE_SCENE.instantiate() as DepthGate
	twin.position = gate_spot
	back.add_child(twin)
	add_child(level)
	var manager: RoomManager = level as RoomManager
	var view: BackRoomView = manager.back_room_view

	manager.player.respawn_at(front.get_spawn_position())
	await _settle()
	var gate_on_screen: Vector2 = gate.global_position - manager.camera.get_screen_center_position()
	var twin_on_screen: Vector2 = twin.global_position - view.get_view_center()
	print("[BackRoomShot] twin vs gate on screen: %s px apart" % (twin_on_screen - gate_on_screen))
	_save("%s_gate" % arguments[1], output_folder)
	view.visible = false
	await _settle()
	_save("%s_nobehind" % arguments[1], output_folder)
	view.visible = true

	manager.player.respawn_at(front.get_spawn_position() + Vector2(MOVE_DISTANCE, 0.0))
	await _settle()
	_save("%s_moved" % arguments[1], output_folder)

	manager.player.respawn_at(front.get_spawn_position())
	await _settle()
	manager.go_through_gate(gate)
	await _save_step("%s_in" % arguments[1], output_folder)
	await _settle()
	print("[BackRoomShot] after the gate: in %s, depth %d" % [manager.current_room.name, manager.current_room.get_depth()])
	_save("%s_through" % arguments[1], output_folder)

	# Back out at once, standing in the twin (it may float: no time to fall).
	manager.player.respawn_at(twin.get_gate_rect().get_center() + Vector2(0.0, DepthGate.GATE_SIZE.y / 2.0))
	await get_tree().physics_frame
	manager.go_through_gate(twin)
	await _save_step("%s_out" % arguments[1], output_folder)
	await _settle()
	_save("%s_back" % arguments[1], output_folder)
	get_tree().quit()


## Three shots during a gate's step: a third, two thirds and the end of its fade.
func _save_step(shot_prefix: String, output_folder: String) -> void:
	for shot_index: int in range(1, 4):
		await get_tree().create_timer(RoomManager.GATE_STEP_TIME / 3.0).timeout
		_save("%s_%d" % [shot_prefix, shot_index], output_folder)


func _settle() -> void:
	for frame_index: int in SETTLE_FRAMES:
		await get_tree().process_frame


func _save(shot_name: String, output_folder: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/%s.png" % [output_folder, shot_name])
	print("[BackRoomShot] saved ", shot_name)
