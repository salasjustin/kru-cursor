---
name: kru-issues-loop
description: Fix known defects back to back without a gate — each fix its own commit — until the branch's changed-file count reaches the cap; product calls are held for the end.
disable-model-invocation: true
argument-hint: "[max changed files, default 80]"
---

`/kru-issues` with the gate lifted. The loop is `${CURSOR_PLUGIN_ROOT}/references/backlog-loop.md` — read it first and run it end to end; this file fills in the defect half. `${CURSOR_PLUGIN_ROOT}/skills/kru-issues/SKILL.md` is the procedure it reuses by section; its bucket, rank and outcome definitions hold here unchanged.

- **Branch**: `fix/issues-loop-<date>`.
- **Queue**: `issues` §1 and §2 over the whole dir, its §4 bookkeeping, ranked by its §3 order.
- **Eligible**: open, `effort` `1`–`3`. As in `issues` §3's weigh, a rare edge case on the money path is held, not fixed.
- **Outcomes**: `issues` §5's — *fixed* (its repro test in the same commit) · *already fixed* · *bigger than its effort* (rescored in place, left open).
- **Report**: each fixed bug as the symptom that's gone for users.
