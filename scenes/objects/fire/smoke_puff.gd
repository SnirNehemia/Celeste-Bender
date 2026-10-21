class_name SmokePuff
extends CPUParticles2D
## SmokePuff: a one-shot puff of soft gray squares that rise slowly, grow and fade
## (Fire_bending.md §9.1 smoke color). Used for the jet's sputter and snap-off, the
## fireball's fizzle and burst, and a brazier going out.
##
## SmokePuff.spawn(parent, world_position, count) makes one; it frees itself.

const SMOKE_COLOR: Color = Color("#2E282B")


static func spawn(parent: Node, world_position: Vector2, count: int) -> SmokePuff:
	var smoke: SmokePuff = SmokePuff.new()
	smoke.amount = maxi(count, 1)
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.lifetime = 0.6
	smoke.local_coords = false
	smoke.direction = Vector2.UP
	smoke.spread = 60.0
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 18.0
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
	# `finished` fires when a one-shot emitter's last particle has died.
	smoke.finished.connect(smoke.queue_free)
	return smoke
