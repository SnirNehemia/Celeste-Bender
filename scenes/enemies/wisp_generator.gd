@tool
class_name WispGenerator
extends Node2D
## Wisp generator: a machine that keeps making Wisps. Every spawn_interval seconds
## (while the player is in its room) a new wisp steps out of its mouth and walks off
## in `direction`. At most max_wisps of its wisps are alive at once; when one is
## defeated (or falls out of the room) the next one replaces it.
##
## Place the node ON the floor, at the bottom-center of the machine (origin at its
## feet, like a wisp or a crate). It isn't solid and can't be hurt: it's a source,
## the wisps are the danger. They walk through it.
##
## The wisps it makes are ordinary Wisp scenes (wisp.tscn) with:
##   - start_direction = direction, patrol_speed and at_edges copied from here
##     (Wisp.EdgeRule: turn at ledges, or walk off them and drop)
##   - is_spawned = true: a room reset or a defeat FREES them (Wisp.reset/defeat),
##     instead of putting them back where they were placed
## They're added to the generator's parent (the room), so the room's reset, gusts,
## fire and orbs treat them like any wisp.
##
## Contracts: Room.RESETTABLE_GROUP + reset(): on a reset the clock starts over
## (first_spawn_delay) and the old wisps free themselves. It finds the room the
## player is in through GameState.current_room, so it needs no NodePath.

## Machine colors: dark enemy purple with a lighter mouth and an arrow.
const BODY_COLOR: Color = Color(0.3, 0.14, 0.42)
const TRIM_COLOR: Color = Color(0.5, 0.24, 0.7)
const MOUTH_COLOR: Color = Color(0.08, 0.03, 0.12)
const GLOW_COLOR: Color = Color(0.82, 0.6, 1.0)
## The wisp scene it makes.
const WISP_SCENE: PackedScene = preload("res://scenes/enemies/wisp.tscn")

## Which way its wisps walk out: -1 = left, 1 = right.
@export_enum("Left:-1", "Right:1") var direction: int = 1:
	set(value):
		# 0 (saved by the old property panel when Left was picked) means Left.
		direction = -1 if value <= 0 else 1
		queue_redraw()
## Seconds between wisps (its rate).
@export var spawn_interval: float = 3.0
## Seconds from entering the room to the first wisp.
@export var first_spawn_delay: float = 0.5
## Most of its wisps alive at once (0 = no limit).
@export var max_wisps: int = 3
## Its wisps' walking speed, px/s (Wisp.patrol_speed).
@export var patrol_speed: float = 30.0
## Its wisps at a ledge: turn around, or walk off and fall (Wisp.EdgeRule).
@export var at_edges: Wisp.EdgeRule = Wisp.EdgeRule.FALL_OFF
## The machine's size, px (the editor's outline).
@export var body_size: Vector2 = Vector2(16, 16):
	set(value):
		body_size = value
		queue_redraw()

## Seconds until the next wisp (counts only while the player is in our room).
var time_until_spawn: float = 0.0
## The wisps we made that still exist (freed ones are dropped when counted).
var spawned_wisps: Array[Wisp] = []
## Seconds since start, for the mouth's pulse.
var animation_time: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	time_until_spawn = first_spawn_delay
	add_to_group(Room.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	animation_time += delta
	queue_redraw()  # the mouth glows up before each wisp
	if not _is_awake():
		# Out of the room: hold off, and come back with at least the first delay.
		time_until_spawn = maxf(time_until_spawn, first_spawn_delay)
		return
	time_until_spawn -= delta
	if time_until_spawn > 0.0:
		return
	time_until_spawn = spawn_interval
	if max_wisps > 0 and _count_alive() >= max_wisps:
		return  # full: try again next interval
	_spawn_wisp()


## Only the room the player is in is awake (like a sentry). No rooms (a test
## scene): always awake.
func _is_awake() -> bool:
	return GameState.current_room == null or GameState.current_room.is_ancestor_of(self)


## How many of our wisps are still alive (freed or defeated ones don't count).
func _count_alive() -> int:
	# filter() returns a plain Array, which can't be put straight into a typed
	# Array[Wisp]; assign() copies it in, checking each element's type. The
	# lambda's argument is untyped on purpose: a freed wisp isn't a Wisp any more.
	spawned_wisps.assign(spawned_wisps.filter(func(wisp: Variant) -> bool: return is_instance_valid(wisp)))
	var alive: int = 0
	for wisp: Wisp in spawned_wisps:
		if wisp.state != Wisp.State.DEFEATED:
			alive += 1
	return alive


## A new wisp at the machine's mouth, already facing `direction`. Its settings are
## set BEFORE add_child, because Wisp._ready() reads them (start_direction,
## start_position).
func _spawn_wisp() -> void:
	var wisp: Wisp = WISP_SCENE.instantiate() as Wisp
	wisp.is_spawned = true
	wisp.start_direction = direction
	wisp.patrol_speed = patrol_speed
	wisp.at_edges = at_edges
	# It comes out of the MOUTH: its body starts flush with the machine's side it
	# walks out of, so it's seen stepping out that way at once. Our parent (the
	# room) holds it; positions are in its coordinates, same as ours.
	var mouth_offset: float = direction * (body_size.x - wisp.body_size.x) / 2.0
	wisp.position = position + Vector2(mouth_offset, 0.0)
	get_parent().add_child(wisp)
	spawned_wisps.append(wisp)
	FX.play_sfx(&"wisp_spawned")


## Called by Room.reset_objects(): the clock starts over. Our wisps free
## themselves in their own reset().
func reset() -> void:
	time_until_spawn = first_spawn_delay
	spawned_wisps.clear()


## The outline relative to the origin (the feet): standing on it.
func get_local_outline() -> Rect2:
	return Rect2(Vector2(-body_size.x / 2.0, -body_size.y), body_size)


func _draw() -> void:
	var box: Rect2 = get_local_outline()
	draw_rect(box, BODY_COLOR)
	# A lighter roof strip and feet, so it reads as a machine, not a wall block.
	draw_rect(Rect2(box.position, Vector2(box.size.x, 3.0)), TRIM_COLOR)
	draw_rect(Rect2(box.position.x, box.end.y - 2.0, box.size.x, 2.0), TRIM_COLOR)
	# The mouth: an opening on the side its wisps walk out of. It glows up over the
	# last half second before a wisp comes.
	var mouth_size: Vector2 = Vector2(4.0, box.size.y * 0.55)
	var mouth_x: float = box.end.x - mouth_size.x if direction > 0 else box.position.x
	var mouth: Rect2 = Rect2(Vector2(mouth_x, box.end.y - 2.0 - mouth_size.y), mouth_size)
	var charge: float = 0.0
	if not Engine.is_editor_hint() and time_until_spawn < 0.5:
		charge = 1.0 - time_until_spawn / 0.5
	draw_rect(mouth, MOUTH_COLOR.lerp(GLOW_COLOR, charge))
	# An arrow on the body pointing the way they walk.
	var center: Vector2 = box.get_center() + Vector2(-direction * 2.0, -1.0)
	var tip: Vector2 = center + Vector2(direction * 3.0, 0.0)
	draw_line(center - Vector2(direction * 2.0, 0.0), tip, GLOW_COLOR, 1.0)
	draw_line(tip, tip + Vector2(-direction * 2.0, -2.0), GLOW_COLOR, 1.0)
	draw_line(tip, tip + Vector2(-direction * 2.0, 2.0), GLOW_COLOR, 1.0)
