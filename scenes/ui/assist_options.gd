class_name AssistOptions
extends RefCounted
## AssistOptions: the player's own play options, set from the pause menu and kept
## between sessions in user://options.cfg:
##   - game_speed: the whole game runs this much slower (1.0 = normal). FX multiplies
##     it into Engine.time_scale together with its own slow motion (FX.assist_speed).
##   - extra_coyote_time: seconds added to PlayerTuning.coyote_time (Player reads it
##     every frame on the floor), so a jump pressed a little late still counts.
##   - show_ghost: show the ghost of the fastest recorded run of each room (GhostRuns).
## These are the PLAYER's choices, not level design and not tuning: they never
## change a level file or a tuning resource.
##
## Static only (AssistOptions.game_speed): one set of options for the whole game,
## reachable from anywhere without an autoload.
##
## Godot concepts used:
##   - static var: a value that belongs to the class itself, not to an instance.
##   - ConfigFile: a small INI-style file (sections, keys, values). `user://` is the
##     player's own data folder, outside the project.

## The choices each pause-menu button steps through.
const GAME_SPEEDS: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
const EXTRA_COYOTE_TIMES: Array[float] = [0.0, 0.05, 0.1, 0.2]
const SECTION: String = "assist"
const DEFAULT_OPTIONS_PATH: String = "user://options.cfg"

## Where the options are kept. A var: the smoke test points it elsewhere.
static var options_path: String = DEFAULT_OPTIONS_PATH
static var game_speed: float = 1.0
static var extra_coyote_time: float = 0.0
static var show_ghost: bool = false


## Reads the saved options (the defaults if there is no file yet) and applies the
## game speed. FX calls it once at startup.
static func load_options() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(options_path) == OK:
		game_speed = clampf(config.get_value(SECTION, "game_speed", 1.0), 0.25, 1.0)
		extra_coyote_time = clampf(config.get_value(SECTION, "extra_coyote_time", 0.0), 0.0, 0.5)
		show_ghost = config.get_value(SECTION, "show_ghost", false)
	FX.set_assist_speed(game_speed)


static func save_options() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "game_speed", game_speed)
	config.set_value(SECTION, "extra_coyote_time", extra_coyote_time)
	config.set_value(SECTION, "show_ghost", show_ghost)
	config.save(options_path)


## The next game speed in GAME_SPEEDS (after the slowest, back to normal). Saved.
static func cycle_game_speed() -> void:
	game_speed = _next_of(GAME_SPEEDS, game_speed)
	FX.set_assist_speed(game_speed)
	save_options()


## The next extra coyote time in EXTRA_COYOTE_TIMES. Saved.
static func cycle_extra_coyote_time() -> void:
	extra_coyote_time = _next_of(EXTRA_COYOTE_TIMES, extra_coyote_time)
	save_options()


static func toggle_ghost() -> void:
	show_ghost = not show_ghost
	save_options()


## The value after `current` in `choices`, wrapping round; the first one if
## `current` isn't in the list (a hand-edited file).
static func _next_of(choices: Array[float], current: float) -> float:
	for index: int in choices.size():
		if is_equal_approx(choices[index], current):
			return choices[(index + 1) % choices.size()]
	return choices[0]
