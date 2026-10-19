class_name DebugOverlay
extends CanvasLayer
## On-screen debug readout for tuning movement: current state, velocity, the
## forgiveness timers, dash/glide/gust resources, and GameState (deaths, time, current
## room). Toggle it with the `debug_toggle` action (F1).
##
## A CanvasLayer draws its children on a separate layer that ignores the game camera,
## so the text stays fixed in the corner of the screen (useful once rooms scroll).
##
## Usage: instance debug_overlay.tscn in a room and drag the Player node onto the
## `player` field in the Inspector. The overlay only READS from the player; it never
## changes anything, so it can be removed without breaking the game.
## (One exception, a dev tool: F4 `debug_save_tuning` writes the player's CURRENT
## tuning values, including anything changed in the Remote tab, back to
## player_tuning.tres, so a good tuning session survives closing the game.)

## The player to display. Set in the Inspector (an exported node reference
## instead of a hard-coded path like get_node("../Player")).
@export var player: Player

## How long the "tuning saved" message stays on screen, real seconds.
const SAVE_MESSAGE_TIME_MSEC: int = 2500

@onready var readout_label: Label = $ReadoutLabel

## Last F4 result, shown under the readout, and when it was shown (real-time ms).
var save_message: String = ""
var save_message_shown_msec: int = 0


## _unhandled_input receives key presses that no UI element consumed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
	elif event.is_action_pressed("debug_save_tuning"):
		_save_tuning()


## Writes the live PlayerTuning resource to its .tres file. The Remote tab edits
## this same in-memory object, so whatever you tuned is what gets saved.
## ResourceSaver.save() serializes a Resource to disk; with no path it uses the
## resource's own resource_path (res://resources/player_tuning.tres).
## Works when running from the project folder (editor or `godot --path .`);
## an exported game can't write to res://.
func _save_tuning() -> void:
	if player == null or player.tuning == null:
		return
	var tuning_path: String = player.tuning.resource_path
	var error: Error = ResourceSaver.save(player.tuning) if tuning_path != "" else ERR_FILE_BAD_PATH
	if error == OK:
		save_message = "Tuning saved to %s" % tuning_path
	else:
		save_message = "Tuning NOT saved (%s)" % error_string(error)
	print("[DebugOverlay] %s" % save_message)
	save_message_shown_msec = Time.get_ticks_msec()
	visible = true  # make sure the message is seen


## _process runs once per rendered frame (vs _physics_process at a fixed 60/s).
## Fine for display code that doesn't affect gameplay.
func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	var state_name: String = String(player.state_machine.current_state.name)
	# GameState is the autoload: reachable by name from any script.
	var room_name: String = String(GameState.current_room.name) if GameState.current_room != null else "-"
	readout_label.text = "State: %s\nVel: %4.0f, %4.0f\nFloor:%s  Wall:%+d\nCoyote:%.2f  Buffer:%.2f  Lock:%.2f\nDashes:%d  Facing:%+d\nGlide:%.2f  Wind:%4.0f,%4.0f\nGust CD:%.2f  Charges:%s\nEarth: %s\nDeaths:%d  Time:%s  Room:%s" % [
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
		player.gust.cooldown_remaining,
		player.gust.get_charges_text(),
		player.earth_bend.describe_contact(),
		GameState.death_count,
		GameState.get_formatted_time(),
		room_name,
	]
	if save_message != "" and Time.get_ticks_msec() - save_message_shown_msec < SAVE_MESSAGE_TIME_MSEC:
		readout_label.text += "
" + save_message
