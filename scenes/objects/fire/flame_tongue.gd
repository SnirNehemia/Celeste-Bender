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
##   - SMOKE: a lick burns for its first part only, then turns into a wisp of smoke
##     that floats UP (whichever way the flame points), grows and fades. Tips can also
##     give off a thin trail of smoke of their own (`smoke_rate`).
##
## MERGED FIRES (F7 play-test): when `merge` is set (FlameMerge.add_tongue), this
## tongue doesn't draw its own edge, body, inner and core layers: the FlameMerge
## draws every tongue of its fire layer by layer (draw_layer), so overlapping tongues
## share one outline instead of looking like separate fires. The tongue still draws
## its own licks and smoke.
##
## Godot concepts used:
##   - _draw(): custom drawing for a CanvasItem; queue_redraw() asks for it again.
##   - The `draw` signal of ANOTHER CanvasItem: connecting to a child's `draw` lets this
##     script draw into the child's canvas item, which carries its own material.
##   - CanvasItemMaterial.BLEND_MODE_ADD: colors are added to what's behind (light).
##   - FastNoiseLite: smooth random noise; sampling it at (time, index) gives values
##     that wander smoothly, unlike randf() which jumps every frame.

## The four layers of a flame, outside in. EDGE and BODY are drawn with normal
## blending, INNER and CORE into an additive canvas item.
enum Layer { EDGE, BODY, INNER, CORE }

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
## Smoke wisps given off by the tip per second (0 = none; licks still turn to smoke).
@export var smoke_rate: float = 0.0
## How fast smoke floats up, px/s, and how long a wisp lasts, seconds.
@export var smoke_rise_speed: float = 16.0
@export var smoke_lifetime: float = 0.7

## How hard a lick flutters sideways (px) and how fast (radians per second).
const LICK_FLUTTER_AMPLITUDE: float = 1.5
const LICK_FLUTTER_SPEED: float = 30.0
## Licks alive at most per tongue, so a long burst can't pile them up.
const MAX_LICKS: int = 16
## Shapes smaller than this many square px aren't drawn (see _fill).
const MIN_FILL_AREA: float = 0.25
## The share of a lick's life it burns as flame; the rest of the time it's smoke.
const LICK_FLAME_SHARE: float = 0.55
## Smoke: a warm mid gray, half see-through at most. Lighter than the §9.1 smoke
## color, which vanished against the dark sky of the test rooms.
const SMOKE_COLOR: Color = Color(0.58, 0.53, 0.55)
const SMOKE_MAX_ALPHA: float = 0.55
## A wisp's size at birth and at the end of its life, px.
const SMOKE_START_SIZE: float = 1.5
const SMOKE_END_SIZE: float = 3.5
## Wisps alive at most per tongue.
const MAX_SMOKE: int = 24

## The FlameMerge drawing this tongue's main layers, or null (it draws them itself).
var merge: FlameMerge
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
## Smoke wisps. Each: {position (world), velocity (world), age, lifetime, phase}.
var smoke: Array[Dictionary] = []
var smoke_spawn_debt: float = 0.0
## True if last frame drew anything of our own (see _process).
var had_own_drawing: bool = true


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


func _exit_tree() -> void:
	if merge != null and is_instance_valid(merge):
		merge.remove_tongue(self)


func _process(delta: float) -> void:
	noise_time += delta * flicker_speed
	_update_licks(delta)
	_update_smoke(delta)
	# Inside a FlameMerge our own canvas items only show licks and smoke. With none
	# of those (most tongues, most frames) there's nothing to redraw, apart from one
	# last empty redraw to clear the final frame of the last one. Saves ~100
	# pointless redraws a frame on a burning thicket wall.
	var has_own_drawing: bool = merge == null or not licks.is_empty() or not smoke.is_empty()
	if has_own_drawing or had_own_drawing:
		queue_redraw()
		core_layer.queue_redraw()
	had_own_drawing = has_own_drawing


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
	# A lick past its flame part becomes smoke right where it is.
	for lick: Dictionary in licks:
		if lick["age"] >= lick["lifetime"] * LICK_FLAME_SHARE:
			_add_smoke(lick["position"], lick["velocity"])
	licks = licks.filter(func(lick: Dictionary) -> bool: return lick["age"] < lick["lifetime"] * LICK_FLAME_SHARE)


## Gives off tip smoke (smoke_rate) and floats every wisp up: whatever its first
## push, smoke turns upward (hot air rises) and sways a little side to side.
func _update_smoke(delta: float) -> void:
	if is_visible_in_tree() and smoke_rate > 0.0 and length >= 2.0 and opacity > 0.0:
		smoke_spawn_debt += smoke_rate * delta
		while smoke_spawn_debt >= 1.0:
			smoke_spawn_debt -= 1.0
			_add_smoke(to_global(Vector2(0.0, -length)), Vector2.ZERO)
	else:
		smoke_spawn_debt = 0.0
	for wisp: Dictionary in smoke:
		wisp["age"] += delta
		var velocity: Vector2 = wisp["velocity"]
		var sway: float = sin(wisp["age"] * 5.0 + wisp["phase"]) * 6.0
		velocity = velocity.move_toward(Vector2(sway, -smoke_rise_speed), 60.0 * delta)
		wisp["velocity"] = velocity
		wisp["position"] += velocity * delta
	smoke = smoke.filter(func(wisp: Dictionary) -> bool: return wisp["age"] < wisp["lifetime"])


func _add_smoke(world_position: Vector2, start_velocity: Vector2) -> void:
	if smoke.size() >= MAX_SMOKE:
		return
	smoke.append({
		"position": world_position,
		"velocity": start_velocity * 0.5,
		"age": 0.0,
		"lifetime": smoke_lifetime * randf_range(0.7, 1.2),
		"phase": randf() * TAU,
	})


## Smoke is drawn first (behind the flame), as small soft squares that grow and fade.
func _draw_smoke() -> void:
	if absf(global_scale.x) < 0.05 or absf(global_scale.y) < 0.05:
		return
	for wisp: Dictionary in smoke:
		var progress: float = wisp["age"] / wisp["lifetime"]
		var size: float = lerpf(SMOKE_START_SIZE, SMOKE_END_SIZE, progress) / absf(global_scale.x)
		# Fade in fast, out slowly.
		var alpha: float = SMOKE_MAX_ALPHA * minf(progress * 6.0, 1.0) * (1.0 - progress)
		var center: Vector2 = to_local(wisp["position"])
		draw_rect(Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), Color(SMOKE_COLOR, alpha * opacity))


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
	var life_left: float = 1.0 - lick["age"] / (lick["lifetime"] * LICK_FLAME_SHARE)
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
	# Licks are placed through to_local(), which breaks down when this node is
	# scaled (almost) to nothing.
	if absf(global_scale.x) < 0.05 or absf(global_scale.y) < 0.05:
		return
	for lick: Dictionary in licks:
		var life_left: float = 1.0 - lick["age"] / (lick["lifetime"] * LICK_FLAME_SHARE)
		if lick["size"] * life_left < 0.6:
			continue
		if inner:
			if life_left > 0.5:
				_fill(on_item, _make_lick_polygon(lick, 0.5), Color(INNER_COLOR, opacity * life_left))
		else:
			# Orange when torn off, cooling to a dark red as it turns to smoke.
			var color: Color = BODY_COLOR.lerp(EDGE_COLOR.darkened(0.3), 1.0 - life_left)
			_fill(on_item, _make_lick_polygon(lick, 1.0), Color(color, opacity))


func _draw() -> void:
	_draw_smoke()
	_draw_licks(self, false)
	if merge != null or not has_flame():
		return  # a FlameMerge draws the main layers (see the header)
	# Outer layers: normal blending, drawn into this node.
	draw_layer(self, Layer.EDGE)
	draw_layer(self, Layer.BODY)


## The hot layers, drawn into the additive child.
func _draw_core() -> void:
	_draw_licks(core_layer, true)
	if merge != null or not has_flame():
		return
	draw_layer(core_layer, Layer.INNER)
	draw_layer(core_layer, Layer.CORE)


## True if there's a flame to draw (long enough and not faded out).
func has_flame() -> bool:
	return length >= 0.5 and opacity > 0.0


## Draws one layer of the flame onto `on_item`, in this tongue's local coordinates.
## EDGE and BODY belong on a normal canvas item, INNER and CORE on an additive one.
## (A FlameMerge doesn't use this: it collects get_layer_shape() of all its tongues
## and draws them in one go.)
func draw_layer(on_item: CanvasItem, layer: int) -> void:
	var shape: Array = get_layer_shape(layer)
	if not shape.is_empty():
		_fill(on_item, shape[0], shape[1])


## One layer's outline (tongue-local points) and color: [PackedVector2Array, Color].
## Inside a FlameMerge the base is wider and a little lower (merge.base_widen and
## base_drop), so neighbouring tongues' feet run together.
func get_layer_shape(layer: int) -> Array:
	var base_widen: float = 1.0
	var base_drop: float = 0.0
	if merge != null:
		base_widen = merge.base_widen
		base_drop = merge.base_drop
	match layer:
		Layer.EDGE:
			return [_make_polygon(1.0, 1.0, 0.0, base_widen, base_drop), Color(EDGE_COLOR, opacity)]
		Layer.BODY:
			return [_make_polygon(0.78, 0.85, 7.0, base_widen, base_drop), Color(BODY_COLOR, opacity)]
		Layer.INNER:
			var inner_scale: float = lerpf(0.45, 0.6, heat)
			return [_make_polygon(inner_scale, inner_scale + 0.1, 13.0, base_widen, base_drop),
				Color(INNER_COLOR, 0.8 * opacity)]
		Layer.CORE:
			var core_scale: float = lerpf(0.2, 0.42, heat)
			var core_color: Color = INNER_COLOR.lerp(CORE_COLOR, heat)
			return [_make_polygon(core_scale, core_scale + 0.05, 19.0, base_widen, base_drop),
				Color(core_color, opacity)]
	return []


## The flame outline for one layer. `width_scale`/`length_scale` shrink the layer,
## `noise_offset` gives each layer its own wander (and inner layers move faster).
## `base_widen` / `base_drop`: the base drawn wider and lower (inside a FlameMerge).
## Points go base-left, up the left side, tip, down the right side, base-right.
func _make_polygon(width_scale: float, length_scale: float, noise_offset: float,
		base_widen: float = 1.0, base_drop: float = 0.0) -> PackedVector2Array:
	# Inner layers flicker faster: their noise time runs ahead.
	var t: float = noise_time * (1.0 + noise_offset * 0.05)
	var breath: float = 1.0 + breath_amount * noise.get_noise_2d(t * 0.6, 50.0 + noise_offset)
	var flame_length: float = length * length_scale * breath
	var half_base: float = base_width * width_scale * 0.5 * base_widen
	var half_fan: float = fan_width * width_scale * 0.5
	var wobble: float = fan_width * width_scale * wobble_amount
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-half_base, base_drop))
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
	points.append(Vector2(half_base, base_drop))
	return points


## Smooth noise in -1..1 for one vertex (`row` keeps vertices independent).
func _wander(t: float, row: float) -> float:
	return noise.get_noise_2d(t * 4.0, row * 13.0)


## Fills `points` on `on_item` (see prepare_fill), drawn with the transform the
## caller set, like any draw_* call.
func _fill(on_item: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var fill: Array = prepare_fill(points)
	if fill.is_empty():
		return
	# The triangles from prepare_fill, drawn directly (a triangle list on the
	# RenderingServer, the drawing backend under every draw_* call): no second cut
	# into triangles as draw_colored_polygon() would do. One color for every vertex.
	RenderingServer.canvas_item_add_triangle_array(on_item.get_canvas_item(), fill[1], fill[0],
		PackedColorArray([color]))


## An outline ready to fill: [points, triangle indices], or [] if there's nothing to
## fill. The noise can fold a forked tip over itself, and a self-crossing outline
## can't be cut into triangles; then the convex hull (the outline with its dents
## filled in) is used instead, for that one frame. Shapes smaller than
## MIN_FILL_AREA (a lick that has nearly burnt out) are skipped: the renderer
## rejects near-zero-area polygons.
static func prepare_fill(points: PackedVector2Array) -> Array:
	# not is_finite(): a node scaled to 0 (a fireball guttering out) turns world
	# positions into infinite local ones.
	var area: float = absf(_get_signed_area(points))
	if not is_finite(area) or area < MIN_FILL_AREA:
		return []
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	if triangles.is_empty():
		points = Geometry2D.convex_hull(points)
		if points.size() < 4:  # convex_hull repeats the first point at the end
			return []
		points.remove_at(points.size() - 1)
		triangles = Geometry2D.triangulate_polygon(points)
		if triangles.is_empty():
			return []
	return [points, triangles]


## The polygon's area (shoelace formula; the sign says which way it winds).
static func _get_signed_area(points: PackedVector2Array) -> float:
	var doubled_area: float = 0.0
	for index: int in points.size():
		var next: Vector2 = points[(index + 1) % points.size()]
		doubled_area += points[index].cross(next)
	return doubled_area / 2.0
