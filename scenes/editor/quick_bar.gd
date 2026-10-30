class_name QuickBar
extends HBoxContainer
## QuickBar: the row of recently used brushes and objects at the bottom of the
## level editor's palette. Keys 1-9 (actions editor_quick_1 ... editor_quick_9)
## choose slot 1-9. Lives in EditorUI; LevelEditor tells it what was chosen
## (note_chosen) and calls choose_slot() on a digit key.
##
## The slots stay put: a new thing takes the next free slot, and once all 9 are
## used it replaces the one used longest ago. Things that move up to the front
## on every use would change their key all the time, and you couldn't learn them.
## Tools (Select, Eraser, Brush, Fill) never get a slot: they have their own keys.

## A slot was clicked (or its key pressed): LevelEditor switches to that entry.
signal entry_chosen(entry: PaletteCatalog.Entry)

const SLOT_COUNT: int = 9
## A slot button's size, px (the palette is 92 px wide: 9 small squares fit).
const SLOT_SIZE: Vector2 = Vector2(9, 12)

## The entry in each slot (null = empty), and when each was last used.
var slot_entries: Array[PaletteCatalog.Entry] = []
var slot_last_used: Array[int] = []
var slot_buttons: Array[Button] = []
## Counts uses, so "used longest ago" is the smallest number.
var use_counter: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 1)
	for slot: int in SLOT_COUNT:
		slot_entries.append(null)
		slot_last_used.append(0)
		var button: Button = Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE  # Space must pan, not press it
		button.expand_icon = true
		button.pressed.connect(choose_slot.bind(slot))
		add_child(button)
		slot_buttons.append(button)
	_refresh()


## `entry` was just chosen (from anywhere): it gets a slot, or its slot is "used".
func note_chosen(entry: PaletteCatalog.Entry) -> void:
	if entry == null or entry.family == "":
		return  # a tool: it has its own key
	use_counter += 1
	var slot: int = slot_entries.find(entry)
	if slot == -1:
		slot = slot_entries.find(null)
	if slot == -1:
		# All full: the one used longest ago makes room.
		slot = 0
		for other: int in SLOT_COUNT:
			if slot_last_used[other] < slot_last_used[slot]:
				slot = other
	slot_entries[slot] = entry
	slot_last_used[slot] = use_counter
	_refresh()


## Chooses the entry in `slot` (0-based), if there is one.
func choose_slot(slot: int) -> void:
	if slot >= 0 and slot < SLOT_COUNT and slot_entries[slot] != null:
		entry_chosen.emit(slot_entries[slot])


## Each button shows its entry's picture, its key and name in the tooltip.
func _refresh() -> void:
	for slot: int in SLOT_COUNT:
		var entry: PaletteCatalog.Entry = slot_entries[slot]
		var button: Button = slot_buttons[slot]
		button.icon = PaletteIcons.get_icon(entry) if entry != null else null
		button.disabled = entry == null
		button.tooltip_text = "%d: %s" % [slot + 1, entry.display_name] if entry != null else "%d: empty (things you use land here)" % (slot + 1)
