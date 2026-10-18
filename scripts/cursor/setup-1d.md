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

- **A shell rule matches the command text, not the file it resolves to.** `planner` and
  `dispatch-auditor` are refused the Write tool (`hooks/seat-guard.sh`), so every store write of
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
PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
export PNPM_VERSION
if ! [ -x "$PNPM_HOME/bin/pnpm" ] || [ "$("$PNPM_HOME/bin/pnpm" --version 2>/dev/null)" != "$PNPM_VERSION" ]; then
  curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION="$PNPM_VERSION" SHELL=bash bash -s --
fi
sudo ln -sfn "$PNPM_HOME/bin/pnpm" "$NODE_BIN/pnpm"
sudo ln -sfn "$PNPM_HOME/bin/pnpx" "$NODE_BIN/pnpx"
```

(`sudo` is passwordless on Cursor's default image.) Where the repo uses `packageManager` and
Corepack can activate the pin (`corepack enable pnpm && corepack prepare pnpm@"$PNPM_VERSION"
--activate`), that is an alternative to the installer + symlinks — still run `corepack disable pnpm`
first when an old shim is present. Where the installer lays down a binary under
`.tools/pnpm-exe/<ver>/`, symlink that file into `$NODE_BIN` instead of `$PNPM_HOME/bin/pnpm`. Do not
append `PATH` to `~/.bashrc` or `~/.profile` and expect agent shells to pick it up. Set `PATH` in a
custom `build.dockerfile` when the repo uses one. The team itself
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
`.cursor/hooks.json` does. Copy these files from `${CURSOR_PLUGIN_ROOT}` into the repo (paths must
match the hook commands) before merging hook entries: `hooks/mcp-outbound-guard.sh`,
`scripts/cursor/mcp-outbound-classify.mjs`, and `scripts/cursor/mcp-outbound-denylist.mjs`. Merge the
`preToolUse` and `beforeMCPExecution` entries from
`${CURSOR_PLUGIN_ROOT}/scripts/cursor/hooks.repo.mcp-guard.json` into `.cursor/hooks.json` (create the
file when the repo has none). Commands are repo-root paths such as `bash hooks/mcp-outbound-guard.sh`
(project hooks run with cwd = the repo root; do not use `${CURSOR_PLUGIN_ROOT}`). The guard denies
send/post/share/delete and similar connector tools while allowing reads, drafts, and Linear
`save_issue` — the denylist lives in `scripts/cursor/mcp-outbound-denylist.mjs`. Skip when the repo
already carries the same matchers. Cursor cloud agents do not currently run hooks for MCP connector
calls (verified Oct 2026); the always-on rule is the only guard there (`rules/kru-lead.mdc`).

**The seats' repo memory, ignored.** The seats carrying Block Q write what they learn about this
repo to `.claude/agent-memory-local/<seat>/` — the path both forks of this team share, kept out of
version control by the repo's `.gitignore`. Add `.claude/agent-memory-local/` to it when no line
already covers the path (`git check-ignore -q .claude/agent-memory-local/x` answers that), so the
first `git add -A` after a build leaves it behind.

Completion: every grant traces to evidence the derivation already produced, the memory path is
ignored, `.cursor/environment.json` carries the install step or the report names why it doesn't,
and the report names what the team may now do unasked (step 6).

