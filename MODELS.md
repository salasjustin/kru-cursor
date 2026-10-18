# Models — what each seat runs on in Cursor

Upstream kru pins every seat to a Claude model and argues each tier in `ROSTER.md` → *Model tiers*.
This fork keeps those *roles* (judgment, builder, mechanical) but pins every seat to a
non-Anthropic model Cursor documents in subagent frontmatter. `scripts/port.mjs` holds the data —
`CONFIRMED_MODELS` (every id a seat may use, each with the page it was read from), `SEAT_MODELS`
(every seat's pick and fallback) — and writes every seat's `model:` line. No agent file is edited
by hand. `node scripts/port.mjs --list-models --seats` prints the map below.

## The map

| seat | model | fallback | why | source |
|---|---|---|---|---|
| `code-reviewer`, `architecture-reviewer`, `planner`, `ux-auditor` | `gpt-5.6-sol[effort=high]` | `gemini-3.1-pro` | judgment seats: what they return *is* the judgment, so they get the strongest non-Anthropic tier at high effort (upstream's reasoning role, new provider). Fallback: Gemini 3.1 Pro is another top-tier model in Cursor's docs | [gpt-5-6-sol](https://cursor.com/docs/models/gpt-5-6-sol), [gemini-3-1-pro](https://cursor.com/docs/models/gemini-3-1-pro) |
| `better-auth-specialist`, `stripe-specialist`, `paypal-specialist`, `nowpayments-specialist`, `chariot-specialist`, `quickbooks-specialist`, `postgres-architect`, `sqlite-architect`, `turso-specialist` | `gpt-5.6-sol[effort=high]` | `gemini-3.1-pro` | money, auth, and migration correctness; same strongest non-Anthropic tier as judgment seats | [gpt-5-6-sol](https://cursor.com/docs/models/gpt-5-6-sol) |
| builders — `cloudflare-builder`, `conversion-copywriter`, `extension-builder`, `fly-platform-engineer`, `go-fullstack-builder`, `hono-builder`, `nextjs-builder`, `node-developer`, `python-developer`, `react-router-builder`, `sanity-builder`, `svelte-ui-builder`, `sveltekit-builder`, `tanstack-start-builder`, `vercel-platform-engineer`, `zapier-specialist` | `composer-2.5[fast=false]` | `grok-4.7` | implementation work: Cursor's Composer standard variant (`fast=false`), not the fast tier | [composer-2-5](https://cursor.com/docs/models/cursor-composer-2-5) |
| `react-ui-builder`, `web-components-builder` | `kimi-k3` | `gpt-5.6-sol` | the component seats stay on Kimi K3 (Moonshot, Cursor's *Other Models* pool). `web-components-builder` writes a public API, so a defect it ships re-pins it to the fallback | [kimi-k3](https://cursor.com/docs/models/kimi-k3) |
| `test-writer` | `grok-4.7` | `composer-2.5[fast=false]` | coverage sweeps and suite repair: long, bounded, self-checking work in Cursor's Grok pool | [grok-4-7](https://cursor.com/docs/models/grok-4-7) |
| `toolchain-engineer`, `vercel-perf-optimizer` | `grok-4.7[effort=medium]` | `composer-2.5[fast=false]` | checklist work against documented conventions; medium effort as upstream pins it | [grok-4-7](https://cursor.com/docs/models/grok-4-7) |
| `accessibility-reviewer`, `visual-reviewer` | `grok-4.7[effort=low]` | `composer-2.5` | upstream's sonnet tier: restraint-heavy review on the fast Grok effort level | [grok-4-7](https://cursor.com/docs/models/grok-4-7) |
| `dispatch-auditor` | `composer-2.5` | `grok-4.7` | checklist seat that fires every turn: Composer's fast tier (default variant) | [composer-2-5](https://cursor.com/docs/models/cursor-composer-2-5) |
| the lead (`kru-lead` skill) | the conversation's model | — | main thread, not settable from a file | — |

Retiering is one row in `SEAT_MODELS` plus the matching row here, then `node scripts/port.mjs && bash scripts/verify.sh`.

### Confirmed ids

Every id below was read verbatim as the page's **Model ID** on 2026-10-18 (Anthropic ids are
omitted on purpose — they must not appear in `agents/`). An id not in this list is refused by the
port and by `scripts/verify.sh` (*seat models are confirmed cursor ids*).

| id | page | pool, list price per 1M tokens (input / output) |
|---|---|---|
| `grok-4.7` | cursor.com/docs/models/grok-4-7 | Cursor Models, $2 / $6 (fast $4 / $12) |
| `composer-2.5` | cursor.com/docs/models/cursor-composer-2-5 | Cursor Models, $0.50 / $2.50 (fast $3 / $15) |
| `kimi-k3` | cursor.com/docs/models/kimi-k3 | Other Models, $3 / $15 |
| `gpt-5.6-sol` | cursor.com/docs/models/gpt-5-6-sol | Other Models, $4 / $20 |
| `gemini-3.1-pro` | cursor.com/docs/models/gemini-3-1-pro | Other Models, $2 / $12 |
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
- **The CLI as installed here** (`cursor-agent` 2026.10.01-e373342, re-checked 2026-10-18): its loader
  for a *plugin's* agents drops `model` and `tools` (`fu(e, {stripModel: true, stripTools: true})`)
  and builds each with `model: "inherit"`, reading read-only from `permissionMode`. Project and user
  agents (`.cursor/agents/`, `~/.cursor/agents/`) keep their `model`. So in that CLI every kru seat
  runs on the conversation's model; the pins apply where Cursor reads a plugin agent's `model`, which
  is the documented behavior. The pins stay: they are right for the documented loader, and `inherit`
  is what the CLI substitutes anyway. Copying `agents/*.md` into a repo's `.cursor/agents/` forces
  them in that CLI, at the cost of a copy that drifts.
- **Not verified on an account:** that each id resolves for a given plan. That needs a signed-in CLI.

## The translations

- **`effort:` → model parameters.** Upstream's `effort: high|medium|low` becomes `id[effort=…]`,
  Cursor's documented home for it (`cursor.com/docs/subagents` → *Model parameters*). Judgment and
  mechanical seats set effort on the non-Anthropic pick; builders use Composer's `fast=false` instead
  of effort.
- **`experimental.cacheTtl`** has no Cursor equivalent and is dropped.
- **Model aliases.** A floating `opus`/`sonnet`/`haiku` a merge brings back maps to its full id when
  the port reads upstream; `SEAT_MODELS` still decides what gets written to `agents/`.

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

Edit `SEAT_MODELS` in `scripts/port.mjs` and the row above, then
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
