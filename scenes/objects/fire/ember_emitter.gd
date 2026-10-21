class_name EmberEmitter
extends CPUParticles2D
## EmberEmitter: 1-px sparks that fly out, rise, curl sideways and fade
## yellow -> red -> nothing. The second fire building block (Fire_bending.md §9.2):
## the jet plume streams them now; fireballs, braziers and bonfires will later.
##
## Two ways to use it:
##   - as a child that streams (the plume): add it, set `direction`/`spread`, and
##     switch `emitting` on and off
##   - one-shot bursts: EmberEmitter.burst(parent, position, count, ...) makes a
##     temporary emitter that fires once and frees itself (ignition ring, pump flare)
##
## Godot concepts used:
##   - CPUParticles2D: a particle system simulated on the CPU (no shader needed), set
##     up entirely from code here. local_coords = false makes sparks stay where they
##     were emitted in the WORLD, so a moving emitter leaves a trail behind it.
##   - Gradient: color_ramp maps each particle's age (0..1) to a color.
##   - A static func can be called on the class itself (EmberEmitter.burst(...)).

## Ember palette (Fire_bending.md §9.1): yellow-white -> orange -> deep red -> gone.
const SPARK_START_COLOR: Color = Color("#FFD34D")
const SPARK_MIDDLE_COLOR: Color = Color("#FF8A1E")
const SPARK_END_COLOR: Color = Color("#8A2410")


func _init() -> void:
	# Set up in _init (not _ready) so burst() can change values right after new().
	amount = 16
	lifetime = 0.45
	lifetime_randomness = 0.4
	local_coords = false
	emitting = false
	direction = Vector2.UP
	spread = 25.0
	initial_velocity_min = 30.0
	initial_velocity_max = 70.0
	# Embers are light: they slow down fast and drift upward (hot air rises).
	gravity = Vector2(0.0, -40.0)
	damping_min = 60.0
	damping_max = 120.0
	# Tangential acceleration bends each spark's path sideways: the "curl".
	tangential_accel_min = -60.0
	tangential_accel_max = 60.0
	scale_amount_min = 1.0
	scale_amount_max = 1.0
	color_ramp = _make_color_ramp()
	z_index = 5


static func _make_color_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, SPARK_START_COLOR)
	ramp.set_color(1, Color(SPARK_END_COLOR, 0.0))
	ramp.add_point(0.35, SPARK_MIDDLE_COLOR)
	ramp.add_point(0.75, SPARK_END_COLOR)
	return ramp


## A one-shot spray of `count` sparks at `world_position`, flying along `toward`
## within ±`spread_degrees` (180 = a full ring) at `speed` px/s (±40%). Added to
## `parent` (normally the room or world), freed once the sparks are gone.
static func burst(parent: Node, world_position: Vector2, count: int, toward: Vector2,
		spread_degrees: float, speed: float) -> EmberEmitter:
	var emitter: EmberEmitter = EmberEmitter.new()
	emitter.amount = maxi(count, 1)
	emitter.one_shot = true
	emitter.explosiveness = 1.0  # all at once
	emitter.direction = toward if toward != Vector2.ZERO else Vector2.UP
	emitter.spread = spread_degrees
	emitter.initial_velocity_min = speed * 0.6
	emitter.initial_velocity_max = speed * 1.4
	parent.add_child(emitter)
	emitter.global_position = world_position
	emitter.emitting = true
	# `finished` fires when a one-shot emitter's last particle has died.
	emitter.finished.connect(emitter.queue_free)
	return emitter
