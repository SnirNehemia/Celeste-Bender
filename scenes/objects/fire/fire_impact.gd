class_name FireImpact
extends Node2D
## FireImpact: what's left where a fireball burst (Fire_bending.md §9.3): a 2-frame
## white-hot flash disc, then 1-2 embers stuck to the surface that glow and blink
## out over `stuck_time`. The spark ring and smoke are separate (EmberEmitter,
## SmokePuff); Fireball spawns all three.
##
## FireImpact.spawn(parent, position, surface_normal, stuck_time). Frees itself.

const FLASH_COLOR: Color = Color("#FFF6CC")
const EMBER_HOT_COLOR: Color = Color("#FFD34D")
const EMBER_COOL_COLOR: Color = Color("#8A2410")
## The flash lasts two frames at 60 fps.
const FLASH_TIME: float = 2.0 / 60.0
const FLASH_RADIUS: float = 6.0

var stuck_time: float = 0.5
var age: float = 0.0
## Positions of the stuck embers, relative to this node.
var ember_offsets: Array[Vector2] = []


## `surface_normal` points away from the wall that was hit (ZERO = unknown): the
## embers sit on the surface, scattered along it.
static func spawn(parent: Node, world_position: Vector2, surface_normal: Vector2,
		ember_time: float) -> FireImpact:
	var impact: FireImpact = FireImpact.new()
	impact.stuck_time = ember_time
	var along_surface: Vector2 = surface_normal.orthogonal() if surface_normal != Vector2.ZERO else Vector2.RIGHT
	for ember_index: int in randi_range(1, 2):
		impact.ember_offsets.append((along_surface * randf_range(-3.0, 3.0)).round())
	impact.z_index = 6
	parent.add_child(impact)
	impact.global_position = world_position.round()
	return impact


func _process(delta: float) -> void:
	age += delta
	if age >= maxf(stuck_time, FLASH_TIME):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if age < FLASH_TIME:
		draw_circle(Vector2.ZERO, FLASH_RADIUS, FLASH_COLOR)
		return
	var life_left: float = 1.0 - age / stuck_time
	for ember_index: int in ember_offsets.size():
		# Blink out one by one: each ember has its own moment to die near the end.
		if life_left < 0.25 * ember_index:
			continue
		var color: Color = EMBER_COOL_COLOR.lerp(EMBER_HOT_COLOR, life_left)
		# A little flicker so they read as glowing, not as paint.
		color.a = 0.7 + 0.3 * randf()
		draw_rect(Rect2(ember_offsets[ember_index], Vector2.ONE), color)
