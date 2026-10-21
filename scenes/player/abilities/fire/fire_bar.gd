class_name FireBar
extends Node
## The fire bar (Fire_bending.md §4): the player's pool of fire PIPS, shared by the
## fireball (Q) and the flame jet (W). A component under the player, like the other
## abilities; it holds the number and nothing else. Drawing is FirePipsDisplay's job
## (fire_pips_display.gd), which listens to the signals below.
##
## Rules:
##   - Pips are WHOLE: every fireball and jet press costs exactly one, at once.
##   - They never refill on their own. More come from fire diamonds (gain()).
##   - Max FireTuning.max_pips; extra pips gained above the cap are lost.
##   - Per room (Fire_bending.md §13): entering a room, dying or R sets the bar to the
##     room's Room.fire_start_pips. Entering comes from GameState.room_entered (a
##     signal); dying and R come through Player.respawn_at(), which calls
##     reset_to_room_start().
##
## Moves call spend() and act only if it returned true. At 0 pips spend() returns
## false and emits `ran_dry`, so the move can fizzle or sputter instead.

## Emitted whenever the pip count changes. `change` is new minus old: negative =
## spent (the display snuffs those pips), positive = gained (they flare up).
## A room reset sends one signal with the whole difference.
signal pips_changed(pips: int, change: int)
## Emitted when something tried to spend a pip and there was none.
signal ran_dry

## Pips held right now, 0..FireTuning.max_pips. Change it only through gain(),
## spend() and reset_to_room_start(), so the signals always fire.
var pips: int = 0
## The player this bar belongs to (the parent node).
var player: Player


func _ready() -> void:
	player = get_parent() as Player
	# Connecting to an AUTOLOAD's signal: GameState exists before any scene, so the
	# connection can be made right here. Disconnected automatically when we're freed.
	GameState.room_entered.connect(_on_room_entered)


## The most pips the bar holds (from the tuning, read fresh so live edits count).
func get_max_pips() -> int:
	return player.fire_tuning.max_pips


## Adds `amount` pips, up to the cap; the rest is lost. Returns how many were
## actually added (0 when already full), so a fire diamond can stay when it didn't help.
func gain(amount: int) -> int:
	var new_pips: int = mini(pips + amount, get_max_pips())
	var added: int = new_pips - pips
	if added > 0:
		_set_pips(new_pips)
	return added


## Spends one pip. Returns false (and emits ran_dry) when there are none, so the
## caller knows not to fire.
func spend() -> bool:
	if pips <= 0:
		ran_dry.emit()
		return false
	_set_pips(pips - 1)
	FX.play_sfx(&"fire_pip_spent")
	return true


## Back to the current room's starting pips (0 outside a room or where fire is off).
func reset_to_room_start() -> void:
	_set_pips(_get_room_start_pips(GameState.current_room))


func _on_room_entered(room: Room) -> void:
	_set_pips(_get_room_start_pips(room))


func _get_room_start_pips(room: Room) -> int:
	if room == null or not room.fire_allowed:
		return 0
	return clampi(room.fire_start_pips, 0, get_max_pips())


func _set_pips(new_pips: int) -> void:
	var change: int = new_pips - pips
	if change == 0:
		return
	pips = new_pips
	pips_changed.emit(pips, change)
