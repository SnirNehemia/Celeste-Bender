---
description: Close out a stage: full tests, style check, docs sync, palette check, commit message (usage: /wrapup W7b)
argument-hint: <stage id, e.g. W7b, F11, L4>
---

Wrap up **Stage $ARGUMENTS**. Run this only after I've said the stage works in play (or I ask for it). Do the steps in order and don't commit anything.

1. **What the stage changed.** `git status --short` and `git diff --stat HEAD` (plus untracked files). Read the stage's text in `PROMPTS.md` (and the element's design doc section) so you know what *should* be there.
2. **Full tests.** This is the one place every test runs: `test-runner` agent with "Run the import check and all smoke tests that exist, including the full water_smoke_test". Also ask it for a `-d` run of the stage's own test and to list every `WARNING` line.
3. **Style.** `style-checker` agent on the stage's changed files. Fix clear violations myself after showing them to you in a short list; leave judgement calls for you.
4. **Water budget** (Water stages, or any stage that touched `scenes/objects/water/`): `perf-checker` agent. Flag any section over 2 ms or more than 15% slower than the last logged run.
5. **Palette (rule 7).** For every new placeable object or terrain layer in the diff, check `scenes/editor/palette_catalog.gd` has an entry (and `palette_icons.gd` an icon if the others have one). List any missing.
6. **Docs sync.** Edit, keeping each file's existing style and length:
   - `CLAUDE.md`: Folder layout (new files go in the tree or the element's "built so far" paragraph; move paths out of "still to come"), Input (new actions), Running and checking (new test sections, new build commands).
   - `GAME_SUMMARY.md`: a few lines for what the stage added.
   - The element's design doc: only if the build differed from the spec — add a short "Built in Stage X" note, never rewrite the spec.
   - `PLAYTEST_LOG.md`: mark this stage's open items as fixed/kept/parked.
   - `PROMPTS.md` Progress: tick the stage only if I confirmed it in play.
7. **Report** (short): the test table, warnings, style fixes made and left, budget line, palette gaps, the docs you edited (one line each), and a suggested commit message in the style of `git log --oneline -5` (e.g. "Stage W5: freeze and ice, play-test 5").

If any test fails or prints ERROR, stop after step 2, report it and offer to send it to `godot-debugger`. Don't update docs for a stage that isn't green.
