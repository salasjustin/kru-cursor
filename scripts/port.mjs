#!/usr/bin/env node
// normalizes this fork's tree into a cursor plugin. every transform is
// idempotent, so the loop after a merge from upstream (github.com/ap-justin/kru) is:
//   git fetch upstream && git merge upstream/main && node scripts/port.mjs
// a merge that reintroduces claude-code vocabulary on a line is re-normalized
// rather than hand-patched, and `--check` fails loudly on what no rule covers:
// a required rule that stopped matching, a forbidden token that survived, a
// generated file that drifted.
//
// what it owns: the layout (skills/kru-<name>/, the claude-only files dropped),
// agent and skill frontmatter, the generated pieces (.cursor-plugin/, rules/,
// commands/, hooks/hooks.json), the version pin, and the harness-vocabulary
// rewrites. what it never touches: prose judgment. a rewrite that needs judgment
// is a hand-owned block (scripts/cursor/*.md) or a known gap in PORTING.md.

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, rmSync, renameSync, statSync } from "node:fs"
import { join, dirname, basename, relative } from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const CHECK = process.argv.includes("--check")
const QUIET = process.argv.includes("--quiet")

const PLUGIN = {
  name: "kru-cursor",
  displayName: "kru for Cursor",
  description:
    "kru, ported to Cursor: an engineering lead plus 41 specialist subagents, the skills they load, and the hooks that keep handoffs honest. A port of github.com/ap-justin/kru.",
  author: { name: "ap-justin" },
  repository: "https://github.com/salasjustin/kru-cursor",
  homepage: "https://github.com/salasjustin/kru-cursor",
  license: "MIT",
  keywords: ["subagents", "orchestration", "engineering-team", "skills", "hooks", "kru"],
  logo: "brand/kru-mark-512.png",
}
// every seat and skill carries the prefix: cursor's skill and agent names are
// one flat namespace shared with the user's own and every other plugin's, and
// `/update` is already a cursor cli command. upstream's `kru:<x>` maps to it 1:1.
const PREFIX = "kru-"

// ---------------------------------------------------------------------------
// models. upstream pins claude ids that cursor serves under the same slug; the
// rationale and the sources live in MODELS.md. effort becomes cursor's model
// parameter syntax (`id[effort=high]`), the documented home for it.
// ---------------------------------------------------------------------------
const CURSOR_MODELS = new Set(["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5", "claude-fable-5-1", "inherit"])
const MODEL_ALIAS = { opus: "claude-opus-5-5", sonnet: "claude-sonnet-5-5", haiku: "claude-haiku-5-5" }
const EFFORTS = new Set(["low", "medium", "high", "xhigh", "max"])

// seats upstream gives no Edit/Write tool split two ways here. the ones whose
// whole job writes nothing get cursor's `readonly`; these two write the store
// (the plan of record, the audit closeout) through the shell, which `readonly`
// would refuse, so they keep the shell and hooks/seat-guard.sh refuses them the
// Write and Delete tools instead — the same line upstream's allowlist drew.
const STORE_WRITERS = new Set(["planner", "dispatch-auditor"])

// where a seat keeps what it learned about one repo (upstream's Block Q). the
// path stays claude's so store-sync and /kru-setup's ignore line cover both forks.
const MEMORY_DIR = ".claude/agent-memory-local"
const MEMORY_LINE = (seat) =>
  `Your memory is \`${MEMORY_DIR}/${seat}/MEMORY.md\` in the working repo — Cursor supplies no agent memory, so read it at the start of a run when it exists, and keep it with the Write tool.`

// upstream files with no cursor meaning. a merge that brings one back is
// dropped again (and git shows it as a modify/delete conflict to resolve as delete).
const DROP = [
  ".claude-plugin", // → .cursor-plugin/, generated below
  ".claude", //        upstream's own release tooling for claude code
  "evals", //          `claude plugin eval` suites
  "TESTING.md", //     upstream's claude-plugin test guide; PORTING.md → Verify carries ours
  "scripts/smoke.sh", // a live `claude -p` run; scripts/cursor-smoke.sh is ours
  "hooks/check-task-tools.sh", // cursor's todo list is always on
  "hooks/check-task-tools.test.sh",
  "skills/setup/cloud-install.sh", // a claude cloud sessionstart template; cursor installs from .cursor/environment.json
]

// fork-owned files: written for cursor by hand, never rewritten by rule. a merge
// that touches one is a human read (PORTING.md → Hand-owned).
const FORK_OWNED = new Set([
  "README.md",
  "PORTING.md",
  "MODELS.md",
  "NOTICE",
  "scripts/port.mjs",
  "scripts/verify.sh",
  "scripts/verify-tree.mjs",
  "scripts/privacy-scan.mjs",
  "scripts/cursor-hooks.test.sh",
  "scripts/cursor-smoke.sh",
  "hooks/cursor-hook.sh",
  "hooks/require-lead.sh",
  "hooks/require-lead.test.sh",
  "hooks/brainstorm-guard.sh",
  "hooks/brainstorm-guard.test.sh",
  "hooks/prompt-state.sh",
  "hooks/seat-guard.sh",
  "hooks/first-turn.sh",
  "hooks/cursor-state.sh",
])
const FORK_OWNED_DIRS = /^(scripts\/cursor\/|\.cursor-plugin\/|rules\/|commands\/|\.github\/)/

// files that talk about claude on purpose and get only the layout and name
// rules: the official-source map's vendoring rows, the claude release ledger the
// update skill keeps, eval-review (it audits a claude plugin eval suite).
const PATHS_ONLY = /^(skills\/kru-update\/(claude|reviewed)\.md|skills\/kru-eval-review\/SKILL\.md)$/

// ---------------------------------------------------------------------------
// rewrite rules. each is [regex, replacement, opts]: `files` narrows it to
// matching paths, `required` makes the port fail when that file stops matching
// (an upstream rewording the rule no longer sees), `sh`/`md` pick the file kind.
// order matters: the narrow rules run before the generic ones, and no
// replacement re-matches its own rule.
// ---------------------------------------------------------------------------
const PATHS_END = Symbol("paths-end")
const R = (re, to, opts = {}) => ({ re, to, ...opts })

const RULES = [
  // the plugin root. cursor substitutes ${CURSOR_PLUGIN_ROOT} (and claude's
  // spelling) in a plugin's skills, agents, rules, commands and hook commands at
  // load, and sets it in a hook's environment; mcp.json is the documented case.
  R(/\$\{CLAUDE_PLUGIN_ROOT\}\/skills\/(?!kru-)([a-z0-9-]+)/g, "${CURSOR_PLUGIN_ROOT}/skills/kru-$1"),
  R(/\$\{CLAUDE_PLUGIN_ROOT\}/g, "${CURSOR_PLUGIN_ROOT}"),
  R(/\$CLAUDE_PLUGIN_ROOT\b/g, "$CURSOR_PLUGIN_ROOT"),
  // in-tree skill paths, in every form the prose and the scripts spell them
  R(/(^|[\s`('"[{|=])skills\/(?!kru-)([a-z0-9][a-z0-9-]*)(?=\/|\b(?![.-]))/gm, "$1skills/kru-$2"),
  R(/\$plugin_root\/skills\/(?!kru-)([a-z0-9-]+)/g, "$plugin_root/skills/kru-$1"),
  R(/(^|[\s`(])skills\/\{(?!kru-)([a-z0-9,-]+)\}/gm, (_m, p, list) => `${p}skills/{${list.split(",").map((n) => PREFIX + n).join(",")}}`),
  R(/`skills\/\*`/g, "`skills/kru-*`"),
  R(/(^|[\s`('"])skills\/\*\//gm, "$1skills/kru-*/"),
  // commands and names: /kru:brief → /kru-brief, kru:lead → kru-lead
  R(/\/kru:([a-z0-9-]+)/g, "/kru-$1"),
  R(/\bkru:(?=[a-z\[$])/g, PREFIX),
  R(/#kru:\}/g, "#kru-}"),
  // the plugin's own manifests
  R(/`\.claude-plugin\/plugin\.json`/g, "`.cursor-plugin/plugin.json`"),
  R(/`\.claude-plugin\/marketplace\.json`/g, "`.cursor-plugin/marketplace.json`"),
  R(/\.claude-plugin\/plugin\.json/g, ".cursor-plugin/plugin.json"),
  R(/\.claude-plugin\/marketplace\.json/g, ".cursor-plugin/marketplace.json"),
  // ↑ the layout and the names: everything above also runs on PATHS_ONLY files
  PATHS_END,

  // --- the hooks (shell) -----------------------------------------------------
  // plugin hooks run with the install dir as cwd; hooks/cursor-hook.sh passes the
  // root as $1 and changes into the project before the hook runs
  R(/\(substituted in hooks\.json\)/g, "(passed by hooks/cursor-hook.sh)", { sh: true }),
  // the team's own repo has no sheet by design
  R(/-u CLAUDE_PLUGIN_ROOT\b/g, "-u CURSOR_PLUGIN_ROOT", { sh: true }),
  R(/\.claude-plugin\b/g, ".cursor-plugin", { sh: true }),
  // the repo sheet: claude reads .claude/CLAUDE.md, cursor AGENTS.md at the root
  R(/"\$cwd\/\.claude\/CLAUDE\.md"/g, '"$cwd/AGENTS.md"', { sh: true }),
  R(/"\$top\/\.claude\/CLAUDE\.md"/g, '"$top/AGENTS.md"', { sh: true }),
  R(/"\$cwd\/AGENTS\.md" "\$cwd\/AGENTS\.md"/g, '"$cwd/AGENTS.md"', { sh: true }),
  R(/"\$cwd"\/\.claude\/rules\/\*\.md/g, '"$cwd"/.cursor/rules/*.mdc', { sh: true, files: /^hooks\/check-handoff\.sh$/, required: /\.cursor\/rules\/\*\.mdc/ }),
  // a review seat runs `readonly` here (agents/<seat>.md), so it can write no
  // report file: the gate stops supplying a path it couldn't use, and the seat
  // returns inline under its caps (PORTING.md → Read-only seats)
  R(/^  code-reviewer\|architecture-reviewer\|accessibility-reviewer\|visual-reviewer\|ux-auditor\)$/m, "  __readonly_seats_return_inline__)", { sh: true, files: /^hooks\/check-handoff\.sh$/, required: /__readonly_seats_return_inline__/ }),
  R(/^check supply kru-code-reviewer "Review the signup diff\." "(kru-review|code-reviewer-t\.md)"$/gm, 'check allow kru-code-reviewer "Review the signup diff."', { sh: true, files: /^hooks\/check-handoff\.test\.sh$/, required: /^check allow kru-code-reviewer "Review the signup diff\."$/m }),
  // test fixtures that write a repo's sheet where claude reads it
  R(/(\$sandbox\/(?!home\/)[a-z]+)\/\.claude\/CLAUDE\.md/g, "$1/AGENTS.md", { sh: true, files: /\.test\.sh$/ }),
  // a no-edit seat: upstream reads the tools: allowlist, which the port turns
  // into `readonly` (or, for the store writers, hooks/seat-guard.sh)
  R(/grep -m1 '\^tools:' "\$plugin_root\/agents\/\$seat\.md" \| grep -qvE '\\b\(Edit\|Write\)\\b' && readonly_seat=true/g,
    `{ grep -q '^readonly: true' "$plugin_root/agents/$seat.md" || case "$seat" in ${[...STORE_WRITERS].join("|")}) true ;; *) false ;; esac; } && readonly_seat=true`,
    { sh: true, files: /^hooks\/check-handoff\.sh$/, required: /grep -q '\^readonly: true' "\$plugin_root\/agents\/\$seat\.md"/ }),
  // the asset deps live outside the install dir, which a plugin update replaces;
  // cursor has no per-plugin data dir, so they go in the user's data dir
  R(/data="\$\{CLAUDE_PLUGIN_DATA:-\$HOME\/\.claude\/plugins\/data\/kru-kru\}\/asset"/g, 'data="${KRU_PLUGIN_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/kru-cursor}/asset"', { sh: true, files: /^scripts\/asset\/run\.sh$/, required: /KRU_PLUGIN_DATA:-/ }),
  R(/# package\.json \+ lockfile into every cached plugin version — 65 MB a version for\n# two seats that rarely run — while \$\{CLAUDE_PLUGIN_DATA\} survives updates\./g,
    "# package.json + lockfile into every cached plugin version — 65 MB a version for\n# two seats that rarely run. cursor has no plugin data dir, so on cursor they live\n# in the user's data dir (KRU_PLUGIN_DATA overrides) — outside the store, which a\n# store repo would sync — where a plugin update leaves them.", { sh: true, files: /^scripts\/asset\/run\.sh$/ }),
  // the read-only listings a triage turn reaches for, cursor's cli
  R(/'claude mcp list'\*\|'claude plugin list'\*\|'claude plugin details'\*\)/g, "'agent mcp list'*|'agent status'*|'agent models'*|'cursor-agent mcp list'*|'cursor-agent status'*)", { sh: true, files: /^hooks\/readonly-bash\.sh$/, required: /'agent mcp list'/ }),
  // a cloud vm: cursor's managed vms expose the agent metadata socket
  R(/kru_is_cloud\(\) \{ \[ "\$\{CLAUDE_CODE_REMOTE:-\}" = "true" \]; \}/g,
    'kru_is_cloud() { [ "${KRU_CLOUD:-}" = "1" ] || [ -n "${CURSOR_AGENT_SOCKET:-}" ] || [ -S /run/cursor/api.sock ]; }', { sh: true, files: /^scripts\/kru-store\.sh$/, required: /CURSOR_AGENT_SOCKET/ }),
  R(/CLAUDE_CODE_REMOTE=true/g, "KRU_CLOUD=1", { sh: true, files: /^scripts\/kru-store\.test\.sh$/ }),
  R(/-u CLAUDE_CODE_REMOTE\b/g, "-u KRU_CLOUD -u CURSOR_AGENT_SOCKET", { sh: true }),
  R(/(?<!CURSOR_PROJECT_DIR:-)\$\{CLAUDE_PROJECT_DIR:-\$PWD\}/g, "${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}", { sh: true }),
  // plugin options: cursor declares `variables` instead of claude's userConfig,
  // and none of kru's settings is a variable (they are env vars a hook reads)
  R(/# the plugin's \/plugin options \(plugin\.json `userConfig`\) reach a hook as\n# CLAUDE_PLUGIN_OPTION_<KEY>\./g,
    "# claude's /plugin options reach a hook as CLAUDE_PLUGIN_OPTION_<KEY>; cursor has\n# no equivalent, so on cursor only the env vars below are read. kept for a\n# claude install of the same tree (CLAUDE_PLUGIN_OPTION_<KEY>).", { sh: true }),
  // the roster audit (scripts/audit.sh): the manifests, the name prefix, the
  // model syntax and the memory marker all moved
  R(/\[ "\$\(jq -r '\.plugins\[\] \| select\(\.name == "kru"\) \| \.version' \.cursor-plugin\/marketplace\.json\)" = "\$v" \]/g,
    `[ "$(jq -r '.plugins[] | select(.name == "${PLUGIN.name}") | .version' .cursor-plugin/marketplace.json)" = "$v" ]`, { sh: true, files: /^scripts\/audit\.sh$/, required: /select\(\.name == "kru-cursor"\)/ }),
  R(/\[ "\$\(sed -n '2,\/\^---\$\/s\/\^name: \*\/\/p' "\$f" \| tr -d '"'\)" = "\$n" \] \|\| bad "\$f name != file stem"/g,
    `[ "$(sed -n '2,/^---$/s/^name: *//p' "$f" | tr -d '"')" = "${PREFIX}$n" ] || bad "$f name != ${PREFIX}<file stem>"`, { sh: true, files: /^scripts\/audit\.sh$/, required: /= "kru-\$n" \]/ }),
  R(/\[\[ \$m =~ \^claude-\(opus\|sonnet\|haiku\)-\[0-9\]\+-\[0-9\]\+\$ \]\]/g,
    "[[ $m =~ ^claude-(opus|sonnet|haiku)-[0-9]+-[0-9]+(\\[effort=(low|medium|high|xhigh|max)\\])?$ ]]", { sh: true, files: /^scripts\/audit\.sh$/, required: /\\\[effort=/ }),
  R(/grep -l '\^memory: local' agents\/\*\.md/g, `grep -l '${MEMORY_DIR}/' agents/*.md`, { sh: true, files: /^scripts\/audit\.sh$/, required: /agent-memory-local\/. agents/ }),
  R(/"Block Q heading and memory: local seat lists differ"/g, '"Block Q heading and memory line seat lists differ"', { sh: true, files: /^scripts\/audit\.sh$/ }),
  R(/for h in \$\(grep -oE 'hooks\/\[a-z0-9-\]\+\\\.sh' hooks\/hooks\.json \| sort -u\); do/g,
    "for h in $(grep -oE 'hooks/[a-z0-9-]+\\.sh' hooks/hooks.json | sort -u) $(jq -r '.hooks[][].command' hooks/hooks.json | grep -oE ' [a-z0-9-]+\\.sh( |$)' | tr -d ' ' | sed 's#^#hooks/#' | sort -u); do", { sh: true, files: /^scripts\/audit\.sh$/, required: /jq -r .\.hooks\[\]\[\]\.command/ }),

  // --- prose (markdown) ---------------------------------------------------------
  // the instruction files: cursor reads AGENTS.md (and CLAUDE.md) at a repo
  // root and .cursor/rules/*.mdc. the user's own ~/.claude/CLAUDE.md is kept as
  // is — it's the user's rules file, which the handoff gate still reads.
  R(/(~|\$HOME)\/\.claude\/CLAUDE\.md/g, "{USER_RULES}$1", { md: true }),
  R(/(^|[\s`('"(\/])\.claude\/CLAUDE\.md/gm, "$1AGENTS.md", { md: true }),
  R(/\bCLAUDE\.md\b/g, "AGENTS.md", { md: true }),
  R(/\{USER_RULES\}(~|\$HOME)/g, "$1/.claude/CLAUDE.md", { md: true }),
  R(/(`?)AGENTS\.md\1(?:\s*(?:\/|,|\bor\b)\s*\1AGENTS\.md\1)+/g, "$1AGENTS.md$1", { md: true }),
  R(/\ba (`?)AGENTS\.md/g, "an $1AGENTS.md", { md: true }),
  R(/`\.claude\/rules\/`/g, "`.cursor/rules/`", { md: true }),
  R(/\.claude\/skills\//g, ".cursor/skills/", { md: true }),
  R(/\.claude\/agents\//g, ".cursor/agents/", { md: true }),
  // the tools: cursor's subagent tool is Task, its shell tool Shell, and it has
  // one todo list, always on — no task tools to fall back from
  R(/the task tools \(`TaskCreate` ·\s+`TaskUpdate`, or `TodoWrite` where those are off\)/g, "the agent's todo list (always on in Cursor)", { md: true, files: /^skills\/kru-lead\/SKILL\.md$/, required: /the agent's todo list \(always on in Cursor\)/ }),
  R(/the task tools \(`TaskCreate` · `TodoWrite`\)/g, "the agent's todo list", { md: true }),
  R(/\bTodoWrite\b/g, "the todo list", { md: true }),
  R(/\bfresh `Agent` call\b/g, "fresh `Task` call", { md: true }),
  R(/\bthe `?Agent`? tool\b/g, "the Task tool", { md: true }),
  R(/\bteam-seat `Agent` launch\b/g, "team-seat `Task` launch", { md: true }),
  R(/`SendMessage`\/resume/g, "resuming the subagent by its agent ID", { md: true }),
  R(/`SendMessage`/g, "resuming the subagent by its agent ID", { md: true }),
  // claude's bundled delegates → cursor's. Explore is a cursor built-in under the
  // same name; claude's Plan agent is cursor's Plan mode; /code-review is /review
  R(/`Plan`/g, "Plan mode", { md: true }),
  R(/`\/code-review`/g, "`/review`", { md: true }),
  R(/(^|[\s(])\/code-review\b/gm, "$1/review", { md: true }),
  // mcp tool ids: claude spells them mcp__<server>__<tool>; cursor names a server
  // and its tool, and permission rules write Mcp(server:tool)
  R(/`mcp__([a-z0-9-]+(?:_[a-z0-9-]+)*?)__([A-Za-z0-9_*-]+)`/g, "`$2` (`$1` MCP)", { md: true }),
  R(/\bmcp__([a-z0-9-]+(?:_[a-z0-9-]+)*?)__([A-Za-z0-9_*-]+)/g, "$2 ($1 MCP)", { md: true }),
  R(/\bmcp__/g, "MCP ", { md: true }),
  // install and listing commands
  R(/`claude mcp list` and `claude plugin list`/g, "`agent mcp list` and the plugins under **Customize**", { md: true }),
  R(/`claude mcp add --scope local`, and\s+`claude plugin enable --scope project` \(`--scope local` in a shared repo, so it stays out of the\s+commit\)/g,
    "an entry in the repo's `.cursor/mcp.json`, and\na project-scope install from **Customize** (a user-scope one in a shared repo, so it stays out of\nthe commit)", { md: true, files: /^skills\/kru-setup\/SKILL\.md$/, required: /an entry in the repo's `\.cursor\/mcp\.json`/ }),
  R(/\*\*The lead's board is user-scoped too\.\*\*[\s\S]*?lands on their next restart\.\n/g,
    "**The lead's board needs nothing.** Cursor's todo list is always on, so there is no switch to set.\n", { md: true, files: /^skills\/kru-setup\/SKILL\.md$/, required: /The lead's board needs nothing/ }),
  R(/\| `mcp` \| `agent mcp list` and the plugins under \*\*Customize\*\*,/g, "| `mcp` | `agent mcp list` and the plugins under **Customize**,", { md: true }),
  R(/`claude plugin details kru`/g, "the plugin's entry under **Customize**", { md: true }),
  R(/\ba `claude plugin eval` suite\b/g, "a claude plugin eval suite (kept from upstream; Cursor has no eval runner)", { md: true, files: /^ROSTER\.md$/ }),
  // turso's claude plugin is its hosted mcp server plus a skill kru vendors; in
  // cursor the server is added directly
  R(/`\/plugin marketplace add tursodatabase\/turso-mcp`, `\/plugin install turso@turso`, then `\/mcp` → \*\*turso\*\* → Authenticate/g,
    "the hosted MCP server `https://mcp.turso.ai/mcp` added under **Customize** → MCP (or in the repo's `.cursor/mcp.json`), then authenticated from that entry", { md: true, files: /^agents\/turso-specialist\.md$/, required: /mcp\.turso\.ai\/mcp` added under/ }),
  R(/the \*\*Turso plugin\*\* \(`\/plugin marketplace add tursodatabase\/turso-mcp`, `\/plugin install turso@turso`; its `turso` skill \+ the hosted MCP/g,
    "the **Turso MCP server** (added in Cursor under **Customize** → MCP; upstream installs it as a claude plugin with a `turso` skill) — the hosted MCP", { md: true, files: /^SOURCES\.md$/, required: /the \*\*Turso MCP server\*\*/ }),
  // mcp installs: claude's `claude mcp add` → an entry in cursor's mcp.json, and
  // the vendors' own installers take a cursor flag
  R(/`claude mcp add --transport http ([a-z0-9-]+) (https:\/\/[^\s`]+)`/g, '`"$1": { "url": "$2" }` in `.cursor/mcp.json`', { md: true }),
  R(/`claude mcp add ([a-z0-9-]+) -- ([^`]+)`/g, '`"$1": { "command": "$2" }` in `.cursor/mcp.json` (split into `command` + `args`)', { md: true }),
  R(/\(`claude mcp add` with no `--scope project`\)/g, "(`~/.cursor/mcp.json` rather than the repo's `.cursor/mcp.json`)", { md: true }),
  R(/`npx auth@latest mcp --claude-code`/g, "`npx auth@latest mcp --cursor`", { md: true }),
  R(/mcp init --client claude\b/g, "mcp init --client cursor", { md: true }),
  R(/`fly mcp server --claude`/g, "`fly mcp server --cursor`", { md: true }),
  // what /kru-setup writes, and so what /kru-propagate carries: no claude cloud files here
  R(/the sheet section in `AGENTS\.md`, `\.claude\/cloud-setup\.md`, the cloud install hook it registers, and the grants in `\.claude\/settings\.json`/g,
    "the sheet section in `AGENTS.md`, `.cursor/environment.json`, and the grants in `.cursor/cli.json`", { md: true, files: /^skills\/kru-propagate\/SKILL\.md$/, required: /`\.cursor\/environment\.json`, and the grants in `\.cursor\/cli\.json`/ }),
  R(/ — or a `\.claude\/cloud-setup\.md`\./g, " — or a `.cursor/environment.json` setup wrote.", { md: true, files: /^skills\/kru-propagate\/SKILL\.md$/ }),
  R(/A cloud session pushes its own `claude\/\*` branch/g, "A cloud agent pushes its own branch", { md: true }),
  // the model tiers stay upstream's; how cursor reads them is MODELS.md's
  R(/^## Model tiers\n(?!In kru-cursor)/m, "## Model tiers\nIn kru-cursor the pins below land as `MODELS.md` says: `effort` becomes the model id's `[effort=…]` parameter, `experimental.cacheTtl` has no Cursor equivalent, and `scripts/port.mjs` writes every seat's `model:` line.\n\n", { md: true, files: /^ROSTER\.md$/, required: /^In kru-cursor the pins below land as `MODELS\.md` says/m }),
  // the store's cloud surface
  R(/cloud session \(`CLAUDE_CODE_REMOTE=true`\)/g, "cloud agent (`CURSOR_AGENT_SOCKET` set, or `KRU_CLOUD=1`)", { md: true }),
  // the harness itself. "Claude Code channel(s)" is a product extension-builder
  // builds, not the harness, so it stays
  R(/\s*\(resolves in both local and web plugin loads\)/g, " (it resolves in local and cloud-agent loads alike)", { md: true }),
  R(/\bClaude Code's own plan mode\b/g, "Cursor's own Plan mode", { md: true }),
  R(/\bClaude Code\b(?! channels?\b)(?!'s own system prompt)(?!'s todo tool)/g, "Cursor", { md: true }),
  // hooks vocabulary: cursor's events are camel-case, and a stop hook auto-submits
  // its follow-up as the next user message rather than blocking the stop
  R(/\bthe plugin'?s?( own)? `hooks\/hooks\.json`/g, "the plugin's `hooks/hooks.json`", { md: true }),
  R(/\bSessionStart hook\b/g, "sessionStart hook", { md: true }),
  R(/\bSubagentStop\b/g, "subagentStop", { md: true }),
  R(/\bPreToolUse\b/g, "preToolUse", { md: true }),
  R(/\bPostToolUse\b/g, "postToolUse", { md: true }),
  // the design surface upstream publishes to is claude.ai's; the seats still
  // name it, and PORTING.md → Known gaps says what cursor has instead
  // (counted by WATCH below, never rewritten)
  // the version-and-wiring map: no claude manifests here
  R(/\*\*both\*\* `plugin\.json` and `marketplace\.json` descriptions/g, "**both** `.cursor-plugin/plugin.json` and `.cursor-plugin/marketplace.json` descriptions", { md: true }),
  R(/(?<![./])`plugin\.json`(?! version)/g, "`.cursor-plugin/plugin.json`", { md: true }),
  R(/(?<![./])`marketplace\.json`/g, "`.cursor-plugin/marketplace.json`", { md: true }),
  R(/`\.cursor-plugin\/\.cursor-plugin\//g, "`.cursor-plugin/", { md: true }),
  // the review report: review seats run readonly here (see the shell rule above)
  R(/\*\*Name a report path in every review brief\.\*\*[^\n]*/g, () => block("gates-report-path.md"), { md: true, files: /^skills\/kru-lead\/references\/gates\.md$/, required: /\*\*Name no report path in a review brief\.\*\*/ }),
  R(/7\. \*\*What comes back\*\* — the return shape, plus a report path on a review brief \(Step 4\)\./g,
    "7. **What comes back** — the return shape (a review seat returns inline here — `gates.md`, Step 4).", { md: true, files: /^skills\/kru-lead\/SKILL\.md$/, required: /a review seat returns inline here/ }),
  R(/Two it supplies rather than refuses when a brief lacks them: item 7's report path and the learnings channel\./g,
    "One it supplies rather than refuses when a brief lacks it: the learnings channel.", { md: true, files: /^skills\/kru-lead\/SKILL\.md$/, required: /One it supplies rather than refuses/ }),
  R(/^- \*\*A report path, named per seat\*\*[^\n]*/gm, "- **No report path** — review seats run `readonly` in this fork, so each returns inline under its own caps (`gates.md`).", { md: true, files: /^skills\/kru-lead\/references\/screen-passes\.md$/, required: /\*\*No report path\*\*/ }),
  R(/^- \[workflow\] handoffs to review seats named no report path twice this session[^\n]*\n/gm, "", { md: true, files: /^agents\/dispatch-auditor\.md$/ }),
  // the setup skill's grants, store repo and cloud environment are claude's
  // settings grammar end to end; the cursor section is hand-owned
  R(/### 1d\. Grant what the team does on every run — \*full run\*[\s\S]*?(?=### 1e\. )/g, () => block("setup-1d.md"), { md: true, files: /^skills\/kru-setup\/SKILL\.md$/, required: /### 1d\. Grant what the team does on every run/ }),
  // the official-source map's harness row: cursor's docs are the lead's own source
  R(/^\| \*\*Orchestration \/ harness mechanics\*\*[^\n]*/gm, () => block("sources-harness-row.md").trimEnd(), { md: true, files: /^SOURCES\.md$/, required: /^\| \*\*Orchestration \/ harness mechanics\*\*/m }),
  // a client's repo name out of a public reference (PORTING.md → Privacy)
  R(/Exercised on `[a-z0-9-]+` (\d{4}-\d{2}-\d{2}):/g, "Exercised on a production plan store $1:", { md: true, files: /^references\/lossless-doc-compaction\.md$/, required: /Exercised on a production plan store/ }),
]

// files whose hand-owned block a rule pulls in
function block(name) {
  return readF(join(ROOT, "scripts", "cursor", name))
}

// tokens that must not survive a port anywhere outside the fork-owned files. a
// hit means a new upstream phrasing no rule covers — the port fails rather
// than shipping it.
const FORBIDDEN = [
  /CLAUDE_PLUGIN_ROOT/,
  /\.claude-plugin/,
  /\/kru:[a-z]/,
  /\bkru:[a-z]/,
  /\bmcp__/,
  /claude plugin (install|marketplace)/,
  /\/plugin (install|marketplace)/,
  /\bTaskCreate\b|\bTaskUpdate\b/,
  /CLAUDE_PLUGIN_DATA/,
]
// files a FORBIDDEN token may stay in: the claude release ledger the update
// skill keeps reads claude's names by design (PORTING.md → Known gaps)
const FORBIDDEN_OK = /^skills\/kru-update\/(claude|reviewed)\.md$/

// surfaces cursor has no equivalent for. the port can't rewrite them — each is
// a judgment call recorded in PORTING.md — so it counts and warns.
const WATCH = [/\bClaude Design\b/, /\bclaude\.ai\b/, /(^|[\s`(])\/design\b/, /\bArtifact\b/, /(^|[\s`(])\/(run|simplify|research|verify)\b/]

// ---------------------------------------------------------------------------
const log = (...a) => !QUIET && console.log(...a)
const changed = []
const problems = []
const contents = new Map()
const exists = (p) => (contents.has(p) ? contents.get(p) !== null : existsSync(p))

function readF(path) {
  if (!contents.has(path)) contents.set(path, existsSync(path) ? readFileSync(path, "utf8") : null)
  return contents.get(path)
}
function write(path, next) {
  const prev = readF(path)
  contents.set(path, next)
  if (prev === next) return false
  changed.push(relative(ROOT, path))
  if (!CHECK) {
    mkdirSync(dirname(path), { recursive: true })
    writeFileSync(path, next)
  }
  return true
}
function remove(path) {
  if (!existsSync(path)) return
  changed.push(`- ${relative(ROOT, path)}`)
  if (!CHECK) rmSync(path, { recursive: true, force: true })
}
function walk(dir, out = []) {
  if (!existsSync(dir)) return out
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if ([".git", "node_modules"].includes(e.name) || e.name.startsWith(".venv")) continue
    const p = join(dir, e.name)
    e.isDirectory() ? walk(p, out) : out.push(p)
  }
  return out
}

// --- frontmatter --------------------------------------------------------------
// naive on purpose: kru frontmatter is `key: value` lines plus indented
// continuation lines, and a yaml dependency in a port script is a dependency in
// every merge. entries keep their raw lines so an untouched key round-trips.
function splitFrontmatter(src) {
  const m = src.match(/^---\n([\s\S]*?)\n---\n?/)
  if (!m) return null
  const entries = []
  for (const line of m[1].split("\n")) {
    const k = line.match(/^([A-Za-z][A-Za-z0-9_-]*):(.*)$/)
    if (k) entries.push({ key: k[1], lines: [line] })
    else if (entries.length) entries.at(-1).lines.push(line)
    else entries.push({ key: "", lines: [line] })
  }
  return { entries, body: src.slice(m[0].length) }
}
const value = (e) => (e ? [e.lines[0].replace(/^[^:]+:\s*/, ""), ...e.lines.slice(1).map((l) => l.trim())].join(" ").trim() : null)
const get = (fm, key) => fm.entries.find((e) => e.key === key)
// a quoted yaml scalar decoded to its string, so re-encoding it is a fixed point
const unquote = (s) => {
  if (!s) return s
  if (/^".*"$/.test(s)) {
    try {
      return JSON.parse(s)
    } catch {
      return s.slice(1, -1)
    }
  }
  return /^'.*'$/.test(s) ? s.slice(1, -1).replace(/''/g, "'") : s
}
// a value yaml reads back as the same string: plain when it can be, else
// double-quoted (json's escaping is valid yaml)
const scalar = (v) => (/:\s|\s#|^[\s'"&*!|>%@`{}[\],?#-]|\s$|^$/.test(v) ? JSON.stringify(v) : v)
const joinFm = (lines, body) => `---\n${lines.join("\n")}\n---\n${body.replace(/^\n*/, "\n")}`

// --- step 1: layout -------------------------------------------------------------
function relayout() {
  for (const d of DROP) remove(join(ROOT, d))
  const skillsDir = join(ROOT, "skills")
  for (const d of readdirSync(skillsDir)) {
    if (d.startsWith(PREFIX) || !statSync(join(skillsDir, d)).isDirectory()) continue
    const to = join(skillsDir, PREFIX + d)
    if (existsSync(to)) {
      problems.push(`skills/${d} and skills/${PREFIX}${d} both exist — a merge brought an upstream edit in beside the ported copy; move its change across and delete skills/${d}`)
      continue
    }
    changed.push(`skills/${d} → skills/${PREFIX}${d}`)
    if (!CHECK) renameSync(join(skillsDir, d), to)
    else contents.set(`__renamed:${d}`, to)
  }
}
const skillDirs = () => {
  const dir = join(ROOT, "skills")
  const all = readdirSync(dir).filter((d) => statSync(join(dir, d)).isDirectory())
  // under --check the rename is virtual: read from the upstream dir
  return all.map((d) => ({ name: d.startsWith(PREFIX) ? d : PREFIX + d, path: join(dir, d) }))
}
const seatNames = () => readdirSync(join(ROOT, "agents")).filter((f) => f.endsWith(".md")).map((f) => basename(f, ".md"))

// --- step 2: agents ---------------------------------------------------------------
// returns the seats hooks/seat-guard.sh refuses the Write and Delete tools
function portAgents() {
  const noEdit = []
  for (const seat of seatNames()) {
    const path = join(ROOT, "agents", `${seat}.md`)
    const fm = splitFrontmatter(readF(path))
    if (!fm) {
      problems.push(`agents/${seat}.md: no frontmatter`)
      continue
    }
    const description = unquote(value(get(fm, "description")))
    if (!description) problems.push(`agents/${seat}.md: no description`)
    // upstream spells the allowlist `tools:`; a ported tree spells the result as
    // `readonly`. upstream wins when a merge brings the tools line back.
    const tools = value(get(fm, "tools"))
    let readOnly, guarded
    if (tools !== null) {
      const edits = /\b(Edit|Write|NotebookEdit|MultiEdit)\b/.test(tools)
      guarded = !edits
      readOnly = !edits && !STORE_WRITERS.has(seat)
      if (STORE_WRITERS.has(seat) && edits) problems.push(`agents/${seat}.md: upstream gave ${seat} an edit tool — drop it from STORE_WRITERS in scripts/port.mjs`)
    } else {
      readOnly = value(get(fm, "readonly")) === "true"
      guarded = readOnly || STORE_WRITERS.has(seat)
    }
    if (guarded) noEdit.push(seat)

    let model = unquote(value(get(fm, "model"))) ?? "inherit"
    model = MODEL_ALIAS[model] ?? model
    const base = model.replace(/\[.*\]$/, "")
    const effort = value(get(fm, "effort"))
    if (effort) {
      if (!EFFORTS.has(effort)) problems.push(`agents/${seat}.md: effort ${effort} is not one cursor takes`)
      model = `${base}[effort=${effort}]`
    }
    if (!CURSOR_MODELS.has(base)) problems.push(`agents/${seat}.md: model ${base} is not in CURSOR_MODELS (MODELS.md)`)

    // cursor's agent parser reads one line per key, so the description stays one line
    const out = [`name: ${PREFIX}${seat}`, `description: ${scalar(description)}`, `model: ${model}`]
    // `readonly` is the documented field; the plugin loader in cursor-agent
    // 2026.10.01 reads `permissionMode: readonly` for a plugin's agents
    // (MODELS.md → Sources), so both are written and either loader enforces it
    if (readOnly) out.push("readonly: true", "permissionMode: readonly")

    let body = fm.body
    if (get(fm, "memory") || body.includes(MEMORY_LINE(seat))) {
      if (!body.includes(MEMORY_LINE(seat))) {
        if (/^## Memory \(this repo's facts\)\n/m.test(body)) body = body.replace(/^## Memory \(this repo's facts\)\n/m, (h) => `${h}${MEMORY_LINE(seat)}\n`)
        else problems.push(`agents/${seat}.md: memory: local but no "## Memory (this repo's facts)" heading to carry the line`)
      }
    }
    write(path, joinFm(out, body))
  }
  return noEdit.sort()
}

// --- step 3: skills -----------------------------------------------------------------
// claude-only skill keys: `user-invocable` (hide from the menu — every cursor
// skill is in the / menu) and `allowed-tools` (no per-skill tool allowlist).
// `argument-hint` stays: cursor ignores it, and it is what marks a skill the
// user invokes, which step 6 turns into a command.
const SKILL_DROP = new Set(["user-invocable", "allowed-tools"])
function portSkills() {
  for (const { name, path: dir } of skillDirs()) {
    const path = join(dir, "SKILL.md")
    if (!exists(path)) {
      problems.push(`skills/${name}: no SKILL.md`)
      continue
    }
    const fm = splitFrontmatter(readF(path))
    if (!fm) {
      problems.push(`skills/${name}: no frontmatter`)
      continue
    }
    const lines = []
    let named = false
    for (const e of fm.entries) {
      if (SKILL_DROP.has(e.key)) continue
      if (e.key === "name") {
        lines.push(`name: ${name}`)
        named = true
        continue
      }
      lines.push(...e.lines)
    }
    if (!named) lines.unshift(`name: ${name}`)
    write(path, joinFm(lines, fm.body))
  }
}

// --- step 4: vocabulary across every text file ----------------------------------------
function rewrite(text, rel) {
  const sh = /\.sh$/.test(rel)
  const md = /\.(md|mdc)$/.test(rel)
  const pathsOnly = PATHS_ONLY.test(rel)
  let out = text
  for (const rule of RULES) {
    if (rule === PATHS_END) {
      if (pathsOnly) break
      continue
    }
    if (rule.sh && !sh) continue
    if (rule.md && !md) continue
    if (rule.files && !rule.files.test(rel)) continue
    const next = out.replace(rule.re, rule.to)
    // a required rule that already ran leaves text it no longer matches; its
    // `done` marker standing in the output is the proof it applied
    if (rule.required) rule.hits = (rule.hits ?? 0) + (out.search(rule.re) !== -1 || rule.required.test(next) ? 1 : 0)
    out = next
  }
  // upstream spells its commands both `/kru:x` and bare `/x`; a bare one is
  // re-pointed from the skill set on disk rather than from a list that drifts
  if (md && !pathsOnly) out = out.replace(BARE_COMMAND(), (_m, p, n) => `${p}/${PREFIX}${n}`)
  return out
}
let bareCommand
function BARE_COMMAND() {
  if (!bareCommand) {
    const names = skillDirs().map((d) => d.name.slice(PREFIX.length)).sort((a, b) => b.length - a.length)
    bareCommand = new RegExp(`(^|[\\s\`('"])\\/(${names.join("|")})(?![\\w/-]|\\.\\w)`, "gm")
  }
  return bareCommand
}

function portText() {
  for (const path of walk(ROOT)) {
    let rel = relative(ROOT, path)
    if (!/\.(md|mdc|sh|mjs|txt)$/.test(rel)) continue
    if (FORK_OWNED.has(rel) || FORK_OWNED_DIRS.test(rel)) continue
    // a vendored license is kept verbatim, whatever it says
    if (/(^|\/)(LICENSE|NOTICE|COPYING)[^/]*$/.test(rel)) continue
    // under --check a skill dir not yet renamed is judged at its ported path
    rel = rel.replace(/^skills\/(?!kru-)([^/]+)\//, `skills/${PREFIX}$1/`)
    const before = readF(path)
    const after = rewrite(before, rel)
    if (after !== before) write(path, after)
  }
  for (const rule of RULES) {
    if (rule === PATHS_END || !rule.required) continue
    if (!rule.hits) problems.push(`required rule no longer matches (${rule.files}): ${String(rule.re).slice(0, 100)} — upstream reworded it; port the new text by hand`)
  }
}

// --- step 5: version ----------------------------------------------------------------------
// VERSION is `<fork>+kru<upstream>`. a merge that brings upstream's plain
// `x.y.z` back keeps the fork half from the manifest and takes the new pin.
function portVersion() {
  const vpath = join(ROOT, "VERSION")
  let v = readF(vpath).trim()
  if (/^\d+\.\d+\.\d+$/.test(v)) {
    const manifest = readF(join(ROOT, ".cursor-plugin", "plugin.json"))
    const fork = manifest ? JSON.parse(manifest).version?.split("+")[0] : null
    v = `${fork ?? "0.1.0"}+kru${v}`
  }
  if (!/^\d+\.\d+\.\d+\+kru\d+\.\d+\.\d+$/.test(v)) problems.push(`VERSION ${v} is not <fork>+kru<upstream>`)
  write(vpath, `${v}\n`)
  const rpath = join(ROOT, "ROSTER.md")
  write(rpath, readF(rpath).replace(/^# Roster — v\S+/m, `# Roster — v${v}`))
  return v
}

// --- step 6: generated pieces ------------------------------------------------------------
const GEN = (src) => `GENERATED by scripts/port.mjs${src ? ` from ${src}` : ""} — do not edit`

function portManifest(version) {
  const manifest = {
    name: PLUGIN.name,
    displayName: PLUGIN.displayName,
    version,
    description: PLUGIN.description,
    author: PLUGIN.author,
    homepage: PLUGIN.homepage,
    repository: PLUGIN.repository,
    license: PLUGIN.license,
    keywords: PLUGIN.keywords,
    logo: PLUGIN.logo,
  }
  if (!exists(join(ROOT, PLUGIN.logo))) problems.push(`manifest logo ${PLUGIN.logo} is not in the tree`)
  write(join(ROOT, ".cursor-plugin", "plugin.json"), JSON.stringify(manifest, null, 2) + "\n")
  // a single-plugin marketplace at the root, so the repo imports as a team
  // marketplace (Customize → From GitHub Repository needs one) as well as
  // submitting to the public one
  const marketplace = {
    name: PLUGIN.name,
    owner: PLUGIN.author,
    metadata: { description: PLUGIN.description, version },
    plugins: [{ name: PLUGIN.name, source: "./", description: PLUGIN.description, version, author: PLUGIN.author, homepage: PLUGIN.homepage, repository: PLUGIN.repository, license: PLUGIN.license, keywords: PLUGIN.keywords, logo: PLUGIN.logo }],
  }
  write(join(ROOT, ".cursor-plugin", "marketplace.json"), JSON.stringify(marketplace, null, 2) + "\n")
}

// the hooks, in cursor's flat format. every command goes through
// hooks/cursor-hook.sh, which turns cursor's payload into the fields the hook
// reads, changes into the project (a plugin hook's cwd is the install dir), and
// answers in cursor's schema — a permission hook always prints valid json,
// since anything else blocks the action.
function portHooks(noEdit) {
  const h = (event, script, extra = {}, args = []) => ({
    command: ["bash", '"${CURSOR_PLUGIN_ROOT}/hooks/cursor-hook.sh"', event, script, ...args].join(" "),
    ...extra,
  })
  const hooks = {
    version: 1,
    hooks: {
      // local editor and cli only: cloud agents skip sessionStart, so the same
      // once-per-conversation work also runs from the first preToolUse
      sessionStart: [h("sessionStart", "first-turn.sh", { timeout: 60 })],
      beforeSubmitPrompt: [h("beforeSubmitPrompt", "prompt-state.sh", { timeout: 10 })],
      preToolUse: [
        h("preToolUse", "first-turn.sh", { matcher: "*", timeout: 60 }),
        h("preToolUse", "require-lead.sh", { matcher: "*", timeout: 10 }),
        h("preToolUse", "check-handoff.sh", { matcher: "Task", timeout: 10 }),
        h("preToolUse", "brainstorm-guard.sh", { matcher: "Shell|Write|Delete", timeout: 10 }),
        h("preToolUse", "seat-guard.sh", { matcher: "Write|Delete", timeout: 10 }, noEdit),
      ],
      subagentStart: [h("subagentStart", "seat-guard.sh", { timeout: 10 }, noEdit)],
      postToolUse: [h("postToolUse", "log-dispatch.sh", { matcher: "Task", timeout: 10 })],
      // a hook past its loop_limit is skipped outright. log-return asks once
      // (loop_count 0) and logs the second miss (loop_count 1), so it must still
      // run at 1; nudge-audit bounds itself by the dispatch count it already
      // nudged for, and cursor leaves the span of a stop's loop_count open, so
      // a cap there could silence a later turn's audit
      subagentStop: [h("subagentStop", "log-return.sh", { timeout: 10, loop_limit: 2 })],
      stop: [h("stop", "nudge-audit.sh", { timeout: 10, loop_limit: null }), h("stop", "store-sync.sh", { timeout: 30 }, ["stop"])],
    },
  }
  write(join(ROOT, "hooks", "hooks.json"), JSON.stringify(hooks, null, 2) + "\n")
}

// two always-on rules. the lead contract itself stays a skill (it's 38 KB, and
// most turns never dispatch); the rule is the precondition and the addressing a
// session needs before it knows to load it — the line upstream's
// /kru:setup writes into a repo's CLAUDE.md, made unconditional by the plugin.
// the second carries the setup nudge, which upstream sends from sessionStart
// and a cloud agent never runs.
function portRules(version) {
  const lead = [
    "---",
    "description: kru — load the kru-lead skill before building, reviewing or dispatching a seat; how seats and commands are named",
    "alwaysApply: true",
    "---",
    `<!-- ${GEN("")} (kru-cursor v${version}) -->`,
    "",
    "This workspace has **kru** installed: an engineering team of specialist subagents run by a lead.",
    "",
    "- **Before building, reviewing or dispatching any seat, load the `kru-lead` skill** (`/kru-lead`) and follow it — it is the contract the whole team runs on. A triage or config turn that only reads needs nothing.",
    "- Seats are custom subagents: dispatch one with the Task tool as `kru-<seat>` (`kru-code-reviewer`, `kru-react-ui-builder`). Prose names them bare (`code-reviewer`).",
    "- Team skills are `kru-<name>` (`kru-testing`), and the user's commands are `/kru-<name>` (`/kru-brief`, `/kru-setup`).",
    "- The install dir is `${CURSOR_PLUGIN_ROOT}`; the store resolver is `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\"`.",
    "",
  ].join("\n")
  write(join(ROOT, "rules", "kru-lead.mdc"), lead)
  const setup = [
    "---",
    "description: kru — name /kru-setup once in a repo that has no kru sheet in AGENTS.md",
    "alwaysApply: true",
    "---",
    `<!-- ${GEN("hooks/setup-nudge.sh")} -->`,
    "",
    "A repo that has run `/kru-setup` carries a sheet in its root `AGENTS.md`, stamped `<!-- kru v… -->`. When the working repo's `AGENTS.md` has no such stamp, name `/kru-setup` to the user once this conversation (it is theirs to type), then carry on: brainstorming, briefs and grilling need no setup, and on a blank repo setup is where the stack gets settled. Skip it in the kru-cursor repo itself.",
    "",
    "On a cloud agent the session-start hook never runs, so this rule is the nudge there; locally the hook may also say it — once covers both.",
    "",
  ].join("\n")
  write(join(ROOT, "rules", "kru-setup-nudge.mdc"), setup)
  const dir = join(ROOT, "rules")
  if (exists(dir)) for (const f of readdirSync(dir)) if (!["kru-lead.mdc", "kru-setup-nudge.mdc"].includes(f)) problems.push(`rules/${f}: not generated by port.mjs (stale?)`)
}

// a skill that carries argument-hint or disable-model-invocation upstream is one
// the user invokes by name; cursor puts a plugin's commands in the / menu
function portCommands() {
  const dir = join(ROOT, "commands")
  const wanted = new Set()
  for (const { name, path } of skillDirs()) {
    const src = readF(join(path, "SKILL.md"))
    const fm = src && splitFrontmatter(src)
    if (!fm) continue
    const hint = unquote(value(get(fm, "argument-hint")))
    const manual = value(get(fm, "disable-model-invocation")) === "true"
    if (!hint && !manual) continue
    wanted.add(`${name}.md`)
    const description = (unquote(value(get(fm, "description"))) ?? "").split(/(?<=\.)\s/)[0].replace(/\s+/g, " ")
    const body = [
      "---",
      `name: ${name}`,
      `description: ${scalar(description)}`,
      "---",
      `<!-- ${GEN(`skills/${name}/SKILL.md`)} -->`,
      "",
      `Load the \`${name}\` skill (\`\${CURSOR_PLUGIN_ROOT}/skills/${name}/SKILL.md\`) and follow it for this turn.`,
      hint ? `Arguments (${hint}): whatever the user typed after the command.` : "Arguments: whatever the user typed after the command.",
      "",
    ].join("\n")
    write(join(dir, `${name}.md`), body)
  }
  if (exists(dir))
    for (const f of readdirSync(dir)) {
      if (wanted.has(f)) continue
      // a stale command is a change a real run makes, and a --check failure
      remove(join(dir, f))
    }
  return wanted.size
}

// --- step 7: audit ------------------------------------------------------------------------
function audit() {
  const watched = new Map()
  for (const path of walk(ROOT)) {
    const rel = relative(ROOT, path)
    if (!/\.(md|mdc|sh|json|mjs)$/.test(rel) || FORK_OWNED.has(rel)) continue
    const src = readF(path) ?? ""
    if (!FORBIDDEN_OK.test(rel))
      for (const re of FORBIDDEN) {
        const hit = src.match(re)
        if (hit) problems.push(`${rel}: unported \`${hit[0]}\``)
      }
    for (const m of src.matchAll(/(?:^|[\s`('"])\/kru-([a-z0-9-]+)\b/g))
      if (!exists(join(ROOT, "skills", `${PREFIX}${m[1]}`)) && !exists(join(ROOT, "skills", m[1]))) problems.push(`${rel}: /kru-${m[1]} names no skill`)
    for (const re of WATCH) {
      const hits = src.match(new RegExp(re.source, "gm"))
      if (hits) watched.set(rel, (watched.get(rel) ?? 0) + hits.length)
    }
  }
  if (watched.size) {
    log(`\nsurfaces cursor lacks (PORTING.md → Known gaps): ${[...watched.values()].reduce((a, b) => a + b, 0)} references in ${watched.size} file(s)`)
    for (const [rel, n] of [...watched].sort((a, b) => b[1] - a[1]).slice(0, 8)) log(`  ? ${rel} (${n})`)
  }
}

// --list-fork-owned: the files a fresh port of upstream needs laid over it to
// reproduce this tree (scripts/verify.sh → the fresh-port check). generated
// files are left out on purpose — the port has to regenerate them.
if (process.argv.includes("--list-fork-owned")) {
  const out = [...FORK_OWNED].filter((f) => existsSync(join(ROOT, f)))
  for (const p of walk(ROOT)) {
    const rel = relative(ROOT, p)
    if (/^(scripts\/cursor\/|\.github\/)/.test(rel)) out.push(rel)
  }
  // the manifest's fork half of the version is the one fact a fresh port reads back
  out.push(".cursor-plugin/plugin.json")
  console.log([...new Set(out)].sort().join("\n"))
  process.exit(0)
}

relayout()
const noEdit = portAgents()
portSkills()
portText()
const version = portVersion()
portManifest(version)
portHooks(noEdit)
portRules(version)
const commands = portCommands()
if (!CHECK || changed.length === 0) audit()

log(`port: ${seatNames().length} seats (${noEdit.length} no-edit) · ${skillDirs().length} skills · ${commands} commands · v${version}`)
log(`ported: ${changed.length} file(s) ${CHECK ? "would change" : "changed"}`)
if (changed.length && !QUIET) for (const c of changed.slice(0, 40)) log(`  ~ ${c}`)
if (changed.length > 40 && !QUIET) log(`  … ${changed.length - 40} more`)
if (problems.length) {
  console.error(`\n${problems.length} problem(s):`)
  for (const p of problems) console.error(`  ! ${p}`)
  process.exit(1)
}
if (CHECK && changed.length) {
  console.error(`\n--check: tree is not normalized; run: node scripts/port.mjs`)
  process.exit(1)
}
