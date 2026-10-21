extends Node
## tools/screenshot_rooms.gd: saves a picture of every room of a world scene, for
## reviewing layouts without playing (Stage E7). Not part of the game.
##
## Run it WINDOWED (headless has no renderer, so nothing would be drawn):
##   godot --path . res://tools/screenshot_rooms.tscn -- <world.tscn> <output folder>
## e.g. `-- res://scenes/earth_world.tscn C:/temp/shots`. One PNG per room
## (room_01.png, ...), the whole room even when it's wider than the screen, scaled up
## 3x with nearest-neighbour (crisp pixels).
##
## How: it jumps the player into each room (RoomManager.jump_to_room), then turns off
## the RoomCamera's own movement and points the camera at each screen-sized slice of
## the room in turn, grabbing the rendered frame after each move. The slices are
## pasted side by side (Image.blit_rect) into one picture of the whole room.

## Output scale: 320x180 frames are tiny on a modern screen.
const SCALE: int = 3
## Frames to wait after moving the camera or the player, so the picture has settled
## (the player lands, the ground painter draws).
const SETTLE_FRAMES: int = 20


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var world_path: String = arguments[0] if arguments.size() > 0 else "res://scenes/earth_world.tscn"
	var output_folder: String = arguments[1] if arguments.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(output_folder)
	var world: RoomManager = (load(world_path) as PackedScene).instantiate() as RoomManager
	add_child(world)
	await _wait_frames(SETTLE_FRAMES)
	var camera: RoomCamera = world.camera
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	for room_index: int in world.rooms.size():
		var room: Room = world.rooms[room_index]
		world.jump_to_room(room)
		await _wait_frames(SETTLE_FRAMES)
		# From now on we place the camera ourselves.
		camera.set_physics_process(false)
		camera.set_process(false)
		var bounds: Rect2 = room.get_bounds()
		var picture: Image = Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
		var slice_x: float = 0.0
		while true:
			# The camera's position is the CENTER of the screen.
			var left: float = minf(slice_x, bounds.size.x - screen_size.x)
			camera.global_position = bounds.position + Vector2(left, 0.0) + screen_size / 2.0
			await _wait_frames(3)
			# Wait for the frame to be fully drawn before reading it back.
			await RenderingServer.frame_post_draw
			var frame: Image = get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGBA8)
			picture.blit_rect(frame, Rect2i(Vector2i.ZERO, Vector2i(screen_size)), Vector2i(int(left), 0))
			if left + screen_size.x >= bounds.size.x:
				break
			slice_x += screen_size.x
		camera.set_physics_process(true)
		camera.set_process(true)
		picture.resize(picture.get_width() * SCALE, picture.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		var file_path: String = output_folder.path_join("room_%02d.png" % (room_index + 1))
		picture.save_png(file_path)
		print("[Screenshots] %s -> %s" % [room.display_title, file_path])
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame
