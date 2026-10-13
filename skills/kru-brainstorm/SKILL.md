---
name: kru-brainstorm
description: Grill an idea like `/kru-brief` does, grounded in the current codebase, and write nothing. On the user's go, the settled answers become the brief.
disable-model-invocation: true
argument-hint: "<the idea — half-formed is fine>"
---

`/kru-brief` without the pen. Same grill, same codebase grounding, **nothing written** until the user says go — so an idea can be tried on and dropped at no cost.

Read `$ARGUMENTS`; empty → ask one line ("What's the idea?") and stop.

## Grill

Read `${CURSOR_PLUGIN_ROOT}/skills/kru-brief/SKILL.md` and run its preamble, §1 and §2 on the idea, read-only: §1's deletions and rewrites wait for the go.

**Write nothing** — no repo file, no store entry, no builder dispatched. Every settled answer lives in the session and is the hand-off.

When the frontier is empty, or the user stops answering, one line: *nothing's saved — say go to write it as a brief, or `/kru-todo` to park it.*

## Go

The user's go ("go", "brief it") is the only thing that writes. Run the brief's §1 writes, then §3 and §4, with the grill's settled answers as `Decisions resolved` — none re-asked. A frontier still open at the go runs as brief rounds first.
