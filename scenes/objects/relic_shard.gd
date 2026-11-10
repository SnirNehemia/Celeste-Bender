@tool
class_name RelicShard
extends TrailingPickup
## Relic shard (Collectibles.md §2): the "100%" collectible. Every ELEMENT has its
## own relic, broken in four: a shard is quarter `slot` (1..4) of `element`'s relic.
## A level holds one or more relics (normally its chapter's element; mixed levels
## several), each as four shards, slots 1-4 of the same element.
##
## THE STRAWBERRY RULE: a touch makes it FOLLOW the player (TrailingPickup). It is
## SECURED once the player has stood on the ground SECURE_GROUND_TIME without dying:
## then it pops into the pack, GameState.secure_shard() counts it for the run and, in
## a Story Mode run, StoryProgress saves it at once. Dying while it follows sends it
## flying home, to be taken again.
##
## A shard secured earlier this run (its room reloaded) isn't there at all; one saved
## in an earlier Story sitting is a GHOST: see-through, it plays the same but adds
## nothing new.
##
## Place the node where the shard's middle should be: it lives on the tile grid, a
## 2x2-tile square centered on a tile corner (the editor snaps it there).

enum Element { AIR, EARTH, FIRE, WATER }

## Group of every RelicShard in the tree (RelicView counts a level's shards with it).
const GROUP: StringName = &"relic_shards"
## Every relic has this many shards (its quarters).
const SHARDS_PER_RELIC: int = 4

## The shard is one QUARTER of the level's relic (RelicPainter: a round medallion
## broken in four), so it looks like a piece of what it completes. The relic's
## radius, px: the quarter is RELIC_RADIUS square, inside its 2x2-tile outline with
## room for the outline and the bob.
const RELIC_RADIUS: float = 11.0
## It rocks gently as it floats: up to ROCK_DEGREES each way, ROCK_SPEED swings a
## second. (A sideways "spin" squeezed the quarter-disc into a blob.)
const ROCK_DEGREES: float = 8.0
const ROCK_SPEED: float = 0.45
## Seconds on the ground before it counts.
const SECURE_GROUND_TIME: float = 0.25
## The pop when secured: seconds to fly into the pack.
const SECURE_TIME: float = 0.2
## A ghost (saved in an earlier sitting) is this see-through.
const GHOST_ALPHA: float = 0.35

## Which quarter of the relic it is.
@export_range(1, 4) var slot: int = 1:
	set(value):
		slot = value
		queue_redraw()
@export var element: Element = Element.AIR:
	set(value):
		element = value
		queue_redraw()

## Seconds the carrier has been standing on the ground while it follows.
var ground_time: float = 0.0
## Seconds left of the pop into the pack (0 = not popping).
var securing_remaining: float = 0.0
var is_ghost: bool = false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# The pause menu's relic (RelicView) finds the level's shards by this group.
	add_to_group(GROUP)
	if GameState.has_shard(element, slot):
		_set_state(State.GONE)
		visible = false
		return
	is_ghost = GameState.is_story_run and StoryProgress.has_shard(_get_level_path(), element, slot)


func _physics_process(delta: float) -> void:
	super(delta)
	if securing_remaining > 0.0:
		securing_remaining = maxf(securing_remaining - delta, 0.0)
		if is_instance_valid(carrier):
			global_position = global_position.lerp(carrier.body_look.get_pack_global_position(), 0.4)
		if securing_remaining == 0.0:
			if is_instance_valid(carrier):
				carrier.body_look.pop_lid()
			stop_following()
			_set_state(State.GONE)
			visible = false


func _on_taken() -> void:
	ground_time = 0.0
	FX.play_sfx(&"shard_touch")


## Standing on the ground long enough secures it.
func _follow_step(delta: float) -> void:
	if securing_remaining > 0.0:
		return
	if carrier.is_on_floor() and not carrier.is_dead():
		ground_time += delta
	else:
		ground_time = 0.0
	if ground_time >= SECURE_GROUND_TIME:
		_secure()


func _secure() -> void:
	GameState.secure_shard(element, slot)
	if GameState.is_story_run:
		StoryProgress.record_shard(_get_level_path(), element, slot)
	securing_remaining = SECURE_TIME
	FX.play_sfx(&"shard_secured")
	FX.shake(1.0, 0.1)


## While popping into the pack a death can't take it back any more.
func _on_carrier_died() -> void:
	if securing_remaining > 0.0:
		return
	fly_home()


## "Air relic", "Water relic"...
static func get_relic_name(relic_element: int) -> String:
	return "%s relic" % String(Element.keys()[relic_element]).capitalize()


## "Air relic" when all its quarters are found, else "Air 2/4".
static func get_relic_progress_text(relic_element: int, found_count: int) -> String:
	if found_count >= SHARDS_PER_RELIC:
		return get_relic_name(relic_element)
	return "%s %d/%d" % [String(Element.keys()[relic_element]).capitalize(), found_count, SHARDS_PER_RELIC]


## The level's scene path: StoryProgress's key.
func _get_level_path() -> String:
	var world: Node = get_tree().current_scene
	return world.scene_file_path if world != null else ""


func _draw() -> void:
	if state == State.GONE:
		return
	var alpha: float = GHOST_ALPHA if is_ghost else 1.0
	# The rocking tilt; shrink while popping into the pack.
	var tilt: float = deg_to_rad(sin(idle_time * TAU * ROCK_SPEED + slot) * ROCK_DEGREES)
	var scale_factor: float = securing_remaining / SECURE_TIME if securing_remaining > 0.0 else 1.0
	# draw_set_transform: everything drawn after it is moved, turned and scaled by
	# this, so the painter can draw the quarter as if it stood still.
	draw_set_transform(bob_offset, tilt, Vector2.ONE * scale_factor)
	# The relic's middle sits off the origin so the QUARTER is centered on it.
	var relic_center: Vector2 = -RelicPainter.get_quarter_offset(slot, RELIC_RADIUS)
	RelicPainter.draw_quarter(self, slot, element, relic_center, RELIC_RADIUS, alpha)
	draw_set_transform(Vector2.ZERO)
	# A glint that blinks now and then, on the rim.
	if fmod(idle_time + slot * 0.7, 2.2) < 0.15:
		draw_rect(Rect2((bob_offset + Vector2(0.0, -3.0)).floor(), Vector2.ONE), Color(1, 1, 1, alpha))
