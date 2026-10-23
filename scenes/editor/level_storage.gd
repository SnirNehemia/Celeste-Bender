class_name LevelStorage
extends RefCounted
## LevelStorage: the only code that knows where editor levels live on disk
## (Level_editor.md §3). It lists, saves, loads, renames, duplicates and deletes them.
##
## A level is one world scene file, `<levels_dir>/<slug>.tscn`: a RoomManager root
## with its rooms, Player, camera, UI and a LevelInfo node (see level_template.gd for
## a fresh one). Saving uses PackedScene.pack(), the same thing Godot's editor does
## when you press Ctrl+S on a scene, so the files open in the Godot editor too.
##
## Everything here is `static`: call LevelStorage.list_levels() etc. without making
## an object. There's nothing to remember between calls except `levels_dir`.
##
## Ownership (why adopt() exists): PackedScene.pack(root) saves only the nodes whose
## `owner` is `root`. A node added in code has no owner, so it would silently be
## left out of the file. That's also what keeps the nodes rooms build for
## themselves in _ready (GroundPainter, FireGrid, ...) out of the file: they're
## rebuilt on every load. So: whoever builds or edits a level calls adopt() on each
## node it adds, and nothing else gets saved.
##
## Dev only for now: res:// can only be written when the game runs from the Godot
## project, not in an exported or web build. Changing `levels_dir` (e.g. to
## user://levels/) is all it takes to store levels elsewhere later.

const DEFAULT_LEVELS_DIR: String = "res://levels/"
const LEVEL_EXTENSION: String = ".tscn"
## Exported builds rename scene files to "<name>.tscn.remap" (pointing at a
## converted binary file). load() follows the remap; the file list must strip it.
const REMAP_SUFFIX: String = ".remap"
## Title used when a level file has no readable title.
const UNTITLED: String = "Untitled level"

## Folder the levels live in. A static var: one value shared by the whole game.
## The smoke test points it at a throwaway folder so it never touches real levels.
static var levels_dir: String = DEFAULT_LEVELS_DIR


## Paths of every level file in `levels_dir`, sorted by file name.
static func list_levels() -> Array[String]:
	var paths: Array[String] = []
	var dir: DirAccess = DirAccess.open(levels_dir)
	if dir == null:
		return paths  # no folder yet = no levels yet
	for file_name: String in dir.get_files():
		var scene_name: String = file_name.trim_suffix(REMAP_SUFFIX)
		if scene_name.ends_with(LEVEL_EXTENSION) and not paths.has(levels_dir.path_join(scene_name)):
			paths.append(levels_dir.path_join(scene_name))
	paths.sort()
	return paths


## Reads a level file from disk. Returns null if it can't be loaded.
## CACHE_MODE_REPLACE: Godot keeps loaded resources in a cache by path, and a plain
## load() would hand back the version from before our last save. REPLACE re-reads
## the file and updates the cache, so play and the level list see the latest save.
static func load_level(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene


## Packs `level_root` and every node it owns into a PackedScene in memory (no file).
## The editor's play-test runs from this. Returns null if packing failed.
static func pack_level(level_root: Node) -> PackedScene:
	# A root instantiated from a file remembers that file (scene_file_path). pack()
	# would then save the level as "an instance of itself"; clearing it saves the
	# nodes themselves.
	level_root.scene_file_path = ""
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(level_root)
	if pack_error != OK:
		push_error("[LevelStorage] could not pack the level: %s" % error_string(pack_error))
		return null
	return packed


## Writes `level_root` and every node it owns to `path`. Returns OK or an error code.
static func save_level(level_root: Node, path: String) -> Error:
	var packed: PackedScene = pack_level(level_root)
	if packed == null:
		return ERR_CANT_CREATE
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("[LevelStorage] could not save %s: %s" % [path, error_string(save_error)])
	return save_error


## Makes `node` part of the saved level: sets its owner to `level_root`, and the same
## for its children. An instanced scene (player.tscn, an object) is adopted as one
## piece: its own children already belong to it and come from its scene file.
static func adopt(node: Node, level_root: Node) -> void:
	node.owner = level_root
	if node.scene_file_path != "":
		return
	for child: Node in node.get_children():
		adopt(child, level_root)


## The level's title, read from the file without building its nodes. A PackedScene
## keeps its nodes as a SceneState: a table of node names and saved property values.
static func read_title(path: String) -> String:
	var packed: PackedScene = load_level(path)
	if packed == null:
		return UNTITLED
	var state: SceneState = packed.get_state()
	for node_index: int in state.get_node_count():
		if state.get_node_name(node_index) != LevelInfo.NODE_NAME:
			continue
		for property_index: int in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == &"level_title":
				var title: String = String(state.get_node_property_value(node_index, property_index))
				return title if title != "" else UNTITLED
	return UNTITLED


## Makes a fresh level (one boxed room, see LevelTemplate) and saves it.
## Returns its path, or "" if saving failed.
static func create_level(title: String) -> String:
	var level_root: RoomManager = LevelTemplate.build_new_level(title)
	var path: String = unique_path_for(title)
	var error: Error = save_level(level_root, path)
	level_root.free()  # never entered the tree, so free() (not queue_free) is right
	return path if error == OK else ""


## Saves a copy of the level at `path` under a new file, titled "<title> copy".
## Returns the copy's path, or "" on failure.
static func duplicate_level(path: String) -> String:
	var level_root: Node = _instantiate(path)
	if level_root == null:
		return ""
	var info: LevelInfo = level_root.get_node_or_null(NodePath(LevelInfo.NODE_NAME)) as LevelInfo
	var new_title: String = (info.level_title if info != null else UNTITLED) + " copy"
	if info != null:
		info.level_title = new_title
	var new_path: String = unique_path_for(new_title)
	var error: Error = save_level(level_root, new_path)
	level_root.free()
	return new_path if error == OK else ""


## Changes the level's title. The FILE keeps its name: Story Mode (Stage L11) refers
## to levels by path, and a rename must not break those links.
static func rename_level(path: String, new_title: String) -> Error:
	var level_root: Node = _instantiate(path)
	if level_root == null:
		return ERR_FILE_NOT_FOUND
	var info: LevelInfo = level_root.get_node_or_null(NodePath(LevelInfo.NODE_NAME)) as LevelInfo
	if info == null:
		level_root.free()
		return ERR_INVALID_DATA
	info.level_title = new_title
	var error: Error = save_level(level_root, path)
	level_root.free()
	return error


## Deletes the level file for good.
static func delete_level(path: String) -> Error:
	# globalize_path turns "res://levels/x.tscn" into a real OS path for DirAccess.
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A free file path for a level called `title`: "My Level!" -> my_level.tscn,
## or my_level_2.tscn if that's taken.
static func unique_path_for(title: String) -> String:
	var slug: String = _slugify(title)
	var path: String = levels_dir.path_join(slug + LEVEL_EXTENSION)
	var number: int = 2
	while FileAccess.file_exists(path):
		path = levels_dir.path_join("%s_%d%s" % [slug, number, LEVEL_EXTENSION])
		number += 1
	return path


## Lowercase letters and digits, everything else squashed into single underscores.
static func _slugify(title: String) -> String:
	var slug: String = ""
	for character: String in title.to_lower():
		var is_plain: bool = (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		if is_plain:
			slug += character
		elif not slug.ends_with("_"):
			slug += "_"
	slug = slug.trim_prefix("_").trim_suffix("_")
	return slug if slug != "" else "level"


## Builds the level's nodes from its file, outside the scene tree (nothing runs
## _ready). The caller frees the result.
static func _instantiate(path: String) -> Node:
	var packed: PackedScene = load_level(path)
	if packed == null:
		return null
	return packed.instantiate()
