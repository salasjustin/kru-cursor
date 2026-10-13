---
name: kru-remember
description: Capture a preference or a liked pattern into the team's cross-project inbox, to be swept back into the team later. The user-facing write half of the preference loop.
disable-model-invocation: true
argument-hint: "<the preference or pattern the user liked>"
---

Park what the user liked into the team's preference inbox so a later `/kru-roster learn` sweep can promote it back into the team. This is the **explicit** capture channel — the team never infers preferences from approval, so this command is how a preference gets banked. See `${CURSOR_PLUGIN_ROOT}/PREFERENCES.md` for the whole loop.

**Zero-derail.** Capture and get back to work — this is a one-line append, not a task. Do it inline; don't spawn anything.

## Do

1. **Read `$ARGUMENTS`** — the thing the user wants remembered. If empty, ask one line ("What should I bank — and is it design, code, or workflow?") and stop — or, headless, bank nothing and say so in the return.
2. **Classify the lane** — `[design]` (visual/UI/motion), `[code]` (API shape, architecture, conventions), or `[workflow]` (how the user wants the team to operate). Infer from context; don't interrogate.
3. **Concrete pattern with code?** If the user is banking an actual snippet/component/layout (not just a stated preference), save the artifact to the file `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" path patterns/<slug>` names (kebab-case slug from the pattern) and index it with `→ patterns/<slug>.md` on the inbox line. A stated preference with no artifact is just the line.
4. **Append one line** to the file `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" path inbox` names (create the dir and the file if missing), in the `PREFERENCES.md` format:

   ```markdown
   - [<lane>] <the preference, tightly worded> — _<source> · <project-slug> · <YYYY-MM-DD>_
   ```

   Project slug = the current repo's dir name (or `—` if none). Date = today. Source is `user:justin` for Justin's words and `pm:<bot>` (`pm:kai`) for a PM bot's — a PM bot's line is a proposal, and Justin's words outrank it at the sweep. Agents append their own lines directly, per the lead's handoff.
5. **Confirm in one line** — echo the banked line, note it'll land in the team on the next `/kru-roster learn` sweep. Pass through whatever `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" where` prints, which is usually nothing. Then return to whatever was in flight.

## Don't

- Don't promote it now — capture is lossless and untriaged; the sweep is the gated step that edits the team.
- How the PM bots themselves operate is not a team preference: it goes to the PM bots' own `remember` skill (`${CURSOR_PLUGIN_ROOT}/PREFERENCES.md` → Tier 1, writer 1). This inbox takes what the seats should carry.
- A preference is **cross-project** and belongs at `inbox` / `patterns/<slug>` — the roots the resolver calls cross-project (`${CURSOR_PLUGIN_ROOT}/references/store.md`). A want, a defect or a decision about *this product* is project-specific plan state and goes through `TRACKER.md` instead.
- Don't dedupe or curate against existing lines — the sweep does that. Just append.
