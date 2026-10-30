---
description: Turn my play-test notes into bugs, tuning changes and design questions, and log them (usage: /playtest <my notes>)
argument-hint: <play-test notes, free text>
---

My play-test notes: $ARGUMENTS

1. **Context.** Which stage is current (`PROMPTS.md` Progress, `git log --oneline -3`) and which rooms the notes mention. Read `PLAYTEST_LOG.md` (create it if missing, with a `# Play-test log` title and one `## <stage> · play-test <n> · <date>` section per session, newest first) so you see what was already tried, and say so if a note repeats an old one.
2. **Sort each note** into one of these:
   - **Bug**: something behaves wrongly (stuck, falls through, wrong state, crash). Each bug goes to the `godot-debugger` agent (one bug per call, parallel when they're independent; include the room, the keys pressed and what I saw).
   - **Tuning**: feel is off but the mechanic is right ("jump feels floaty", "ice too slippery"). Find the exact `@export` in `resources/*_tuning.gd` (grep the name and its comment), its current value in the `.tres`, and propose a new value with a one-line reason. If no tuning field covers it, it's a magic number in code: say where, and propose moving it into the tuning resource.
   - **Design**: the mechanic itself should change, or the note conflicts with the design doc. Quote the relevant line from the element's design doc and propose an alternative (CLAUDE.md rule 8). Don't build it.
   - **Unclear**: ask me one short question about it.
3. **Show me a table** before changing anything: # | note (my words, short) | kind | proposed change. Wait for my OK, or for me to pick which ones.
4. **Apply** the approved ones: debugger fixes in the main conversation (explain each in the usual bullets), tuning in the `.tres` (not in code). Then `test-selector` -> `test-runner` for the touched areas.
5. **Log** in `PLAYTEST_LOG.md`, under a new section for this session: each note with its kind and status (fixed / tuned old -> new / parked / question / won't fix + why). Keep entries to one line.
6. End with the test checklist for what changed: what to press, what I should see.
