extends Node
## tools/screenshot_back_room.gd: shows what a back room (Room.back_room,
## BackRoomView) looks like, without editing any level. Not part of the game.
##
## Run it WINDOWED (headless has no renderer):
##   godot --path . res://tools/screenshot_back_room.tscn -- <level.tscn> <front room> <back room> <output folder>
## Loads the level, sets `<front room>`'s back_room to
## `<back room>` in memory only (the file is untouched), moves the player into the
## front room and saves <front>_without.png and <front>_with_<back>.png, 3x.

const SCALE: int = 3
## Frames to wait so the camera, backdrop and fades settle.
const SETTLE_FRAMES: int = 60


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() < 4:
		push_error("[BackRoomShot] usage: -- <level.tscn> <front room> <back room> <output folder>")
		get_tree().quit()
		return
	var output_folder: String = arguments[3]
	DirAccess.make_dir_recursive_absolute(output_folder)
	for with_back_room: bool in [false, true]:
		var level: Node = (load(arguments[0]) as PackedScene).instantiate()
		var front: Room = level.get_node(NodePath(arguments[1])) as Room
		front.back_room = arguments[2] if with_back_room else ""
		add_child(level)
		var manager: RoomManager = level as RoomManager
		# Into the front room, at its spawn point (the room manager follows).
		manager.player.global_position = front.get_spawn_position()
		for frame_index: int in SETTLE_FRAMES:
			await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		var shot_name: String = "%s_with_%s" % [arguments[1], arguments[2]] if with_back_room else "%s_without" % arguments[1]
		image.save_png("%s/%s.png" % [output_folder, shot_name])
		print("[BackRoomShot] saved ", shot_name)
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()
