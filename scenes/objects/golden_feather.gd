@tool
class_name GoldenFeather
extends TrailingPickup
## Golden feather (Collectibles.md §3): the no-death challenge, one per level at most.
##
## Rules:
##   - It can only be taken while GameState.death_count is 0 (R counts as a death).
##     After a death, or once it broke this run, it shows DIM and can't be taken.
##     So wherever it's placed, carrying it to the Goal means a deathless level.
##   - Taken, it follows the player (TrailingPickup), FIRST in the chain (nearest the
##     pack), and is never "secured".
##   - A death while carrying it BREAKS it: gold flakes burst out, and it sits dim at
##     home for the rest of the run (GameState.is_golden_broken).
##   - Reaching the Goal while carrying it makes the level GOLD: StoryPlayer saves
##     it (StoryProgress.record_golden) and the cards show it.
##
## Place the node where the feather's middle should be (normally in the first room).

const GOLD_COLOR: Color = Color(1.0, 0.84, 0.3)
const GOLD_LIGHT_COLOR: Color = Color(1.0, 0.95, 0.65)
const GOLD_DARK_COLOR: Color = Color(0.62, 0.4, 0.08)
const OUTLINE_COLOR: Color = Color("1a1424")
## Dim (can't be taken / broken): its colors this see-through.
const DIM_ALPHA: float = 0.3
## The vane's outline (px, pointing up, quill at the bottom) and its spine.
const VANE: PackedVector2Array = [Vector2(0, -7), Vector2(2, -5), Vector2(3, -1),
	Vector2(2, 3), Vector2(0, 5), Vector2(-2, 2), Vector2(-2.5, -2), Vector2(-1.5, -5)]
const SPINE_FROM: Vector2 = Vector2(0, -6)
const SPINE_TO: Vector2 = Vector2(0, 7)
## It leans and sways: degrees of lean, sway amplitude (degrees) and speed (cycles/s).
const LEAN_DEGREES: float = 20.0
const SWAY_DEGREES: float = 10.0
const SWAY_SPEED: float = 0.6
## The break: flakes, seconds they fly, how fast (px/s), how many.
const FLAKE_TIME: float = 0.7
const FLAKE_SPEED: float = 50.0
const FLAKE_COUNT: int = 10
const FLAKE_GRAVITY: float = 120.0

## The broken flakes still in the air: each [position (local), velocity].
var flakes: Array = []
## Seconds left of the flakes.
var flake_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if flake_remaining > 0.0:
		flake_remaining = maxf(flake_remaining - delta, 0.0)
		for flake: Array in flakes:
			flake[1].y += FLAKE_GRAVITY * delta
			flake[0] += flake[1] * delta


## Only before any death, and only if it hasn't broken this run.
func _can_take(_player: Player) -> bool:
	return GameState.death_count == 0 and not GameState.is_golden_broken


func _on_taken() -> void:
	GameState.is_carrying_golden = true
	# First in the chain: right behind the pack, before any shards.
	chain.erase(self)
	chain.push_front(self)
	FX.play_sfx(&"golden_touch")
	FX.shake(1.5, 0.12)


## A death breaks it: flakes burst from where it was, then it sits dim at home.
func _on_carrier_died() -> void:
	GameState.is_carrying_golden = false
	GameState.is_golden_broken = true
	var break_point: Vector2 = global_position
	FX.play_sfx(&"golden_break")
	park_home_gone()
	# The flakes are drawn by this node (now back home), from the break point.
	flakes.clear()
	for index: int in FLAKE_COUNT:
		var angle: float = TAU * index / FLAKE_COUNT + randf() * 0.4
		flakes.append([to_local(break_point), Vector2.from_angle(angle) * FLAKE_SPEED * randf_range(0.5, 1.0)])
	flake_remaining = FLAKE_TIME


## Dim while it can't be taken (a death before reaching it, or broken).
func _is_dim() -> bool:
	if Engine.is_editor_hint():
		return false
	return state == State.GONE or (state == State.HOME and not _can_take(null))


func _draw() -> void:
	var alpha: float = DIM_ALPHA if _is_dim() else 1.0
	var sway: float = deg_to_rad(LEAN_DEGREES + sin(idle_time * TAU * SWAY_SPEED) * SWAY_DEGREES)
	var vane: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in VANE:
		vane.append(point.rotated(sway) + bob_offset)
	for nudge: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var shifted: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in vane:
			shifted.append(point + nudge)
		draw_colored_polygon(shifted, Color(OUTLINE_COLOR, alpha))
	draw_colored_polygon(vane, Color(GOLD_COLOR, alpha))
	draw_line(SPINE_FROM.rotated(sway) + bob_offset, SPINE_TO.rotated(sway) + bob_offset,
		Color(GOLD_DARK_COLOR, alpha), 1.0)
	# A shine that runs along the vane now and then (not while dim).
	if alpha == 1.0 and fmod(idle_time, 1.8) < 0.3:
		var shine: Vector2 = Vector2(1.5, lerpf(-5.0, 3.0, fmod(idle_time, 1.8) / 0.3)).rotated(sway)
		draw_rect(Rect2((shine + bob_offset).floor(), Vector2.ONE), GOLD_LIGHT_COLOR)
	if flake_remaining > 0.0:
		var flake_alpha: float = flake_remaining / FLAKE_TIME
		for flake: Array in flakes:
			draw_rect(Rect2((flake[0] as Vector2).floor(), Vector2.ONE), Color(GOLD_COLOR, flake_alpha))
