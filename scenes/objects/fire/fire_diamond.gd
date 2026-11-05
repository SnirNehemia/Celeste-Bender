@tool
class_name FireDiamond
extends WindCrystal
## Fire diamond (Fire_bending.md §4.3): a floating ORANGE diamond with a small flame
## licking inside it. Touching it adds fire pips to the player's fire bar:
##   single: +1 pip    double: +2 pips (a bigger diamond with two flames)
## Pips above the cap are lost. It's SINGLE USE: a collected fire diamond stays gone
## until death or R (fire is a budget, like earth tiles), so it never respawns.
##
## Like GustDiamond, this INHERITS from WindCrystal: the bobbing, the generous
## hitbox, the touch check and the reset with the room come from wind_crystal.gd.
## It changes:
##   - the look (colors and `respawns = false` in _init(), shape and flames in _ready())
##   - what touching does (_give_to(): Player.gain_fire_pips())
##   - a used diamond disappears completely instead of showing a dim outline
##
## Stage F13: a small HeatGlow sits behind it (a child of the bobbing diamond), so a
## fire diamond lights its corner of the room and reads as fire from far away.
##
## gain_fire_pips() returns false when the bar is already full (or fire isn't allowed
## in the room), so brushing past with a full bar doesn't waste the diamond.
## Since Stage F7, flames turn wind crystals and gust diamonds into these
## (WindCrystal.ignite: the air diamond hides and spawns one of these in its place).

## Fire palette (Fire_bending.md §9.1): the diamond is the orange body color with a
## red-orange rim; the inner flame is yellow with a pale core.
const DIAMOND_COLOR: Color = Color("#FF8A1E")
const RIM_COLOR: Color = Color("#E8431A")
const FLAME_COLOR: Color = Color("#FFD34D")
const FLAME_CORE_COLOR: Color = Color("#FFF6CC")
## Diamond half sizes, px. The double is wider and taller, so the two read apart by
## shape as well as by their flame count.
const SINGLE_HALF_SIZE: Vector2 = Vector2(4, 6)
const DOUBLE_HALF_SIZE: Vector2 = Vector2(6, 7)
## The rim is this many px bigger than the diamond on every side.
const RIM_WIDTH: float = 1.0
## Inner flame: base half width and height (px); how fast its tip licks (cycles/s).
const FLAME_HALF_WIDTH: float = 1.5
const FLAME_HEIGHT: float = 4.0
const FLAME_LICK_FREQUENCY: float = 3.0
## Its glow: radius px for the single (the double's is a third bigger), and color.
const GLOW_RADIUS: float = 10.0
const GLOW_COLOR: Color = Color(1.0, 0.55, 0.2, 0.2)

## How many pips this diamond gives: 1 = single, 2 = double.
@export_range(1, 2) var pip_amount: int = 1:
	set(value):
		pip_amount = value
		# In the editor, redraw the shape at once when the value changes.
		if is_node_ready():
			_build_look()

## The rim polygon (behind the diamond) and the inner flames (on top of it), all
## children of the base class's `diamond` polygon, so they bob with it.
var rim: Polygon2D
var flames: Array[Polygon2D] = []
var glow: HeatGlow


func _init() -> void:
	ready_color = DIAMOND_COLOR
	respawning_color = Color(DIAMOND_COLOR, 0.0)  # gone, not dimmed (see _use_up)
	pickup_sound = &"fire_diamond"
	respawns = false
	fire_pip_value = 0  # already fire: nothing to convert
	has_air_look = false  # its own rim and flames (_build_look)


func _ready() -> void:
	# super() runs WindCrystal._ready(): hitbox, layers, reset group, `diamond`.
	super()
	_build_look()


func _physics_process(delta: float) -> void:
	super(delta)  # bobbing and the touch check
	_lick_flames()


## (Re)builds the diamond, its rim and its flames for the current pip_amount.
func _build_look() -> void:
	var half_size: Vector2 = DOUBLE_HALF_SIZE if pip_amount >= 2 else SINGLE_HALF_SIZE
	diamond.polygon = _diamond_points(half_size)
	if rim == null:
		rim = Polygon2D.new()
		rim.color = RIM_COLOR
		# show_behind_parent: drawn before the diamond, so it shows only as a border.
		rim.show_behind_parent = true
		diamond.add_child(rim)
	rim.polygon = _diamond_points(half_size + Vector2.ONE * RIM_WIDTH)
	if glow == null and not Engine.is_editor_hint():
		glow = HeatGlow.new()
		glow.name = "Glow"
		glow.color = GLOW_COLOR
		glow.show_behind_parent = true
		diamond.add_child(glow)
	if glow != null:
		glow.radius = GLOW_RADIUS * (1.33 if pip_amount >= 2 else 1.0)
	for flame: Polygon2D in flames:
		flame.queue_free()
	flames.clear()
	# One flame in the middle, or two side by side for the double.
	var flame_offsets: Array[float] = [0.0]
	if pip_amount >= 2:
		flame_offsets = [-2.0, 2.0]
	for offset_x: float in flame_offsets:
		var flame: Polygon2D = Polygon2D.new()
		flame.color = FLAME_COLOR
		flame.position = Vector2(offset_x, 2.0)  # the flame's base, a bit below the middle
		diamond.add_child(flame)
		var flame_core: Polygon2D = Polygon2D.new()
		flame_core.color = FLAME_CORE_COLOR
		flame.add_child(flame_core)
		flames.append(flame)
	_lick_flames()


## Moves each flame's tip from side to side and up and down (each flame at its own
## phase), and its pale core with it: a small flame "licking" inside the diamond.
func _lick_flames() -> void:
	for flame_index: int in flames.size():
		var flame: Polygon2D = flames[flame_index]
		var phase: float = bob_time * TAU * FLAME_LICK_FREQUENCY + flame_index * 2.1
		var tip: Vector2 = Vector2(sin(phase) * 0.8, -FLAME_HEIGHT - 0.8 * sin(phase * 1.7))
		flame.polygon = PackedVector2Array([
			Vector2(-FLAME_HALF_WIDTH, 0), tip, Vector2(FLAME_HALF_WIDTH, 0)])
		var flame_core: Polygon2D = flame.get_child(0) as Polygon2D
		flame_core.polygon = PackedVector2Array([
			Vector2(-0.6, 0), tip * 0.55, Vector2(0.6, 0)])
		flame.visible = is_available
	if glow != null:
		glow.visible = is_available


func _diamond_points(half_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -half_size.y), Vector2(half_size.x, 0),
		Vector2(0, half_size.y), Vector2(-half_size.x, 0)])


## Touching: add the pips (see the header for when it refuses).
func _give_to(touched_player: Player) -> bool:
	return touched_player.gain_fire_pips(pip_amount)


## Used: a pop, then it's gone (no outline) until the room resets.
func _use_up() -> void:
	super()
	rim.visible = false
	FX.flash_screen(Color(DIAMOND_COLOR, 0.12), 0.08)


## Back with the room reset.
func _come_back() -> void:
	super()
	if rim != null:
		rim.visible = true
