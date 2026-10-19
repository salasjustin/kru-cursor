---
name: kru-setup
description: Derive this repo's kru sheet when `AGENTS.md` has no `<!-- kru v` stamp, or when the task says to derive, re-derive, or run the `prose` pass alone.
---

The plugin is the **fractional CTO**: one practice, carried across every engagement. What it cannot
carry is the engagement itself — this stack, this token file, this gate, this machine. Those are
**answers**, and a session that re-derives them every time pays twice: once reading the repo, and
again in the routing deliberation it spends reaching a conclusion this repo settled long ago.

This skill runs that derivation once and writes the answers into the repo's `AGENTS.md`,
which loads on every session there with no setup stamp. **They arrive as prose in that file's own
voice** — the file belongs to the repo, and a section that reads as a foreign object is one a human
skips and a later hand-edit works around.

Two jobs: **derive this repo's answers**, and **leave its always-loaded file better than you found
it**. That file is what every session in the repo pays for on every turn, team or no team, and a repo
already carrying its own sediment does not get better because a good section was appended to it.

**The second job runs alone.** A file accretes between setups, and re-deriving a whole sheet to prune
it is a bigger hammer than the pruning needs.

| task scope | run |
|---|---|
| *(none named)* | this repo, both jobs — every step below |
| a repo path | both jobs, there |
| `prose` in the task | the pass alone — every step below not marked *full run*. Read the surface, run the bars over every line already in it, propose the cuts. |
| blank repo / greenfield | no manifest, lockfile or source to derive from — step 1b, then 1c–1e and steps 4–6 |

## Do

### 0. Load the standard
**Load `writing-for-agents`.** Every line you write and every line you touch is always-loaded context
in every session in this repo — the strictest tier that standard governs. Its `SKILL-MECHANICS.md` is
skill-only and stays shut.

Completion: the standard is loaded.

### 1. Derive the sheet — *full run*
Read the repo. Every line **cites what it came from**: a line with no derivation is a guess, and a
re-run has no way to check it.

| Field | Derive from | What it retires |
|---|---|---|
| seat pointers | the repo's dependency manifests and lockfile, run through **`${CURSOR_PLUGIN_ROOT}/references/routing.md`** | that table, on every later session |
| project seats | `.cursor/skills/*`, `.cursor/agents/*` | seats this plugin has no way to know exist |
| `skills` | the same manifests, run through **`${CURSOR_PLUGIN_ROOT}/references/routing.md`** → *Conditional skills* | a seat reading `package.json` for its libraries on every dispatch — and the silence when a seat that never carried the skill writes against the library anyway |
| `tokens` | the design system's file, and the gate that closes it (hook config, test script) | a builder's hunt for the `## Design system` pointer — and the from-scratch design chain, since a system already exists |
| `screens` | whether this repo renders UI, and what starts its dev server | the screen passes and the PM's design-spec gate |
| `test` | the runner, its command, and **what a run costs** | rediscovering the repo's testing conventions |
| `verify` | typecheck and lint commands | the behavior gate's generic form |
| `mcp` | `agent mcp list` and the plugins under **Customize**, against the seats the rows above named and their **`${CURSOR_PLUGIN_ROOT}/SOURCES.md`** rows | a seat reaching mid-run for a server this repo never enabled, and a dispatch spent finding that out |

**Cost is a field.** A runner that spawns a browser per test file, a suite that takes ten minutes, a
machine that swaps under a fan-out — none of it is knowable from the plugin, and it decides whether a
coverage sweep is a scoped run or a stalled one. Where a cost binds, write the bound. Under vitest
the per-file figure is already on disk: `node_modules/.vite/vitest/<hash>/results.json` holds
`{ results: [["<project>:<path>", { duration, failed }]] }` from the last run — test time only, no
startup, and files deleted since are still listed, so read it as a lower bound per file and an upper
bound on the file count.

Prefer a **project seat** over a plugin seat wherever the two overlap: a repo that wrote its own skill
for its own subsystem knows something the plugin does not.

**What the repo knows that a skill lacks goes upstream.** The derivation reads the repo's own testing
docs, configs and `.cursor/skills/*`; where one carries a recipe a plugin skill would need in the next
repo too — a `vitest` gotcha `skills/kru-vitest/` has no row for, a runner cost the skill doesn't state, a
convention its docs are silent on — append it to the file `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" path inbox` names, in
`${CURSOR_PLUGIN_ROOT}/PREFERENCES.md`'s line format: lane `[code]`, source `setup`, citing the repo
file it came from. The sheet still cites the fact for this repo (*The line between the plugin and the
repo*, below).

**A repo a major behind a skill gets a todo.** Each skill the `skills` field names carries its pin on
the *Reproduced on* line beneath its frontmatter — the packages before its `with` are the claims, the
ones after are context. Where the lockfile resolves one of those packages a major below the pin, the
skill is coaching code the repo can't run, so the upgrade is a want: append it to the file
`bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" path todos` names, `discovered`, `plan: —`, value
`~3`, urgency `~2`, effort `~3` per major behind (cap `~5`), one sub-bullet citing the skill's pin line, the
lockfile entry, and the skill's `reference/migration.md` when it has one. A line already there naming
the package is the want, filed — leave it.

**Every other outdated dependency gets a todo too** — `pnpm outdated` (or the stack's equivalent)
names them. Patch and minor bumps file as one catch-up line; each remaining major files as its own,
same fields as above minus the skill pin. The lockfile is the evidence either way.

Completion: every field carries a value with its derivation, or is absent — because this repo has no
answer for it, or because the repo's own docs already are the answer (step 2); every repo-held recipe a
plugin skill lacks has an inbox line; every package a major behind its skill's pin has a todo line, and
every other outdated one is on the catch-up line or its own major's.

### 1b. Blank repo — grill, then deploy — *full run*
Nothing on disk answers step 1, so the PM's task carries the subject and stack, or setup grills one
round and **returns the frontier** for the next invocation. Headless
(`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), take the lanes the task already settled and put each lane it left open under **Questions for the PM** with your recommendation instead of waiting on a round. Load **`grilling`**; each round is one
numbered frontier with recommended answers — do not wait mid-run for replies that are not in the task.

When the task already settled all three — **what we are building**, **stack lanes**, **finalize** —
skip grilling and cite those decisions. Otherwise run **one round** per invocation, then return until
the task carries the answers.

When grilling is complete, **deploy the team**: 1c–1e and steps 4–6 as on a full run, each line citing
the decision it came from (shape in `sheet.md`).

Completion: the sheet holds the decided stack with its seats.

### 1c. Wire what the seats reach for — *full run*
A seat's source chain names an MCP server or a plugin, and both are enabled **per project** — so a repo
that never enabled one leaves that seat holding the tool names and none of the tools. Run
`agent mcp list` and the plugins under **Customize**, diff against what the step-1 seats reach for
(**`${CURSOR_PLUGIN_ROOT}/SOURCES.md`**), and wire the gap.

**Scope is the server's blast radius, not habit.** A server encoding a fact about *this* project —
Sentry, Stripe, an auth provider, a queue — is project-scoped: an entry in the repo's `.cursor/mcp.json`, and
a project-scope install from **Customize** (a user-scope one in a shared repo, so it stays out of
the commit). The cache is one shared copy, so a per-project entry costs a line of JSON rather than disk.
User scope is for a server genuinely reached from every engagement, and that set stays small — today
`kru`, `context7`, `typescript-lsp`, `chrome-devtools`. **Count the footprint before promoting one**:
a config byte-identical across twenty repos is the duplication the project rule prevents, not an
instance of it, and a server sitting in one repo's list out of twenty is a project fact wearing a
user-scope coat.

**The lead's board needs nothing.** Cursor's todo list is always on, so there is no switch to set.

Three that fail with no error:

- **The name is the namespace.** Several seats name `resolve-library-id` (`context7` MCP) /
  `query-docs` in their own tool lists, so Context7 has to be registered under the bare name
  `context7` (user scope, http `https://mcp.context7.com/mcp`). The official plugin namespaces it to
  `*` (`plugin_context7_context7` MCP) —
  that leaves those seats holding entries that resolve to nothing. The claude.ai connector (`MCP claude_ai_Context7__*`) is Claude-only and is not a Cursor failure mode. The Svelte seats name `list-sections`, `get-documentation`, and `svelte-autofixer` (`svelte` MCP) the same way — a Svelte repo registers a bare `svelte` entry in `.cursor/mcp.json` (http `https://mcp.svelte.dev/mcp`) for local Cursor use. Cloud agents only get it once it is added as a team MCP server in the Cursor dashboard (they ignore the repo's `.cursor/mcp.json`).
- **A permission allowlist entry is coupled to that same prefix.** Moving a server between plugin,
  connector and local scope dead-letters every rule naming it: the rule stops matching, nothing
  errors, and the user is re-prompted forever. Re-point the allowlist in the same change that moves
  the server, never after.
- **A language server is not its compiler.** A plugin that declares
  `lspServers` and ships no binary stays inert until `typescript-language-server` is on PATH.
  Verify with an `initialize` handshake — `--version` answers from the compiler and tells you
  nothing about the server. Where a global TypeScript feeds it, pin `typescript@6`: bare `latest`
  resolves to 7.x, the native port, whose `lib/` carries no `tsserver.js`, leaving the stale
  `tsserver` shim on PATH and the LSP nothing to drive. Project-local TypeScript, which the language
  server prefers, is unaffected.

Where an http remote and a stdio `npx -y <pkg>@latest` serve the same server, take the remote — the
stdio form spawns a process per session and re-resolves `@latest` on every start.

Completion: every seat the derivation named can reach the source its row names, or the user has been
told which one it can't and what enabling it would cost.

### 1d. Grant what the team does on every run — *full run*
<!-- hand-owned in kru-cursor (scripts/cursor/setup-1d.md): upstream's section is the non-Cursor settings grammar end to end -->
Two sets of actions repeat in every project, and each prompts until something grants it — with no
error and no log line, so the gap survives by being answered rather than noticed.

**The store, once, at user scope.** The cross-project root is reached from every engagement — the
case the scope rule above reserves, not an instance of the habit it warns about. Run
`bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" home` and write the grants against **what it
prints**. The CLI reads them from `~/.cursor/cli-config.json` → `permissions.allow`
(`cursor.com/docs/cli/reference/permissions`); the editor's auto-run allowlist takes the same shell
commands under **Settings → Agents**.

The rows spell the default root; substitute what `home` printed when it differs.

| grant | covers |
|---|---|
| `Read(~/.kru/**)` · `Write(~/.kru/**)` | a todo appended, a defect file written, a brief rewritten |
| `Shell(rm:<home>/.kru/audit/*)` · `Shell(rm:<home>/.kru/management/*/issues/*)` | the two deletions the contract *mandates* — the audit closeout (`agents/dispatch-auditor.md`) and the defect file a landed fix closes (`skills/kru-lead/references/reconcile.md`) |

Two things decide whether those last rules ever fire:

- **A shell rule matches the command text, not the file it resolves to.** `kru-planner` and
  `kru-dispatch-auditor` are refused the Write tool (`hooks/seat-guard.sh`), so every store write of
  theirs is a shell command — and the rule has to be written in the form the seat actually types.
  Expand `<home>`: a seat writing an absolute path walks straight past a rule spelled with `~`.
- **Write the rules against the root the resolver prints** — a grant against a path the files left
  silently covers nothing. `TRACKER.md` carries why that path and no other, and
  `${CURSOR_PLUGIN_ROOT}/references/store.md` carries the surfaces that move it.
- **A cloud agent reads none of this.** User config stays on the machine. On that surface the
  resolver puts the project half inside the clone, where the agent already works, and the
  cross-project half in the vm's home, which dies with it — unless a store repo is set (below).

**The store repo, when the user runs cloud agents.** A cloud vm's home dies with the run, so
preferences, plans and the seats' repo memory only survive it through `KRU_STORE_REPO` — a private
repo the user owns, which `hooks/store-sync.sh` keeps the home synced to. Check the shell profile
(locally) and the cloud agents' **Secrets** (`cursor.com/dashboard` → Cloud Agents; each secret
reaches the agent as an environment variable). Unset and the user runs cloud agents: offer it. On a
yes, the user adds `KRU_STORE_REPO=<owner>/<store-repo>` as a secret — it is theirs to add, since a
secret written into the repo would be the leak the Secrets tab exists to prevent. The agent clones
the store with the GitHub access the cloud agent already has; where that access doesn't reach a
private store, store-sync prints one line and the run continues on its own copy.

**The work tracker, when the human team watches Linear.** Bugs and product wants stay GitHub
issues until the repo opts in (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*). On a yes, the
user adds `KRU_TRACKER=linear`, `KRU_LINEAR_TEAM` (a team key, for example `BG`), and
`KRU_LINEAR_PROJECT` (a project name, for example `Connector`). Those names are the repo's.
`KRU_LINEAR_SECURITY_TEAM` is optional (for example `SEC`); unset, a security finding uses the
main team and the label `security`. What is filed follows *Tracker text* (`TRACKER.md`). On the
GitHub tracker a security finding stays in the store or a private advisory. Prefer the connected
Linear MCP tools. `LINEAR_API_KEY` is optional, only for the script when those tools are not
connected, and a secret if it is set — never a line in the repo. Pull requests stay on GitHub.
Unset, and GitHub stays the tracker.

**The cloud environment is a record in the repo.** Cursor builds a cloud agent's machine from
`.cursor/environment.json` (`cursor.com/docs/cloud-agent/setup`): its `install` command runs when a
build is made and again when a branch changes the dependencies, so the repo's dependency install
goes there — read off step 1's findings and the repo's own setup doc (`CONTRIBUTING*`, `README*`),
each tool pinned to the version the repo pins. Write it when the repo has none; an existing one is
the repo's, and a missing install step is a line in the report rather than an edit. **Put the
repo's pinned pnpm on the default `PATH` agent shells inherit** — on Cursor's default image the
Corepack shim under `~/.nvm/versions/node/<ver>/bin` wins over `/usr/local/bin`, so symlinking only
into `/usr/local/bin` still leaves `pnpm` 10.x and turbo can fail with `Exec format error` on a
pnpm 12 pin. An `export PATH=…` in `install` does not reach later agent shells: Cursor documents
that a Build keeps disk state only, not exported shell variables ([Cloud agent setup](https://cursor.com/docs/cloud-agent/setup) → *How Builds use the install script*). During `install`, remove the
shim and replace it in the same directory (disk state only; idempotent):

```bash
PNPM_VERSION='<repo pin>' # e.g. 12.0.0 from packageManager or the repo's docs
NODE_BIN="$(dirname "$(command -v node)")"
corepack disable pnpm 2>/dev/null || true
rm -f "$NODE_BIN/pnpm" "$NODE_BIN/pnpx" 2>/dev/null || sudo rm -f "$NODE_BIN/pnpm" "$NODE_BIN/pnpx"
PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
export PNPM_VERSION
if ! [ -x "$PNPM_HOME/bin/pnpm" ] || [ "$("$PNPM_HOME/bin/pnpm" --version 2>/dev/null)" != "$PNPM_VERSION" ]; then
  curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION="$PNPM_VERSION" SHELL=bash bash -s --
fi
EXE="$PNPM_HOME/.tools/pnpm-exe/$PNPM_VERSION/pnpm"
if [ -x "$EXE" ]; then
  KRU_BIN="$HOME/.kru-bin"
  mkdir -p "$KRU_BIN"
  ln -sf "$EXE" "$KRU_BIN/pnpm"
  export PATH="$KRU_BIN:$PATH"
  PATH_PREFIX="$KRU_BIN"
else
  export PATH="$PNPM_HOME/bin:$PATH"
  PATH_PREFIX="$PNPM_HOME/bin"
fi
```

In the same `.cursor/environment.json`, persist what agent shells inherit — prepend `PATH_PREFIX`
from the install block to `env.PATH` (for example `"env": { "PATH": "/home/ubuntu/.local/share/pnpm/bin:…" }`
when pnpm 12 laid down no `.tools/pnpm-exe/<ver>/pnpm` binary, or `"PATH": "/home/ubuntu/.kru-bin:…"`
when it did). Link the real binary under `.tools/pnpm-exe/<ver>/pnpm`, never the `pnpm` wrapper in
`$PNPM_HOME/bin` (the wrapper resolves beside its own path and breaks when linked). pnpm 12's installer
often lays down no `.tools` binary; then `$PNPM_HOME/bin` on `PATH` whole is the fix. Do not append
`PATH` to `~/.bashrc` or `~/.profile` and expect agent shells to pick it up. (`sudo` is passwordless on
Cursor's default image when removing the Corepack shim.) Where the repo uses `packageManager` and
Corepack can activate the pin (`corepack enable pnpm && corepack prepare pnpm@"$PNPM_VERSION"
--activate`), that is an alternative — still run `corepack disable pnpm` first when an old shim is
present. Set `PATH` in a custom `build.dockerfile` when the repo uses one. The team itself
needs no install line: a cloud agent loads kru-cursor from the marketplace or the team marketplace
it was installed from, never from a local copy. Context7 reaches a cloud agent only as a server the
team configured at `cursor.com/agents` — name it in the report when step 1c wired it locally.
Network egress and secrets live in the dashboard, not the repo; the report names any host step 1
read off the repo's `.env*` files and SDK calls, sandbox hosts only.

`KRU_NO_STORE_SYNC=1` turns the sync off for one session. The mechanics and the merge rules:
`${CURSOR_PLUGIN_ROOT}/references/store.md` → *The store repo*.

**The repo's gates, per repo, at project scope.** Step 1 derived `test` and `verify`, and each of
those commands prompts on first use in each repo. They go in the repo's `.cursor/cli.json` →
`permissions.allow` — committed only when the team shares the gate, otherwise kept local.
**Narrow to the commands the sheet names**: `Shell(pnpm:test*)` grants the suite, `Shell(pnpm)`
grants the install and the publish with it. The config file is the record, so no sheet field states
it — an `AGENTS.md` line would be the cache bar 3 rejects.

**The gate before every commit stays the sheet's `verify` line.** Cursor runs no project skill on its
own before a commit, so nothing is written for it: the lead runs the line before each commit it
makes, and a repo that wants it unconditional wires it into its own git hooks.

**Cloud agents: block outbound MCP.** Plugin hooks do not run on cloud agents; only this repo's
`.cursor/hooks.json` does, and connector MCP hooks still do not run there today (verified Oct 2026).
`rules/kru-lead.mdc` is the guard on cloud agents. Copy these files from `${CURSOR_PLUGIN_ROOT}`
into the repo (paths must match the hook commands) before merging hook entries:
`hooks/mcp-outbound-guard.sh`, `scripts/cursor/mcp-outbound-classify.mjs`, and
`scripts/cursor/mcp-outbound-allowlist.mjs`. Merge the `preToolUse` and `beforeMCPExecution` entries
from `${CURSOR_PLUGIN_ROOT}/scripts/cursor/hooks.repo.mcp-guard.json` into `.cursor/hooks.json`
(create the file when the repo has none). Commands are repo-root paths such as
`bash hooks/mcp-outbound-guard.sh` (project hooks run with cwd = the repo root; do not use
`${CURSOR_PLUGIN_ROOT}`). Default-deny policy lives in `scripts/cursor/mcp-outbound-allowlist.mjs`
(reads, drafts, and Linear `save_issue` only). Skip when the repo already carries the same matchers.

**The seats' repo memory, ignored.** The seats carrying Block Q write what they learn about this
repo to `.claude/agent-memory-local/<seat>/` — the path both forks of this team share, kept out of
version control by the repo's `.gitignore`. Add `.claude/agent-memory-local/` to it when no line
already covers the path (`git check-ignore -q .claude/agent-memory-local/x` answers that), so the
first `git add -A` after a build leaves it behind.

Completion: every grant traces to evidence the derivation already produced, the memory path is
ignored, `.cursor/environment.json` carries the install step or the report names why it doesn't,
and the report names what the team may now do unasked (step 6).

### 1e. Encode what the seats would otherwise be told — *full run*
**`${CURSOR_PLUGIN_ROOT}/references/lint-rules.md`** is the catalog of seat rules a check can hold. Take the rows whose stack
step 1 found, diff each against the repo's own config (`biome.json` rules and `plugins`, the
`tsconfig`, `pyproject.toml`'s `[tool.ruff]`/`[tool.mypy]`, `.golangci.yml`, `vite.config.ts`'s `sveltekit({...})`),
and file each unwired row as a slice for its owner — a lint rule is the team's call, not the
user's, and setup's part ends at the filing. The report counts them in one clause.

Completion: every catalog row for this stack is wired or filed as a slice for its owner.

### 2. Read what the repo already says
Open root `AGENTS.md`, nested `AGENTS.md`, and `.cursor/rules/**/*.mdc`. Root `AGENTS.md` and a rule with `alwaysApply: true` load every session; a rule with globs or a description loads only when it matches ([rules](https://cursor.com/docs/rules)). User Rules and Team Rules are not files in the repo — Customize, and the team dashboard. That is the whole always-loaded surface, and reading it in one pass is the vantage
step 3 works from.

Completion: every always-loaded file in the repo is read.

### 3. The bars, and the pass
Seven bars. They govern **the line you add and the line already there alike** — which is what makes
this a pass over the file rather than an append to it.

1. **Only this repo could produce it.** A line that would read the same in any repo is a no-op paying
   rent: it changes no behavior against the default, and the model already had it from the plugin.
   The team's own identity is the standing example — `kru-lead` carries it, so a sentence
   introducing the team is a sentence the pointer already spent. **Keep the operative test and drop
   the frame around it**: a file describing itself or the surface it sits on — "everything here is
   loaded into every session", "this file holds X" — tells the reader what reading it already told
   them, and the operative test it wraps is the whole line.
2. **A meaning lives in one place.** Everything on this surface is loaded together, so a line
   repeated across two of these files is paid for twice and drifts from whichever copy is edited
   first. It binds *inside* a section as well as across files. A closing paragraph summarising the
   section's own bullets is the second copy — a charter section attracts three passes of it (the
   principle, the instruction, the rule of thumb), each reading load-bearing alone while only the
   bullets carry a distinct test. And prose beside a derived table stops where the table starts: a
   seats/stack table names the stack with versions and the manifest each came from, so the intro
   above it keeps only the product premise nothing else states.
3. **The environment is a source of truth; a line restating it is a cache.** A cache earns its load
   only when the lookup is expensive. `pnpm test` sitting in `package.json` is a one-file lookup and
   stays there — unless the line is adding what the file can't say (what the run *costs*). A **seat
   pointer** earns its line for the opposite reason: reaching it means running a routing table over
   the manifest, which is exactly the expensive lookup a cache is for.
4. **A pointer's wording is what fires it.** Front-load the leading word, name one trigger per
   branch, and cut identity the target already carries.
5. **Every line cites its derivation** — what makes it checkable on a re-run, and what makes a line
   that has gone stale findable at all. It binds every line *you* write; for a line already there,
   the test is whether it still matches disk.
6. **Reference only some branches reach sits behind a pointer**, so the lines every session needs
   stay legible.
7. **A gate is the statement; prose carries what nothing checks.** Where a type error, a lint rule, a
   resolve-time refusal or a tree-sweeping spec already enforces a boundary, that enforcement *is*
   the rule, and the line here is a second copy of it. Bar 3's twin one rung over: that one asks
   whether a **value** is cheap to look up, this one whether a **rule** is already enforced. Read it
   the other way too: a rule that is prose names what enforces it — the gate, the spec, the compile
   error — or says plainly that nothing does.

An always-loaded file is added to far more often than it is cut from, so its default state is
**sediment** — layers that settled because adding felt safe and removing felt risky. Run the bars
over every line already in it:

| Fails | Edit |
|---|---|
| reads the same in any repo (1) | delete the sentence whole |
| describes itself or the surface it sits on (1) | keep the operative test, cut the frame |
| states what another always-loaded file states (2) | keep the copy nearest the work, cut the rest |
| closes a section by summarising its own bullets (2) | cut the closer; the bullets carry the tests |
| narrates what a derived table beside it states (2) | cut back to the premise the table can't state |
| caches a one-file, one-command lookup (3) | cut it, unless it adds what the file can't say |
| names a doc without the branch that reaches it (4) | front-load the leading word, one trigger per branch |
| no longer matches disk (5) | re-derive it, or cut it |
| in-file reference burying the steps around it (6) | disclose it behind a pointer |
| restates what a gate, lint rule or compile error binds (7) | cut it; the enforcement is the statement |
| states a rule, names nothing that enforces it (7) | name the gate, or say plainly nothing checks it |

**What you keep is the whole point of the file**: the unwritten convention, the reason behind a
choice, the gotcha no config confesses, the one-way door, the ban whose cost is invisible at the call
site. Those are load-bearing however long they run — a paragraph earning its length is not sprawl,
and the repo's voice is not noise. This pass exists to make room for them.

**Every proposed cut names the file that already answers it.** A cut with no such file is not a
duplication finding — it is a rule you are asking the user to drop, and it reaches them as that
question, in their words, with what it would cost. **Open that file and verify it carries the
answer** before cutting toward it: a pointer can lead back here — a header citing this file — and the
reasoning behind one of those is the only copy, so it stays. Verify the same way afterwards. Extract
the rule phrases from before and after and diff those; a rule that lost its sentence leaves its
gate's header citing a doc that no longer states it, and re-reading the file whole is how that
survives the pass.

Completion: every line, added or already there, clears all seven bars; every line proposed for
cutting is named with the file that answers it, and that file was opened and found to carry it.

### 4. Blend — *full run*
The answers land as a **team section in the host file's own idiom** — the shape derived from that
file the way the content is derived from the repo. Read what the file already does and match it:
`${CURSOR_PLUGIN_ROOT}/skills/kru-setup/sheet.md` carries the fields, the two lines whose wording is
fixed, and one sheet rendered in two idioms.

**Placement is the file's own order.** The pointer orients a session before work starts, so it sits
with the file's other orienting material rather than appended below its last section. A derived fact
with a natural home in an existing section goes *there* instead — a test's cost beside the repo's
commands, a token file beside its gate — which leaves the team section holding the seats.

**The stamp** is one HTML comment directly above that section:

```
<!-- kru vX.Y.Z · derived YYYY-MM-DD · `skills/kru-setup/SKILL.md` to re-derive -->
```

It renders as nothing and does two jobs no prose does: it tells a later session the team was set up
here, and it carries the plugin version the answers came from — which is what makes them a cache
rather than a fork.

Completion: the section reads as though the file's own author wrote it, and the stamp carries the
installed `VERSION`.

### 5. Write, returning product cuts to the PM
`AGENTS.md` is checked in and read by everyone who clones the repo — teammates without this
plugin included, and the hand that wrote whatever you are proposing to cut. The sheet's lines and the
pass's edits that cut a copy another file answers are the team's: write them. Before cutting a rule
a human authored whose only copy is here, **return one question** — in their words, with what dropping
it would cost — and apply only when the invoking task approves that cut. Everything else is written
without waiting. Headless (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), keep the rule and put that question under **Questions for the PM**.

Completion: the file holds the pass and the sheet, and no human-authored rule left without explicit
approval in the task.

### 6. Report
A short paragraph, in the user's vocabulary: what the team now knows about this project and what it
will do differently for it — the seats this repo runs, anything the derivation turned up that the
repo had never written down, what the team may now do without asking (step 1d) in one line. The pass's edits, filed lint slices and inbox lines ride as one counted
clause ("plus 6 cleanups to the project notes"); the diff is there if asked. Setup commits at most
locally: the PM bot reviews the diff, pushes it and opens the pull request, and the owner merges it
(`skills/kru-lead/SKILL.md` → *Who acts at the door*).

Completion: before you send it, check yourself — every line that went in traces to a derivation, and
every line that came out to the file that answers it. That accounting is your check, not the report's
content.

## Re-run — the full update path
The file is a function of *(plugin version × repo state)*, so re-deriving from scratch settles both
directions it goes stale from. One release's patch to what setup wrote, carried across every repo at
once, is `skills/kru-propagate/SKILL.md`'s; a change that needs the file re-derived comes here.

- **The repo moved** — a dependency swap, a new gate, a design system where there was none. The
  citations are the signal: a derived line that no longer matches disk is a line to re-derive.
- **The plugin moved** — `skills/kru-roster/learn.md` (PM or lead loads) promoted a preference, a seat was hired or renamed. The
  stamp is the signal: a stamp below the installed `VERSION` is behind — report that to the caller; re-derive only when the task says to.

**The citations are what make a re-run an edit rather than a second copy.** Each derived line carries
what it came from, so a re-run reads the file, re-derives, and edits the lines it can account for.
Everything else in the file is the repo's, whoever wrote it: an answer already stated in someone
else's words is theirs — cite it and move on.

## The line between the plugin and the repo
The repo's file holds the **engagement**; the plugin holds the **practice**. A rule that would still
be true in the next repo belongs upstream — `skills/kru-remember/SKILL.md` files it and `skills/kru-roster/learn.md` (PM or lead loads)
gates it (`${CURSOR_PLUGIN_ROOT}/PREFERENCES.md`). A rule true only here stays in the repo.

The plan store stays outside the working repo, its pointer included
(`${CURSOR_PLUGIN_ROOT}/TRACKER.md`): the file describes the repo, never where the repo's plans live.
