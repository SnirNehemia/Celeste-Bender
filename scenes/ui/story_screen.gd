class_name StoryScreen
extends Control
## Story screen (Level_editor.md §9): main menu -> Story Mode. Plays the levels of
## the StoryList (res://levels/story.tres) in order, editor levels and chapter
## worlds alike, with progress saved by StoryProgress.
##
## Pages, one shown at a time (like the main menu):
##   - Main:   Continue (the first level not finished) · Level select · New run
##             (asks first) · Edit order (dev builds only) · Back
##   - Select: every entry: finished ones with a check mark, best time and deaths,
##             the next one open, the rest locked (greyed out)
##   - Edit:   (dev builds) the list; Shift+Up/Down moves the selected entry; Add,
##             Remove, Rename. Every change is saved to story.tres at once.
##   - Add:    the levels in res://levels/ and the chapter worlds (MainMenu.CHAPTERS)
## Playing hands over to StoryPlayer, which runs the levels back to back.
##
## Keyboard: arrows + Enter or C pick, Esc goes back a page (from Main: to the main
## menu). The mouse works too. Built in code at the game's 320x180, hence the small
## fonts. Shift+Up/Down are the InputMap actions story_move_up / story_move_down.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.13)
const FONT_SIZE: int = 8
const TITLE_FONT_SIZE: int = 16
const HINT_ALPHA: float = 0.6
const LIST_SIZE: Vector2 = Vector2(260, 92)
const SELECT_LIST_SIZE: Vector2 = Vector2(280, 100)
## The check mark for finished levels: ✓ if the font has it, else a plain *.
const CHECK_MARK: String = "✓"
const CHECK_MARK_FALLBACK: String = "*"

var story: StoryList
var main_page: VBoxContainer
var select_page: VBoxContainer
var edit_page: VBoxContainer
var add_page: VBoxContainer
var continue_button: Button
var select_button: Button
var edit_button: Button
## The Select page's entry buttons, rebuilt each time it opens.
var select_list: VBoxContainer
var edit_list: ItemList
var add_list: ItemList
## [title, scene path] per item of the Add list.
var add_candidates: Array = []
var prompt: PromptPanel
## The button that opened the current page (focus goes back to it on Back).
var opened_from: Button = null


func _ready() -> void:
	StoryPlayer.stop()  # back from a finished run: it's over
	story = StoryList.load_story()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	column.add_child(_make_label("STORY MODE", TITLE_FONT_SIZE))

	main_page = _build_main_page()
	column.add_child(main_page)
	select_page = _build_select_page()
	column.add_child(select_page)
	edit_page = _build_edit_page()
	column.add_child(edit_page)
	add_page = _build_add_page()
	column.add_child(add_page)

	prompt = PromptPanel.new()
	add_child(prompt)
	prompt.closed.connect(_focus_current_page)
	_show_page(main_page, null)


# --- Pages ---

func _build_main_page() -> VBoxContainer:
	var page: VBoxContainer = _make_page()
	continue_button = _make_button("Continue", _on_continue_pressed)
	page.add_child(continue_button)
	select_button = _make_button("Level select", func() -> void: _show_page(select_page, select_button))
	page.add_child(select_button)
	page.add_child(_make_button("New run", _on_new_run_pressed))
	edit_button = _make_button("Edit order", func() -> void: _show_page(edit_page, edit_button))
	# Editing writes res://levels/story.tres: only from the Godot project.
	if not OS.has_feature("editor"):
		edit_button.visible = false
	page.add_child(edit_button)
	page.add_child(_make_button("Back", _go_to_main_menu))
	page.add_child(_make_hint("Arrows to choose, Enter or C to start, Esc: back"))
	return page


func _build_select_page() -> VBoxContainer:
	var page: VBoxContainer = _make_page()
	# A ScrollContainer shows part of a taller child and scrolls to the focused
	# button (follow_focus), so a long story still fits on the 180 px screen.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = SELECT_LIST_SIZE
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	select_list = VBoxContainer.new()
	select_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_list.add_theme_constant_override("separation", 2)
	scroll.add_child(select_list)
	page.add_child(_make_button("Back", _go_back))
	return page


func _build_edit_page() -> VBoxContainer:
	var page: VBoxContainer = _make_page()
	edit_list = ItemList.new()
	edit_list.custom_minimum_size = LIST_SIZE
	edit_list.add_theme_font_size_override("font_size", FONT_SIZE)
	edit_list.item_activated.connect(func(_index: int) -> void: _on_rename_pressed())
	page.add_child(edit_list)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	page.add_child(row)
	row.add_child(_make_button("Add", func() -> void: _show_page(add_page, null)))
	row.add_child(_make_button("Remove", _on_remove_pressed))
	row.add_child(_make_button("Rename", _on_rename_pressed))
	row.add_child(_make_button("Back", _go_back))
	page.add_child(_make_hint("Shift+Up/Down: move.  Enter: rename.  Saved at once."))
	return page


func _build_add_page() -> VBoxContainer:
	var page: VBoxContainer = _make_page()
	add_list = ItemList.new()
	add_list.custom_minimum_size = LIST_SIZE
	add_list.add_theme_font_size_override("font_size", FONT_SIZE)
	add_list.item_activated.connect(func(index: int) -> void: _add_candidate(index))
	page.add_child(add_list)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	page.add_child(row)
	row.add_child(_make_button("Add", func() -> void:
		var selected: PackedInt32Array = add_list.get_selected_items()
		if not selected.is_empty():
			_add_candidate(selected[0])))
	row.add_child(_make_button("Back", func() -> void: _show_page(edit_page, null)))
	page.add_child(_make_hint("Enter: add after the selected entry"))
	return page


## Shows `page` (filled fresh from the story and progress), hides the others, and
## focuses its first control. `from_button`: where focus returns on Back.
func _show_page(page: VBoxContainer, from_button: Button) -> void:
	if from_button != null:
		opened_from = from_button
	for each_page: VBoxContainer in [main_page, select_page, edit_page, add_page]:
		each_page.visible = each_page == page
	if page == main_page:
		_refresh_main_page()
	elif page == select_page:
		_refresh_select_page()
	elif page == edit_page:
		_refresh_edit_list(_selected_edit_index())
	elif page == add_page:
		_refresh_add_list()
	_focus_current_page()


func _focus_current_page() -> void:
	if edit_page.visible:
		edit_list.grab_focus()
		return
	if add_page.visible:
		add_list.grab_focus()
		return
	var page: VBoxContainer = main_page if main_page.visible else select_page
	var buttons: Array[Node] = select_list.get_children() if page == select_page else page.get_children()
	for child: Node in buttons:
		var button: Button = child as Button
		if button != null and button.visible and not button.disabled:
			button.grab_focus()
			return


func _go_back() -> void:
	_show_page(main_page, null)
	if opened_from != null:
		opened_from.grab_focus()


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _refresh_main_page() -> void:
	var index: int = StoryProgress.get_continue_index(story)
	continue_button.disabled = story.entries.is_empty()
	if story.entries.is_empty():
		continue_button.text = "Continue (the story is empty)"
	elif index == -1:
		continue_button.text = "Play again from the start (all done)"
	else:
		continue_button.text = "Continue: %s" % story.entries[index].title
	select_button.disabled = story.entries.is_empty()


func _refresh_select_page() -> void:
	for child: Node in select_list.get_children():
		select_list.remove_child(child)
		child.queue_free()
	for index: int in story.entries.size():
		var button: Button = _make_button(get_entry_label(index), _play.bind(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not StoryProgress.is_open(story, index)
		select_list.add_child(button)


## The Select page's text for entry `index`: a check mark with the best time and
## deaths when finished, "(locked)" when it can't be played yet.
func get_entry_label(index: int) -> String:
	var entry: StoryEntry = story.entries[index]
	if StoryProgress.is_finished(entry.scene_path):
		return "%s %s   %s, %d deaths" % [_check_mark(), entry.title,
			StoryProgress.format_time(StoryProgress.get_best_time(entry.scene_path)), StoryProgress.get_best_deaths(entry.scene_path)]
	if not StoryProgress.is_open(story, index):
		return "   %s  (locked)" % entry.title
	return "   %s" % entry.title


func _check_mark() -> String:
	return CHECK_MARK if get_theme_default_font().has_char(CHECK_MARK.unicode_at(0)) else CHECK_MARK_FALLBACK


# --- Playing ---

func _on_continue_pressed() -> void:
	_play(maxi(StoryProgress.get_continue_index(story), 0))


func _play(index: int) -> void:
	if story.entries.is_empty() or not StoryProgress.is_open(story, index):
		return
	StoryPlayer.start(story, index)


func _on_new_run_pressed() -> void:
	prompt.ask("New run: forget every finished level, best time and deaths?", [["New run", func(_text: String) -> void:
		StoryProgress.reset_all()
		_refresh_main_page()]])


# --- Edit order (dev builds) ---

func _input(event: InputEvent) -> void:
	# Before the list sees the key (_input runs before GUI input): Shift+Up/Down
	# moves the entry instead of the selection. Checked first, because plain Up's
	# action matches Shift+Up too.
	if not edit_page.visible or prompt.visible:
		return
	if event.is_action_pressed("story_move_up", true):
		move_selected(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("story_move_down", true):
		move_selected(1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if prompt.visible:
		return  # it handles its own keys
	# C (jump) also presses the focused button, as in the main menu.
	if event.is_action_pressed("jump"):
		var focused: Button = get_viewport().gui_get_focus_owner() as Button
		if focused != null and not focused.disabled:
			focused.pressed.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if main_page.visible:
			_go_to_main_menu()
		elif add_page.visible:
			_show_page(edit_page, null)
		else:
			_go_back()


## Moves the selected entry up (-1) or down (1) and saves.
func move_selected(steps: int) -> void:
	var index: int = _selected_edit_index()
	if index < 0:
		return
	var new_index: int = story.move_entry(index, steps)
	if new_index != index:
		story.save_story()
	_refresh_edit_list(new_index)


## Adds an entry after the selected one (or at the end) and saves.
func add_entry(title: String, scene_path: String) -> void:
	var index: int = _selected_edit_index() + 1 if _selected_edit_index() >= 0 else story.entries.size()
	story.entries.insert(index, StoryEntry.new(title, scene_path))
	story.save_story()
	_refresh_edit_list(index)


func remove_entry(index: int) -> void:
	story.entries.remove_at(index)
	story.save_story()
	_refresh_edit_list(mini(index, story.entries.size() - 1))


func rename_entry(index: int, title: String) -> void:
	story.entries[index].title = title
	story.save_story()
	_refresh_edit_list(index)


func _on_remove_pressed() -> void:
	var index: int = _selected_edit_index()
	if index < 0:
		return
	prompt.ask("Remove \"%s\" from the story? (Its progress is kept.)" % story.entries[index].title,
		[["Remove", func(_text: String) -> void: remove_entry(index)]])


func _on_rename_pressed() -> void:
	var index: int = _selected_edit_index()
	if index < 0:
		return
	prompt.ask("Title shown in Story Mode:", [["OK", func(text: String) -> void:
		if text.strip_edges() != "":
			rename_entry(index, text.strip_edges())]], story.entries[index].title)


func _add_candidate(index: int) -> void:
	var candidate: Array = add_candidates[index]
	_show_page(edit_page, null)
	add_entry(candidate[0], candidate[1])


func _refresh_edit_list(select_index: int) -> void:
	edit_list.clear()
	for entry: StoryEntry in story.entries:
		edit_list.add_item(entry.title)
	if select_index >= 0 and select_index < story.entries.size():
		edit_list.select(select_index)
		edit_list.ensure_current_is_visible()


## The Add page: every editor level, then every chapter world.
func _refresh_add_list() -> void:
	add_candidates = []
	for path: String in LevelStorage.list_levels():
		add_candidates.append([LevelStorage.read_title(path), path])
	for chapter: Array in MainMenu.CHAPTERS:
		add_candidates.append([String(chapter[0]).replace("  -  ", " - "), String(chapter[1])])
	add_list.clear()
	for candidate: Array in add_candidates:
		var kind: String = "Level" if String(candidate[1]).begins_with(LevelStorage.levels_dir) else "Chapter"
		add_list.add_item("%s: %s" % [kind, candidate[0]])
	if not add_candidates.is_empty():
		add_list.select(0)


func _selected_edit_index() -> int:
	var selected: PackedInt32Array = edit_list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


# --- Small builders ---

func _make_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	return page


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


func _make_hint(text: String) -> Label:
	var hint: Label = _make_label(text, FONT_SIZE)
	hint.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
	return hint
