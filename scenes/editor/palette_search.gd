class_name PaletteSearch
extends VBoxContainer
## PaletteSearch: the search box at the top of the level editor's palette, and the
## list of matches it shows instead of the open tab while you type. Lives in
## EditorUI, which hides the tabs while `is_searching()`.
##
## Ctrl+F (editor_search) puts the cursor in the box. Every word typed must appear
## in an entry's name, tab or element ("ice slo" finds the four ice slopes).
## Enter chooses the first match, Esc empties the box; clicking a match chooses it.
## Either way the box lets go of the keyboard, so the editor's keys work again.
##
## A LineEdit is Godot's one-line text field. While it has the keyboard focus it
## eats the keys typed into it, so typing "e" doesn't switch on the eraser.

## A match was chosen: LevelEditor switches to it.
signal entry_chosen(entry: PaletteCatalog.Entry)
## The text changed: EditorUI shows the matches or the tabs again.
signal search_changed

## Matches shown at most (the palette is short; type more to narrow it down).
const MAX_RESULTS: int = 12

var search_box: LineEdit
var results: VBoxContainer
## The entries the list shows right now, best first.
var matches: Array[PaletteCatalog.Entry] = []


func _ready() -> void:
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search (Ctrl+F)"
	search_box.clear_button_enabled = true
	search_box.text_changed.connect(_on_text_changed)
	search_box.text_submitted.connect(_on_text_submitted)
	search_box.gui_input.connect(_on_box_input)
	add_child(search_box)
	results = VBoxContainer.new()
	results.visible = false
	add_child(results)


func is_searching() -> bool:
	return search_box.text.strip_edges() != ""


## Ctrl+F: the cursor goes into the box, its text selected (typing replaces it).
func focus() -> void:
	search_box.grab_focus()
	search_box.select_all()


## Empties the box and lets go of the keyboard.
func clear() -> void:
	search_box.text = ""
	_on_text_changed("")
	search_box.release_focus()


## Entries whose name, tab and element hold every word of `text` (any case).
static func find_matches(text: String) -> Array[PaletteCatalog.Entry]:
	var found: Array[PaletteCatalog.Entry] = []
	var words: PackedStringArray = text.to_lower().split(" ", false)
	if words.is_empty():
		return found
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		var haystack: String = ("%s %s %s" % [entry.display_name, entry.family, entry.element]).to_lower()
		var all_found: bool = true
		for word: String in words:
			all_found = all_found and haystack.contains(word)
		if all_found:
			found.append(entry)
	return found


func _on_text_changed(text: String) -> void:
	matches = find_matches(text)
	for child: Node in results.get_children():
		child.queue_free()
	for index: int in mini(matches.size(), MAX_RESULTS):
		var entry: PaletteCatalog.Entry = matches[index]
		var button: Button = Button.new()
		button.text = entry.display_name
		button.icon = PaletteIcons.get_icon(entry)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = entry.family if entry.family != "" else "Tool"
		button.pressed.connect(_choose.bind(entry))
		results.add_child(button)
	results.visible = is_searching()
	if is_searching() and matches.is_empty():
		var none: Label = Label.new()
		none.text = "Nothing matches."
		results.add_child(none)
	search_changed.emit()


## Enter: the first match.
func _on_text_submitted(_text: String) -> void:
	if not matches.is_empty():
		_choose(matches[0])


## Esc inside the box: empty it (and don't let Esc reach the editor, which would
## ask to leave).
func _on_box_input(event: InputEvent) -> void:
	if event.is_action_pressed("editor_back"):
		clear()
		accept_event()


func _choose(entry: PaletteCatalog.Entry) -> void:
	entry_chosen.emit(entry)
	clear()
