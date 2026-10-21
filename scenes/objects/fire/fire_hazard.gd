class_name FireHazard
extends Area2D
## FireHazard: a flame that kills the player on touch (Fire_bending.md §8, §10).
## Burning grass, bonfires, burning crates and leaflings (later stages) add one of
## these over their flame and switch `active` on while they burn.
##
## It kills through the same path as spikes (scenes/objects/spikes.gd): an Area2D on
## physics layer 3 ("hazards") looking at layer 2 ("player"), checked every physics
## frame, confirmed with the real rectangles, then player.die(). Unlike spikes there
## is no safe direction: fire burns whichever way you move through it.
##
## The player's OWN fire never kills: the jet plume and thrown fireballs are not
## FireHazards (decided in Stage F0/F4). Brazier flames aren't either, so lighting one
## with the jet is safe.
##
## Use: FireHazard.new(), set hazard_size (the deadly rectangle, centered on this
## node), add it as a child of the burning thing, flip `active`.

const GROUP: StringName = &"fire_hazard"

## The deadly rectangle, px, centered on this node.
@export var hazard_size: Vector2 = Vector2(8, 8):
	set(value):
		hazard_size = value
		_resize()
## Burning right now. Off = harmless (e.g. not lit yet, or burnt out).
@export var active: bool = true

var shape_node: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 4  # bit value of layer 3, "hazards"
	collision_mask = 2   # bit value of layer 2, "player"
	monitorable = false
	shape_node = CollisionShape2D.new()
	shape_node.shape = RectangleShape2D.new()
	add_child(shape_node)
	_resize()


func _resize() -> void:
	if shape_node != null:
		(shape_node.shape as RectangleShape2D).size = hazard_size


## The deadly area in world coordinates.
func get_hazard_rect() -> Rect2:
	return Rect2(global_position - hazard_size / 2.0, hazard_size)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		# The overlap list lags a teleport by a physics step (like spikes): confirm
		# with the rectangles at their current positions.
		if touched_player != null and get_hazard_rect().intersects(touched_player.get_hitbox_rect()):
			touched_player.die()
