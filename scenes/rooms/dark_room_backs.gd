class_name DarkRoomBacks
extends RefCounted
## DarkRoomBacks: how DARK ROOMS (Room.is_dark) look when they're only seen from
## another depth, in the BackRoomView's layers behind the room you're in. Owned by
## the BackRoomView, which calls apply() for each layer every frame.
##
## Why it's needed: the DarkRoomOverlay only darkens what the FRONT camera sees, so a
## dark room one depth behind showed its whole layout through the open air of the
## rooms in front, before you ever stepped in. Instead, the layer's haze shader
## (back_room_haze.gdshader) gets each dark room's rectangle in the layer's picture:
## there the room is hidden and only a see-through black is left (dimmed by
## FireTuning.dark_back_dim), so the backdrop or a deeper layer shows through,
## darkened. A LIT BRAZIER in such a room shows as a faint warm glow (a hint that
## something burns in there, without lighting up the layout).
##
## During a gate's step the layer behind comes forward (looks_back 1 -> 0), and its
## dim eases to the front's darkness (dark_room_darkness), so stepping into a dark
## room doesn't pop from dim to black at the swap.

## The shader's array sizes (back_room_haze.gdshader MAX_DARK_RECTS / MAX_DARK_GLOWS).
const MAX_DARK_RECTS: int = 8
const MAX_DARK_GLOWS: int = 16

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
## The rooms of the level.
var rooms: Array[Room] = []
## Each dark room's braziers, found once (room instance id -> Array[Brazier]).
var _braziers_by_room: Dictionary = {}


func _init(level_rooms: Array[Room]) -> void:
	rooms = level_rooms


## Hands `material` (one layer's haze shader) the dark rooms at `depth`, as seen by a
## camera centered at `view_center` drawing `view_size` px, and their lit braziers.
## `looks_back`: how far back the layer looks now (1 = one depth, less during a step).
func apply(material: ShaderMaterial, depth: int, view_center: Vector2, view_size: Vector2, looks_back: float) -> void:
	var corner: Vector2 = view_center - view_size / 2.0  # world px at the picture's (0, 0)
	var view_rect: Rect2 = Rect2(corner, view_size)
	var rect_array: PackedVector4Array = PackedVector4Array()
	rect_array.resize(MAX_DARK_RECTS)
	var glow_array: PackedVector4Array = PackedVector4Array()
	glow_array.resize(MAX_DARK_GLOWS)
	var rect_count: int = 0
	var glow_count: int = 0
	for room: Room in rooms:
		if rect_count >= MAX_DARK_RECTS:
			break
		if not is_instance_valid(room) or not room.is_dark or room.get_depth() != depth:
			continue
		var bounds: Rect2 = room.get_bounds()
		if not bounds.intersects(view_rect):
			continue
		rect_array[rect_count] = Vector4(bounds.position.x - corner.x, bounds.position.y - corner.y, bounds.size.x, bounds.size.y)
		rect_count += 1
		for brazier: Brazier in _get_braziers(room):
			if glow_count >= MAX_DARK_GLOWS:
				break
			if not is_instance_valid(brazier) or not brazier.is_burning():
				continue
			var spot: Vector2 = brazier.get_fire_rect().get_center() - corner
			glow_array[glow_count] = Vector4(spot.x, spot.y, fire_tuning.dark_back_glow_radius, fire_tuning.dark_back_glow_strength)
			glow_count += 1
	material.set_shader_parameter(&"dark_rects", rect_array)
	material.set_shader_parameter(&"dark_rect_count", rect_count)
	material.set_shader_parameter(&"dark_glows", glow_array)
	material.set_shader_parameter(&"dark_glow_count", glow_count)
	# One depth back or more: dimmed; coming forward in a step: toward the front's dark.
	var dim: float = lerpf(fire_tuning.dark_room_darkness, fire_tuning.dark_back_dim, clampf(looks_back, 0.0, 1.0))
	material.set_shader_parameter(&"dark_dim", dim)
	material.set_shader_parameter(&"dark_glow_color", FlameMerge.GLOW_COOL_COLOR)


## The braziers anywhere under `room` (searched once, then remembered).
func _get_braziers(room: Room) -> Array:
	var key: int = room.get_instance_id()
	if not _braziers_by_room.has(key):
		var found: Array[Brazier] = []
		_collect_braziers(room, found)
		_braziers_by_room[key] = found
	return _braziers_by_room[key]


func _collect_braziers(node: Node, found: Array[Brazier]) -> void:
	for child: Node in node.get_children():
		if child is Brazier:
			found.append(child as Brazier)
		_collect_braziers(child, found)
