class_name PlayerStateMachine
extends Node
## Holds the player's states (its children) and runs whichever one is active.
##
## Scene layout:  Player > StateMachine > Idle / Run / Jump / Fall / WallSlide / Dead
## Player._ready() calls setup(), and Player._physics_process() calls physics_update().

## The state we start in. Assigned in the Inspector (drag the Idle node here).
@export var initial_state: PlayerState

## The currently active state.
var current_state: PlayerState


## Gives every child state a reference to the player and listens for their
## transition requests, then enters the initial state.
func setup(owner_player: Player) -> void:
	for child: Node in get_children():
		var state: PlayerState = child as PlayerState
		if state == null:
			continue
		state.player = owner_player
		state.transition_requested.connect(_on_transition_requested)
	current_state = initial_state
	current_state.enter()


## Forwards the physics tick to the active state.
func physics_update(delta: float) -> void:
	current_state.physics_update(delta)


## States ask for transitions through their signal; this just forwards it.
func _on_transition_requested(target_state_name: StringName) -> void:
	transition_to(target_state_name)


## Swaps the active state for the child node with the requested name.
## Public so the player can force a state from outside the states (die / respawn).
func transition_to(target_state_name: StringName) -> void:
	var next_state: PlayerState = get_node_or_null(NodePath(target_state_name)) as PlayerState
	if next_state == null:
		push_error("[StateMachine] No state named '%s'" % target_state_name)
		return
	current_state.exit()
	current_state = next_state
	current_state.enter()
