# Level editor and Story Mode — spec v1 (Stage L0)

A **parallel track**, not an element chapter: it can be built in its own sessions while the element stages (F12, F13, …) go on. Stages are named **L1, L2, …** and listed in `PROMPTS.md` under "Level editor track". The two tracks meet in only two places: the palette catalog (§6) and one small Goal hook for Story Mode (§9).

## 1. What it is
- **Level editor** (main menu → Level Editor): paint rooms, place and set up objects, link switches to doors, lay rooms out on a map into one big level, play-test it at once, save it.
- **Story Mode** (main menu → Story Mode): an ordered list of levels, editor-made levels and the existing chapters alike, played back to back. Finishing one unlocks the next; progress is saved.
- **Dev tool for now.** The editor only works when the game runs from the Godot project. Story Mode plays everywhere, the web build included.

## 2. Decided in Stage L0
| Question | Decision |
|---|---|
| Who saves, where | Dev only: levels are scenes in `res://levels/`, committed to git. One script (`LevelStorage`) knows the folder, so a player-facing `user://` version later is a small change. |
| Controls | Mouse + keyboard in the editor. Play-testing stays keyboard-only. |
| Connecting rooms | A **map of rooms**: rooms of any size placed edge to edge in any direction; gaps in the walls are the exits, the same model `RoomManager` already uses. |
| Palette v1 | Everything that exists: basics, Air, Earth, Fire, enemies (spread over several stages). |
| Paired objects | A **link tool** (L): select an object, click its targets, and lines show the links. |
| Story Mode entries | Any level: editor levels **and** the existing chapters (Air 1–7, Earth 1–10, Fire later). |
| Story progress | Saved, with one-by-one unlock and best time and deaths per level, in `user://`. |
| Existing rooms | Can be **imported as copies** into an editor level. Originals and their build scripts are never touched. |
| New objects from element stages | The element stage that adds an object also adds its palette catalog entry (rule in `CLAUDE.md`). |
| Main menu | Story Mode and Level Editor on top; the chapter and test-room entries move into a "Chapters & test rooms" submenu. |

## 3. Level files
- One level is **one world scene**, `res://levels/<slug>.tscn`, written with `PackedScene.pack()`. It has the same shape as `scenes/earth_world.tscn`: a `RoomManager` root, `Room` children placed edge to edge, `Player`, `RoomCamera`, `DebugOverlay`, plus a small `LevelInfo` node (title, start room, notes).
- **Why a real scene, not a custom data file:** `RoomManager`, the F2 room picker, the screenshot tool, the smoke tests and the Godot editor all work with it unchanged. Links like `Door.switches` are exported node references, and a packed scene already stores those.
- Only nodes owned by the level root are saved. Things that rooms and objects build in `_ready` (GroundPainter, FireGrid, PebbleField, flames, leaves) are rebuilt on load, as they are today.
- `scenes/editor/level_storage.gd` is the only code that lists, saves, loads, renames, duplicates and deletes levels.
- In exported builds the Level Editor entry is greyed out ("dev build only"), detected with `OS.has_feature("editor")`.
- A level edited in the Godot editor still opens in the in-game editor, but the in-game editor rewrites the whole file when it saves.

## 4. The editor screen
- **Layout:** a large canvas; a palette on the left with tabs Basics / Terrain / Air / Earth / Fire / Enemies; a property panel on the right; a top bar with the level title, current room, tool and an unsaved-changes dot; a status line at the bottom with the tile under the mouse and warnings.
- **Resolution:** the game draws at 320×180 with `viewport` stretch, which would make editor text unreadable. While the editor is open it switches the window to `canvas_items` stretch at a larger size (start with 640×360) so text is sharp and the canvas can zoom freely. Play-testing switches back to the game's 320×180 `viewport`. Stage L2 checks that this switch is clean at runtime.
- **Grid:** 8 px tiles. Objects snap to the grid; holding Alt places them freely to the pixel.
- **Undo/redo for every edit**, using Godot's `UndoRedo` class.
- **Controls.** All of them are InputMap actions named `editor_*`, so the code never reads raw keys:

| Input | Does |
|---|---|
| Left mouse | paint with the current brush / place the current object / select and drag |
| Shift + left drag | fill a rectangle with the current brush |
| Right mouse | erase the tile, or delete the object under the mouse |
| Middle drag, or Space + left drag | pan |
| Mouse wheel | zoom (whole steps, so pixels stay square) |
| Ctrl+Z / Ctrl+Y | undo / redo |
| Ctrl+S | save |
| Ctrl+D / Delete | duplicate / delete the selection |
| L | link mode for the selected object (§7) |
| M | toggle the map view (§5) |
| Tab / Shift+Tab | play-test from the start / from the mouse (§8) |
| G | toggle the grid |
| Esc | leave link mode, or go back to the level library (asks first if there are unsaved changes) |

- **Level library** (the first screen of Level Editor): the list of levels in `res://levels/`, with New, Open, Duplicate, Rename and Delete (Delete asks to confirm).

## 5. Rooms and the map (M)
- The **map view** shows the whole level zoomed out: each room is a rectangle with its name and a tiny drawing of its tiles.
- Drag on empty space to make a room, drag a room to move it, drag its edges to resize it. Rooms snap to the grid and to neighbouring room edges. The minimum size is one screen (320×180); L7 matches the way the existing rooms handle 180 px being 22.5 tiles.
- Overlapping rooms are refused (drawn red). On shared edges the map marks the openings, the exits, in green.
- One room is the **start room** (a star). The Player starts at its SpawnPoint.
- Double-click a room to edit it. In the room view the neighbouring rooms are drawn dimmed so you can see what's next door. A brush stroke only paints the room under the mouse, because tiles belong to rooms.
- **Room settings** (shown in the property panel when nothing is selected): title, size, elements allowed (Air / Earth / Fire), fire start pips, and the one-key Earth experiment. These are the Room's own exported settings.
- **Import room as a copy:** pick any Room from the existing worlds (Air 1–7, Earth 1–10, the Earth, Fire and mixed test rooms, other editor levels) and click where it goes. The copy becomes part of this level and isn't linked to the original afterwards.

## 6. The palette catalog
- `scenes/editor/palette_catalog.gd` has one entry per placeable thing, grouped by family. Entry fields:
  - `id`, `display_name`, `family` (basics / terrain / air / earth / fire / enemies), `kind` (object or terrain brush)
  - `scene` for an object; layer name + tileset + layer script for a terrain brush
  - `editor_color` for the palette swatch and the stand-in drawing, if the object doesn't draw itself in the editor
  - `editable_properties`: the export names shown in the property panel (design settings only, never tuning numbers like gravity or friction)
  - `size_property` (drag handles, e.g. `door_size`, `zone_size`, `tile_count`) and `point_properties` (drag handles for points, e.g. the vine's `end_point`, the sail's `rail_start`/`rail_end`, the leaf's `travel`)
  - `link_property` + accepted target type (e.g. Door `switches` ← Switch, HangingPlatform `vines` ← Switch, Crate `hung_from` ← Switch, EnemyGate `enemies` ← enemy)
  - `placement` (grid / standing on the floor / free) and `one_per_room` (SpawnPoint)
- Terrain brushes: Ground (`Tiles`), Earth, Grass, Thicket, Overgrown. Each paints its TileMapLayer, and the first stroke creates the layer in that room.
- **Cross-track rule** (also in `CLAUDE.md`): from Stage L4 on, any stage that adds a placeable object or terrain layer adds its catalog entry and keeps the editor smoke test passing. The editor holds no per-object code. If an object needs special editor behaviour, that becomes a new catalog field, not an `if` in the editor.
- **Families in v1:**
  - Basics: spawn point, goal, spikes (facing, count)
  - Air: wind zone, wind crystal, gust diamond, crate, windmill, leaf platform, sail platform, door, pressure plate, no-glide zone
  - Earth: earth ground (brush), cracked wall, stone wall, boulder, loose rocks
  - Fire: grass / thicket / overgrown (brushes), fire diamond, brazier, vine, hanging platform, leaf pile
  - Enemies: wisp, sentry, vine monkey, thicket elephant, shell (once F12 lands), enemy gate

## 7. Properties and links
- **Property panel:** a widget for each type. bool → checkbox; int/float → number field (arrows or drag); enum → dropdown; Vector2 → two fields; direction vectors such as `wind_direction` → an 8-way picker. Every change can be undone and shows at once, because the objects' setters already redraw (e.g. `door_size`).
- **Links (L):** with a linkable object selected, L starts link mode. Click targets to add or remove them, and Esc or L ends it. Links are always drawn as dim lines, bright for the selected object. Links may cross rooms. Deleting a target removes it from every link list.

## 8. Play-test
- **Tab** plays from the start room. **Shift+Tab** drops the player at the mouse in that room; the room's SpawnPoint is still the checkpoint.
- Nothing has to be saved first: the editor packs the level in memory and runs that copy. **Tab** goes back to the editor with the view, selection and undo history as they were. The pause menu gets a "Back to editor" entry.
- Checks before playing: the start room needs a SpawnPoint (this one blocks). Missing Goal, rooms without a SpawnPoint, unreachable rooms and broken links are only warnings in the status line.
- Reaching the Goal in a play-test shows "Goal reached — time, deaths" and goes back to the editor.

## 9. Story Mode
- `res://levels/story.tres` is a `StoryList` resource with ordered entries {display title, scene path}. An entry can be an editor level or an existing chapter world (`scenes/world.tscn`, `scenes/earth_world.tscn`, later the Fire world).
- **Story screen:** Continue · Level select (finished levels get a ✓ with best time and deaths, the next one is open, the rest are locked) · New run (resets progress, asks to confirm).
- **Edit order** (dev builds only, on the same screen): Shift+Up/Down moves an entry; Add picks from levels and chapters; Remove; Rename changes the display title. Changes save at once.
- **Playing:** each level runs as chapters do now (GameState timer and deaths). At its Goal comes a level-complete card (title, time, deaths), then the next level. After the last one comes the end screen with the run's totals.
- **Progress** lives in `user://story_progress.cfg` (a `ConfigFile`): finished entries and best time and deaths, keyed by **scene path**, so reordering doesn't lose progress. An entry is open if it is first or the entry before it is finished.
- **Goal hook:** today Goal → `GameState.finish_run()` → `run_finished` → EndScreen. Story Mode has to decide what happens at the goal. That is one small hook in GameState and EndScreen (e.g. a "story run" flag the end screen respects), the only gameplay code this track touches.

## 10. Main menu
Story Mode · Level Editor (dev only) · Chapters & test rooms ▸ (the current five entries; Esc goes back).

## 11. Stages
L0 plan (this doc) · L1 menu + level storage · L2 editor canvas + ground painting + save/load · L3 spawn, goal + play-test · L4 objects + palette catalog (basics + Air) · L5 property panel + room settings · L6 link tool · L7 map of rooms + import copies · L8 Earth palette · L9 Fire palette · L10 enemies palette · L11 Story Mode. Full prompts are in `PROMPTS.md`. Each stage adds a section to `tests/editor_smoke_test.tscn`, which drives the editor through its code, not the mouse.

## 12. Ideas parking lot
- Player-facing levels in `user://` and the editor in the web build.
- Sharing levels with others. That would need a plain data format, because loading someone else's `.tscn` runs their scripts.
- Decoration layers (background tiles, props), custom tile art.
- A thumbnail per level in the library and Story screens.
- A per-room "par" time, and golden collectibles.
