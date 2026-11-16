extends Node
## Headless smoke test for the levels written by tools/build_basics_level.gd and
## tools/build_element_levels.gd. Not part of the game.
##
## For EVERY level in LEVEL_PATHS: it loads, has a start room and a Goal, its relics
## are whole (four slots each), and the player is alive and inside the room after
## spawning in each room (the same teleport the F2 room picker uses).
## Then, per level, the parts a wrong tile would silently break: fake walls can be
## walked through, pick-ups are where the player can touch them, the things that
## must open do open. It does NOT prove a level can be finished by hand: jumps and
## bends are only checked by playing.
## Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/built_levels_smoke_test.tscn
## Add `-- basics` (or air, earth, fire, water) to run only that level.

const LEVEL_PATHS: Dictionary = {
	"basics": "res://levels/chapter_0_basics_finished.tscn",
	"air": "res://levels/air_the_high_road.tscn",
	"earth": "res://levels/earth_the_deep_dig.tscn",
	"fire": "res://levels/fire_the_ember_wood.tscn",
	"water": "res://levels/water_the_thaw.tscn",
}
## How long a pick-up needs to notice the player and settle, s.
const PICKUP_WAIT: float = 1.5
## A Key orb grows, holds and flies to the pack before it counts, s.
const KEY_WAIT: float = 3.5

var failures: int = 0
var level: RoomManager = null


func _ready() -> void:
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	for level_key: String in LEVEL_PATHS:
		if not wanted.is_empty() and not wanted.has(level_key):
			continue
		if not ResourceLoader.exists(LEVEL_PATHS[level_key]):
			_check(false, "%s: level file exists (%s)" % [level_key, LEVEL_PATHS[level_key]])
			continue
		await _open_level(level_key)
		await _check_every_room(level_key)
		await call("_check_%s" % level_key)
		_close_level()
	print("[BuiltLevels] %s" % ("ALL PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Loads the level into the tree with a fresh run. The player can't be killed by
## hazards (Player.is_invincible, the play-test cheat): the checks teleport it
## into the middle of things.
func _open_level(level_key: String) -> void:
	GameState.reset_run()
	level = (load(LEVEL_PATHS[level_key]) as PackedScene).instantiate() as RoomManager
	add_child(level)
	await get_tree().physics_frame
	level.player.is_invincible = true
	_check(level.current_room != null, "%s: the player starts inside a room" % level_key)


func _close_level() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	level.queue_free()
	level = null
	FX.clear_slow_motion()


## Structure, then a visit to every room.
func _check_every_room(level_key: String) -> void:
	var goal_count: int = 0
	var slots_by_element: Dictionary = {}
	for room: Room in level.rooms:
		for node: Node in room.get_children():
			if node is Goal:
				goal_count += 1
			elif node is RelicShard:
				var shard: RelicShard = node as RelicShard
				var slots: Array = slots_by_element.get(shard.element, [])
				slots.append(shard.slot)
				slots_by_element[shard.element] = slots
	_check(goal_count == 1, "%s: one Goal (found %d)" % [level_key, goal_count])
	_check(not slots_by_element.is_empty(), "%s: has relic shards" % level_key)
	for element: Variant in slots_by_element:
		var slots: Array = slots_by_element[element]
		slots.sort()
		_check(slots == [1, 2, 3, 4], "%s: relic %s has slots 1-4 once each (found %s)" % [level_key, element, slots])
	for room: Room in level.rooms:
		level.jump_to_room(room)
		await get_tree().create_timer(0.3).timeout
		_check(not level.player.is_dead(), "%s: alive after spawning in %s" % [level_key, room.name])
		_check(room.get_bounds().grow(2.0).has_point(level.player.get_center()),
			"%s: spawn of %s is inside the room" % [level_key, room.name])


# --- Helpers -----------------------------------------------------------------------

## Stands the player's feet at `local_px` of the room called `room_name`.
func _stand(room_name: String, local_px: Vector2) -> Room:
	var room: Room = level.get_node(room_name) as Room
	if level.current_room != room:
		level.jump_to_room(room)
	level.player.respawn_at(room.global_position + local_px)
	level.player.velocity = Vector2.ZERO
	return room


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Holds a move action for `seconds`, then lets go.
func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


## Touches the Key orb `orb_name` and checks its key is in the bag.
func _take_key(room_name: String, orb_name: String) -> void:
	var room: Room = level.get_node(room_name) as Room
	var orb: KeyOrb = room.get_node(orb_name) as KeyOrb
	_stand(room_name, orb.position + Vector2(0, 5))
	await _wait(KEY_WAIT)
	_check(GameState.has_key(orb.key_color), "%s: key of %s collected" % [room_name, orb_name])


## Touches the relic shard `shard_name`, then stands on `ground_px` until it counts.
func _take_shard(room_name: String, shard_name: String, ground_px: Vector2) -> void:
	var room: Room = level.get_node(room_name) as Room
	var shard: RelicShard = room.get_node(shard_name) as RelicShard
	_stand(room_name, shard.position + Vector2(0, 5))
	await _wait(0.3)
	_stand(room_name, ground_px)
	await _wait(PICKUP_WAIT)
	_check(GameState.has_shard(shard.element, shard.slot), "%s: %s secured" % [room_name, shard_name])


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS  %s" % description)
	else:
		failures += 1
		print("FAIL  %s" % description)


# --- Chapter 0 - Basics (finished) -------------------------------------------------

func _check_basics() -> void:
	# The golden feather first: it can only be taken with no deaths.
	var start: Room = _stand("Room1", Vector2(88, 128))
	await _wait(PICKUP_WAIT)
	_check(GameState.is_carrying_golden, "basics: golden feather taken over the first pillar")
	# The fake wall behind the spawn point: walk left into Room0.
	_stand("Room1", (start.get_node("SpawnPoint") as Marker2D).position)
	await _hold(&"move_left", 1.5)
	_check(level.current_room == level.get_node("Room0"), "basics: walking left from the start goes through the fake wall into Room0")
	await _take_shard("Room0", "RelicShard2", Vector2(60, 96))
	await _take_shard("Room18", "RelicShard1", Vector2(40, 96))
	# The dark wing: through the fake wall beside the brazier.
	_stand("Room29", Vector2(120, 160))
	await _hold(&"move_right", 1.2)
	var dark: Room = level.get_node("Room29") as Room
	_check(level.player.global_position.x > dark.global_position.x + 22 * 8,
		"basics: the dark wing's fake wall lets you through")
	await _take_shard("Room29", "RelicShard4", Vector2(148, 88))
	await _take_key("Room29", "KeyOrbGreen")
	# The sky ride's shard hangs in the air: touch it, then stand on the island.
	await _take_shard("Room39", "RelicShard3", Vector2(640, 152))
	await _take_key("Room40", "KeyOrbOrange")
	await _take_key("Room17", "KeyOrb")
	await _check_basics_enemy_wing()
	# All four keys: the hub's lights light, the Grand door behind it opens, the Goal ends the run.
	_stand("Room14", Vector2(164, 384))
	await _wait(5.0)
	var hub: Room = level.get_node("Room14") as Room
	for light_name: String in ["KeyLight", "KeyLight2", "KeyLight3", "KeyLight4"]:
		_check((hub.get_node(light_name) as KeyLight).is_on(), "basics: hub %s is lit" % light_name)
	var sanctum: Room = _stand("Room15", Vector2(20, 168))
	await _wait(3.0)
	_check((sanctum.get_node("GrandDoor") as Door).wants_open, "basics: the Grand door opens with all four keys")
	_stand("Room15", Vector2(292, 168))
	await _wait(0.5)
	_check(GameState.is_run_finished, "basics: touching the Goal finishes the run")
	_check(GameState.count_shards() == 4, "basics: all four shards secured (found %d)" % GameState.count_shards())


## Room42: each falling block, touched, drops on its lane's wisps; all six beaten
## opens the door over the stairs, and the yellow key is on the ledge behind it.
func _check_basics_enemy_wing() -> void:
	var arena: Room = _stand("Room42", Vector2(20, 320))
	for sentry_name: String in ["Sentry", "Sentry2", "Sentry3"]:
		(arena.get_node(sentry_name) as Sentry).destroy()
	var gate: EnemyGate = arena.get_node("EnemyGate") as EnemyGate
	_check(not gate.is_on(), "basics: enemy gate starts off")
	# [where to stand on the block (feet, px), the wisps under it].
	var drops: Array = [
		[Vector2(40, 296), ["Wisp6"]],
		[Vector2(128, 312), ["Wisp5", "Wisp", "Wisp2", "Wisp3"]],
		[Vector2(228, 296), ["Wisp4"]],
	]
	for drop: Array in drops:
		_stand("Room42", drop[0])
		await _wait(2.0)
		for wisp_name: String in drop[1]:
			_check((arena.get_node(wisp_name) as Wisp).state == Wisp.State.DEFEATED,
				"basics: the falling block crushed %s" % wisp_name)
	_check(gate.is_on(), "basics: enemy gate on after all six wisps")
	_check((arena.get_node("Door") as Door).wants_open, "basics: the door over the stairs opens")
	await _take_key("Room42", "KeyOrbYellow")


# --- The four element levels (tools/build_element_levels.gd) -----------------------

func _check_air() -> void:
	await _check_element_level("air")


func _check_earth() -> void:
	await _check_element_level("earth")


func _check_fire() -> void:
	await _check_element_level("fire")


func _check_water() -> void:
	await _check_element_level("water")


## What every element level shares: the feather in Room1, a shard in each of Room1-3
## and RoomS, the Key orb in Room2, and Room4's Key light, Grand door, depth gate
## and Goal.
func _check_element_level(level_key: String) -> void:
	var first: Room = level.get_node("Room1") as Room
	_stand("Room1", (first.get_node("GoldenFeather") as Node2D).position + Vector2(0, 5))
	await _wait(PICKUP_WAIT)
	_check(GameState.is_carrying_golden, "%s: golden feather can be taken" % level_key)
	for slot_room: Array in [[1, "Room1"], [2, "Room2"], [3, "Room3"], [4, "RoomS"]]:
		var room: Room = level.get_node(slot_room[1]) as Room
		await _take_shard(slot_room[1], "RelicShard%d" % slot_room[0], (room.get_node("SpawnPoint") as Marker2D).position)
	await _take_key("Room2", "KeyOrb")
	var gate_room: Room = _stand("Room4", (level.get_node("Room4/SpawnPoint") as Marker2D).position)
	await _wait(4.0)
	_check((gate_room.get_node("KeyLight") as KeyLight).is_on(), "%s: the Key light is lit" % level_key)
	_check((gate_room.get_node("GrandDoor") as Door).wants_open, "%s: the Grand door opens" % level_key)
	var twin: DepthGate = (gate_room.get_node("DepthGate") as DepthGate).find_twin()
	_check(twin != null and Room.find_room_of(twin) == level.get_node("RoomS"), "%s: the depth gate's twin is in RoomS" % level_key)
	var goal: Goal = gate_room.get_node("Goal") as Goal
	_stand("Room4", goal.position + Vector2(goal.goal_size.x / 2.0, goal.goal_size.y))
	await _wait(0.5)
	_check(GameState.is_run_finished, "%s: touching the Goal finishes the run" % level_key)
