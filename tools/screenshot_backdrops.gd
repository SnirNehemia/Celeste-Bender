extends Node
## tools/screenshot_backdrops.gd: saves pictures of every backdrop look
## (scenes/backdrop/), for reviewing the art without playing. Not part of the game.
##
## Run it WINDOWED (headless has no renderer, so nothing would be drawn):
##   godot --path . res://tools/screenshot_backdrops.tscn -- <output folder> [look] [quick]
## Per look:
##   <look>_<altitude>_a.png / _b.png   each altitude at the start, then with the
##                                      camera moved 400 px right and 60 px down
##   <look>_column.png                  skyline over surface over underground in
##                                      one tall picture: does it read as one scene?
##   <look>_soft.png / <look>_break.png halfway through surface -> skyline and
##                                      underground -> surface (Backdrop.Transition;
##                                      <look>_ground_soft.png where that one is soft)
## Scaled up 3x (the column 2x), crisp pixels. A look's name after the folder does
## only that one (`-- C:/temp/shots desert`); `quick` after it (or `all quick`)
## skips the _a/_b pictures.

const SCALE: int = 3
const COLUMN_SCALE: int = 2
## Frames to wait after a change, so motes and swaying things are mid-motion.
const SETTLE_FRAMES: int = 30
const CAMERA_MOVE: Vector2 = Vector2(400.0, 60.0)
## Altitudes top to bottom, for the column.
const COLUMN_ORDER: Array[Backdrop.Altitude] = [Backdrop.Altitude.SKYLINE, Backdrop.Altitude.SURFACE, Backdrop.Altitude.UNDERGROUND]

var camera: Camera2D
var backdrop: Backdrop


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var output_folder: String = arguments[0] if arguments.size() > 0 else OS.get_user_data_dir()
	var only_look: String = arguments[1].to_lower() if arguments.size() > 1 else "all"
	var is_quick: bool = arguments.size() > 2 and arguments[2] == "quick"
	DirAccess.make_dir_recursive_absolute(output_folder)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	backdrop = Backdrop.new()
	backdrop.camera = camera
	add_child(backdrop)
	for look: Backdrop.Look in Backdrop.THEME_SCRIPTS.keys():
		var look_name: String = String(Backdrop.Look.keys()[look]).to_lower()
		if only_look != "all" and look_name != only_look:
			continue
		if not is_quick:
			await _save_altitudes(look, look_name, output_folder)
		await _save_column(look, "%s/%s_column.png" % [output_folder, look_name])
		await _save_mid_change(look, Backdrop.Altitude.SURFACE, Backdrop.Altitude.SKYLINE, Backdrop.SOFT_TIME,
			"%s/%s_soft.png" % [output_folder, look_name])
		# Out of the ground: a break, except where the look changes softly (underwater).
		var is_soft: bool = Backdrop.get_transition(look, Backdrop.Altitude.UNDERGROUND, look, Backdrop.Altitude.SURFACE) == Backdrop.Transition.SOFT
		var change_time: float = Backdrop.SOFT_TIME if is_soft else Backdrop.BREAK_TIME
		await _save_mid_change(look, Backdrop.Altitude.UNDERGROUND, Backdrop.Altitude.SURFACE, change_time,
			"%s/%s_%s.png" % [output_folder, look_name, "ground_soft" if is_soft else "break"])
	get_tree().quit()


func _save_altitudes(look: Backdrop.Look, look_name: String, output_folder: String) -> void:
	for altitude: Backdrop.Altitude in Backdrop.THEME_SCRIPTS[look].keys():
		var shot_name: String = "%s_%s" % [look_name, String(Backdrop.Altitude.keys()[altitude]).to_lower()]
		camera.position = Vector2.ZERO
		var started_at: int = Time.get_ticks_msec()
		backdrop.show_look(look, altitude)
		print("[Backdrops] %s built in %d ms" % [shot_name, Time.get_ticks_msec() - started_at])
		await _wait_frames(SETTLE_FRAMES)
		_save_image(_grab(), SCALE, "%s/%s_a.png" % [output_folder, shot_name])
		camera.position = CAMERA_MOVE
		await _wait_frames(SETTLE_FRAMES)
		_save_image(_grab(), SCALE, "%s/%s_b.png" % [output_folder, shot_name])


## The three altitudes stacked, camera at the start for each.
func _save_column(look: Backdrop.Look, path: String) -> void:
	camera.position = Vector2.ZERO
	var pieces: Array[Image] = []
	for altitude: Backdrop.Altitude in COLUMN_ORDER:
		backdrop.show_look(look, altitude)
		await _wait_frames(SETTLE_FRAMES)
		pieces.append(_grab())
	var column: Image = Image.create_empty(pieces[0].get_width(), pieces[0].get_height() * pieces.size(), false, pieces[0].get_format())
	for index: int in pieces.size():
		column.blit_rect(pieces[index], Rect2i(Vector2i.ZERO, pieces[index].get_size()), Vector2i(0, index * pieces[index].get_height()))
	_save_image(column, COLUMN_SCALE, path)


## Halfway through the change from `from_altitude` up to `to_altitude`.
func _save_mid_change(look: Backdrop.Look, from_altitude: Backdrop.Altitude, to_altitude: Backdrop.Altitude,
		change_time: float, path: String) -> void:
	camera.position = Vector2.ZERO
	backdrop.show_look(look, from_altitude)
	await _wait_frames(SETTLE_FRAMES)
	backdrop.show_look(look, to_altitude, Vector2.UP)
	await get_tree().create_timer(change_time * 0.5).timeout
	_save_image(_grab(), SCALE, path)
	await get_tree().create_timer(change_time * 0.6).timeout


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


func _save_image(image: Image, scale_factor: int, path: String) -> void:
	image.resize(image.get_width() * scale_factor, image.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
	image.save_png(path)
	print("[Backdrops] saved ", path)


func _wait_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().process_frame
