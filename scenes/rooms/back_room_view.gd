class_name BackRoomView
extends CanvasLayer
## BackRoomView: shows the layer BEHIND the room you're in (Level_editor.md §5a):
## every room one depth deeper (Room.get_depth), seen through the open air of the
## rooms in front. From depth N you see only depth N+1, never the outer N-1: going
## deeper into a cave leaves the outer cave behind you. Depth gates (DepthGate)
## take you there.
##
## HOW: a SubViewport (a second, off-screen screen) that shares the game's
## World2D, the space every room lives in, but has its own Camera2D pointed at the
## next depth's BAND (rooms of each depth sit Room.DEPTH_SPACING further down). It
## draws those rooms (frozen, the way RoomManager keeps rooms far from the player:
## still drawn, not running), and this layer shows the picture behind the rooms
## (CANVAS_LAYER_INDEX: in front of the Backdrop, behind layer 0) hazed
## (back_room_haze.gdshader: colors pulled toward the backdrop's MAIN COLOR,
## Backdrop.get_main_color, so a room further back sinks into the background
## around it: darker in caves, lighter in skylines; but solid things stay solid,
## so the backdrop never shows through their platforms). When the look changes the
## haze color eases to the new one (HAZE_COLOR_SPEED).
##
## PARALLAX, PINNED AT GATES (Stage D3): the layer behind slides more slowly than
## the front (PARALLAX), but lines up EXACTLY with it at the PIN: the gate nearest
## the player in the current room that has a twin behind it (or, with none, the
## room's middle). Stand in a gate and its twin is right behind it. The math:
##   view = depth_offset(1) + PARALLAX * camera + (1 - PARALLAX) * anchor
## where `anchor` is where the camera settles when the player stands at the pin
## (RoomCamera.get_center_for, so the camera's clamping at room edges is taken
## into account). With the player at the pin, camera == anchor, so view = camera +
## depth_offset(1): the twin (same map spot, one band down) lands on the gate's
## screen spot. Away from it, the view moves PARALLAX times as far as the camera.
## Inside the gate (and PIN_REACH around it) the anchor follows the player (the
## nearest point of that area), so anywhere inside lines up, and it's continuous
## when you step out. When the pin changes, the view glides there (PIN_GLIDE_TIME)
## instead of jumping.
##
## SMALLER, SO FURTHER (after the D play-test): the picture is drawn a little
## smaller (BACK_SCALE) around the pin's spot on screen (the pin gate's middle, or
## the room's middle), smoothly filtered, so the layer behind reads as further
## away. The SubViewport is bigger than the screen by enough that the shrunk
## picture still covers it. Stepping in through a gate grows it to full size
## (begin_step); stepping out shrinks it back (begin_return).
##
## EVEN DEEPER (a test, after the D play-test): DEEPER_LAYERS more depths show
## behind that one (depth N+2, N+3...), each fainter (more haze: layer_haze; still
## OPAQUE, so the backdrop never shows through them), slower (PARALLAX to the
## power of how far back) and a little smaller again. They're pinned at the same
## spot, so at a gate every layer lines up. Each one is another whole drawing of
## the world, so only depths that have rooms are drawn. DEEPER_LAYERS = 0 goes
## back to the plan's "only the next depth".
## A gate's step moves EVERY layer one step forward (_step_progress 0 -> 1): the
## one behind clears and grows into the front, the one behind it eases into the
## "behind" look (less haze, bigger, faster), and so on; at the swap each layer's
## picture hands over to the next nearer one (_hand_over), so nothing vanishes and
## comes back. Stepping out runs it backwards (1 -> 0). A layer that wasn't shown
## before (a depth newly in reach) fades in (_layer_fades).
##
## NOT WHERE YOU ARE (picked from three looks in a play-test): besides the haze,
## every layer behind has flatter, grayer colors (CONTRAST_PER_DEPTH,
## SATURATION_PER_DEPTH) and a soft blur (BLUR_PER_DEPTH), all stronger per depth,
## so nothing behind is as crisp or as colorful as the platforms you can stand on
## (back_room_haze.gdshader). Every setting of a layer comes from how far back it
## looks now (apply_look, a fraction during a gate's step), so steps blend them
## smoothly too. The editor's previews use the same look (EditorDepthView).
##
## Made by RoomManager next to the Backdrop. Listens to GameState.room_entered.
## RoomManager drives it through a gate step (begin_step / end_step going in,
## begin_return / release_view going out).

## Draw order: in front of the Backdrop (-10), behind the rooms (0).
const CANVAS_LAYER_INDEX: int = -5
## Contrast and saturation are multiplied by these once per depth back (0.65
## behind, 0.42 two back...), and the blur reaches this many px per depth back.
const CONTRAST_PER_DEPTH: float = 0.65
const SATURATION_PER_DEPTH: float = 0.6
const BLUR_PER_DEPTH: float = 0.8
## How much of the camera's movement in front the layer behind follows: less
## than 1 = further away. The layer behind is a real room at nearly the same
## distance, so it's only a little slower (0.6 felt too far in screenshots).
const PARALLAX: float = 0.75
## How big the layer behind is drawn at rest (1 = the front's size).
const BACK_SCALE: float = 0.92
## How many depths beyond the one behind also show, fainter (see the header).
const DEEPER_LAYERS: int = 2
## Haze of each layer from the second one back on (index 0 = depth N+2); further
## ones reuse the last.
const DEEPER_HAZE: Array[float] = [0.7, 0.85]
## How fast the haze color follows a new backdrop look (share of the way per second).
const HAZE_COLOR_SPEED: float = 2.0
## The look of the layer behind: its colors pulled toward the haze, solid things opaque.
const HAZE_SHADER: Shader = preload("res://scenes/rooms/back_room_haze.gdshader")
## How far its colors are pulled into the haze (0-1), at rest.
const HAZE_AMOUNT: float = 0.45
## Seconds to fade the layer behind in or out when it changes (a new depth).
const FADE_TIME: float = 0.35
## Seconds the view takes to glide to a new pin (gate or room middle).
const PIN_GLIDE_TIME: float = 0.3
## How far around the pin gate (px) the player still counts as standing in it:
## within it the layers line up exactly. A tile, so feet on the floor just under
## a gate placed by hand a few px high still line up.
const PIN_REACH: float = 8.0

## The rooms of the level, and the backdrop (its main color is the haze's).
## Set by RoomManager.
var rooms: Array[Room] = []
var backdrop: Backdrop = null
## The front camera, and the player (the pin is measured from where they stand).
## Set by RoomManager.
var camera: RoomCamera = null
var player: Player = null

var _viewport: SubViewport = null
var _view_camera: Camera2D = null
var _picture: TextureRect = null
var _haze: ShaderMaterial = null
## The screen's size, px (the game's 320x180).
var _screen_size: Vector2 = Vector2.ZERO
## The room we're in. The depth shown behind it (-1: none), and the one about to
## be shown once the old one has faded out.
var _front_room: Room = null
var _shown_depth: int = -1
var _wanted_depth: int = -1
var _fade_tween: Tween = null
## How big the picture is drawn now (BACK_SCALE at rest, 1 during a step).
var _picture_scale: float = BACK_SCALE
## The pin (see the header): the gate it's at (null: the room's middle).
var _pin_gate: DepthGate = null
## A glide to a new pin: how far it is (0 -> 1), and the view center and scaling
## spot it started from (INF: nothing to glide from).
var _glide_progress: float = 1.0
var _glide_from_center: Vector2 = Vector2.INF
var _glide_from_focus: Vector2 = Vector2.INF
## The view center and scaling spot used last frame (a glide starts from them).
var _last_center: Vector2 = Vector2.INF
var _last_focus: Vector2 = Vector2.INF
## While stepping out through a gate: the view stays exactly here (INF: no hold).
var _held_center: Vector2 = Vector2.INF
## The deeper layers (see the header), nearest first: their SubViewports, cameras
## and pictures; and how much of their opacity shows now (0-1, faded in steps).
var _deeper_viewports: Array[SubViewport] = []
var _deeper_cameras: Array[Camera2D] = []
var _deeper_pictures: Array[TextureRect] = []
## How far a gate's step has moved the layers forward (see the header): 0 at
## rest, 1 when each has the look of the next nearer one.
var _step_progress: float = 0.0
## Each deeper layer's own fade-in (0-1): a depth newly in reach fades in.
var _layer_fades: Array[float] = []
## Each deeper layer's view center last frame (INF: not shown), for the hand-over.
var _deeper_centers: Array[Vector2] = []
## Set by end_step: the next room_entered hands the layers over (_hand_over)
## instead of fading the depth behind out and in.
var _is_handing_over: bool = false
## The color every layer is hazed toward now (INF alpha: not set yet).
var _haze_color: Color = Color(0.0, 0.0, 0.0, -1.0)


func _ready() -> void:
	layer = CANVAS_LAYER_INDEX
	_screen_size = get_viewport().get_visible_rect().size
	# The deepest first: children draw in order, so nearer layers cover them.
	for index: int in range(DEEPER_LAYERS - 1, -1, -1):
		var steps_back: int = index + 2
		var deeper_picture: TextureRect = _make_layer("Deeper%d" % steps_back, steps_back)
		_deeper_pictures.push_front(deeper_picture)
		_deeper_viewports.push_front(deeper_picture.get_meta(&"viewport") as SubViewport)
		_deeper_cameras.push_front((deeper_picture.get_meta(&"viewport") as SubViewport).get_child(0) as Camera2D)
		_layer_fades.push_front(0.0)
		_deeper_centers.push_front(Vector2.INF)
	_picture = _make_layer("Back", 1)
	_viewport = _picture.get_meta(&"viewport") as SubViewport
	_view_camera = _viewport.get_child(0) as Camera2D
	_haze = _picture.material as ShaderMaterial
	GameState.room_entered.connect(_on_room_entered)


## Sets a layer's shader for one that looks `looks_back` depths behind (a fraction
## while a gate's step moves the layers): its haze, flatter colors and blur (see
## the header). Static: the editor's previews use it too.
static func apply_look(material: ShaderMaterial, looks_back: float) -> void:
	var nearer: int = floori(looks_back)
	material.set_shader_parameter(&"haze_amount", lerpf(layer_haze(nearer), layer_haze(nearer + 1), looks_back - nearer))
	material.set_shader_parameter(&"contrast", pow(CONTRAST_PER_DEPTH, looks_back))
	material.set_shader_parameter(&"saturation", pow(SATURATION_PER_DEPTH, looks_back))
	material.set_shader_parameter(&"blur_radius", BLUR_PER_DEPTH * looks_back)


## Makes one layer `steps_back` depths behind: a SubViewport with its camera, and
## the hazed picture of it (returned; its viewport is in its "viewport" meta).
func _make_layer(layer_name: String, steps_back: int) -> TextureRect:
	var viewport: SubViewport = SubViewport.new()
	viewport.name = layer_name + "Viewport"
	# Room around the screen for the shrunk picture to still cover it, whichever
	# spot it shrinks toward (even numbers: at full size it sits on whole pixels).
	var margin: Vector2 = (_screen_size * (1.0 / layer_scale(steps_back) - 1.0) / 2.0).ceil() * 2.0
	viewport.size = Vector2i(_screen_size + margin * 2.0)
	viewport.transparent_bg = true
	# The same World2D as the game: the rooms are drawn from here too, by our camera.
	viewport.world_2d = get_viewport().world_2d
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var view_camera: Camera2D = Camera2D.new()
	view_camera.name = layer_name + "Camera"
	viewport.add_child(view_camera)
	view_camera.make_current()
	var picture: TextureRect = TextureRect.new()
	picture.name = layer_name + "Picture"
	picture.texture = viewport.get_texture()
	# Smooth when shrunk (a little soft, like something further off); at full size
	# it sits on whole pixels, so it's as sharp as the front.
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size = Vector2(viewport.size)
	var haze: ShaderMaterial = ShaderMaterial.new()
	haze.shader = HAZE_SHADER
	apply_look(haze, steps_back)
	picture.material = haze
	# Hidden until there's a depth behind: modulate's alpha fades it in and out.
	picture.modulate = Color(1.0, 1.0, 1.0, 0.0)
	picture.set_meta(&"viewport", viewport)
	add_child(picture)
	return picture


## How far into the haze a layer `steps_back` depths behind is pulled (0: the
## front, none; 1: the one behind, HAZE_AMOUNT; further ones DEEPER_HAZE). The
## editor uses it too.
static func layer_haze(steps_back: int) -> float:
	if steps_back <= 0:
		return 0.0
	if steps_back == 1:
		return HAZE_AMOUNT
	return DEEPER_HAZE[mini(steps_back - 2, DEEPER_HAZE.size() - 1)]


## How big a layer `steps_back` depths behind is drawn at rest.
static func layer_scale(steps_back: int) -> float:
	return pow(BACK_SCALE, steps_back)


func _process(delta: float) -> void:
	if _shown_depth < 0 or camera == null or not is_instance_valid(_front_room):
		return
	_update_pin(delta)
	_update_haze_color(delta)
	_last_center = get_view_center()
	_last_focus = _get_focus()
	_view_camera.position = _last_center.round()
	_place_picture(_picture, _picture_scale, _last_focus)
	# The one behind looks one depth back, less as a step brings it forward.
	apply_look(_haze, 1.0 - _step_progress)
	_update_deeper_layers(delta)


## Eases the haze color toward the backdrop's main color (at once the first time)
## and gives it to every layer's shader.
func _update_haze_color(delta: float) -> void:
	if backdrop == null:
		return
	var target: Color = backdrop.get_current_main_color()
	_haze_color = target if _haze_color.a < 0.0 else _haze_color.lerp(target, minf(1.0, delta * HAZE_COLOR_SPEED))
	_haze.set_shader_parameter(&"haze_color", _haze_color)
	for picture: TextureRect in _deeper_pictures:
		(picture.material as ShaderMaterial).set_shader_parameter(&"haze_color", _haze_color)


## The color the layers are hazed toward now. For tests.
func get_haze_color() -> Color:
	return _haze_color


## The deeper layers follow the one behind: the same pin, found back from its
## view center (so they glide and hold with it), each slower and smaller. During a
## gate's step each looks partway like the next nearer one (_step_progress).
func _update_deeper_layers(delta: float) -> void:
	if _deeper_pictures.is_empty():
		return
	var camera_center: Vector2 = camera.get_screen_center_position()
	# view = depth_offset(1) + PARALLAX * camera + (1 - PARALLAX) * anchor, solved for the anchor.
	var anchor: Vector2 = (_last_center - Room.depth_offset(1) - camera_center * PARALLAX) / (1.0 - PARALLAX)
	for index: int in _deeper_pictures.size():
		var steps_back: int = index + 2
		var is_shown: bool = _has_rooms_at(_shown_depth + index + 1) and _picture.modulate.a > 0.0
		_deeper_viewports[index].render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_shown else SubViewport.UPDATE_DISABLED
		_deeper_pictures[index].visible = is_shown
		if not is_shown:
			_layer_fades[index] = 0.0
			_deeper_centers[index] = Vector2.INF
			continue
		_layer_fades[index] = minf(1.0, _layer_fades[index] + delta / FADE_TIME)
		# How far back it looks now: whole steps at rest, one less at a step's end.
		var looks_back: float = steps_back - _step_progress
		var parallax: float = pow(PARALLAX, looks_back)
		var center: Vector2 = Room.depth_offset(steps_back) + camera_center * parallax + anchor * (1.0 - parallax)
		_deeper_centers[index] = center
		_deeper_cameras[index].position = center.round()
		_place_picture(_deeper_pictures[index], pow(BACK_SCALE, looks_back), _last_focus)
		apply_look(_deeper_pictures[index].material as ShaderMaterial, looks_back)
		_deeper_pictures[index].modulate.a = _picture.modulate.a * _layer_fades[index]


## How many pictures (the one behind and the deeper ones) are on screen now:
## shown and not faded out. For tests.
func get_visible_picture_count() -> int:
	var count: int = 1 if _picture.visible and _picture.modulate.a > 0.0 else 0
	for picture: TextureRect in _deeper_pictures:
		if picture.visible and picture.modulate.a > 0.0:
			count += 1
	return count


## How many deeper layers are drawn now. For tests.
func get_deeper_layers_shown() -> int:
	var count: int = 0
	for viewport: SubViewport in _deeper_viewports:
		if viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			count += 1
	return count


## Where the view behind is centered now (world, in the band behind): see the
## header, gliding toward a new pin, or held during a step out.
func get_view_center() -> Vector2:
	if _held_center != Vector2.INF:
		return _held_center
	var camera_center: Vector2 = camera.get_screen_center_position()
	var target: Vector2 = Room.depth_offset(1) + camera_center * PARALLAX + _get_anchor() * (1.0 - PARALLAX)
	if _glide_progress < 1.0 and _glide_from_center != Vector2.INF:
		return _glide_from_center.lerp(target, smoothstep(0.0, 1.0, _glide_progress))
	return target


## The depth shown behind now (-1: none). For tests.
func get_shown_depth() -> int:
	return _shown_depth


## True while the view behind is drawn every frame. For tests.
func is_rendering() -> bool:
	return _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS


## The gate the layer behind is pinned at (null: the room's middle). For tests.
func get_pin_gate() -> DepthGate:
	return _pin_gate


## How big the picture is drawn now. For tests.
func get_picture_scale() -> float:
	return _picture_scale


## Where the camera settles with the player at the pin (see the header): at the
## point of the pin gate nearest the player's feet, or the room's middle.
func _get_anchor() -> Vector2:
	var bounds: Rect2 = camera.room_bounds if camera.room_bounds.has_area() else _front_room.get_bounds()
	var pin_point: Vector2 = _front_room.get_bounds().get_center()
	if is_instance_valid(_pin_gate):
		var gate_rect: Rect2 = _pin_gate.get_gate_rect().grow(PIN_REACH)
		var feet: Vector2 = player.global_position if player != null else gate_rect.get_center()
		pin_point = feet.clamp(gate_rect.position, gate_rect.end)
	return camera.get_center_for(pin_point, bounds)


## The screen spot the picture shrinks toward: the pin gate's middle (so its twin
## stays centered behind it), or the room's middle; kept on the screen.
func _get_focus() -> Vector2:
	var world_point: Vector2 = _front_room.get_bounds().get_center()
	if is_instance_valid(_pin_gate):
		world_point = _pin_gate.get_gate_rect().get_center()
	var focus: Vector2 = (world_point - camera.get_screen_center_position() + _screen_size / 2.0).clamp(Vector2.ZERO, _screen_size)
	if _glide_progress < 1.0 and _glide_from_focus != Vector2.INF:
		return _glide_from_focus.lerp(focus, smoothstep(0.0, 1.0, _glide_progress))
	return focus


## Draws `picture` at `picture_scale`, shrunk toward `focus` (a screen spot that
## stays put). At scale 1 the picture's middle is the screen's middle.
func _place_picture(picture: TextureRect, picture_scale: float, focus: Vector2) -> void:
	var full_size_corner: Vector2 = (_screen_size - picture.size) / 2.0
	picture.scale = Vector2.ONE * picture_scale
	picture.position = focus - (focus - full_size_corner) * picture_scale


## Picks the pin: the nearest gate in the front room with a twin behind it. A new
## pin starts a glide from wherever the view is now.
func _update_pin(delta: float) -> void:
	_glide_progress = minf(1.0, _glide_progress + delta / PIN_GLIDE_TIME)
	var nearest: DepthGate = null
	var nearest_distance: float = INF
	var feet: Vector2 = player.global_position if player != null else _front_room.get_bounds().get_center()
	for child: Node in _front_room.get_children():
		var gate: DepthGate = child as DepthGate
		if gate == null or gate.find_twin_in(1) == null:
			continue
		var distance: float = gate.get_gate_rect().get_center().distance_to(feet)
		if distance < nearest_distance:
			nearest = gate
			nearest_distance = distance
	if nearest != _pin_gate:
		_start_glide()
		_pin_gate = nearest


## The view glides from where it is now to its new target (a new pin, a new room
## of the same depth, the end of a step out).
func _start_glide() -> void:
	if _last_center != Vector2.INF:
		_glide_from_center = _last_center
		_glide_from_focus = _last_focus
		_glide_progress = 0.0


func _on_room_entered(room: Room) -> void:
	if not is_instance_valid(room) or not rooms.has(room):
		return
	if _front_room != null and room != _front_room:
		_start_glide()  # the same depth seen from another room: re-pin smoothly
	_front_room = room
	_pin_gate = null
	var behind: int = room.get_depth() + 1
	var wanted: int = behind if _has_rooms_at(behind) else -1
	if wanted == _wanted_depth:
		return
	_wanted_depth = wanted
	if _is_handing_over:
		_hand_over(wanted)
		return
	_glide_progress = 1.0  # a new depth: nothing to glide from
	_last_center = Vector2.INF
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	# Out with the old depth first (still looking at it), then switch.
	if _picture.modulate.a > 0.0:
		_fade_tween.tween_property(_picture, "modulate:a", 0.0, FADE_TIME * 0.5)
	_fade_tween.tween_callback(_switch_to.bind(wanted))
	if wanted >= 0:
		_fade_tween.tween_property(_picture, "modulate:a", 1.0, FADE_TIME)


## The swap of a step in (see the header): the depth behind is now the one the
## first deeper layer showed, so the picture takes over from it exactly where it
## was (gliding on from its view center) and each deeper layer from the one behind
## it. With nothing behind the new room, the picture just goes.
func _hand_over(wanted: int) -> void:
	_is_handing_over = false
	_step_progress = 0.0
	var handed_center: Vector2 = _deeper_centers[0] if not _deeper_centers.is_empty() else Vector2.INF
	for index: int in _layer_fades.size():
		_layer_fades[index] = _layer_fades[index + 1] if index + 1 < _layer_fades.size() else 0.0
	_switch_to(wanted)
	if wanted < 0:
		# Nothing behind the room we're in now. Hidden at once: a SubViewport that
		# stops rendering keeps its last picture, which was this very room.
		_picture.modulate.a = 0.0
		return
	_picture.modulate.a = 1.0
	if handed_center != Vector2.INF:
		_glide_from_center = handed_center
		_glide_from_focus = _last_focus
		_glide_progress = 0.0
	else:
		# The depth behind wasn't drawn yet (DEEPER_LAYERS = 0): fade it in.
		_picture.modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(_picture, "modulate:a", 1.0, FADE_TIME)


## True if any room of the level is at `depth`.
func _has_rooms_at(depth: int) -> bool:
	for room: Room in rooms:
		if is_instance_valid(room) and room.get_depth() == depth:
			return true
	return false


## Shows `depth` behind (-1: none; then the second view stops rendering, since it
## costs a whole extra drawing of the world each frame).
func _switch_to(depth: int) -> void:
	_shown_depth = depth
	if depth < 0:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# The deeper pictures too, hidden: a stopped SubViewport keeps its last frame.
		for index: int in _deeper_viewports.size():
			_deeper_viewports[index].render_target_update_mode = SubViewport.UPDATE_DISABLED
			_deeper_pictures[index].visible = false
			_layer_fades[index] = 0.0
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_process(0.0)


# --- Gate steps (RoomManager.go_through_gate) ---

## Going in: over `duration` seconds the layer behind clears (its look goes to
## the front's: apply_look with _step_progress) and grows to full size, while
## RoomManager fades the front out. Returns the tween.
func begin_step(duration: float) -> Tween:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var step: Tween = create_tween().set_parallel(true)
	step.tween_property(self, "_picture_scale", 1.0, duration)
	step.tween_property(self, "_step_progress", 1.0, duration)
	return step


## Going in, the swap: put the size back, before the new room is entered; its
## room_entered then hands the layers over (_hand_over, which puts the look back).
func end_step() -> void:
	_picture_scale = BACK_SCALE
	_is_handing_over = true


## Going out, right after the swap (the room we left is now behind us): show
## `depth` at once, clear and full size, held exactly at `view_center` (where the
## front camera was looking), then over `duration` seconds let it haze and shrink
## back, while RoomManager fades the new front in over it: the step in, reversed.
## release_view() lets it go back to following the camera. Returns the tween.
func begin_return(depth: int, view_center: Vector2, duration: float) -> Tween:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_wanted_depth = depth
	_held_center = view_center
	_last_center = view_center
	_glide_progress = 1.0
	_picture_scale = 1.0
	_picture.modulate.a = 1.0
	# Each deeper layer now shows what the next nearer one showed: the first one
	# the depth that was behind us (fully in), the others shifted back.
	for index: int in range(_layer_fades.size() - 1, -1, -1):
		_layer_fades[index] = _layer_fades[index - 1] if index > 0 else 1.0
	_step_progress = 1.0
	_switch_to(depth)
	var step: Tween = create_tween().set_parallel(true)
	step.tween_property(self, "_picture_scale", BACK_SCALE, duration)
	step.tween_property(self, "_step_progress", 0.0, duration)
	return step


## After begin_return: the view glides from where it was held to where it follows
## the camera (pinned at the gate) again.
func release_view() -> void:
	_held_center = Vector2.INF
	_start_glide()

