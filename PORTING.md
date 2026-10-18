# Porting — how this fork tracks kru, and where Cursor stops

This repo is a **git fork** of [ap-justin/kru](https://github.com/ap-justin/kru) with upstream as a
remote (`upstream`). Nothing is vendored twice: upstream's files, normalized into a Cursor plugin in
place by one script, plus a small set of fork-owned files.

```
bash scripts/sync-upstream.sh    # merge upstream/main and regenerate the tree (or: git merge upstream/main && node scripts/port.mjs)
bash scripts/verify.sh           # every static check (CI runs it on each pull request and push to main)
```

Port and sync pull requests **must merge with a merge commit** (`gh pr merge --merge`), not squash
or rebase. The tree is a function of the newest upstream commit **in git history**; squash leaves
`VERSION` ahead of history and CI fails until upstream is re-recorded (`git merge -s ours --no-ff
<upstream-sha>`). Details: `skills/kru-roster/fork-sync.md`.

`.github/workflows/sync-upstream.yml` runs the first two weekly and opens the result as a pull
request (an issue when the port can't take the new upstream); `skills/kru-roster/fork-sync.md` is
the runbook and `skills/kru-roster/release.md` the release steps.

`scripts/port.mjs` is **idempotent**, which is the whole design: a merge that reintroduces Claude Code
vocabulary gets rewritten again instead of hand-patched. `--check` exits non-zero when the tree is
not normalized, when a required rule stopped matching (upstream reworded a line a rule exists for),
or when a forbidden token (`CLAUDE_PLUGIN_ROOT`, `.claude-plugin`, `kru:`, `mcp__`, `claude plugin
install`, …) survived. `scripts/verify.sh` goes one further: it ports a fresh copy of the newest
upstream commit in history with the fork-owned files laid over it and requires the result to be
this tree byte for byte — so no ported file carries a hand edit the next merge would lose.

## The layout

| upstream | here | why |
|---|---|---|
| `.claude-plugin/plugin.json`, `marketplace.json` | `.cursor-plugin/plugin.json`, `.cursor-plugin/marketplace.json` | Cursor's manifest; generated (name `kru-cursor`, version, logo `brand/kru-mark-512.png`). The marketplace file lets the repo import as a team marketplace |
| `skills/<name>/` | `skills/kru-<name>/` | Cursor's skill names are one flat namespace shared with the user's skills and every other plugin, the name must match the folder, and `/update` is already a Cursor CLI command |
| `agents/<seat>.md` | same file, `name: kru-<seat>` | the same namespace; the file keeps its name so upstream merges and the hooks' `agents/$seat.md` lookups need nothing |
| — | `rules/kru-lead.mdc`, `rules/kru-setup-nudge.mdc` | always-on rules, generated: the lead precondition and the `/kru-setup` reminder (below) |
| — | `commands/kru-<name>.md` | one per skill upstream marks user-invoked (`argument-hint` or `disable-model-invocation`), 36 today, generated |
| `hooks/hooks.json` (claude format) | `hooks/hooks.json` (cursor format) | generated; every entry runs through `hooks/cursor-hook.sh` |
| `.claude/`, `evals/`, `TESTING.md`, `scripts/smoke.sh`, `hooks/check-task-tools.*`, `skills/setup/cloud-install.sh`, `skills/claude-code-delegation`, `scripts/sync-bot-skills.*`, `scripts/bot-skills.txt` | — | dropped by the port: upstream's claude release tooling, `claude plugin eval` suites, a live `claude -p` run, a check for a claude setting, a claude cloud-session hook template, claude-code delegation, upstream bot-library sync |
| — | `scripts/cursor-smoke.sh` (never reintroduced) | dropped: the fork's live API smoke; `bash scripts/verify.sh` is the only release gate, mirroring upstream v0.153.0 |

## Every Claude Code construct, and what it became

| Claude Code construct | Cursor handling | Why |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | `${CURSOR_PLUGIN_ROOT}` | documented for a plugin's `mcp.json`. For the rest, read off `cursor-agent` 2026.10.01: the plugin loader substitutes `${CURSOR_PLUGIN_ROOT}` (and claude's spelling) in a plugin's skills, agents, rules, commands and hook commands at load, and exports it to every hook process. `hooks/cursor-hook.sh` also locates itself from its own path, so a hook never depends on the variable alone |
| `${CLAUDE_PLUGIN_DATA}` (asset deps) | `${KRU_PLUGIN_DATA:-$XDG_DATA_HOME/kru-cursor}` | Cursor has no per-plugin data dir; the deps must outlive an update and stay out of the store (a store repo would sync `node_modules`) |
| `userConfig` (`/plugin` → Configure: `KRU_STORE_REPO`, the `KRU_NO_*` switches) | dropped — env vars only (shell profile locally, cloud agent **Secrets** in the cloud) | Cursor's `variables` fill `${VAR}` placeholders in a plugin's config and are set by team admins; they don't reach a hook's environment, and kru ships no MCP config to substitute into. `scripts/kru-store.sh` still maps `CLAUDE_PLUGIN_OPTION_*` for a claude install of the same tree |
| `kru:<name>`, `/kru:<name>`, a bare `/<name>` command | `kru-<name>`, `/kru-<name>` | one rule for seats, skills and commands; the bare form is re-pointed from the skill set on disk |
| agent `tools:` allowlist | dropped; the 9 seats with no `Edit`/`Write` become `readonly: true` + `permissionMode: readonly` (7) or are refused the Write/Delete tools by `hooks/seat-guard.sh` (`planner`, `dispatch-auditor`) | `readonly` is Cursor's documented read-only field ("no file edits, no state-changing shell commands") — the strongest control Cursor offers. The installed CLI strips `tools` from a plugin's agents and reads read-only from `permissionMode`, so both keys are written. The planner and the auditor write the store through the shell, which `readonly` would refuse, so their line is the hook — the same line upstream's allowlist drew (no edit tool, shell kept) |
| agent `model:` | the fork's pick from `SEAT_MODELS` in `scripts/port.mjs` (every seat; no Anthropic ids in `agents/`); every id must be in `CONFIRMED_MODELS` | upstream still pins Claude tiers; the port maps them to non-Anthropic Cursor ids. the map, fallbacks and sources are `MODELS.md` |
| agent `effort:` | folded into the model id's parameter, e.g. `gpt-5.6-sol[effort=high]` | Cursor's documented syntax for reasoning effort on a subagent's model |
| agent `memory: local` | a line in the seat's Block Q naming `.claude/agent-memory-local/<seat>/MEMORY.md`, read and kept by the seat | Cursor has no agent memory; the path stays claude's so both forks of the team share it and `store-sync`/`/kru-setup` cover it (same as kru-opencode) |
| agent `experimental.cacheTtl` | dropped | no Cursor equivalent |
| skill `user-invocable: false` | dropped | every Cursor skill is in the `/` menu; there is no hide flag |
| skill `allowed-tools` | dropped | Cursor skills carry no tool allowlist |
| skill `disable-model-invocation`, `argument-hint` | kept | Cursor reads the first under the same name; it ignores the second, which marks the skills that get a command |
| user-invoked skills (`/kru:brief`, …) | the skill itself (`/kru-brief`) plus a generated `commands/kru-brief.md` that loads it | Cursor puts both skills and commands in the `/` menu; the command is the explicit front door the brief asked for |
| the lead precondition (`/kru:setup` writes a "load the lead" line into `.claude/CLAUDE.md`) | `rules/kru-lead.mdc`, `alwaysApply: true`: load `kru-lead` before building, reviewing or dispatching; how seats and commands are named | a plugin can ship always-on context in Cursor. The 38 KB contract stays a skill — most turns never dispatch — and the rule is the precondition, which `hooks/require-lead.sh` still enforces. The PR babysit loop is the one procedure the rule carries; the skill points at it |
| hooks.json format (nested `hooks`, `type: command`, PascalCase events, `${CLAUDE_PLUGIN_ROOT}`) | flat entries, camelCase events, `version: 1`, every command `bash "${CURSOR_PLUGIN_ROOT}/hooks/cursor-hook.sh" <event> <script>` | Cursor's format. The adapter turns Cursor's payload into the fields upstream's hooks read and their answers into Cursor's schema |
| `SessionStart` → `check-task-tools.sh` | dropped | Cursor's todo list is always on |
| `SessionStart` → `setup-nudge.sh`, `store-sync.sh start` | `sessionStart` locally **and** the first `preToolUse` of each conversation (`hooks/first-turn.sh`, once per conversation id, 15 s budget), plus `rules/kru-setup-nudge.mdc`; store-sync's clone, pull and push share one time budget per run (`KRU_STORE_SYNC_TIMEOUT`: 45 s when `first-turn.sh` runs it from `sessionStart`, 10 s from the first tool call, 20 s inside the 30 s stop hook, plus git's low-speed abort; a value that isn't a positive number of seconds falls back to that default (`0` included), and `08` is eight), enforced by a watchdog that kills the call's process group — so an ssh or remote helper stuck in connect ends too, and nothing depends on coreutils `timeout`, which macOS lacks — and a budget that runs out says it timed out instead of the sign-in hint; port rules | cloud agents don't run `sessionStart`; the first tool call is the earliest a hook sees there, and the rule covers the reminder even before it. That tool call waits on the hook, so a hung remote gives up instead of holding it |
| `PreToolUse *` → `require-lead.sh` | `preToolUse` `*` → a Cursor-native rewrite: evidence of the load is the agent reading `skills/kru-lead/SKILL.md`, the user typing `/kru-lead` or any `/kru-<command>` (recorded at `beforeSubmitPrompt`); only the tools that build are gated (Write/Delete/edit tools, Task, MCP calls, shell that doesn't only read), so a read, a fetch or a question passes; once per conversation; a subagent's call (`parent_tool_call_id`) exempt | upstream reads claude's jsonl transcript; Cursor's transcript is another format, may be absent (`transcript_path: null`), and may hold the always-on rule that names `/kru-lead`, so it isn't read at all. Reads pass because Cursor loads a skill by reading it — gating the first read would close the only door out |
| `PreToolUse Agent` → `check-handoff.sh` | `preToolUse` `Task` → upstream's gate unchanged; `updatedInput` → `updated_input`, built from Cursor's own `tool_input` with only the prompt replaced | Task is Cursor's subagent tool. Cursor's Task input shape is undocumented, so the adapter flattens an object-shaped `subagent_type` to the seat name and never rewrites keys it didn't read |
| `PreToolUse Write\|Edit\|NotebookEdit\|Bash` → `brainstorm-guard.sh` | `preToolUse` `Shell\|Write\|Delete` → a Cursor-native rewrite: the lock is set by the user's `/kru-brainstorm` and lifted by *go* / *brief it* / `/kru-brief`, recorded at `beforeSubmitPrompt` (`hooks/prompt-state.sh`) | same transcript reason; `beforeSubmitPrompt` runs on cloud agents too |
| `PostToolUse Agent` → `log-dispatch.sh` | `postToolUse` `Task`, upstream's hook unchanged | — |
| `SubagentStop` → `log-return.sh` (`decision: block` keeps the seat running) | `subagentStop` → `followup_message`; `agent_type` ← `subagent_type`, `last_assistant_message` ← `summary`, `stop_hook_active` ← `loop_count > 0` | Cursor continues a completed subagent with a follow-up; `loop_count` is documented per subagent |
| `Stop` → `nudge-audit.sh` (`decision: block`) | `stop` → `followup_message`, auto-submitted as the next user message; no `loop_limit` dependence | the hook's own mark (dispatch count already nudged for) bounds it; Cursor leaves `loop_count`'s span unspecified for `stop`, so the adapter doesn't map it |
| `Stop` → `store-sync.sh stop` | `stop` | — |
| a permission hook's exit 2 + stderr | `{"permission":"deny","user_message":…,"agent_message":…}` | Cursor blocks on exit 2 but documents the messages on the JSON; and exit 0 with anything but valid JSON **blocks** a permission hook, so the adapter prints `{"permission":"allow"}` on every other path |
| tool names `Bash`, `Edit`/`Write`/`NotebookEdit`, `Agent`/`Task` | matchers `^(Shell\|Write\|Delete)$`, `^(Write\|Delete)$`, `^Task$` | Cursor's tool matchers (`cursor.com/docs/hooks` → Matcher Configuration). A matcher is a regex tested unanchored (`new RegExp(m).test(tool)` in `cursor-agent` 2026.10.01), so every name is anchored — a bare `Write` would also match `WriteShellStdin`; `verify-tree.mjs` refuses an unanchored one |
| `TaskCreate` · `TaskUpdate` (or `TodoWrite`) | "the agent's todo list (always on in Cursor)" | one built-in todo tool |
| `SendMessage` / resume | resuming the subagent by its agent ID | Cursor's resume mechanism (`cursor.com/docs/subagents` → Resume) |
| built-ins `Explore`, `Plan`, `/code-review` | `Explore` (same name), Plan mode, `/review` | Cursor's built-ins |
| Claude Design's canvas, the `Artifact` tool, bundled `/design`, claude.ai/design as the in-session editor | `/kru-design` drafts `.dc.html` artboards and publishes with `/canvas` ([skills](https://cursor.com/docs/skills), [canvas](https://cursor.com/docs/agent/tools/canvas)). The `.dc.html` files are the surface when `/canvas` isn't available. The look is decided on the canvas; the verdict is the PM's | Cursor's canvas is a React artifact beside the chat. A plugin packages the layout as a skill ([canvas](https://cursor.com/docs/agent/tools/canvas) → *Packaging in skills*). There is no Artifact tool and no claude.ai/design host |
| bundled `/run` (confirm the behavior works) | the Browser subagent ([browser](https://cursor.com/docs/agent/tools/browser), [subagents](https://cursor.com/docs/subagents)) | Cursor's `/run` is Shell Mode, an alias of `/shell` ([slash commands](https://cursor.com/docs/cli/reference/slash-commands)), which does not confirm a running product |
| bundled `/research` | a Cursor subagent for a long research task ([subagents](https://cursor.com/docs/subagents)) | no `/research` built-in ([skills](https://cursor.com/docs/skills)) |
| `/kru-update`'s Claude Code release sweep | read [Cursor's changelog](https://cursor.com/changelog) and [docs release notes](https://cursor.com/docs/release-notes). The file stays `claude.md` so the argument stays `claude` | the closed Claude Code ledger in `reviewed.md` is history |
| `mcp__<server>__<tool>` | `` `<tool>` (`<server>` MCP) `` | Cursor names a server and its tool (permissions write `Mcp(server:tool)`) |
| `claude mcp add …`, `npx … --claude-code`, `mcp init --client claude`, `fly mcp server --claude` | an entry in `.cursor/mcp.json`; the vendors' `--cursor` flags | Cursor's MCP config |
| the Turso claude plugin (`/plugin install turso@turso`) | the hosted Turso MCP server added in Cursor | the plugin is that server plus a skill kru vendors |
| `.claude/CLAUDE.md` (the repo sheet), `CLAUDE.md`, and `~/.claude/CLAUDE.md` in skill prose | root `AGENTS.md`, and `.cursor/rules` with `alwaysApply: true` | what loads every session ([rules](https://cursor.com/docs/rules)). A rule without `alwaysApply: true` does not. The handoff gate reads root `AGENTS.md` and those rules, and still reads `~/.claude/CLAUDE.md` as a fallback |
| `.claude/skills/`, `.claude/agents/`, `.claude/rules/*.md` | `.cursor/skills/`, `.cursor/agents/`, `.cursor/rules/*.mdc` | Cursor's project locations |
| `CLAUDE_CODE_REMOTE=true` (cloud) | `KRU_CLOUD=1` forces the cloud store. Unset, `CURSOR_AGENT_SOCKET` or `/run/cursor/api.sock` does. `KRU_CLOUD=0` forces the local store even when that socket exists — set it on a machine that has the socket but is not a cloud vm, and in tests (`references/store.md`) | Cursor's managed vms expose the agent metadata socket (`cursor.com/docs/cloud-agent/metadata`) |
| bugs and product wants on the product repo's GitHub issues | `KRU_TRACKER` (`github` when unset or empty, `linear` when a repo opts in). Linear is a team key plus a project name, for example `KRU_LINEAR_TEAM=BG` and `KRU_LINEAR_PROJECT=Connector` — examples, not values this plugin hard-codes. Prefer the connected Linear MCP tools (`save_issue`, `list_issues`, `save_comment`). `LINEAR_API_KEY` is optional, only for `scripts/kru-tracker.sh` when MCP is not connected, and never a committed key. Pull requests stay on GitHub; `link` prints `Fixes #<n>` or `Linear: <id>`. On the GitHub tracker a security finding stays in the store's `issues/` or a GitHub private security advisory. On Linear it is filed, internal to the team, with label `security` on `KRU_LINEAR_SECURITY_TEAM`, or on the main team when that is unset. What is filed follows *Tracker text* (`TRACKER.md`). The agent's todo list, `TODOS.md` scratch, and `plan/<effort>/` tickets stay where they are | the fork's tracker. Upstream files those in the plan store; this fork's edits point every filing skill at the setting, so a fresh port keeps it |
| `CLAUDE_PROJECT_DIR` | `CURSOR_PROJECT_DIR` (falling back to `CLAUDE_PROJECT_DIR`, which Cursor also sets) | Cursor's hook env |
| the claude cloud environment (setup script, `.claude/cloud-setup.md`, `.claude/cloud-install.sh`, `settings.json` permission grants, a project `verify` skill run before commits) | `skills/kru-setup` §1d, hand-owned (`scripts/cursor/setup-1d.md`): `.cursor/environment.json` install, `~/.cursor/cli-config.json` / `.cursor/cli.json` permissions, `KRU_STORE_REPO` as a cloud agent secret; no pre-commit skill | Cursor's cloud environment and permission grammar. Cursor runs no project skill before a commit |
| review report path `${TMPDIR}/kru-review/…` | none: review seats return inline under their caps (`skills/kru-lead/references/gates.md`, hand-owned paragraph) | review seats run `readonly`, so they can't write a report file; the gate stops supplying a path they couldn't use |
| `claude plugin details` / `/plugin` → Configure | the plugin's entry under **Customize** | Cursor's plugin UI |
| `claude-code-guide` (the lead's harness source) | Cursor's docs (`SOURCES.md` → *Orchestration / harness mechanics*, hand-owned row) | the lead's own official source |

## Read-only seats

`code-reviewer`, `architecture-reviewer`, `accessibility-reviewer`, `visual-reviewer`, `ux-auditor`,
`conversion-copywriter` run with Cursor's `readonly`. Upstream let its reviewers write a
report file through the shell; `readonly` refuses that, so their long-form report comes back inline,
capped by each seat's *What you return* contract — the price of the stronger guarantee. `planner` and
`dispatch-auditor` keep the shell (the plan of record, the audit closeout) and are refused the Write
and Delete tools by `hooks/seat-guard.sh`, which maps a Task's `tool_call_id` to its seat at
`subagentStart` and reads it back through a tool call's `parent_tool_call_id`. That mapping uses a
field the CLI sends (`parent_tool_call_id`) that Cursor's docs don't list; where it is absent the
guard allows — and the six readonly seats among the team's 37 agents don't depend on it.

## Hand-owned — what a merge will not normalize

Every change this fork makes lives in one of three places, never in a ported file — a hand edit to
one is overwritten by the next port, and `scripts/verify.sh`'s fresh-port check fails on it:

1. **A rewrite rule** in `scripts/port.mjs` (`RULES`): vocabulary and layout, applied everywhere a
   pattern matches. `required` makes the port fail when upstream rewords the line a rule exists for.
2. **A fork edit** in `scripts/cursor/edits.mjs` (`EDITS`): a decision this fork makes that upstream
   doesn't share (who the PM is, who pushes, where a bug goes), written as an exact passage of the
   ported file and what it becomes, applied after every rule. An edit whose passage upstream
   rewords fails the port by name; the fix is the new passage copied in. `scripts/port-edits.test.sh`
   runs them against a fresh upstream tree, idempotence and the rewording failure included.
3. **A hand-owned file** — listed in `FORK_OWNED` (or under `scripts/cursor/`, `.github/`), skipped by
   the port and laid over upstream by the fresh-port check. A whole section is a hand-owned block
   pulled in by a rule (`scripts/cursor/*.md`).

| file | why |
|---|---|
| `README.md`, `PORTING.md`, `MODELS.md`, `NOTICE` | the fork's own documents |
| `scripts/port.mjs`, `scripts/verify.sh`, `scripts/verify-tree.mjs` | the port, the verify gate, and the tree/manifest checks `verify.sh` runs |
| `scripts/privacy-scan.mjs`, `scripts/privacy-scan.test.sh`, `scripts/leak-patterns.mjs`, `scripts/guard-text.mjs` | the privacy scanner, its pattern tables, and the outbound text guard (`PORTING.md` → *Privacy*) |
| `scripts/cursor-hooks.test.sh` | tests the Cursor hook seam against the ported hooks |
| `hooks/cursor-hook.sh`, `hooks/first-turn.sh`, `hooks/prompt-state.sh`, `hooks/seat-guard.sh`, `hooks/cursor-state.sh` | the Cursor seam. Per-conversation state lives under `${TMPDIR:-/tmp}/kru-cursor-<uid>/`, both levels `0700` and refused unless a real directory this user owns |
| `hooks/readonly-bash.test.sh` | tests the ported `hooks/readonly-bash.sh`, whose flag-writers port rules add: every flag is read off the segment's words with quotes resolved, so `'-o'` is `-o`. sed reads only on an allowlist (`-n -E -r -s -z -u`, `-e`, addresses, `p d D q = G g h H N P x l y { }`, `s///[gpIiMm0-9]*`), since its `w`/`W`/`e` need no separator; every raw newline splits, and `|;&` split only outside quotes; `$$'` is a pid plus a single quote, not `$'…'`, and any other unquoted `$` (and an unescaped `$` or `` ` `` inside `"…"`) fails closed; a function definition (`name ()` or `name ( )`, including `ls () ( touch x ); ls`) is a write on the whole command and on each segment; awk's `system (`/`getline`/`@include`/`@load` and an indirect `@name(` are checked on the raw line when awk is on it and again on the quote-resolved words, and awk `-f` or any flag but `-F`/`-v` is a write; find's `-exec`/`-ok`/`-delete`/`-fprint`/`-fls` and git's `--output` (not `--output-*`) are refused on the quote-resolved words; plus `sort -o` and its GNU prefixes `--o…`, `sort --compress-program`, `rg --pre`, `yq -i`/`--inplace`/`--split-exp`, `date -s`/`--set` or a clock operand, `command` but `-v`/`-V`, `uniq`'s second operand, `file -C`, `base64 -o`, `<(`; `xxd` leaves the read list |
| `scripts/cursor/readonly-words.sh` | the word splitter, the function-definition check, and the sed and awk allowlists the port inserts into `hooks/readonly-bash.sh` |
| `hooks/require-lead.sh`, `hooks/require-lead.test.sh`, `hooks/brainstorm-guard.sh`, `hooks/brainstorm-guard.test.sh` | Cursor-native rewrites of upstream's transcript-reading gates; an upstream change to their *rules* (what counts as a go, which tools are reads) needs mirroring by hand. Both still call upstream's `hooks/readonly-bash.sh` |
| `hooks/mcp-outbound-guard.sh`, `hooks/mcp-outbound-guard.test.sh`, `scripts/cursor/mcp-outbound-allowlist.mjs`, `scripts/cursor/mcp-outbound-classify.mjs`, `scripts/cursor/hooks.repo.mcp-guard.json`, `.cursor/hooks.json` | MCP outbound guard: policy in `scripts/cursor/mcp-outbound-allowlist.mjs`; wired through generated `hooks/hooks.json` and the repo's `.cursor/hooks.json` (`/kru-setup` copies scripts and merges `hooks.repo.mcp-guard.json`). Cursor cloud agents do not run hooks on connector MCP today (verified Oct 2026); `rules/kru-lead.mdc` is the guard there |
| `scripts/sync-upstream.sh`, `scripts/sync-upstream.test.sh`, `.github/workflows/sync-upstream.yml`, `.github/workflows/verify.yml`, `scripts/workflows.test.sh` | the weekly upstream sync: upstream recorded as a merge parent, the tree regenerated by the port, so no text conflict; a pull request, or an issue when the port fails or the push is refused; `sync-upstream.sh` never commits on the default branch. The fork owns `.github/` outright: upstream's is dropped before the overlay, here and in `verify.sh`'s fresh-port check. The verify job that runs upstream's code holds `contents: read` only, no stored credentials, and outputs nothing but an ok flag; the sync job records the bundle's sha256 and the artifact id before that job runs; the one that pushes downloads by that id, checks the sha256, and runs no repo code (`skills/kru-roster/fork-sync.md`). `workflows.test.sh` holds those rules for every workflow: per-job permissions, no `${{ }}` inside `run:`, no token beside a repo script, `persist-credentials: false`, actions pinned to commit SHAs |
| `skills/kru-roster/release.md`, `skills/kru-roster/fork-sync.md`, `skills/kru-roster/request.md` | the fork's release (version `0.N.0+kruX.Y.Z`, tag, Cursor's marketplace), sync runbook, and requester path. A new file inside a ported directory is hand-owned by listing it in `FORK_OWNED` (`scripts/port.mjs`): the port skips it and the fresh-port check lays it over upstream; the roster skill points at both through a port rule |
| `scripts/cursor/edits.mjs`, `scripts/port-edits.test.sh` | the fork edits and their test (above) |
| `scripts/kru-tracker.sh`, `scripts/kru-tracker.test.sh` | the work tracker (`KRU_TRACKER=github\|linear`). Fork-owned, so a fresh port lays the script over upstream and the edits point the skills at it. The test mocks `gh` and `curl`; a live Linear team is not required for `verify.sh` |
| `scripts/brief-drift.mjs`, `scripts/brief-drift.test.sh` | the brief re-run's drift report. Fork-owned. The test feeds mocked tracker JSON; `list-effort` and `show` are covered in `kru-tracker.test.sh` |
| `scripts/cloud-skills.sh`, `scripts/cloud-skills.test.sh` | installer a cloud agent's environment step pipes in. Shallow-clones this repo's `skills/` and `agents/` plus `pstack/` into `.claude/skills/<name>/` and `.claude/agents/`, and copies each agent to `~/.cursor/agents/` (`KRU_CURSOR_AGENTS_DIR` overrides that directory) so a cloud agent sees them at startup ([subagents](https://cursor.com/docs/subagents)). Skips a name the repo tracks and overwrites an untracked repo copy. The home copy replaces a file whose frontmatter `name:` starts with `kru-` and a file that is not there yet; an existing home agent whose `name:` is not `kru-*` is left untouched. It lists the copied repo paths in `info/exclude` between begin and end markers. After a successful copy it lists registered `name:` values and exits 1 when none start with `kru-`. The kru clone or fetch failure warns and exits 1. A plugins clone or fetch failure warns and still installs the kru seats. The run exits 1 when no kru-* agent is on disk. Run the installer in the environment install step only: subagents load at session start, so the start step is too late. A repo using it must not negate `.claude/skills` or `.claude/agents` in `.gitignore`. Fork-owned so a re-port leaves it in place. The test uses local source repos |
| `scripts/cursor/setup-1d.md` | `/kru-setup` §1d (grants, store repo, cloud environment), pulled in by a port rule |
| `scripts/cursor/gates-report-path.md` | the review-report paragraph of `gates.md` |
| `scripts/asset/xai.mjs`, `scripts/asset/xai.test.mjs` | the asset generator's xAI backend and its tests; port rules hook it into upstream's `gen-asset.ts` and copy it in `run.sh` (`MODELS.md`) |
| `scripts/cursor/sources-harness-row.md` | `SOURCES.md` → *Orchestration / harness mechanics* |
| `scripts/cursor/ui-design-cursor.md` | `references/ui-practice.md` after *Engineering never runs a mockup or canvas step*, pulled in by a port rule |
| `scripts/cursor/update-sweep.md` | `skills/kru-update/claude.md`, the Cursor changelog sweep, pulled in by a port rule (the file keeps the name `claude.md`) |
| `skills/kru-design/SKILL.md` | the design skill: `.dc.html` artboards plus Cursor's `/canvas`. Listed in `FORK_OWNED` so a new file inside `skills/` survives the port |
| `skills/kru-update/claude.md`, `reviewed.md` | `claude.md` is the Cursor changelog sweep (the block above); `reviewed.md` keeps the closed Claude Code ledger and a Cursor mark. Layout rules only, plus that one edit |
| `skills/kru-eval-review/SKILL.md` | grades an upstream suite already in the tree. Layout rules, plus fork edits: no default `evals/` directory, no `/claude-api` checklist |

## Known gaps

Replacements below cite the doc that describes the Cursor surface. A row stays here only when no
documented counterpart exists. The port still counts the leftovers (`WATCH` in `scripts/port.mjs`).

- **claude.ai/design sync lane.** `references/design-sync.md` still describes publishing a bundle of
  real components to a claude.ai/design project, and `agents/web-components-builder.md` still says a
  custom element mounts in "a design bundle for Claude Design". Cursor has no such project
  ([canvas](https://cursor.com/docs/agent/tools/canvas) is an in-session React artifact, not a synced
  component host). The procedure is left in place so an existing `.design-sync/` can be read. The top of
  `design-sync.md` says not to run it, and the seats point at `/canvas` instead of standing one up.
  The in-session surface is `/canvas`.
- **`ArtifactData`.** `references/store.md` still names the artifact database the store uses when
  `KRU_STORE_URL` is set. Nothing in Cursor's docs is that database.
- **A claude.ai connector** on the unreachable-source ladder (`SOURCES.md`). Connector traffic through
  that host has no Cursor equivalent in the docs. The other rungs stand.
- **`/simplify`.** Named by upstream as a bundled skill. It is not in [Cursor's skills](https://cursor.com/docs/skills).
- **`/verify`.** Claude Code runs a project skill named `verify` before a commit. Cursor runs no
  project skill before a commit (the cloud-environment row above). It is not a built-in
  ([skills](https://cursor.com/docs/skills)). This repo's check is `bash scripts/verify.sh`. The live
  roster no longer tells the lead to delegate to `/verify`. The closed ledger in
  `skills/kru-update/reviewed.md` still names it.
- **`/skill-doctor` and `/doctor prompt-audit`.** No built-in lists unused skills, and none audits
  prompts for older models ([skills](https://cursor.com/docs/skills)). The token-split half of that
  read is Cursor's context usage report ([changelog](https://cursor.com/changelog/canvas-improvements)).
  `skills/kru-roster/audit.md` points at that report. The closed ledger still names both commands.
- ***You should know*.** A side agent that flags, mid-task, what the turn missed. No Cursor mode by
  that name ([skills](https://cursor.com/docs/skills)). `lead` still triages a card if one arrives.
  The closed ledger still records the mod.
- **`/kru-eval-review`.** Grades an upstream plugin-eval suite already in the tree, and tells the reader not to install a runner. This repo has no default `evals/` directory and no checklist beside the traps in the skill. Cursor has no eval runner.
- **wayfinder's `prototype` skill.** `skills/kru-wayfinder/SKILL.md` still says to call a skill named `prototype`. It is not vendored here and it is not a Cursor built-in ([skills](https://cursor.com/docs/skills)). `grilling` and `domain-modeling` are vendored. The sentence is left as written.
- **Per-seat models in the CLI.** `cursor-agent` 2026.10.01 runs a plugin's agents on the parent's
  model (`MODELS.md`).
- **Task input and plugin hooks on cloud agents are partly undocumented.** The shape of `tool_input`
  for the Task tool, `parent_tool_call_id`, `additional_context` on a `preToolUse` answer, and
  whether a marketplace plugin's hooks run on a cloud agent (the docs list project, team and
  enterprise hooks) were read off the CLI or inferred; every one fails open.
- **The brainstorm lock doesn't follow a subagent**: a subagent's tool calls carry their own
  conversation id. The lead dispatches nothing while a brainstorm stands.

## Privacy

The public tree must not ship a secret, a private email, a path off the author's machine, client data, a private repo's name, or a private team identity (a roster of names, or the private approval phrase). History must not ship the first five either. The team-identity check is tree-only: the commits that introduced that roster stay, and rewriting history is a separate decision.

`scripts/privacy-scan.mjs` runs in `verify.sh` over the working tree and over every commit (`git log -p
--all --diff-merges=first-parent`, so a merge's conflict resolution counts; added lines and
author/committer emails). CI also runs gitleaks, pinned and checksum-verified.

The scan fails on tokens and keys; on emails outside the reserved example domains, outside an exact list of placeholder addresses the vendored docs use, and other than the known bot identity `cursoragent@cursor.com`; on paths off the author's machine; and on client names and private-repo names. Those names are matched by hash, so the scanner does not publish them. The team-identity roster is a fixed list of case-sensitive whole words plus one phrase, stored as code points so neither this file nor the scanner spells them.

- **Tree:** clean. One client repo name in `references/lossless-doc-compaction.md` is rewritten by a
  port rule; the eval prompt that named a client is dropped with `evals/`.
- **History:** this fork keeps upstream's history unchanged — it is already public, and a shared
  history is what makes `git merge upstream/main` work. The scan finds reviewed lines in it, removed from this tree or left as vendored examples (`82976d23` `evals/homepage-copy/prompt.md`,
  `cac9076` the babysit loop naming the one repo a reviewer covers, taken out of the tree in the following commit,
  `b10943af` `skills/lead/references/lossless-doc-compaction.md`, example `password=` / `token=` /
  `API_TOKEN=` assignments in that commit's Cloudflare and Turborepo docs, and `94dcd7bf` Turso
  `auth_token=` examples, plus colon assignments in upstream `cb005e14` conform, `94dcd7bf` hono,
  and `60f7ccb6` react-hook-form docs, plus `b10943af` Cloudflare `API_KEY` type names). The current tree's vendored copies of those docs are the
  same examples. The sync workflow's `GH_TOKEN` lines are GitHub's own `${{ github.token }}`.
  Six gitleaks hits are documentation placeholders in vendored Cloudflare docs. Gitleaks also
  sees the tracker's own probe strings in `scripts/kru-tracker.test.sh`; that file is the same path
  exception as the regex scan, because those lines are the fixtures. No real secret.

## License

kru is MIT (`LICENSE`, Copyright (c) 2026 ap-justin), which permits redistribution of the fork. Each
vendored skill keeps its own license file verbatim (16 files, moved with their directories, never
rewritten — the port skips license files), and `NOTICE` lists every upstream, including the
`cursor/plugins` `pstack` subsection (MIT, Lauren Tan) adapted into `skills/kru-diagnosing-bugs`.

## Local test

`cursor-agent` (2026.10.01-e373342) installs and accepts `--plugin-dir`, and loads
`~/.cursor/plugins/local/<name>/`. On the build machine it was **not signed in**, and it stops at
authentication before loading any plugin (`Error: Authentication required. Please run 'agent login'
first, or set CURSOR_API_KEY environment variable.`), so no headless turn ran. In its place,
`scripts/cursor-hooks.test.sh` copies the plugin into a sandbox `~/.cursor/plugins/local/kru-cursor`
and runs every `hooks.json` command the way the CLI does — `${CURSOR_PLUGIN_ROOT}` substituted and
exported, the install dir as cwd (the workspace for `stop`/`subagentStop`), Cursor-shaped payloads,
matchers tested as unanchored regexes, responses merged deny-first — and asserts every permission
answer is valid JSON.

`KRU_HOOK_LOG=<file>` makes `hooks/cursor-hook.sh` append one JSON line per hook call (event, script,
exit, conversation) — the marker the harness reads, and a way to watch the hooks in a live session.
