class_name SmokePuff
extends CPUParticles2D
## SmokePuff: a one-shot puff of soft gray squares that rise slowly, grow and fade
## (Fire_bending.md §9.1 smoke color). Used for the jet's sputter and snap-off, the
## fireball's fizzle and burst, and a brazier going out.
##
## SmokePuff.spawn(parent, world_position, count) makes one; it frees itself.
## `drift` (Stage F13): a puff carried by wind (a gust snuffing a flame) leaves along
## the drift instead of straight up.
## Fire particle cap (Stage F13, FireFxBudget): a crowded room gets smaller puffs
## (fewer squares), and the budget counts them while they live.

const SMOKE_COLOR: Color = Color("#2E282B")


static func spawn(parent: Node, world_position: Vector2, count: int, drift: Vector2 = Vector2.ZERO) -> SmokePuff:
	var smoke: SmokePuff = SmokePuff.new()
	smoke.amount = FireFxBudget.scale_smoke(maxi(count, 1))
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.lifetime = 0.6
	smoke.local_coords = false
	smoke.direction = Vector2.UP
	smoke.spread = 60.0
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 18.0
	if drift != Vector2.ZERO:
		# Blown: off along the wind, a little up (smoke still rises), and faster.
		smoke.direction = (drift.normalized() * 2.0 + Vector2.UP).normalized()
		smoke.spread = 25.0
		smoke.initial_velocity_min = 20.0
		smoke.initial_velocity_max = 40.0
	smoke.gravity = Vector2(0.0, -10.0)
	smoke.damping_min = 10.0
	smoke.damping_max = 20.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 3.0
	# scale_amount_curve: particles grow over their life (x = age 0..1).
	var growth: Curve = Curve.new()
	growth.add_point(Vector2(0.0, 0.7))
	growth.add_point(Vector2(1.0, 1.4))
	smoke.scale_amount_curve = growth
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(SMOKE_COLOR.lightened(0.25), 0.6))
	fade.set_color(1, Color(SMOKE_COLOR, 0.0))
	smoke.color_ramp = fade
	smoke.z_index = 4
	parent.add_child(smoke)
	smoke.global_position = world_position
	smoke.emitting = true
	FireFxBudget.add_smoke(smoke.amount)
	# `finished` fires when a one-shot emitter's last particle has died.
	smoke.finished.connect(smoke.queue_free)
	smoke.tree_exiting.connect(FireFxBudget.add_smoke.bind(-smoke.amount))
	return smoke
