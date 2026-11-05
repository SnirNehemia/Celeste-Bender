class_name DarkRoomOverlay
extends Node2D
## DarkRoomOverlay: the darkness of DARK ROOMS (a room with Room.is_dark on). Made by
## the RoomManager, like the Backdrop. In a dark room everything is pitch black except
## what a light reaches:
##   - the player always carries a faint, small glow (dark_player_light_*)
##   - every fire is a light: a fireball flying through the dark gives a GLIMPSE of
##     what lies ahead (its light moves with it, and fades out behind it over
##     dark_light_fade_time); steady fires (braziers, bonfires) light a LARGER area
##   - burning grass and thicket light the room as they burn, a fire diamond glows
##
## How: one rectangle over the camera's view, drawn ABOVE the rooms (z DRAW_Z_INDEX)
## but under the HUD-like world drawings (the pips and the aim preview are at z 40),
## with a shader (dark_room.gdshader) that blacks out the pixels inside dark rooms'
## rectangles and cuts a soft, stepped, dithered hole around each light. Rooms that
## aren't dark show through untouched, so sliding from a lit room into a dark one, the
## dark comes in with the room.
##
## LIGHT SOURCES: any node in LIGHT_GROUP with get_dark_lights() -> Array[Vector4]
## (world x, world y, radius px, strength 0..1). FlameMerge (every fire made of
## flames: braziers, bonfires, fireballs, the jet, burning enemies and vines), the
## FireGrid (burning cells, grouped) and FireDiamond do. Each frame the overlay asks
## them all, keeps the ones near the view, the strongest MAX_LIGHTS of them, and
## passes them to the shader. A light that stops being reported (a fireball that
## burst) fades out instead of vanishing: the afterglow of a glimpse.
##
## Godot concepts used:
##   - ShaderMaterial on a CanvasItem: the shader runs for every pixel the node draws.
##     Uniforms (set_shader_parameter) are the values the script hands it each frame;
##     arrays of vec4 carry the lights.
##   - z_as_relative = false: our z_index is absolute, not added to the parent's.

## Light sources join this group (see the header).
const LIGHT_GROUP: StringName = &"dark_light_sources"
## Most lights and dark rooms the shader takes (its uniform arrays' sizes).
const MAX_LIGHTS: int = 64
const MAX_DARK_RECTS: int = 16
## Above the rooms and their effects, under the pips and aim preview (z 40).
const DRAW_Z_INDEX: int = 35
## Lights this far outside the view still count (their glow reaches in), px.
const VIEW_MARGIN: float = 96.0

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var camera: Camera2D
var player: Player
var rooms: Array[Room] = []
## Lights seen recently that stopped being reported, fading out: source instance id ->
## [light (Vector4), seconds of fade left].
var fading_lights: Dictionary = {}
## Last frame's lights by source (instance id -> Array[Vector4]), to notice which ones
## went away.
var last_lights: Dictionary = {}
## The view's rectangle this frame (world px), and the lights handed to the shader.
var view_rect: Rect2
var shown_lights: Array[Vector4] = []
var shader_material: ShaderMaterial


func _ready() -> void:
	z_index = DRAW_Z_INDEX
	z_as_relative = false
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://scenes/rooms/dark_room.gdshader")
	material = shader_material


## True if any room is dark (no dark room: the overlay does nothing at all).
func has_dark_rooms() -> bool:
	for room: Room in rooms:
		if room.is_dark:
			return true
	return false


func _process(delta: float) -> void:
	if camera == null or not has_dark_rooms():
		visible = false
		return
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	view_rect = Rect2(camera.get_screen_center_position() - view_size / 2.0, view_size).grow(8.0)
	var dark_rects: Array[Vector4] = _get_dark_rects()
	visible = not dark_rects.is_empty()
	if not visible:
		fading_lights.clear()
		last_lights.clear()
		return
	shown_lights = _gather_lights(delta)
	var light_array: PackedVector4Array = PackedVector4Array()
	light_array.resize(MAX_LIGHTS)
	for light_index: int in shown_lights.size():
		light_array[light_index] = shown_lights[light_index]
	var rect_array: PackedVector4Array = PackedVector4Array()
	rect_array.resize(MAX_DARK_RECTS)
	for rect_index: int in dark_rects.size():
		rect_array[rect_index] = dark_rects[rect_index]
	shader_material.set_shader_parameter(&"lights", light_array)
	shader_material.set_shader_parameter(&"light_count", shown_lights.size())
	shader_material.set_shader_parameter(&"dark_rects", rect_array)
	shader_material.set_shader_parameter(&"dark_rect_count", dark_rects.size())
	shader_material.set_shader_parameter(&"darkness", fire_tuning.dark_room_darkness)
	shader_material.set_shader_parameter(&"light_steps", float(maxi(fire_tuning.dark_light_steps, 1)))
	queue_redraw()


func _draw() -> void:
	draw_rect(view_rect, Color.BLACK)


## The dark rooms the view overlaps, as (x, y, width, height).
func _get_dark_rects() -> Array[Vector4]:
	var rects: Array[Vector4] = []
	for room: Room in rooms:
		if not room.is_dark:
			continue
		var bounds: Rect2 = room.get_bounds()
		if bounds.intersects(view_rect) and rects.size() < MAX_DARK_RECTS:
			rects.append(Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	return rects


## Every light that reaches the view this frame: the player's glow, every source's
## lights, and the fading ones. The strongest MAX_LIGHTS (by strength x radius).
func _gather_lights(delta: float) -> Array[Vector4]:
	var lights: Array[Vector4] = []
	var seen: Dictionary = {}
	if player != null and not player.is_dead():
		var center: Vector2 = player.get_center()
		lights.append(Vector4(center.x, center.y, fire_tuning.dark_player_light_radius, fire_tuning.dark_player_light_strength))
	var reach_rect: Rect2 = view_rect.grow(VIEW_MARGIN)
	for source: Node in get_tree().get_nodes_in_group(LIGHT_GROUP):
		var source_lights: Array[Vector4] = []
		for light: Vector4 in source.call(&"get_dark_lights"):
			if reach_rect.has_point(Vector2(light.x, light.y)) and light.w > 0.0:
				source_lights.append(light)
		if source_lights.is_empty():
			continue
		seen[source.get_instance_id()] = source_lights
		lights.append_array(source_lights)
	# Sources that went dark since last frame start fading (only their brightest
	# light: an afterglow, not a copy of a whole burning field).
	var fade_time: float = maxf(fire_tuning.dark_light_fade_time, 0.0)
	for source_id: int in last_lights:
		if not seen.has(source_id) and fade_time > 0.0:
			var brightest: Vector4 = Vector4.ZERO
			for light: Vector4 in last_lights[source_id]:
				if light.w * light.z > brightest.w * brightest.z:
					brightest = light
			fading_lights[source_id] = [brightest, fade_time]
	last_lights = seen
	for source_id: int in fading_lights.keys():
		var entry: Array = fading_lights[source_id]
		entry[1] = float(entry[1]) - delta
		if float(entry[1]) <= 0.0 or seen.has(source_id):
			fading_lights.erase(source_id)
			continue
		var faded: Vector4 = entry[0]
		faded.w *= float(entry[1]) / fade_time
		lights.append(faded)
	if lights.size() > MAX_LIGHTS:
		lights.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.w * a.z > b.w * b.z)
		lights.resize(MAX_LIGHTS)
	return lights
