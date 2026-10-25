@tool
class_name WindCrystal
extends Area2D
## Wind crystal (GAME_DESIGN.md §5.1, §6): a floating green diamond that refills the
## player's breath (glide stamina) and gust charge on touch, then respawns after a short delay.
##
## Place the node where the CENTER of the diamond should be. Everything (shape,
## hitbox) is built in code in _ready(), so wind_crystal.tscn is a single node.
##
## It talks to the player only through Player.refill_from_crystal(), which refills
## the breath AND the gust charge. If nothing needed refilling it
## returns false and the crystal is NOT used up (same as Celeste), so you can't
## waste a crystal by brushing past it.
##
## Used crystals come back after respawn_time, or at once when the room resets
## (death or R): the crystal joins Room.RESETTABLE_GROUP and has a reset() method.
##
## Area2D on physics layer 3 ("hazards"/triggers), looking at layer 2 ("player").
## @tool so the diamond is visible while placing it in the editor.
##
## LOOK (F7 play-test: "like the fire diamonds"): the same build as a fire diamond.
## A tall diamond (4 x 6 half size, the single fire diamond's shape), very light blue
## with a darker blue rim, and WIND blowing inside: thin blue streaks sliding across
## it, each on its own row and speed with a slight wave, cut off at the diamond's
## edge. GustDiamond is the double: the double's bigger shape and more streaks, in the
## same light blue (like the two fire diamonds share their orange). So a crystal and
## the +1 fire diamond it converts into share a shape, and so do the gust diamond and
## the +2.
##
## Other pickups reuse this script by INHERITING from it (`extends WindCrystal`):
## GustDiamond (gust_diamond.gd) changes the colors and sound in _init() and
## overrides _give_to(), and gets the bobbing, respawn and reset for free.
## FireDiamond (fire/fire_diamond.gd) does the same, and turns off `respawns`.
##
## FIRE CONVERTS IT (Stage F7, Fire_bending.md §4.3): crystals and gust diamonds are
## the "air diamonds". They are FLAMMABLE (flammable.gd: group "flammable", ignite(),
## get_fire_rect(), a catch area on layer 6 so fireballs hit them), so any flame
## touching one (a fireball, the jet, burning grass, a bonfire) converts it:
##   - an orange wipe crosses it from the side the fire came from
##     (conversion_wipe_time), then a flare
##   - a real FireDiamond worth `fire_pip_value` pips takes its place (+1 for the
##     crystal, +2 for the gust diamond), single use like every fire diamond
## The air diamond hides until the room resets; reset() frees the fire diamond and
## brings the air one back. FireDiamond sets fire_pip_value = 0: it can't convert.

## Very light blue, shared by both air diamonds (F7 play-test; the crystal was green,
## the gust diamond blue). Dimmed outline while respawning.
const CRYSTAL_COLOR: Color = Color(0.72, 0.9, 1.0)
const RESPAWNING_COLOR: Color = Color(0.72, 0.9, 1.0, 0.25)
## Darker blue rim, and wind streaks in a mid blue (white ones vanished against the
## light blue) (the fire diamond: red rim, yellow flame).
const CRYSTAL_RIM_COLOR: Color = Color(0.32, 0.58, 0.88)
const STREAK_COLOR: Color = Color(0.4, 0.66, 0.95)
## Half the hitbox's size, px (the drawing is air_half_size, below).
const HALF_SIZE: float = 5.0
## The rim is this many px bigger than the diamond on every side (like FireDiamond).
const AIR_RIM_WIDTH: float = 1.0
## Wind streaks: length (px), how fast they blow across (px/s, each streak ±30%), and
## how far their row waves up and down (px) as they go.
const STREAK_LENGTH: float = 4.5
const STREAK_SPEED: float = 9.0
const STREAK_WAVE: float = 0.5
## Gentle up-down float: amplitude in px and speed in cycles per second.
const BOB_AMPLITUDE: float = 1.5
const BOB_FREQUENCY: float = 0.8

## Conversion (Stage F7): the wipe's color and its brighter leading edge.
const CONVERSION_COLOR: Color = Color("#FF8A1E")
const CONVERSION_EDGE_COLOR: Color = Color("#FFD34D")

## Seconds before a used crystal comes back.
@export var respawn_time: float = 2.5

## Look and sound. Plain vars (not consts) so a subclass can change them in _init().
var ready_color: Color = CRYSTAL_COLOR
var respawning_color: Color = RESPAWNING_COLOR
var pickup_sound: StringName = &"crystal"
## False = single use: once used it stays gone until the room resets (death or R),
## instead of coming back after respawn_time. FireDiamond sets it in _init().
var respawns: bool = true
## Pips of the fire diamond a flame turns this into (Stage F7). 0 = not convertible.
var fire_pip_value: int = 1
## The air look (rim + wind streaks). Subclasses set these in _init(): GustDiamond is
## the double; FireDiamond turns it off (it has its own rim and flames).
var has_air_look: bool = true
var air_half_size: Vector2 = Vector2(4, 6)
var air_rim_color: Color = CRYSTAL_RIM_COLOR
var streak_count: int = 2

## True while the crystal is available to touch.
var is_available: bool = true
## Seconds since start, drives the bob animation.
var bob_time: float = 0.0
## Goes up on every use and every reset. A respawn timer remembers the value from
## when it started and does nothing if it changed, so a timer left over from before
## a room reset can't "pop" the crystal a second time.
var use_count: int = 0

var diamond: Polygon2D
## The air look's rim (behind the diamond) and wind streaks (on it), children of
## `diamond`.
var air_rim: Polygon2D
var air_streaks: Array[Polygon2D] = []
## Each streak's row (px, local), speed (px/s) and head start (px).
var streak_rows: PackedFloat32Array = PackedFloat32Array()
var streak_speeds: PackedFloat32Array = PackedFloat32Array()
var streak_offsets: PackedFloat32Array = PackedFloat32Array()
## The area streaks show in: the diamond, 1 px in from its edge.
var streak_clip: PackedVector2Array = PackedVector2Array()

## Conversion state (Stage F7). The wipe runs 0 -> 1 from the side the fire came from
## (wipe_from: unit vector from the middle toward that side).
var is_converting: bool = false
var is_converted: bool = false
var wipe_progress: float = 0.0
var wipe_from: Vector2 = Vector2.DOWN
var wipe_overlay: Polygon2D
var wipe_edge: Polygon2D
## The FireDiamond standing in for this one after conversion, until reset.
var converted_diamond: Node2D
var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")


func _ready() -> void:
	collision_layer = 4  # bit value of layer 3
	collision_mask = 2   # bit value of layer 2, "player"
	# Groups are named tags on nodes; Room.reset_objects() calls reset() on every
	# node in this group inside its room.
	add_to_group(Room.RESETTABLE_GROUP)

	diamond = Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -HALF_SIZE), Vector2(HALF_SIZE, 0), Vector2(0, HALF_SIZE), Vector2(-HALF_SIZE, 0)])
	diamond.color = ready_color
	add_child(diamond)
	if has_air_look:
		_build_air_look()

	# The hitbox is a little bigger than the drawing: pickups should be generous.
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = HALF_SIZE + 2.0
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = circle
	add_child(hitbox)

	if fire_pip_value > 0 and not Engine.is_editor_hint():
		add_to_group(Flammable.GROUP)
		_make_catch_area(circle.radius)


func _physics_process(delta: float) -> void:
	bob_time += delta
	# Only the drawing bobs; the hitbox stays put so touching it is predictable.
	diamond.position.y = roundf(sin(bob_time * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE)

	if has_air_look:
		_blow_streaks()
	if is_converting:
		_update_conversion(delta)
	if Engine.is_editor_hint() or not is_available:
		return
	# Checked every frame (not just on body_entered) so that a player who is ALREADY
	# inside the crystal when they spend their gust gets refilled right away.
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player != null and not touched_player.is_dead() \
				and _give_to(touched_player):
			_use_up()
			return


## What touching does. Returns true if it helped (only then is the crystal used up).
## Subclasses override this: GDScript calls the subclass's version when there is one.
func _give_to(touched_player: Player) -> bool:
	return touched_player.refill_from_crystal()


## Hide (dimmed outline), wait respawn_time, then come back.
func _use_up() -> void:
	is_available = false
	use_count += 1
	var this_use: int = use_count
	diamond.color = respawning_color
	FX.shake(1.0, 0.08)
	FX.play_sfx(pickup_sound)
	if not respawns:
		return  # single use: only reset() brings it back
	# create_timer() makes a one-shot timer; `await` pauses this function (not the game)
	# until it fires. Uses game time, so it also pauses during freeze frames.
	await get_tree().create_timer(respawn_time, false).timeout
	if this_use != use_count:
		return  # a room reset (or a newer use) happened meanwhile: not our timer anymore
	_come_back()
	# Quick pop so the player notices it's back.
	diamond.scale = Vector2(1.6, 1.6)
	var pop_tween: Tween = create_tween()
	pop_tween.tween_property(diamond, "scale", Vector2.ONE, 0.15)


## Available again, full color.
func _come_back() -> void:
	is_available = true
	diamond.color = ready_color
	if air_rim != null:
		air_rim.color = air_rim_color


# --- The air look (F7 play-test) -----------------------------------------------------

## The diamond in air_half_size, its rim, and streak_count wind streaks on rows spread
## over its height (like FireDiamond._build_look, with streaks for flames).
func _build_air_look() -> void:
	diamond.polygon = _air_diamond_points(air_half_size)
	air_rim = Polygon2D.new()
	air_rim.color = air_rim_color
	# show_behind_parent: drawn before the diamond, so it shows only as a border.
	air_rim.show_behind_parent = true
	air_rim.polygon = _air_diamond_points(air_half_size + Vector2.ONE * AIR_RIM_WIDTH)
	diamond.add_child(air_rim)
	streak_clip = _air_diamond_points(air_half_size - Vector2.ONE)
	# Fixed (not random) rows, speeds and head starts: the same in the editor and in
	# game, and two diamonds side by side still differ because their bob_time does.
	for streak_index: int in streak_count:
		var across: float = (float(streak_index) + 0.5) / streak_count * 2.0 - 1.0  # -1..1
		streak_rows.append(across * air_half_size.y * 0.5)
		streak_speeds.append(STREAK_SPEED * (1.0 + 0.3 * sin(streak_index * 2.1)))
		streak_offsets.append(streak_index * 3.7)
		var streak: Polygon2D = Polygon2D.new()
		streak.color = STREAK_COLOR
		diamond.add_child(streak)
		air_streaks.append(streak)
	_blow_streaks()


## Moves every streak across the diamond, left to right, wrapping round: each a thin
## sliver on its own row with a slight wave, cut to the inside of the diamond (so it
## slides in at one edge and out at the other). Hidden while used up.
func _blow_streaks() -> void:
	var span: float = air_half_size.x * 2.0 + STREAK_LENGTH * 2.0  # edge to edge, plus room to enter and leave
	for streak_index: int in air_streaks.size():
		var streak: Polygon2D = air_streaks[streak_index]
		streak.visible = is_available
		if not is_available:
			continue
		var travelled: float = bob_time * streak_speeds[streak_index] + streak_offsets[streak_index]
		var head_x: float = fposmod(travelled, span) - span / 2.0 + STREAK_LENGTH
		var row_y: float = streak_rows[streak_index] + STREAK_WAVE * sin(travelled * 0.9)
		# A thin lens: pointed at both ends, 1 px thick in the middle.
		var sliver: PackedVector2Array = PackedVector2Array([
			Vector2(head_x - STREAK_LENGTH, row_y), Vector2(head_x - STREAK_LENGTH * 0.5, row_y - 0.5),
			Vector2(head_x, row_y), Vector2(head_x - STREAK_LENGTH * 0.5, row_y + 0.5)])
		var inside: Array[PackedVector2Array] = Geometry2D.intersect_polygons(sliver, streak_clip)
		streak.polygon = inside[0] if not inside.is_empty() else PackedVector2Array()
	if air_rim != null and not is_available:
		air_rim.color = Color(air_rim_color, respawning_color.a)


func _air_diamond_points(half_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -half_size.y), Vector2(half_size.x, 0),
		Vector2(0, half_size.y), Vector2(-half_size.x, 0)])


## Called by Room.reset_objects() when the player dies or restarts the room:
## back at once (no pop), and use_count cancels any pending respawn timer. A
## converted one gets its air look back and the fire diamond is removed.
func reset() -> void:
	use_count += 1
	_undo_conversion()
	_come_back()


# --- Fire converts it (Stage F7) -----------------------------------------------------

## The Flammable contract: a flame touched it. Starts the conversion (once; only
## while it's there to touch: a used crystal waiting to respawn doesn't convert).
func ignite(source: Node) -> void:
	if fire_pip_value <= 0 or is_converting or is_converted or not is_available:
		return
	is_converting = true
	is_available = false  # no air pickup during the wipe
	wipe_progress = 0.0
	wipe_from = _get_fire_side(source)
	if wipe_overlay == null:
		wipe_overlay = Polygon2D.new()
		wipe_overlay.color = CONVERSION_COLOR
		diamond.add_child(wipe_overlay)
		wipe_edge = Polygon2D.new()
		wipe_edge.color = CONVERSION_EDGE_COLOR
		diamond.add_child(wipe_edge)
	wipe_overlay.visible = true
	wipe_edge.visible = true
	_update_wipe_shape()


func is_burning() -> bool:
	return is_converting


## Wind doesn't undo a conversion.
func snuff() -> void:
	pass


func get_fire_rect() -> Rect2:
	var reach: float = HALF_SIZE + 2.0
	return Rect2(global_position - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)


## Which side the fire touched from: toward the source if it has a place (a fireball's
## thrower, a bonfire, the jet on the player), else from below (burning grass: the
## grid as a whole sits at the room's corner, so its position means nothing).
func _get_fire_side(source: Node) -> Vector2:
	var source_2d: Node2D = source as Node2D
	if source_2d == null or source is FireGrid:
		return Vector2.DOWN
	var toward: Vector2 = source_2d.global_position - global_position
	return toward.normalized() if toward.length() > 0.5 else Vector2.DOWN


func _update_conversion(delta: float) -> void:
	wipe_progress += delta / maxf(fire_tuning.conversion_wipe_time, 0.01)
	if wipe_progress >= 1.0:
		_finish_conversion()
	else:
		_update_wipe_shape()


## The orange part: the diamond cut by a straight front that moves from the fire's
## side across to the far side; a thin yellow band rides the front.
func _update_wipe_shape() -> void:
	var reach: float = 8.0  # more than any air diamond's half size
	# The front's distance from the middle, along wipe_from: from the fire's side
	# (+reach) across to the far side (-reach). Orange is everything beyond it.
	var front: float = reach - 2.0 * reach * wipe_progress
	wipe_overlay.polygon = _clip_to_diamond(front, reach * 2.0)
	wipe_edge.polygon = _clip_to_diamond(front, 1.0)


## The part of the diamond between `front` and `front + depth` along wipe_from.
func _clip_to_diamond(front: float, depth: float) -> PackedVector2Array:
	var across: Vector2 = wipe_from.orthogonal() * 20.0
	var near_line: Vector2 = wipe_from * front
	var far_line: Vector2 = wipe_from * (front + depth)
	var band: PackedVector2Array = PackedVector2Array([
		near_line - across, near_line + across, far_line + across, far_line - across])
	var pieces: Array[PackedVector2Array] = Geometry2D.intersect_polygons(diamond.polygon, band)
	return pieces[0] if not pieces.is_empty() else PackedVector2Array()


## The wipe is done: a flare, and a FireDiamond takes this one's place.
func _finish_conversion() -> void:
	is_converting = false
	is_converted = true
	diamond.visible = false
	wipe_overlay.visible = false
	wipe_edge.visible = false
	var fire_diamond: FireDiamond = FireDiamond.new()
	fire_diamond.name = "%sFire" % name
	fire_diamond.pip_amount = fire_pip_value
	fire_diamond.position = position
	fire_diamond.bob_time = bob_time  # carries on bobbing in step, no jump
	get_parent().add_child(fire_diamond)
	converted_diamond = fire_diamond
	# The flare: the new diamond pops in big, a ring and a burst of sparks.
	fire_diamond.diamond.scale = Vector2(1.8, 1.8)
	var pop_tween: Tween = fire_diamond.create_tween()
	pop_tween.tween_property(fire_diamond.diamond, "scale", Vector2.ONE, 0.2)
	FireRing.spawn(get_parent(), global_position, 10.0, 0.2)
	EmberEmitter.burst(get_parent(), global_position, fire_tuning.conversion_spark_count, Vector2.UP, 180.0, 60.0)
	FX.shake(1.0, 0.1)
	FX.play_sfx(&"diamond_convert")


## Back to an air diamond (room reset).
func _undo_conversion() -> void:
	if converted_diamond != null and is_instance_valid(converted_diamond):
		converted_diamond.queue_free()
	converted_diamond = null
	is_converting = false
	is_converted = false
	if diamond != null:
		diamond.visible = true
	if wipe_overlay != null:
		wipe_overlay.visible = false
		wipe_edge.visible = false


## The Area2D fireballs hit (layer 6, "flammable"), the size of the pickup hitbox.
func _make_catch_area(radius: float) -> void:
	var catch_area: Area2D = Area2D.new()
	catch_area.name = "CatchArea"
	catch_area.collision_layer = Flammable.LAYER_BIT
	catch_area.collision_mask = 0
	catch_area.monitoring = false  # it is only found, it doesn't look for anything
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.shape = circle
	catch_area.add_child(shape_node)
	add_child(catch_area)
