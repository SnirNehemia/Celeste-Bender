@tool
class_name TrailingPickup
extends Area2D
## TrailingPickup: the shared part of the pick-ups that FOLLOW the player after a
## touch instead of being taken at once (Collectibles.md): RelicShard and
## GoldenFeather extend it. It knows:
##   - the states: HOME (waiting where placed, bobbing), FOLLOWING (trailing behind
##     the player's pack), RETURNING (flying back home after a death), GONE (taken,
##     or broken: what it looks like then is up to the subclass);
##   - the CHAIN: several followers trail one behind the other (`chain`, a static
##     list shared by every follower: the first trails the pack, each next one the
##     one before it);
##   - what a death does: _on_carrier_died(), which subclasses replace (a shard flies
##     home, the feather shatters).
## Subclasses fill in _can_take() (may the player take it now?), _on_taken(),
## _follow_step() (per frame while following: a shard checks for safe ground) and
## _draw().
##
## WHY IT CHANGES PARENT: rooms the player is far from are frozen
## (RoomManager: PROCESS_MODE_DISABLED on the whole room), and a follower left inside
## its home room would freeze in mid-air as soon as the player walked into the next
## room. So while following it is moved under the world (the player's parent) with
## reparent(), which keeps its place on screen, and moved back home when it returns.
##
## Area2D on layer 3 (triggers) looking at layer 2 ("player"), like the crystals.
##
## Godot concepts used:
##   - static var: one value shared by every instance of the class (the chain).
##   - Node.reparent(): moves a node under another parent, keeping its global position.
##   - Virtual methods: functions a subclass defines again to change what happens;
##     the base class calls them without knowing which subclass it is.

enum State { HOME, FOLLOWING, RETURNING, GONE }

## Every follower now trailing the player, first (nearest the pack) to last.
static var chain: Array[TrailingPickup] = []

## Hitbox radius, px (pick-ups should be generous).
const HITBOX_RADIUS: float = 7.0
## Gentle float while home: amplitude px, cycles per second.
const BOB_AMPLITUDE: float = 1.5
const BOB_FREQUENCY: float = 0.8
## Following: how fast it closes on its spot (1/s, an exponential catch-up that
## eases in smoothly, frame-rate independent), its spot behind the one it follows
## (px: back and up), and the spot behind the pack for the first one.
const FOLLOW_SHARPNESS: float = 9.0
const CHAIN_GAP: Vector2 = Vector2(9.0, -1.0)
const PACK_GAP: Vector2 = Vector2(7.0, -5.0)
## Flying home after a death: seconds.
const RETURN_TIME: float = 0.5

var state: State = State.HOME
## Seconds in the current state, and since start (the bob).
var state_time: float = 0.0
var idle_time: float = 0.0
## The player it follows (null while home).
var carrier: Player = null
## Where it was placed: its parent then and its position there.
var home_parent: Node = null
var home_position: Vector2 = Vector2.ZERO
## Where a return flight starts (global px).
var return_start: Vector2 = Vector2.ZERO
## Drawing offset (the bob); the node itself stays put while home.
var bob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = 4  # bit value of layer 3
	collision_mask = 2   # bit value of layer 2, "player"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = HITBOX_RADIUS
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = circle
	add_child(hitbox)
	if Engine.is_editor_hint():
		return
	home_parent = get_parent()
	home_position = position
	add_to_group(DarkRoomOverlay.LIGHT_GROUP)


func _exit_tree() -> void:
	# A follower freed while trailing (a scene change) mustn't stay in the chain.
	chain.erase(self)


func _physics_process(delta: float) -> void:
	idle_time += delta
	state_time += delta
	if Engine.is_editor_hint():
		bob_offset = Vector2(0.0, roundf(sin(idle_time * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE))
		queue_redraw()
		return
	match state:
		State.HOME:
			bob_offset = Vector2(0.0, roundf(sin(idle_time * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE))
			_check_touch()
		State.FOLLOWING:
			bob_offset = Vector2.ZERO
			if not is_instance_valid(carrier):
				_go_home_now()
			else:
				var target: Vector2 = _get_chain_target()
				global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
				_follow_step(delta)
		State.RETURNING:
			var progress: float = minf(state_time / RETURN_TIME, 1.0)
			var home_global: Vector2 = _get_home_global()
			global_position = return_start.lerp(home_global, ease(progress, -2.0))  # ease in-out
			if progress >= 1.0:
				_go_home_now()
	queue_redraw()


## A live player in the hitbox who may take it (_can_take) starts the following.
func _check_touch() -> void:
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player != null and not touched_player.is_dead() and _can_take(touched_player):
			start_following(touched_player)
			return


## Starts trailing `player`: joins the end of the chain, leaves its room's branch.
func start_following(player: Player) -> void:
	carrier = player
	_set_state(State.FOLLOWING)
	# The `died` signal tells us about a death. CONNECT_ONE_SHOT: disconnected after
	# the first call, so a later death (after we're home) doesn't reach us.
	if not player.died.is_connected(_on_carrier_died):
		player.died.connect(_on_carrier_died, CONNECT_ONE_SHOT)
	reparent(player.get_parent())
	# Join the chain AFTER reparent(): leaving the old parent runs _exit_tree(),
	# which takes the node out of the chain.
	chain.append(self)
	_on_taken()


## Stops trailing (secured, broken or sent home): out of the chain, no more signal.
func stop_following() -> void:
	chain.erase(self)
	if is_instance_valid(carrier) and carrier.died.is_connected(_on_carrier_died):
		carrier.died.disconnect(_on_carrier_died)
	carrier = null


## Flies back home (the default for a death; RelicShard uses it).
func fly_home() -> void:
	stop_following()
	return_start = global_position
	_set_state(State.RETURNING)


## Back under its home parent at its home spot, waiting again.
func _go_home_now() -> void:
	stop_following()
	if home_parent != null and is_instance_valid(home_parent) and get_parent() != home_parent:
		reparent(home_parent)
	position = home_position
	_set_state(State.HOME)


## Back home but GONE (a broken feather shows dim where it was).
func park_home_gone() -> void:
	stop_following()
	if home_parent != null and is_instance_valid(home_parent) and get_parent() != home_parent:
		reparent(home_parent)
	position = home_position
	_set_state(State.GONE)


func _set_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0


func _get_home_global() -> Vector2:
	if home_parent is Node2D and is_instance_valid(home_parent):
		return (home_parent as Node2D).to_global(home_position)
	return global_position


## Its spot in the chain: behind the pack (first) or behind the one before it.
func _get_chain_target() -> Vector2:
	var facing: float = 1.0 if carrier.facing_direction >= 0.0 else -1.0
	var index: int = chain.find(self)
	if index <= 0:
		return carrier.body_look.get_pack_global_position() + Vector2(-facing * PACK_GAP.x, PACK_GAP.y)
	return chain[index - 1].global_position + Vector2(-facing * CHAIN_GAP.x, CHAIN_GAP.y)


## Its light in a dark room (DarkRoomOverlay) while it's there to see.
func get_dark_lights() -> Array[Vector4]:
	var lights: Array[Vector4] = []
	if state != State.GONE and is_visible_in_tree():
		var center: Vector2 = global_position + bob_offset
		lights.append(Vector4(center.x, center.y, 16.0, 0.6))
	return lights


# --- For subclasses -----------------------------------------------------------

## May `player` take it now?
func _can_take(_player: Player) -> bool:
	return true


## Just started following.
func _on_taken() -> void:
	pass


## Every physics frame while following, after moving.
func _follow_step(_delta: float) -> void:
	pass


## The carrier died while it followed. Default: fly home.
func _on_carrier_died() -> void:
	fly_home()
