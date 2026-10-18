# Models — what each seat runs on in Cursor

Upstream kru pins every seat to a Claude model and argues each tier in `ROSTER.md` → *Model tiers*.
This fork keeps those tiers where Claude is still the right call, moves five seats onto models
Cursor serves that fit their work better or cost less, and records a fallback for every seat.
`scripts/port.mjs` holds the data — `CONFIRMED_MODELS` (every id a seat may use, each with the page
it was read from), `SEAT_MODELS` (the fork's picks, each with its fallback) and `TIER_FALLBACK`
(the fallback for a seat left on upstream's pin) — and writes every seat's `model:` line. No agent
file is edited by hand. `node scripts/port.mjs --list-models --seats` prints the map below.

## The map

| seat | model | fallback | why | source |
|---|---|---|---|---|
| `code-reviewer`, `architecture-reviewer`, `planner`, `ux-auditor` | `claude-opus-5-5[effort=high]` | `gpt-5.6-sol` | judgment seats: what they return *is* the judgment, so they get the strongest tier at high effort (upstream's reasoning, unchanged). Fable 5.1 stays unpinned for upstream's reason (2.5× the price). Fallback: GPT-5.6 Sol is the same price band ($4 / $20) from another provider | [opus-5-5](https://cursor.com/docs/models/claude-opus-5-5), [gpt-5-6-sol](https://cursor.com/docs/models/gpt-5-6-sol) |
| the other 25 seats on upstream's Opus pin — builders, data, auth, payments, platform, `conversion-copywriter`, `svelte-ui-builder` | `claude-opus-5-5` | `gpt-5.6-sol` | correctness on money, auth, migrations and deploys; upstream's per-seat case in `ROSTER.md` holds | [opus-5-5](https://cursor.com/docs/models/claude-opus-5-5), [gpt-5-6-sol](https://cursor.com/docs/models/gpt-5-6-sol) |
| `react-ui-builder`, `web-components-builder` | `kimi-k3` | `claude-opus-5-5` | the component seats move to Kimi K3 (Moonshot, Cursor's *Other Models* pool, $3 / $15 — under Opus's $4 / $20). `web-components-builder` writes a public API, so a defect it ships re-pins it to the fallback | [kimi-k3](https://cursor.com/docs/models/kimi-k3) |
| `test-writer` | `grok-4.7` | `claude-sonnet-5-5` | coverage sweeps and suite repair: long, bounded, self-checking work. Grok 4.7 draws from the *Cursor Models* pool ($2 / $6, more included usage, no Cursor Token Rate on Teams) | [grok-4-7](https://cursor.com/docs/models/grok-4-7) |
| `toolchain-engineer`, `vercel-perf-optimizer` | `grok-4.7[effort=medium]` | `claude-sonnet-5-5[effort=medium]` | checklist work against documented conventions; medium effort as upstream pins it. Grok 4.7 lists `medium` among its four effort levels | [grok-4-7](https://cursor.com/docs/models/grok-4-7) |
| `accessibility-reviewer`, `visual-reviewer` | `claude-sonnet-5-5` | `grok-4.7` | upstream's tier: restraint-heavy review. `visual-reviewer` stays off Kimi K3 — it judges screenshots, and Kimi K3's page doesn't claim vision beyond the generic "images for vision-capable models" line | [sonnet-5-5](https://cursor.com/docs/models/claude-sonnet-5-5) |
| `dispatch-auditor` | `claude-haiku-5-5[effort=medium]` | `composer-2.5[fast=false]` | checklist seat that fires every turn: the cheapest model on the list ($0.10 / $0.50) | [haiku-5-5](https://cursor.com/docs/models/claude-haiku-5-5) |
| the lead (`kru-lead` skill) | the conversation's model | — | main thread, not settable from a file | — |

`svelte-ui-builder` stays on Opus: it is outside the two component seats the fork moved to Kimi K3, and its
loop runs on the Svelte MCP's autofixer, which the model doesn't change. Moving it is one line in
`SEAT_MODELS`.

### Confirmed ids

Every id below was read verbatim as the page's **Model ID** on 2026-10-13. An id not in this list
is refused by the port and by `scripts/verify.sh` (*seat models are confirmed cursor ids*).

| id | page | pool, list price per 1M tokens (input / output) |
|---|---|---|
| `claude-opus-5-5` | cursor.com/docs/models/claude-opus-5-5 | Other Models, $4 / $20 |
| `claude-sonnet-5-5` | cursor.com/docs/models/claude-sonnet-5-5 | Other Models, $2 / $10 |
| `claude-haiku-5-5` | cursor.com/docs/models/claude-haiku-5-5 | Other Models, $0.10 / $0.50 |
| `claude-fable-5-1` | cursor.com/docs/models/claude-fable-5-1 | Other Models, $10 / $50 (no seat) |
| `grok-4.7` | cursor.com/docs/models/grok-4-7 | Cursor Models, $2 / $6 (fast $4 / $12) |
| `composer-2.5` | cursor.com/docs/models/cursor-composer-2-5 | Cursor Models, $0.50 / $2.50 (fast $3 / $15) |
| `kimi-k3` | cursor.com/docs/models/kimi-k3 | Other Models, $3 / $15 |
| `gpt-5.6-sol` | cursor.com/docs/models/gpt-5-6-sol | Other Models, $4 / $20 (fallback only) |
| `gemini-3.1-pro` | cursor.com/docs/models/gemini-3-1-pro | Other Models, $2 / $12 (no seat) |
| `inherit` | cursor.com/docs/subagents → Configuration fields | the parent's model |

Prices from `cursor.com/docs/models-and-pricing`. A named third-party model draws from *Other
Models* even when the parent chat runs on Auto, Grok or Composer; Grok and Composer are exempt from
the Teams Cursor Token Rate. On the Start plan (India) there is no *Other Models* pool, so only the
Grok and Composer seats run as pinned there.

The installed CLI (`cursor-agent` 2026.10.01-e373342) carries no model list of its own — `cursor-agent
models` fetches it and needs a signed-in CLI, which this box doesn't have — so no id here was
confirmed against the CLI. The one slug the bundle names is `composer-2.5` (it maps `composer-2` to
it).

## Fallbacks

Cursor's frontmatter takes one model, so a fallback is not something Cursor reads. It works at two
levels:

1. **In the port.** When a pick's id drops out of `CONFIRMED_MODELS` (a model retired from Cursor's
   docs), the port writes the seat's fallback instead and says so, and fails only when the fallback
   isn't confirmed either.
2. **By hand, on a plan or admin that doesn't serve the pick.** Cursor itself falls back to "a
   compatible model" when an admin blocks the pinned one, the plan lacks it, or a legacy plan needs
   Max Mode for it (`cursor.com/docs/subagents` → *When the configured model won't be used*). To pin
   the recorded fallback instead, swap the two entries in `SEAT_MODELS`.

## What Cursor does with the pin

- **The docs:** a custom subagent's `model` is honored except in the three cases above; the parent
  agent can also name a model when it launches a subagent, and the task card shows which model ran.
- **The CLI as installed here** (`cursor-agent 2026.10.01-e373342`, re-checked 2026-10-13): its loader
  for a *plugin's* agents drops `model` and `tools` (`fu(e, {stripModel: true, stripTools: true})`)
  and builds each with `model: "inherit"`, reading read-only from `permissionMode`. Project and user
  agents (`.cursor/agents/`, `~/.cursor/agents/`) keep their `model`. So in that CLI every kru seat
  runs on the conversation's model; the pins apply where Cursor reads a plugin agent's `model`, which
  is the documented behavior. The pins stay: they are right for the documented loader, and `inherit`
  is what the CLI substitutes anyway. Copying `agents/*.md` into a repo's `.cursor/agents/` forces
  them in that CLI, at the cost of a copy that drifts.
- **Not verified on an account:** that each id resolves for a given plan. That needs a signed-in CLI.

## The translations

- **`effort:` → model parameters.** Upstream's `effort: high|medium` becomes `id[effort=…]`, Cursor's
  documented home for it (`cursor.com/docs/subagents` → *Model parameters*).
- **`experimental.cacheTtl`** has no Cursor equivalent and is dropped.
- **Model aliases.** A floating `opus`/`sonnet`/`haiku` a merge brings back maps to its full id.

## The asset generator's xAI backend

The asset generator (`scripts/asset/gen-asset.ts`) gains an xAI backend for stills and
edits (`scripts/asset/xai.mjs`, hand-owned; the hook into the generator is port rules):

- **Endpoint and models**, from docs.x.ai → *Inference API → Images* and *Model Capabilities → Image
  Generation*: `POST https://api.x.ai/v1/images/generations` (edits: `/v1/images/edits`, the source as
  a base64 data URL in `image.url`), `response_format: "b64_json"`, `aspect_ratio`, `resolution`
  (`1k`/`2k`), `quality` (`low`/`medium`/`auto`, `grok-imagine-image-2.0` only). Pick
  `grok-imagine-image-2.0`; fallback `grok-imagine-image` (1.0), tried when the API rejects the model.
  `grok-imagine-image-quality` is not used: xAI retires that slug on 2026-11-02.
- **When it runs:** `XAI_API_KEY` is set and the run is a still or an edit with no Google `--model`
  (or a `grok-imagine-*` one). `--backend google` opts out. Video (Veo) and cutouts (rembg) stay on
  the existing path, and with no `XAI_API_KEY` every run takes the existing Google backend.
- **The key** is read from the environment only, sent in the `Authorization` header, never logged;
  error messages carry the status and the response body, never the request.
- **Tested:** request building, backend choice and model fallback against a mocked fetch
  (`node --test scripts/asset/xai.test.mjs`, in `verify.sh`), and a dry run of the full generator
  with `fetch` stubbed. **The live call is untested** — no xAI key on the build machine.

## Retiering

Edit `SEAT_MODELS` (or `TIER_FALLBACK`) in `scripts/port.mjs` and the row above, then
`node scripts/port.mjs && bash scripts/verify.sh`. A new id goes into `CONFIRMED_MODELS` with the
page it was read from, and only once a page shows it verbatim.

## Sources

- `cursor.com/docs/models-and-pricing` — the pools, list prices, the Token Rate.
- `cursor.com/docs/models/<model>` — each id (the pages linked in *Confirmed ids*).
- `cursor.com/docs/subagents` — the `model` field, `inherit`, model parameters (`effort`, `fast`),
  when the configured model won't be used.
- `cursor-agent` 2026.10.01-e373342, `index.js` — the plugin-agent loader (`stripModel`, `stripTools`,
  `permissionMode`) and the `composer-2` → `composer-2.5` mapping.
- `docs.x.ai/developers/rest-api-reference/inference/images.md`,
  `docs.x.ai/developers/model-capabilities/images/generation.md`,
  `docs.x.ai/developers/migration/imagine-image-quality-nov-2.md` — the image API, its models, the
  retirement.
