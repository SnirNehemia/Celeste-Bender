@tool
class_name GustDiamond
extends WindCrystal
## Gust diamond (GAME_DESIGN.md §5.3, §6): a floating light blue diamond, bigger than the crystal,
## that gives TWO gust charges for the current airtime (normally you get one gust
## per airtime). The next landing takes the bonus away again, used or not.
##
## This script INHERITS from WindCrystal (`extends WindCrystal`), so the bobbing,
## the generous hitbox, the respawn after respawn_time and the instant reset with
## the room all come from wind_crystal.gd. It only changes:
##   - the look (in _init()): the DOUBLE shape (the double fire diamond's 6 x 7 half
##     size) with more wind streaks, in the crystal's light blue (F7 play-test: one
##     color for both air diamonds, like the two fire diamonds; it was a deeper blue
##     with a white core before)
##   - what touching does (_give_to(): Player.overcharge_from_diamond())
##
## overcharge_from_diamond() returns false on the ground (landing would take the
## bonus straight back) and when you already have two charges, so walking through
## a diamond doesn't waste it: it's grabbed in the air.

## The double shape, half sizes px: bigger than the crystal's (4 x 6), so the two
## differ in shape too, not only in color (FireDiamond.DOUBLE_HALF_SIZE).
const DOUBLE_HALF_SIZE: Vector2 = Vector2(6, 7)


## _init() runs when the object is created, BEFORE _ready(), so the base class's
## _ready() already sees our colors.
func _init() -> void:
	pickup_sound = &"gust_diamond"
	fire_pip_value = 2  # a flame turns it into a double fire diamond (Stage F7)
	air_half_size = DOUBLE_HALF_SIZE
	streak_count = 3  # the colors stay the crystal's (WindCrystal.CRYSTAL_COLOR)


## Touching: two gust charges for this airtime (see the header for when it refuses).
func _give_to(touched_player: Player) -> bool:
	return touched_player.overcharge_from_diamond()
