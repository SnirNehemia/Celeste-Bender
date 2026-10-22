class_name AshFall
extends CPUParticles2D
## AshFall (Stage F6): a one-shot shower of ash flakes and glowing clumps that fall
## and drift down, fading out (Fire_bending.md §9.3 thicket burn: "the whole tile
## crumbles into a shower of flakes that fall and drift"). Used by the FireGrid when
## burning thicket drops clumps, when a thicket cell crumbles and when an overgrown
## cover collapses.
##
## AshFall.spawn(parent, world_position, count, area, glow_share) makes one; it frees
## itself once the last flake is gone.

## Ash colors (Fire_bending.md §9.1) and the ember red/orange of a glowing clump.
const ASH_COLOR: Color = Color("#4A4545")
const ASH_FLECK_COLOR: Color = Color("#7A7470")
const GLOW_COLOR: Color = Color("#FF8A1E")
const EMBER_COLOR: Color = Color("#8A2410")


## `count` flakes spread over a rectangle of `area` px centered on `world_position`.
## `glow_share` (0..1) of the color range is glowing embers; the rest is gray ash.
static func spawn(parent: Node, world_position: Vector2, count: int, area: Vector2,
		glow_share: float) -> AshFall:
	var ash: AshFall = AshFall.new()
	ash.amount = maxi(count, 1)
	ash.one_shot = true
	ash.explosiveness = 0.7  # mostly at once, a few a moment later
	ash.lifetime = 1.1
	ash.lifetime_randomness = 0.4
	ash.local_coords = false
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = area / 2.0
	ash.direction = Vector2.DOWN
	ash.spread = 70.0
	ash.initial_velocity_min = 4.0
	ash.initial_velocity_max = 16.0
	# Light flakes: they fall slowly and their speed is damped, so they drift.
	ash.gravity = Vector2(0.0, 90.0)
	ash.damping_min = 20.0
	ash.damping_max = 50.0
	ash.tangential_accel_min = -20.0
	ash.tangential_accel_max = 20.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 2.0
	# color_initial_ramp: each flake picks one color along this gradient at birth:
	# glowing orange -> ember red for the first glow_share of it, gray ash after.
	var picks: Gradient = Gradient.new()
	picks.set_color(0, GLOW_COLOR)
	picks.set_color(1, ASH_FLECK_COLOR)
	picks.add_point(clampf(glow_share, 0.01, 0.98), EMBER_COLOR)
	picks.add_point(clampf(glow_share + 0.01, 0.02, 0.99), ASH_COLOR)
	ash.color_initial_ramp = picks
	# color_ramp: over each flake's life, only the alpha: whole, then fading out.
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.6, Color.WHITE)
	ash.color_ramp = fade
	ash.z_index = 5
	parent.add_child(ash)
	ash.global_position = world_position
	ash.emitting = true
	ash.finished.connect(ash.queue_free)
	return ash
