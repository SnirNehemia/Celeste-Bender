class_name EarthMoveAbility
extends Node
## Base class for the three Earth moves (column, boulder, snake). Each move is a
## component node under the player, like the Air abilities:
##   Player > EarthColumnAbility   (Stage E3)
##   Player > EarthSnakeAbility    (Stage E5, later)
##
## (The rock, key S, is NOT a bend move since Stage E4a: it tears out right next to
## the player, with no shadow. See BoulderAbility.)
## The moves share the bend (EarthBendAbility: slow motion, shadow, target). A move
## only says WHICH KEY starts it (get_bend_action) and WHAT HAPPENS at the target
## when the bend is released (erupt). Player._ready() registers every move with
## EarthBendAbility.register_move(), which is how the bend knows the move's key
## and whom to hand the target to.
##
## Subclasses override the two methods below. (GDScript has no abstract methods in
## 4.4, so these defaults just do nothing.)

## The player this belongs to (the parent node), set in _ready().
var player: Player


func _ready() -> void:
	player = get_parent() as Player


## The InputMap action that starts this move's bend, e.g. &"earth_column".
func get_bend_action() -> StringName:
	return &""


## The bend was released over fresh earth: make the move happen at `face`.
func erupt(_face: EarthFace) -> void:
	pass
