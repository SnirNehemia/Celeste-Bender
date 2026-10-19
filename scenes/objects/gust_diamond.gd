@tool
class_name GustDiamond
extends WindCrystal
## Gust diamond (GAME_DESIGN.md §5.3, §6): a floating BLUE diamond with a white core
## that gives TWO gust charges for the current airtime (normally you get one gust
## per airtime). The next landing takes the bonus away again, used or not.
##
## This script INHERITS from WindCrystal (`extends WindCrystal`), so the bobbing,
## the generous hitbox, the respawn after respawn_time and the instant reset with
## the room all come from wind_crystal.gd. It only changes:
##   - the look (colors in _init(), a taller shape and a white core in _ready())
##   - what touching does (_give_to(): Player.overcharge_from_diamond())
##
## overcharge_from_diamond() returns false on the ground (landing would take the
## bonus straight back) and when you already have two charges, so walking through
## a diamond doesn't waste it: it's grabbed in the air.

const DIAMOND_COLOR: Color = Color(0.35, 0.6, 1.0)
const DIAMOND_RESPAWNING_COLOR: Color = Color(0.35, 0.6, 1.0, 0.25)
## White core: the color of the gust (and of the charge pips), so it reads as "more gust".
const CORE_COLOR: Color = Color(1, 1, 1, 0.9)
## Taller and narrower than the green crystal (5 x 5), so the two differ in shape
## too, not only in color. Half sizes, px.
const HALF_WIDTH: float = 4.0
const HALF_HEIGHT: float = 6.0
const CORE_HALF_WIDTH: float = 1.5
const CORE_HALF_HEIGHT: float = 2.5

## The white core, a child of the base class's `diamond` polygon so it bobs and pops with it.
var core: Polygon2D


## _init() runs when the object is created, BEFORE _ready(), so the base class's
## _ready() already sees our colors.
func _init() -> void:
	ready_color = DIAMOND_COLOR
	respawning_color = DIAMOND_RESPAWNING_COLOR
	pickup_sound = &"gust_diamond"


func _ready() -> void:
	# Overriding _ready() replaces the parent's version: super() runs it explicitly
	# (hitbox, layers, reset group, the `diamond` polygon).
	super()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -HALF_HEIGHT), Vector2(HALF_WIDTH, 0), Vector2(0, HALF_HEIGHT), Vector2(-HALF_WIDTH, 0)])
	core = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, -CORE_HALF_HEIGHT), Vector2(CORE_HALF_WIDTH, 0),
		Vector2(0, CORE_HALF_HEIGHT), Vector2(-CORE_HALF_WIDTH, 0)])
	core.color = CORE_COLOR
	diamond.add_child(core)


func _physics_process(delta: float) -> void:
	super(delta)  # bobbing and the touch check
	# The core hides while the diamond is respawning, leaving only the dim outline.
	core.visible = is_available


## Touching: two gust charges for this airtime (see the header for when it refuses).
func _give_to(touched_player: Player) -> bool:
	return touched_player.overcharge_from_diamond()
