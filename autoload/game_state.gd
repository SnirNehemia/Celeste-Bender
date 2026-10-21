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
	deaths_changed.emit(death_count)


## Elapsed time as "m:ss.cc", e.g. "1:07.43".
func get_formatted_time() -> String:
	var minutes: int = int(elapsed_time / 60.0)
	var seconds: float = fmod(elapsed_time, 60.0)
	return "%d:%05.2f" % [minutes, seconds]
