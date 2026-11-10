class_name RelicView
extends Control
## RelicView: the level's relics in the pause menu (Collectibles.md §2.2). Every
## element has its own relic of four quarters, and a level can hold several, so the
## view shows ONE relic at a time, a page per element: the round medallion with
## its found quarters in the element's color and the others dark (RelicPainter),
## its name above, "2/4" under it, and "< 1/3 >" when there's more than one page.
## Left / Right flip pages (PauseMenu passes them on: show_page()).
##
## Found = secured this run (GameState.secured_shards) plus, in a Story Mode run,
## saved in an earlier sitting (StoryProgress). The pages: every element that has
## shards placed in the level, or found ones. It hides itself when there are none.
##
## PauseMenu calls refresh(world) every time it opens: `world` is the running
## level's root (its RoomManager), so a play-test copy counts only its own shards,
## not the editor's level shown under it.
##
## Godot concepts used:
##   - A custom Control: a UI node that draws itself in _draw() like a Node2D does;
##     custom_minimum_size tells its container how much room to give it.

## The relic's radius on screen, px (in the 320x180 view).
const RELIC_RADIUS: float = 16.0
## Text rows above and below the relic, px.
const LINE_HEIGHT: float = 10.0
const FONT_SIZE: int = 8
const TITLE_COLOR: Color = Color(1.0, 1.0, 1.0)
const TEXT_COLOR: Color = Color(0.85, 0.85, 0.9)
const HINT_COLOR: Color = Color(0.6, 0.6, 0.68)
const WIDTH: float = 64.0

## element -> Array of found slots, for every page.
var found: Dictionary = {}
## The elements that have a page, in Element order.
var page_elements: Array[int] = []
## The page shown (index into page_elements). Kept between openings.
var page_index: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, RELIC_RADIUS * 2.0 + 4.0 + LINE_HEIGHT * 3.0)


## Reads what's found and which relics the level has.
func refresh(world: Node) -> void:
	found = {}
	for element: int in GameState.secured_shards:
		found[element] = (GameState.secured_shards[element] as Array).duplicate()
	if GameState.is_story_run and world != null:
		var saved: Dictionary = StoryProgress.get_shards(world.scene_file_path)
		for element: int in saved:
			if not found.has(element):
				found[element] = []
			for slot: int in saved[element]:
				if not (found[element] as Array).has(slot):
					(found[element] as Array).append(slot)
	var elements: Dictionary = {}
	for element: int in found:
		elements[element] = true
	for element: int in _get_level_shard_elements(world):
		elements[element] = true
	page_elements.clear()
	for element: int in RelicShard.Element.values():
		if elements.has(element):
			page_elements.append(element)
	page_index = clampi(page_index, 0, maxi(page_elements.size() - 1, 0))
	visible = not page_elements.is_empty()
	queue_redraw()


## Flips `delta` pages (wrapping round). Returns true if there was another page.
func show_page(delta: int) -> bool:
	if page_elements.size() < 2:
		return false
	page_index = posmod(page_index + delta, page_elements.size())
	queue_redraw()
	return true


## The element of the page shown (-1 when there are none).
func get_shown_element() -> int:
	return page_elements[page_index] if not page_elements.is_empty() else -1


## The elements of the relic shards placed in `world` (through RelicShard.GROUP).
func _get_level_shard_elements(world: Node) -> Array[int]:
	var elements: Array[int] = []
	for node: Node in get_tree().get_nodes_in_group(RelicShard.GROUP):
		var shard: RelicShard = node as RelicShard
		if (world == null or world.is_ancestor_of(shard)) and not elements.has(shard.element):
			elements.append(shard.element)
	return elements


func _draw() -> void:
	if page_elements.is_empty():
		return
	var element: int = get_shown_element()
	var found_slots: Array = found.get(element, [])
	_draw_centered_text(RelicShard.get_relic_name(element), LINE_HEIGHT - 2.0, TITLE_COLOR)
	var center: Vector2 = Vector2(size.x / 2.0, LINE_HEIGHT + 2.0 + RELIC_RADIUS)
	RelicPainter.draw_relic(self, element, found_slots, center, RELIC_RADIUS)
	var count_text: String = "complete" if found_slots.size() >= RelicShard.SHARDS_PER_RELIC \
		else "%d/%d" % [found_slots.size(), RelicShard.SHARDS_PER_RELIC]
	var below: float = LINE_HEIGHT + 4.0 + RELIC_RADIUS * 2.0
	_draw_centered_text(count_text, below + LINE_HEIGHT - 2.0, TEXT_COLOR)
	if page_elements.size() > 1:
		_draw_centered_text("< %d/%d >" % [page_index + 1, page_elements.size()], below + LINE_HEIGHT * 2.0 - 2.0, HINT_COLOR)


## One line of text centered across the view, its baseline at `baseline_y`.
func _draw_centered_text(text: String, baseline_y: float, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2((size.x - text_width) / 2.0, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
