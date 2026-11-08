class_name LevelLibrary
extends Control
## Level library: the first screen of the Level Editor (Level_editor.md §4).
## Opened from the main menu. Lists every level in res://levels/ and lets you
## make a new one, open it in the editor, play it, duplicate, rename or delete it.
##
## All file work goes through LevelStorage (scenes/editor/level_storage.gd); this
## script is only the UI. Mouse and keyboard both work:
##   - the list is an ItemList: click or arrows to select, double-click or Enter to open
##   - Tab moves between the list and the buttons, Esc goes back to the main menu
## New, Rename and Delete ask first in a PromptPanel (scenes/ui/prompt_panel.gd).
##
## Built in code in _ready(), like the main menu. Sizes are in the game's 320x180
## internal resolution, hence the small fonts.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const LEVEL_EDITOR_SCENE: String = "res://scenes/editor/level_editor.tscn"
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.13)
const ERROR_COLOR: Color = Color(1.0, 0.45, 0.4)
const FONT_SIZE: int = 8
const TITLE_FONT_SIZE: int = 16
const HINT_ALPHA: float = 0.6
const LIST_SIZE: Vector2 = Vector2(260, 92)
const DEFAULT_NEW_TITLE: String = "New level"

## The level to select when the library opens (set by the editor when you leave it,
## so you come back to the level you were on). A static var survives scene changes.
static var path_to_select: String = ""

## Level file paths, in the same order as the list's items.
var level_paths: Array[String] = []

var level_list: ItemList
## Buttons that need a selected level; disabled when the list is empty.
var selection_buttons: Array[Button] = []
var status_label: Label
var prompt: PromptPanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)

	var title: Label = _make_label("LEVEL EDITOR", TITLE_FONT_SIZE)
	column.add_child(title)

	level_list = ItemList.new()
	level_list.custom_minimum_size = LIST_SIZE
	level_list.add_theme_font_size_override("font_size", FONT_SIZE)
	# item_activated: double-click or Enter on an item.
	level_list.item_activated.connect(func(_index: int) -> void: _on_open_pressed())
	level_list.item_selected.connect(func(_index: int) -> void: _update_buttons())
	column.add_child(level_list)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 3)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(button_row)
	button_row.add_child(_make_button("New", _on_new_pressed))
	for entry: Array in [["Open", _on_open_pressed], ["Play", _on_play_pressed],
			["Duplicate", _on_duplicate_pressed], ["Rename", _on_rename_pressed],
			["Delete", _on_delete_pressed]]:
		var button: Button = _make_button(entry[0], entry[1])
		selection_buttons.append(button)
		button_row.add_child(button)
	button_row.add_child(_make_button("Back", _go_back))

	status_label = _make_label("", FONT_SIZE)
	column.add_child(status_label)
	var hint: Label = _make_label("Double-click or Enter opens. Tab: buttons. Esc: back", FONT_SIZE)
	hint.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
	column.add_child(hint)

	prompt = PromptPanel.new()
	add_child(prompt)
	prompt.closed.connect(func() -> void: level_list.grab_focus())

	# Back from the editor: the level you were on. Fresh from the menu: the level
	# opened last time, even in an earlier session (Enter reopens it).
	var select_path: String = path_to_select if path_to_select != "" else LevelStorage.get_last_opened()
	_refresh_list(select_path)
	path_to_select = ""
	var last_title: String = LevelStorage.read_title(select_path) if select_path != "" and level_paths.has(select_path) else ""
	if last_title != "" and level_paths.size() > 0:
		_set_status("Last opened: %s (Enter)" % last_title, false)
	level_list.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# The prompt handles its own Esc (in _input, before this).
	if event.is_action_pressed("ui_cancel") and not prompt.visible:
		get_viewport().set_input_as_handled()
		_go_back()


# --- The list ---

## Re-reads the levels folder and fills the list, selecting `select_path` if given
## (or the first level).
func _refresh_list(select_path: String) -> void:
	level_paths = LevelStorage.list_levels()
	level_list.clear()
	for path: String in level_paths:
		level_list.add_item(LevelStorage.read_title(path))
	if not level_paths.is_empty():
		var index: int = maxi(level_paths.find(select_path), 0)
		level_list.select(index)
		level_list.ensure_current_is_visible()
	_update_buttons()
	if level_paths.is_empty():
		_set_status("No levels yet: press New.", false)


func _update_buttons() -> void:
	var has_selection: bool = _selected_path() != ""
	for button: Button in selection_buttons:
		button.disabled = not has_selection


## The selected level's path, or "" if nothing is selected.
func _selected_path() -> String:
	var selected: PackedInt32Array = level_list.get_selected_items()
	if selected.is_empty():
		return ""
	return level_paths[selected[0]]


# --- Actions ---

func _on_new_pressed() -> void:
	prompt.ask("Name of the new level:", [["OK", func(title: String) -> void:
		var path: String = LevelStorage.create_level(_clean_title(title))
		if path == "":
			_set_status("Could not save the new level.", true)
			return
		_refresh_list(path)
		_set_status("Made %s" % path.get_file(), false)]], DEFAULT_NEW_TITLE)


## Opens the selected level in the editor (scenes/editor/level_editor.tscn).
func _on_open_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		return
	# The editor reads which level to open from this static var in its _ready().
	LevelEditor.path_to_open = path
	get_tree().change_scene_to_file(LEVEL_EDITOR_SCENE)


## Plays the selected level as saved.
func _on_play_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		return
	var packed: PackedScene = LevelStorage.load_level(path)
	if packed == null:
		_set_status("Could not load %s" % path.get_file(), true)
		return
	GameState.reset_run()
	# change_scene_to_packed: like change_scene_to_file, but with the scene we just
	# loaded fresh (LevelStorage skips Godot's cache, so it's the latest save).
	get_tree().change_scene_to_packed(packed)


func _on_duplicate_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		return
	var new_path: String = LevelStorage.duplicate_level(path)
	if new_path == "":
		_set_status("Could not duplicate %s" % path.get_file(), true)
		return
	_refresh_list(new_path)
	_set_status("Copied to %s" % new_path.get_file(), false)


func _on_rename_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		return
	prompt.ask("New name (the file keeps its name):", [["OK", func(title: String) -> void:
		if LevelStorage.rename_level(path, _clean_title(title)) != OK:
			_set_status("Could not rename %s" % path.get_file(), true)
			return
		_refresh_list(path)
		_set_status("Renamed.", false)]], LevelStorage.read_title(path))


func _on_delete_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		return
	var title: String = LevelStorage.read_title(path)
	prompt.ask("Delete \"%s\" for good?" % title, [["Delete", func(_text: String) -> void:
		if LevelStorage.delete_level(path) != OK:
			_set_status("Could not delete %s" % path.get_file(), true)
			return
		_refresh_list("")
		_set_status("Deleted \"%s\"." % title, false)]])


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## An empty title becomes the default one, so no level ends up nameless.
func _clean_title(title: String) -> String:
	var stripped: String = title.strip_edges()
	return stripped if stripped != "" else DEFAULT_NEW_TITLE


func _set_status(text: String, is_error: bool) -> void:
	status_label.text = text
	status_label.modulate = ERROR_COLOR if is_error else Color.WHITE


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_pressed)
	return button


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
