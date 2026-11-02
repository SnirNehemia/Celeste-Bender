@tool
class_name IceRaft
extends Crate
## IceRaft (Stage W7a, kept by the grid ice, Stage I3; Water_bending.md §16
## "Re-planned: grid ice"): the only ice that MOVES. The held ball touching a water
## surface (or under it) + 2 makes one: a flat slab floating at that surface, as wide
## as the ball's whole units in tiles (IcePlan.for_ball, WaterWorld.apply_ice_plan).
## On clean water or black water: it's the way to cross black water.
##
## It is a Crate underneath (extends Crate: scenes/objects/crate.gd), so it floats,
## bobs on waves, rides currents (the water's speed drags it), loose water bumps off
## it and you can stand on it. Its collision is the Crate's box, sized to the slab
## (crate_size). It floats high (its own raft_buoyancy) and drifts far (its own low
## raft_water_drag, no air friction: afloat, a crate counts as "in the air").
## Gusts, the ball's shove and launches push it (the Pushable contract). Its deck is
## ice (IceLayer.ICE_GROUP: slow to start and stop on it). Whoever stands on it
## presses it down (raft_rider_weight), and jumping off pushes it back the other way
## (raft_jump_push). Gusting sideways while standing on it pushes it the other way,
## like a boat pushed off with a paddle (the wind-catcher contract), and it KEEPS that
## speed: each gust adds to it (raft_max_sail_speed), a neutral gust brakes it.
## Gusting DOWN (straight or diagonal, after the sailing play-tests) HOPS you and the
## raft up together, keeping its speed (in the air the raft chases your feet sideways,
## Sail.FLYING, so you land on it); gusting UP DIVES: the raft goes under, carrying
## you, under whatever hangs into the water, then back up (Sail.DIVING; on black
## water that still kills you). A diagonal adds its sideways recoil too. A floating
## crate takes a sideways gust's recoil too (Crate.absorb_gust_recoil); only a raft
## sails.
##
## Fire MELTS it (the Flammable contract's ignite(): it doesn't burn). The room's
## WaterWorld made it, owns it (rafts, the ice cap), frees it on reset, and melts it
## through WaterWorld.melt_raft(), which gives its water back exactly.
##
## Drawn by IceLook (glass) through the shared ice material. @tool only because
## Crate is (Godot warns otherwise); it's never placed in the editor.
##
## Groups: what a Crate joins (pushable, heavy, water_solid, flammable) but not
## Room.RESETTABLE_GROUP; plus the ice group. Made only through IceRaft.make().

## Its corners are cut this much, px (it reads as a slab of ice, not a crate).
const CORNER_CUT: float = 1.5

## A diagonal gust's sail move (absorb_gust_recoil):
##   NONE       floating as usual
##   DIVING     under the water and back up for raft_dive_time, carrying the rider
##   LAUNCHING  hops on its next frame (the gust came from inside the player's state
##              change, which mustn't start another one: Player.launch_by does)
##   FLYING     in the air after a hop: chases the rider's feet sideways
##   LANDING    falling back: the water it lands in soaks up the fall (raft_land_speed)
enum Sail { NONE, DIVING, LAUNCHING, FLYING, LANDING }
## FLYING while you rise: its deck stays this many px under your feet. More than the
## player's floor snap (1 px): any closer and you stood on it in mid-air, it lifted
## you, and you two climbed 86 px instead of 17.
const FOLLOW_GAP: float = 2.5
## DIVING: your feet are put this far above its deck (touching it, not in it), and
## you're lost when something holds you more than DIVE_LOST_DISTANCE px from there.
const DIVE_FEET_GAP: float = 0.05
const DIVE_LOST_DISTANCE: float = 3.0
## A gust from above counts as "over the deck" this many px past either end (the
## player is 8 px wide: half over its end still lands on it).
const DECK_GUST_MARGIN: float = 4.0

## The water frozen in it, px² (read by WaterWorld.melt_raft).
var water_area: float = 0.0
var world: WaterWorld
## The freeze that made it (the ice cap melts freezes).
var freeze_id: int = -1
var look: IceLook
## Was the player standing on it last frame (for the jump's recoil)?
var was_ridden: bool = false
var sail: Sail = Sail.NONE
## DIVING: game seconds of the dive left. FLYING: seconds it may still chase you.
var sail_time_remaining: float = 0.0
## The forward speed of the sail move, px/s, and (LAUNCHING) the hop's upward speed.
var sail_speed_x: float = 0.0
var hop_speed: float = 0.0
## FLYING: whom it chases.
var hop_rider: Player = null
## LAUNCHING done, the rider's launch waits for the raft's own move (_launch_rider).
var is_launching_rider: bool = false
## The rider's own platform_on_leave, put back when the hop ends (_end_rider_launch).
var rider_platform_on_leave: CharacterBody2D.PlatformOnLeave = CharacterBody2D.PLATFORM_ON_LEAVE_ADD_VELOCITY
## DIVING: whom it carries (null once they're lost: a rock stopped them), and where
## on the deck they stand (px from its middle).
var dive_rider: Player = null
var dive_offset_x: float = 0.0


## A new raft filling `room_rect` (room-local px) holding `area` px² of water, added
## to `owner_world`'s room.
static func make(owner_world: WaterWorld, room_rect: Rect2, area: float, made_by: int) -> IceRaft:
	var raft: IceRaft = IceRaft.new()
	raft.name = "IceRaft"
	raft.world = owner_world
	raft.water_area = area
	raft.freeze_id = made_by
	raft.crate_size = room_rect.size
	raft.air_friction = 0.0  # on water it's "in the air": only the water slows it
	# The origin at the bottom-center of the slab, like a crate. Placed BEFORE
	# add_child, so _ready() (run by add_child) sees where it is.
	var bottom_center: Vector2 = Vector2(room_rect.get_center().x, room_rect.end.y)
	raft.position = owner_world.room.to_local(owner_world.to_global(bottom_center))
	owner_world.room.add_child(raft)
	return raft


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# The WaterWorld owns it (reset frees it); a crate's reset would put it "back".
	remove_from_group(Room.RESETTABLE_GROUP)
	add_to_group(IceLayer.ICE_GROUP)
	# Its own moves ignore the player (layer 2; you still stand on it). Bobbing up into
	# your feet, it got pushed back down, your floor snap followed it, and the two of
	# you sank together into the black water (found in W7a).
	collision_mask &= ~2
	# It moves AFTER the player each physics frame (higher priority runs later): a dive
	# then puts the rider back on its deck where it just went, and a hop's chase aims at
	# where you are this frame, not the frame before.
	process_physics_priority = 1
	var half: float = crate_size.x * 0.5
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-half + CORNER_CUT, -crate_size.y), Vector2(half - CORNER_CUT, -crate_size.y),
		Vector2(half, -crate_size.y + CORNER_CUT), Vector2(half, -CORNER_CUT),
		Vector2(half - CORNER_CUT, 0.0), Vector2(-half + CORNER_CUT, 0.0),
		Vector2(-half, -CORNER_CUT), Vector2(-half, -crate_size.y + CORNER_CUT),
	])
	var outlines: Array[PackedVector2Array] = [outline]
	look = IceLook.build(outlines, false)
	material = IceLook.get_material()


func _physics_process(delta: float) -> void:
	var was_diving: bool = sail == Sail.DIVING
	if not Engine.is_editor_hint() and is_instance_valid(world):
		_carry_rider(delta)
		_sail(delta)
	super(delta)
	if was_diving:
		# Its last dive frame too (_sail has just ended the dive), or you'd end up
		# a pixel inside its deck.
		_carry_diver()
		if sail != Sail.DIVING:
			if is_instance_valid(dive_rider):
				dive_rider.velocity = Vector2.ZERO  # on the deck again, at rest on it
			dive_rider = null
	elif is_launching_rider:
		_launch_rider()


## Melted or freed mid-hop (any way out of the tree): the rider gets their
## platform_on_leave back.
func _exit_tree() -> void:
	_end_rider_launch()


## The player if they're standing on it, else null.
func _get_rider() -> Player:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player != null and not player.is_dead() and player.get_floor_body() == self:
		return player
	return null


## Its rider (the player standing on it) presses it down while there; jumping off
## pushes it back the other way and dips it (the recoil).
func _carry_rider(delta: float) -> void:
	var tuning: WaterTuning = world.water_tuning
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var is_ridden: bool = _get_rider() != null
	if is_ridden:
		velocity.y += gravity * tuning.raft_rider_weight * delta
	elif was_ridden and player != null and player.velocity.y < 0.0 and sail != Sail.FLYING \
			and sail != Sail.DIVING:
		# Jumped off: pushed back away from the arrow held (none: only the dip). Not
		# after a hop or in a dive: you two move together.
		velocity.x -= signf(player.get_move_input()) * tuning.raft_jump_push
		velocity.y += tuning.raft_jump_dip
	was_ridden = is_ridden


## The diagonal gust's sail moves (see Sail). Runs before the Crate's own physics, so
## gravity, the water's lift and drag still act on the velocity set here.
func _sail(delta: float) -> void:
	var tuning: WaterTuning = world.water_tuning
	match sail:
		Sail.DIVING:
			# Down for the first half, back up for the second, going forward all along
			# (its lift is neutral meanwhile: _get_buoyancy).
			sail_time_remaining -= delta
			var is_going_down: bool = sail_time_remaining > tuning.raft_dive_time * 0.5
			velocity = Vector2(sail_speed_x, tuning.raft_dive_speed * (1.0 if is_going_down else -1.0))
			if sail_time_remaining <= 0.0:
				sail = Sail.NONE  # the rider is let go after this frame's carry
		Sail.LAUNCHING:
			_hop(hop_speed)
		Sail.FLYING:
			_follow_rider(delta)
		Sail.LANDING:
			# Back on the water: the splash takes the fall's speed, so the deck (and
			# your feet) don't plunge under. Unchecked it went 6 px under: on black water,
			# death. On solid ground it just lands.
			if submerged_share > 0.0:
				velocity.y = minf(velocity.y, tuning.raft_land_speed)
				sail = Sail.NONE
			elif is_on_floor():
				sail = Sail.NONE


## Launches the raft (and, once it has moved, the rider standing on it: _launch_rider)
## up at `speed`, forward at sail_speed_x. With nobody on it, it only bobs up.
func _hop(speed: float) -> void:
	var rider: Player = _get_rider()
	velocity = Vector2(sail_speed_x, -speed)
	if rider == null:
		sail = Sail.NONE
		return
	hop_rider = rider
	is_launching_rider = true
	sail = Sail.FLYING
	sail_time_remaining = world.water_tuning.raft_follow_time


## Right after the raft's launching move: the rider gets the same launch. The same
## velocity for both, and the same gravity (900 each): you rise and fall together;
## Launched keeps your speed above run speed (it fades slowly). The WHOLE launch, and
## leaving the deck adds nothing (platform_on_leave off until the hop ends,
## _end_rider_launch). Before, you got the launch minus the raft's own speed and
## counted on Godot adding that speed back as you left its deck (CharacterBody2D's
## platform_on_leave), but the raft had already risen into your feet: what was left
## was ~0, you never left the deck, and the raft flew off without you (flaky).
func _launch_rider() -> void:
	is_launching_rider = false
	if not is_instance_valid(hop_rider):
		return
	rider_platform_on_leave = hop_rider.platform_on_leave
	hop_rider.platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	# Feet on its deck where it went (it rose into them), not inside it.
	hop_rider.global_position.y = minf(hop_rider.global_position.y, global_position.y - crate_size.y - DIVE_FEET_GAP)
	hop_rider.launch_by(Vector2(sail_speed_x, -hop_speed))


## The hop is over (landed, lost or timed out): the rider leaves moving floors as
## usual again.
func _end_rider_launch() -> void:
	if is_instance_valid(hop_rider):
		hop_rider.platform_on_leave = rider_platform_on_leave
	hop_rider = null


## In the air after a hop: it moves sideways to stay under the rider's feet, until they
## land (on it or anywhere), die, or raft_follow_time runs out. Its height is its own
## (same launch, same gravity: it stays just under you; holding jump you float higher).
func _follow_rider(delta: float) -> void:
	sail_time_remaining -= delta
	# Landed = on a floor and not rising: right after the launch, is_on_floor() still
	# reports the frame before (the raft's deck).
	var has_landed: bool = is_instance_valid(hop_rider) and hop_rider.is_on_floor() and hop_rider.velocity.y >= 0.0
	if not is_instance_valid(hop_rider) or hop_rider.is_dead() or has_landed or sail_time_remaining <= 0.0:
		if has_landed and hop_rider.get_floor_body() == self:
			# Landed back on it: your speed becomes your speed ON it (the deck carries
			# you as well). You flew as fast as it did, so you stand still on it; kept
			# whole, the two added up and you ran off its front.
			hop_rider.velocity.x -= velocity.x
		sail = Sail.LANDING
		_end_rider_launch()
		return
	# Steering nothing, you keep the hop's sideways speed (the raft's momentum, after the
	# second sailing play-test): air control alone braked a slow hop to a stop in the
	# air, and the raft, chasing you, lost its speed with you.
	if hop_rider.get_move_input() == 0.0:
		hop_rider.velocity.x = sail_speed_x
	var follow_speed: float = world.water_tuning.raft_follow_speed
	# gap / delta: the speed that closes the whole gap this frame (clamped, so a raft
	# stuck behind a wall doesn't jump when it comes free).
	velocity.x = clampf((hop_rider.get_center().x - global_position.x) / delta, -follow_speed, follow_speed)
	if hop_rider.velocity.y < 0.0:
		# Rising: its deck held just under your feet (the player's origin). On its own
		# the water's lift at the launch sent it up faster than you, into your feet,
		# and knocked you off it. Falling, its own gravity (the same as yours) is enough.
		var target_y: float = hop_rider.global_position.y + FOLLOW_GAP + crate_size.y
		velocity.y = clampf((target_y - global_position.y) / delta, -follow_speed, follow_speed)


## DIVING, after its own move: puts the rider back on its deck where it went (under
## water you'd only sink slowly, and it would leave you behind). move_and_collide, so
## rock still stops you: hit something hanging into the water and the raft goes on
## without you.
func _carry_diver() -> void:
	if not is_instance_valid(dive_rider) or dive_rider.is_dead():
		dive_rider = null
		return
	var feet: Vector2 = Vector2(global_position.x + dive_offset_x, global_position.y - crate_size.y - DIVE_FEET_GAP)
	var collision: KinematicCollision2D = dive_rider.move_and_collide(feet - dive_rider.global_position)
	if collision != null and dive_rider.global_position.distance_to(feet) > DIVE_LOST_DISTANCE:
		dive_rider = null  # stopped by rock: lost
		return
	dive_rider.velocity = velocity  # its own move next frame goes the same way


## Player.WIND_CATCHER_METHOD (Stage W7a): standing on a raft and gusting, your feet
## stay planted and the RAFT takes the gust's recoil: it moves the other way. The
## recoil ADDS to the speed it already has (after the second sailing play-test), up to
## raft_max_sail_speed: gust right again and again to gain speed. Aimed down (straight
## or on a diagonal) it HOPS, aimed up it DIVES (see Sail), keeping that speed, so you
## sail over or under things without losing it. A neutral gust brakes it
## (receive_gust_from). The gust's own cone doesn't push the raft you stand on
## (receive_gust_from ignores an aimed gust from over the deck): this is its whole push.
func absorb_gust_recoil(direction: Vector2, strength: float) -> void:
	if not is_instance_valid(world):
		return
	var tuning: WaterTuning = world.water_tuning
	var recoil: float = -signf(direction.x) * strength * tuning.raft_gust_recoil_share
	var new_speed_x: float = clampf(velocity.x + recoil, -tuning.raft_max_sail_speed, tuning.raft_max_sail_speed)
	if direction.y > 0.0:
		sail = Sail.LAUNCHING
		sail_speed_x = new_speed_x
		hop_speed = tuning.raft_hop_speed
	elif direction.y < 0.0:
		dive_rider = _get_rider()
		if dive_rider == null:
			return
		sail = Sail.DIVING
		sail_speed_x = new_speed_x
		sail_time_remaining = tuning.raft_dive_time
		dive_offset_x = dive_rider.global_position.x - global_position.x
	else:
		velocity.x = new_speed_x


## The Pushable contract, with the gust's origin (Pushable.METHOD_WITH_SOURCE). A gust
## blown from ABOVE its deck (after the sailing play-test) doesn't blow it away:
## falling toward it with a neutral gust, the all-around blast shoved the raft out
## from under you. From over the deck, the NEUTRAL gust brakes it (raft_neutral_brake
## px/s toward the water's speed; with the landing grip, Player.has_ice_landing_grip,
## you land and stop on it) and an aimed one does nothing here (standing on it, that
## gust's push is absorb_gust_recoil). From anywhere else it's the Crate's push.
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	var deck_top: float = global_position.y - crate_size.y
	var is_over_deck: bool = source_position.is_finite() and source_position.y < deck_top \
		and absf(source_position.x - global_position.x) <= crate_size.x * 0.5 + DECK_GUST_MARGIN
	if not is_over_deck:
		receive_gust(direction, strength)
		return
	# The neutral gust pushes everything straight away from its center
	# (AirBlast.push_around); an aimed one, along its aim.
	var is_neutral: bool = direction.is_equal_approx((global_position - source_position).normalized())
	if is_neutral and is_instance_valid(world):
		velocity.x = move_toward(velocity.x, water_speed_x, world.water_tuning.raft_neutral_brake)


## Does standing on this take the gust's recoil (Player.get_wind_catching_floor)? Only
## while it floats (like the Crate): a raft left on dry ground is just ground, so your
## gust shoves YOU as usual and nothing hops or dives (after the third sailing
## play-test: on land an up-gust "dived" the raft into the ground and it sprang back
## out a moment later, a recoil from water that wasn't there).
func is_catching_wind() -> bool:
	return submerged_share > 0.0


## Crate's hook: a raft floats high (raft_buoyancy: after the W7a play-test, your
## feet stay above the black water). Diving, its lift just balances its weight (1:
## wholly under, it neither rises nor sinks), so the dive's speed holds.
func _get_buoyancy() -> float:
	if sail == Sail.DIVING:
		return 1.0
	if is_instance_valid(world):
		return world.water_tuning.raft_buoyancy
	return super()


## Crate's hook: a raft drifts far on water (raft_water_drag, Stage W7a).
func _get_water_drag() -> float:
	if is_instance_valid(world):
		return world.water_tuning.raft_water_drag
	return super()


## Crate's hook: a raft afloat settles fast instead of bouncing (raft_bob_damping),
## except while it sails: a hop or a dive sets its own up-and-down speed.
func _get_bob_damping() -> float:
	if is_instance_valid(world) and sail == Sail.NONE:
		return world.water_tuning.raft_bob_damping
	return 0.0


## Crate's hook: a raft on an ice slope slides down it like a crate.
func can_slide_on_ice() -> bool:
	return true


## Fell out of the room (a Crate calls reset() then): its water is gone with it.
func reset() -> void:
	if is_instance_valid(world):
		world.melt_raft(self)
	else:
		queue_free()


# --- The Flammable contract: fire MELTS ice (it doesn't burn) -------------------------

func ignite(_source: Node) -> void:
	if is_instance_valid(world):
		world.melt_raft(self)


func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


func _draw() -> void:
	if look != null:
		look.draw(self)
