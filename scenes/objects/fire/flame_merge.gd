class_name FlameMerge
extends Node2D
## FlameMerge (F7 play-test): draws a group of FlameTongues as ONE fire. Every fire
## that is more than one tongue (a bonfire, a brazier, burning grass, the jet plume, a
## fireball) puts its tongues in a FlameMerge.
##
## Why: a FlameTongue drawn on its own paints its red edge, then its orange body,
## then its hot core. Two overlapping tongues drawn one after the other show the
## second one's red edge over the first one's body: an outline INSIDE the fire, so
## neighbouring tongues read as separate little fires. The merge draws by LAYER
## instead: every tongue's edge, then every tongue's body, then (into an additive
## child) every tongue's inner and core layers. Overlapping tongues then share one
## outline: the red edge only shows around the outside of the whole group.
##
## Each tongue still moves itself (its noise, size, lean...) and still draws its own
## licks and smoke; only its three main layers move here (FlameTongue.merge, set by
## add_tongue). The tongues can be anywhere in the tree: each is drawn through its
## transform relative to this node.
##
## Order: this node takes the tongues' z_index (from the first one added), and when it
## shares a parent with them it moves itself after them, so the merged fire is drawn
## over the tongues' own licks and smoke, like before.
##
## Bases: inside a merge each tongue's base is drawn base_widen times wider and
## base_drop px lower (FlameTongue.get_layer_shape), so neighbouring bases overlap into one
## bed of flame instead of separate feet.
##
## Redrawing: a canvas item keeps showing its last drawing until it's asked to draw
## again. So when a tongue leaves (a fire burnt out, or R cleared it) we redraw once
## more, or its last frame would stay frozen on screen.
##
## HEAT GLOW (Stage F13, Fire_bending.md §9.2 item 4): every merged fire also lights
## what's around it, one soft additive glow (HeatGlow.draw_glow) under the whole
## group: centered on the visible tongues, as wide as they spread plus
## heat_glow_reach times their length, yellower the hotter they burn, flickering.
## So braziers, bonfires, fireballs, the jet plume, burning enemies and vines all
## light up their surroundings with no code of their own. A fire that draws its own
## glows (the FireGrid: one per cell) turns it off with `has_heat_glow = false`.
##
## DARK ROOMS: every merged fire is also a LIGHT (DarkRoomOverlay.LIGHT_GROUP,
## get_dark_lights): centered where its glow is, dark_fire_light_scale times the
## glow's radius, times `light_scale` (a brazier or bonfire sets a bigger one: steady
## fires light a larger area). The FireGrid lights its cells itself (`has_light` off).
##
## Cost: less than separate tongues. The tongues' polygons are built as before, but
## sent to the renderer as one triangle list per canvas item (two, with the additive
## one), not one draw command per tongue and layer (see _draw_layers).

## The tongues' layers, drawn in this order (see FlameTongue.get_layer_shape).
const OUTER_LAYERS: Array[int] = [FlameTongue.Layer.EDGE, FlameTongue.Layer.BODY]
const HOT_LAYERS: Array[int] = [FlameTongue.Layer.INNER, FlameTongue.Layer.CORE]

## How much wider each tongue's base is drawn, and how far lower (px, along the
## tongue's own "down"), so neighbouring tongues' feet overlap.
@export var base_widen: float = 1.8
@export var base_drop: float = 1.0
## Draw the heat glow under the fire (see the header).
@export var has_heat_glow: bool = true
## Light up dark rooms (see the header), and how much bigger than a plain fire's.
@export var has_light: bool = true
@export var light_scale: float = 1.0

## The warm light's color at a cool and at a white-hot fire (§9.1 body and inner).
const GLOW_COOL_COLOR: Color = Color(1.0, 0.5, 0.16)
const GLOW_HOT_COLOR: Color = Color(1.0, 0.78, 0.35)
## The glow stands this share of the flames' length above their bases.
const GLOW_RISE_SHARE: float = 0.35

var tongues: Array[FlameTongue] = []
## The additive child the inner and core layers are drawn into.
var core_layer: Node2D
## The additive child the heat glow is drawn into, behind the flames.
var glow_layer: Node2D
## Seconds of flicker, from a random start (two fires never pulse together).
var glow_time: float = 0.0
var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")


func _ready() -> void:
	if name.is_empty() or name.begins_with("@"):
		name = "FlameMerge"
	core_layer = Node2D.new()
	core_layer.name = "Core"
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core_layer.material = additive
	add_child(core_layer)
	core_layer.draw.connect(_draw_hot_layers)
	glow_layer = Node2D.new()
	glow_layer.name = "HeatGlow"
	glow_layer.show_behind_parent = true  # under the flames: light, not a veil
	var glow_additive: CanvasItemMaterial = CanvasItemMaterial.new()
	glow_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = glow_additive
	add_child(glow_layer)
	glow_layer.draw.connect(_draw_heat_glow)
	glow_time = randf() * 100.0
	add_to_group(DarkRoomOverlay.LIGHT_GROUP)


## A FlameMerge added to `parent`: put tongues in it with add_tongue().
static func make(parent: Node) -> FlameMerge:
	var merge: FlameMerge = FlameMerge.new()
	parent.add_child(merge)
	return merge


func add_tongue(tongue: FlameTongue) -> void:
	if tongues.is_empty():
		z_index = tongue.z_index
		z_as_relative = tongue.z_as_relative
	tongues.append(tongue)
	tongue.merge = self
	# Drawn after the tongues' own licks and smoke (siblings draw in tree order).
	if tongue.get_parent() == get_parent() and get_parent() != null:
		get_parent().move_child(self, -1)


func remove_tongue(tongue: FlameTongue) -> void:
	tongues.erase(tongue)
	# One more redraw without it: if it was the last one, _process stops redrawing,
	# and the old picture would otherwise stay on screen (frozen flames after R).
	queue_redraw()
	if core_layer != null:
		core_layer.queue_redraw()
		glow_layer.queue_redraw()


func _process(delta: float) -> void:
	# The tongues change every frame (noise), so the merged drawing does too.
	if not tongues.is_empty():
		glow_time += delta
		queue_redraw()
		core_layer.queue_redraw()
		glow_layer.queue_redraw()


## One soft glow under the visible tongues (see the header).
func _draw_heat_glow() -> void:
	if not has_heat_glow:
		return
	var glow: Array = _get_glow_shape()
	if not glow.is_empty():
		HeatGlow.draw_glow(glow_layer, glow[0], glow[1], glow[2])


## The light of this fire in a dark room (DarkRoomOverlay): one light where the glow
## is, scaled up. None while no tongue shows.
func get_dark_lights() -> Array[Vector4]:
	var lights: Array[Vector4] = []
	if not has_light or not is_visible_in_tree():
		return lights
	var glow: Array = _get_glow_shape()
	if glow.is_empty():
		return lights
	var world_center: Vector2 = to_global(glow[0])
	var radius: float = float(glow[1]) * fire_tuning.dark_fire_light_scale * light_scale
	var strength: float = clampf((glow[2] as Color).a / maxf(fire_tuning.heat_glow_alpha, 0.001), 0.0, 1.0)
	lights.append(Vector4(world_center.x, world_center.y, radius, strength))
	return lights


## The glow under the visible tongues this frame: [center (our local px), radius,
## color], or [] when no tongue shows.
func _get_glow_shape() -> Array:
	var to_local_space: Transform2D = get_global_transform().affine_inverse()
	var middles: PackedVector2Array = PackedVector2Array()
	var total_length: float = 0.0
	var total_heat: float = 0.0
	var total_opacity: float = 0.0
	for tongue: FlameTongue in tongues:
		if not is_instance_valid(tongue) or not tongue.is_visible_in_tree() or not tongue.has_flame():
			continue
		var tongue_to_us: Transform2D = to_local_space * tongue.get_global_transform()
		middles.append(tongue_to_us * Vector2(0.0, -tongue.length * GLOW_RISE_SHARE))
		# The length as drawn: a scaled-down tongue (a guttering fireball) glows less.
		total_length += tongue.length * tongue_to_us.get_scale().y
		total_heat += tongue.heat
		total_opacity += tongue.opacity
	if middles.is_empty():
		return []
	var count: float = float(middles.size())
	var center: Vector2 = Vector2.ZERO
	for middle: Vector2 in middles:
		center += middle
	center /= count
	var spread: float = 0.0
	for middle: Vector2 in middles:
		spread = maxf(spread, middle.distance_to(center))
	var average_length: float = total_length / count
	var flicker: float = HeatGlow.get_flicker(glow_time * 7.0, 0.18)
	var radius: float = (spread + average_length * fire_tuning.heat_glow_reach + 3.0) * (1.0 + (flicker - 1.0) * 0.5)
	var color: Color = GLOW_COOL_COLOR.lerp(GLOW_HOT_COLOR, total_heat / count)
	color.a = fire_tuning.heat_glow_alpha * (total_opacity / count) * flicker
	return [center, radius, color]


func _draw() -> void:
	_draw_layers(self, OUTER_LAYERS)


func _draw_hot_layers() -> void:
	_draw_layers(core_layer, HOT_LAYERS)


## Draws `layers` of every visible tongue onto `on_item`, all tongues one layer at a
## time, each through its transform relative to us. Everything goes to the renderer
## as ONE triangle list (play-test: a burning room had ~100 tongues, and one draw
## command per tongue and layer, ~400 a frame, cost more than everything else in
## the fire). The list keeps the order: every tongue's first layer, then every
## tongue's second, so the outline still only shows around the outside.
func _draw_layers(on_item: CanvasItem, layers: Array[int]) -> void:
	var to_local_space: Transform2D = get_global_transform().affine_inverse()
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for layer: int in layers:
		for tongue: FlameTongue in tongues:
			if not is_instance_valid(tongue) or not tongue.is_visible_in_tree() or not tongue.has_flame():
				continue
			var shape: Array = tongue.get_layer_shape(layer)
			if shape.is_empty():
				continue
			# Cut into triangles in the tongue's own space (its size limits are in
			# its own px), then moved into ours.
			var fill: Array = FlameTongue.prepare_fill(shape[0])
			if fill.is_empty():
				continue
			var first_vertex: int = points.size()
			points.append_array((to_local_space * tongue.get_global_transform()) * (fill[0] as PackedVector2Array))
			for vertex_index: int in fill[1]:
				indices.append(first_vertex + vertex_index)
			var color: Color = shape[1]
			for vertex_index: int in (fill[0] as PackedVector2Array).size():
				colors.append(color)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(on_item.get_canvas_item(), indices, points, colors)
