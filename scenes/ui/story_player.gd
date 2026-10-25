class_name StoryPlayer
extends CanvasLayer
## StoryPlayer: plays Story Mode's levels back to back (Level_editor.md §9).
##
## The Story screen calls StoryPlayer.start(story, index). It makes ONE StoryPlayer
## and adds it to the tree's root, next to the running scene, not inside it: the
## running scene is replaced at every level (change_scene_to_file), and a node
## under the root survives that. It then:
##   1. resets the run (GameState: timer, deaths), sets GameState.is_story_run and
##      opens the entry's world scene,
##   2. hears GameState.run_finished when the player touches that world's Goal (the
##      world's EndScreen stays hidden in a story run), saves the progress
##      (StoryProgress) and shows the level-complete card: title, time, deaths,
##   3. on Jump, opens the next entry; after the last one it shows the end card with
##      the totals of this sitting, and Jump goes back to the Story screen.
## Leaving a world through the pause menu goes to the main menu, which calls stop().
##
## Like the EndScreen, its UI is built in code at the game's 320x180, and it
## ignores Jump for a moment so the jump held while touching the goal doesn't skip
## the card. process_mode ALWAYS: it works even while the game is paused.

const STORY_SCREEN_SCENE: String = "res://scenes/ui/story_screen.tscn"
const INPUT_DELAY: float = 0.6
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.7)
const TITLE_COLOR: Color = Color(0.4, 0.95, 0.5)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const HINT_COLOR: Color = Color(0.7, 0.7, 0.75)

## The one StoryPlayer while a story run is on (null otherwise).
static var current: StoryPlayer = null
## How a scene is opened: change_scene_to_file unless set. The smoke test sets it
## to a function that only writes the path down (changing scene would end the test).
static var scene_opener: Callable = Callable()

var story: StoryList
## The entry being played (or whose card is up).
var entry_index: int = 0
## This sitting's totals, for the end card.
var total_time: float = 0.0
var total_deaths: int = 0
## True while the end card (after the last level) is up.
var is_showing_end: bool = false
var input_delay_remaining: float = 0.0

var card: Control
var title_label: Label
var stats_label: Label
var hint_label: Label


## Starts playing `story` at entry `index`. Any run already going ends first.
static func start(new_story: StoryList, index: int) -> void:
	stop()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	current = StoryPlayer.new()
	current.name = "StoryPlayer"
	current.story = new_story
	tree.root.add_child(current)
	current.play_entry(index)


## Ends the story run (the main menu and the Story screen call it).
static func stop() -> void:
	GameState.is_story_run = false
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null


func _ready() -> void:
	layer = 16  # over the world's own end screen (15) and HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	card.visible = false
	GameState.run_finished.connect(_on_run_finished)


func _process(delta: float) -> void:
	if card.visible:
		input_delay_remaining = maxf(input_delay_remaining - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if card.visible and input_delay_remaining <= 0.0 and event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		advance()


## Opens the world of entry `index`, with a fresh timer and death count.
func play_entry(index: int) -> void:
	entry_index = index
	card.visible = false
	GameState.reset_run()
	GameState.is_story_run = true
	_open_scene(story.entries[index].scene_path)


## Jump on a card: the next level, the end card after the last, or back to the
## Story screen from the end card.
func advance() -> void:
	if is_showing_end:
		stop()
		_open_scene(STORY_SCREEN_SCENE)
	elif entry_index + 1 < story.entries.size():
		play_entry(entry_index + 1)
	else:
		_show_end_card()


func _on_run_finished() -> void:
	if not GameState.is_story_run:
		return
	var entry: StoryEntry = story.entries[entry_index]
	var time: float = GameState.elapsed_time
	var deaths: int = GameState.death_count
	StoryProgress.record_finish(entry.scene_path, time, deaths)
	total_time += time
	total_deaths += deaths
	title_label.text = "Level complete"
	stats_label.text = "%s\nTime: %s    Deaths: %d\nBest: %s, %d deaths" % [entry.title, StoryProgress.format_time(time), deaths,
		StoryProgress.format_time(StoryProgress.get_best_time(entry.scene_path)), StoryProgress.get_best_deaths(entry.scene_path)]
	var is_last: bool = entry_index + 1 >= story.entries.size()
	hint_label.text = "Press Jump (C) to finish" if is_last else "Press Jump (C): next, %s" % story.entries[entry_index + 1].title
	_show_card()


func _show_end_card() -> void:
	is_showing_end = true
	title_label.text = "Story complete!"
	stats_label.text = "%d levels\nTotal time: %s    Total deaths: %d" % [story.entries.size(),
		StoryProgress.format_time(total_time), total_deaths]
	hint_label.text = "Press Jump (C) to go back"
	_show_card()


func _show_card() -> void:
	input_delay_remaining = INPUT_DELAY
	card.visible = true


func _open_scene(path: String) -> void:
	if scene_opener.is_valid():
		scene_opener.call(path)
	else:
		get_tree().change_scene_to_file(path)


func _build_ui() -> void:
	# One Control holding the card, so showing or hiding it is one switch.
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(card)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	title_label = _make_label(16, TITLE_COLOR)
	column.add_child(title_label)
	stats_label = _make_label(8, TEXT_COLOR)
	column.add_child(stats_label)
	hint_label = _make_label(8, HINT_COLOR)
	column.add_child(hint_label)


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	return label
