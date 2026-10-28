@tool
class_name IceBlock
extends Crate
## IceBlock (Stage W5, Water_bending.md §7.3): FREE ice. Water frozen by the freeze
## (a thrown ball, a flung ribbon, a waterfall, the ball in your hands) becomes ice
## in exactly the shape it had (IceOutline, after the first W5 play-test: "freeze
## the ball in its original form"), and that ice keeps the water's MOMENTUM: it flies
## on, falls and lands (developer's call). It is a Crate underneath (extends Crate:
## scenes/objects/crate.gd), so it falls, floats (half under, like a wooden crate),
## loose water bumps off it and you can stand on it. Its collision is its outline,
## split into convex parts (physics shapes must be convex); it never turns (a Crate
## doesn't), so it lands the way it froze.
## Two kinds:
##   - COMPACT (a ball, a splash): a block you can gust and push around. It slides
##     far (friction ice_block_friction) and SHATTERS into loose water after a fall
##     of ice_block_shatter_fall px or more. Water breaks a fall (a block thrown into
##     a pool doesn't shatter on the pool's floor).
##   - LONG (`is_long`: a ribbon, a waterfall): it flies and falls the same way, but
##     LIES STILL where it lands (high friction, not pushable) as a platform, and
##     doesn't shatter (developer's call: "fly, then lie still").
## PINS (Stage W6, IcePins): touching a pin tip IMPALES it: it stops dead and stays
## there, at its angle, no longer pushable (a frozen ball becomes a fixed step over a
## pin bed, a frozen ribbon a fixed slide). Its mask includes the pins' layer 7
## "ice_catch" for that; nothing else looks at that layer but the snake's rope.
## SLIDES (Stage W6): a long piece lying flatter than slide_pillar_angle is a SLIDE,
## one-way for the player (SLIDE_GROUP, see Player._update_one_way_slides). A compact
## block on an ice slope slides down it (Crate, through IceSlope); a long one doesn't
## (it lies where it lands).
## FROZEN IN PLACE (re-planned ice, WaterTuning.ice_hangs, the default): a compact
## block is made with no momentum and HANGS where it froze, still, a step in the air.
## It comes loose only when something pushes it (a gust, the ball's shove, an Earth
## column or snake: receive_gust / receive_launch), and is then a PUCK: knocked off
## in the air it falls straight down (the push's sideways part is dropped) until it
## lands; on ice it slides with puck_ice_friction (none: on until something stops it),
## off ice puck_ground_friction stops it at once. Frozen in water, it floats instead.
## Fire MELTS it (the Flammable contract's ignite(): it doesn't burn). The room's
## WaterWorld made it, owns it (player_ice: the ice cap), frees it on reset, and melts
## it through WaterWorld.melt_ice(), which gives its water back exactly.
##
## Drawn by IceLook (glass, with icicles under long pieces) through the shared ice
## material. @tool only because Crate is (Godot warns otherwise); it's never placed
## in the editor.
##
## Groups: what a Crate joins (pushable, heavy, water_solid, flammable) but not
## Room.RESETTABLE_GROUP; a long piece isn't pushable either; plus "ice" (ICE_GROUP:
## the player slides on ice). Made only through IceBlock.make().

## The player treats floors and walls in this group as ice (Player.is_ice).
const ICE_GROUP: StringName = &"ice"
## A long piece stops this fast on the ground, px/s²: it lies where it lands.
const LONG_GROUND_FRICTION: float = 3000.0
## Ice the player only stands on from above (one-way: jump up through it). Members
## have get_slide_top_y(global_x) and get_slide_bounds() (Stage W6).
const SLIDE_GROUP: StringName = &"ice_slide"

## The water frozen in it, px² (read by WaterWorld.melt_ice).
var water_area: float = 0.0
var world: WaterWorld
var is_long: bool = false
## Its outline (local: the origin is the bottom-center of its box, like a crate's),
## and the same split into convex parts (collision, melting, loose water's boxes).
var outlines: Array[PackedVector2Array] = []
var parts: Array[PackedVector2Array] = []
var look: IceLook
## Where it last left the ground (y, global): a long fall shatters a compact one.
var fall_start_y: float = 0.0
var was_on_floor_last_frame: bool = false
## A slide: long and lying flatter than slide_pillar_angle (Stage W6).
var is_slide: bool = false
## Caught by pins (Stage W6): it doesn't move any more.
var is_impaled: bool = false
## Hanging where it froze (see the header): no physics until something pushes it.
## Not Crate.is_hanging, which means "hung from vines".
var is_frozen_in_place: bool = false
## Just knocked loose in the air: it falls straight down until it first lands.
var is_dropping_straight: bool = false


## New free ice: the outlines `room_outlines` (room-local) of `area` px² of water,
## moving at `start_velocity`, added to `owner_world`'s room. `long` picks the kind.
static func make(owner_world: WaterWorld, room_outlines: Array[PackedVector2Array], area: float,
		start_velocity: Vector2, long: bool) -> IceBlock:
	var block: IceBlock = IceBlock.new()
	block.name = "IceBlock"
	block.world = owner_world
	block.water_area = area
	block.is_long = long
	var box: Rect2 = IceOutline.bounds(room_outlines)
	# The origin at the bottom-center of the box, like a crate: then everything a
	# Crate works out from crate_size (its water box, its floating) fits the ice.
	var bottom_center: Vector2 = Vector2(box.get_center().x, box.end.y)
	block.outlines = IceOutline.moved(room_outlines, -bottom_center)
	block.parts = IceOutline.convex_parts(block.outlines)
	block.crate_size = box.size
	block.velocity = start_velocity
	block.ground_friction = LONG_GROUND_FRICTION if long else owner_world.water_tuning.ice_block_friction
	block.is_frozen_in_place = owner_world.water_tuning.ice_hangs and not long
	# Placed BEFORE add_child, so _ready() (run by add_child) sees where it is.
	block.position = owner_world.room.to_local(owner_world.to_global(bottom_center))
	owner_world.room.add_child(block)
	return block


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# The WaterWorld owns it (reset frees it); a crate's reset would put it "back".
	remove_from_group(Room.RESETTABLE_GROUP)
	if is_long:
		remove_from_group(Pushable.GROUP)  # it lies where it lands
	add_to_group(ICE_GROUP)
	# Pins catch it (Stage W6): look at their layer too.
	collision_mask |= IcePins.CATCH_LAYER_BIT
	is_slide = is_long and IceOutline.lying_angle_degrees(outlines) < world.water_tuning.slide_pillar_angle
	if is_slide:
		add_to_group(SLIDE_GROUP)
	# Its outline is its collision: the Crate's box goes, a convex shape per part comes.
	hitbox.queue_free()
	hitbox = null
	for part: PackedVector2Array in parts:
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.polygon = part
		add_child(shape)
	look = IceLook.build(outlines, is_long)
	material = IceLook.get_material()
	fall_start_y = global_position.y


func _physics_process(delta: float) -> void:
	if is_impaled:
		return  # held by the pins: it never moves again (until it melts)
	if is_frozen_in_place:
		# Frozen in water, it floats (water can't hold ice still); else it hangs.
		if not Engine.is_editor_hint() and is_instance_valid(world) \
				and world.get_submerged_share(get_water_box()) > 0.0:
			is_frozen_in_place = false
		else:
			velocity = Vector2.ZERO
			fall_start_y = global_position.y
			return
	if world != null and world.water_tuning.ice_hangs and not is_long:
		_set_puck_friction()
	if is_dropping_straight:
		velocity.x = 0.0
	super(delta)
	if is_dropping_straight and is_on_floor():
		is_dropping_straight = false
	if Engine.is_editor_hint() or not is_instance_valid(world):
		return
	if _touches_pins():
		_impale()
		return
	var on_floor: bool = is_on_floor()
	if submerged_share > 0.0:
		fall_start_y = global_position.y  # water breaks the fall
	elif was_on_floor_last_frame and not on_floor:
		fall_start_y = global_position.y
	elif not was_on_floor_last_frame and not on_floor:
		fall_start_y = minf(fall_start_y, global_position.y)  # the top of its arc
	elif not was_on_floor_last_frame and on_floor and not is_long \
			and global_position.y - fall_start_y >= world.water_tuning.ice_block_shatter_fall:
		# Landed after a long fall: it shatters into the water it was.
		world.melt_ice(self)
		return
	was_on_floor_last_frame = on_floor


## Did this frame's move touch a pin tip (IcePins.GROUP)?
func _touches_pins() -> bool:
	for index: int in get_slide_collision_count():
		var collider: Node = get_slide_collision(index).get_collider() as Node
		if collider != null and collider.is_in_group(IcePins.GROUP):
			return true
	return false


## Caught by pins: stops dead, for good, and nothing pushes it any more.
func _impale() -> void:
	is_impaled = true
	velocity = Vector2.ZERO
	remove_from_group(Pushable.GROUP)


## A puck's friction for this frame: none on ice (it glides on), a lot on anything
## else (it stops). The floor is what it stood on after last frame's move.
func _set_puck_friction() -> void:
	var tuning: WaterTuning = world.water_tuning
	var on_ice: bool = false
	if is_on_floor():
		for index: int in get_slide_collision_count():
			var collision: KinematicCollision2D = get_slide_collision(index)
			var collider: Node = collision.get_collider() as Node
			if collision.get_normal().y < -0.5 and collider != null and collider.is_in_group(ICE_GROUP):
				on_ice = true
				break
	ground_friction = tuning.puck_ice_friction if on_ice else tuning.puck_ground_friction


## Pushed while frozen in place: it comes loose. Resting on something (frozen on a
## sheet or the ground), it takes the push and slides; in the air, it drops straight.
func _come_loose() -> void:
	if not is_frozen_in_place:
		return
	is_frozen_in_place = false
	is_dropping_straight = not test_move(global_transform, Vector2(0.0, 1.0))


## The Pushable contract (Crate's), with coming loose first.
func receive_gust(direction: Vector2, strength: float) -> void:
	_come_loose()
	super(direction, strength)


func receive_launch(launch_velocity: Vector2) -> void:
	_come_loose()
	super(launch_velocity)


## Crate's hook (Stage W6): a compact block slides down ice slopes; a long piece
## lies where it lands.
func can_slide_on_ice() -> bool:
	return not is_long


## The top of the ice at `global_x` (global y), or INF where there's none: a one-way
## slide asks this (Player._update_one_way_slides).
func get_slide_top_y(global_x: float) -> float:
	var top: float = IceOutline.top_y_at(outlines, global_x - global_position.x)
	return top + global_position.y if top < INF else INF


## The box around it (global), for a quick "is the player near it?" test.
func get_slide_bounds() -> Rect2:
	var box: Rect2 = IceOutline.bounds(outlines)
	return Rect2(box.position + global_position, box.size)


## Loose water bumps off each convex part's box (global): a long arc isn't one big box.
func get_water_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for part: PackedVector2Array in parts:
		var box: Rect2 = Rect2(part[0], Vector2.ZERO)
		for point: Vector2 in part:
			box = box.expand(point)
		boxes.append(Rect2(box.position + global_position, box.size))
	return boxes


## Fell out of the room (a Crate calls reset() then): its water is gone with it.
func reset() -> void:
	if is_instance_valid(world):
		world.melt_ice(self)
	else:
		queue_free()


# --- The Flammable contract: fire MELTS ice (it doesn't burn) -------------------------

func ignite(_source: Node) -> void:
	if is_instance_valid(world):
		world.melt_ice(self)


func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


func _draw() -> void:
	if look != null:
		look.draw(self)
