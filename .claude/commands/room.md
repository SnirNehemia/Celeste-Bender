---
description: Build or revise one room of a chapter through its build script (usage: /room earth 4, /room fire 7)
argument-hint: <air|earth|fire> <room number> [what to change]
---

Build or revise **room $ARGUMENTS**. First word = chapter, second = room number, the rest (if any) = the change I want.

1. Read `CLAUDE.md` and the chapter's design doc (`GAME_DESIGN.md` for air, `Earth_bending.md`, `Fire_bending.md`) for this room's brief: what it teaches, what it must require, difficulty.
2. Find the chapter's generator: `tools/build_rooms.gd` (air), `tools/build_earth_chapter.gd` (earth), `tools/build_fire_chapter.gd` (fire, from Stage F14). Read how an existing room there is written and copy its idiom (helpers, tile/ASCII layout, checkpoint and goal placement, comments).
3. **Edit the build script, never the generated `.tscn`**: regenerating overwrites scene edits. If I hand-edited the `.tscn` in the Godot editor, warn me before regenerating.
4. Rebuild only this room: `godot --headless --path . res://tools/<build tscn> -- <n>`.
5. Add or extend this room's check in the chapter smoke test (the key move that solves it, plus structure: spawn, checkpoint, goal reachable). Run it and the import check; no script errors allowed.
6. Take a picture: `godot --path . res://tools/screenshot_rooms.tscn -- res://scenes/<chapter>_world.tscn <folder in the scratchpad>`, then view this room's PNG and describe it. Send it to me with SendUserFile.
7. Sanity checklist, state each yes/no: spawn not on a hazard; checkpoint before every hard section; the room's new element is *required* (can't be skipped); no softlock (a way out after a death or after using the element); fits 320×180 screens as designed.
8. End with: how to test (which keys, what I should see), 3–6 explanation bullets, a suggested commit message. Don't commit.
