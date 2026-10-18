<picture>
  <source media="(prefers-color-scheme: dark)" srcset="brand/kru-header-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="brand/kru-header-light.svg">
  <img alt="kru" src="brand/kru-header-light.svg">
</picture>

*(said “crew”)*

**kru for Cursor.** Your engineering department as a Cursor plugin: an engineering lead that scopes,
routes and verifies, 41 specialist subagents it dispatches (React, SvelteKit, Next.js, Postgres,
Stripe, Cloudflare, reviewers, designers…), the skills they work from, and hooks that keep every
handoff honest.

This is a port of [kru](https://github.com/ap-justin/kru) (built for Claude Code) to the
[Cursor plugin format](https://cursor.com/docs/reference/plugins). Same team, same contract, Cursor's
names: seats are custom subagents (`kru-code-reviewer`), skills and commands carry the same prefix
(`/kru-setup`, `/kru-brief`). How the port works and where Cursor differs: [`PORTING.md`](PORTING.md).

## Install
**From the Cursor Marketplace** (once listed): open **Customize**, search for **kru-cursor**,
**Install**, and choose user or project scope.

**From this repo, as a team marketplace** (Teams and Enterprise): **Dashboard → Plugins & MCPs → Add
Marketplace → Import from Repo**, paste this repo's GitHub URL, and add `kru-cursor`. The repo
carries its own `.cursor-plugin/marketplace.json` for that. Set it *Default On* or *Required* to
put it in front of everyone, cloud agents included.

**Locally, to try it or work on it**: copy the plugin into Cursor's local plugin folder and reload.
```sh
git clone https://github.com/salasjustin/kru-cursor
mkdir -p ~/.cursor/plugins/local
cp -R kru-cursor ~/.cursor/plugins/local/kru-cursor   # a copy: a symlink pointing outside the folder is skipped
```
Then **Developer: Reload Window** (or restart Cursor) and check **Customize** for the kru rules,
skills, agents, commands and hooks. The CLI loads it too: `cursor-agent --plugin-dir
~/.cursor/plugins/local/kru-cursor`. On Teams and Enterprise, local plugins need **Allow Local
Plugin Imports** on, and a marketplace install of the same name takes precedence over the local copy.

## Requirements
- **`jq` and `bash`**, for the hooks. Without `jq` every hook fails open: the team still runs, ungated.
- **Model access** to the ids the seats pin (Claude Opus, Sonnet and Haiku 5.5, Kimi K3, Grok 4.7, and
  Composer 2.5; see [`MODELS.md`](MODELS.md) for each seat's fallback). A model your plan or
  admin blocks falls back to a compatible one.
- **The `chrome-devtools` MCP server**, for the visual and accessibility reviewers only; without it
  they audit from source. In `~/.cursor/mcp.json`:
  ```json
  { "mcpServers": { "chrome-devtools": { "command": "npx", "args": ["chrome-devtools-mcp@latest", "--headless=true", "--screenshotFormat=webp", "--screenshotMaxWidth=1440"] } } }
  ```
- **Context7** (`https://mcp.context7.com/mcp`) as an MCP server named `context7`: most seats' official-source chain starts there.
- **Optional, for generated image/video assets:** `GOOGLE_API_KEY` (or `XAI_API_KEY` for stills and
  edits through xAI's Grok Imagine) and Node.js on PATH. Without them
  the `graphic-designer` seat says what's missing and offers a fallback instead of a placeholder.

## First run: `/kru-setup`
In the repo you want the team to work on, type:
```
/kru-setup
```
It reads the repo (stack, framework versions, conventions, test setup, design system) and writes the
answers into the repo's root `AGENTS.md`, so later conversations don't re-derive them. Run it once
per repo, and again when the repo or the plugin moves. On an empty repo it grills the subject and
the stack with you first.

Then just ask: *"add feature Y"*, *"fix Z"*, *"build a landing page for X"*. The lead picks the seats.

## On cloud agents
Cloud agents run the plugin from the marketplace (or team marketplace) it was installed from, never
from a local copy. Three things behave differently there, by Cursor's design:

- **No session-start hook.** Cloud agents skip `sessionStart`, so the once-per-conversation work
  (syncing the store and the `/kru-setup` reminder) runs at the conversation's first tool call
  instead, and an always-on rule (`rules/kru-setup-nudge.mdc`) carries the reminder too.
- **No hooks in the first read-only turns.** Cursor sometimes starts a cloud agent read-only and runs
  no hooks until it can write; the gates start with the first write-capable turn.
- **The plan store moves into the clone** (`<repo>/.kru`) and ships in the branch, because no home dir
  survives the vm. Commit it, or set `KRU_STORE_REPO=<owner>/<repo>` (a private repo you own) as a
  **cloud agent secret** (Dashboard → Cloud Agents → Secrets), and the whole store is cloned at the
  first tool call and pushed at every turn end. [`references/store.md`](references/store.md) → *The store repo*.

`/kru-setup` writes the repo's `.cursor/environment.json` install step so a cloud agent's machine has
the repo's dependencies. A repo that should carry the skills themselves, plugin install or not, uses
the installer in [Cloud agents](#cloud-agents).

## Cloud agents
A Cursor cloud agent loads project skills from `<repo>/.claude/skills/<name>/SKILL.md`, including
files git does not track. It does not load `<repo>/.cursor/skills` or `~/.cursor/skills`.
`scripts/cloud-skills.sh` fills `.claude/skills` and `.claude/agents` from this repo and from
[pstack](https://github.com/cursor/plugins/tree/main/pstack), and copies each agent to
`~/.cursor/agents/` as well, for any repo. Run the installer in the environment install step
only. Subagents load at session start, so the start step is too late for that session.
Cursor loads custom subagents from `.cursor/agents`, `~/.cursor/agents`, and `.claude/agents`
([subagents](https://cursor.com/docs/subagents)). A copy that lands only in the repo mid-session
is not offered to the Task tool for that session, so the home directory has to be filled before
the agent starts:

```sh
curl -fsSL https://raw.githubusercontent.com/salasjustin/kru-cursor/main/scripts/cloud-skills.sh | bash -s --
```

Pass the repo directory when the shell is not already inside it. With no argument the script uses
`git rev-parse --show-toplevel`, then `/workspace`. It shallow-clones `skills/` and `agents/` from
this repo and `pstack/` from `cursor/plugins` (latest `main`) into `~/.cache/kru-cloud-skills`,
copies each skill flat into `.claude/skills/<name>/` and each agent into `.claude/agents/` and
`~/.cursor/agents/`, and overwrites an untracked copy. A name the repo already tracks is left as
it is in the repo. A home agent whose frontmatter `name:` starts with `kru-` is replaced, and a missing home file is copied. An existing home agent whose `name:` is not `kru-*` is left untouched. On a shared name, this repo's copy wins over
pstack. It then lists the registered subagent `name:` values. If none start with `kru-`, it exits
1. Each copied repo path is one line in the checkout's `info/exclude`
(`git rev-parse --git-path info/exclude`), between `# kru-cloud-skills begin` and
`# kru-cloud-skills end`. That block is rewritten on every run. Other exclude lines stay.

A repo that uses this installer must not negate `.claude/skills` or `.claude/agents` in
`.gitignore`. A negation beats `info/exclude`, and the copies would show up as untracked. Repos
align to that contract; the installer does not try to outrank a root gitignore. If the kru clone or
fetch fails, the script warns and exits 1. If the plugins clone or fetch fails, it warns and still
installs the kru seats. The run exits 1 when no registered subagent name starts with `kru-`, so a
plugins failure is not success when no kru seat is on disk.

## What it does in your session
The team is opinionated about process and enforces it with hooks. Each fails open (a crash, a missing
`jq`, a timeout lets the action through), and each interruption below can be turned off.

| When | What happens | Turn it off |
|---|---|---|
| First tool call of a conversation | Syncs the store when `KRU_STORE_REPO` is set; reminds you to run `/kru-setup` in a repo without it | `KRU_NO_STORE_SYNC=1`; the reminder with the lead gate's switch |
| First write, dispatch or command | Blocks once until the lead skill is loaded, so no build starts off-contract. Reads are never blocked | `KRU_NO_LEAD_GATE=1`, or `touch ~/.kru/lead-gate/off` |
| Dispatching a seat | Refuses a brief that carries stale line numbers, restates a rule the seat already has, or leaves a decision open, and logs the refusal | `KRU_NO_GATE=1` |
| During `/kru-brainstorm` | Refuses writes until you say *go* (or *brief it*, or run `/kru-brief`) | — |
| A no-edit seat writes a file | Refused: reviewers and designers run `readonly`; the planner and the dispatch auditor write only through the shell | — |
| A seat returns without its `Return pass:` line | Asked once to run its return pass; a second miss is logged | — |
| End of a turn that dispatched seats | Sends one follow-up asking the lead to run the dispatch auditor over the routing | `KRU_NO_AUDIT=1` |

The switches are environment variables: export them in your shell profile, or add them as cloud
agent secrets. (Cursor plugins have no per-plugin settings for them.)

Two things land inside your repo: `/kru-setup`'s `AGENTS.md` sheet (and the `.cursor/` config it
writes), and, on a cloud agent, the plan store. Everything else stays outside it. Every path is
resolved by `scripts/kru-store.sh`; `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" where` says
where yours is when it isn't the default.

- `~/.kru/management/<project>/`: briefs, plans, tickets, todos, issues, kept at user level so your
  repo stays clean and the plan survives branch churn and a re-clone.
- `~/.kru/inbox.md`, `patterns/`: preferences you bank with `/kru-remember`.
- `~/.kru/refusals.jsonl`: dispatches the handoff gate refused, capped at 500 lines; `/kru-roster learn` reads it.
- `~/.kru/audit/`, `lead-gate/`: per-conversation bookkeeping for the hooks; audit ledgers self-delete after 7 days.
- `${TMPDIR}/kru-cursor-<uid>/`: per-conversation hook state (the lead gate's mark, the brainstorm lock).

Four env vars move it: **`KRU_HOME`** relocates everything (default `~/.kru`), **`KRU_PROJECT`** names
the project's store folder in place of the repo's folder name (so a laptop clone and a cloud clone
agree), **`KRU_PROJECT_STORE`** pins one project's plan store, and **`KRU_STORE_REPO`** syncs the
store through a private git repo. [`references/store.md`](references/store.md) is the whole map.

Bugs and product wants go to the work tracker. **`KRU_TRACKER`** is `github` (the default; unset and
empty count the same) or `linear`. Nothing routes to Linear until a repo sets `KRU_TRACKER=linear`,
**`KRU_LINEAR_TEAM`** to the team key, and **`KRU_LINEAR_PROJECT`** to the project name (for example
`KRU_LINEAR_TEAM=BG` and `KRU_LINEAR_PROJECT=Connector`). Those names are the repo's; this plugin
hard-codes none. When the agent has Linear MCP tools, it uses those. **`LINEAR_API_KEY`** is optional:
the script's API fallback when MCP is not connected, a cloud agent secret if you set one, never a
committed key. Pull requests stay on GitHub and link the Linear issue id. On the GitHub tracker a
security finding stays in the store's `issues/` or a GitHub private security advisory. On Linear it is
a Linear issue (`KRU_LINEAR_SECURITY_TEAM`, or the main team with the label `security`) whose body is
only a description and a pointer to the evidence. [`TRACKER.md`](TRACKER.md) → *Security on Linear*.

## Commands
**Getting started**
- `/kru-setup`: set the team up in this repo. Once per repo, again when the repo or the plugin moves.
- Then ask: "add feature Y", "fix Z", "build a landing page for X". Or `/kru-lead <task>`.

**Coding sessions**
- `/kru-brainstorm <idea>`: grill an idea like `/kru-brief`, nothing saved; say go and it becomes the brief.
- `/kru-brief <subject>`: grill a change and keep the record before building.
- `/kru-copy-deck [<page>]`: write a marketing page's argument and copy before it's designed or built.
- `/kru-todo <the thing>`, `/kru-issue <what's wrong>`: park a want or a defect without breaking the session.
- `/kru-remember <what you liked>`: bank a preference for the team to absorb later.
- `/kru-landed`: after the PR merges, sync back onto the base branch.
- `/kru-text-fix [<path> | <branch> | <pr>]`: every text pass the target earns. The verbs under it run alone too: `/kru-comment-fix`, `/kru-prose-fix`, `/kru-doc-fix`.

**Backlog and tech debt**
- `/kru-reflect [<pr> | <branch> | <commit> | everything]`: every seat looks back over its own lane, then the fixes get scoped, sliced and landed.
- `/kru-todos`, `/kru-issues`: work the backlog; each entry landed is deleted.
- `/kru-issues-loop`, `/kru-todos-loop [<max files>]`: fix defects or build wants one commit at a time until the branch reaches the changed-file cap.
- `/kru-briefs`: check every brief against what shipped.
- `/kru-design-system audit`, `/kru-seo-review`, `/kru-review-animations`, `/kru-improve-animations`, `/kru-design-gallery`, `/kru-ux-review <flow>`: audits on what already ships.

Each command loads the skill of the same name, so the `/` menu may list both; either one runs it.

## Stack
- **UI**: React, Svelte 5, Web Components.
- **Framework**: React Router 7, Next.js App Router, TanStack Start, SvelteKit, Go-served React, Python.
- **Data**: Postgres, SQLite, Turso, Sanity.
- **Auth, payments and accounting**: Better Auth, Stripe, PayPal, Chariot (DAF grants), NOWPayments (crypto), QuickBooks Online.
- **Integrations**: Zapier.
- **Platform**: Vercel, Cloudflare, Fly.io.
- **Tooling**: pnpm, Turborepo, Biome.
- **Packages**: Vite plugins, MCP servers, Node CLIs and small libraries.

The seats behind each layer and how to spawn one directly: [`ROSTER.md`](ROSTER.md). A stack with no
seat is a question the lead brings to you before it guesses.

## Working on the plugin
`/kru-roster` (hire a seat, author a skill, sweep banked preferences into the seats) **edits the
plugin's own files**: run it in a clone of this repo, not against an installed copy.

This repo tracks upstream kru as a git remote and normalizes what a merge brings in with one
idempotent script:
```sh
git fetch upstream && git merge upstream/main
node scripts/port.mjs           # re-normalize; --check fails when the tree isn't
bash scripts/verify.sh          # every static check, the hook tests and the privacy scan (CI runs it)
```
[`PORTING.md`](PORTING.md) has the layout, every Claude Code construct and what it became here, and
the known gaps.

How the team is structured and grown: `ROSTER.md`. What each stack's official source is: `SOURCES.md`.
The preference loop: `PREFERENCES.md`. The plan store's file format: `TRACKER.md`.

## License
MIT. See [`LICENSE`](LICENSE). Vendored upstream skills keep their own licenses; see [`NOTICE`](NOTICE).
