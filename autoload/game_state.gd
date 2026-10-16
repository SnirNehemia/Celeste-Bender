extends Node
## GameState: global run data — death count, elapsed time, current room.
##
## This script is an AUTOLOAD (registered in project.godot under [autoload]).
## Godot creates one instance of it when the game starts, keeps it alive across
## scene changes, and makes it reachable from any script by its name: `GameState`.
## It's Godot's version of a global singleton.
##
## Who writes here: RoomManager (deaths, current room). Who reads: the debug
## overlay now, the HUD and end screen later (Stage 9).
## No class_name on purpose: the autoload name `GameState` is already global,
## and a class_name with the same name would clash.

## Emitted whenever the death count changes, so UI can update without polling.
signal deaths_changed(new_death_count: int)

## Total deaths this run (R / restart counts too, like Celeste's "Retry").
var death_count: int = 0
## Seconds since the run started. Keeps counting during deaths and room slides.
var elapsed_time: float = 0.0
## The room the player is currently in. Its spawn point is the respawn checkpoint.
var current_room: Room = null


func _process(delta: float) -> void:
	elapsed_time += delta


func register_death() -> void:
	death_count += 1
	deaths_changed.emit(death_count)


## Clears the run (for a future "new game"; not used yet).
func reset_run() -> void:
	death_count = 0
	elapsed_time = 0.0
	current_room = null
	deaths_changed.emit(death_count)


## Elapsed time as "m:ss.cc", e.g. "1:07.43".
func get_formatted_time() -> String:
	var minutes: int = int(elapsed_time / 60.0)
	var seconds: float = fmod(elapsed_time, 60.0)
	return "%d:%05.2f" % [minutes, seconds]
