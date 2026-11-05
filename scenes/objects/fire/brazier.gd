@tool
class_name Brazier
extends Switch
## Brazier (Fire_bending.md §6.2): an iron bowl on a short post. Light it and it is
## ON, so a linked Door opens (doors pick their switches in the Inspector, like
## pressure plates and windmills).
##
##   burn_time = 0   permanent: once lit, it stays lit until death or R
##   burn_time > 0   TIMED: it goes out after burn_time seconds and its door closes.
##                   The flame shrinks as the time runs out and gutters (flickers
##                   and dips) in the last second. Lighting it again restarts the time.
##
## How fire lights it: the Flammable contract (scenes/objects/fire/flammable.gd).
## It joins the "flammable" group, has ignite()/is_burning()/snuff()/get_fire_rect(),
## and a child Area2D on layer 6 ("flammable") that fireballs hit. The jet plume
## lights it by touching its fire rect.
##
## Lighting it: a flare, a ring of sparks, a 2-frame freeze and a shake (§9.4).
## The flame is NOT a FireHazard (decided in Stage F4): lighting one with the jet
## means flying right past it.
## A gust doesn't put it out (the bowl protects the flame, §5.4): snuff() does nothing.
##
## Place the node where the post meets the floor; the bowl sits post_height above.
## It joins the room's reset group: death or R puts it out (or, with `starts_lit`,
## lights it again).
##
## STARTS LIT (`starts_lit`): it's already burning when the room starts and after
## every reset, quietly (no flare, no shake), so its door starts open. Made for DARK
## ROOMS: a steady fire lights a larger area than a passing fireball (its flames'
## light is dark_brazier_light_scale bigger, FlameMerge.light_scale). A timed brazier
## that starts lit still runs out.

const BOWL_COLOR: Color = Color(0.24, 0.24, 0.27)
const RIM_COLOR: Color = Color(0.45, 0.45, 0.5)
const COAL_COLOR: Color = Color("#8A2410")
## Bowl: 12 px across the top, 8 at the bottom, 4 tall.
const BOWL_TOP_HALF_WIDTH: float = 6.0
const BOWL_BOTTOM_HALF_WIDTH: float = 4.0
const BOWL_HEIGHT: float = 4.0
const POST_WIDTH: float = 2.0
## The catch area around the bowl and its flame, px (wider than the bowl: aiming at
## a small thing should be forgiving).
const CATCH_SIZE: Vector2 = Vector2(14, 16)
## The flame: three tongues, calm (little flicker = "controlled fire", §9.3).
const FLAME_LENGTHS: Array[float] = [8.0, 11.0, 7.0]
const FLAME_OFFSETS_X: Array[float] = [-3.0, 0.0, 3.0]
## Lighting effects.
const LIGHT_FREEZE_TIME: float = 2.0 / 60.0
const LIGHT_SPARK_COUNT: int = 12
## The last this many seconds of a timed brazier: it gutters.
const GUTTER_TIME: float = 1.0
## A timed brazier's flame at the very end of its time, as a fraction of full size.
const SMALLEST_FLAME_SCALE: float = 0.35

## 0 = permanent. Otherwise seconds until it goes out.
@export var burn_time: float = 0.0:
	set(value):
		burn_time = value
		queue_redraw()
## Already lit when the room starts and after every reset (see the header).
@export var starts_lit: bool = false
## Height of the post (from the floor to the bottom of the bowl), px.
@export var post_height: float = 8.0:
	set(value):
		post_height = value
		queue_redraw()

## Seconds left before a timed brazier goes out (unused when permanent).
var time_remaining: float = 0.0
var flames: Array[FlameTongue] = []
var catch_area: Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(Flammable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	catch_area = Area2D.new()
	catch_area.name = "CatchArea"
	catch_area.collision_layer = Flammable.LAYER_BIT
	catch_area.collision_mask = 0
	catch_area.monitoring = false  # it is only found, it doesn't look for anything
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = CATCH_SIZE
	shape_node.shape = box
	shape_node.position = _get_catch_center()
	catch_area.add_child(shape_node)
	add_child(catch_area)
	# One merged flame: the tongues share an outline (FlameMerge).
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for flame_index: int in FLAME_LENGTHS.size():
		var flame: FlameTongue = FlameTongue.new()
		flame.position = Vector2(FLAME_OFFSETS_X[flame_index], _get_bowl_top_y())
		flame.base_width = 4.0
		flame.fan_width = 5.0
		flame.flicker_speed = 0.7
		flame.wobble_amount = 0.2
		flame.breath_amount = 0.12
		flame.fork_amount = 0.35
		flame.lick_rate = 2.0
		flame.lick_size = 3.0
		flame.lick_speed = 18.0
		flame.heat = 0.5
		flame.smoke_lifetime = 1.0
		flame.z_index = 1  # in front of the bowl's back edge
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		flames.append(flame)
	# Dark rooms: a steady fire lights a larger area (see the header).
	flame_merge.light_scale = (preload("res://resources/fire_tuning.tres") as FireTuning).dark_brazier_light_scale
	if starts_lit:
		_light(false)


# --- The Flammable contract ----------------------------------------------------------

## Lights it (called again and again while a flame keeps touching: only the first
## call plays the effects). A timed brazier that's already lit just restarts its time.
func ignite(_source: Node) -> void:
	_light(true)


## Lights it: restarts a timed one's time; the first time, `with_effects` plays the
## flare, sparks, freeze and shake (not when it starts lit).
func _light(with_effects: bool) -> void:
	time_remaining = burn_time
	if is_on():
		return
	set_on(true)
	for flame: FlameTongue in flames:
		flame.visible = true
	if not with_effects:
		return
	var bowl_center: Vector2 = global_position + Vector2(0.0, _get_bowl_top_y())
	FireRing.spawn(get_parent(), bowl_center, 12.0, 0.2)
	EmberEmitter.burst(get_parent(), bowl_center, LIGHT_SPARK_COUNT, Vector2.UP, 180.0, 70.0)
	FX.freeze(LIGHT_FREEZE_TIME)
	FX.shake(2.0, 0.15)
	FX.play_sfx(&"brazier_lit")


func is_burning() -> bool:
	return is_on()


## A gust doesn't reach the flame inside the bowl (Fire_bending.md §5.4).
func snuff() -> void:
	pass


func get_fire_rect() -> Rect2:
	return Rect2(global_position + _get_catch_center() - CATCH_SIZE / 2.0, CATCH_SIZE)


# --- Reset and the timer -----------------------------------------------------------

func reset() -> void:
	_go_out(false)
	if starts_lit:
		_light(false)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_on() or burn_time <= 0.0:
		return
	time_remaining -= delta
	if time_remaining <= 0.0:
		_go_out(true)


func _go_out(with_smoke: bool) -> void:
	if not is_on():
		return
	set_on(false)
	for flame: FlameTongue in flames:
		flame.visible = false
	if with_smoke:
		SmokePuff.spawn(get_parent(), global_position + Vector2(0.0, _get_bowl_top_y() - 2.0), 5)
		FX.play_sfx(&"brazier_out")


## Flame size for a timed brazier: shrinks with the time left, and in the last
## second it gutters (random dips and flickers).
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_on():
		return
	var flame_scale: float = 1.0
	var flame_opacity: float = 1.0
	if burn_time > 0.0:
		flame_scale = lerpf(SMALLEST_FLAME_SCALE, 1.0, clampf(time_remaining / burn_time, 0.0, 1.0))
		if time_remaining < GUTTER_TIME:
			flame_scale *= randf_range(0.5, 1.0)
			flame_opacity = randf_range(0.4, 1.0)
	var smoke_rate: float = _get_brazier_smoke_rate()
	for flame_index: int in flames.size():
		flames[flame_index].length = FLAME_LENGTHS[flame_index] * flame_scale
		flames[flame_index].opacity = flame_opacity
		# Only the tallest (middle) tongue smokes, so it reads as one thin column.
		flames[flame_index].smoke_rate = smoke_rate if flame_index == 1 else 0.0


## From the player's FireTuning when there is one, so F5 tunes it live.
func _get_brazier_smoke_rate() -> float:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	return player.fire_tuning.brazier_smoke_per_second if player != null else 3.0


# --- Drawing -----------------------------------------------------------------------

## The bowl's top edge, relative to this node (the post's foot).
func _get_bowl_top_y() -> float:
	return -post_height - BOWL_HEIGHT


func _get_catch_center() -> Vector2:
	return Vector2(0.0, _get_bowl_top_y() - 3.0)


func _draw() -> void:
	var bowl_bottom_y: float = -post_height
	var bowl_top_y: float = _get_bowl_top_y()
	draw_rect(Rect2(-POST_WIDTH / 2.0, bowl_bottom_y, POST_WIDTH, post_height), BOWL_COLOR)
	# A foot plate so it reads as standing on the floor.
	draw_rect(Rect2(-3.0, -1.0, 6.0, 1.0), BOWL_COLOR)
	var bowl: PackedVector2Array = PackedVector2Array([
		Vector2(-BOWL_TOP_HALF_WIDTH, bowl_top_y),
		Vector2(BOWL_TOP_HALF_WIDTH, bowl_top_y),
		Vector2(BOWL_BOTTOM_HALF_WIDTH, bowl_bottom_y),
		Vector2(-BOWL_BOTTOM_HALF_WIDTH, bowl_bottom_y),
	])
	draw_colored_polygon(bowl, BOWL_COLOR)
	draw_line(Vector2(-BOWL_TOP_HALF_WIDTH, bowl_top_y), Vector2(BOWL_TOP_HALF_WIDTH, bowl_top_y), RIM_COLOR, 1.0)
	# Cold coals in the bowl; they glow while lit.
	var coal_color: Color = Color("#FF8A1E") if is_on() else COAL_COLOR.darkened(0.4)
	draw_rect(Rect2(-3.0, bowl_top_y + 1.0, 6.0, 1.0), coal_color)
	# A timed brazier has notches on its post, so you can tell it apart before lighting.
	if burn_time > 0.0:
		for notch_index: int in 2:
			draw_rect(Rect2(-POST_WIDTH / 2.0 - 1.0, bowl_bottom_y + 2.0 + notch_index * 3.0, POST_WIDTH + 2.0, 1.0), RIM_COLOR)
