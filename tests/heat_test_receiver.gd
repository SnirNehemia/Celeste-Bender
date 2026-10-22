extends Node2D
## A stand-in heat receiver for tests/fire_smoke_test.gd (Stage F7). Not part of the
## game. It joins the "heat_receiver" group and adds up the heat it's given, so the
## test can check that hot updrafts reach heat receivers (balloons, heat sails,
## windmills and leaflings join this group in later stages).

## Sum of strength × delta from every apply_heat() call, and the strongest single one.
var total_heat: float = 0.0
var strongest: float = 0.0


func _ready() -> void:
	add_to_group(Heat.RECEIVER_GROUP)


## The heat-receiver contract (scenes/objects/fire/heat.gd).
func apply_heat(strength: float, delta: float) -> void:
	total_heat += strength * delta
	strongest = maxf(strongest, strength)
