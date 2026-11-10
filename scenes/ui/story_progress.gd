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


## The relic shards saved for a level (Collectibles.md §2): element
## (RelicShard.Element) -> Array of its saved slots (1..4). Every element has its
## own relic, so a level can hold shards of several.
static func get_shards(scene_path: String) -> Dictionary:
	return _load().get_value(scene_path, "relic_shards", {})


## True if shard `slot` of `element`'s relic is saved for a level.
static func has_shard(scene_path: String, element: int, slot: int) -> bool:
	var shards: Dictionary = get_shards(scene_path)
	return shards.has(element) and (shards[element] as Array).has(slot)


## Saves shard `slot` of `element`'s relic for a level at once (RelicShard, when
## it's secured in a story run), so quitting mid-level keeps it.
static func record_shard(scene_path: String, element: int, slot: int) -> void:
	var config: ConfigFile = _load()
	var shards: Dictionary = config.get_value(scene_path, "relic_shards", {})
	var slots: Array = shards.get(element, [])
	if slots.has(slot):
		return
	slots.append(slot)
	slots.sort()
	shards[element] = slots
	config.set_value(scene_path, "relic_shards", shards)
	config.save(progress_path)


## True if the level was finished carrying the golden feather (Collectibles.md §3).
static func is_golden(scene_path: String) -> bool:
	return _load().get_value(scene_path, "golden", false)


static func record_golden(scene_path: String) -> void:
	var config: ConfigFile = _load()
	config.set_value(scene_path, "golden", true)
	config.save(progress_path)


## The level's collectibles in one short line, e.g. "Air relic  Water 2/4  Gold":
## each element's relic, complete or how many of its 4 quarters, then "Gold" for a
## golden level ("" when there is nothing yet).
static func get_collectibles_text(scene_path: String) -> String:
	var parts: Array[String] = []
	var shards: Dictionary = get_shards(scene_path)
	var elements: Array = shards.keys()
	elements.sort()
	for element: int in elements:
		parts.append(RelicShard.get_relic_progress_text(element, (shards[element] as Array).size()))
	if is_golden(scene_path):
		parts.append("Gold")
	return "  ".join(parts)


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
