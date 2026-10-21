class_name FireRing
extends Node2D
## FireRing: a thin ring of fire light that grows from a point and fades, one shot.
## The jet's ignition "whoomp" and its chain pump flare (Fire_bending.md §9.3); later
## braziers lighting up. Additive, so it reads as a flash of heat, not a shape.
##
## Spawn it with FireRing.spawn(parent, position, radius, duration). It frees itself.

const RING_COLOR: Color = Color("#FFD34D")
const RING_OUTER_COLOR: Color = Color("#FF8A1E")

var max_radius: float = 10.0
var duration: float = 0.18
var age: float = 0.0


static func spawn(parent: Node, world_position: Vector2, radius: float, ring_duration: float) -> FireRing:
	var ring: FireRing = FireRing.new()
	ring.max_radius = radius
	ring.duration = ring_duration
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = additive
	ring.z_index = 6
	parent.add_child(ring)
	ring.global_position = world_position
	return ring


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(age / duration, 0.0, 1.0)
	# ease-out: grows fast, then slows, like a pressure wave losing energy.
	var radius: float = max_radius * (1.0 - pow(1.0 - progress, 3.0))
	var fade: float = 1.0 - progress
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(RING_OUTER_COLOR, fade * 0.8), 2.0)
	draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 16, Color(RING_COLOR, fade), 1.0)
