# Backdrop guide: how to build (or revise) a look

The rules and lessons from the eleven looks built so far (mountain, temple, forest, desert, underwater, jungle, shore, volcano, sanctum, deepwood, cavern). `/backdrop` follows this guide step by step; any session touching `scenes/backdrop/` should read it first. The code's own headers (`backdrop.gd`, `backdrop_theme.gd`, `backdrop_paint.gd`, `backdrop_terrain.gd`) explain the mechanics; this file explains **what makes a look good** and **what a new look must touch**.

Models to copy:
- **Jungle**: the classic painted style (`BackdropPaint`), and the big front leaves the developer liked best.
- **Sanctum**: the ground's own style (`BackdropTerrain`), with faint platforms far back and a sparse, nature-first scatter of buildings (its own `buildings.gd`).
- **Underwater**: a look whose underground changes SOFTLY, because there's no ground to break through.

---

## 1. What a look is

- A **look** is one setting (a biome) seen at three **altitudes**: UNDERGROUND, SURFACE and SKYLINE. That makes three scripts, `themes/<look>/{underground,surface,skyline}.gd`, each extending `BackdropTheme` and adding layers far to near in `_build_layers()`.
- A fourth script, `themes/<look>/style.gd` (`class_name <Look>Style`, `extends RefCounted`, static only), holds what the three share:
  - colors;
  - the TALL painters;
  - `add_shared_layers(theme, section)`;
  - the helpers for the big shapes.
- If one kind of detail grows big (sanctum's temples), it gets its own file next to the style (`buildings.gd`).
- Every picture is a seamless **strip**, 640×260. The screen shows rows 40–220 at rest; the spare rows above and below absorb vertical parallax and the soft seam. Use `BackdropPaint.row(screen_y)` and `tall_row(screen_y, section)`, never raw numbers.
- Pictures are painted once per run and cached. `RoomManager` paints every look a level uses when it loads (`Backdrop.paint_ahead`), so painting may be slow-ish (a fraction of a second), but `draw_extra` callbacks run **every frame** and must stay cheap.

## 2. The rules the developer set (non-negotiable)

1. **Celeste-like, in our art style.** Flat shapes, a bright rim on every top, lit faces upper-left, colors in a few hard BANDS with a 1–2 row checker dither between them (never smooth gradients). Far layers are hazier: pulled toward the look's air color, never just darker.
2. **One scene per look.** The three altitudes must read as ONE place seen from three heights. Anything tall (sky, a far range, giant trees, a cloud or canopy bank, towers, kelp) is a TALL layer (`add_tall_layer`), painted once over the stacked altitudes and sliced, so a summit in the skyline is the same mountain whose flanks rise in the surface view. Check this with the `_column.png` shot.
3. **Surface ↔ skyline: nothing pops.** The surface and the skyline share **every** layer, in the same order with the same scrolls, through `<Look>Style.add_shared_layers`. A layer only one of them paints is a split layer (`add_split_layer`): in the other view it sits just off screen and scrolls in. Near things that would end in a straight cut at the seam fade out in a dither (`fade_sections`). The developer checked this on every look; it was the biggest round of rework.
4. **Underground ↔ surface: a BREAK** through a band of the look's own rock (set `crust_colors` in `underground.gd` to that rock's [body, lit rim]), because you break out of the ground. The exception is a look with no ground to break, which goes in `Backdrop.SOFT_UNDERGROUND_LOOKS` and shares its tall layers over all three altitudes (underwater).
5. **A FOREGROUND in every altitude:** big dark shapes right in front (huge leaves and fronds, pine boughs, kelp, dead trees, crags, ivy, a fallen arch stone), with the scroll every look uses, `FRONT_SCROLL = Vector2(0.62, 0.18)` in its style. "In the rainforest I really liked the bigger leaves in the front. Make more things like that." Keep them dark and at the screen's edges and corners, never across the middle.
6. **The play layer reads first.** The backdrop is darker or paler and lower in contrast than the ground and objects, so nothing in it looks walkable. Faint platforms far back are welcome (sanctum, deepwood), but they're hazed well toward the air.
7. **Depth through many rows.** Deepwood has four rows of trees, each with its own scroll and more haze, and mist bands between them. More parallax rows read as more depth; one big flat layer does not.
8. **Alive, a little.** Motes (`BackdropMotes`: DOT, STREAK, BUBBLE, LEAF, FIREFLY, BIRD), light shafts (`draw_light_shafts`, which breathe), glows (`draw_glow`), drifting mist (`drift_speed`). Two or three moving things per altitude is plenty.
9. **Sparse and natural.** "The air temple should be a lot more nature vibe, like a sparse scatter of temples on some cliffs." Buildings and props are accents on the landscape, not the subject.
10. **Main color.** `Backdrop.get_main_color` averages a look's layers; the depth layers behind the play layer are hazed toward it. An altitude whose layers average to something odd (a bright sun disc, a huge saturated foreground) makes rooms behind look wrong. Keep each altitude's overall tone coherent: darker underground, lighter skyline.

## 3. The two painting styles

- **Painted** (`BackdropPaint`): ridges, mesas, bumps, mountains with rims and hatch, clouds, puffs, crags, leaves, fronds, leaf clumps, shards, cones, caves. The first eight looks use it. Quick to write; reads like Celeste's backgrounds.
- **Ground style** (`BackdropTerrain`): build a `Mask` (`new_mask` / `new_band`, then `add_rect`, `add_circle`, `add_line`, `add_chunk`, `add_below`), `roughen` it, then `paint(image, mask, palette, crust_width, fade, hatch, seed)`. The palette has six colors: [crust, rim, edge, inside, hatch, deep]. Extras: `paint_blades` (grass), `paint_hanging` (moss and roots), `paint_clump_tops` (crowns). Far versions use `hazed(palette, AIR, amount)`. It looks like the game's own terrain; sanctum and deepwood use it. Slower to paint, so mind the load time (§6).
- Mixing is fine: a painted sky with ground-style cliffs.

## 4. Conventions in the code

- **Names.**
  - The style's `const NAME: String = "<look>"` keys the tall cache.
  - Layer names are unique within a look: Sky, FarPeaks, CloudSea, Cliffs, Mist, Near, Front...
- **Scroll factors grow far to near.** Typical values:
  - sky: about 0.01;
  - far rows: 0.04–0.16;
  - mid layers: 0.2–0.36;
  - front: `FRONT_SCROLL`, 0.62 x 0.18 in every look.
  - The y factor is about a third of the x factor.
  - A tall or split layer must have the **same** scroll in every altitude that shows it, which `add_shared_layers` guarantees.
- **Seeds.** Every random call takes a seed. Give each look its own thousand-block so looks never share noise: sanctum is 4xxx and deepwood 5xxx, so a new look takes the next free block (6xxx, then 7xxx...).
- **Colors** are named consts in the style or altitude script (`AIR`, `SKY_BANDS`, `FRONT_BODY`, `FRONT_LIT`...), and `far(color, amount)` pulls one toward the air.
- **Whole pixels.** Put `@warning_ignore_start("integer_division")` at the top of painting scripts, `roundi`/`roundf` positions, and draw see-through things in `draw_rect` rows (see `draw_light_shafts`: overlapping triangles double-blend).
- **Headers.** Every script starts with a `##` header saying what the viewer sees, far to near, and where its other altitudes are. The style lists its TALL layers. Keep the headers true after every revision (the style checker catches stale ones).
- **Name clashes.** Don't name a loop variable `wrap`, `range` or other built-ins, and don't name a local `layer` or `offset`: they shadow Godot names and raise warnings.

## 5. What a NEW look must touch

1. `scenes/backdrop/themes/<look>/style.gd`, `underground.gd`, `surface.gd`, `skyline.gd` (class names `<Look>Style`, `<Look>Underground`, `<Look>Surface`, `<Look>Skyline`).
2. `scenes/backdrop/backdrop.gd`:
   - Add the look **at the END** of `enum Look` (rooms save the number, not the name).
   - Add its entry in `THEME_SCRIPTS`.
   - Name it in the header's LOOK list.
   - If it has no ground to break, add it to `SOFT_UNDERGROUND_LOOKS`. If its SURFACE is still inside the ground (cavern), add it to `BREAK_SKYLINE_LOOKS`: underground <-> surface is then soft (share tall layers over those two, like underwater) and the break is out to the skyline; set `crust_colors` in the surface and underground scripts.
   - The preview (K), the map's backdrop menu, the property panel and `tools/screenshot_backdrops.gd` all read the enum and `THEME_SCRIPTS`, so they need nothing.
3. AUTO looks (`Room.get_backdrop_theme` in `room_base.gd`) pick only from room contents (water, fire, earth, else mountain). A new look is chosen by hand, so leave AUTO alone unless the developer asks.
4. **Docs:**
   - `GAME_DESIGN.md` §2 (the Backdrops paragraph: the look list, its underground and skyline names, the look count);
   - `Level_editor.md` (the backdrop_theme list);
   - `CLAUDE.md` (the backdrop folder line: look names and count);
   - `GAME_SUMMARY.md` if it lists looks.
5. `tests/editor_smoke_test.gd` L17 checks the backdrop machinery, not every look. Add a check only if the look adds new machinery (a new transition rule, a new BackdropTheme helper).

## 6. Checking a look

- **Screenshots** (windowed, since headless draws nothing):
  `godot --path . res://tools/screenshot_backdrops.tscn -- <scratchpad folder> <look>`
  - `<look>_<altitude>_a/_b.png`: at rest, and with the camera moved, to check parallax and seams.
  - `<look>_column.png`: skyline over surface over underground. Does it read as ONE scene?
  - `<look>_soft.png`: halfway from surface to skyline. Does nothing pop or end in a cut?
  - `<look>_break.png` (or `_ground_soft.png`): halfway out of the ground.

  View the PNGs yourself and judge them against §2 before showing the developer; send the ones that matter with SendUserFile.
- **In the game:** K in the level editor opens the backdrop preview. Left/Right picks the look, Up/Down changes altitude (with the real transitions), and Space stops the drift.
- **Repeating strip:** the strip repeats every 640 px, so check the `_b` shot for an obvious repeat or a seam.
- **Load time:** painting runs once per look at level load. If a ground-style look grows heavy (many masks, big `roughen` areas), time each painter (`Time.get_ticks_usec()` before and after it, in a throwaway `extends SceneTree` script run with `--script`), and keep the whole look to a second or two: sanctum and deepwood take about a second, the cavern about 2 s (§7).
- **Tests:** the import check, then `editor_smoke_test` with `-d`. Grep the output for WARNINGs in `scenes/backdrop/`; there must be none. Use the test-runner and style-checker agents.

## 7. Lessons from the developer's play-tests

- **Transitions (first round):** the changes between looks used to fade, and the developer wanted them to scroll ("a scroll of the same background"). That became SOFT and BREAK.
- **One scene per look (second round):** the developer asked for each biome to "almost read like one scene", which led to the style.gd files and the tall layers. Surface to skyline had a hard border, and the fix was to share every layer.
- **Popping:** things popping out of nowhere at the surface/skyline seam were the most common complaint, so check every split layer.
- **Front shapes:** the big front leaves were the most liked detail, so every look now has front shapes.
- **Ground style:** the "terrain style" (ground-style painting) was asked for by name for the two newest looks, along with faint platforms in the back.
- **Detail:** for sanctum and deepwood the developer said "take your time getting details right"; quality over speed is expected here.
- **Frames within frames (cavern):** rows of separate columns read as thin poles. What the developer asked for instead was "several layers of depth" with background platforms "stretching from the top of the screen to its bottom": walls of rock that are mostly openings (one per slot in each view), each framing the walls behind, with ledges and slopes inside the openings. A wall that's mostly solid becomes a flat dark mass.
- **Depth in the dark (cavern):** the developer wanted the deep "much darker", with the farthest layer pitch black and a creepy carved face so faint the player hardly notices it. So far walls are hazed toward the air (pitch black down there) and swallowed by it; the deep reads by the nearer walls' faint rims, and a hidden thing gets a tiny live detail (dim red pinpricks swelling in the face's sockets) instead of more brightness. `CavernStyle.sink_into_air` hazes toward the air *at each pixel's own height* with `Image.blend_rect_mask` (fast), so one wall can be lit at the top and black at the bottom.
- **Altitudes must differ in shape, not just light (cavern):** sharing the walls kept the deep and the upper cave one cave, but with the same round openings they looked alike. The deep cuts the same walls into tall chasms with sheer, slowly wandering cliff faces and no floor. Random per-step edges read as bricks; a slow noise down the height reads as cliffs.
- **Load time:** a full-height ground-style wall costs about 0.25 s to paint (`BackdropTerrain.paint`'s distance pass), so the cavern's four walls make about 2 s at level load, once per run.

## 8. Revising a look

- Change the painter, not the cache: textures are cached per run (`texture_cache`, `tall_cache`), so restart the game or preview after an edit.
- When moving something between altitudes, keep the shared-layer order and scrolls identical in surface and skyline.
- Re-shoot only that look (`-- <folder> <look>`) and compare the before and after shots side by side.
