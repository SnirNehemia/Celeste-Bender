class_name BackRoomView
extends CanvasLayer
## BackRoomView: shows the current room's BACK ROOM (Room.back_room) behind it: a
## real room of the level, seen one layer deeper, as if through the openings of
## the room you're in. Only the current room's back room shows: in the back room
## itself you see ITS back room (if it has one), never the room you came from, the
## way going deeper into a cave leaves the outer cave behind you.
## Step 1 of "rooms as backgrounds": you can only look, not go there yet.
##
## HOW: a SubViewport (a second, off-screen screen) that shares the game's
## World2D, the space every room lives in, but has its own Camera2D pointed at
## the back room. It draws that room (frozen, the way RoomManager keeps rooms far
## from the player: still drawn, not running), and this layer shows the picture
## behind the rooms (CANVAS_LAYER_INDEX: in front of the Backdrop, behind layer 0)
## hazed (back_room_haze.gdshader: colors pulled toward a cool gray, but solid
## things stay solid, so the backdrop never shows through its platforms) and
## following the camera more slowly (PARALLAX): further away.
##
## Made by RoomManager next to the Backdrop. Listens to GameState.room_entered.

## Draw order: in front of the Backdrop (-10), behind the rooms (0).
const CANVAS_LAYER_INDEX: int = -5
## How much of the camera's movement in the front room the back room's view
## follows: less than 1 = further away.
const PARALLAX: float = 0.6
## The back room's look: its colors pulled toward the haze, solid things opaque.
const HAZE_SHADER: Shader = preload("res://scenes/rooms/back_room_haze.gdshader")
## Seconds to fade a back room in or out when the room changes.
const FADE_TIME: float = 0.35

## Every room of the level (to find a back room by name). Set by RoomManager.
var rooms: Array[Room] = []
## The camera of the front (current) room. Set by RoomManager.
var camera: Camera2D = null

var _viewport: SubViewport = null
var _view_camera: Camera2D = null
var _picture: TextureRect = null
## The room we're in, the one shown behind it, and the one about to be shown once
## the old one has faded out (null: none).
var _front_room: Room = null
var _back_room: Room = null
var _wanted_back_room: Room = null
var _fade_tween: Tween = null


func _ready() -> void:
	layer = CANVAS_LAYER_INDEX
	_viewport = SubViewport.new()
	_viewport.name = "BackRoomViewport"
	_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	_viewport.transparent_bg = true
	# The same World2D as the game: the rooms are drawn from here too, by our camera.
	_viewport.world_2d = get_viewport().world_2d
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_view_camera = Camera2D.new()
	_view_camera.name = "BackRoomCamera"
	_viewport.add_child(_view_camera)
	_view_camera.make_current()
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.texture = _viewport.get_texture()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var haze: ShaderMaterial = ShaderMaterial.new()
	haze.shader = HAZE_SHADER
	_picture.material = haze
	# Hidden until there's a back room: modulate's alpha fades it in and out.
	_picture.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_picture)
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.room_entered.connect(_on_room_entered)


func _process(_delta: float) -> void:
	if _back_room == null or camera == null or not is_instance_valid(_front_room) or not is_instance_valid(_back_room):
		return
	# Where the camera is in the front room, scaled down, is where we look in the
	# back room: the back room slides by more slowly.
	var camera_offset: Vector2 = camera.get_screen_center_position() - _front_room.get_bounds().get_center()
	_view_camera.position = (_back_room.get_bounds().get_center() + camera_offset * PARALLAX).round()


## The room `room` shows behind it, or null: the room of the level whose title or
## node name is its `back_room`; never itself.
func find_back_room(room: Room) -> Room:
	if room == null or room.back_room.strip_edges() == "":
		return null
	var wanted: String = room.back_room.strip_edges()
	for other: Room in rooms:
		if other != room and is_instance_valid(other) and (other.display_title == wanted or String(other.name) == wanted):
			return other
	return null


## The back room on show now (null: none). For tests.
func get_back_room() -> Room:
	return _back_room


func _on_room_entered(room: Room) -> void:
	if not is_instance_valid(room) or not rooms.has(room):
		return
	_front_room = room
	var back: Room = find_back_room(room)
	if back == _wanted_back_room:
		return
	_wanted_back_room = back
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	# Out with the old back room first (still looking at it), then switch.
	if _picture.modulate.a > 0.0:
		_fade_tween.tween_property(_picture, "modulate:a", 0.0, FADE_TIME * 0.5)
	_fade_tween.tween_callback(_switch_to.bind(back))
	if back != null:
		_fade_tween.tween_property(_picture, "modulate:a", 1.0, FADE_TIME)


## Points the view at `back` (null: none; then the second view stops rendering,
## since it costs a whole extra drawing of the world each frame).
func _switch_to(back: Room) -> void:
	_back_room = back
	if back == null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_process(0.0)
