---
description: Import the project and run every smoke test that exists, report PASS/FAIL
---

Run the full health check **through the `test-runner` agent** (Agent tool, `subagent_type: "test-runner"`), so the test output stays out of this conversation. It already knows the Godot path and the list of smoke tests (Air, Earth, Earth chapter, Fire, Fire chapter once it exists, editor).

0. If `$ARGUMENTS` is empty or says "changed"/"relevant", first ask the `test-selector` agent (`subagent_type: "test-selector"`) which tests the current change needs, and pass its list to `test-runner`. Say "all" in `$ARGUMENTS` to skip this and run everything.
1. Prompt it: "Run the import check and all smoke tests that exist; report the table and every ERROR/SCRIPT ERROR line." If I named specific tests in `$ARGUMENTS`, pass only those.
2. Relay its table to me: test, PASS/FAIL, and for failures the first failing line.
3. Never say "all good" if its report quotes any ERROR / SCRIPT ERROR line, even when the test printed PASS. Quote the line.
4. Don't fix anything unless I ask; just report, and say what you suspect. If I ask to investigate a failure, hand it to the `godot-debugger` agent first.
5. If the agent isn't available (e.g. not loaded in this session), fall back to running the commands yourself: `godot --headless --path . --import`, then `godot --headless --path . <scene>` for each test in `tests/*_smoke_test.tscn`, with `godot` = `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.
