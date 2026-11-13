@tool
class_name SwitchWall
extends CrackedWall
## Switch wall: a wall that breaks open when its linked switches turn on (a step pad,
## a pressure plate, a brazier...). It is a CrackedWall in every other way (same look,
## same hidden chambers opening behind it, back whole on death or R), but rocks do
## nothing to it: only its switches break it. Wired like a Door: `switches` and
## `link_mode` (ANY = one is enough, ALL = every one must be on).
##
## Progress (TriggerLamps, like a Door): in ALL mode with 2+ switches a lamp per switch
## sits in the middle of the wall, lit while that switch is on, and the wall shudders
## each time one more switch turns on.
##
## It reacts to the switches CHANGING (the `switched` signal), so a wall whose switch
## is already on at the start of a room stays whole until something flips.

enum LinkMode { ANY, ALL }

const EARTH_TUNING: EarthTuning = preload("res://resources/earth_tuning.tres")
const LINK_LINE_COLOR: Color = Color(0.6, 0.72, 0.9, 0.6)

## The switches that break it. Pick them in the editor with L, like a door's.
@export var switches: Array[Switch] = []:
	set(value):
		switches = value
		queue_redraw()
@export var link_mode: LinkMode = LinkMode.ANY

## The lamps and the pulse when a switch is done (TriggerLamps).
var trigger_lamps: TriggerLamps = TriggerLamps.new()


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	for linked_switch: Switch in switches:
		if linked_switch != null:
			linked_switch.switched.connect(_on_switch_changed)
	trigger_lamps.quiet()
	_update_trigger_lamps()


func _process(delta: float) -> void:
	# Editor: keep the link lines following the switches as they are dragged.
	# In play: redraw while the lamps flash or the wall shudders.
	if Engine.is_editor_hint() or trigger_lamps.advance(delta):
		queue_redraw()


## Death or R: whole again (CrackedWall), and the lamps show the switches as they are
## now, without a pulse for switches flicking back after the reset.
func reset() -> void:
	super.reset()
	trigger_lamps.quiet()
	_update_trigger_lamps()


func _update_trigger_lamps() -> void:
	trigger_lamps.update(TriggerLamps.progress_of(switches), link_mode == LinkMode.ALL)
	queue_redraw()


func _on_switch_changed(_is_now_on: bool) -> void:
	if is_broken:
		return
	_update_trigger_lamps()
	var on_count: int = 0
	var linked_count: int = 0
	for linked_switch: Switch in switches:
		if linked_switch == null:
			continue
		linked_count += 1
		if linked_switch.is_on():
			on_count += 1
	var satisfied: bool = on_count == linked_count if link_mode == LinkMode.ALL else on_count > 0
	if satisfied and linked_count > 0:
		break_open(Vector2.UP, EARTH_TUNING)


func _draw() -> void:
	if Engine.is_editor_hint():
		trigger_lamps.update(TriggerLamps.progress_of(switches), link_mode == LinkMode.ALL)
	# The whole wall shudders when a switch is done; the lamps sit in its middle.
	draw_set_transform(trigger_lamps.get_shake_offset())
	super._draw()
	var area: Rect2 = Rect2(Vector2.ZERO, get_size_px())
	trigger_lamps.draw(self, area, area)
	draw_set_transform(Vector2.ZERO)
	if Engine.is_editor_hint():
		var middle: Vector2 = get_size_px() / 2.0
		for linked_switch: Switch in switches:
			if linked_switch != null:
				draw_dashed_line(middle, to_local(linked_switch.global_position), LINK_LINE_COLOR, 1.0, 3.0)
