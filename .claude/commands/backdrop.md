---
description: Build a new backdrop look or revise one (usage: /backdrop new <name> <brief>, /backdrop <look> <change>)
argument-hint: new <name> <brief> | <existing look> <what to change>
---

Backdrop work: **$ARGUMENTS**. If the first word is `new`, build a new look named by the second word from the brief that follows. Otherwise the first word is an existing look (mountain, temple, forest, desert, underwater, jungle, shore, volcano, sanctum, deepwood...) and the rest is the change I want.

**First read `BACKDROP_GUIDE.md` in full**: its §2 rules are what I judge looks by. Then read the model looks it names (jungle, sanctum, underwater: each one's `style.gd` and one altitude script) and, for a revision, every script of the look being changed. Follow CLAUDE.md's code style and explain-as-you-go rules.

## A new look

1. **Agree on the brief with me** (AskUserQuestion, one round, up to 4 questions; skip any my brief already answers):
   - **Setting and mood:** the place, its time of day, light or dark, and how it differs from the existing looks it's closest to.
   - **The three altitudes:** what UNDERGROUND, SURFACE and SKYLINE each are (for example, sanctum is an undercroft, cliffs over a cloud sea, and cliff tops), and what TALL things tie them into one scene.
   - **Style:** painted (`BackdropPaint`, like jungle), ground style (`BackdropTerrain`, like sanctum), or mixed; faint platforms in the back or not.
   - **The foreground shapes and the moving things:** motes, shafts, glows, drift.
   - Also settle whether the underground BREAKS through rock or changes SOFTLY (only if there's no ground to break, like underwater).

   Then write the plan in 5–8 lines and go on without waiting: the tall layers, each altitude's layers far to near, the palette (air color, bands, front colors), and the seed block (guide §4).
2. **Shared style and the surface first.** Write `style.gd` (colors, the tall painters, `add_shared_layers`) and `surface.gd`. Register the look in `backdrop.gd` (guide §5: at the END of the enum, plus `THEME_SCRIPTS`). Give `underground.gd` and `skyline.gd` minimal working versions so the look loads: the shared layers plus a placeholder.
3. **Check, then show me.** Run the import check. Then take shots: `godot --path . res://tools/screenshot_backdrops.tscn -- <scratchpad>/<look>_shots <look>`. View the surface `_a` and `_b` PNGs and judge them against guide §2:
   - Does the play layer read first?
   - Is there a foreground in front?
   - Is there depth through rows?
   - Is there a visible repeat?

   Fix what fails, then send me the surface shots (SendUserFile) with 3–5 lines on what's in them. **Stop and ask whether to go on** (AskUserQuestion: go on / changes first).
4. **Skyline and underground**, after my OK and any changes. Check the shared layers carefully: every surface-only layer must reach the skyline as a split layer, and vice versa, with `fade_sections` where near things would end in a cut. Set the underground's `crust_colors`.
5. **The whole look.** Shoot it again, and view `_column.png` (one scene?), `_soft.png` (does anything pop or end in a straight cut at the seam?) and `_break.png` / `_ground_soft.png`. Fix, re-shoot, then send me the column, the soft shot and each altitude's `_a`.
6. **Wrap up:**
   - Update the docs (guide §5.4).
   - Run `editor_smoke_test` with `-d` through the test-runner agent (no WARNINGs under `scenes/backdrop/`), and run the style-checker agent on the new files.
   - If painting got heavy, time it (guide §6).
   - Add anything new this look taught us to `BACKDROP_GUIDE.md` §7, in one or two lines.

## A revision

1. If the change is unclear, ask (AskUserQuestion, one round). Otherwise, say in 2–3 lines what you'll change and in which layers.
2. Take before shots of the look into the scratchpad, make the change, then take after shots.
3. View before and after, and check guide §2 rules 3 and 4 if the change touches a shared or split layer. Send me the pairs that show the change.
4. Run the tests and the style check as in step 6 above, keep the script headers true, and add any new lesson to the guide's §7.

## Always end with

- **How to test:** open the level editor, press K, choose the look with Left/Right, press Up/Down to move through the altitudes and watch the changes, and say what I should see.
- **3–6 bullets** on what you built and why, naming any Godot concept the first time it appears.
- A suggested commit message. Don't commit.
