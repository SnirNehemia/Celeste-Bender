class_name FreezeAbility
extends Node
## FreezeAbility: the freeze (tap 2; Water_bending.md §16 "Re-planned: grid ice",
## Stage I1). A component under the player like the fireball.
##
## Grid ice freezes ONLY what you hold: while you hold water (the WaterHolding state),
## 2 makes the ICE PLAN real, the ghost the water hands draw (WaterHandsAbility
## .freeze_held: a block of tiles, a snake's tiles, a waterfall's wall or a raft), and
## the hold ends. Holding an EMPTY ball over a wet patch (the frost cursor, Stage
## W8b), 2 coats that patch in ice instead (WaterHandsAbility.coat_held). With
## nothing held, 2 only FIZZLES: a few frost specks at your hands.
## (Gone with the grid ice: freezing your last throw, the snow puff, the ice crystal
## and the ice ball.)
## A cooldown (freeze_cooldown, game time) follows every freeze.
##
## Flow: WaterHolding asks try_freeze_held() every frame; this node's own
## _physics_process makes the fizzle.

## Emitted when water froze: the WaterWorld's id of the new freeze.
signal froze(freeze_id: int)
## Emitted when the frost cursor coated a wet patch in ice (Stage W8b): how many tiles.
signal coated(tile_count: int)

var player: Player
var cooldown_remaining: float = 0.0
## For tests and the overlay: the last freeze's id (-1 = none yet), fizzles so far.
var last_freeze_id: int = -1
var fizzle_count: int = 0
## For tests: icy coats made so far.
var coat_count: int = 0


func _ready() -> void:
	player = get_parent() as Player


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	# 2 with nothing held: a fizzle (holding, WaterHolding handles the press). Not
	# during the cooldown: this node runs after the player's state machine (a child
	# after its parent), so on the frame a held ball froze, the hold is already over.
	if Input.is_action_just_pressed("water_freeze") and not player.water_hands.is_holding() \
			and cooldown_remaining <= 0.0 and player.is_element_allowed(Player.ELEMENT_WATER) \
			and not player.is_dead():
		_fizzle()


## While holding (WaterHolding asks every frame): on the frame 2 is pressed, the plan
## freezes. True = it froze (the hold is over).
func try_freeze_held() -> bool:
	if not Input.is_action_just_pressed("water_freeze") or cooldown_remaining > 0.0:
		return false
	# The frost cursor on a wet patch (Stage W8b): an icy coat, no water used.
	var coated_tiles: int = player.water_hands.coat_held()
	if coated_tiles > 0:
		cooldown_remaining = player.water_tuning.freeze_cooldown
		coat_count += 1
		FX.play_sfx(&"freeze")
		coated.emit(coated_tiles)
		return true
	var freeze_id: int = player.water_hands.freeze_held()
	if freeze_id < 0:
		return false  # nothing to freeze (an empty ball, all blocked): the hold goes on
	cooldown_remaining = player.water_tuning.freeze_cooldown
	last_freeze_id = freeze_id
	FX.play_sfx(&"freeze")
	froze.emit(freeze_id)
	return true


## Nothing in your hands: a few frost specks, no ice.
func _fizzle() -> void:
	fizzle_count += 1
	var world: WaterWorld = WaterWorld.find_at(get_tree(), player.get_center())
	if world != null:
		world.sparkle(world.to_local(player.get_center() + Vector2(player.facing_direction * 6.0, 0.0)), 3)
	FX.play_sfx(&"freeze_fizzle")
