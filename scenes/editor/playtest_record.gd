class_name PlaytestRecord
extends RefCounted
## PlaytestRecord: what the level editor remembers of play-tests, to draw over the
## level afterwards (EditorOverlay): the path the player took in the LAST play-test
## (the trail), and where the player died, over ALL play-tests of this level (the
## death markers; older play-tests' deaths are drawn fainter). T shows or hides
## both, Ctrl+T (or the room panel's button) clears the deaths.
##
## LevelEditor feeds it: begin_trail() when a play-test starts, add_point() every
## physics frame with the player's feet, add_death() on the player's `died` signal,
## save() when the play-test ends. The play copy of the level sits at the same
## place as the editor's, so its positions are level positions here too.
##
## The trail is cut into segments wherever the player jumped further than a normal
## frame allows (a respawn, a room reset): no line across the screen to the spawn.
## Deaths are kept per level file in RECORD_PATH (a ConfigFile in user://, the
## player's own data folder, not the project), so they survive closing the editor.

## Where the deaths of every level are kept. A var: the smoke test points it elsewhere.
static var record_path: String = "user://editor_playtest_record.cfg"
const DEFAULT_RECORD_PATH: String = "user://editor_playtest_record.cfg"
const DEATHS_KEY: String = "deaths"
## Which play-test each death came from, and how many play-tests there were (so the
## overlay can fade older deaths). Records from before these keys count as run 0.
const DEATH_RUNS_KEY: String = "death_runs"
const RUN_COUNT_KEY: String = "run_count"
## Further than this between two physics frames is a teleport (respawn), px.
const JUMP_DISTANCE: float = 24.0
## A trail point is kept only once the player has moved this far from the last, px
## (standing still for a minute adds nothing).
const MIN_STEP: float = 1.0

## Show the trail and deaths in the editor (T).
var is_shown: bool = true
## The level these deaths belong to.
var level_path: String = ""
## The last play-test's path: one PackedVector2Array per unbroken stretch.
var trail: Array[PackedVector2Array] = []
## Feet positions where the player died, all play-tests of this level.
var deaths: PackedVector2Array = PackedVector2Array()
## Per death (same index as `deaths`): the number of the play-test it happened in.
var death_runs: PackedInt32Array = PackedInt32Array()
## Play-tests of this level so far; the current or last one is number run_count.
var run_count: int = 0


## Loads the deaths kept for `path` (none if it never was play-tested); the trail starts empty.
func load_level(path: String) -> void:
	level_path = path
	trail.clear()
	var config: ConfigFile = ConfigFile.new()
	deaths = PackedVector2Array()
	death_runs = PackedInt32Array()
	run_count = 0
	if config.load(record_path) == OK:
		deaths = config.get_value(level_path, DEATHS_KEY, PackedVector2Array())
		death_runs = config.get_value(level_path, DEATH_RUNS_KEY, PackedInt32Array())
		run_count = config.get_value(level_path, RUN_COUNT_KEY, 0)
	death_runs.resize(deaths.size())  # an older record: its deaths count as run 0


## A play-test starts: the old trail goes, a new one begins.
func begin_trail() -> void:
	trail.clear()
	is_shown = true
	run_count += 1


func add_point(feet: Vector2) -> void:
	if trail.is_empty():
		trail.append(PackedVector2Array([feet]))
		return
	var segment: PackedVector2Array = trail[trail.size() - 1]
	var last: Vector2 = segment[segment.size() - 1]
	if last.distance_to(feet) > JUMP_DISTANCE:
		trail.append(PackedVector2Array([feet]))  # a respawn: a new stretch
	elif last.distance_to(feet) >= MIN_STEP:
		# A PackedVector2Array is a value in an Array: change it, then put it back.
		segment.append(feet)
		trail[trail.size() - 1] = segment


func add_death(feet: Vector2) -> void:
	deaths.append(feet)
	death_runs.append(run_count)


## How many play-tests ago death number `index` happened: 0 = the last one.
func get_death_age(index: int) -> int:
	return run_count - death_runs[index]


## Forgets this level's deaths (and saves that). Returns how many there were.
func clear_deaths() -> int:
	var count: int = deaths.size()
	deaths = PackedVector2Array()
	death_runs = PackedInt32Array()
	save()
	return count


## Writes this level's deaths to record_path, keeping the other levels'.
func save() -> void:
	if level_path == "":
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(record_path)  # missing the first time: then it starts empty
	if deaths.is_empty():
		for key: String in [DEATHS_KEY, DEATH_RUNS_KEY]:
			if config.has_section_key(level_path, key):
				config.erase_section_key(level_path, key)
	else:
		config.set_value(level_path, DEATHS_KEY, deaths)
		config.set_value(level_path, DEATH_RUNS_KEY, death_runs)
	config.set_value(level_path, RUN_COUNT_KEY, run_count)
	config.save(record_path)
