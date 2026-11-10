extends Node
## GameState: global run data — death count, elapsed time, current room.
##
## This script is an AUTOLOAD (registered in project.godot under [autoload]).
## Godot creates one instance of it when the game starts, keeps it alive across
## scene changes, and makes it reachable from any script by its name: `GameState`.
## It's Godot's version of a global singleton.
##
## Who writes here: RoomManager (deaths, current room), Goal (finish_run). Who
## reads: the debug overlay and the EndScreen.
## No class_name on purpose: the autoload name `GameState` is already global,
## and a class_name with the same name would clash.

## Emitted whenever the death count changes, so UI can update without polling.
signal deaths_changed(new_death_count: int)
## Emitted once when the player reaches the Goal at the end of the last room.
signal run_finished
## Emitted when current_room changes to a different room (the first room at startup,
## every room slide, the F2 room picker). The fire bar listens to it: pips are per room.
signal room_entered(room: Room)

## Total deaths this run (R / restart counts too, like Celeste's "Retry").
var death_count: int = 0
## Seconds since the run started. Keeps counting during deaths and room slides.
var elapsed_time: float = 0.0
## Emitted once per key color, the moment a KeyOrb of that color is touched.
## KeyLights listen to it (they may be in another room). `key_color` is a KeyColors.Name.
signal key_collected(key_color: int)

## The key colors collected this run (KeyColors.Name -> true). NOT touched by deaths
## or R (Room.reset_objects never reaches it): a key, once in the bag, stays there
## until the run starts over (reset_run: a new level, a new play-test).
var collected_keys: Dictionary = {}

## Emitted when a relic shard is SECURED (Collectibles.md §2): its relic's
## `element` (RelicShard.Element) and its quarter, `slot` 1..4.
signal shard_secured(element: int, slot: int)

## Relic shards secured this run. Every ELEMENT has its own relic of four quarters,
## so a shard is an (element, slot) pair: element (RelicShard.Element) -> Array of
## its secured slots (1..4).
## Like the keys, deaths and R don't touch it; reset_run() clears it.
var secured_shards: Dictionary = {}
## Golden feather (Collectibles.md §3): true while the player carries it.
var is_carrying_golden: bool = false
## True once a feather broke this run (a death while carrying it): gone until a new run.
var is_golden_broken: bool = false

## The room the player is currently in. Its spawn point is the respawn checkpoint.
## A SETTER (the `set(value):` block) runs every time someone assigns the variable,
## so RoomManager just writes `GameState.current_room = room` and the signal follows.
var current_room: Room = null:
	set(value):
		var is_new_room: bool = value != current_room
		current_room = value
		if is_new_room and value != null:
			room_entered.emit(value)
## True after the Goal is reached: the timer stops and R no longer restarts.
var is_run_finished: bool = false
## True while Story Mode plays its levels (Level_editor.md §9). Then the Goal's
## run_finished belongs to StoryPlayer (level-complete card, next level), and the
## EndScreen stays hidden. StoryPlayer sets it; the main menu clears it.
var is_story_run: bool = false


func _process(delta: float) -> void:
	if not is_run_finished:
		elapsed_time += delta


func register_death() -> void:
	death_count += 1
	deaths_changed.emit(death_count)


## Ends the run (called by Goal): freezes the time, then tells the end screen.
func finish_run() -> void:
	if is_run_finished:
		return
	is_run_finished = true
	run_finished.emit()


## Clears the run for a new attempt (EndScreen calls it before reloading the world).
func reset_run() -> void:
	death_count = 0
	elapsed_time = 0.0
	current_room = null
	is_run_finished = false
	collected_keys.clear()
	secured_shards.clear()
	is_carrying_golden = false
	is_golden_broken = false
	deaths_changed.emit(death_count)


## Shard `slot` (1..4) of `element`'s relic is counted for this run. Only the
## first time emits.
func secure_shard(element: int, slot: int) -> void:
	if has_shard(element, slot):
		return
	if not secured_shards.has(element):
		secured_shards[element] = []
	(secured_shards[element] as Array).append(slot)
	shard_secured.emit(element, slot)


## True if shard `slot` of `element`'s relic was secured this run.
func has_shard(element: int, slot: int) -> bool:
	return secured_shards.has(element) and (secured_shards[element] as Array).has(slot)


## How many shards were secured this run, all relics together.
func count_shards() -> int:
	var total: int = 0
	for element: int in secured_shards:
		total += (secured_shards[element] as Array).size()
	return total


## True if a key of `key_color` (a KeyColors.Name) was collected this run.
func has_key(key_color: int) -> bool:
	return collected_keys.has(key_color)


## Puts a key in the bag (KeyOrb calls it on touch). Only the first time emits.
func collect_key(key_color: int) -> void:
	if collected_keys.has(key_color):
		return
	collected_keys[key_color] = true
	key_collected.emit(key_color)


## Elapsed time as "m:ss.cc", e.g. "1:07.43".
func get_formatted_time() -> String:
	var minutes: int = int(elapsed_time / 60.0)
	var seconds: float = fmod(elapsed_time, 60.0)
	return "%d:%05.2f" % [minutes, seconds]
