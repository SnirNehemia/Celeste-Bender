class_name PlayerState
extends Node
## Base class for every player state (Idle, Run, Jump, Fall, ...).
##
## A state is a Node that lives as a child of the player's StateMachine node.
## The StateMachine calls enter() when we switch into the state, physics_update()
## every physics frame while it is active, and exit() when we leave.
##
## States never move the body themselves; they only set `player.velocity`.
## Player._physics_process calls move_and_slide() once afterwards.
##
## To change state, a state emits `transition_requested` with the NAME of the
## target state node (e.g. &"Fall"). The StateMachine listens to that signal.
## A signal is Godot's way for one node to announce "something happened" without
## knowing who is listening, which keeps states decoupled from the machine.

## Emitted by a state to ask the state machine to switch to another state.
## Only subclasses emit it, so silence Godot's "declared but never used" warning here.
@warning_ignore("unused_signal")
signal transition_requested(target_state_name: StringName)

## Set by PlayerStateMachine.setup() so every state can reach the player.
var player: Player


## Called once when this state becomes active.
func enter() -> void:
	pass


## Called once when this state stops being active.
func exit() -> void:
	pass


## Called every physics frame while active. `delta` is the frame time in seconds.
func physics_update(_delta: float) -> void:
	pass
