class_name StoryProgress
extends RefCounted
## StoryProgress: what the player has finished in Story Mode, with the best time
## and fewest deaths per level (Level_editor.md §9). Saved in
## user://story_progress.cfg, so it works in exported and web builds too
## (user:// is the player's own save folder; in a browser it's kept by the browser).
##
## Keyed by SCENE PATH, not by position in the list: reordering or renaming the
## story keeps every level's progress.
##
## Unlocking: an entry is open if it's the first, if it's finished, or if the entry
## before it is finished. Continue plays the first entry not finished yet.
##
## Godot concept, ConfigFile: an INI-style file of [sections] with key = value
## lines. Here one section per level: finished, best_time, best_deaths.
## Everything is static: StoryProgress.is_finished(path) etc.

const DEFAULT_PROGRESS_PATH: String = "user://story_progress.cfg"

## The file. The smoke test points it at a throwaway file.
static var progress_path: String = DEFAULT_PROGRESS_PATH


static func _load() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	config.load(progress_path)  # a missing file just leaves it empty
	return config


static func is_finished(scene_path: String) -> bool:
	return _load().get_value(scene_path, "finished", false)


## Best time in seconds, or -1 if never finished.
static func get_best_time(scene_path: String) -> float:
	return _load().get_value(scene_path, "best_time", -1.0)


## Fewest deaths in a finished run, or -1 if never finished.
static func get_best_deaths(scene_path: String) -> int:
	return _load().get_value(scene_path, "best_deaths", -1)


## A level was finished in `time` seconds with `deaths` deaths: marks it finished
## and keeps the better of the old and new bests.
static func record_finish(scene_path: String, time: float, deaths: int) -> void:
	var config: ConfigFile = _load()
	var best_time: float = config.get_value(scene_path, "best_time", -1.0)
	var best_deaths: int = config.get_value(scene_path, "best_deaths", -1)
	config.set_value(scene_path, "finished", true)
	config.set_value(scene_path, "best_time", time if best_time < 0.0 else minf(best_time, time))
	config.set_value(scene_path, "best_deaths", deaths if best_deaths < 0 else mini(best_deaths, deaths))
	config.save(progress_path)


## New run: forgets everything.
static func reset_all() -> void:
	ConfigFile.new().save(progress_path)  # an empty file


## True if the entry at `index` of `story` can be played (see the header).
static func is_open(story: StoryList, index: int) -> bool:
	if index == 0 or is_finished(story.entries[index].scene_path):
		return true
	return is_finished(story.entries[index - 1].scene_path)


## The entry Continue plays: the first not finished yet. -1 when all are done.
static func get_continue_index(story: StoryList) -> int:
	for index: int in story.entries.size():
		if not is_finished(story.entries[index].scene_path):
			return index
	return -1


## "1:07.43" for a time in seconds (the same format as GameState's timer).
static func format_time(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]
