class_name PlaytestCheats
extends Node
## PlaytestCheats: test-only switches while play-testing a level from the editor
## (LevelEditor adds one to the play copy; never part of the real game).
##   I  invincible: hazards and enemies can't kill you (a pit or R still do, or
##      you'd fall forever / couldn't restart). Player.is_invincible.
##   N  fly: the player hangs in the air and the arrows move it anywhere, through
##      walls; you can't die. The player node is disabled meanwhile, so it leaves
##      the physics world (nothing touches it) and runs no state machine.
##   O  slow motion: full speed -> half -> quarter -> full.
##   P  pause / resume; while paused, . (period) steps one physics frame.
## A line at the top of the screen lists what's on.
##
## process_mode ALWAYS: this node still runs (and reads keys) while the tree is
## paused, which is how it can step a paused game one frame at a time.
## Slow motion multiplies the game's own (FX: a gust's aim slows time too), set
## every frame, so neither one undoes the other. The pause goes through FX's own
## "step" reason, so a menu or a hit freeze ending never resumes it by surprise.

## The slow-motion steps O cycles through.
const SPEEDS: Array[float] = [1.0, 0.5, 0.25]
## Flying speed, px/s; Shift is not read here (it's a game key), so one speed.
const FLY_SPEED: float = 160.0
const LABEL_COLOR: Color = Color(1.0, 0.85, 0.2)

var player: Player = null
var is_invincible: bool = false
var is_flying: bool = false
var speed_index: int = 0
var is_paused: bool = false
## True while a single step runs (the pause is lifted for one physics frame).
var is_stepping: bool = false
var label: Label


func _init(new_player: Player) -> void:
	player = new_player
	name = "PlaytestCheats"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# A CanvasLayer draws on screen, not in the level, so the camera doesn't move it.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	label = Label.new()
	label.position = Vector2(2, 2)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	layer.add_child(label)
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("playtest_invincible"):
		set_invincible(not is_invincible)
	elif event.is_action_pressed("playtest_fly"):
		set_flying(not is_flying)
	elif event.is_action_pressed("playtest_slow_motion"):
		speed_index = (speed_index + 1) % SPEEDS.size()
	elif event.is_action_pressed("playtest_pause"):
		set_paused(not is_paused)
	elif event.is_action_pressed("playtest_step"):
		step_frame()
	else:
		return
	_refresh_label()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# The game's own slow motion (FX) times the cheat's.
	Engine.time_scale = FX.slow_motion_scale * SPEEDS[speed_index]
	if is_flying and not is_paused and is_instance_valid(player):
		var direction: Vector2 = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
		# delta is scaled by the slow motion, so flying slows down with it.
		player.global_position += direction * FLY_SPEED * delta


func set_invincible(on: bool) -> void:
	is_invincible = on
	player.is_invincible = on or is_flying


func set_flying(on: bool) -> void:
	is_flying = on
	# Disabled: out of the physics world, no _physics_process (no falling, no state).
	player.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if not on:
		player.velocity = Vector2.ZERO  # let go where you are, no leftover speed
	player.is_invincible = is_invincible or on


func set_paused(on: bool) -> void:
	is_paused = on
	FX.set_step_pause(on)


## While paused: lets exactly one physics frame run. physics_frame fires just
## BEFORE each physics frame is processed: unpaused, the next one runs; paused again
## at the one after, that one doesn't.
func step_frame() -> void:
	if not is_paused or is_stepping:
		return
	is_stepping = true
	FX.set_step_pause(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	is_stepping = false
	if is_paused:
		FX.set_step_pause(true)


## Everything back as it was: the play-test is ending.
func switch_all_off() -> void:
	if is_instance_valid(player):
		set_flying(false)
		set_invincible(false)
	speed_index = 0
	is_paused = false
	FX.set_step_pause(false)


func _refresh_label() -> void:
	var on: Array[String] = []
	if is_invincible:
		on.append("invincible")
	if is_flying:
		on.append("flying")
	if SPEEDS[speed_index] < 1.0:
		on.append("%sx speed" % str(SPEEDS[speed_index]))
	if is_paused:
		on.append("paused (. = 1 frame)")
	label.text = "" if on.is_empty() else "Test: " + ", ".join(on)
