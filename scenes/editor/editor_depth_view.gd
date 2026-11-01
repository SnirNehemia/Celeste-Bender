class_name EditorDepthView
extends Node2D
## EditorDepthView: in the level editor, ANOTHER depth than the one being edited
## (Level_editor.md §5a), lined up 1:1 (no parallax): a room there shows exactly
## at its map spot, so you see which room is behind which and can place depth
## gates and their twins by eye. The map (M) and the room view both show it; the
## depth being edited is LevelEditor.get_shown_depth(). The editor has two:
##   - BEHIND (`direction` +1): the next deeper depth, under the level, through
##     the game's haze shader (back_room_haze.gdshader), as in play; and (a test)
##     BackRoomView.DEEPER_LAYERS more under that (+2, +3...), fainter, with the
##     same haze as in play (BackRoomView.layer_haze), opaque like there;
##   - IN FRONT (`direction` -1, after the D play-test): the next shallower depth,
##     OVER the level, very faint (FRONT_ALPHA), so you see what will hide this
##     depth's rooms in play without it getting in the way.
##
## HOW: like the game's BackRoomView, a SubViewport that shares the editor's
## World2D with its own Camera2D, here a copy of the editor camera moved one band
## (Room.depth_offset(direction)); this node draws its picture over exactly what
## the editor camera shows. The SubViewports must not draw the editor's own
## backdrop, overlay or these pictures (one would draw itself): those are on
## render layer 2 only (EDITOR_ONLY_LAYER, CanvasItem.visibility_layer), and the
## SubViewports' canvas_cull_mask shows layer 1 only.

## The render layer (bit value) of the editor's own drawings (backdrop, overlay,
## these views): the main view shows them, the SubViewports don't.
const EDITOR_ONLY_LAYER: int = 2
## Only the level's own nodes (render layer 1) are drawn in the SubViewports.
const LEVEL_LAYER: int = 1
## How strongly the depth in front shows over the level (0-1).
const FRONT_ALPHA: float = 0.16

var editor: LevelEditor
## Which depth, from the shown one: +1 behind, -1 in front. Set before _ready.
var direction: int = 1

var _viewport: SubViewport = null
var _view_camera: Camera2D = null


func _ready() -> void:
	visibility_layer = EDITOR_ONLY_LAYER
	_viewport = SubViewport.new()
	_viewport.name = "DepthViewport"
	_viewport.size = LevelEditor.EDITOR_VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.world_2d = get_viewport().world_2d
	_viewport.canvas_cull_mask = LEVEL_LAYER
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_view_camera = Camera2D.new()
	_view_camera.name = "DepthCamera"
	_viewport.add_child(_view_camera)
	_view_camera.make_current()
	if direction > 0:
		var haze: ShaderMaterial = ShaderMaterial.new()
		haze.shader = BackRoomView.HAZE_SHADER
		material = haze
	else:
		modulate.a = FRONT_ALPHA


func _process(_delta: float) -> void:
	var is_shown: bool = editor.level_root != null and not editor.is_playtesting \
		and has_rooms_at(editor.get_shown_depth() + direction)
	# Off when nothing is there: each drawn frame is a whole extra drawing of the level.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_shown else SubViewport.UPDATE_DISABLED
	visible = is_shown
	if not is_shown:
		return
	# Hazed toward the main color of the backdrop the room being edited shows, as
	# in play (Backdrop.get_main_color; worked out once per look).
	if material != null:
		# The same look as in play: haze, flatter colors, blur.
		BackRoomView.apply_look(material as ShaderMaterial, direction)
	if material != null and editor.current_room != null:
		var room: Room = editor.current_room
		(material as ShaderMaterial).set_shader_parameter(&"haze_color",
			Backdrop.get_main_color(room.get_backdrop_theme(), room.get_backdrop_altitude(editor.get_start_room())))
	# The editor camera, one band down (behind) or up (in front): the same map spot.
	_view_camera.position = editor.camera.position + Room.depth_offset(direction)
	_view_camera.zoom = editor.camera.zoom
	queue_redraw()


## True if a room of the level is at `depth` (never for a depth below 0).
func has_rooms_at(depth: int) -> bool:
	if depth < 0:
		return false
	for room: Room in editor.get_rooms():
		if room.get_depth() == depth:
			return true
	return false


## True while the view is drawn. For tests.
func is_rendering() -> bool:
	return _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func _draw() -> void:
	# Over exactly what the editor camera shows: the picture is the same size in
	# screen pixels, so it lines up 1:1.
	draw_texture_rect(_viewport.get_texture(), editor._visible_world_rect(), false)
