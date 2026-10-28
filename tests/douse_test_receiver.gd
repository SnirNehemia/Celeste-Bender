extends Node2D
## A stand-in flammable for the water smoke test (Stage W4): it burns until water
## douses it. Follows the Flammable contract (scenes/objects/fire/flammable.gd):
## the group, ignite / is_burning / snuff, a fire rect, and the Water extra douse().
## Made in code by tests/water_smoke_test.gd and put where the snake will touch it.

## Half the side of its fire rect, px.
const HALF_SIZE: float = 4.0

var burning: bool = true
## How many times water put it out.
var douse_count: int = 0


func _ready() -> void:
	add_to_group(Flammable.GROUP)


func ignite(_source: Node) -> void:
	burning = true


func is_burning() -> bool:
	return burning


## A gust: this stand-in ignores the wind (like a brazier).
func snuff() -> void:
	pass


## Water touched its fire (Flammable.douse_near).
func douse() -> void:
	burning = false
	douse_count += 1


func get_fire_rect() -> Rect2:
	return Rect2(global_position - Vector2(HALF_SIZE, HALF_SIZE), Vector2(HALF_SIZE, HALF_SIZE) * 2.0)
