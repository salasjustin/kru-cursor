# The screen passes — what they are, how to brief them, and what stays lead-owned

Detail for **PM-named** screen passes and Step 5 acceptance checks. The lead **does not** dispatch these in Step 4; list screens and flows for the PM on the preview unless the **task names** a pass or seat explicitly.

## The two passes have seats — PM or task invokes them

`kru-visual-reviewer` and `kru-accessibility-reviewer` are review-only agents whose entire body is the corresponding skill file — same rules, same output, same boundaries, read from the one copy. **Two callers, one body:** the lead or agent loads `skills/kru-visual-review/SKILL.md` or `skills/kru-accessibility-review/SKILL.md` (`Read`, or `/kru-visual-review` / `/kru-accessibility-review` when invoked) for an inline sweep, or dispatches `kru-visual-reviewer` / `kru-accessibility-reviewer` when the task names the seat — not an automatic Step 4 batch.

**Conformance is the repo's own gate**, written in Phase 0 and run at every commit (`${CURSOR_PLUGIN_ROOT}/references/ui-handoff.md` → *Conformance is prevented, not detected*) — so an off-token value is already a failing test by the time a pass could look, and neither seat here is briefed for one.

## Brief `kru-visual-reviewer` for spec match and coverage

Hand it:

1. **Approved mockups** — paths or URLs for the screens in the slice, at the frames engineering must match.
2. **Build spec pointer** — file or link from the PM brief.
3. **Target** — URLs/pages and the states the spec names that mockups do not show.
4. **Report path** — per `gates.md`.

The seat compares the running UI to the mockups at **1440** and **375**. Mismatches are **FIX** findings for the builder. It still covers empty/error/loading/disabled/focus and traces breakage to `file:line`.

Without mockups in the brief, the seat returns that spec match cannot run; you should have stopped at Step 3's design spec gate.

`kru-accessibility-reviewer` is unchanged — structural WCAG; contrast ratios are not recomputed.

Three things bound the batch:

- **Cost** — `kru-visual-reviewer` drives a browser for minutes; run on slices that render, with explicit pages and spec pointers.
- **No report path** — review seats run `readonly` in this fork, so each returns inline under its own caps (`gates.md`).
- **Run the suite first on a token-shaped defect** — literals and off-scale values belong in the repo gate, not the browser.

## The lead-owned passes

These have no seat and you never dispatch them. They are lead-owned, the list in `SKILL.md` → *Delegate on stack, not size*: they run in the main thread when the user names one, and that does not open the closed inline list:

- `skills/kru-seo-review/SKILL.md` — technical SEO/AEO audit, markup fixes on request.
- `skills/kru-copywriting/SKILL.md` (PM loads when the task names it) · `skills/kru-copy-editing/SKILL.md` (PM loads when the task names it) · `skills/kru-cro/SKILL.md` (PM loads when the task names it) — on copy that already ships. A page not yet written is `kru-conversion-copywriter`'s, routed before design (to the external designer) or build.
- `skills/kru-review-animations/SKILL.md` · `skills/kru-improve-animations/SKILL.md` — motion craft review · roadmap (PM or lead `Read` when the task names that pass).

Marketing copy for new pages: `kru-conversion-copywriter` → PM → designer mockups → PM spec → engineering. In-product microcopy and flows: design spec only; technical SEO: `skills/kru-seo-review/SKILL.md`.
