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
##   - current_speed_x (Stage W7b): the CURRENT that carries you, px/s: the water's
##     speed around you (WaterWorld.get_water_velocity_around, which looks past your
##     own wake) times current_push, times how much of you is in it. Player adds it to
##     the wind (get_wind_velocity), so a current works exactly like a sideways wind:
##     it shifts the speed you settle at.
##   - fall_push (Stage W7b): a WATERFALL falling through you pushes you down, px/s of
##     extra sink (Player.apply_gravity), easing in and out at waterfall_grip.
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
## The current carrying you sideways, px/s (0 out of water).
var current_speed_x: float = 0.0
## A waterfall pushing you down, px/s of extra sink (0 under none).
var fall_push: float = 0.0


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
	var tuning: WaterTuning = player.water_tuning
	current_speed_x = 0.0
	if submerged_share > 0.0:
		current_speed_x = water_world.get_water_velocity_around(hitbox) * tuning.current_push * submerged_share
	var target_push: float = 0.0 if water_world == null else water_world.get_falling_push(hitbox)
	fall_push = move_toward(fall_push, target_push, tuning.waterfall_max_push * tuning.waterfall_grip * get_physics_process_delta_time())


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
