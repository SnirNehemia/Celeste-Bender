---
description: Run one build stage from PROMPTS.md (usage: /stage 3)
argument-hint: <stage number>
---

Run **Stage $ARGUMENTS** of the build plan.

1. Read `CLAUDE.md`, `GAME_DESIGN.md` and `PROMPTS.md`.
2. Check the Progress list in `PROMPTS.md`. If an earlier stage isn't ticked, tell me and ask whether to continue anyway.
3. If this stage isn't Stage 0, run a quick tools check: is a Godot MCP server available (`claude mcp list`)? If not, say so and offer to set it up using the steps in Stage 0 Part A, but don't block on it.
4. For a big stage, show me a short plan first and wait for my OK.
5. Do the stage exactly as written in `PROMPTS.md`, following all rules in `CLAUDE.md`.
6. Check for errors (Godot MCP if available, otherwise the headless commands in CLAUDE.md).
7. End with: the test checklist, the explanation bullets, and a suggested commit message.
8. Only after I confirm it works in play, tick this stage in the Progress list.
