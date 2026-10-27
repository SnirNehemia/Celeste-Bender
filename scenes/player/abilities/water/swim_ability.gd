class_name SwimAbility
extends Node
## Swim component (Water_bending.md §5.4). Lives as a child of the Player:
##   Player > SwimAbility
##
## Responsibilities (and only these): knowing HOW MUCH OF THE PLAYER IS UNDER WATER
## and turning that into the numbers the movement uses. Swimming isn't a bending move:
## it works in any room with water, whether Water bending is allowed there or not.
##
##   - submerged_share: 0..1, the part of the hitbox that is in water, read once per
##     physics frame from the room's WaterWorld (the same number floating crates use).
##   - get_speed_multiplier() / get_jump_multiplier(): the water's resistance. The
##     deeper you are, the slower you run and the lower you jump from the bottom.
##   - is_swimming(): your head is under (share >= swim_share). Then jump is a STROKE
##     (Player.try_swim_move()), gravity is weak and you sink slowly.
##
## Like the other abilities, it owns no movement: Player.apply_gravity(),
## apply_horizontal_movement(), start_ground_jump() and try_swim_move() read it, and
## the states (Idle, Run, Jump, Fall) call those. The water itself is pushed by the
## player in WaterWorld._stir_with_player() (wake and splash).
##
## All values are in WaterTuning ("Swimming" group, the F5 panel's Water tab).

var player: Player
## 0..1: how much of the player's hitbox is under water this frame.
var submerged_share: float = 0.0


func _ready() -> void:
	player = get_parent() as Player


## Reads the water around the player. Player._update_timers() calls it first thing
## every physics frame, so every state sees this frame's value.
func update_submersion() -> void:
	var hitbox: Rect2 = player.get_hitbox_rect()
	var water_world: WaterWorld = WaterWorld.find_at(get_tree(), hitbox.get_center())
	submerged_share = 0.0 if water_world == null else water_world.get_submerged_share(hitbox)
	# A puddle or a splash's thin film doesn't count: less than wade_min_depth px in.
	if submerged_share * hitbox.size.y < player.water_tuning.wade_min_depth:
		submerged_share = 0.0


func is_in_water() -> bool:
	return submerged_share > 0.0


## Head under: jump strokes instead of jumping.
func is_swimming() -> bool:
	return submerged_share >= player.water_tuning.swim_share


## Run speed multiplier: 1 on dry land, 1 - water_resistance when fully under.
func get_speed_multiplier() -> float:
	return 1.0 - player.water_tuning.water_resistance * submerged_share


## Jump multiplier for a jump off the bottom: 1 on dry land, lower the deeper you stand.
func get_jump_multiplier() -> float:
	return 1.0 - player.water_tuning.water_jump_loss * submerged_share
