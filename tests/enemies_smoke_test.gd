extends Node2D
## Headless smoke test for the enemy additions made after the Fire chapter's
## enemies: the sentry's Automatic mode and Tracking Shots, the wisp's At Edges
## rule, the Wisp generator and the Wall spider. Not part of the game.
##
## It builds a tiny world in code (no Room, no level): solid blocks are plain
## StaticBody2D rectangles on layer 1 ("world"), which is all these enemies look at.
## With no Room, GameState.current_room is null, so everything counts as "in the
## player's room" and is awake.
## Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/enemies_smoke_test.tscn

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SENTRY_SCENE: PackedScene = preload("res://scenes/enemies/sentry.tscn")
const WISP_SCENE: PackedScene = preload("res://scenes/enemies/wisp.tscn")
const GENERATOR_SCENE: PackedScene = preload("res://scenes/enemies/wisp_generator.tscn")
const SPIDER_SCENE: PackedScene = preload("res://scenes/enemies/wall_spider.tscn")
const ORB_SCENE: PackedScene = preload("res://scenes/enemies/sentry_orb.tscn")

var failures: int = 0
var player: Player = null


func _ready() -> void:
	GameState.current_room = null
	# The player stands on a floor far left, out of every enemy's way: it's only
	# there as the tracking orbs' target.
	_add_block(Rect2(-600, 0, 100, 16))
	player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(-550, 0)
	add_child(player)
	await _frames(2)
	await _check_spider_circles()
	await _check_spider_knocked_off()
	await _check_wisp_edges()
	await _check_generator()
	await _check_tracking_orbs()
	await _check_automatic_sentry()
	print("ENEMIES SMOKE TEST: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


## A spider on top of a floating 32x24 block goes round all four sides, never
## falling off.
func _check_spider_circles() -> void:
	var block: Rect2 = Rect2(0, 0, 32, 24)
	_add_block(block)
	var spider: WallSpider = SPIDER_SCENE.instantiate() as WallSpider
	spider.position = Vector2(16, -4)  # its 8x8 box resting on the block's top
	add_child(spider)
	var lowest: float = -INF
	var leftmost: float = INF
	var rightmost: float = -INF
	var ever_airborne: bool = false
	# The perimeter is about 2 * (40 + 32) = 144 px; at 28 px/s once round is ~5 s.
	for frame: int in 420:
		await get_tree().physics_frame
		lowest = maxf(lowest, spider.global_position.y)
		leftmost = minf(leftmost, spider.global_position.x)
		rightmost = maxf(rightmost, spider.global_position.x)
		ever_airborne = ever_airborne or spider.state == WallSpider.State.AIRBORNE
	_check(not ever_airborne, "spider: never lets go of the block")
	_check(rightmost >= block.end.x + 3.0, "spider: crawled down the right side (max x %.0f)" % rightmost)
	_check(lowest >= block.end.y + 3.0, "spider: crawled along the underside (max y %.0f)" % lowest)
	_check(leftmost <= block.position.x - 3.0, "spider: crawled up the left side (min x %.0f)" % leftmost)
	spider.queue_free()


## A gust from the side knocks it off a floor; it lands and crawls again. A gust
## into its surface does nothing.
func _check_spider_knocked_off() -> void:
	_add_block(Rect2(100, 0, 200, 16))
	var spider: WallSpider = SPIDER_SCENE.instantiate() as WallSpider
	spider.position = Vector2(140, -4)
	add_child(spider)
	await _frames(2)
	spider.receive_gust(Vector2.DOWN, 200.0)
	_check(spider.state == WallSpider.State.CRAWL, "spider: a gust into its floor does nothing")
	spider.receive_gust(Vector2.RIGHT, 160.0)
	_check(spider.state == WallSpider.State.AIRBORNE, "spider: a sideways gust knocks it off")
	await _wait(1.0)
	_check(spider.state == WallSpider.State.CRAWL and is_equal_approx(spider.surface_normal.y, -1.0),
		"spider: lands on the floor and crawls on")
	spider.queue_free()


## FALL_OFF walks off a ledge onto the floor below; TURN_AROUND stays up.
func _check_wisp_edges() -> void:
	_add_block(Rect2(400, 0, 40, 8))     # the ledge
	_add_block(Rect2(380, 64, 200, 16))  # the floor below it
	var faller: Wisp = WISP_SCENE.instantiate() as Wisp
	faller.at_edges = Wisp.EdgeRule.FALL_OFF
	faller.position = Vector2(430, 0)
	add_child(faller)
	var turner: Wisp = WISP_SCENE.instantiate() as Wisp
	turner.position = Vector2(410, 0)
	turner.start_direction = -1
	add_child(turner)
	await _wait(2.0)
	_check(faller.global_position.y > 50.0 and faller.state == Wisp.State.PATROL,
		"wisp: FALL_OFF walked off the ledge and patrols below (y %.0f)" % faller.global_position.y)
	_check(turner.global_position.y < 1.0, "wisp: TURN_AROUND stays on its ledge")
	faller.queue_free()
	turner.queue_free()


## Spawns wisps every interval up to max_wisps; a reset frees them.
func _check_generator() -> void:
	_add_block(Rect2(700, 0, 300, 16))
	var generator: WispGenerator = GENERATOR_SCENE.instantiate() as WispGenerator
	generator.spawn_interval = 0.2
	generator.first_spawn_delay = 0.1
	generator.max_wisps = 2
	generator.direction = 1
	generator.position = Vector2(720, 0)
	add_child(generator)
	await _wait(1.0)
	var wisps: Array[Wisp] = _find_spawned_wisps()
	_check(wisps.size() == 2, "generator: made exactly max_wisps wisps (%d)" % wisps.size())
	_check(wisps.size() > 0 and wisps[0].global_position.x > 725.0, "generator: its wisps walk out to the right")
	# A defeated wisp is freed; the generator drops it from its list (the typed
	# Array[Wisp] filter that once crashed here) and makes a replacement.
	wisps[0].defeat()
	await _wait(0.5)
	_check(_find_spawned_wisps().size() == 2 and generator._count_alive() == 2,
		"generator: replaces a defeated wisp")
	for wisp: Wisp in _find_spawned_wisps():
		wisp.reset()
	generator.reset()
	await _frames(2)
	_check(_find_spawned_wisps().is_empty(), "generator: a reset frees its wisps")
	generator.queue_free()
	# Facing left: wisps step out of its LEFT side and walk left. A 0 (what the old
	# panel saved for Left) is read as Left too.
	var left_generator: WispGenerator = GENERATOR_SCENE.instantiate() as WispGenerator
	left_generator.first_spawn_delay = 0.1
	left_generator.direction = 0
	left_generator.position = Vector2(900, 0)
	add_child(left_generator)
	_check(left_generator.direction == -1, "generator: a saved 0 reads as Left")
	await _wait(0.15)
	var left_wisps: Array[Wisp] = _find_spawned_wisps()
	_check(left_wisps.size() == 1 and left_wisps[0].global_position.x < 897.0,
		"generator: its wisp comes out of the left side")
	var start_x: float = left_wisps[0].global_position.x if left_wisps.size() == 1 else 0.0
	await _wait(0.5)
	_check(left_wisps.size() == 1 and left_wisps[0].global_position.x < start_x - 10.0,
		"generator: and walks left")
	left_generator.queue_free()
	for wisp: Wisp in _find_spawned_wisps():
		wisp.queue_free()
	await _frames(2)
	# Leaf Wisps on: it makes LeafWisps.
	var leaf_generator: WispGenerator = GENERATOR_SCENE.instantiate() as WispGenerator
	leaf_generator.first_spawn_delay = 0.1
	leaf_generator.leaf_wisps = true
	leaf_generator.position = Vector2(720, 0)
	add_child(leaf_generator)
	await _wait(0.15)
	var leaf_wisps: Array[Wisp] = _find_spawned_wisps()
	_check(leaf_wisps.size() == 1 and leaf_wisps[0] is LeafWisp, "generator: with Leaf Wisps on it makes leaf wisps")
	leaf_generator.queue_free()


func _find_spawned_wisps() -> Array[Wisp]:
	var found: Array[Wisp] = []
	for child: Node in get_children():
		if child is Wisp and (child as Wisp).is_spawned and not child.is_queued_for_deletion():
			found.append(child)
	return found


## Tracking orbs turn toward the player, never beyond their top speed, and a
## heavier one turns slower (momentum).
func _check_tracking_orbs() -> void:
	var start: Vector2 = player.get_center() + Vector2(300, -200)
	var light: SentryOrb = _launch_tracking_orb(start, 1.0)
	var heavy: SentryOrb = _launch_tracking_orb(start + Vector2(0, -40), 4.0)
	var initial_velocity: Vector2 = light.velocity
	await _wait(0.4)
	var to_player: Vector2 = (player.get_center() - light.global_position).normalized()
	_check(light.velocity.normalized().dot(to_player) > initial_velocity.normalized().dot(to_player),
		"tracking orb: turns toward the player")
	_check(light.velocity.length() <= 70.0 + 0.01, "tracking orb: never beyond its top speed")
	var light_turn: float = absf(initial_velocity.angle_to(light.velocity))
	var heavy_turn: float = absf(initial_velocity.angle_to(heavy.velocity))
	_check(heavy_turn < light_turn, "tracking orb: a heavier orb turns slower (%.2f < %.2f rad)" % [heavy_turn, light_turn])
	light.pop()
	heavy.pop()
	# Gust-proof: a gust changes nothing, and the gust's search can't find it.
	var proof: SentryOrb = _launch_tracking_orb(start, 1.0)
	proof.make_gust_proof()
	var before: Vector2 = proof.velocity
	proof.receive_gust_from(Vector2.DOWN, 200.0, Pushable.NO_SOURCE)
	_check(not proof.is_reflected and proof.velocity == before and not proof.is_in_group(Pushable.GROUP),
		"gust-proof orb: a gust does nothing to it")
	proof.pop()
	var plain: SentryOrb = _launch_tracking_orb(start, 1.0)
	plain.receive_gust_from(Vector2.DOWN, 200.0, Pushable.NO_SOURCE)
	_check(plain.is_reflected, "plain orb: a gust still reflects it")
	plain.pop()


func _launch_tracking_orb(start: Vector2, mass: float) -> SentryOrb:
	var orb: SentryOrb = ORB_SCENE.instantiate() as SentryOrb
	add_child(orb)
	orb.launch(start, Vector2.UP * 70.0, null)  # flying away from the player at first
	orb.start_tracking(70.0, mass)
	return orb


## An automatic sentry fires on its clock toward fire_direction with no line of
## sight (sight_range 0).
func _check_automatic_sentry() -> void:
	var sentry: Sentry = SENTRY_SCENE.instantiate() as Sentry
	sentry.automatic = true
	sentry.fire_direction = Vector2.RIGHT
	sentry.sight_range = 0.0
	sentry.first_shot_delay = 0.1
	sentry.fire_interval = 0.3
	sentry.position = Vector2(1200, 0)
	add_child(sentry)
	await _wait(0.5)
	var orbs: Array[SentryOrb] = []
	for child: Node in get_children():
		if child is SentryOrb and (child as SentryOrb).shooter == sentry and not (child as SentryOrb).is_popped:
			orbs.append(child)
	_check(not orbs.is_empty(), "automatic sentry: fires without seeing the player")
	_check(not orbs.is_empty() and orbs[0].velocity.x > 0.0 and is_zero_approx(orbs[0].velocity.y),
		"automatic sentry: fires toward fire_direction")
	sentry.queue_free()


## A solid rectangle on layer 1 ("world").
func _add_block(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = rect.size
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1
