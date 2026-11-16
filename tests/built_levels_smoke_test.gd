extends Node
## Headless smoke test for the levels written by tools/build_basics_level.gd,
## tools/build_element_levels.gd, tools/build_air_chapter.gd,
## tools/build_earth_level.gd and tools/build_fire_level.gd. Not part of the game.
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
## Add `-- basics` (or air, earth, fire, water, windward, bedrock, ascent) to run only that level.

const LEVEL_PATHS: Dictionary = {
	"basics": "res://levels/chapter_0_basics_finished.tscn",
	"air": "res://levels/air_the_high_road.tscn",
	"earth": "res://levels/earth_the_deep_dig.tscn",
	"fire": "res://levels/fire_the_ember_wood.tscn",
	"water": "res://levels/water_the_thaw.tscn",
	"windward": "res://levels/chapter_1_air_windward.tscn",
	"bedrock": "res://levels/earth_bedrock.tscn",
	"ascent": "res://levels/fire_burning_ascent.tscn",
}
## Levels still being built stage by stage: their relic may be missing slots.
const UNFINISHED_LEVELS: Array[String] = ["windward", "bedrock", "ascent"]
## How long a pick-up needs to notice the player and settle, s.
const PICKUP_WAIT: float = 1.5
## A Key orb grows, holds and flies to the pack before it counts, s.
const KEY_WAIT: float = 3.5
## Physics frames to let the player settle on the floor after being placed, before
## a simulated jump (a room change takes a few).
const SETTLE_FRAMES: int = 12

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
		if UNFINISHED_LEVELS.has(level_key):
			continue
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


# --- Chapter 1 - Air: The Windward Court (tools/build_air_chapter.gd) --------------

## Stage 1 (Act 1 and the hub): the feather, the Lift's fake wall and its shard,
## the hub's shard, the gate to the sanctum, and a Grand door that is still shut.
func _check_windward() -> void:
	var first: Room = level.get_node("Room1") as Room
	_stand("Room1", (first.get_node("GoldenFeather") as Node2D).position + Vector2(0, 5))
	await _wait(PICKUP_WAIT)
	_check(GameState.is_carrying_golden, "windward: golden feather can be taken")
	# The Lift's fake wall: from the lip in front of it (column 5, row 18), walk left.
	_stand("Room3", Vector2(44, 144))
	await _hold(&"move_left", 1.5)
	_check(level.current_room == level.get_node("RoomSecretLift"),
		"windward: the Lift's fake wall leads into RoomSecretLift")
	var secret: Room = level.get_node("RoomSecretLift") as Room
	await _take_shard("RoomSecretLift", "RelicShard1", (secret.get_node("SpawnPoint") as Marker2D).position)
	var hub: Room = level.get_node("Room7") as Room
	await _take_shard("Room7", "RelicShard4", (hub.get_node("SpawnPoint") as Marker2D).position)
	var twin: DepthGate = (hub.get_node("DepthGate") as DepthGate).find_twin()
	_check(twin != null and Room.find_room_of(twin) == level.get_node("RoomSanctum"),
		"windward: the hub's depth gate leads to the sanctum")
	# No wing is built yet, so no Key orb exists: the lights are dark and the door shut.
	var sanctum: Room = _stand("RoomSanctum", (level.get_node("RoomSanctum/SpawnPoint") as Marker2D).position)
	await _wait(2.0)
	_check((sanctum.get_node("GrandDoor") as Door).switches.size() == 5, "windward: the Grand door waits for five Key lights")
	_check(not (sanctum.get_node("GrandDoor") as Door).wants_open, "windward: the Grand door is shut without the keys")
	await _check_windward_moves()


## Plays Act 1's key moves with simulated key presses, from the edge each one starts
## at, and checks where the player ends up: the rooms' distances were calculated from
## PlayerTuning, this measures them. The player is invincible here, so every check
## also asks for the far FLOOR's height (walking through a spike pit, or out over a void, doesn't count).
func _check_windward_moves() -> void:
	# Room1: jump + glide over the 12-tile pit (columns 13-24, floor row 15).
	_stand("Room1", Vector2(100, 120))
	await _frames(SETTLE_FRAMES)
	await _jump_then(&"move_right", [])
	await _glide(&"move_right", 150)
	_check_landed("Room1", 200.0, 120.0, "windward: a glide crosses Open Air's pit")
	# Room2, first pit: 14 tiles from pillar A (top row 15) to the floor on row 18.
	_stand("Room2", Vector2(60, 120))
	await _frames(SETTLE_FRAMES)
	await _jump_then(&"move_right", [])
	await _glide(&"move_right", 170)
	_check_landed("Room2", 176.0, 144.0, "windward: a glide crosses The Long Drift's first pit")
	# Room2, second pit: 26 tiles from pillar B, through the wind crystal, to row 20.
	_stand("Room2", Vector2(236, 120))
	await _frames(SETTLE_FRAMES)
	await _jump_then(&"move_right", [])
	await _glide(&"move_right", 260)
	_check_landed("Room2", 448.0, 160.0, "windward: the wind crystal carries a glide over the second pit")
	# Room4: jump + down-gust up to the island 8 tiles up (floor row 28, top row 20).
	_stand("Room4", Vector2(60, 224))
	await _frames(SETTLE_FRAMES)
	await _jump_then(&"move_right", [&"move_down"])
	await _hold_frames(&"move_right", 25)
	await _frames(60)
	_check_landed("Room4", 112.0, 160.0, "windward: a down-gust climbs to Second Wind's first island")
	# Room4: jump + down-gust over the 9-tile pit in dead air (columns 21-29).
	_stand("Room4", Vector2(164, 160))
	await _frames(SETTLE_FRAMES)
	await _jump_then(&"move_right", [&"move_down"])
	await _hold_frames(&"move_right", 120)
	_check_landed("Room4", 240.0, 160.0, "windward: a down-gust crosses the dead-air pit")
	# Room5: jump, gust LEFT, glide over the 18-tile pit (columns 8-25).
	_stand("Room5", Vector2(60, 192))
	await _frames(SETTLE_FRAMES)
	await _jump_then(&"move_right", [&"move_left"])
	await _glide(&"move_right", 200)
	_check_landed("Room5", 208.0, 192.0, "windward: gust left + glide crosses Kickback's pit")


## A full-height jump while holding `move_action`; at its top, a gust aimed with
## `aim_actions` (none = no gust). The move key is let go while aiming, so the aim
## is exactly `aim_actions`, and pressed again after.
func _jump_then(move_action: StringName, aim_actions: Array) -> void:
	Input.action_press(move_action)
	Input.action_press(&"jump")
	await _frames(18)
	Input.action_release(&"jump")
	await _frames(2)
	if aim_actions.is_empty():
		return
	Input.action_release(move_action)
	for aim_action: StringName in aim_actions:
		Input.action_press(aim_action)
	await _frames(1)
	Input.action_press(&"gust")
	await _frames(2)
	Input.action_release(&"gust")
	# Letting go of Z fires the gust. Back to the move key at once: a glide has to
	# start DURING the recoil to keep its speed.
	await _frames(3)
	for aim_action: StringName in aim_actions:
		Input.action_release(aim_action)
	Input.action_press(move_action)


## A fresh Jump press in the air, held (the glide), moving with `move_action` for
## `frames` physics frames; then every key is let go.
func _glide(move_action: StringName, frames: int) -> void:
	Input.action_press(move_action)
	Input.action_press(&"jump")
	await _frames(frames)
	Input.action_release(&"jump")
	Input.action_release(move_action)
	await _frames(20)


func _hold_frames(move_action: StringName, frames: int) -> void:
	Input.action_press(move_action)
	await _frames(frames)
	Input.action_release(move_action)
	await _frames(10)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


## The player stands on a floor, past `min_x` and no lower than `floor_y` (px,
## local to the room `room_name`).
func _check_landed(room_name: String, min_x: float, floor_y: float, description: String) -> void:
	var room: Room = level.get_node(room_name) as Room
	var feet: Vector2 = level.player.global_position - room.global_position
	_check(level.player.is_on_floor() and feet.x >= min_x and feet.y <= floor_y + 1.0,
		"%s (feet at %d, %d)" % [description, int(feet.x), int(feet.y)])


# --- Fire - The Burning Ascent (tools/build_fire_level.gd) ---------------------------

## Stage 1 (the run-in, the hub, the sanctum): the feather; each run-in room's
## braziers lit the way the room teaches, and its door opening; the fuse running the
## length of its grass to its brazier; the jet moves the rooms are sized by, played
## with simulated keys; the hub's gate, its shut Grand door, and shard 4.
func _check_ascent() -> void:
	var first: Room = level.get_node("Room1") as Room
	_stand("Room1", (first.get_node("GoldenFeather") as Node2D).position + Vector2(0, 5))
	await _wait(PICKUP_WAIT)
	_check(GameState.is_carrying_golden, "ascent: golden feather can be taken")
	# Kindling: from column 15 a fireball up and right reaches the brazier's shelf.
	_stand("Room1", Vector2(124, 144))
	await _fireball(Vector2.RIGHT, [&"move_up", &"move_right"])
	await _wait(1.5)
	_check((first.get_node("Brazier") as Brazier).is_burning(), "ascent: a fireball up-right lights Kindling's brazier")
	_check((first.get_node("Door") as Door).wants_open, "ascent: Kindling's brazier opens its door")
	await _walk_through_door(first, 232.0, "Room2", "Kindling")
	# Spent, without leaving the room (that would reset it): the low brazier straight
	# ahead from the spawn, then the diamond, then the high one up-right.
	var spent: Room = _stand("Room2", (level.get_node("Room2/SpawnPoint") as Marker2D).position)
	await _fireball(Vector2.RIGHT, [&"move_right"])
	await _wait(1.0)
	_check(level.player.fire_bar.pips == 0, "ascent: Spent's one pip is spent by the first fireball")
	await _move_to(spent, (spent.get_node("FireDiamond") as Node2D).position + Vector2(0, 8))
	await _wait(0.5)
	_check(level.player.fire_bar.pips == 1, "ascent: Spent's diamond gives one more pip")
	await _move_to(spent, Vector2(100, 144))
	await _fireball(Vector2.RIGHT, [&"move_up", &"move_right"])
	await _wait(1.5)
	_check((spent.get_node("BrazierLow") as Brazier).is_burning() and (spent.get_node("BrazierHigh") as Brazier).is_burning(),
		"ascent: both of Spent's braziers lit with its two pips")
	_check((spent.get_node("Door") as Door).wants_open, "ascent: Spent's two braziers open its door")
	await _walk_through_door(spent, 232.0, "Room3", "Spent")
	# The Fuse: the grass lit at its near end burns all the way to the brazier.
	var fuse: Room = _stand("Room3", (level.get_node("Room3/SpawnPoint") as Marker2D).position)
	await _wait(0.5)
	(fuse.get_node("FireGrid") as FireGrid).ignite_at(fuse.global_position + Vector2(52, 144), 4.0, null)
	var waited: float = 0.0
	while waited < 30.0 and not (fuse.get_node("Door") as Door).wants_open:
		await _wait(0.5)
		waited += 0.5
	_check((fuse.get_node("Door") as Door).wants_open, "ascent: the Fuse's grass carries the fire to its brazier (%.1f s)" % waited)
	await _wait(4.0)
	await _walk_through_door(fuse, 376.0, "Room4", "the Fuse")
	# First Burst: jump + a burst right over the 10-tile pit (columns 13-22)...
	await _jet_jump("Room4", Vector2(100, 144), true, &"move_right", [&"move_right"], [], 1)
	_check_landed("Room4", 184.0, 144.0, "ascent: jump + one burst right crosses First Burst's pit")
	# ...then a burst up, over onto the 8-row ledge (columns 31-38, top row 10).
	await _jet_jump("Room4", Vector2(212, 144), true, &"move_right", [&"move_up"], [], 1)
	_check_landed("Room4", 248.0, 80.0, "ascent: jump + a burst up, then right, tops First Burst's ledge")
	# Chain: a burst up from column 12, the chained second one up and right, over
	# onto the ledge (columns 25-38, top row 12).
	await _jet_jump("Room5", Vector2(100, 224), true, &"move_right", [&"move_up"], [&"move_right"], 2)
	_check_landed("Room5", 200.0, 96.0, "ascent: two chained bursts climb Chain's 16 rows")
	# Ash Walk: a burst straight up from standing on the grass by the ledge sets the
	# grass alight, then over onto the ledge (columns 31-38, top row 10).
	var ash: Room = level.get_node("Room6") as Room
	await _jet_jump("Room6", Vector2(236, 144), false, &"move_right", [], [], 1)
	_check((ash.get_node("FireGrid") as FireGrid).is_burning(), "ascent: jetting off Ash Walk's grass sets it burning")
	_check_landed("Room6", 248.0, 80.0, "ascent: a burst up off the grass, then right, tops Ash Walk's ledge")
	# The hub: from the girder on row 9 (column 22) a jump + burst right reaches the
	# Sky of Embers ledge (columns 33-38, top row 7).
	await _jet_jump("Room7", Vector2(186, 72), true, &"move_right", [&"move_right"], [], 1)
	_check_landed("Room7", 264.0, 56.0, "ascent: a jump + burst from the top girders reaches the hub's high ledge")
	var hub: Room = level.get_node("Room7") as Room
	var twin: DepthGate = (hub.get_node("DepthGate") as DepthGate).find_twin()
	_check(twin != null and Room.find_room_of(twin) == level.get_node("RoomSanctum"),
		"ascent: the hub's depth gate leads to the sanctum")
	var sanctum: Room = _stand("RoomSanctum", (level.get_node("RoomSanctum/SpawnPoint") as Marker2D).position)
	await _wait(2.0)
	_check((sanctum.get_node("GrandDoor") as Door).switches.size() == 4, "ascent: the Grand door waits for four Key lights")
	_check(not (sanctum.get_node("GrandDoor") as Door).wants_open, "ascent: the Grand door is shut without the keys")
	# The shard's shelf (columns 8-12, top row 10): from column 19, a jump left
	# (it ends right of the shelf), a burst up, then left onto it.
	await _jet_jump("RoomSanctum", Vector2(156, 152), true, &"move_left", [&"move_up"], [], 1)
	var feet: Vector2 = level.player.global_position - sanctum.global_position
	_check(level.player.is_on_floor() and feet.x >= 64.0 and feet.x <= 104.0 and feet.y <= 81.0,
		"ascent: a burst up reaches the sanctum's shard shelf (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	await _take_shard("RoomSanctum", "RelicShard4", Vector2(84, 152))
	await _check_ascent_wildfire()


## Stage 2, wing 1 Wildfire: the hub's jet to its ledge and the way in; each room's
## fire doing what the room needs (fires are lit straight in the room's FireGrid:
## the aim is the player's, the test checks the room); the jet over the exam's pit;
## shard 2; the red key; the teleport door home lighting the hub's red light.
func _check_ascent_wildfire() -> void:
	# The hub: from the girder on row 30 (column 18), a jump + burst left reaches the
	# Wildfire ledge (columns 1-6, top row 28), and its gap leads into the wing.
	await _jet_jump("Room7", Vector2(136, 240), true, &"move_left", [&"move_left"], [], 1)
	var hub: Room = level.get_node("Room7") as Room
	var feet: Vector2 = level.player.global_position - hub.global_position
	_check(level.player.is_on_floor() and feet.x <= 48.0 and feet.y <= 225.0,
		"ascent: a jump + burst left from the girders reaches the Wildfire ledge (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	_stand("Room7", Vector2(24, 224))
	await _hold(&"move_left", 1.0)
	_check(level.current_room == level.get_node("WildRoom1"), "ascent: the hub's Wildfire gap leads into Dry Grass")
	# Dry Grass: the floor fire climbs the mound and lights the brazier in its shrine.
	var dry: Room = _stand("WildRoom1", (level.get_node("WildRoom1/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	(dry.get_node("FireGrid") as FireGrid).ignite_at(dry.global_position + Vector2(28 * 8 + 4, 144), 4.0, null)
	var door_opened: bool = await _wait_for_door(dry.get_node("Door") as Door, 30.0)
	_check(door_opened, "ascent: Dry Grass's fire climbs the mound and lights the shrine's brazier")
	await _wait(6.0)
	await _jet_jump_keep_room(dry, Vector2(232, 144), &"move_left", [&"move_up"])
	feet = level.player.global_position - dry.global_position
	# On the shrine's roof (columns 17-22, top row 9) or past the mound: either way over.
	var on_roof: bool = feet.x >= 136.0 and feet.x < 184.0 and feet.y <= 73.0
	_check(level.player.is_on_floor() and (on_roof or (feet.x < 136.0 and feet.y <= 145.0)),
		"ascent: a jump + burst up, then left, gets over Dry Grass's mound (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	await _hold(&"move_left", 2.0)
	_check(level.current_room == level.get_node("WildRoom2"), "ascent: Dry Grass's door leads on to Undergrowth")
	# Undergrowth: the thicket wall, then the floor patch, burn away; you drop through.
	var under: Room = _stand("WildRoom2", (level.get_node("WildRoom2/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	var under_grid: FireGrid = under.get_node("FireGrid") as FireGrid
	under_grid.ignite_at(under.global_position + Vector2(23 * 8, 12 * 8 + 4), 4.0, null)
	await _wait(6.0)
	var thicket: TileMapLayer = under.get_node("Thicket") as TileMapLayer
	_check(thicket.get_cell_source_id(Vector2i(23, 5)) == -1, "ascent: Undergrowth's thicket wall burns away")
	under_grid.ignite_at(under.global_position + Vector2(6 * 8, 13 * 8 + 2), 4.0, null)
	await _wait(5.0)
	_check(thicket.get_cell_source_id(Vector2i(6, 13)) == -1, "ascent: Undergrowth's thicket floor burns away")
	await _move_to(under, Vector2(56, 100))
	await _wait(1.0)
	feet = level.player.global_position - under.global_position
	_check(feet.y > 150.0, "ascent: through the burnt floor down to Undergrowth's lower corridor (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	await _hold(&"move_left", 1.5)
	_check(level.current_room == level.get_node("WildRoom3"), "ascent: Undergrowth's lower corridor leads on to Overgrown")
	# Overgrown: the left wall's cover flashes away; the floor cover opens shard 2.
	var over: Room = _stand("WildRoom3", (level.get_node("WildRoom3/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	var over_grid: FireGrid = over.get_node("FireGrid") as FireGrid
	over_grid.ignite_at(over.global_position + Vector2(5 * 8 + 4, 15 * 8), 4.0, null)
	await _wait(2.0)
	var covers: TileMapLayer = over.get_node("Overgrown") as TileMapLayer
	_check(covers.get_cell_source_id(Vector2i(2, 15)) == -1, "ascent: Overgrown's wall cover burns away")
	over_grid.ignite_at(over.global_position + Vector2(21 * 8, 18 * 8 + 2), 4.0, null)
	await _wait(2.0)
	_check(covers.get_cell_source_id(Vector2i(21, 18)) == -1, "ascent: Overgrown's floor cover burns away")
	await _take_shard("WildRoom3", "RelicShard2", Vector2(172, 168))
	_stand("WildRoom3", Vector2(60, 144))
	await _hold(&"move_left", 1.5)
	_check(level.current_room == level.get_node("WildRoom4"), "ascent: Overgrown's burnt cover leads on to Wildfire")
	# Wildfire: the wall, the jet over the pit, the floor patch, the cover, the key.
	var exam: Room = _stand("WildRoom4", (level.get_node("WildRoom4/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	var exam_grid: FireGrid = exam.get_node("FireGrid") as FireGrid
	exam_grid.ignite_at(exam.global_position + Vector2(57 * 8, 12 * 8 + 4), 4.0, null)
	await _wait(8.0)
	_check((exam.get_node("Thicket") as TileMapLayer).get_cell_source_id(Vector2i(57, 5)) == -1,
		"ascent: Wildfire's thicket wall burns away")
	await _jet_jump_keep_room(exam, Vector2(412, 104), &"move_left", [&"move_left"])
	feet = level.player.global_position - exam.global_position
	_check(level.player.is_on_floor() and feet.x >= 232.0 and feet.x <= 304.0 and feet.y <= 105.0,
		"ascent: a jump + burst left crosses Wildfire's spike pit (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	exam_grid.ignite_at(exam.global_position + Vector2(26 * 8, 13 * 8 + 2), 4.0, null)
	await _wait(5.0)
	await _move_to(exam, Vector2(212, 100))
	await _wait(1.0)
	feet = level.player.global_position - exam.global_position
	_check(feet.y > 150.0, "ascent: through Wildfire's burnt floor to the lower level (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	exam_grid.ignite_at(exam.global_position + Vector2(14 * 8 + 4, 17 * 8), 4.0, null)
	await _wait(2.0)
	_check((exam.get_node("Overgrown") as TileMapLayer).get_cell_source_id(Vector2i(13, 17)) == -1,
		"ascent: Wildfire's cover burns away")
	await _take_key("WildRoom4", "KeyOrb")
	var door: TeleportDoor = exam.get_node("WayHome") as TeleportDoor
	_stand("WildRoom4", door.position + Vector2(8, 24))
	await _frames(SETTLE_FRAMES)
	await _hold(&"move_up", 0.3)
	await _wait(1.0)
	_check(level.current_room == hub, "ascent: Wildfire's teleport door goes home to the hub")
	await _wait(3.0)
	_check((hub.get_node("KeyLight1") as KeyLight).is_on(), "ascent: the red key lights the hub's red light")
	await _check_ascent_ropes()


## Stage 3, wing 2 Ropes and Weights: the hub's jet to its ledge and the way in;
## each room's vines burnt (straight on the vine; in Lowered a real fireball at the vine-grown
## plank) and the room then CROSSED on foot (a fall is a pit: the player comes back
## at the spawn, still in that room, and the check fails); shard 3 from the fallen
## crate; the orange key and the door home.
func _check_ascent_ropes() -> void:
	# The hub: from the girder on row 27 (column 22) a jump + burst right reaches the
	# Ropes and Weights ledge (columns 33-38, top row 25), and its gap leads on.
	await _jet_jump("Room7", Vector2(186, 216), true, &"move_right", [&"move_right"], [], 1)
	var hub: Room = level.get_node("Room7") as Room
	var feet: Vector2 = level.player.global_position - hub.global_position
	_check(level.player.is_on_floor() and feet.x >= 264.0 and feet.y <= 201.0,
		"ascent: a jump + burst right from the girders reaches the Ropes ledge (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	_stand("Room7", Vector2(300, 200))
	await _hold(&"move_right", 1.0)
	_check(level.current_room == level.get_node("RopeRoom1"), "ascent: the hub's Ropes gap leads into Drawbridge")
	# Drawbridge: the vine burns, the plank falls across, the gap is walked over.
	var bridge_room: Room = _stand("RopeRoom1", (level.get_node("RopeRoom1/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	_burn_vine(bridge_room, "DrawbridgeVine")
	await _wait(3.0)
	await _hold(&"move_right", 4.0)
	_check(level.current_room == level.get_node("RopeRoom2"), "ascent: Drawbridge's fallen plank carries you over the gap")
	# Dead Weight: the vine burns, the metal crate drops on the plate, the door opens;
	# a jet over the gap; from the crate's top a jump reaches shard 3's ledge.
	var weight_room: Room = _stand("RopeRoom2", (level.get_node("RopeRoom2/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	_burn_vine(weight_room, "WeightVine")
	await _wait(2.5)
	_check((weight_room.get_node("Door") as Door).wants_open, "ascent: Dead Weight's crate, cut down, holds its door open")
	_check(not (weight_room.get_node("Weight") as Crate).is_burning(), "ascent: Dead Weight's metal crate didn't catch fire from its vine")
	await _jet_jump_keep_room(weight_room, Vector2(72, 104), &"move_right", [&"move_right"])
	feet = level.player.global_position - weight_room.global_position
	_check(level.player.is_on_floor() and feet.x >= 152.0 and feet.y <= 105.0,
		"ascent: a jump + burst crosses Dead Weight's gap (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	var crate: Node2D = weight_room.get_node("Weight") as Node2D
	await _move_to(weight_room, crate.position + Vector2(0, -17))
	await _jump_holding(&"move_right", 18)
	feet = level.player.global_position - weight_room.global_position
	_check(level.player.is_on_floor() and feet.y <= 73.0,
		"ascent: a jump from the fallen crate reaches shard 3's ledge (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	await _move_to(weight_room, Vector2(212, 104))
	await _jump_holding(&"move_right", 10)
	feet = level.player.global_position - weight_room.global_position
	_check(feet.y > 73.0, "ascent: shard 3's ledge is out of reach of a jump from the floor (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	await _move_to(weight_room, Vector2(244, 72))
	await _wait(PICKUP_WAIT)
	_check(GameState.has_shard(RelicShard.Element.FIRE, 3), "ascent: shard 3 secured on its ledge")
	await _walk_through_door(weight_room, 236.0, "RopeRoom3", "Dead Weight", 104.0)
	# Lowered: a real fireball at the vine-grown plank drops it level across the gap.
	var lowered_room: Room = _stand("RopeRoom3", (level.get_node("RopeRoom3/SpawnPoint") as Marker2D).position)
	await _move_to(lowered_room, Vector2(80, 104))
	await _fireball(Vector2.RIGHT, [&"move_up", &"move_right"])
	await _wait(3.0)
	await _hold(&"move_right", 4.0)
	_check(level.current_room == level.get_node("RopeRoom4"), "ascent: Lowered's plank, burnt free, bridges its gap")
	# Counterweights: all three, then across, the key and the way home.
	var exam: Room = _stand("RopeRoom4", (level.get_node("RopeRoom4/SpawnPoint") as Marker2D).position)
	await _wait(0.3)
	_burn_vine(exam, "DrawbridgeVine")
	_burn_vine(exam, "WeightVine")
	(exam.get_node("Bridge") as HangingPlatform).ignite(null)
	await _wait(3.5)
	_check((exam.get_node("Door") as Door).wants_open, "ascent: Counterweights' crate holds its door open")
	await _walk_hopping(&"move_right", 7.0)
	feet = level.player.global_position - exam.global_position
	_check(level.current_room == exam and level.player.is_on_floor() and feet.x >= 376.0 and feet.y <= 105.0,
		"ascent: Counterweights is crossed on foot, over both bridges and through the door (feet at %d, %d)" % [int(feet.x), int(feet.y)])
	await _take_key("RopeRoom4", "KeyOrb")
	var door: TeleportDoor = exam.get_node("WayHome") as TeleportDoor
	_stand("RopeRoom4", door.position + Vector2(8, 24))
	await _frames(SETTLE_FRAMES)
	await _hold(&"move_up", 0.3)
	await _wait(1.0)
	_check(level.current_room == hub, "ascent: Counterweights' teleport door goes home to the hub")
	await _wait(3.0)
	_check((hub.get_node("KeyLight2") as KeyLight).is_on(), "ascent: the orange key lights the hub's orange light")


## Holds `move_action` for `seconds`, tapping Jump every half second: small hops,
## the way a player walks over a crate or up a one-tile step.
func _walk_hopping(move_action: StringName, seconds: float) -> void:
	Input.action_press(move_action)
	var elapsed: float = 0.0
	while elapsed < seconds:
		Input.action_press(&"jump")
		await _frames(4)
		Input.action_release(&"jump")
		await _wait(0.45)
		elapsed += 0.5
	Input.action_release(move_action)
	await _frames(10)


## Lights the vine `vine_name` of `room` halfway down its length (as a fireball there would).
func _burn_vine(room: Room, vine_name: String) -> void:
	var vine: Vine = room.get_node(vine_name) as Vine
	vine.ignite_at(vine.global_position + vine.end_point / 2.0, 4.0, null)


## A full-height jump (Jump held 18 frames) from where the player stands, with
## `move_action` held only for the first `frames` physics frames (a short hop
## sideways), then until a floor.
func _jump_holding(move_action: StringName, frames: int) -> void:
	Input.action_press(move_action)
	Input.action_press(&"jump")
	for index: int in 18:
		if index == frames:
			Input.action_release(move_action)
		await get_tree().physics_frame
	Input.action_release(&"jump")
	Input.action_release(move_action)
	var waited: int = 0
	while waited < 120 and not level.player.is_on_floor():
		await get_tree().physics_frame
		waited += 1
	await _frames(10)


## From the floor (row 18, or `floor_y` px) at `start_x` px, left of `room`'s door, walks right
## through the open door, without a respawn (that would shut it again), and
## checks the player came out in `next_room_name`.
func _walk_through_door(room: Room, start_x: float, next_room_name: String, room_label: String,
		floor_y: float = 144.0) -> void:
	await _move_to(room, Vector2(start_x, floor_y))
	await _hold(&"move_right", 1.5)
	_check(level.current_room == level.get_node(next_room_name),
		"ascent: %s's open door can be walked through" % room_label)


## Waits until `door` wants open, at most `seconds`. True if it did.
func _wait_for_door(door: Door, seconds: float) -> bool:
	var waited: float = 0.0
	while waited < seconds and not door.wants_open:
		await _wait(0.5)
		waited += 0.5
	return door.wants_open


## Like _jet_jump with one burst, but without a respawn (which would reset `room`:
## its burnt grass and thicket, its lit braziers): moves to `local_px`, gives one
## pip, a running jump holding `run_action`, a burst steered with `aim`, then
## `run_action` until a floor.
func _jet_jump_keep_room(room: Room, local_px: Vector2, run_action: StringName, aim: Array) -> void:
	await _move_to(room, local_px)
	level.player.facing_direction = 1.0 if run_action == &"move_right" else -1.0
	level.player.fire_bar.gain(1)
	Input.action_press(run_action)
	Input.action_press(&"jump")
	await _frames(18)
	Input.action_release(&"jump")
	Input.action_release(run_action)
	for action: StringName in aim:
		Input.action_press(action)
	Input.parse_input_event(_action_event(&"flame_jet", true))
	await _frames(3)
	Input.parse_input_event(_action_event(&"flame_jet", false))
	# Keep steering for the rest of the 30-frame burst.
	await _frames(30)
	for action: StringName in aim:
		Input.action_release(action)
	Input.action_press(run_action)
	var frames: int = 0
	while frames < 300:
		await get_tree().physics_frame
		frames += 1
		if frames > 4 and level.player.is_on_floor():
			break
	Input.action_release(run_action)
	await _frames(10)


## Moves the player's feet to `local_px` of `room` WITHOUT a respawn (which would
## reset the room: lit braziers, taken diamonds), and lets it settle.
func _move_to(room: Room, local_px: Vector2) -> void:
	level.player.global_position = room.global_position + local_px
	level.player.velocity = Vector2.ZERO
	await _frames(SETTLE_FRAMES)


## Throws a fireball from where the player stands, facing `facing`, holding `aim`
## first: a tap of Q throws at once in the arrows' direction.
func _fireball(facing: Vector2, aim: Array) -> void:
	level.player.facing_direction = facing.x
	await _frames(SETTLE_FRAMES)
	for action: StringName in aim:
		Input.action_press(action)
	# The arrows are read on the frame Q is pressed: hold them a frame before.
	await _frames(1)
	await _press(&"fireball")
	# A tap goes through the aim state for a frame or two before the throw.
	await _frames(4)
	for action: StringName in aim:
		Input.action_release(action)


## From `feet_px` of `room_name`, with the ROOM'S OWN pips (the spawn resets them to
## its Fire Start Pips, so the test checks the room's budget): with `jump`, a running jump (holding
## `run_action`) to its top; then `bursts` jet bursts (W held to chain) steered with
## `aim`, plus `late_aim` from the second burst on, and no other key; then
## `run_action` held until back on a floor.
func _jet_jump(room_name: String, feet_px: Vector2, jump: bool, run_action: StringName, aim: Array, late_aim: Array,
		bursts: int) -> void:
	_stand(room_name, feet_px)
	level.player.facing_direction = 1.0 if run_action == &"move_right" else -1.0
	await _frames(SETTLE_FRAMES)
	if jump:
		Input.action_press(run_action)
		Input.action_press(&"jump")
		await _frames(18)
		Input.action_release(&"jump")
		Input.action_release(run_action)
	for action: StringName in aim:
		Input.action_press(action)
	# W as an event, not action_press: the jet reads it as a fresh press
	# (is_action_just_pressed), like a real key, and its release ends a chain.
	Input.parse_input_event(_action_event(&"flame_jet", true))
	# A burst is 0.5 s (30 frames); W held past its end chains the next. The last
	# burst's W is let go a few frames early, so it doesn't chain one more.
	for index: int in 30 * bursts - 4:
		await get_tree().physics_frame
		# One burst: let go at once (a quick tap of W is still a whole burst).
		if index == 2 and bursts == 1:
			Input.parse_input_event(_action_event(&"flame_jet", false))
		if index == 30:
			for action: StringName in late_aim:
				Input.action_press(action)
	Input.parse_input_event(_action_event(&"flame_jet", false))
	await _frames(6)
	for action: StringName in aim + late_aim:
		Input.action_release(action)
	Input.action_press(run_action)
	var frames: int = 0
	# Until back on a floor (at most 5 s); the first frames may still see the floor
	# a standing jet took off from.
	while frames < 300:
		await get_tree().physics_frame
		frames += 1
		if frames > 4 and level.player.is_on_floor():
			break
	Input.action_release(run_action)
	await _frames(10)


# --- Earth - Bedrock (tools/build_earth_level.gd) ------------------------------------

## Stage 1 (Act 1, the hub, the Heart stub): the feather, the fake wall in Topsoil's
## ridge and its shard, the hub's shard, a Grand door that is still shut, the Goal,
## and the super jumps the rooms are sized by.
func _check_bedrock() -> void:
	var first: Room = level.get_node("Room1") as Room
	_stand("Room1", (first.get_node("GoldenFeather") as Node2D).position + Vector2(0, 5))
	await _wait(PICKUP_WAIT)
	_check(GameState.is_carrying_golden, "bedrock: golden feather can be taken")
	# The fake wall: from the floor right of the ridge (column 34, row 24), walk left
	# into the chamber and onto the shard.
	_stand("Room1", Vector2(276, 192))
	await _hold(&"move_left", 0.8)
	var shard: RelicShard = first.get_node("RelicShard1") as RelicShard
	await _wait(0.3)
	_check(shard.global_position.distance_to(level.player.get_center()) < 24.0,
		"bedrock: walking left into Topsoil's ridge reaches the shard behind the fake wall")
	await _take_shard("Room1", "RelicShard1", Vector2(276, 192))
	await _take_shard("Room7", "RelicShard4", (level.get_node("Room7/SpawnPoint") as Marker2D).position)
	var hub: Room = _stand("Room7", (level.get_node("Room7/SpawnPoint") as Marker2D).position)
	await _wait(2.0)
	var door: Door = hub.get_node("GrandDoor") as Door
	_check(door.switches.size() == 4, "bedrock: the Grand door waits for four Key lights")
	_check(not door.wants_open, "bedrock: the Grand door is shut without the keys")
	await _check_bedrock_moves()
	await _check_bedrock_burrows()
	var heart: Room = level.get_node("RoomHeart") as Room
	var goal: Goal = heart.get_node("Goal") as Goal
	_stand("RoomHeart", goal.position + Vector2(goal.goal_size.x / 2.0, goal.goal_size.y))
	await _wait(0.5)
	_check(GameState.is_run_finished, "bedrock: touching the Goal finishes the run")


## The super jumps of Act 1 and the hub, played with simulated key presses: tap A
## on the earth tile, hold right, and check where the player ends up.
func _check_bedrock_moves() -> void:
	# Room1: from the patch (column 21, row 24) onto the ridge (top row 17).
	await _super_jump("Room1", Vector2(172, 192), 50)
	_check_landed("Room1", 176.0, 136.0, "bedrock: a super jump tops Topsoil's ridge")
	# Room2: tower A's tile (column 16, row 30) onto tower A (row 23)...
	await _super_jump("Room2", Vector2(132, 240), 30)
	_check_landed("Room2", 136.0, 184.0, "bedrock: a super jump tops the Sinkhole's first tower")
	# ...then tower B's tile (column 23, row 23) onto tower B (row 16).
	await _super_jump("Room2", Vector2(188, 184), 40)
	_check_landed("Room2", 192.0, 128.0, "bedrock: a super jump tops the Sinkhole's second tower")
	# Room7: up the chimney (columns 63-65) and right into the pocket (floor row 10).
	await _super_jump("Room7", Vector2(516, 136), 60)
	_check_landed("Room7", 528.0, 80.0, "bedrock: a super jump up the hub's chimney reaches the pocket")


## Wing 1, The Burrows: the hub's shaft drops into it, a big rock dug in Dig Here
## drops you on down to Down the Shaft, the covered walls of Peeking and the Warren
## can be walked through, the Warren's shard and Key orb can be taken, its door
## goes home to the hub, and the key lights the hub's two ochre lights.
func _check_bedrock_burrows() -> void:
	# The shaft: stand over the hub's first mouth (columns 12-15) and fall.
	_stand("Room7", Vector2(108, 120))
	await _wait(2.0)
	_check(level.current_room == level.get_node("RoomB1"), "bedrock: the hub's first shaft drops into Dig Here")
	# The dig: on the earth's left end (column 14, row 12) facing right, hold S for
	# a big rock, throw it, walk right into the hole.
	_stand("RoomB1", Vector2(116, 96))
	level.player.facing_direction = 1.0
	await _frames(SETTLE_FRAMES)
	Input.parse_input_event(_action_event(&"earth_boulder", true))
	await _wait(0.6)
	Input.parse_input_event(_action_event(&"earth_boulder", false))
	await _wait(0.3)
	await _press(&"earth_boulder")
	await _wait(0.5)
	Input.action_press(&"move_right")
	await _wait(2.5)
	Input.action_release(&"move_right")
	_check(level.current_room == level.get_node("RoomB2"),
		"bedrock: a big rock dug in Dig Here opens the way down to Down the Shaft (now in %s)" % level.current_room.name)
	# Peeking: from corridor 1 (column 27, row 12) walk left through the covered wall.
	_stand("RoomB3", Vector2(220, 96))
	await _hold(&"move_left", 1.2)
	var peeking: Room = level.get_node("RoomB3") as Room
	_check(level.player.global_position.x - peeking.global_position.x < 21 * 8,
		"bedrock: Peeking's covered wall can be walked through")
	# The Warren: from cave C's right part (column 23, row 32) walk left through it.
	_stand("RoomB4", Vector2(188, 256))
	await _hold(&"move_left", 1.2)
	var warren: Room = level.get_node("RoomB4") as Room
	_check(level.player.global_position.x - warren.global_position.x < 18 * 8,
		"bedrock: the Warren's covered wall can be walked through")
	await _take_shard("RoomB4", "RelicShard2", Vector2(92, 104))
	await _take_key("RoomB4", "KeyOrb")
	# Home: Up in the teleport door comes out by the hub's first shaft.
	var door: TeleportDoor = warren.get_node("WayHome") as TeleportDoor
	_stand("RoomB4", door.position + Vector2(8, 24))
	await _frames(SETTLE_FRAMES)
	await _hold(&"move_up", 0.3)
	await _wait(1.0)
	var hub: Room = level.get_node("Room7") as Room
	_check(level.current_room == hub, "bedrock: the Warren's door goes home to the hub")
	await _wait(3.0)
	_check((hub.get_node("ShaftLight1") as KeyLight).is_on() and (hub.get_node("KeyLight1") as KeyLight).is_on(),
		"bedrock: the ochre key lights both of the hub's ochre lights")
	_check(not (hub.get_node("GrandDoor") as Door).wants_open, "bedrock: one key of four leaves the Grand door shut")


## A tap of `action`: pressed for two physics frames.
func _press(action: StringName) -> void:
	Input.parse_input_event(_action_event(action, true))
	await _frames(2)
	Input.parse_input_event(_action_event(action, false))
	await _frames(1)


## Stands the player on `feet_px` of `room_name`, taps A (a pillar under the feet:
## the super jump), then holds right for `right_frames` physics frames.
func _super_jump(room_name: String, feet_px: Vector2, right_frames: int) -> void:
	_stand(room_name, feet_px)
	level.player.facing_direction = 1.0
	await _frames(SETTLE_FRAMES)
	Input.parse_input_event(_action_event(&"earth_column", true))
	await _frames(2)
	Input.parse_input_event(_action_event(&"earth_column", false))
	await _hold_frames(&"move_right", right_frames)
	await _frames(40)


func _action_event(action: StringName, pressed: bool) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event
