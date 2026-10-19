# kru plugin update log

## 0.159.0

**Handoff gate, grouping.** Stays a **shadow** hint (logged to the refusal log, dispatch still allowed). Reasons quote the file path; a bare directory name logs as `grouping-mention` (low confidence). Briefs that only reference another lane's path (`mounted by` / `leave it`) are not flagged.

**Lead.** Test and spec files route via `references/routing.md` (Block D red-green tests stay with the behavior seat; standalone sweep/browser/harness tests go to the lane owner or `test-writer`). Handoff item 3 names cross-seat contracts (shared class, prop, or rebind rule) instead of leaving them open.

**Skills.** `modern-css` defensive corpus: mix Tailwind v4 `lab()` colour steps `in oklab`. `panda-css`: `@fontsource-variable/*` tokens must use the published `font-family` string, not the npm package name.

## 0.158.0

Reflect look-back no longer dispatches `code-reviewer`, `architecture-reviewer`, or the browser review seats. Stack owners re-read their lanes against official sources; remediation builds skip the gates.md review loop.

PM acceptance: the lead ends with Step 5 (builder evidence or unproven, PR/preview/CI, product-visible checklist on the preview, known gaps). Builders verify what a user could not confirm from the product alone (tests, lint, typecheck, edge cases, data/backend, in-process checks). Product-visible checks are the PM's — not lead Step 4 dispatch of `visual-reviewer` / `accessibility-reviewer` / `ux-auditor` unless the task names them.

In-build Step 4 no longer dispatches `code-reviewer` or `architecture-reviewer` (or the built-in code-review fast path). Seam questions load `codebase-design` on the main thread when the task asks; correctness and structure review run only when the PM names those seats.

## 0.157.0

Agent invocation: PM bots and cloud agents load skills by path; hooks treat `Read` of `skills/kru-lead/SKILL.md` as the lead contract. Stalls return batches and product gates to the caller. Descriptions are triggers; `argument-hint` removed. Model invocation only on narrow branches for `setup`, `improve-animations`, `seo-review`, `remember`, and the backlog loops.

## 0.156.0

Design seats removed from engineering roster; external designer owns flows, mockups, and brand.
