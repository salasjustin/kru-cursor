---
name: kru-issue
description: Open a defect file in the project's plan store from what the user just said, un-investigated. The user's front door to issues/, for when no task is running to sweep from.
disable-model-invocation: true
argument-hint: "<what's wrong>"
---

Write the defect file from what the user just told you and get out. They hit something *wrong* and want it recorded before it evaporates. See `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *`issues/`* for the artifact's lifecycle — you don't need to read it to run this.

**Zero-derail.** Record and go straight back to whatever was in flight. Inline; spawn nothing.

**A stub on purpose, and legible as one.** No `Explore`, no reading the code to find call sites, no repro attempt, no root-cause theory, no blast-radius trace — and above all **you do not fix the bug**. The investigation a full write-up wants is a real read pass, and spending it here turns "I hit a bug" into work nobody asked for. So record what the user knows and mark every field you didn't investigate as `_not investigated_` **in the file**. That marker is load-bearing: an unanchored claim that *looks* investigated is exactly the failure `issues/` exists to prevent, and an obvious stub is safer than a confident one.

## Do

1. **Read `$ARGUMENTS`** — what's wrong. If empty, ask one line ("What's wrong?") and stop.
2. **Glance at `issues/`** (`ls`, nothing more). Same defect already has a file → append the user's new detail to it and stop. One directory listing isn't investigation; two files for one bug is drift.
3. **Write the file `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" path issues/<kebab-slug>` names.** **No precondition**: create the dir if it isn't there.

   ```markdown
   ---
   severity: medium
   urgency: ~3
   ---
   # <what's wrong, one line — the symptom a user sees, in the user's framing>

   **Observed:** <what they said happens, in their words>
   **Call sites:** _not investigated_
   **Root cause:** _not investigated_
   **Repro:** _not investigated_
   **Blast radius:** _not investigated_
   **Fix options:** _not investigated_
   ```

   Take `severity` from the user when they state it, else `medium` — and name which in the confirm line so they can correct it in one word. Never infer severity from how alarmed the message sounds. `urgency` (`TRACKER.md` anchors) is bare when they said how soon ("before launch", "whenever"), else `~3`.
4. **What the user already supplied fills its field.** They named a `file:line`, or said how to reproduce it? Write it in and drop that field's marker — recording what you were told isn't investigation. This skill skips *finding*, not *keeping*. Cite `file:line` for anything they gave you: the write-up sits outside the repo, so an unanchored reference is unfollowable.
5. **Confirm in one line** — "logged as <severity>, needed <urgency in words>; not looked into yet." No path. Pass through whatever `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" where` prints, which is usually nothing. Then straight back to whatever was in flight.

## Don't

- **Don't take a non-defect.** Something merely *wanted* — a feature, a refactor, a cleanup, duplication, misfiled config — is `/kru-todo`'s line, not a defect file. The store's three-way split holds: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`**. Say in one line which you did.
- Don't fix it, and don't offer a fix. Filling the file in is a normal `/kru-lead <task>`; fixing it deletes the file in that same change, along with the repro test that replaces it (`lead` Step 4.5).
- Write through the resolver, never by hand (`TRACKER.md`, `${CURSOR_PLUGIN_ROOT}/references/store.md`).
