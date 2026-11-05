class_name TouchScroll
extends RefCounted
## Finger scrolling for lists (ScrollContainer) on a phone. On a touchscreen a
## finger dragged over a list's buttons doesn't scroll it: the buttons take the
## touch. A screen's _input passes each InputEventScreenDrag here, and the list
## under the finger scrolls by the finger's movement.
## Used by EditorUI (palette, property panel, help) and RoomPicker.

## Scrolls the innermost visible ScrollContainer under `root` that contains the
## finger. Returns true if one scrolled.
static func scroll_under(root: Node, drag: InputEventScreenDrag) -> bool:
	var target: ScrollContainer = null
	# find_children(pattern, type, recursive, owned): every ScrollContainer below
	# root, parents before children, so the last match is the innermost one.
	for node: Node in root.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = node as ScrollContainer
		if scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(drag.position):
			target = scroll
	if target == null:
		return false
	# Finger moves up -> the list moves up with it -> it shows what's further down.
	target.scroll_vertical -= roundi(drag.relative.y)
	return true
