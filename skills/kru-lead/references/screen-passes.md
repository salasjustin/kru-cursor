# The screen passes — what they are, how to brief them, and what stays the user's

Detail behind `SKILL.md` → Step 4, *Screen passes*. Reached on UI work; a non-UI change never loads this.

## The two passes have seats, and you dispatch them

`visual-reviewer` and `accessibility-reviewer` are review-only agents whose entire body is the corresponding skill file — same rules, same output, same boundaries, read from the one copy. **Two callers, one body:** the user still types `/kru-visual-review` · `/kru-accessibility-review` and gets the pass inline; you spawn the seat and get it in an isolated context, after the source-reading gates and one browser at a time (`gates.md` → the batch).

**Conformance is the repo's own gate**, written in Phase 0 and run at every commit (`${CURSOR_PLUGIN_ROOT}/references/ui-handoff.md` → *Conformance is prevented, not detected*) — so an off-token value is already a failing test by the time a pass could look, and neither seat here is briefed for one.

What that reversal does **not** touch is what a pass may conclude. `visual-reviewer` returns **breakage and causes, never a verdict on intent** — whether the build looks like the design stays the user's glance, and it's prevented upstream by a closed token file (*Conformance is prevented, not detected*, `${CURSOR_PLUGIN_ROOT}/references/ui-handoff.md`). Dispatching the pass buys you coverage and rule violations; it does not buy you the design gate, and it never replaces the user's look.

## Mockup layout (before the PM)

When the target is a **mockup** — `.dc.html` or a `/canvas` publish from `kru-ui-designer` or `/kru-design` — brief `kru-visual-reviewer` for **mockup layout**, not the Step 4 coverage matrix. Viewports: **each artboard at its stated width** (desktop **1440**, mobile **375**; never a desktop file at 375). The drafter already ran `composition` → *The pass*; this seat **renders and measures independently** — verify the pass **done-when** and every **Check** in the loaded `skills/kru-composition/reference/` entries, cited by section name. Every finding names **selector or `file:line`** and **measured px**. The lead serves artboards at `http://localhost:4400/…` (`python3 -m http.server 4400 -d .design-work`); the seat still never starts a server. On **FIX**, route defects to `kru-ui-designer` and re-dispatch (three reviewer passes, `gates.md`). This pass does not judge whether the design is right — only whether composition checks fail.

## Brief them for coverage and cause, because that's the only part they win

The user has already seen the happy path in their own window. What nobody has rendered is the empty state, the error state, loading, disabled, focus-visible, 375, and the row with the 90-character string — so **name the states you want reached** in the handoff, and treat "no one has ever seen this screen" as a finding when it comes back.

The other half is tracing: a defect the user spots in a second costs them an hour to locate, and this seat returns it as a `file:line` with a scope.

What `visual-reviewer` no longer does is table numbers — tap targets are `accessibility-reviewer`'s, off-token values are the repo gate's, and asking this seat for them buys a browser-priced duplicate. **Contrast is nobody's**: the design decided it and it ships as authored, so neither seat reports a ratio and neither one is briefed for one.

Three things bound the batch:

- **Cost** — `visual-reviewer` drives a browser for minutes; run it on a slice that renders, not on every commit, and hand it the target pages **and the states you want reached** rather than "the app."
- **No report path** — review seats run `readonly` in this fork, so each returns inline under its own caps (`gates.md`).
- **The return is the record, not the message** — `accessibility-review`'s issue, keyboard and screen-reader tables stay in the report; the user hears who is blocked from what ("keyboard users can't reach Save"), the rest counted in one clause. The same goes for the file:line tables the animation passes below produce.
- **Run the suite first on a token-shaped defect** — a literal hex or an off-scale value is already a failing test, and finding it in a browser costs a hundred times more.

## The lead-owned passes

These have no seat and you never dispatch them. They are lead-owned, the list in `SKILL.md` → *Delegate on stack, not size*: they run in the main thread when the user names one, on the target they name, and that does not open the closed inline list:

- `/kru-seo-review` — technical SEO/AEO audit, markup fixes on request.
- `/kru-copywriting` · `/kru-copy-editing` · `/kru-cro` — rewrite a marketing page's copy · line edit · conversion audit of an underperforming page/form. All three act on a page that already ships; a marketing page that has *not been written yet* is `conversion-copywriter`'s, routed before design or build (`${CURSOR_PLUGIN_ROOT}/references/routing.md`).
- `/kru-review-animations` · `/kru-improve-animations` — motion craft review · prioritized motion roadmap.

These are cheap to run after the fact and each carries its own **taste** — which is exactly why they are lead-owned, and named by the user, when the two screen passes are not: a copy rewrite or a motion roadmap is a preference, and dispatching one as a gate means the team quietly editing the user's voice.

These act on words that exist. The words themselves arrive earlier: a marketing page's argument and strings are `conversion-copywriter`'s, written before the page is designed or built, and what these passes then edit is a deck the user already approved rather than text a builder invented. On every other surface a builder still ships working draft text, checked the way visuals and motion are — by the user, when they care. Copy for lay/client audiences explains deliverables by what they're for, not by category label (learned preference). In-product microcopy stays `ux-designer`/`ux-copy`'s lane; technical SEO markup stays `/kru-seo-review`'s; channels/campaigns stay out of scope (`ROSTER.md`).
