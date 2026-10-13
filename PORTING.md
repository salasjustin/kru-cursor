# Porting — how this fork tracks kru, and where Cursor stops

This repo is a **git fork** of [ap-justin/kru](https://github.com/ap-justin/kru) with upstream as a
remote (`upstream`). Nothing is vendored twice: upstream's files, normalized into a Cursor plugin in
place by one script, plus a small set of fork-owned files.

```
git fetch upstream && git merge upstream/main
node scripts/port.mjs            # re-normalize what the merge brought in
bash scripts/verify.sh           # every static check (CI runs it on each pull request and push to main)
bash scripts/cursor-smoke.sh     # local, spends a request: a signed-in cursor-agent loads the plugin
```

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
| `.claude/`, `evals/`, `TESTING.md`, `scripts/smoke.sh`, `hooks/check-task-tools.*`, `skills/setup/cloud-install.sh` | — | dropped by the port: upstream's claude release tooling, `claude plugin eval` suites, a live `claude -p` run, a check for a claude setting, a claude cloud-session hook template |

## Every Claude Code construct, and what it became

| Claude Code construct | Cursor handling | Why |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | `${CURSOR_PLUGIN_ROOT}` | documented for a plugin's `mcp.json`. For the rest, read off `cursor-agent` 2026.10.01: the plugin loader substitutes `${CURSOR_PLUGIN_ROOT}` (and claude's spelling) in a plugin's skills, agents, rules, commands and hook commands at load, and exports it to every hook process. `hooks/cursor-hook.sh` also locates itself from its own path, so a hook never depends on the variable alone |
| `${CLAUDE_PLUGIN_DATA}` (asset deps) | `${KRU_PLUGIN_DATA:-$XDG_DATA_HOME/kru-cursor}` | Cursor has no per-plugin data dir; the deps must outlive an update and stay out of the store (a store repo would sync `node_modules`) |
| `userConfig` (`/plugin` → Configure: `KRU_STORE_REPO`, the `KRU_NO_*` switches) | dropped — env vars only (shell profile locally, cloud agent **Secrets** in the cloud) | Cursor's `variables` fill `${VAR}` placeholders in a plugin's config and are set by team admins; they don't reach a hook's environment, and kru ships no MCP config to substitute into. `scripts/kru-store.sh` still maps `CLAUDE_PLUGIN_OPTION_*` for a claude install of the same tree |
| `kru:<name>`, `/kru:<name>`, a bare `/<name>` command | `kru-<name>`, `/kru-<name>` | one rule for seats, skills and commands; the bare form is re-pointed from the skill set on disk |
| agent `tools:` allowlist | dropped; the 9 seats with no `Edit`/`Write` become `readonly: true` + `permissionMode: readonly` (7) or are refused the Write/Delete tools by `hooks/seat-guard.sh` (`planner`, `dispatch-auditor`) | `readonly` is Cursor's documented read-only field ("no file edits, no state-changing shell commands") — the strongest control Cursor offers. The installed CLI strips `tools` from a plugin's agents and reads read-only from `permissionMode`, so both keys are written. The planner and the auditor write the store through the shell, which `readonly` would refuse, so their line is the hook — the same line upstream's allowlist drew (no edit tool, shell kept) |
| agent `model:` | same id | Cursor serves `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5` under the same ids — `MODELS.md` |
| agent `effort:` | the model id's parameter: `claude-opus-5-5[effort=high]` | Cursor's documented syntax for reasoning effort on a subagent's model |
| agent `memory: local` | a line in the seat's Block Q naming `.claude/agent-memory-local/<seat>/MEMORY.md`, read and kept by the seat | Cursor has no agent memory; the path stays claude's so both forks of the team share it and `store-sync`/`/kru-setup` cover it (same as kru-opencode) |
| agent `experimental.cacheTtl` | dropped | no Cursor equivalent |
| skill `user-invocable: false` | dropped | every Cursor skill is in the `/` menu; there is no hide flag |
| skill `allowed-tools` | dropped | Cursor skills carry no tool allowlist |
| skill `disable-model-invocation`, `argument-hint` | kept | Cursor reads the first under the same name; it ignores the second, which marks the skills that get a command |
| user-invoked skills (`/kru:brief`, …) | the skill itself (`/kru-brief`) plus a generated `commands/kru-brief.md` that loads it | Cursor puts both skills and commands in the `/` menu; the command is the explicit front door the brief asked for |
| the lead precondition (`/kru:setup` writes a "load the lead" line into `.claude/CLAUDE.md`) | `rules/kru-lead.mdc`, `alwaysApply: true`: load `kru-lead` before building, reviewing or dispatching; how seats and commands are named | a plugin can ship always-on context in Cursor. The 38 KB contract stays a skill — most turns never dispatch — and the rule is the precondition, which `hooks/require-lead.sh` still enforces |
| hooks.json format (nested `hooks`, `type: command`, PascalCase events, `${CLAUDE_PLUGIN_ROOT}`) | flat entries, camelCase events, `version: 1`, every command `bash "${CURSOR_PLUGIN_ROOT}/hooks/cursor-hook.sh" <event> <script>` | Cursor's format. The adapter turns Cursor's payload into the fields upstream's hooks read and their answers into Cursor's schema |
| `SessionStart` → `check-task-tools.sh` | dropped | Cursor's todo list is always on |
| `SessionStart` → `setup-nudge.sh`, `store-sync.sh start` | `sessionStart` locally **and** the first `preToolUse` of each conversation (`hooks/first-turn.sh`, once per conversation id, 15 s budget), plus `rules/kru-setup-nudge.mdc`; store-sync's clone, pull and push share one time budget per run (`KRU_STORE_SYNC_TIMEOUT`: 45 s when `first-turn.sh` runs it from `sessionStart`, 10 s from the first tool call, 20 s inside the 30 s stop hook, plus git's low-speed abort; a value that isn't all digits falls back to that default, and `08` is eight), enforced by a watchdog that kills the call's process group — so an ssh or remote helper stuck in connect ends too, and nothing depends on coreutils `timeout`, which macOS lacks — and a budget that runs out says it timed out instead of the sign-in hint; port rules | cloud agents don't run `sessionStart`; the first tool call is the earliest a hook sees there, and the rule covers the reminder even before it. That tool call waits on the hook, so a hung remote gives up instead of holding it |
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
| `mcp__<server>__<tool>` | `` `<tool>` (`<server>` MCP) `` | Cursor names a server and its tool (permissions write `Mcp(server:tool)`) |
| `claude mcp add …`, `npx … --claude-code`, `mcp init --client claude`, `fly mcp server --claude` | an entry in `.cursor/mcp.json`; the vendors' `--cursor` flags | Cursor's MCP config |
| the Turso claude plugin (`/plugin install turso@turso`) | the hosted Turso MCP server added in Cursor | the plugin is that server plus a skill kru vendors |
| `.claude/CLAUDE.md` (the repo sheet), `CLAUDE.md` | `AGENTS.md` at the repo root | what Cursor reads at a repo root (the CLI also reads `CLAUDE.md`). The user's own `~/.claude/CLAUDE.md` is kept: it is a user file the handoff gate still reads when present |
| `.claude/skills/`, `.claude/agents/`, `.claude/rules/*.md` | `.cursor/skills/`, `.cursor/agents/`, `.cursor/rules/*.mdc` | Cursor's project locations |
| `CLAUDE_CODE_REMOTE=true` (cloud) | `KRU_CLOUD=1`, or `CURSOR_AGENT_SOCKET` set, or `/run/cursor/api.sock` present | Cursor's managed vms expose the agent metadata socket (`cursor.com/docs/cloud-agent/metadata`) |
| `CLAUDE_PROJECT_DIR` | `CURSOR_PROJECT_DIR` (falling back to `CLAUDE_PROJECT_DIR`, which Cursor also sets) | Cursor's hook env |
| the claude cloud environment (setup script, `.claude/cloud-setup.md`, `.claude/cloud-install.sh`, `settings.json` permission grants, a project `verify` skill run before commits) | `skills/kru-setup` §1d, hand-owned (`scripts/cursor/setup-1d.md`): `.cursor/environment.json` install, `~/.cursor/cli-config.json` / `.cursor/cli.json` permissions, `KRU_STORE_REPO` as a cloud agent secret; no pre-commit skill | Cursor's cloud environment and permission grammar. Cursor runs no project skill before a commit |
| review report path `${TMPDIR}/kru-review/…` | none: review seats return inline under their caps (`skills/kru-lead/references/gates.md`, hand-owned paragraph) | review seats run `readonly`, so they can't write a report file; the gate stops supplying a path they couldn't use |
| `claude plugin details` / `/plugin` → Configure | the plugin's entry under **Customize** | Cursor's plugin UI |
| `claude-code-guide` (the lead's harness source) | Cursor's docs (`SOURCES.md` → *Orchestration / harness mechanics*, hand-owned row) | the lead's own official source |

## Read-only seats

`code-reviewer`, `architecture-reviewer`, `accessibility-reviewer`, `visual-reviewer`, `ux-auditor`,
`ux-designer`, `conversion-copywriter` run with Cursor's `readonly`. Upstream let its reviewers write a
report file through the shell; `readonly` refuses that, so their long-form report comes back inline,
capped by each seat's *What you return* contract — the price of the stronger guarantee. `planner` and
`dispatch-auditor` keep the shell (the plan of record, the audit closeout) and are refused the Write
and Delete tools by `hooks/seat-guard.sh`, which maps a Task's `tool_call_id` to its seat at
`subagentStart` and reads it back through a tool call's `parent_tool_call_id`. That mapping uses a
field the CLI sends (`parent_tool_call_id`) that Cursor's docs don't list; where it is absent the
guard allows — and the seven readonly seats don't depend on it.

## Hand-owned — what a merge will not normalize

| file | why |
|---|---|
| `README.md`, `PORTING.md`, `MODELS.md`, `NOTICE` | the fork's own documents |
| `hooks/cursor-hook.sh`, `first-turn.sh`, `prompt-state.sh`, `seat-guard.sh`, `cursor-state.sh` | the Cursor seam. Per-conversation state lives under `${TMPDIR:-/tmp}/kru-cursor-<uid>/`, both levels `0700` and refused unless a real directory this user owns |
| `hooks/readonly-bash.test.sh` | tests the ported `hooks/readonly-bash.sh`, whose flag-writers port rules add: every flag is read off the segment's words with quotes resolved, so `'-o'` is `-o`. sed reads only on an allowlist (`-n -E -r -s -z -u`, `-e`, addresses, `p d D q = G g h H N P x l y { }`, `s///[gpIiMm0-9]*`), since its `w`/`W`/`e` need no separator; segments split on `|;&` and newlines only outside quotes; awk's `system (`/`getline`/`@include`/`@load` and an indirect `@name(` are checked on the raw line when awk is on it and again on the quote-resolved words, and awk `-f` or any flag but `-F`/`-v` is a write; plus `find -ok`/`-okdir`, `sort -o` and its GNU prefixes `--o…`, `sort --compress-program`, `--output` (not `--output-*`), `rg --pre`, `yq -i`/`--inplace`/`--split-exp`, `date -s`/`--set` or a clock operand, `command` but `-v`/`-V`, `uniq`'s second operand, `file -C`, `base64 -o`, `<(`; `xxd` leaves the read list |
| `scripts/cursor/readonly-words.sh` | the word splitter and the sed and awk allowlists the port inserts into `hooks/readonly-bash.sh` |
| `hooks/require-lead.sh`, `hooks/brainstorm-guard.sh` and their tests | Cursor-native rewrites of upstream's transcript-reading gates; an upstream change to their *rules* (what counts as a go, which tools are reads) needs mirroring by hand. Both still call upstream's `hooks/readonly-bash.sh` |
| `scripts/cursor/setup-1d.md` | `/kru-setup` §1d (grants, store repo, cloud environment), pulled in by a port rule |
| `scripts/cursor/gates-report-path.md` | the review-report paragraph of `gates.md` |
| `scripts/cursor/sources-harness-row.md` | `SOURCES.md` → *Orchestration / harness mechanics* |
| `skills/kru-update/claude.md`, `reviewed.md` | the sweep of claude code releases; layout rules only (below) |
| `skills/kru-eval-review/SKILL.md` | audits a claude plugin eval suite; layout rules only |

## Known gaps

- **The design canvas.** Upstream's design turn publishes Claude Design's canvas editor through the
  `Artifact` tool and syncs to a claude.ai/design project. Cursor reaches neither; the prose still
  names them (the port counts them on every run), and `ui-designer` loses the publish step with the
  `Artifact` tool. What replaces it isn't written yet: kru-opencode's `kru-artboards` skill (local
  `.dc.html` files the user opens) and Cursor's `/canvas` (React artifacts) are the two candidates.
- **Claude's bundled skills** `/run`, `/simplify`, `/research`, `/verify` and the *You should know* mod
  are named in places and have no Cursor counterpart; the seats fall back to their own sources.
- **`/kru-update`'s claude ground** still sweeps Claude Code releases as upstream wrote it; this
  fork's equivalent ground is Cursor's changelog and plugin docs. `/kru-propagate` and
  `/kru-eval-review` came over as upstream wrote them apart from the setup-file names.
- **Per-seat models in the CLI.** `cursor-agent` 2026.10.01 runs a plugin's agents on the parent's
  model (`MODELS.md`).
- **Task input and plugin hooks on cloud agents are partly undocumented.** The shape of `tool_input`
  for the Task tool, `parent_tool_call_id`, `additional_context` on a `preToolUse` answer, and
  whether a marketplace plugin's hooks run on a cloud agent (the docs list project, team and
  enterprise hooks) were read off the CLI or inferred; every one fails open.
- **The brainstorm lock doesn't follow a subagent**: a subagent's tool calls carry their own
  conversation id. The lead dispatches nothing while a brainstorm stands.

## Privacy

`scripts/privacy-scan.mjs` runs in `verify.sh` over the tree and over every commit (`git log -p
--all --diff-merges=first-parent`, so a merge's conflict resolution counts; added lines and
author/committer emails), plus gitleaks when installed (CI installs a pinned,
checksum-verified copy). It fails on tokens and keys, emails outside the reserved example domains and
an exact list of placeholder addresses the vendored docs use, paths off the author's machine, and
client or private-repo names — those matched by hash, so the scanner doesn't publish them.

- **Tree:** clean. One client repo name in `references/lossless-doc-compaction.md` is rewritten by a
  port rule; the eval prompt that named a client is dropped with `evals/`.
- **History:** this fork keeps upstream's history unchanged — it is already public, and a shared
  history is what makes `git merge upstream/main` work. The scan finds two reviewed lines in it, both
  in upstream commits and both removed from this tree (`82976d23` `evals/homepage-copy/prompt.md`,
  `b10943af` `skills/lead/references/lossless-doc-compaction.md`), and six gitleaks hits that are all
  documentation placeholders in vendored Cloudflare docs. No real secret.

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
answer is valid JSON. `scripts/cursor-smoke.sh` is the signed-in version: one headless turn in a
throwaway repo, passing when a kru hook fired (`KRU_HOOK_LOG`) and the agent names the kru rule,
skill and seat.

`KRU_HOOK_LOG=<file>` makes `hooks/cursor-hook.sh` append one JSON line per hook call (event, script,
exit, conversation) — the marker both scripts read, and a way to watch the hooks in a live session.
