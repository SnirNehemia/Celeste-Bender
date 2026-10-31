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
## Every look x altitude is its own script: themes/<look>/<altitude>.gd, and the
## three of a look share a style (themes/<look>/style.gd: one tall sky, one set of
## colors, the same big shapes in front), so a look reads as ONE scene seen at
## three heights. When the player walks into a room whose look or altitude
## differs, the backdrop changes in one of two ways (get_transition):
##   SOFT   the view scrolls on by one screen, the new look coming in from the
##          side it travels toward (above when climbing, the side walked to), and
##          where the two meet they blend in a dithered band instead of a line.
##          A look's shared tall layers (sky, far range...) simply continue from
##          one altitude into the next. Surface <-> skyline, any change of look,
##          and every change underwater.
##   BREAK  the same scroll, but with a jagged band of the look's rock between the
##          two: breaking out of the ground (or into it), underground <-> above.
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
## How a change from one look to another is shown (see the header).
enum Transition { SOFT, BREAK }

## Looks whose underground changes SOFTLY too: under water there's no ground to
## break through, only darker water.
const SOFT_UNDERGROUND_LOOKS: Array[Look] = [Look.UNDERWATER]
## Seconds each kind of change takes (a room slide is ~0.3 s: the backdrop keeps
## going a little after the room has arrived).
const SOFT_TIME: float = 0.9
const BREAK_TIME: float = 0.7
## A soft change: px over which the new look blends into the old one at their
## seam. Up and down, the old look only reaches BackdropPaint.SCREEN_TOP_ROW px past
## its edge (the strip's spare rows), so the blend can't be wider than that;
## sideways the strips go on forever, so it can be wider.
const SOFT_FEATHER_VERTICAL: float = 36.0
const SOFT_FEATHER_SIDEWAYS: float = 90.0
## A break: half the height of the rock band between the looks, and how far its
## jagged edge wanders (px).
const CRUST_HALF_HEIGHT: float = 5.0
const CRUST_ROUGHNESS: float = 4.0
const WIPE_SHADER: Shader = preload("res://scenes/backdrop/backdrop_wipe.gdshader")
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
## The change in progress, if any.
var _slide_tween: Tween = null
## During a BREAK: the rock band drawn between the two frames, the colors it's
## drawn in, and its middle (screen row).
var _crust: Node2D = null
var _crust_colors: Array[Color] = []
var _crust_row: float = 0.0
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
	if _crust != null:
		_crust.queue_redraw()


## Shows `look` at `altitude` (AUTO counts as SURFACE here: rooms resolve AUTO
## themselves). `slide_direction` is the way the view travels: UP (climbing) brings
## the new look in from above, DOWN from below, LEFT or RIGHT from that side.
## Vector2.ZERO: no change shown, the new look is there at once. Whether it's SOFT or a BREAK depends on
## the two looks (get_transition).
func show_look(look: Look, altitude: Altitude, slide_direction: Vector2 = Vector2.ZERO) -> void:
	if altitude == Altitude.AUTO:
		altitude = Altitude.SURFACE
	if look == current_look and (altitude == current_altitude or look == Look.NONE):
		return
	var transition: Transition = get_transition(current_look, current_altitude, look, altitude)
	current_look = look
	current_altitude = altitude
	# A change still going: finish it at once (drop every older frame).
	_end_change()
	var old_frame: Control = _current_frame
	_current_frame = _make_frame(look, altitude)
	if old_frame == null:
		return
	if slide_direction == Vector2.ZERO:
		old_frame.queue_free()
		return
	if transition == Transition.BREAK and slide_direction.y != 0.0:
		_start_break(old_frame, slide_direction)
	else:
		_start_soft(old_frame, slide_direction)


## How a change from (`old_look`, `old_altitude`) to (`new_look`, `new_altitude`)
## is shown: a BREAK in and out of the ground, otherwise SOFT (see the header).
static func get_transition(old_look: Look, old_altitude: Altitude, new_look: Look, new_altitude: Altitude) -> Transition:
	var crosses_ground: bool = (old_altitude == Altitude.UNDERGROUND) != (new_altitude == Altitude.UNDERGROUND)
	var is_soft_look: bool = SOFT_UNDERGROUND_LOOKS.has(old_look) and SOFT_UNDERGROUND_LOOKS.has(new_look)
	if crosses_ground and not is_soft_look:
		return Transition.BREAK
	return Transition.SOFT


## SOFT: both frames scroll by one screen like a BREAK, but unclipped (each
## strip reaches a little past the screen's edge) and with the new frame's
## leading edge blended into the old one by the wipe shader on its CanvasGroup.
func _start_soft(old_frame: Control, slide_direction: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var travel: Vector2 = slide_direction * screen_size
	var is_vertical: bool = slide_direction.y != 0.0
	var wipe: ShaderMaterial = ShaderMaterial.new()
	wipe.shader = WIPE_SHADER
	wipe.set_shader_parameter(&"enter_from", slide_direction)
	wipe.set_shader_parameter(&"feather", SOFT_FEATHER_VERTICAL if is_vertical else SOFT_FEATHER_SIDEWAYS)
	wipe.set_shader_parameter(&"screen_pixels", screen_size)
	_group_in(_current_frame).material = wipe
	for frame: Control in [old_frame, _current_frame]:
		frame.clip_contents = false
	_current_frame.position = travel
	# The leading edge: the new frame's side that faces the old one (its bottom when
	# it comes in from above). Tweened alongside the frames.
	var screen_length: float = screen_size.y if is_vertical else screen_size.x
	var axis_travel: float = travel.y if is_vertical else travel.x
	var edge_from: float = axis_travel + (screen_length if axis_travel < 0.0 else 0.0)
	var edge_to: float = screen_length if axis_travel < 0.0 else 0.0
	_slide_tween = create_tween().set_parallel()
	_slide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property(_current_frame, "position", Vector2.ZERO, SOFT_TIME)
	_slide_tween.tween_property(old_frame, "position", -travel, SOFT_TIME)
	# Set before tweening: a shader parameter only exists as a property once it has a value.
	wipe.set_shader_parameter(&"leading_edge", edge_from)
	_slide_tween.tween_property(wipe, "shader_parameter/leading_edge", edge_to, SOFT_TIME)
	_slide_tween.chain().tween_callback(_end_change)


## BREAK: both frames move together by one screen with a band of rock between
## them (the ground being broken through), the old one out, the new one in.
func _start_break(old_frame: Control, slide_direction: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var travel: Vector2 = slide_direction * screen_size
	_current_frame.position = travel
	# The rock is the underground look's own (whichever side it's on).
	var underground_theme: BackdropTheme = _theme_in(old_frame if current_altitude != Altitude.UNDERGROUND else _current_frame)
	_crust_colors = underground_theme.crust_colors if underground_theme != null else BackdropTheme.DEFAULT_CRUST_COLORS
	_crust = Node2D.new()
	_crust.name = "Crust"
	# draw: the signal a CanvasItem sends when it's time to draw it, so a plain
	# Node2D can be drawn by a method here (draw calls go through the node).
	_crust.draw.connect(_draw_crust)
	add_child(_crust)
	_slide_tween = create_tween().set_parallel()
	_slide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property(_current_frame, "position", Vector2.ZERO, BREAK_TIME)
	_slide_tween.tween_property(old_frame, "position", -travel, BREAK_TIME)
	# The seam: the new frame's edge that faces the old one.
	var seam_from: float = travel.y + (screen_size.y if slide_direction.y < 0.0 else 0.0)
	var seam_to: float = screen_size.y if slide_direction.y < 0.0 else 0.0
	_slide_tween.tween_method(func(row: float) -> void: _crust_row = row, seam_from, seam_to, BREAK_TIME)
	_slide_tween.chain().tween_callback(_end_change)


## The jagged band of rock along the seam of a BREAK: a body, a lit rim on top,
## a darker line under it, edges wandering by CRUST_ROUGHNESS.
func _draw_crust() -> void:
	var width: float = get_viewport().get_visible_rect().size.x
	var body: Color = _crust_colors[0]
	var rim: Color = _crust_colors[1]
	for x: int in range(0, int(width), 2):
		# Two sines of unrelated lengths per edge: irregular rock, but not noisy.
		var top: float = roundf(_crust_row - CRUST_HALF_HEIGHT - absf(sin(x * 0.11) + sin(x * 0.037 + 1.3)) * CRUST_ROUGHNESS * 0.5)
		var bottom: float = roundf(_crust_row + CRUST_HALF_HEIGHT + absf(sin(x * 0.09 + 2.0) + sin(x * 0.029)) * CRUST_ROUGHNESS * 0.5)
		_crust.draw_rect(Rect2(x, top, 2.0, bottom - top), body)
		_crust.draw_rect(Rect2(x, top, 2.0, 1.0), rim)
		_crust.draw_rect(Rect2(x, bottom - 1.0, 2.0, 1.0), body.darkened(0.4))


## Ends a change at once: every frame but the current one goes, the current one
## goes back to rest (no wipe, no drift), the rock band goes.
func _end_change() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null
	for child: Node in get_children():
		if child != _current_frame:
			child.queue_free()
	_crust = null
	if _current_frame != null:
		_current_frame.position = Vector2.ZERO
		_current_frame.clip_contents = true
		_group_in(_current_frame).material = null


## Which way to scroll from `old_altitude` to `new_altitude` when the player moved
## by `travel` (from one room's middle to the next): up or down when the altitude
## changes (skyline is up), else the way the player went, mostly sideways.
static func get_slide_direction(old_altitude: Altitude, new_altitude: Altitude, travel: Vector2) -> Vector2:
	if old_altitude != new_altitude:
		return Vector2.UP if new_altitude > old_altitude else Vector2.DOWN
	if absf(travel.y) > absf(travel.x) * 2.0:
		return Vector2.UP if travel.y < 0.0 else Vector2.DOWN
	return Vector2.LEFT if travel.x < 0.0 else Vector2.RIGHT


## True while a change is under way (the tests wait for it).
func is_sliding() -> bool:
	return _slide_tween != null and _slide_tween.is_valid() and _slide_tween.is_running()


## A short name for a look and altitude, e.g. "Forest, skyline" (the editor's map).
static func describe(look: Look, altitude: Altitude) -> String:
	if look == Look.NONE:
		return "No backdrop"
	return "%s, %s" % [String(Look.keys()[look]).capitalize(), String(Altitude.keys()[altitude]).to_lower()]


## A new frame (see _current_frame) with the look's theme built inside, placed for
## the camera right away so it doesn't flash at the wrong spot for a frame.
## Frame > Group (a CanvasGroup: the soft wipe's shader goes on it) > Theme.
func _make_frame(look: Look, altitude: Altitude) -> Control:
	var frame: Control = Control.new()
	frame.name = "%s%s" % [String(Look.keys()[look]).capitalize(), String(Altitude.keys()[altitude]).capitalize()]
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# Anchors: the frame fills the screen (a CanvasLayer's Controls anchor to the viewport).
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var group: CanvasGroup = CanvasGroup.new()
	group.name = "Group"
	frame.add_child(group)
	if THEME_SCRIPTS.has(look):
		var theme: BackdropTheme = (THEME_SCRIPTS[look][altitude] as GDScript).new() as BackdropTheme
		theme.name = "Theme"
		theme.build()
		group.add_child(theme)
		if camera != null and _camera_start != Vector2.INF:
			theme.follow_camera(camera.get_screen_center_position() - _camera_start, 0.0)
	return frame


## The theme inside a frame, or null (NONE, or not a frame).
static func _theme_in(frame: Node) -> BackdropTheme:
	return frame.get_node_or_null(^"Group/Theme") as BackdropTheme


static func _group_in(frame: Node) -> CanvasGroup:
	return frame.get_node_or_null(^"Group") as CanvasGroup


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
