---
name: kru-todos-loop
description: Build parked wants back to back without a gate — each its own commit — until the branch's changed-file count reaches the cap; product calls are held for the end.
disable-model-invocation: true
argument-hint: "[max changed files, default 80]"
---

`/kru-todos` with the gate lifted. The loop is `${CURSOR_PLUGIN_ROOT}/references/backlog-loop.md` — read it first and run it end to end; this file fills in the want half. `${CURSOR_PLUGIN_ROOT}/skills/kru-todos/SKILL.md` is the procedure it reuses by section; its bucket, score, rank and outcome definitions hold here unchanged.

- **Branch**: `feat/todos-loop-<date>`.
- **Queue**: `todos` §1 and §2 over the whole file and the product repo's open GitHub issues labelled `enhancement` (`gh issue list --label enhancement --state open`), its §4 bookkeeping, ranked by its §3 order.
- **Eligible**: open, `value` `3`–`5`, `effort` `1`–`3`, and `pitched`. A GitHub `enhancement` issue is a want the PM filed, so it counts as `pitched`, and its `value`, `urgency` and `effort` are the digits in its body. A `discovered` line is the team's own capture and waits for the user to pull it, per `todos` → *Guardrails*; count it with the unreached. A `~` value is the team's guess at what the user wants, so it qualifies only at `4`–`5`.
- **Held, on top of the shared bar**: a want whose line leaves open what it does for the person using it — the build would have to pick the feature, which is `/kru-brief`'s grill, not a guess.
- **Outcomes**: `todos` §5's — *built* · *already done* · *bigger than its effort* (rescored in place, left parked).
- **Report**: each built want as what someone using the product now gets. Every `~` value or urgency the run built on is listed under *Questions for the PM* for the PM bot to confirm, so the guess becomes its number.
