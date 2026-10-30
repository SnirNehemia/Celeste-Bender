class_name Backdrop
extends CanvasLayer
## Backdrop: the multi-layer, parallax background behind the rooms, Celeste style.
## A room's backdrop has two parts, both Room settings:
##   LOOK      where the level is set: mountains, a temple, a forest, a desert, the
##             sea, a jungle, a shore, a volcano
##             (Room.backdrop_theme; AUTO picks from what's in the room)
##   ALTITUDE  where in that setting the room is: UNDERGROUND (caves, crypts, roots),
##             SURFACE, or SKYLINE (high up: above the clouds, the treetops, the roofs)
##             (Room.backdrop_altitude; AUTO picks from the room's height compared
##             with the level's start room, see Room.get_backdrop_altitude)
## Every look x altitude is its own script: themes/<look>/<altitude>.gd. When the
## player walks into a room whose look or altitude differs, the backdrop SCROLLS to
## the new one, as if the camera panned on through one tall picture: climbing out
## of a cave, the cave slides down out of view and the surface comes in from above;
## a new look at the same height slides in from the side the player walked to.
##
## Made by RoomManager._ready() in every world, Story level and editor play-test
## (nothing to place by hand). It listens to GameState.room_entered (a signal the
## autoload emits whenever the current room changes) and asks the room.
##
## A CanvasLayer is a separate drawing layer with its own coordinates: things in it
## ignore the Camera2D and are drawn in SCREEN pixels. `layer = -10` draws it before
## (behind) the default layer 0 where the rooms are. The parallax is done by hand:
## every frame each BackdropLayer is placed from how far the camera has moved.
##
## Files: backdrop_theme.gd (one look = a stack of layers), backdrop_layer.gd (one
## scrolling strip), backdrop_paint.gd (paints the strips), backdrop_motes.gd (snow,
## dust, bubbles...), themes/<look>/{underground,surface,skyline}.gd (the 24 looks).
## BackdropPreview (backdrop_preview.gd) shows them all without making rooms.

## Where a level is set. AUTO: picked from the room's contents. NONE: just the
## plain background color (project setting default_clear_color).
## New looks go at the END: rooms save the number, not the name.
enum Look { AUTO, NONE, MOUNTAIN, TEMPLE, FOREST, DESERT, UNDERWATER, JUNGLE, SHORE, VOLCANO }
## Where in that setting a room is. AUTO: from the room's height (Room).
enum Altitude { AUTO, UNDERGROUND, SURFACE, SKYLINE }

## The script of each look and altitude (preload: loaded with this script, not mid-game).
const THEME_SCRIPTS: Dictionary = {
	Look.MOUNTAIN: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/mountain/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/mountain/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/mountain/skyline.gd"),
	},
	Look.TEMPLE: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/temple/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/temple/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/temple/skyline.gd"),
	},
	Look.FOREST: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/forest/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/forest/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/forest/skyline.gd"),
	},
	Look.DESERT: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/desert/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/desert/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/desert/skyline.gd"),
	},
	Look.UNDERWATER: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/underwater/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/underwater/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/underwater/skyline.gd"),
	},
	Look.JUNGLE: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/jungle/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/jungle/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/jungle/skyline.gd"),
	},
	Look.SHORE: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/shore/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/shore/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/shore/skyline.gd"),
	},
	Look.VOLCANO: {
		Altitude.UNDERGROUND: preload("res://scenes/backdrop/themes/volcano/underground.gd"),
		Altitude.SURFACE: preload("res://scenes/backdrop/themes/volcano/surface.gd"),
		Altitude.SKYLINE: preload("res://scenes/backdrop/themes/volcano/skyline.gd"),
	},
}
## Seconds the scroll from one look to the next takes (a room slide is ~0.3 s:
## the backdrop keeps going a little after the room has arrived).
const SLIDE_TIME: float = 0.8
## Draw order: below the rooms (layer 0) and every UI CanvasLayer.
const CANVAS_LAYER_INDEX: int = -10

## The camera whose movement drives the parallax. Set by RoomManager.
var camera: Camera2D = null
## The level's start room: AUTO altitudes are measured from it. Set by RoomManager.
var start_room: Room = null
## The look and altitude on screen (the newest, if one is scrolling in).
var current_look: Look = Look.NONE
var current_altitude: Altitude = Altitude.SURFACE
## Each look sits in its own FRAME: a screen-sized Control with clip_contents, so
## nothing of it is drawn outside the frame. Scrolling moves two frames side by
## side (or one above the other), which gives a clean edge between the two looks.
## The frame showing the current look (it has no theme inside for NONE):
var _current_frame: Control = null
## The scroll in progress, if any.
var _slide_tween: Tween = null
## Where the camera was when the backdrop started: offsets are measured from here.
var _camera_start: Vector2 = Vector2.INF
## The middle of the room entered last: which way the player went decides which
## way a new look at the same altitude scrolls in.
var _last_room_center: Vector2 = Vector2.INF


func _ready() -> void:
	layer = CANVAS_LAYER_INDEX
	# RoomManager makes us before it sets the first room, so this hears that one too.
	GameState.room_entered.connect(_on_room_entered)


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var camera_center: Vector2 = camera.get_screen_center_position()
	if _camera_start == Vector2.INF:
		_camera_start = camera_center
	for frame: Node in get_children():
		var theme: BackdropTheme = _theme_in(frame)
		if theme != null:
			theme.follow_camera(camera_center - _camera_start, delta)


## Shows `look` at `altitude` (AUTO counts as SURFACE here: rooms resolve AUTO
## themselves). `slide_direction` is the way the view travels: UP scrolls the old
## look down out of view and brings the new one in from above, RIGHT brings it in
## from the right... Vector2.ZERO: no scroll, the new look is there at once.
func show_look(look: Look, altitude: Altitude, slide_direction: Vector2 = Vector2.ZERO) -> void:
	if altitude == Altitude.AUTO:
		altitude = Altitude.SURFACE
	if look == current_look and (altitude == current_altitude or look == Look.NONE):
		return
	current_look = look
	current_altitude = altitude
	# A scroll still going: finish it at once (drop every older frame).
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	for frame: Node in get_children():
		if frame != _current_frame:
			frame.queue_free()
	var old_frame: Control = _current_frame
	if old_frame != null:
		old_frame.position = Vector2.ZERO
	_current_frame = _make_frame(look, altitude)
	if old_frame == null:
		return
	if slide_direction == Vector2.ZERO:
		old_frame.queue_free()
		return
	# A Tween animates properties over time. Both frames move together by one
	# screen: the new one from beside the old, the old one out the other side.
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var travel: Vector2 = slide_direction * screen_size
	_current_frame.position = travel
	_slide_tween = create_tween().set_parallel()
	_slide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property(_current_frame, "position", Vector2.ZERO, SLIDE_TIME)
	_slide_tween.tween_property(old_frame, "position", -travel, SLIDE_TIME)
	_slide_tween.chain().tween_callback(old_frame.queue_free)


## Which way to scroll from `old_altitude` to `new_altitude` when the player moved
## by `travel` (from one room's middle to the next): up or down when the altitude
## changes (skyline is up), else the way the player went, mostly sideways.
static func get_slide_direction(old_altitude: Altitude, new_altitude: Altitude, travel: Vector2) -> Vector2:
	if old_altitude != new_altitude:
		return Vector2.UP if new_altitude > old_altitude else Vector2.DOWN
	if absf(travel.y) > absf(travel.x) * 2.0:
		return Vector2.UP if travel.y < 0.0 else Vector2.DOWN
	return Vector2.LEFT if travel.x < 0.0 else Vector2.RIGHT


## True while a scroll is under way (the tests wait for it).
func is_sliding() -> bool:
	return _slide_tween != null and _slide_tween.is_valid() and _slide_tween.is_running()


## A short name for a look and altitude, e.g. "Forest, skyline" (the editor's map).
static func describe(look: Look, altitude: Altitude) -> String:
	if look == Look.NONE:
		return "No backdrop"
	return "%s, %s" % [String(Look.keys()[look]).capitalize(), String(Altitude.keys()[altitude]).to_lower()]


## A new frame (see _current_frame) with the look's theme built inside, placed for
## the camera right away so it doesn't flash at the wrong spot for a frame.
func _make_frame(look: Look, altitude: Altitude) -> Control:
	var frame: Control = Control.new()
	frame.name = "%s%s" % [String(Look.keys()[look]).capitalize(), String(Altitude.keys()[altitude]).capitalize()]
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# Anchors: the frame fills the screen (a CanvasLayer's Controls anchor to the viewport).
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if THEME_SCRIPTS.has(look):
		var theme: BackdropTheme = (THEME_SCRIPTS[look][altitude] as GDScript).new() as BackdropTheme
		theme.name = "Theme"
		theme.build()
		frame.add_child(theme)
		if camera != null and _camera_start != Vector2.INF:
			theme.follow_camera(camera.get_screen_center_position() - _camera_start, 0.0)
	return frame


## The theme inside a frame, or null (NONE, or not a frame).
static func _theme_in(frame: Node) -> BackdropTheme:
	return frame.get_node_or_null(^"Theme") as BackdropTheme


func _on_room_entered(room: Room) -> void:
	# Only rooms of our own world: in Story Mode the next level's world is made
	# while this one is on its way out.
	if not is_instance_valid(room) or not get_parent().is_ancestor_of(room):
		return
	var center: Vector2 = room.get_bounds().get_center()
	var altitude: Altitude = room.get_backdrop_altitude(start_room)
	if altitude == Altitude.AUTO:
		altitude = Altitude.SURFACE
	var direction: Vector2 = Vector2.ZERO
	# The first room of a level shows at once.
	if _current_frame != null and _last_room_center != Vector2.INF:
		direction = get_slide_direction(current_altitude, altitude, center - _last_room_center)
	_last_room_center = center
	show_look(room.get_backdrop_theme(), altitude, direction)
