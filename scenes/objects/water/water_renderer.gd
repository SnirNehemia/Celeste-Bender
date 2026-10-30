class_name WaterRenderer
extends Node2D
## WaterRenderer (Stage W2, Water_bending.md §6.3): draws a room's loose water
## (its particles) as METABALLS, so drops that touch flow together into smooth
## blobs instead of looking like a swarm of squares. A child of the WaterWorld,
## which makes it in _ready(); the bodies (pools) are still drawn by the WaterWorld.
##
## How 2D metaballs work, in two passes:
##   1. Every particle is drawn as a SOFT DOT (bright in the middle, fading to
##      nothing at blob_dot_radius) into a picture of its own, a SubViewport, with
##      ADDITIVE blending: where dots overlap, their brightness adds up. The picture
##      is the size of the game screen and follows the camera.
##   2. This node draws that picture over the screen with a THRESHOLD shader
##      (water_blob.gdshader): pixels brighter than blob_threshold are water, the
##      rest are see-through. Two dots near each other add up between them too, so
##      they join with a smooth neck, like real drops; a lighter rim marks the edge.
## A SubViewport is a separate render target: its own little screen that nodes
## inside it draw into, which can then be used as a texture (get_texture()).
##
## Cost: GPU only (one extra small render + one shader pass), nothing from the 2 ms
## CPU budget except one draw call per particle into the picture, which Godot
## batches. Skipped in headless runs (no renderer there): is_drawing_particles() is
## false, and the WaterWorld draws plain squares instead (also the fallback when
## WaterTuning.use_metaballs is off, §6.3).

const BLOB_SHADER: Shader = preload("res://scenes/objects/water/water_blob.gdshader")
## The soft dot's picture size, px (it's scaled to the dot's size when drawn).
const DOT_TEXTURE_SIZE: int = 16

var world: WaterWorld
## The picture the dots are drawn into, and the node inside it that draws them.
var blob_viewport: SubViewport
var dot_layer: Node2D
var dot_texture: GradientTexture2D
var blob_material: ShaderMaterial


func _ready() -> void:
	world = get_parent() as WaterWorld
	if DisplayServer.get_name() == "headless":
		return  # nothing is rendered in headless runs: no metaballs (tests)
	blob_viewport = SubViewport.new()
	blob_viewport.name = "BlobViewport"
	blob_viewport.transparent_bg = true
	blob_viewport.disable_3d = true
	blob_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	blob_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(blob_viewport)
	dot_layer = Node2D.new()
	dot_layer.name = "Dots"
	# ADD blending: overlapping dots sum their brightness (the "field").
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dot_layer.material = additive
	# The dot picture is tiny and scaled up: smooth (linear) sampling keeps it soft.
	dot_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	dot_layer.draw.connect(_draw_dots)
	blob_viewport.add_child(dot_layer)
	dot_texture = _make_dot_texture()
	blob_material = ShaderMaterial.new()
	blob_material.shader = BLOB_SHADER
	material = blob_material
	# The blob picture is read 1:1 with the screen's pixels: keep them crisp.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## True when particles are drawn here as metaballs (not by the WaterWorld as squares).
func is_drawing_particles() -> bool:
	return blob_viewport != null and world.water_tuning.use_metaballs


## Called by the WaterWorld after each step: redraw the dots and the blobs.
func refresh() -> void:
	if not is_drawing_particles():
		return
	dot_layer.queue_redraw()
	queue_redraw()


## Every rendered frame: the dot picture follows the camera. The main viewport's
## canvas_transform is what the Camera2D sets (world -> screen); the SubViewport gets
## the same one, so a dot lands on the same screen pixel as the particle would.
func _process(_delta: float) -> void:
	if not is_drawing_particles():
		return
	blob_viewport.canvas_transform = get_viewport().canvas_transform
	dot_layer.transform = world.global_transform  # particles are room-local
	var tuning: WaterTuning = world.water_tuning
	blob_material.set_shader_parameter(&"threshold", tuning.blob_threshold)
	blob_material.set_shader_parameter(&"foam_strength", tuning.particle_foam_strength)
	if _has_dots():
		dot_layer.queue_redraw()
		queue_redraw()


## Anything to draw: particles, or the ball in the player's hands (Stage W3).
func _has_dots() -> bool:
	return not world.drop_positions.is_empty() or not world.held_dots.is_empty()


## Pass 1, inside the SubViewport: one soft dot per particle. A fast one is
## STRETCHED along its velocity (Water_bending.md §6.2, waterfalls), so a pour reads
## as one ribbon of water instead of a dotted line; still water stays round.
func _draw_dots() -> void:
	var tuning: WaterTuning = world.water_tuning
	var radius: float = tuning.blob_dot_radius
	var dot_rect: Rect2 = Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var positions: PackedVector2Array = world.drop_positions
	var velocities: PackedVector2Array = world.drop_velocities
	var foams: PackedFloat32Array = world.drop_foam
	var foam_start: float = tuning.particle_foam_speed_start
	var foam_range: float = maxf(1.0, tuning.particle_foam_speed_full - foam_start)
	for index: int in positions.size():
		var velocity: Vector2 = velocities[index]
		var speed: float = velocity.length()
		var stretch: float = 1.0 + speed * tuning.blob_stretch
		# FOAM rides in the dot's green channel: red is "how much water" (the field the
		# threshold reads), green is "how much of it is white water". Both add up where
		# dots overlap, so green / red in the shader is the foam share of that spot.
		var foam: float = maxf(foams[index], clampf((speed - foam_start) / foam_range, 0.0, 1.0))
		# draw_set_transform: everything drawn next is moved, turned and scaled, so the
		# dot is drawn around (0, 0), long along x, turned to point along the velocity.
		dot_layer.draw_set_transform(positions[index], velocity.angle(), Vector2(stretch, 1.0))
		# BLACK water (Stage W7a) rides in blue the same way: the shader draws ink.
		var ink: float = 1.0 if world.drop_groups[index] == WaterWorld.BLACK_GROUP else 0.0
		dot_layer.draw_texture_rect(dot_texture, dot_rect, false, Color(1.0, foam, ink, 1.0))
	# The held ball (Stage W3): plain round dots, no foam. The same blobs as loose
	# water, so the ball and the water it lets go of look like one thing.
	for dot: Vector2 in world.held_dots:
		dot_layer.draw_set_transform(dot, 0.0, Vector2.ONE)
		dot_layer.draw_texture_rect(dot_texture, dot_rect, false, Color(1.0, 0.0, 0.0, 1.0))
	dot_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pass 2: the dot picture over the whole screen, through the threshold shader.
func _draw() -> void:
	if not is_drawing_particles() or not _has_dots():
		return
	# Where the screen's corners are in this node's own coordinates.
	var screen_to_local: Transform2D = global_transform.affine_inverse() * get_viewport().canvas_transform.affine_inverse()
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var top_left: Vector2 = screen_to_local * Vector2.ZERO
	var bottom_right: Vector2 = screen_to_local * screen_size
	draw_texture_rect(blob_viewport.get_texture(), Rect2(top_left, bottom_right - top_left), false)


## A white dot fading from full in the middle to nothing at the edge (radial).
func _make_dot_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = DOT_TEXTURE_SIZE
	texture.height = DOT_TEXTURE_SIZE
	return texture
