# Level design guide: how to plan and build a level

Read this before planning or building any level (a new one, more rooms for an old one, or a rework). It collects what the developer's hand-made levels show about how they design, the numbers a room must respect, and the process that worked.

**Where it comes from.** Written 16 Nov 2026 from a tile-by-tile read of the two hand-made levels, plus the level tools:
- `levels/chapter_1_air.tscn`: the developer's Air level, 15 rooms, unfinished. The main source.
- `levels/chapter_1_air_copy.tscn`: the hand-made "Chapter 0 - Basics", 34 rooms.
- `tools/build_basics_level.gd`, `tools/build_element_levels.gd`, `tools/level_kit.gd`.

**How sure each part is.** §2 to §5 are patterns read off the maps: what the developer built, with the rooms that show it. Why they built it that way is Claude's reading, not something the developer said. When the developer corrects one, fix it here. §6's numbers are calculated from the tuning files, not measured in play.

Models to study (print them with the dump tool, §9):
- **Air rooms 11 and 12**: one new object taught in an empty room, then tested with the safety net taken away.
- **Air rooms 15, 17, 18**: a big set piece, built as two halves and then joined.
- **Basics room 14 and its wings**: the hub shape every chapter ends with.

---

## 1. The process

1. **Plan first, in chat, and wait for a yes.** The developer asks for a plan before any room exists. A plan is: the level's shape (§2), a table with one line per room (name, what it teaches, the layout in a sentence), where the collectibles go, and the open decisions.
2. **Check the mechanics you plan to use against the code, not the design docs.** The docs lag behind the tuning. Examples found while writing this guide:
   - `GAME_DESIGN.md` gives the down-gust as 120 px/s; `player_tuning.tres` has 300.
   - A fire sentry's fireballs can't be reflected by a gust (§7).
3. **Say what won't feel good** and offer an alternative before building (CLAUDE.md rule 8).
4. **Build in stages with a play-test between them.** Never a whole level in one go: the intro rooms and the hub first, then one wing per stage, then the finale. Rooms built from numbers alone are mostly wrong the first time.
5. **Build with `LevelKit`** in a `tools/build_<level>.gd` script (§8), into a NEW file. Never write into a level the developer made by hand; never rebuild a tool-made level once the developer has edited it in the editor.
6. **Check**: `kit.find_problems()` prints nothing, the level's section in `tests/built_levels_smoke_test` passes, and the dump (§9) looks like the plan.
7. **Hand over** with a per-room test checklist: what to press, what should happen.

## 2. The shape of a level

The developer's levels have four parts, in this order.

| Part | What it is | Seen in |
|---|---|---|
| **Run-in** | A few small rooms in a line, each teaching one thing | Basics rooms 1 to 4 and the corridor rooms after them; Air rooms 1 to 4 |
| **Hub** | One tall room with a row of Key lights and the way to the Grand door | Basics room 14 |
| **Wings** | Themed series of rooms off the hub, each ending in a Key orb | Basics: crumbling stones, platform puzzles, enemies and step pads, darkness and hidden chambers |
| **Behind the door** | The Grand door and the Goal, one depth behind the hub | Basics room 15 |

- **A wing is one family of objects.** Its first room is the smallest room that shows the idea, with nothing else in it:
  - Basics "platform puzzles": one rail platform, one step pad, a storm-cloud floor.
  - Basics "crumbling stones": a staircase of crumbling stones over spikes.
  - Basics "enemies and step pads": five wisps on a staircase floor, no hazards at all.
- **The hub is tall, with exits at different heights** on both sides (Basics room 14 is 40 x 50 tiles). The Key lights stand together in a row in the middle, with the depth gate right under them, so the player sees the whole lock at once.
- **Levels climb.** The Air level goes from map y = 0 to y = -1244 over 15 rooms. Almost every room is entered low on the left and left high on the right. Plan rooms "up and to the right" unless a room has a reason to go down.
- **Wing order is free; difficulty ramps inside each wing.** Because the player can take the wings in any order, no wing may need something only another wing teaches.
- **A way back.** A wing must end back at the hub without replaying its rooms: a drop into the hub from above (Basics "The way down"), or a one-way teleport door.

## 3. How a room is built

- **Rooms are rarely exactly one screen.** A screen is 40 x 23 tiles. Hand-made sizes: 40 x 31, 40 x 32, 60 x 30, 42 x 33, 45 x 33. A third of a screen taller or wider makes the camera scroll a little and gives a climb room to breathe. Use an exact screen for the first tutorial rooms and for calm rooms.
- **Set pieces are several screens.** Air room 10 is 64 x 65 tiles, room 15 is 64 x 81 (3.5 screens tall). One or two per level, late.
- **Tutorial rooms are made of rectangles; later rooms are organic.**
  - Early: square pillars 3 to 6 tiles wide, straight walls one tile thick, flat spike floors (Air rooms 1 to 3).
  - Later: ceilings that taper like stalactites (19 tiles wide at the top, 1 at the tip), walls that step in and out by a tile every few rows, thick ragged edges (Air rooms 4, 5, 7, 10, 15).
  - When building from code, don't leave late rooms as boxes: step the walls and taper the masses.
- **Single-tile perches.** Late rooms scatter lone tiles (and 2 x 2 blocks) as footholds, far enough apart that each hop needs an ability. Air room 6 has four of them rising along a diagonal, about 9 tiles apart.
- **No floor means death, and reads as open sky.** Air rooms 4, 5, 10, 11 and 12 have no bottom: the lower third is empty air. The developer uses this in sky rooms where Basics used spikes. Use spikes when the danger is a spot to avoid, a bottomless room when the whole room is the danger.
- **Storm clouds as a floor.** In the platform rooms the bottom two rows are storm cloud (Basics "platform puzzles"), and diagonal cloud bands make a slalom for a ride (Basics room 37).
- **Spikes on a wall mean "no wall jump here".** Air room 2 lines the whole right wall with left-facing spikes so the climb has to use the pillars.
- **Entry and exit openings.** A gap 3 to 4 rows tall in a side wall, right above the floor it leads onto. The spawn point stands 1 or 2 tiles inside the entry.
- **Rooms meet by position.** There are no doors between rooms: an exit gap must sit at the same place on the map as the next room's entry gap. Example: Air room 1's exit is rows 1 to 4 of a room at y = 0; room 2 sits at y = -200 and its entry is rows 26 to 28. Work out every pair of gaps in map pixels before building.

## 4. How the developer teaches

- **The same room again, with a new verb.** Air rooms 1 to 4 ARE Basics rooms 1 to 4, with the helper blocks taken out. Room 3 loses its ceiling masses and stepping stones and gains a no-glide zone over most of the room: the geography is familiar, the solution is new. A player who knows the room sees exactly what the new ability replaces.
- **A, then A again and harder.** Basics has pairs named "Room 18" / "Room 18 copy" and "Room 19" / "Room 19 copy": the same room twice in a row, the second with one or two more spikes. The repeat costs the player nothing to read, so all their attention goes to the harder part.
- **Teach in an empty room, then take the safety net away.** The clearest pair in the Air level:
  - Room 11: an empty box, 42 x 33, with four gust diamonds as the only route (15 tiles apart, then 9 and 8 with a 5-tile rise each). Gliding is allowed, so a missed diamond can be saved.
  - Room 12: the same box under a no-glide zone covering all of it, with seven diamonds in two rows (7 or 8 tiles apart, the rows 13 tiles apart). No glide to save you, and a choice between the high row and the low row.
- **Zones isolate a verb.** A no-glide zone as big as the room (280 x 224 px in room 3, 288 x 240 in room 12) is how the developer says "this room is about the gust".
- **Refills low, upgrades high.** In the big climb (Air room 17) the lower half has five wind crystals, 8 to 12 rows apart, on alternating sides of the shaft. The upper half, where the shaft narrows from 13 tiles to 6, has three gust diamonds. Easy help first, then the help that demands more.
- **Calm rooms between hard ones.** Air rooms 13 and 14 are one flat screen of grass with a leaf pile 180 to 270 px wide and nothing that can kill. Put a room like this after a set piece.
- **Up one way, down another.** Air room 15: climb the shaft on the right, then come down through a huge hidden cave on the left, stepping on four step pads on the way. The pads open a door at the bottom, beside where the climb started. The player ends where they began, with the door they walked past now open.
- **Rides with errands.** Basics room 36: a slow rail platform (40 px/s) crosses a room 125 tiles wide. Three step pads sit off the platform at different heights, and a switch wall blocks the rail until all three are on. The player has to leave the ride, do a job, and get back on.
- **Many small switches, one gate.** Eight pressure plates under eight falling blocks (Basics room 34), four step pads for one door (Air room 15), always in ALL mode. The developer likes "do every part" locks more than single switches.
- **The same place at three depths.** Basics rooms 26, 27 and 28 are one layout at three depths: plain, then with falling and crumbling blocks, then dark. Depth is used as "this room again, changed", not only as a place for secrets.
- **Other elements appear as scenery.** Air rooms use grass floors, an earth wall, thicket strips, ice. They are there for the look; the route never needs their element. Fine as decoration, but keep the element switched off in the room unless the route uses it.

## 5. How the developer iterates

- **Copy, then change.** Room titles like "Room 13 copy" and "Room 21 copy copy" are the working method: a room is duplicated and one thing is changed.
- **Halves first, then joined.** The set piece was built as room 17 (the shaft alone, 40 tiles wide) and room 18 (the hidden cave alone, 49 wide), then joined into room 15 (64 wide). When building a big room from code, write it as parts that can be built and tested alone.
- **Most rooms keep the default title** ("Room 7"). Only a wing's rooms get a name that says the theme. Give every tool-built room a real title anyway (`find_problems` wants one, and the room picker shows it).
- **Unfinished rooms are normal.** A hand-made level in progress has rooms with no exit and rooms off to the side. Ask before treating one as final, and never "tidy" one.

## 6. Numbers

Tiles are 8 px. The developer saves tuning from play (F4), and `resources/player_tuning.tres` overrides the defaults in `player_tuning.gd`, so these numbers go stale: measure again before relying on them (see below).

Measured 16 Nov 2026 with simulated keys on flat ground, landing at the height of the take-off:

| Move | Across | Up |
|---|---|---|
| Jump (full hold) | 51 px (6 tiles) | 29 px (3.5 tiles) |
| Jump + glide | 124 px (15.5 tiles) | |
| Jump + down-gust at the top | 98 px (12 tiles) | 78 px (nearly 10 tiles) |
| Jump + gust left + glide | 184 px (23 tiles) | |
| Jump + down-gust + glide | 197 px (24.5 tiles) | |
| A second down-gust (gust diamond) | | about 50 px more (calculated) |

**Speed on ice** (measured 16 Nov 2026, the same way; painted ice, Air on):
- A gust ON THE GROUND never builds speed, on ice too: its sideways recoil is halved and braked to a stop within the input lock (`gust_ground_recoil_friction`). Speed comes from a gust IN THE AIR: a hop, then a gust aimed away, throws you at 200 px/s (2.2x run speed).
- Land on ice with it and you keep it: about 175-200 px/s on landing, fading only to about 185 after 0.5 s and 150 after 1.5 s. On ground it stops at once.
- The recoil SETS the speed, it doesn't add: chaining hops never goes past 200 px/s.

| From ice at | Move | Across |
|---|---|---|
| 152 px/s | Jump (full hold) | 95 px (12 tiles), against 51 from a standstill |
| 163 px/s | Jump + glide | 179 px (22 tiles), against 124 |

So at full ice speed a plain jump carries about as far as a jump + down-gust does from a standstill, and jump + glide nearly as far as gust + glide.

Other numbers:
- Bonfire updraft (a burning leaf heap): lifts a glider at 160 px/s, 48 px (6 tiles) above the flame (`FireTuning.hot_updraft_lift`, `bonfire_updraft_height`; tuning, not measured).
- Safe steps and gaps with no bending: steps up to 3 tiles, gaps up to 3 tiles when climbing, 5 on the level (`build_basics_level.gd`, used for the whole Basics hub).
- Landing lower buys distance: a glide sinks 30 px/s, so each tile of drop adds about 3 tiles of glide, until the 1.5 s of breath run out.
- Gust cone 40 px long; neutral blast radius 35 px.

**Calculation was wrong where it mattered.** The first Air build sized a dead-air pit at 12 tiles from a calculated down-gust reach of 118 px; measured, it is 98 and the pit could not be crossed. Measure: `tests/built_levels_smoke_test.gd` has the helpers (`_jump_then`, `_glide`, `_check_landed`) that press the keys, and its `windward` section replays every key move of the level.

What the hand-made rooms actually ask for, which is a better guide than the limits:
- Tutorial pillars are 3 to 6 tiles wide with gaps of 3 to 4 tiles.
- Gust diamonds in a chain: 7 to 15 tiles apart on the level, 8 or 9 apart when each is 5 tiles higher.
- Wind crystals up a shaft: 8 to 12 rows apart.
- Lone perches for gust hops: about 9 tiles apart.

Rule: size each gap to about 80% of the measured reach of the move it asks for, AND wider than the easier move before it can cross (a "you must glide" gap is over 6 tiles, a "you must gust" gap over 15.5). Add a simulated-keys check for every key move of a new room.

## 7. Objects: the settings the developer changes, and traps

- **Sentries are tuned per placement**, with three settings:
  - `sight_range`: 100 for an ambush under an overhang, 220 as the default, 350 for a sniper at the top of a shaft.
  - `fire_interval`: 2.0 as the default, 0.5 for rapid fire.
  - `fire_orbs`: on makes it a fire sentry (ember orange) that throws fireballs.
  - `orb_speed` was left at 60 everywhere so far.
- **A fire sentry's fireballs can't be gusted.** A gust neither reflects nor moves them; they can only be dodged. In a room with only Air, a fire sentry can be destroyed by a reflected orb from an ordinary sentry (by the code: every sentry's hit table kills on REFLECTED_ORB, and a reflected orb aims itself at an enemy within 45° of the gust) and by nothing else the player has. So pair fire sentries with orb sentries, or treat them as a hazard that stays.
- **A fire sentry's fireball lights leaf piles, Air-only room or not** (measured: one shot made a 60-leaf heap a bonfire). But it ARCS: it flies over a pile lying on the floor (6 px tall) and over the player standing behind it. Put the pile in the shot's path: a tall heap (`pile_height` 20+), or on a ledge at the sentry's height. Burning GRASS needs the room's Fire on or `grass_burns` (Room setting; without either, plants don't burn).
- **One sentry over a whole climb.** The developer puts a long-range fire sentry on the ceiling of the tall shaft (Air room 17), so the entire climb is under fire from above.
- **Step pads and plates** are set wider than the default: pads 16 or 24 px, plates 16 px.
- **Doors are small**: 8 x 24 px for a step-pad door. Grand doors are 16 x 64.
- **Hidden chambers are big.** Not only 3 x 3 alcoves (Air room 6, at floor level at the end of a floor): Air rooms 10 and 15 hide caves 35 tiles wide and 70 rows tall, a whole second route. Thicket tiles along a chamber's edge are the developer's hint that something is there.
- **Painting a hidden chamber turns Earth on in the room.** Set `earth_allowed = false` again afterwards in a level that shouldn't have Earth.
- **Collectibles** follow `Collectibles.md`: one relic of the level's element with all four slots, one hiding place of each kind (precision, secret, element puzzle, off the path), and the golden feather in the first room. In Basics the secrets are a fake wall behind the spawn point, an alcove off a shaft, a second chamber higher in the same wall as the real route, and a detour over a moving platform.

## 8. Building with LevelKit

- `LevelKit.create(title)` for a new level, `LevelKit.open(path)` to finish a copy of a hand-made one (then `kit.save` to a different path).
- Rooms: `add_room(node_name, title, map_px, size_px, depth)`. Elements start OFF: turn on what the room uses.
- Terrain: `paint_map` (a room as text, see the header of `level_kit.gd`), `fill`, `clear`. Text maps are the readable way: the map in the tool looks like the dump of the result.
- Objects: `place(room, entry_id, node_name, position_px, settings)`, with ids from `scenes/editor/palette_catalog.gd`. Each entry's comment says where its origin is (a sentry's is its bottom-center on the floor; pick-ups and floor-standing 2 x 2 things use `LevelKit.corner`).
- Links: `kit.link(door, &"switches", [plate])`. A link made in code can cross rooms: the Grand door in the room behind the hub links to the hub's Key lights (Basics, and the Air chapter). Key orbs find their Key lights by color, with no link.
- Depth: `add_room(..., depth)` plus `kit.depth_gate` in both rooms at the same map spot.
- Mistakes already made once:
  - A spawn point left at the template's default, inside a hill: R put the player in rock. Call `set_spawn` in every room.
  - A fall along a room's edge left the level: close the corners above an open edge.
  - Wall gaps that don't line up with the next room (§3).

## 9. Studying a level: the dump tool

`tools/dump_level.tscn` prints a level as text: each room as a character map with its objects and their settings listed under it.

```
godot --headless --path . res://tools/dump_level.tscn -- res://levels/chapter_1_air.tscn > out.txt
godot --headless --path . res://tools/dump_level.tscn -- res://levels/chapter_1_air.tscn Room11 Room12
```

Use it:
- before planning, on the developer's newest hand-made rooms. They are the best statement of what the developer wants, and this guide ages;
- after a build, to compare the result with the plan;
- when the developer says "like room N": read that room first.

## 10. Checklists

**Every room**
- [ ] One idea, or one new combination of ideas already taught.
- [ ] Entered low on the left and left high on the right, unless there's a reason.
- [ ] Its entry and exit gaps line up with its neighbours on the map.
- [ ] The spawn point is set, on a floor, 1 or 2 tiles inside the entry.
- [ ] Every jump is within about 80% of the reach in §6.
- [ ] Dying puts the player back before the hard part, not in it.
- [ ] Only the elements it uses are on.
- [ ] It has a title.

**Every level**
- [ ] Run-in, hub, wings, behind the door (§2).
- [ ] Each wing: a minimal first room, a twist, a combination, an exam with the Key orb, and a way back.
- [ ] A calm room after each set piece.
- [ ] One relic with four slots in the four kinds of hiding place; one golden feather in the first room.
- [ ] Exactly one Goal, behind the Grand door; every Key light has its orb.
- [ ] `find_problems()` is empty and the built-levels smoke test passes.
- [ ] Added to `levels/story.tres` only when the developer says so.

## 11. Lessons log

Add a dated line here whenever a play-test or a correction from the developer teaches something this guide didn't have.

- 16 Nov 2026 (Fire level, canopy): a fallen plank lying flat across two rims has its top 4 px over the floor, and planks are one-way: walking off the ledge passes in under its edge and drops you into the gap. Cut a one-tile notch in the NEAR rim under the plank's end: it lies as a gentle slope, under the floor at the near end and over it at the far end, walked across with no hop.
- 16 Nov 2026 (Fire level, canopy): a weight that must stay on a plate shouldn't land on the walking path: the player has to hop it and can push it off (shutting the door). Sink the plate in a slot one tile deep: the crate drops in, can't be pushed out, and is only a one-tile hop.
- 16 Nov 2026 (Fire level): a door in a wall two tiles thick only clears its own tile: the tile behind it must be left open, or the open door leads into rock. A test that only checks `wants_open` misses it: walk through every door in the test.
- 16 Nov 2026 (Fire level): rooms meet by map position, so a wing can only open where nothing else is behind the hub's wall. The Wildfire ledge moved up because the run-in's last room is behind the hub's lower left wall. Check what's on the map behind a wall before putting a wing's gap in it.
- 16 Nov 2026 (Fire level): a brazier on a shelf wider than itself can't be lit by a 45-degree fireball from below: the ball meets the shelf's corner first (fireballs fly almost straight). A shelf under a brazier starts right under it. Also measured: the jet's reach (in tools/build_fire_level.gd's header).
- 16 Nov 2026: a test that teleports the player (`respawn_at`) resets the room like a death: lit braziers go out, taken diamonds come back. Move the player without a respawn inside a room whose state the test builds up.
- 16 Nov 2026: calculated reaches were off by up to 20% and one room could not be crossed; a simulated-keys check caught it before any play-test (§6). Measure, don't calculate.
- 16 Nov 2026: a side-gust only helps a glide if the glide starts DURING the recoil (within a few frames). A late glide gets almost nothing from it. Rooms that need "gust, then glide" should say so on a sign.
- 16 Nov 2026: the developer asked for a room of fire sentries in the Air enemy wing, wanting fast projectiles and reflection to be a real challenge. Enemy wings should end harder than "reflect one slow orb".
- 17 Nov 2026 (Air level, Currents): a wind zone pushes the player when ANY part of the 11 px body overlaps it, not only the feet: keep a band's edge 2 tiles clear of a floor you want to be out of it. Walking off a ledge and pressing Jump within about 6 frames is a coyote JUMP, not a glide; the glide only starts about 10 frames later, after a fall of about 35 px, so a "walk off and glide" route needs a floor over 35 px lower within about 7 tiles. A headwind (10 px/s net glide) can't be crossed or dodged in a 31-row room; use tailwinds, and test every "stalls you" claim with keys. A test that falls into a void leaves a delayed respawn that moves the player after the next `_stand`: wait 2.5 s after a death.
