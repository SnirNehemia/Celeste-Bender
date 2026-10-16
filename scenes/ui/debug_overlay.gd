class_name DebugOverlay
extends CanvasLayer
## On-screen debug readout for tuning movement: current state, velocity, the
## forgiveness timers, and GameState (deaths, time, current room). Toggle it with the `debug_toggle` action (F1).
##
## A CanvasLayer draws its children on a separate layer that ignores the game camera,
## so the text stays fixed in the corner of the screen (useful once rooms scroll).
##
## Usage: instance debug_overlay.tscn in a room and drag the Player node onto the
## `player` field in the Inspector. The overlay only READS from the player; it never
## changes anything, so it can be removed without breaking the game.

## The player to display. Set in the Inspector (an exported node reference
## instead of a hard-coded path like get_node("../Player")).
@export var player: Player

@onready var readout_label: Label = $ReadoutLabel


## _unhandled_input receives key presses that no UI element consumed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible


## _process runs once per rendered frame (vs _physics_process at a fixed 60/s).
## Fine for display code that doesn't affect gameplay.
func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	var state_name: String = String(player.state_machine.current_state.name)
	# GameState is the autoload: reachable by name from any script.
	var room_name: String = String(GameState.current_room.name) if GameState.current_room != null else "-"
	readout_label.text = "State: %s\nVel: %4.0f, %4.0f\nFloor:%s  Wall:%+d\nCoyote:%.2f  Buffer:%.2f  Lock:%.2f\nDashes:%d  Facing:%+d\nGlide:%.2f  Wind:%4.0f,%4.0f\nDeaths:%d  Time:%s  Room:%s" % [
		state_name,
		player.velocity.x,
		player.velocity.y,
		"Y" if player.is_on_floor() else "N",
		int(player.get_wall_direction()),
		player.coyote_time_remaining,
		player.jump_buffer_remaining,
		player.wall_jump_lock_remaining,
		player.air_dash.get_dashes_available(),
		int(player.facing_direction),
		player.glide.stamina_remaining,
		player.get_wind_velocity().x,
		player.get_wind_velocity().y,
		GameState.death_count,
		GameState.get_formatted_time(),
		room_name,
	]
