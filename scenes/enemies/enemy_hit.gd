class_name EnemyHit
extends RefCounted
## EnemyHit (Stage F11, Fire_bending.md §7, §10): ONE hit on an enemy, and the one
## path every hit takes. Whatever hurts or moves an enemy (a fireball, a flame, a
## thrown rock, a gust, spikes, a rising column, the snake, a reflected orb, a dash)
## builds an EnemyHit and hands it to EnemyHit.deliver(). The enemy looks the hit's
## TYPE up in its ElementImmunity table (element_immunity.gd) and reacts: killed,
## staggered, pushed, or nothing.
##
## Before Stage F11 every hit had its own method on every enemy (receive_rock_hit,
## receive_launch, receive_crush, wisp.defeat() from the orb...). Now the hitters
## only know this file, and each enemy only answers one method, so a new enemy (the
## vine monkey, later the elephant and the Shell) is one table plus its reactions.
##
## THE ENEMY CONTRACT (duck typing, like Pushable and Flammable):
##   1. join the group "enemies" (EnemyHit.GROUP)
##   2. have   func receive_hit(hit: EnemyHit) -> ElementImmunity.Response
##      look hit.type up in the enemy's table, react, and return the response
##      (IGNORE when it's already defeated)
## Enemies that a gust or a column can reach are ALSO Pushable (group "pushable" +
## receive_gust): Pushable.try_push/try_launch/try_crush notice an enemy and turn the
## push into an EnemyHit here, so the gust, the column and the snake didn't change.
##
## Godot concept, RefCounted: a plain object (not a Node) that frees itself when no
## variable holds it any more, like a Python object. A hit lives for one call.

## What hit the enemy. The keys of every ElementImmunity table.
enum Type {
	FIREBALL,       ## a thrown fireball, hitting it head-on
	FLAME,          ## any other fire: the jet plume, a fireball's splash, burning grass
	                ## and thicket, bonfires, burning crates, a burning monkey
	BIG_ROCK,       ## a thrown big (16×16) rock
	PERFECT_ROCK,   ## a small rock thrown in the perfect window
	SMALL_ROCK,     ## a small rock thrown sloppily
	GUST,           ## the gust or the dash wake
	SPIKES,         ## touching spikes
	EARTH_PUSH,     ## a rising Earth Column's tip or the Earth Snake's head
	CRUSH,          ## squeezed between a rising column and a solid
	REFLECTED_ORB,  ## a sentry orb the gust sent back
	DASH,           ## the player dashing into it (a stunned wisp)
	WHIP,           ## the thicket elephant's tail whip (Stage F11b)
}

## Group every enemy joins (see the contract above).
const GROUP: StringName = &"enemies"
## Enemies that BREAK Earth creations touching them (Stage F11b, the thicket
## elephant): a rising column or the snake's head shatters on them instead of
## pushing them. EarthColumn and EarthSnake check this group.
const BREAKS_EARTH_GROUP: StringName = &"breaks_earth"
## "Where it hit: unknown".
const NO_POSITION: Vector2 = Vector2.INF
const METHOD: StringName = &"receive_hit"

var type: Type = Type.FLAME
## The push the hit gives, px/s (a rock's knockback, a gust's direction × strength,
## a column's launch). ZERO for hits that don't push (spikes, flames).
var push_velocity: Vector2 = Vector2.ZERO
## For a killing hit: seconds before the kill lands (a rock-hit wisp flies, harmless,
## then pops). 0 = at once.
var kill_delay: float = 0.0
## What dealt it (a Fireball, a Boulder, the Player...), or null. Enemies may look at
## it (a dash kill refills the dasher's dash).
var source: Node = null
## Where it landed, world coordinates, or NO_POSITION. Enemies that burn in parts
## (the elephant's spots) or from one side (the monkey's creeping flame) use it.
var world_position: Vector2 = NO_POSITION


static func make(hit_type: Type, push: Vector2 = Vector2.ZERO, hit_source: Node = null,
		delay: float = 0.0, at: Vector2 = NO_POSITION) -> EnemyHit:
	var hit: EnemyHit = EnemyHit.new()
	hit.type = hit_type
	hit.push_velocity = push
	hit.source = hit_source
	hit.kill_delay = delay
	hit.world_position = at
	return hit


## Where the hit came from: its world_position, else its source's position (a
## Node2D), else NO_POSITION.
func get_origin() -> Vector2:
	if world_position != NO_POSITION:
		return world_position
	var source_2d: Node2D = source as Node2D
	if source_2d != null and is_instance_valid(source_2d):
		return source_2d.global_position
	return NO_POSITION


## The enemy for something a hitter touched, or null. Checks the node, then its
## parent (an enemy's sensor is often a child Area2D).
static func find_enemy(touched: Object) -> Node:
	var node: Node = touched as Node
	if node == null:
		return null
	for candidate: Node in [node, node.get_parent()]:
		if candidate != null and candidate.is_in_group(GROUP) and candidate.has_method(METHOD):
			return candidate
	return null


static func is_enemy(touched: Object) -> bool:
	return find_enemy(touched) != null


## Hands `hit` to the enemy behind `touched`. Returns its response, or IGNORE if
## `touched` isn't an enemy.
static func deliver(touched: Object, hit: EnemyHit) -> ElementImmunity.Response:
	var enemy: Node = find_enemy(touched)
	if enemy == null:
		return ElementImmunity.Response.IGNORE
	return enemy.call(METHOD, hit) as ElementImmunity.Response


## Builds and delivers a hit in one call.
static func send(touched: Object, hit_type: Type, push: Vector2 = Vector2.ZERO,
		hit_source: Node = null, delay: float = 0.0, at: Vector2 = NO_POSITION) -> ElementImmunity.Response:
	return deliver(touched, make(hit_type, push, hit_source, delay, at))


## True if `body` breaks Earth creations that touch it (see BREAKS_EARTH_GROUP).
static func breaks_earth(body: Object) -> bool:
	var node: Node = body as Node
	return node != null and node.is_in_group(BREAKS_EARTH_GROUP)
