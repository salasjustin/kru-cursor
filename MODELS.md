# Models — what each seat runs on in Cursor

Upstream kru pins every seat to a full Claude model id and argues each tier in `ROSTER.md` → *Model
tiers*. Cursor serves the same three models under the same ids, so this fork keeps upstream's tiers
seat for seat — the reasoning in `ROSTER.md` holds unchanged — and translates the two frontmatter
keys Cursor reads differently. `scripts/port.mjs` writes every seat's `model:` line; nothing is
edited by hand.

## The map

| upstream `model:` (+ `effort:`) | Cursor `model:` | seats |
|---|---|---|
| `claude-opus-5-5` | `claude-opus-5-5` | 30 — the builders, the data, auth, payments and platform seats, `ux-designer`, `ui-designer`, `brand-designer`, `conversion-copywriter` |
| `claude-opus-5-5` + `effort: high` | `claude-opus-5-5[effort=high]` | `code-reviewer`, `architecture-reviewer`, `planner`, `ux-auditor` |
| `claude-sonnet-5-5` | `claude-sonnet-5-5` | `test-writer`, `visual-reviewer`, `accessibility-reviewer`, `graphic-designer` |
| `claude-sonnet-5-5` + `effort: medium` | `claude-sonnet-5-5[effort=medium]` | `toolchain-engineer`, `vercel-perf-optimizer` |
| `claude-haiku-5-5` + `effort: medium` | `claude-haiku-5-5[effort=medium]` | `dispatch-auditor` |
| — (main thread) | the conversation's model | the lead (`kru-lead` skill) |

List prices per 1M tokens on Cursor (input / output): Opus 5.5 $4 / $20, Sonnet 5.5 $2 / $10,
Haiku 5.5 $0.10 / $0.50 (above 100k input tokens Haiku bills 5×). Fable 5.1 ($10 / $50) is pinned to
no seat, for upstream's reason. A named third-party model draws from Cursor's *Other Models* pool
even when the parent chat runs on Auto or Composer.

## The translations

- **`effort:` → model parameters.** Upstream's `effort: high|medium` is a Claude Code agent key.
  Cursor sets reasoning effort as a parameter on the model id — `id[effort=high]` — which is the
  documented home for it (`cursor.com/docs/subagents` → *Model parameters*). The values upstream
  uses are the ones Cursor's examples show.
- **`experimental.cacheTtl`** (the 1h prompt cache upstream sets on re-dispatched seats) has no
  Cursor equivalent and is dropped; Cursor manages caching itself.
- **Model aliases.** Upstream already refuses the floating `opus`/`sonnet`/`haiku` aliases; the port
  maps one to its full id if a merge ever brings one back, and refuses an id outside
  `CURSOR_MODELS` in `scripts/port.mjs`.

## What Cursor does with the pin

- **The docs:** a custom subagent's `model` is honored unless an admin blocks the model, a legacy
  request-based plan needs Max Mode for it, or the plan doesn't include it — then Cursor falls back
  to a compatible model (`cursor.com/docs/subagents` → *When the configured model won't be used*).
  The parent agent can also name a model when it launches a subagent.
- **The CLI as installed here** (`cursor-agent 2026.10.01-e373342`): its loader for a *plugin's*
  agents strips `model` (and `tools`) and runs them on `inherit` — the parent's model — while it
  honors `model` on project and user agents (`.cursor/agents/`, `~/.cursor/agents/`). Read off the
  shipped bundle (`stripModel: true` in the plugin-agent loader), not documented. So in that CLI a
  kru seat runs on the conversation's model, and the tiers above apply where Cursor reads plugin
  agents' `model` (the documented behavior). Copying `agents/*.md` into a repo's `.cursor/agents/`
  is the way to force the pins in that CLI, at the cost of a second copy that drifts.
- **Unverified here:** that each id resolves on a given account. `cursor-agent models` lists them,
  and needs a signed-in CLI, which this port was built without (`PORTING.md` → *Local test*). The
  ids are read off Cursor's models pages (`cursor.com/docs/models/claude-opus-5-5`, `…-sonnet-5-5`,
  `…-haiku-5-5`) and the fast-mode id `claude-opus-5-5-fast` on the pricing page.

## Retiering

One edit: change the seat's upstream `model:`/`effort:` (that is upstream's file, so the change rides
a merge) — or, to diverge from upstream on purpose, add the override to `portAgents()` in
`scripts/port.mjs` and say why here. Then `node scripts/port.mjs && bash scripts/verify.sh`.

## Sources

- `cursor.com/docs/subagents` — the `model` field, `inherit`, model parameters, fallback rules.
- `cursor.com/docs/models-and-pricing` — ids, rates, the Other Models pool.
- `cursor-agent` 2026.10.01-e373342, `index.js` — the plugin-agent loader (`stripModel`, `stripTools`,
  `permissionMode`).
