class_name EndScreen
extends CanvasLayer
## End screen (GAME_DESIGN.md §8): "slice complete", deaths and time, and
## "press Jump to play again".
##
## Hidden until GameState emits `run_finished` (the Goal in room 5 triggers it).
## In a Story Mode run (GameState.is_story_run) it only freezes the player:
## StoryPlayer shows the level-complete card instead (Level_editor.md §9).
## Then it freezes the player, dims the screen and shows the run's numbers.
## Pressing Jump clears the run (GameState.reset_run()) and reloads the world scene,
## which puts everything back to the start.
##
## The UI is built in code in _ready(): a few Control nodes are clearer as code
## than as a .tscn here. Control nodes are Godot's UI building blocks; a
## CanvasLayer draws them fixed on screen, ignoring the game camera.
## Sizes are in the 320x180 internal resolution (stretch mode "viewport").

## The player to freeze when the run ends. Set in the Inspector.
@export var player: Player

## Seconds after the screen appears before Jump is accepted, so the jump you were
## holding while touching the goal doesn't skip the screen instantly.
const INPUT_DELAY: float = 0.6
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.7)
const TITLE_COLOR: Color = Color(0.4, 0.95, 0.5)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const HINT_COLOR: Color = Color(0.7, 0.7, 0.75)

var stats_label: Label
var input_delay_remaining: float = 0.0


func _ready() -> void:
	layer = 15  # above the game and the debug overlay, below the F2 room picker
	visible = false
	_build_ui()
	GameState.run_finished.connect(_on_run_finished)


func _process(delta: float) -> void:
	if visible:
		input_delay_remaining = maxf(input_delay_remaining - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or input_delay_remaining > 0.0:
		return
	if event.is_action_pressed("jump"):
		GameState.reset_run()
		# Reloads the scene that is running now (the world) from disk: every room,
		# enemy and object starts fresh.
		get_tree().reload_current_scene()


func _on_run_finished() -> void:
	if player != null:
		player.set_frozen(true)
	# Story Mode shows its own level-complete card and goes on to the next level.
	if GameState.is_story_run:
		return
	stats_label.text = "Deaths: %d\nTime: %s" % [GameState.death_count, GameState.get_formatted_time()]
	input_delay_remaining = INPUT_DELAY
	visible = true


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	# Anchors 0..1 on both axes = stretch over the whole screen.
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# A VBoxContainer stacks its children vertically; CenterContainer centers it.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)

	column.add_child(_make_label("Windbound - slice complete", 16, TITLE_COLOR))
	stats_label = _make_label("", 8, TEXT_COLOR)
	column.add_child(stats_label)
	column.add_child(_make_label("Press Jump (C) to play again", 8, HINT_COLOR))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	return label
