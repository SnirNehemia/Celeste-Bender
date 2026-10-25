class_name StoryList
extends Resource
## StoryList: Story Mode's levels, in play order (Level_editor.md §9). Saved as
## res://levels/story.tres (LevelStorage.story_path(), the only code that knows
## the folder). The Story screen reads it, and in dev builds edits it: every
## change is saved at once (save_story).
##
## Each entry is a StoryEntry sub-resource (title + scene path). A .tres file can
## hold sub-resources inline, so the whole list is one file.

## The first story when there's no file yet: the two chapters, Air then Earth.
const DEFAULT_ENTRIES: Array = [
	["Air - Windbound", "res://scenes/world.tscn"],
	["Earth - the Earth chapter", "res://scenes/earth_world.tscn"],
]

@export var entries: Array[StoryEntry] = []


## The saved story, or the default one if there's no file (not saved until edited).
static func load_story() -> StoryList:
	var path: String = LevelStorage.story_path()
	if ResourceLoader.exists(path):
		# CACHE_MODE_REPLACE: re-read the file, not a copy cached before an edit.
		var story: StoryList = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as StoryList
		if story != null:
			return story
	var default_story: StoryList = StoryList.new()
	for pair: Array in DEFAULT_ENTRIES:
		default_story.entries.append(StoryEntry.new(pair[0], pair[1]))
	return default_story


## Writes the story to its file. Dev builds only: res:// is read-only elsewhere.
func save_story() -> Error:
	var path: String = LevelStorage.story_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = ResourceSaver.save(self, path)
	if error != OK:
		push_error("[StoryList] could not save %s: %s" % [path, error_string(error)])
	return error


## Moves the entry at `index` by `steps` (-1 = up, 1 = down). Returns its new
## index (the same one if it can't move further).
func move_entry(index: int, steps: int) -> int:
	var new_index: int = clampi(index + steps, 0, entries.size() - 1)
	if new_index == index:
		return index
	var entry: StoryEntry = entries[index]
	entries.remove_at(index)
	entries.insert(new_index, entry)
	return new_index
