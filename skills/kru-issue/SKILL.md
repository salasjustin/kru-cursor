---
name: kru-issue
description: Record a defect from what the PM just said, un-investigated. A normal bug goes to the work tracker. A security finding stays in the store on GitHub; on Linear it goes to Linear, internal to the team, and what is filed follows *Tracker text* in TRACKER.md. The PM's front door for when no task is running to sweep from.
disable-model-invocation: true
argument-hint: "<what's wrong>"
---

Record the defect from what the PM just told you and get out — on the work tracker (`bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh"`), or, for a security finding, as a store file. On Linear it also goes to Linear, internal to the team. What you write follows *Tracker text* (`${CURSOR_PLUGIN_ROOT}/TRACKER.md`). They hit something *wrong* and want it recorded before it evaporates. See `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *`issues/`* for the artifact's lifecycle — you don't need to read it to run this.

**Zero-derail.** Record and go straight back to whatever was in flight. Inline; spawn nothing.

**A stub on purpose, and legible as one.** No `Explore`, no reading the code to find call sites, no repro attempt, no root-cause theory, no blast-radius trace — and above all **you do not fix the bug**. The investigation a full write-up wants is a real read pass, and spending it here turns "I hit a bug" into work nobody asked for. So record what the user knows and mark every field you didn't investigate as `_not investigated_` **in the file**. That marker is load-bearing: an unanchored claim that *looks* investigated is exactly the failure `issues/` exists to prevent, and an obvious stub is safer than a confident one.

## Do

1. **Read `$ARGUMENTS`** — what's wrong. If empty, ask one line ("What's wrong?") and stop.
2. **Pick the destination from what you were told.** Security-shaped — anything an attacker could use: an auth bypass, data exposure, an injection, a leaked secret — or unsure → a security finding. On the GitHub tracker that is the store file (step 3 on) and never the work tracker. On the Linear tracker it goes to Linear, internal to the team, and the evidence stays in the store file (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Security on Linear*). What you write follows *Tracker text* (`${CURSOR_PLUGIN_ROOT}/TRACKER.md`). When Linear MCP tools are connected, file with `save_issue` (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*) and do not call the script: a missing `LINEAR_API_KEY` is not exit 4 and not a reason to skip Linear. When they are not connected, run `file --kind security` only if `ready` exits 0; on exit 4 the store file is the only record and the confirm line says why (`ready` writes it). Still write the store file either way. On the tracker that security issue is a short title and a link to the file, not the template's Repro, Root cause, or Exploit sections. Otherwise a normal bug → the work tracker. When `backend` is `linear` and Linear MCP tools are connected, use them (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*) and do not treat a missing `LINEAR_API_KEY` as a reason to use the store. Otherwise, when `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh" ready` exits 0, use the script; else the store file, and the confirm line says why (`ready` writes it).
   - **Tracker, for a normal bug:** On Linear with MCP tools connected, do this glance, comment and file through those tools (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*). Otherwise glance for the same bug (`bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh" search --kind bug --query "<two words from the symptom>"`, nothing more). One hit → add the new detail (`comment --id <id> --body "<the new detail>"`) and stop. None, or more than one → `file --kind bug --title "<the symptom, one line>" --body "<the template below, minus the frontmatter, with severity and urgency as its first line>"`. It prints the id and the url separated by a tab. On GitHub it drops a label `gh` refuses and says so. Then step 5. bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand
3. **Glance at `issues/`** (`ls`, nothing more). Same defect already has a file → append the new detail to it and stop. One directory listing isn't investigation; two files for one bug is drift. Else **write the file `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" path issues/<kebab-slug>` names.** **No precondition**: create the dir if it isn't there.

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

   Take `severity` from the user when they state it, else `medium` — and name which in the confirm line so they can correct it in one word. Never infer severity from how alarmed the message sounds. `urgency` (`TRACKER.md` anchors) is bare when they said how soon ("before launch", "whenever"), else `~3`. The template above is the store file. A bug or want on the tracker may carry its plain repro, symptoms and call sites. A security issue on the tracker does not use the template.
4. **What the user already supplied fills its field.** They named a `file:line`, or said how to reproduce it? Write it in and drop that field's marker — recording what you were told isn't investigation. This skill skips *finding*, not *keeping*. Cite `file:line` for anything they gave you: the write-up sits outside the repo, so an unanchored reference is unfollowable.
5. **Confirm in one line** — "logged as <severity>, needed <urgency in words>; not looked into yet", with the tracker id when it went to the work tracker, and no path when it went to the store. Pass through whatever `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" where` prints, which is usually nothing. Then straight back to whatever was in flight.

## Don't

- **Don't take a non-defect.** Something merely *wanted* — a feature, a refactor, a cleanup, duplication, misfiled config — is `/kru-todo`'s line, not a defect file. The split holds: **wrong → the work tracker (security: `issues/` on GitHub; on Linear, internal to the team, text that follows *Tracker text*), wanted → `/kru-todo`, unformed → `notes/`**. Say in one line which you did.
- **Tracker text.** bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand. Name the defect and point at the store file.
- Don't fix it, and don't offer a fix. Filling it in is a normal `/kru-lead <task>`; fixing it puts the line `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh" link --id <id>` prints on the pull request (and closes a Linear issue through MCP `save_issue` with `state` `Done` when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*), otherwise `close --id <id>`) or deletes the file in that same change, along with the repro test that replaces it (`lead` Step 4.5).
- Write through the resolver, never by hand (`TRACKER.md`, `${CURSOR_PLUGIN_ROOT}/references/store.md`).
