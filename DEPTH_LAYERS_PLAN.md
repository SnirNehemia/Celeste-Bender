# Depth layers and depth gates: implementation plan (Stages D1–D4)

A self-contained plan for building rooms behind rooms with gates between them, all four stages in one go. The short spec is in `Level_editor.md` §5a, the stage prompts are in `PROMPTS.md` ("Depth layers — Stages D1-D4"), and there is a one-line summary in `GAME_DESIGN.md` §2. This file is the full working plan. If they disagree, this file wins; update the others to match when done.

## 1. Goal

Rooms can sit **behind** other rooms. The player sees the layer behind the room they're in, hazed and solid. They can step into it through a **depth gate** by pressing Up, and from there see one layer deeper. They never see the outer layer they came from: going deeper into a cave leaves the outer cave behind.

In the level editor's map, a **depth toggle** shows one depth at a time. The next deeper depth is drawn underneath it, so the designer can see which room is behind which and where the gates line up.

## 2. Decisions (made with the developer, don't reopen)

| Question | Decision |
|---|---|
| Alignment of the layer behind | **Parallax, pinned at gates.** It slides slower than the front (PARALLAX), but lines up exactly at the gate nearest the player. With no gate in the room, it pins at the room's middle. When the pin changes, it glides there over about 0.3 s instead of jumping. |
| How many layers | **Any number.** Depth 0 (front), 1, 2, and so on. From depth N you see only N+1. |
| Using a gate | **Press Up** (`move_up`) while standing in it. No new key, and no walking through by accident. |
| Map view | **Hazed underneath.** The edited depth is drawn as now. The next deeper one is drawn under it, hazed like in the game, with outlines in a depth color. Gate twins are joined by a line. Page Down / Page Up step through the depths. |
| Look of the layer behind | **Opaque and hazed** (already built). Solid things stay solid; colors are pulled toward a cool gray. The backdrop shows only through the room's open air. |

## 3. What exists now (back rooms, step 1; not committed yet)

- **`scenes/rooms/back_room_view.gd`** (`BackRoomView`, a CanvasLayer at −5, made by `RoomManager._add_backdrop`):
  - A SubViewport shares the game's World2D and has its own Camera2D.
  - It shows the current room's back room: `find_back_room(room)` matches `Room.back_room` against the title or node name.
  - The camera is placed at `back_center + (camera_center - front_center) * PARALLAX`, with PARALLAX = 0.6.
  - The picture is a TextureRect with `back_room_haze.gdshader`.
  - On a room change it fades out, switches (`_switch_to`, in a tween callback), then fades in.
  - Rendering is turned off when there's no back room (`UPDATE_DISABLED`).
- **`scenes/rooms/back_room_haze.gdshader`**: `haze_color` and `haze_amount` (0.45). It keeps the texture's alpha and multiplies only by modulate's alpha, which is used for the fade.
- **`Room.back_room: String`** (`room_base.gd`, in the Look group). It is listed in `level_editor.gd` ROOM_SETTINGS (`&"back_room"`).
- **`tools/screenshot_back_room.gd/.tscn`**: `-- <level> <front room> <back room> <folder>`. It sets `back_room` in memory and saves before/after PNGs.
- **Smoke test** L17 in `tests/editor_smoke_test.gd`: a back-room lookup check (by title, by name, never itself).
- **Docs** that mention step 1: `GAME_DESIGN.md` §2, `Level_editor.md` §5 (Back room field) and §5a, CLAUDE.md (back_room_view in the folder layout).

**D1 removes `Room.back_room`** and the title lookup. Depth replaces them. Levels the developer saved never used `back_room`, so no migration is needed. Check with `grep -r back_room levels/` first.

## 4. Architecture

### 4.1 Depth bands in the world
- **`Room.depth: int = 0`**, exported in a new "Depth" export group (or under Look).
- **World position = map position + `Vector2(0, depth * DEPTH_SPACING)`**, with `DEPTH_SPACING` a constant on Room (e.g. 100 000 px, far beyond any level's height). Depths never touch, so:
  - physics between depths is impossible (no collision layers to manage);
  - `RoomManager._find_room_containing`, room transitions, room sleeping (`_update_awake_rooms`: far rooms are process-disabled) and the camera all work unchanged inside a band;
  - the view behind is just a camera looking at the next band.
- **Map helpers on Room:**
  - `get_map_position() -> Vector2` (position minus the depth offset);
  - `get_map_bounds() -> Rect2`;
  - `static func depth_offset(depth: int) -> Vector2`.
  - `get_bounds()` stays the world rect: gameplay uses it.
- **Everything that compares rooms by height uses map positions:**
  - `Room.get_backdrop_altitude(start_room)` must use map bounds. Otherwise every back room reads as underground.
  - Check `Backdrop.get_slide_direction` callers and `Backdrop._on_room_entered`: the travel vector between rooms of different depths (a gate) should be zero. The backdrop then changes without a scroll, or with a SOFT change if the look differs.
- **The editor stores rooms at world positions** (that's what is saved in the .tscn). When the map moves a room or changes its depth, it sets `position = map_position + depth_offset(depth)`.
- **Where `room.position` / `get_bounds()` is read as a map position:** `map_view.gd` (snapping, overlap, openings, drawing), `editor_overlay.gd` (map drawing, neighbour dimming), `editor_camera` focusing, `room_import`, `editor_clipboard`, the play-test's start point, and `LevelInfo.start_room`.
  - Grep for `get_bounds()` and `.position` in `scenes/editor/`, then decide one by one.
  - Simplest rule: **the editor works in map space for map operations, and in world space for painting and placing inside a room** (painting already works per room in local coordinates).

### 4.2 The view behind (`BackRoomView`, reworked)
- **Its state** is `current_depth`, taken from `GameState.current_room.depth`. It looks at band `current_depth + 1`. If no room has that depth, rendering is turned off (as now).
- **Camera:**
  - `view_camera = pin_back + (camera_center - pin_front) * PARALLAX + correction`, where `pin_front` is the pin in the front band and `pin_back = pin_front + depth_offset(1)`.
  - **Exact at the pin when the player stands there:** compute with the player's position, not only the camera's, because the camera clamps at room edges. Requirement: when the player's center is inside a gate, the twin's screen position equals the gate's screen position (within 1 px).
  - Derivation to use: the front gate's screen position is `pin_front - camera_center`. Choose the view camera so that `pin_back - view_camera` equals that while the player is in the gate, and the back layer drifts by `(1 - PARALLAX)` of the camera's movement away from that state. Concretely: let `anchor_camera` be the camera center at the moment the player stood at the pin. Approximate it as `camera_center - (player_center - pin_front)`. Then `view_camera = pin_back + (camera_center - pin_front) - (1 - PARALLAX) * (camera_center - anchor_camera)`. Verify with the D3 test, and adjust if clamping breaks it.
- **The pin:**
  - It's the gate nearest the player in the current room. With no gate, it's the room's middle.
  - When it changes, tween a `pin_blend` from the old pin to the new one over `PIN_GLIDE_TIME` (0.3 s).
- **Room change at the same depth:** no fade needed, because the band is the same. Just re-pin.
- **Depth change** (through a gate): handled by the gate step (§4.3); afterwards the view shows the new `current_depth + 1`.
- **Haze:** the same shader. Optionally a slightly different `haze_amount` per depth distance, but only the next depth is ever shown, so one value is fine.

### 4.3 Depth gates
- **New object `scenes/objects/depth_gate.gd` + `.tscn`** (`DepthGate`, an Area2D):
  - **Placeholder art** (rule 5: Polygon2D / Line2D): a stone arch about 16×24 with a slowly turning swirl inside. Use the cool haze tone from `GAME_DESIGN.md` §2's color key; pick colors that don't clash with switches and doors.
  - **Twin:** found, not stored. It's the DepthGate in a room of depth ±1 whose map position is within half a tile of this one's (`find_twin()`). A gate links at most one deeper and one shallower twin; use the closest of each. Not storing it means no saved links to keep in sync and nothing to break on copy or import.
  - **Signals:** `player_entered` / `player_exited`, or the player polls `get_overlapping_areas`. Follow how Door/Goal detect the player. Prefer a signal to RoomManager (rule: signals over get_node chains).
- **Using it:**
  - While the player overlaps a gate that has a twin and `move_up` is just pressed (and the player is on the floor, or not; decide in play-test, start with any state except dead or frozen), the gate emits `use_requested(gate)`.
  - RoomManager listens (connect in `_ready` for every gate in the level, or the gates find RoomManager through a group).
- **`RoomManager.go_through_gate(gate)`:**
  1. Ignore it if `is_transitioning` or the player is dead.
  2. Set `is_transitioning`, freeze the player (`set_frozen(true)`, keeping velocity zeroed).
  3. **The step** (about 0.5 s, `GATE_STEP_TIME` in PlayerTuning or a const in RoomManager; it's a look, not feel, so a const is fine): BackRoomView animates `haze_amount` from 0.45 to 0 and scales its picture up slightly around the gate's screen position ("comes forward"). Meanwhile the front fades out, via a full-screen fade or a CanvasModulate on the rooms' canvas. Simplest: a ColorRect overlay in a CanvasLayer between BackRoomView (−5) and the rooms (0) can't hide the rooms, so instead tween the main rooms' `modulate.a` (RoomManager's children that are Rooms, plus the player) or use a full-screen BackBufferCopy. **Decide while building, keep it simple.** Acceptable fallback: crossfade to black over 0.25 s, swap, fade in over 0.25 s.
  4. Swap: the player goes to `twin.global_position` (feet on the twin's floor: use the gate's base point), and `current_room = twin's room`, `GameState.current_room = ...` (emits `room_entered`, so Backdrop and BackRoomView update). Then `camera.snap_to_room(new_room.get_bounds())` and put the camera on the player. Run `twin_room.reset_enemies()` as on a normal room entry, plus `_update_awake_rooms()`.
  5. Unfreeze and clear `is_transitioning`.
- **Death:** respawn at the current room's spawn point (unchanged code: the room is in its band). The checkpoint in GameState is the current room.
- **Restart room (R):** unchanged.

### 4.4 Editor: map view (`map_view.gd`, `editor_overlay.gd`)
- **`MapView.shown_depth: int = 0`.** New InputMap actions `editor_depth_deeper` (Page Down) and `editor_depth_shallower` (Page Up) in `project.godot`. Add them to the quick reference (`editor_help`, which reads its names from the InputMap) and to the key list in CLAUDE.md "Input" and `Level_editor.md` §4.
  - Allowed range: 0 to (deepest existing depth + 1). One past the deepest is allowed so the designer can create the first room of a new depth.
  - A label in the map: "Depth N" plus "(M depths)".
- **Drawing order in the map:**
  1. The depth behind (`shown_depth + 1`): its rooms at their map positions, as they are, through a hazed modulate. A shader or `modulate = Color(0.6, 0.65, 0.8, 1)` is fine in the editor. Outlines in a depth color (e.g. teal) with dashed or thin lines.
  2. The shown depth, as now.
  3. Shallower depths aren't drawn, or drawn as faint outlines only. Decide by look: faint outlines help orientation.
  - The rooms are real nodes in the world band, so drawing "at map position" means either moving them (no) or rendering the band behind through a SubViewport like BackRoomView, aligned 1:1 with an offset. **Reuse the BackRoomView idea:** an editor-side SubViewport whose camera mirrors the editor camera plus `depth_offset`, shown behind with the haze shader. The tiles then look exactly as in the game, at any zoom. Outlines, names and gate markers for the depth behind are drawn by the overlay at map coordinates.
  - The shown depth's own rooms are also in their band. **The editor camera must look at band `shown_depth`:** when the depth changes, move the editor camera by `depth_offset(new) - depth_offset(old)`, so the same map spot stays on screen.
- **Hover:** hovering a room outlines the rooms behind it (depth +1, map rects overlapping) brighter.
- **Gates in the map:** a small arch icon at each gate. A gate and its twin are joined by a short line (they're at the same map spot, so draw a ring or "linked" marker). A gate without a twin is red.
- **Operations at the shown depth:** create room, move, resize, paste, import, select. Overlap is refused only against rooms of the same depth (`is_free(rect, ignore)` filters by depth). Openings (green exits) only between rooms of the same depth.
- **Room panel:** show "Depth N" read-only, and add a right-click menu item "Move to depth…" (deeper or shallower by one). Moving a room changes its position band. Refuse it if it would overlap at the target depth. One undo step.
- **Room view (double-click a room):** the band behind shows hazed, 1:1, via the same editor SubViewport. So when editing a room at depth N you see depth N+1 behind it, aligned, for placing gates by eye. Neighbour dimming stays within the depth.

### 4.5 Editor: placing gates
- **Palette entry** in `palette_catalog.gd` (rule 7): `_add_object(&"depth_gate", "Depth gate", "<family>", preload(...))`. Add a tab assignment in the family map (Objects or Triggers; it's a passage, so Objects), an icon in `palette_icons.gd`, and a placement rule (feet on the tile like the Goal or a Door: SIZE_TOP_LEFT or a bottom-center rule; copy Goal's).
- **Placing** a gate in a room at depth N, where a room at depth N+1 covers that map spot: also place a twin there, in the same undo step (`editor.undo_redo` action with both adds). If depth N−1 also has a room there and no gate, don't auto-create it; the "Add twin" menu handles that.
- **Without a room behind,** the gate is red in the editor (overlay draws a red outline and "no twin"). The right-click menu on a gate offers "Add twin behind" or "Add twin in front" when a room exists there.
- **Moving** a gate moves its twin by the same amount, only if the twin would stay inside its room; otherwise refuse. **Deleting** deletes both. Both are one undo step. Copy/paste and import of a room keep gates. Twins are found by position, so a pasted room's gates simply have no twin until something lines up.
- **Play-test** (`start_playtest`): the player starts at the start point's room. Make sure BackRoomView and Backdrop get its depth right (`room_entered` is emitted at start).

## 5. Stages and what each one ends with

Build in order. After each stage, run the relevant tests (via the `test-selector` and `test-runner` agents), fix, then continue. One wrap-up at the end.

### D1 — Depths in the world and the map
1. `Room.depth`, `DEPTH_SPACING`, `depth_offset()`, `get_map_position()`, `get_map_bounds()`. `get_backdrop_altitude` uses map bounds.
2. Remove `Room.back_room`, its ROOM_SETTINGS entry, `find_back_room`, and the step 1 test check. Update `tools/screenshot_back_room.gd`: it becomes "front room + depth" (it sets a chosen room's depth to 1 and moves it behind the front room in memory) or `-- <level> <folder>` for a level that has depths.
3. BackRoomView: show band `current_depth + 1`, pinned at the room's middle for now. No per-room lookup.
4. Map: `shown_depth`, Page Down/Up actions, the depth label, the camera hop between bands, the band behind drawn hazed underneath via an editor SubViewport, outlines and names at map coordinates, hover highlight, depth-filtered overlap/openings/selection, "Move to depth…" menu, new rooms at the shown depth.
5. Room view: the band behind hazed, 1:1.
6. **Smoke test, section D1** in `editor_smoke_test.gd`:
   - a room moved to depth 1 keeps its map position and its world position is offset;
   - overlap across depths is allowed, within a depth refused;
   - AUTO altitude uses map position;
   - BackRoomView in a play-test from a depth 0 room renders (UPDATE_ALWAYS) and points into band 1;
   - the depth toggle clamps and moves the camera by the offset.

### D2 — The depth gate
1. `depth_gate.gd/.tscn`, `find_twin()`, signals, placeholder art.
2. RoomManager `go_through_gate()` with the step animation (or the fallback crossfade), the swap and the camera snap. BackRoomView follows `room_entered`.
3. Palette entry, icon, placement rule, auto-twin on place, move/delete together, "Add twin" menu, red "no twin" marker, map gate markers.
4. **Smoke test, section D2:**
   - place a gate where a room is behind → two gates, one undo removes both;
   - in a play-test, put the player in the gate, simulate `move_up` → after the step the current room is the twin's, depth 1, and BackRoomView points into band 2 (or is off if there's none);
   - through and back;
   - die after going through → respawn in the depth 1 room;
   - a gate with no twin does nothing on Up.

### D3 — Parallax pinned at gates
1. Pin = the nearest gate in the current room (the room's middle if none), `pin_blend` glide (PIN_GLIDE_TIME 0.3 s), the player-corrected camera formula (§4.2).
2. **Smoke test, section D3:** with the player standing in a gate (in a room large enough that the camera clamps near an edge, too), the twin's screen position equals the gate's within 1 px. Moving the player 100 px away makes the back layer drift by about (1 − PARALLAX) × the camera's movement.
3. Tune PARALLAX by screenshot. Start at 0.6, but since the layer behind is a real room, 0.75–0.85 may read better.

### D4 — Readability polish
1. The gate glows softly (a pulsing Polygon2D or a small light) when it has a twin. It shows a small Up arrow above it while the player stands in it. A gate with no twin is dimmed in play.
2. Play-test from the editor starts with the right depth everywhere, including play-test "here" (Shift+Tab) in a deep room.
3. Story Mode: a level with depths plays fine back to back (StoryPlayer is unaffected; check that `room_entered` is emitted at level start).
4. Backdrops across depths: a gate between rooms of different looks changes the backdrop with no slide direction (travel zero) or a SOFT change. Check it looks fine.
5. **Docs:**
   - `Level_editor.md` §5a: "planned" → as built, plus a "Decided while building" note.
   - `Level_editor.md` §4 keys and §6 palette (the gate).
   - `GAME_DESIGN.md` §2.
   - CLAUDE.md folder layout (`objects/depth_gate`, back_room_view's new role, editor depth view) and Input (the two new actions).
   - `PROMPTS.md`: mark D1–D4 done, with "Decided while building" notes like the other stages.
   - `GAME_SUMMARY.md`: one paragraph.

## 6. Tests to run at the end
- The import check, `editor_smoke_test` with `-d` (no new WARNING lines in touched files), `world_smoke_test`, `earth_chapter_smoke_test`, `fire_smoke_test`. Water too, since RoomManager and Room changed: `water_smoke_test` (long, ~8 min; run it in the background).
- The `style-checker` agent on all changed `.gd` files.
- Screenshots:
  - `tools/screenshot_back_room` (updated) for a level with two depths and a gate pair: the view standing in the gate, then 100 px away;
  - the editor map with the depth toggle (a small tool or a manual check by the developer).
- The developer play-tests: through a gate and back, a death in the deep room, the map toggle.

## 7. Risks and things to watch
- **Map vs world coordinates in the editor** is the biggest source of bugs (§4.1). Grep systematically and decide one call site at a time. Add helpers rather than sprinkling `depth_offset` everywhere.
- **The editor camera hop between bands** must not break undo or selection. Selection holds Room nodes, which is fine.
- **SubViewport cost:** the back band is a second full render of the world band. It's rendered only when a deeper depth exists (step 1 already does this), and the editor has one of its own.
- **Room sleeping:** rooms in other bands are far away, so `_update_awake_rooms` keeps them asleep. BackRoomView draws them anyway, since sleeping only disables processing, not drawing. Animated things behind are frozen; that's acceptable, the same as step 1.
- **Imported or pasted rooms** keep their depth? An import goes to the shown depth. Paste goes to the shown depth too.
- **`LevelInfo.start_room`** can be at any depth. Play-test start points are world positions, so they're fine.
- Keep the user's level files out of commits unless asked: `levels/chapter_1_air.tscn`, `levels/test.tscn` and `levels/chapter_1_air_copy.tscn` are the developer's own edits.

## 8. Current state of the working tree (before starting)
Uncommitted, from the backdrop work that came before this plan:
- every look's surface and skyline share all their layers (split layers, seam fades);
- sanctum is wild cliffs with a few air temples;
- the opaque, hazed back room shader;
- back rooms step 1;
- docs for all of the above.

All tests passed at that point (import, editor, world, Earth chapter, Fire). Suggest a commit of that state before starting D1, so the depth work is its own diff.
