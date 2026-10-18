@tool
class_name Door
extends StaticBody2D
## Door (GAME_DESIGN.md §6): a solid slab that opens and closes according to the
## switches linked to it.
##
## Place the node at the door's TOP-LEFT corner and set `door_size`. When opening,
## the slab retracts toward one side (`retract_toward`, default UP, like a shutter
## rolling into the ceiling) and its collision shrinks with it.
##
## Wiring (all in the Inspector, no code):
##   - switches:      the Switch nodes (pressure plates, windmills...) that control it.
##                    Saved in the .tscn as NodePaths, but the Inspector only lets
##                    you pick nodes that really are Switches.
##   - link_mode:     ANY = open while at least one switch is on; ALL = only when all are.
##   - open_when_off: flips it: open while the switches are OFF (a door that a plate closes).
## In the editor, dashed lines are drawn from the door to each linked switch.
##
## Communication is by SIGNAL: in _ready() the door connects to each switch's
## `switched` signal. Switches don't know doors exist.
##
## Fairness: a closing door pauses while the player or a crate is in the doorway,
## instead of crushing them or pushing them into a wall.
##
## Physics: a StaticBody2D on layer 1 ("world"), so the player and crates collide
## with it like any wall. A StaticBody2D isn't meant to MOVE (that's AnimatableBody2D),
## but it's fine to resize its shape, which is all a door does.

enum LinkMode { ANY, ALL }
enum RetractToward { UP, DOWN, LEFT, RIGHT }

## Not in the §2 color key: blue-gray, so doors read as "solid, but not ground".
const DOOR_COLOR: Color = Color(0.35, 0.45, 0.6)
const EDGE_COLOR: Color = Color(0.6, 0.72, 0.9)
## Faint outline of the closed door while it's open, so you can see where it will close.
const FRAME_COLOR: Color = Color(0.6, 0.72, 0.9, 0.25)
## Editor-only dashed lines to the linked switches.
const LINK_LINE_COLOR: Color = Color(0.6, 0.72, 0.9, 0.6)

## The switches this door follows. Pick them with the node picker in the Inspector.
@export var switches: Array[Switch] = []:
	set(value):
		switches = value
		queue_redraw()
@export var link_mode: LinkMode = LinkMode.ANY
## Invert: open while the switches are off.
@export var open_when_off: bool = false
## Size of the closed door, px. 8x32 = one tile wide, four tall.
@export var door_size: Vector2 = Vector2(8, 32):
	set(value):
		door_size = value
		_apply_open_amount()
## Which side the door slides into when it opens.
@export var retract_toward: RetractToward = RetractToward.UP:
	set(value):
		retract_toward = value
		_apply_open_amount()
## Seconds to fully open / fully close. Opening is quick (the reward should feel
## immediate); closing is a bit slower so you can see it coming.
@export var open_time: float = 0.15
@export var close_time: float = 0.3

## 0 = fully closed, 1 = fully open.
var open_amount: float = 0.0
## What the switches currently ask for. Updated by the `switched` signal.
var wants_open: bool = false
## While > 0, open_amount jumps straight to its target instead of animating.
## See reset() for why this is a few frames and not just one.
var snap_frames_remaining: int = 0

var collision_shape_node: CollisionShape2D


func _ready() -> void:
	collision_layer = 1  # bit value of layer 1, "world"
	collision_mask = 0   # a static body never needs to detect anything
	collision_shape_node = CollisionShape2D.new()
	collision_shape_node.shape = RectangleShape2D.new()
	add_child(collision_shape_node)
	if Engine.is_editor_hint():
		_apply_open_amount()
		return
	add_to_group(Room.RESETTABLE_GROUP)
	for linked_switch: Switch in switches:
		if linked_switch == null:
			push_warning("[Door] %s has an empty slot in `switches`" % name)
			continue
		# The signal passes the switch's new state, but a door with several switches
		# needs to look at ALL of them, so we ignore the argument and recompute.
		linked_switch.switched.connect(_on_switch_changed)
	wants_open = _compute_wants_open()
	open_amount = 1.0 if wants_open else 0.0  # start in the right state, no animation
	_apply_open_amount()


func _process(_delta: float) -> void:
	# Editor only: keep the link lines following the switches as you drag them around.
	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target_amount: float = 1.0 if wants_open else 0.0
	if open_amount == target_amount:
		return
	if snap_frames_remaining > 0:
		snap_frames_remaining -= 1
		open_amount = target_amount
	elif target_amount > open_amount:
		open_amount = move_toward(open_amount, 1.0, delta / maxf(open_time, 0.001))
	else:
		if _is_doorway_blocked():
			return  # wait until the doorway is clear
		open_amount = move_toward(open_amount, 0.0, delta / maxf(close_time, 0.001))
	_apply_open_amount()


## Called by Room.reset_objects() when the player dies or restarts the room.
## The switches reset at the same moment, but a pressure plate only notices its
## crate is gone on its NEXT physics frame (that's when Area2D overlaps refresh),
## and the order the nodes run in is not guaranteed. So for the next few frames we
## snap to whatever the switches say instead of playing the open/close animation.
func reset() -> void:
	snap_frames_remaining = 3
	wants_open = _compute_wants_open()


func _on_switch_changed(_is_now_on: bool) -> void:
	wants_open = _compute_wants_open()


## ANY / ALL over the linked switches, then flipped if open_when_off.
func _compute_wants_open() -> bool:
	var on_count: int = 0
	var linked_count: int = 0
	for linked_switch: Switch in switches:
		if linked_switch == null:
			continue
		linked_count += 1
		if linked_switch.is_on():
			on_count += 1
	var switches_satisfied: bool
	if link_mode == LinkMode.ALL:
		switches_satisfied = linked_count > 0 and on_count == linked_count
	else:
		switches_satisfied = on_count > 0
	return switches_satisfied != open_when_off  # != on two bools is XOR: flips when inverted


## True if the player or a crate overlaps the CLOSED door's rectangle.
## This asks the physics world directly (a "shape query") instead of keeping an
## Area2D around, because we only need the answer while closing.
func _is_doorway_blocked() -> bool:
	var doorway: RectangleShape2D = RectangleShape2D.new()
	# 1 px smaller on each side so walls and floors merely TOUCHING the door don't count.
	doorway.size = door_size - Vector2(2.0, 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = doorway
	query.transform = Transform2D(0.0, global_position + door_size / 2.0)
	query.collision_mask = 1 | 2  # "world" (crates) and "player"
	query.exclude = [get_rid()]
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 8):
		# Room solids are StaticBody2Ds and never block; the player and crates are
		# CharacterBody2Ds.
		if result["collider"] is CharacterBody2D:
			return true
	return false


## The part of the door that is still closed, in local px, for the current open_amount.
func _get_closed_rect() -> Rect2:
	var closed_fraction: float = 1.0 - open_amount
	match retract_toward:
		RetractToward.UP:
			return Rect2(0.0, 0.0, door_size.x, door_size.y * closed_fraction)
		RetractToward.DOWN:
			return Rect2(0.0, door_size.y * open_amount, door_size.x, door_size.y * closed_fraction)
		RetractToward.LEFT:
			return Rect2(0.0, 0.0, door_size.x * closed_fraction, door_size.y)
		_:
			return Rect2(door_size.x * open_amount, 0.0, door_size.x * closed_fraction, door_size.y)


## Resizes the collision shape to the closed part, and redraws.
func _apply_open_amount() -> void:
	queue_redraw()
	if collision_shape_node == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	var closed_rect: Rect2 = _get_closed_rect()
	# A fully open door has no collision at all. set_deferred because changing
	# `disabled` in the middle of a physics step isn't allowed.
	var fully_open: bool = closed_rect.size.x < 0.5 or closed_rect.size.y < 0.5
	collision_shape_node.set_deferred("disabled", fully_open)
	if not fully_open:
		(collision_shape_node.shape as RectangleShape2D).size = closed_rect.size
		collision_shape_node.position = closed_rect.get_center()


func _draw() -> void:
	var closed_rect: Rect2 = _get_closed_rect()
	if open_amount > 0.0:
		draw_rect(Rect2(Vector2.ZERO, door_size).grow(-0.5), FRAME_COLOR, false, 1.0)
	if closed_rect.size.x >= 0.5 and closed_rect.size.y >= 0.5:
		draw_rect(closed_rect, DOOR_COLOR)
		draw_rect(closed_rect.grow(-0.5), EDGE_COLOR, false, 1.0)
	if Engine.is_editor_hint():
		for linked_switch: Switch in switches:
			if linked_switch != null:
				draw_dashed_line(door_size / 2.0, to_local(linked_switch.global_position),
					LINK_LINE_COLOR, 1.0, 3.0)
