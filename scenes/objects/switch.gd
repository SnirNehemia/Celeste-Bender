@tool
class_name Switch
extends Node2D
## Base class for anything that can open a door: pressure plates, windmills, and
## later anything else (levers, enemy-defeated triggers...).
##
## A switch is simply ON or OFF. When that changes it emits `switched`. It never
## knows what it is wired to: doors pick their switches in the Inspector
## (Door.switches) and connect to this signal themselves. That keeps the wiring in
## the level, not in the code, and lets one switch drive several doors.
##
## Subclasses decide WHEN to be on (PressurePlate: while a crate sits on it;
## Windmill: while it spins) and just call set_on().
##
## @tool because every subclass draws itself in the editor.

## Emitted whenever the switch turns on or off. `is_now_on` is the new state.
## A signal is Godot's observer pattern: other nodes connect a function to it, and
## emit() calls all of them. The emitter doesn't need to know who's listening.
signal switched(is_now_on: bool)

## Current state. Private (leading _): change it only through set_on(), so the
## signal can never be skipped.
var _is_on: bool = false


func is_on() -> bool:
	return _is_on


## Sets the state; emits `switched` only if it actually changed (so listeners
## aren't spammed every frame by switches that re-check themselves each frame).
func set_on(new_state: bool) -> void:
	if new_state == _is_on:
		return
	_is_on = new_state
	switched.emit(_is_on)
	queue_redraw()  # every switch looks different when on
