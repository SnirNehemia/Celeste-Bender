@tool
class_name LeafWisp
extends Wisp
## Leaf wisp (Fire chapter): a Wisp made of LEAVES. It patrols the same way (walks
## back and forth, turns at walls and ledges, touch kills) and it's the same size,
## but only FIRE beats it:
##   - fire (a fireball, the jet plume, burning grass, a bonfire, a burning monkey)
##     burns it up: the leaves flare, then fall as ash
##   - a GUST only RUFFLES it: its leaves blow back in the gust's direction and
##     spring into place, a few loose ones flutter off. It isn't pushed or stunned,
##     so it never becomes harmless: you can't blow it into spikes like a wisp
##   - rocks, columns, the snake, spikes, crushing, reflected orbs, the whip: nothing.
##     Rocks pass through the leaves, it walks over spikes
## So in a room where it blocks a path, the question is always "where do I get fire
## to it?": a fireball, a grass fuse timed to its patrol, a torch-monkey.
##
## Everything else is the Wisp's (wisp.gd): patrol, gravity, contacts, reset, the
## room edges, the defeated signal for enemy gates. This script changes:
##   - the table (_init sets `immunity` before Wisp._ready would make its own)
##   - receive_gust: a visual ruffle, no hit
##   - the look (_draw): leaves, not a purple block, and how it dies (_burn_up,
##     _spawn_burst)
##
## The look: LEAF_COUNT small leaves (2-3 px, three greens) packed into the body's
## oval, each on a little spring: its offset from home is pulled back every frame
## (`leaf_offsets`, `leaf_velocities`), so a gust that shoves them all one way makes
## the whole clump bend and wobble back. They also rustle a little while it walks.
## Two enemy-purple eye pixels at the front (GAME_DESIGN.md §2: enemies are purple).
## Drawn on the pixel grid: every leaf lands on whole pixels.

## Leaves in the clump, and their colors (thicket and grass greens).
const LEAF_COUNT: int = 9
const LEAF_COLORS: Array[Color] = [Color(0.3, 0.55, 0.22), Color(0.42, 0.68, 0.28), Color(0.22, 0.42, 0.17)]
## Its eyes: glowing enemy purple.
const LEAF_EYE_COLOR: Color = Color(0.78, 0.45, 1.0)
## The leaf spring: how hard a leaf is pulled home (1/s²) and how fast its swing
## dies (1/s). Stiff enough to snap back in about half a second.
const LEAF_SPRING: float = 160.0
const LEAF_DAMPING: float = 7.0
## A gust shoves every leaf about this fast (px/s) in its direction, and blows this
## many loose leaves off.
const GUST_RUFFLE_SPEED: float = 70.0
const GUST_LOOSE_LEAVES: int = 4
## How far a leaf may swing from home, px (a clump never comes apart).
const LEAF_MAX_SWING: float = 3.0
## Ash flakes it falls into when it burns (PebbleField-free: they just fall and fade).
const BURN_ASH_FLAKES: int = 6

## Each leaf's home in the body (drawing coordinates, origin at the feet), its size,
## and its color index. Laid out once (seeded by the leaf index, so every leaf wisp
## looks the same and the editor shows it as it plays).
var leaf_homes: Array[Vector2] = []
var leaf_sizes: Array[Vector2] = []
var leaf_color_indexes: Array[int] = []
## Each leaf's swing away from home (px) and its speed (px/s).
var leaf_offsets: Array[Vector2] = []
var leaf_velocities: Array[Vector2] = []


func _init() -> void:
	# Set before Wisp._ready(), which only makes the plain wisp's table if this is empty.
	immunity = make_leaf_immunity()


func _ready() -> void:
	super()
	_lay_out_leaves()


## The leaf wisp's row of the table: only fire kills; nothing else touches it. (A gust
## never even becomes a hit: receive_gust only ruffles the leaves.)
static func make_leaf_immunity() -> ElementImmunity:
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var ignore: ElementImmunity.Response = ElementImmunity.Response.IGNORE
	return ElementImmunity.from_table({
		EnemyHit.Type.FIREBALL: kill, EnemyHit.Type.FLAME: kill,
		EnemyHit.Type.BIG_ROCK: ignore, EnemyHit.Type.PERFECT_ROCK: ignore, EnemyHit.Type.SMALL_ROCK: ignore,
		EnemyHit.Type.GUST: ignore, EnemyHit.Type.EARTH_PUSH: ignore, EnemyHit.Type.CRUSH: ignore,
		EnemyHit.Type.SPIKES: ignore, EnemyHit.Type.REFLECTED_ORB: ignore, EnemyHit.Type.WHIP: ignore,
	})


## The leaves' homes: spread over the body's oval, bottom row widest. Seeded, so the
## same every time.
func _lay_out_leaves() -> void:
	var leaf_random: RandomNumberGenerator = RandomNumberGenerator.new()
	leaf_random.seed = 7
	leaf_homes.clear()
	leaf_sizes.clear()
	leaf_color_indexes.clear()
	leaf_offsets.clear()
	leaf_velocities.clear()
	var half_width: float = body_size.x / 2.0
	for leaf_index: int in LEAF_COUNT:
		# Rings from the middle out (golden angle), squashed to the body's oval.
		var share: float = sqrt((leaf_index + 0.5) / LEAF_COUNT)
		var angle: float = leaf_index * 2.39996
		var spot: Vector2 = Vector2(cos(angle) * half_width * 0.75, sin(angle) * body_size.y * 0.38) * share
		leaf_homes.append(Vector2(spot.x, -body_size.y / 2.0 + spot.y))
		leaf_sizes.append(Vector2(leaf_random.randi_range(2, 3), 2.0))
		leaf_color_indexes.append(leaf_random.randi_range(0, LEAF_COLORS.size() - 1))
		leaf_offsets.append(Vector2.ZERO)
		leaf_velocities.append(Vector2.ZERO)


## The Pushable contract, as a leaf wisp: a gust only ruffles the leaves (no hit,
## no push, no stun) and blows a few loose leaves off.
func receive_gust(direction: Vector2, _strength: float) -> void:
	if state == State.DEFEATED:
		return
	for leaf_index: int in leaf_velocities.size():
		# Every leaf gets shoved downwind, a little more or less, so the clump ruffles
		# instead of sliding as one block.
		leaf_velocities[leaf_index] += direction * GUST_RUFFLE_SPEED * randf_range(0.6, 1.3) \
			+ direction.orthogonal() * randf_range(-20.0, 20.0)
	_blow_loose_leaves(direction)


## A few leaves torn off by a gust: green specks that flutter away downwind and fall.
## Visual only (the clump keeps all its leaves).
func _blow_loose_leaves(direction: Vector2) -> void:
	var loose: CPUParticles2D = CPUParticles2D.new()
	loose.one_shot = true
	loose.explosiveness = 0.9
	loose.amount = GUST_LOOSE_LEAVES
	loose.lifetime = 0.8
	loose.direction = direction if direction != Vector2.ZERO else Vector2.UP
	loose.spread = 35.0
	loose.gravity = Vector2(0.0, 80.0)  # leaves fall slowly
	loose.initial_velocity_min = 50.0
	loose.initial_velocity_max = 90.0
	loose.damping_min = 40.0
	loose.damping_max = 70.0
	loose.tangential_accel_min = -40.0  # the flutter
	loose.tangential_accel_max = 40.0
	loose.scale_amount_min = 1.0
	loose.scale_amount_max = 2.0
	loose.color = LEAF_COLORS[1]
	loose.local_coords = false
	get_parent().add_child(loose)
	loose.global_position = global_position + Vector2(0.0, -body_size.y / 2.0)
	loose.emitting = true
	loose.finished.connect(loose.queue_free)


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or state == State.DEFEATED:
		return
	_update_leaves(delta)


## Every leaf's spring: pulled home, damped, clamped to LEAF_MAX_SWING. Walking adds
## a soft rustle (a tiny random nudge now and then).
func _update_leaves(delta: float) -> void:
	for leaf_index: int in leaf_offsets.size():
		var offset: Vector2 = leaf_offsets[leaf_index]
		var leaf_velocity: Vector2 = leaf_velocities[leaf_index]
		leaf_velocity += (-offset * LEAF_SPRING - leaf_velocity * LEAF_DAMPING) * delta
		if randf() < 2.0 * delta:
			leaf_velocity += Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		offset = (offset + leaf_velocity * delta).limit_length(LEAF_MAX_SWING)
		leaf_offsets[leaf_index] = offset
		leaf_velocities[leaf_index] = leaf_velocity


## SentryOrb aim assist: a reflected orb can't hurt it, so it's never a target.
func is_valid_orb_target() -> bool:
	return false


## Caught fire: the leaves flare up and fall as ash, with embers and smoke.
func _burn_up() -> void:
	var center: Vector2 = global_position + Vector2(0.0, -body_size.y / 2.0)
	EmberEmitter.burst(get_parent(), center, 12, Vector2.UP, 180.0, 55.0)
	SmokePuff.spawn(get_parent(), center, 4)
	AshFall.spawn(get_parent(), center, BURN_ASH_FLAKES, body_size, 0.6)
	FireRing.spawn(get_parent(), center, body_size.x / 2.0 + 3.0, 0.15)
	defeat()


## Its defeat puff: green and ember bits instead of the wisp's purple squares.
func _spawn_burst() -> void:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 10
	burst.lifetime = 0.5
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 120.0)
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 70.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	var colors: Gradient = Gradient.new()
	colors.set_color(0, Color("#FF8A1E"))
	colors.set_color(1, Color(0.15, 0.12, 0.1, 0.0))  # burnt to nothing
	burst.color_ramp = colors
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector2(0.0, -body_size.y / 2.0)
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.1, false).timeout.connect(burst.queue_free)


## The leaves (each at home + its swing + the walk's 1 px bob, on whole pixels), then
## the two purple eyes at the front.
func _draw() -> void:
	if leaf_homes.is_empty():
		_lay_out_leaves()  # in the editor, _ready() may not have run yet
	var bob: Vector2 = Vector2(0.0, -roundf((sin(animation_time * 5.0) + 1.0) * 0.5))
	for leaf_index: int in leaf_homes.size():
		var leaf_size: Vector2 = leaf_sizes[leaf_index]
		var center: Vector2 = leaf_homes[leaf_index] + leaf_offsets[leaf_index] + bob
		var top_left: Vector2 = (center - leaf_size / 2.0).round()
		var color: Color = LEAF_COLORS[leaf_color_indexes[leaf_index]]
		draw_rect(Rect2(top_left, leaf_size), color)
		# A darker vein pixel on each leaf, so the clump reads as many leaves.
		draw_rect(Rect2(top_left + Vector2(leaf_size.x - 1.0, leaf_size.y - 1.0), Vector2.ONE), color.darkened(0.35))
	var eye_y: float = roundf(-body_size.y + 3.0 + bob.y)
	var front_x: float = roundf(patrol_direction * 2.0)
	draw_rect(Rect2(Vector2(front_x - 2.0, eye_y), Vector2.ONE), LEAF_EYE_COLOR)
	draw_rect(Rect2(Vector2(front_x + 1.0, eye_y), Vector2.ONE), LEAF_EYE_COLOR)
