extends Node
## tools/screenshot_backdrops.gd: saves a picture of every backdrop look
## (scenes/backdrop/), for reviewing the art without playing. Not part of the game.
##
## Run it WINDOWED (headless has no renderer, so nothing would be drawn):
##   godot --path . res://tools/screenshot_backdrops.tscn -- <output folder>
## Two PNGs per look and altitude (<look>_<altitude>_a.png at the start, ..._b.png
## with the camera moved 400 px right and 60 px down, to see the parallax), scaled
## up 3x, crisp pixels. Add a look's name after the folder for only that one
## (`-- C:/temp/shots desert`).

const SCALE: int = 3
## Frames to wait after a change, so motes and swaying things are mid-motion.
const SETTLE_FRAMES: int = 30
const CAMERA_MOVE: Vector2 = Vector2(400.0, 60.0)


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var output_folder: String = arguments[0] if arguments.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(output_folder)
	var camera: Camera2D = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var backdrop: Backdrop = Backdrop.new()
	backdrop.camera = camera
	add_child(backdrop)
	var only_look: String = arguments[1].to_lower() if arguments.size() > 1 else ""
	for look: Backdrop.Look in Backdrop.THEME_SCRIPTS.keys():
		var look_name: String = String(Backdrop.Look.keys()[look]).to_lower()
		if only_look != "" and look_name != only_look:
			continue
		for altitude: Backdrop.Altitude in Backdrop.THEME_SCRIPTS[look].keys():
			var shot_name: String = "%s_%s" % [look_name, String(Backdrop.Altitude.keys()[altitude]).to_lower()]
			camera.position = Vector2.ZERO
			var started_at: int = Time.get_ticks_msec()
			backdrop.show_look(look, altitude)
			print("[Backdrops] %s built in %d ms" % [shot_name, Time.get_ticks_msec() - started_at])
			await _wait_frames(SETTLE_FRAMES)
			_save_frame("%s/%s_a.png" % [output_folder, shot_name])
			camera.position = CAMERA_MOVE
			await _wait_frames(SETTLE_FRAMES)
			_save_frame("%s/%s_b.png" % [output_folder, shot_name])
	get_tree().quit()


func _save_frame(path: String) -> void:
	var frame: Image = get_viewport().get_texture().get_image()
	frame.resize(frame.get_width() * SCALE, frame.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	frame.save_png(path)
	print("[Backdrops] saved ", path)


func _wait_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame
