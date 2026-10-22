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
## base_drop px lower (FlameTongue.draw_layer), so neighbouring bases overlap into one
## bed of flame instead of separate feet.
##
## Redrawing: a canvas item keeps showing its last drawing until it's asked to draw
## again. So when a tongue leaves (a fire burnt out, or R cleared it) we redraw once
## more, or its last frame would stay frozen on screen.
##
## Cost: none extra. The tongues' polygons are built and drawn as before, only onto
## one canvas item (two, with the additive one) instead of two per tongue.

## The tongues' layers, drawn in this order (see FlameTongue.draw_layer).
const OUTER_LAYERS: Array[int] = [FlameTongue.Layer.EDGE, FlameTongue.Layer.BODY]
const HOT_LAYERS: Array[int] = [FlameTongue.Layer.INNER, FlameTongue.Layer.CORE]

## How much wider each tongue's base is drawn, and how far lower (px, along the
## tongue's own "down"), so neighbouring tongues' feet overlap.
@export var base_widen: float = 1.8
@export var base_drop: float = 1.0

var tongues: Array[FlameTongue] = []
## The additive child the inner and core layers are drawn into.
var core_layer: Node2D


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


func _process(_delta: float) -> void:
	# The tongues change every frame (noise), so the merged drawing does too.
	if not tongues.is_empty():
		queue_redraw()
		core_layer.queue_redraw()


func _draw() -> void:
	_draw_layers(self, OUTER_LAYERS)


func _draw_hot_layers() -> void:
	_draw_layers(core_layer, HOT_LAYERS)


## Draws `layers` of every visible tongue onto `on_item`, all tongues one layer at a
## time, each through its transform relative to us.
func _draw_layers(on_item: CanvasItem, layers: Array[int]) -> void:
	var to_local_space: Transform2D = get_global_transform().affine_inverse()
	for layer: int in layers:
		for tongue: FlameTongue in tongues:
			if not is_instance_valid(tongue) or not tongue.is_visible_in_tree() or not tongue.has_flame():
				continue
			on_item.draw_set_transform_matrix(to_local_space * tongue.get_global_transform())
			tongue.draw_layer(on_item, layer)
	on_item.draw_set_transform_matrix(Transform2D.IDENTITY)
