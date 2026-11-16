class_name GhostRuns
extends Node2D
## GhostRuns: records the player's FASTEST run through each room and, when the
## pause menu's "Ghost" option is on (AssistOptions.show_ghost), replays it as a
## faint figure to race against. Made by the RoomManager, like the Backdrop.
##
## WHAT A ROOM RUN IS: it starts when the player walks into a room (or respawns in
## it) and ends when they leave it into ANOTHER room than the one they came from.
## A death cancels it; the run after the respawn starts at the spawn point. Walking
## back out the way you came isn't a run through the room, so it never counts.
## Each room keeps one best run per way in: the name of the room you came from, or
## START_FROM_SPAWN for runs that start at its spawn point.
## Time is GAME time (physics frames), so slow motion, the assist game speed and
## pauses don't change a run's time.
##
## Runs are always recorded; the option only decides whether the ghost is DRAWN.
## Runs made with a play-test cheat on (invincible, flying) are thrown away, and so
## is a room left by the F2 room picker (cancel_run).
##
## Kept per level in record_path (a ConfigFile in user://, the player's own data
## folder), under the level's scene path (`level_key`). A level with no file (an
## unsaved editor level) keeps its ghosts only until it closes.
##
## How it follows the game: it watches RoomManager.current_room and Player.is_dead()
## each physics frame, so no other script has to tell it about room changes.
##
## Godot concepts used:
##   - _physics_process: runs at the fixed physics rate (60 per second), the same
##     steps the player moves in, so a recording is frame-exact.
##   - _draw / queue_redraw: custom drawing on a CanvasItem; _draw runs again only
##     after queue_redraw().

## Where every level's best runs are kept. A var: the smoke test points it elsewhere.
static var record_path: String = "user://ghost_runs.cfg"
## The "came from" name of runs that start at the room's spawn point.
const START_FROM_SPAWN: String = "(spawn)"
## A position is kept every this many physics frames (2 = 30 per second): half the
## file, and the ghost is drawn between two kept positions anyway.
const RECORD_EVERY_FRAMES: int = 2
## Runs longer than this are not kept, s (someone left the game standing).
const LONGEST_RUN: float = 300.0
## The ghost: the player's box, this see-through (not in the §2 color key: white,
## like the player, so it reads as "you, earlier").
const GHOST_COLOR: Color = Color(1.0, 1.0, 1.0, 0.3)
const GHOST_EDGE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
## The time texts ("Best 4.32", "New best!"): size, colors, seconds shown.
const TEXT_FONT_SIZE: int = PixelFont.FONT_SIZE
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const NEW_BEST_COLOR: Color = Color(0.4, 0.95, 0.5)
const BEST_TEXT_TIME: float = 1.5
const NEW_BEST_TEXT_TIME: float = 2.0
## Above the rooms, under the darkness of dark rooms (35): the dark hides a ghost too.
const DRAW_Z_INDEX: int = 30

var manager: RoomManager
var player: Player
## The level's name in the record file ("" = don't save to disk).
var level_key: String = ""
## Best runs of this level: "<room name>|<came from>" -> {"time": seconds,
## "points": PackedVector2Array of the player's center, relative to the room}.
var best_runs: Dictionary = {}

## The run being recorded.
var run_room: Room = null
var run_from: String = START_FROM_SPAWN
var run_time: float = 0.0
var run_frames: int = 0
var run_points: PackedVector2Array = PackedVector2Array()
var is_recording: bool = false
## A cheat was on at some point of this run: it won't be kept.
var is_run_spoiled: bool = false
## The room the player walked into the current room from ("" = started here).
## Kept through deaths: leaving back that way is never a finished run.
var arrived_from: String = ""
var was_dead: bool = false
## The run the ghost replays (a value of best_runs), or empty.
var ghost_run: Dictionary = {}
## Seconds left of the "New best" text, and what it says.
var new_best_time_left: float = 0.0
var new_best_text: String = ""


func _ready() -> void:
	z_index = DRAW_Z_INDEX
	z_as_relative = false
	_load_runs()


func _physics_process(delta: float) -> void:
	if manager == null or player == null or manager.current_room == null:
		return
	new_best_time_left = maxf(new_best_time_left - delta, 0.0)
	queue_redraw()
	if player.is_dead():
		is_recording = false  # a death ends the attempt; the next starts at the spawn
		was_dead = true
		return
	if manager.current_room != run_room:
		# A new room: the old room's run is over, a new one starts where we walked in.
		var left_room: Room = run_room
		if left_room != null and is_recording and String(manager.current_room.name) != arrived_from:
			_finish_run()
		arrived_from = String(left_room.name) if left_room != null else ""
		_begin_run(manager.current_room, arrived_from if arrived_from != "" else START_FROM_SPAWN)
	elif was_dead:
		_begin_run(run_room, START_FROM_SPAWN)
	was_dead = false
	if not is_recording:
		return
	if player.is_invincible:
		is_run_spoiled = true  # a play-test cheat (invincible or flying)
	if run_frames % RECORD_EVERY_FRAMES == 0:
		run_points.append(player.get_center() - run_room.global_position)
	run_frames += 1
	run_time += delta
	if run_time > LONGEST_RUN:
		is_recording = false


## Throws the current run away without keeping it (the F2 room picker's jump).
## The next room change starts a fresh one.
func cancel_run() -> void:
	is_recording = false
	run_room = null
	arrived_from = ""
	ghost_run = {}


## The best time recorded for `room` entered from `from_name`, or -1.0 if none.
func get_best_time(room: Room, from_name: String) -> float:
	var run: Dictionary = best_runs.get(_key_of(room, from_name), {})
	return run.get("time", -1.0)


func _begin_run(room: Room, from_name: String) -> void:
	run_room = room
	run_from = from_name
	run_time = 0.0
	run_frames = 0
	run_points = PackedVector2Array()
	is_recording = true
	is_run_spoiled = false
	ghost_run = best_runs.get(_key_of(room, from_name), {})


## The player left run_room: keep the run if it's the fastest one from that way in.
func _finish_run() -> void:
	is_recording = false
	if is_run_spoiled or run_points.size() < 2:
		return
	var key: String = _key_of(run_room, run_from)
	var old_time: float = get_best_time(run_room, run_from)
	if old_time >= 0.0 and run_time >= old_time:
		return
	best_runs[key] = {"time": run_time, "points": run_points}
	_save_runs()
	if old_time >= 0.0:
		new_best_text = "New best %.2f (-%.2f)" % [run_time, old_time - run_time]
		new_best_time_left = NEW_BEST_TEXT_TIME
		FX.play_sfx(&"ghost_beaten")


func _key_of(room: Room, from_name: String) -> String:
	return "%s|%s" % [room.name, from_name]


func _load_runs() -> void:
	best_runs = {}
	if level_key == "":
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(record_path) != OK or not config.has_section(level_key):
		return
	for key: String in config.get_section_keys(level_key):
		var run: Variant = config.get_value(level_key, key)
		if run is Dictionary and (run as Dictionary).has("time") and (run as Dictionary).get("points") is PackedVector2Array:
			best_runs[key] = run


## Writes this level's best runs to record_path, keeping the other levels'.
func _save_runs() -> void:
	if level_key == "":
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(record_path)  # missing the first time: then it starts empty
	for key: String in best_runs:
		config.set_value(level_key, key, best_runs[key])
	config.save(record_path)


## Where the ghost is `seconds` into its run (global px), between two kept
## positions. Call only while seconds is inside the run.
func _get_ghost_center(seconds: float) -> Vector2:
	var points: PackedVector2Array = ghost_run["points"]
	var seconds_per_point: float = RECORD_EVERY_FRAMES / float(Engine.physics_ticks_per_second)
	var exact_index: float = seconds / seconds_per_point
	var index: int = mini(int(exact_index), points.size() - 1)
	var next_index: int = mini(index + 1, points.size() - 1)
	return run_room.global_position + points[index].lerp(points[next_index], exact_index - index)


func _draw() -> void:
	var font: Font = PixelFont.get_font()  # drawn in the 320x180 world: whole pixels
	if new_best_time_left > 0.0 and player != null:
		# Over the player's head, in the room they just walked into.
		var text_position: Vector2 = (player.get_center() + Vector2(-30.0, -14.0)).round()
		draw_string(font, text_position, new_best_text, HORIZONTAL_ALIGNMENT_CENTER, 60.0,
			TEXT_FONT_SIZE, Color(NEW_BEST_COLOR, minf(new_best_time_left * 2.0, 1.0)))
	if not AssistOptions.show_ghost or ghost_run.is_empty() or run_room == null or not is_recording:
		return
	var ghost_time: float = ghost_run["time"]
	if run_time > ghost_time:
		return  # the ghost has left the room: you're behind
	var box: Rect2 = player.get_hitbox_rect()
	var ghost_box: Rect2 = Rect2((_get_ghost_center(run_time) - box.size / 2.0).round(), box.size)
	draw_rect(ghost_box, GHOST_COLOR)
	draw_rect(ghost_box, GHOST_EDGE_COLOR, false, 1.0)
	if run_time < BEST_TEXT_TIME:
		# The time to beat, over the ghost's head while the run is young.
		draw_string(font, ghost_box.position + Vector2(-27.0 + box.size.x / 2.0, -4.0),
			"Best %.2f" % ghost_time, HORIZONTAL_ALIGNMENT_CENTER, 54.0, TEXT_FONT_SIZE, TEXT_COLOR)
