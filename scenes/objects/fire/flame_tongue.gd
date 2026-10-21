class_name FlameTongue
extends Node2D
## FlameTongue: one living tongue of flame, the first fire building block
## (Fire_bending.md §9.2). Every flame in the Fire chapter is made of these: the jet
## plume now, braziers, bonfires and burning grass later.
##
## It draws a 7-point polygon from its origin (the BASE of the flame) toward local
## -Y (up). Rotate the node to point the flame elsewhere (the jet plume rotates it to
## point away from the thrust). The polygon's sides and tip are pushed around by
## FastNoiseLite, scrolled over time, so the tip licks and splits; the length
## "breathes" ±breath_amount on a slower noise.
##
## Three nested layers, each a little smaller and faster than the one around it:
##   edge  (red-orange, normal blend)  the outline, reads on bright ground
##   body  (orange,     normal blend)
##   core  (white-yellow, ADDITIVE)    on a child CanvasItem with an additive
##                                     material, so it glows over whatever is behind
## `heat` (0..1) blends the core from yellow to white-hot and grows it: the jet sets it
## from the thrust, so the plume is whitest at ignition.
##
## The "dance" (after the F3 play-test):
##   - FORKED TIP: on noise, the tip splits into two points with a notch between
##     them, which sway apart and rejoin (`fork_amount`, 0 = a single point).
##   - SHED LICKS: small flame blobs tear off the tip (`lick_rate` per second), then
##     flutter sideways, shrink and cool from orange to red as they drift away along
##     the flame's direction. They live in WORLD coordinates, so a moving flame (the
##     jet) leaves them behind, like a campfire shedding pieces of flame.
##
## Godot concepts used:
##   - _draw(): custom drawing for a CanvasItem; queue_redraw() asks for it again.
##   - The `draw` signal of ANOTHER CanvasItem: connecting to a child's `draw` lets this
##     script draw into the child's canvas item, which carries its own material.
##   - CanvasItemMaterial.BLEND_MODE_ADD: colors are added to what's behind (light).
##   - FastNoiseLite: smooth random noise; sampling it at (time, index) gives values
##     that wander smoothly, unlike randf() which jumps every frame.

## Fire palette (Fire_bending.md §9.1).
const CORE_COLOR: Color = Color("#FFF6CC")
const INNER_COLOR: Color = Color("#FFD34D")
const BODY_COLOR: Color = Color("#FF8A1E")
const EDGE_COLOR: Color = Color("#E8431A")

## Flame length from base to tip, px (before breathing).
@export var length: float = 12.0
## Width at the base and at the widest point (about 40% up), px.
@export var base_width: float = 6.0
@export var fan_width: float = 8.0
## 0 = a cool flame (small yellow core), 1 = white-hot (big white core).
@export_range(0.0, 1.0) var heat: float = 0.5
## How far the sides and tip wander, as a fraction of the width.
@export var wobble_amount: float = 0.35
## Length breathing, ± fraction (0.2 = ±20%).
@export var breath_amount: float = 0.2
## Noise scroll speed: higher = faster licking.
@export var flicker_speed: float = 1.0
## Overall opacity (fading a whole tongue out).
@export_range(0.0, 1.0) var opacity: float = 1.0
## How far the tip forks: 0 = always one point, 1 = splits wide and often.
@export_range(0.0, 1.0) var fork_amount: float = 0.6
## Licks torn off the tip per second (0 = none), and how they fly.
@export var lick_rate: float = 0.0
@export var lick_speed: float = 40.0
@export var lick_lifetime: float = 0.25
## A fresh lick's size, px (its length; it's about 60% as wide).
@export var lick_size: float = 4.0

## How hard a lick flutters sideways (px) and how fast (radians per second).
const LICK_FLUTTER_AMPLITUDE: float = 1.5
const LICK_FLUTTER_SPEED: float = 30.0
## Licks alive at most per tongue, so a long burst can't pile them up.
const MAX_LICKS: int = 16

## The additive layer's canvas item (child node), drawn through its `draw` signal.
var core_layer: Node2D
var noise: FastNoiseLite
## Time fed to the noise. Advances with game time, so slow motion slows the flame.
var noise_time: float = 0.0
## Licks in flight. Each: {position (world), velocity (world), age, lifetime, size,
## phase (flutter offset)}.
var licks: Array[Dictionary] = []
## Fractional licks owed: lick_rate × delta adds up until a whole one is due.
var lick_spawn_debt: float = 0.0


func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	# A different seed per tongue, so neighbouring tongues never move in step.
	noise.seed = randi()
	noise_time = randf() * 100.0
	core_layer = Node2D.new()
	core_layer.name = "Core"
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core_layer.material = additive
	add_child(core_layer)
	core_layer.draw.connect(_draw_core)


func _process(delta: float) -> void:
	noise_time += delta * flicker_speed
	_update_licks(delta)
	queue_redraw()
	core_layer.queue_redraw()


## Tears new licks off the tip and moves/ages the ones in flight.
func _update_licks(delta: float) -> void:
	# Only a visible, burning tongue sheds; licks already torn off finish their life.
	if is_visible_in_tree() and lick_rate > 0.0 and length >= 2.0 and opacity > 0.0:
		lick_spawn_debt += lick_rate * delta
		while lick_spawn_debt >= 1.0:
			lick_spawn_debt -= 1.0
			_spawn_lick()
	else:
		lick_spawn_debt = 0.0
	for lick: Dictionary in licks:
		lick["age"] += delta
		lick["position"] += lick["velocity"] * delta
		# Drag: the lick loses speed as it burns out.
		lick["velocity"] *= 1.0 - minf(4.0 * delta, 1.0)
	licks = licks.filter(func(lick: Dictionary) -> bool: return lick["age"] < lick["lifetime"])


## A lick starts at the flame's tip (where the noise has it this frame) and flies
## on along the flame's direction, up to 20° to one side.
func _spawn_lick() -> void:
	if licks.size() >= MAX_LICKS:
		return
	var tip_local: Vector2 = Vector2(fan_width * wobble_amount * 1.4 * _wander(noise_time, 3.0), -length * 0.9)
	# The flame's "up" (local -Y) as a world direction.
	var flame_up: Vector2 = Vector2.UP.rotated(global_rotation)
	var direction: Vector2 = flame_up.rotated(deg_to_rad(randf_range(-20.0, 20.0)))
	licks.append({
		"position": to_global(tip_local),
		"velocity": direction * lick_speed * randf_range(0.7, 1.3),
		"age": 0.0,
		"lifetime": lick_lifetime * randf_range(0.6, 1.2),
		"size": lick_size * randf_range(0.7, 1.2),
		"phase": randf() * TAU,
	})


## A lick's outline in LOCAL space: a teardrop pointing along its flight, shrinking
## with age, shifted sideways by the flutter. `scale_factor` < 1 for the inner layer.
func _make_lick_polygon(lick: Dictionary, scale_factor: float) -> PackedVector2Array:
	var life_left: float = 1.0 - lick["age"] / lick["lifetime"]
	var lick_length: float = lick["size"] * life_left * scale_factor
	var half_width: float = lick_length * 0.3
	var velocity: Vector2 = lick["velocity"]
	var forward: Vector2 = velocity.normalized() if velocity.length() > 0.01 else Vector2.UP
	var side: Vector2 = forward.orthogonal()
	var flutter: float = sin(lick["age"] * LICK_FLUTTER_SPEED + lick["phase"]) * LICK_FLUTTER_AMPLITUDE
	var center: Vector2 = to_local(lick["position"] + side * flutter)
	# World directions into this node's (possibly rotated) local space.
	forward = forward.rotated(-global_rotation)
	side = side.rotated(-global_rotation)
	return PackedVector2Array([
		center + forward * lick_length * 0.6,
		center + side * half_width,
		center - forward * lick_length * 0.4,
		center - side * half_width,
	])


## Draws every lick into `on_item`: the outer body (normal blend) or, for young
## licks, a hot center (into the additive layer).
func _draw_licks(on_item: CanvasItem, inner: bool) -> void:
	for lick: Dictionary in licks:
		var life_left: float = 1.0 - lick["age"] / lick["lifetime"]
		if lick["size"] * life_left < 0.6:
			continue
		if inner:
			if life_left > 0.5:
				_fill(on_item, _make_lick_polygon(lick, 0.5), Color(INNER_COLOR, opacity * life_left))
		else:
			# Orange when torn off, cooling to red as it dies.
			var color: Color = BODY_COLOR.lerp(EDGE_COLOR, 1.0 - life_left)
			_fill(on_item, _make_lick_polygon(lick, 1.0), Color(color, opacity))


func _draw() -> void:
	_draw_licks(self, false)
	if length < 0.5 or opacity <= 0.0:
		return
	# Outer layers: normal blending, drawn into this node.
	_fill(self, _make_polygon(1.0, 1.0, 0.0), Color(EDGE_COLOR, opacity))
	_fill(self, _make_polygon(0.78, 0.85, 7.0), Color(BODY_COLOR, opacity))


## The hot layers, drawn into the additive child.
func _draw_core() -> void:
	_draw_licks(core_layer, true)
	if length < 0.5 or opacity <= 0.0:
		return
	var inner_scale: float = lerpf(0.45, 0.6, heat)
	_fill(core_layer, _make_polygon(inner_scale, inner_scale + 0.1, 13.0),
		Color(INNER_COLOR, 0.8 * opacity))
	var core_scale: float = lerpf(0.2, 0.42, heat)
	var core_color: Color = INNER_COLOR.lerp(CORE_COLOR, heat)
	_fill(core_layer, _make_polygon(core_scale, core_scale + 0.05, 19.0),
		Color(core_color, opacity))


## The flame outline for one layer. `width_scale`/`length_scale` shrink the layer,
## `noise_offset` gives each layer its own wander (and inner layers move faster).
## Points go base-left, up the left side, tip, down the right side, base-right.
func _make_polygon(width_scale: float, length_scale: float, noise_offset: float) -> PackedVector2Array:
	# Inner layers flicker faster: their noise time runs ahead.
	var t: float = noise_time * (1.0 + noise_offset * 0.05)
	var breath: float = 1.0 + breath_amount * noise.get_noise_2d(t * 0.6, 50.0 + noise_offset)
	var flame_length: float = length * length_scale * breath
	var half_base: float = base_width * width_scale * 0.5
	var half_fan: float = fan_width * width_scale * 0.5
	var wobble: float = fan_width * width_scale * wobble_amount
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-half_base, 0.0))
	points.append(Vector2(-half_fan + wobble * _wander(t, 1.0 + noise_offset), -flame_length * 0.4))
	points.append(Vector2(-half_fan * 0.55 + wobble * _wander(t, 2.0 + noise_offset), -flame_length * 0.72))
	# The tip swings the most: that's the "licking". It forks on slow noise: `split`
	# 0 = one point; up to 1 = two points apart with a notch between them, each of a
	# different height, so the two halves seem to dance around each other.
	# Clamped inside the fan, so the tip never swings past the flame's own sides.
	var tip_x: float = clampf(wobble * 1.4 * _wander(t, 3.0 + noise_offset), -half_fan * 0.4, half_fan * 0.4)
	var split: float = fork_amount * clampf(noise.get_noise_2d(t * 1.5, 90.0 + noise_offset) * 2.0, 0.0, 1.0)
	if split < 0.05:
		points.append(Vector2(tip_x, -flame_length))
	else:
		var half_gap: float = half_fan * 0.45 * split
		var height_sway: float = 0.12 * split * _wander(t, 6.0 + noise_offset)
		points.append(Vector2(tip_x - half_gap, -flame_length * (1.0 - 0.12 * split + height_sway)))
		points.append(Vector2(tip_x, -flame_length * (1.0 - 0.35 * split)))  # the notch
		points.append(Vector2(tip_x + half_gap, -flame_length * (1.0 - 0.12 * split - height_sway)))
	points.append(Vector2(half_fan * 0.55 + wobble * _wander(t, 4.0 + noise_offset), -flame_length * 0.72))
	points.append(Vector2(half_fan + wobble * _wander(t, 5.0 + noise_offset), -flame_length * 0.4))
	points.append(Vector2(half_base, 0.0))
	return points


## Smooth noise in -1..1 for one vertex (`row` keeps vertices independent).
func _wander(t: float, row: float) -> float:
	return noise.get_noise_2d(t * 4.0, row * 13.0)


## Fills `points` on `on_item`. The noise can fold a forked tip over itself, and Godot
## can't fill a self-crossing outline ("triangulation failed"); then the convex hull
## (the outline with its dents filled in) is drawn instead, for that one frame.
func _fill(on_item: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(points).is_empty():
		points = Geometry2D.convex_hull(points)
		if points.size() < 4:  # convex_hull repeats the first point at the end
			return
	on_item.draw_colored_polygon(points, color)
