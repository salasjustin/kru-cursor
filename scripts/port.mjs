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
// rewrites. what it never decides: prose judgment. a rewrite that needs judgment
// is a fork edit (scripts/cursor/edits.mjs — an exact passage and what it
// becomes, applied last), a hand-owned block (scripts/cursor/*.md) or a known
// gap in PORTING.md.

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, rmSync, renameSync, statSync } from "node:fs"
import { join, dirname, basename, relative } from "node:path"
import { fileURLToPath } from "node:url"
import { EDITS } from "./cursor/edits.mjs"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const CHECK = process.argv.includes("--check")
const QUIET = process.argv.includes("--quiet")

const PLUGIN = {
  name: "kru-cursor",
  displayName: "kru for Cursor",
  description:
    "kru, ported to Cursor: an engineering lead plus 37 specialist subagents, the skills they load, and the hooks that keep handoffs honest. A port of github.com/ap-justin/kru.",
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
// models. every id a seat may run on, each read verbatim off a cursor docs page
// (MODELS.md → Sources); an id that isn't here is refused, and scripts/verify.sh
// checks every agent against this list. effort and the other options ride as
// cursor's model parameters (`id[effort=high]`, `id[fast=false]`).
// ---------------------------------------------------------------------------
const CONFIRMED_MODELS = {
  "claude-opus-5-5": "https://cursor.com/docs/models/claude-opus-5-5",
  "claude-sonnet-5-5": "https://cursor.com/docs/models/claude-sonnet-5-5",
  "claude-haiku-5-5": "https://cursor.com/docs/models/claude-haiku-5-5",
  "claude-fable-5-1": "https://cursor.com/docs/models/claude-fable-5-1",
  "grok-4.7": "https://cursor.com/docs/models/grok-4-7",
  "composer-2.5": "https://cursor.com/docs/models/cursor-composer-2-5",
  "kimi-k3": "https://cursor.com/docs/models/kimi-k3",
  "gpt-5.6-sol": "https://cursor.com/docs/models/gpt-5-6-sol",
  "gemini-3.1-pro": "https://cursor.com/docs/models/gemini-3-1-pro",
  inherit: "https://cursor.com/docs/subagents",
}
const CURSOR_MODELS = new Set(Object.keys(CONFIRMED_MODELS))
const MODEL_ALIAS = { opus: "claude-opus-5-5", sonnet: "claude-sonnet-5-5", haiku: "claude-haiku-5-5" }
const baseModel = (m) => m.replace(/\[.*\]$/, "")
// where this fork re-tiers a seat away from upstream's pin: [pick, fallback].
// the why for each row is MODELS.md's. a seat not named here keeps upstream's
// pin, with the fallback its tier gets below
const SEAT_MODELS = {
  // the component seats: Kimi K3, Opus where it isn't served
  "react-ui-builder": ["kimi-k3", "claude-opus-5-5"],
  "web-components-builder": ["kimi-k3", "claude-opus-5-5"],
  // bounded build and repair work: Grok 4.7, in Cursor's own pool
  "test-writer": ["grok-4.7", "claude-sonnet-5-5"],
  "toolchain-engineer": ["grok-4.7[effort=medium]", "claude-sonnet-5-5[effort=medium]"],
  "vercel-perf-optimizer": ["grok-4.7[effort=medium]", "claude-sonnet-5-5[effort=medium]"],
}
const TIER_FALLBACK = {
  "claude-opus-5-5": "gpt-5.6-sol", // the same price band and tier, another provider
  "claude-sonnet-5-5": "grok-4.7",
  "claude-haiku-5-5": "composer-2.5[fast=false]",
}
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
  "scripts/smoke.sh", // a live `claude -p` run; dropped like upstream v0.153.0
  "scripts/cursor-smoke.sh", // fork's live token-spending check; verify.sh is the only gate (upstream v0.153.0 dropped smoke.sh)
  "hooks/check-task-tools.sh", // cursor's todo list is always on
  "hooks/check-task-tools.test.sh",
  "skills/setup/cloud-install.sh", // a claude cloud sessionstart template; cursor installs from .cursor/environment.json
  "skills/claude-code-delegation", // cursor cloud agents; never claude code delegation
  "skills/kru-claude-code-delegation", // same skill after layout prefix (merge can land either path)
  "scripts/sync-bot-skills.sh", // upstream library sync; this fork syncs elsewhere (PORTING.md)
  "scripts/sync-bot-skills.test.sh",
  "scripts/bot-skills.txt",
  "skills/roster/request.md", // fork-owned at skills/kru-roster/request.md (Cursor cloud path)
]
const droppedSkillName = (name) =>
  DROP.some((p) => {
    if (!p.startsWith("skills/")) return false
    const tail = p.slice("skills/".length)
    if (tail.includes("/")) return false
    const bare = tail.startsWith(PREFIX) ? tail.slice(PREFIX.length) : tail
    return name === tail || name === PREFIX + bare || name === bare
  })

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
  "scripts/asset/xai.mjs",
  "scripts/asset/xai.test.mjs",
  "scripts/privacy-scan.mjs",
  "scripts/privacy-scan.test.sh",
  "scripts/leak-patterns.mjs",
  "scripts/guard-text.mjs",
  "scripts/cursor-hooks.test.sh",
  "scripts/sync-upstream.sh",
  "scripts/sync-upstream.test.sh",
  "scripts/workflows.test.sh",
  "scripts/port-edits.test.sh",
  "scripts/kru-tracker.sh",
  "scripts/kru-tracker.test.sh",
  "scripts/brief-drift.mjs",
  "scripts/brief-drift.test.sh",
  "scripts/cloud-skills.sh",
  "scripts/cloud-skills.test.sh",
  "skills/kru-roster/release.md",
  "skills/kru-roster/fork-sync.md",
  "skills/kru-roster/request.md",
  "hooks/cursor-hook.sh",
  "hooks/require-lead.sh",
  "hooks/require-lead.test.sh",
  "hooks/readonly-bash.test.sh",
  "hooks/brainstorm-guard.sh",
  "hooks/brainstorm-guard.test.sh",
  "hooks/prompt-state.sh",
  "hooks/seat-guard.sh",
  "hooks/first-turn.sh",
  "hooks/cursor-state.sh",
  "hooks/mcp-outbound-guard.sh",
  "hooks/mcp-outbound-guard.test.sh",
  "scripts/cursor/mcp-outbound-allowlist.mjs",
  "scripts/cursor/mcp-outbound-classify.mjs",
  "scripts/cursor/hooks.repo.mcp-guard.json",
  ".cursor/hooks.json",
  "skills/kru-design/SKILL.md",
])
const FORK_OWNED_DIRS = /^(scripts\/cursor\/|\.cursor-plugin\/|rules\/|commands\/|\.github\/)/

// files that talk about claude on purpose and get only the layout and name
// rules: the official-source map's vendoring rows, the claude release ledger the
// update skill keeps, eval-review (grades an upstream suite already in the tree;
// layout rules, plus fork edits that drop the default evals/ directory).
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
  // ↑ the layout and the names: everything above also runs on PATHS_ONLY files.
  // claude.md is PATHS_ONLY, so the Cursor sweep has to land before this mark.
  // The heading in the replacement must not be the heading this matches.
  R(/^# claude — what shipped to Claude Code[\s\S]*$/, () => block("update-sweep.md"), { files: /^skills\/kru-update\/claude\.md$/, required: /https:\/\/cursor\.com\/changelog/ }),
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
  // verbs that read by default and write on a flag or an operand. every raw
  // newline splits, even inside a quote, a comment or a heredoc (fail closed);
  // | ; & split only outside quotes (kru_segments). every flag check reads the
  // segment's words with quotes resolved
  // (kru_words, from scripts/cursor/readonly-words.sh), so a quoted flag is the
  // flag. awk's system(), getline, @include, @load and an indirect @name() run
  // code — on the raw line when awk is on it, so grep or rg for the words still
  // reads, and again on the quote-resolved words, because sys''tem and
  // $'\x73ystem' are system. a | other than || or a > in that program pipes or
  // writes. awk -f/--file or any flag but -F/-v loads a program the line can't
  // show. sed is an allowlist (kru_sed_reads): its w/W/e need no separator, so
  // only read flags, addresses, p d D q = G g h H N P x l y and s///[gpIiMm0-9]* read,
  // and -f/--file/-i are writes. sort -o (GNU takes any unambiguous prefix:
  // --o, --out) writes a file and --compress-program runs one, --output writes
  // (--output-separator doesn't), rg --pre runs a program per file, yq
  // -i/--inplace and --split-exp write, date -s/--set or a clock operand sets
  // the clock (-I takes a format), `command` runs whatever follows it bar
  // -v/-V, uniq's second operand and file -C write, macOS base64 -o writes,
  // xxd's second operand writes so it leaves the list, and <( runs a command.
  // find's -exec/-execdir/-ok/-okdir/-delete/-fprint/-fprint0/-fprintf/-fls run
  // or write, and quoting hides them (-ex''ec), so find is checked on the
  // quote-resolved words. git --output writes its file the same way
  // (--out''put=); --output-separator does not. $$' is a pid plus a single
  // quote, not $'…', and any other unquoted $ fails closed (kru_segments_line).
  // a function definition (`name ()` or `name ( )`) is a write on the whole
  // command and on each segment, so `ls () ( touch x ); ls` cannot hide a
  // write behind a read-looking name
  // (tests: hooks/readonly-bash.test.sh)
  R(/(refusal costs one message\.\n)\n(?=# kru_readonly_bash <command>)/, (_m, a) => `${a}\n${block("readonly-words.sh")}\n`,
    { sh: true, files: /^hooks\/readonly-bash\.sh$/, required: /^kru_sed_reads\(\) \{$/m }),
  R(/\|\*'-exec'\*\|(.*)\|\*'xargs'\*\) return 1 ;;/g, "|*'-exec'*|*'-ok'*|$1|*'xargs'*|*'<('*) return 1 ;;", { sh: true, files: /^hooks\/readonly-bash\.sh$/, required: /\*'-ok'\*\|.*\|\*'xargs'\*\|\*'<\('\*\) return 1 ;;/ }),
  R(/^(kru_readonly_bash\(\) \{\n)( +)case "\$1" in\n/m, (_m, f, a) => f + [
    "# awk's system() and getline run commands, system with any space before its",
    "# paren, and so does gawk's indirect @name(). quoting can hide them, so the",
    "# awk branch below checks the quote-resolved words too. the raw line still",
    "# answers whenever awk is on it, so grep or rg for the words still reads",
    String.raw`case $1 in *awk*) [[ $1 =~ system[[:space:]]*\(|getline|@include|@load|@[[:space:]]*[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\( ]] && return 1 ;; esac`,
    "# any --output writes its file (git diff --output=x); --output-separator and",
    "# the other --output-* names don't",
    String.raw`[[ $1 =~ --output([=[:space:]\'\"]|$) ]] && return 1`,
    "# a function definition hides a write behind a read-looking name",
    "# (ls () ( touch x ); ls) — on the whole command, before segments",
    'kru_fn_def "$1" && return 1',
    'case "$1" in',
  ].map((l) => a + l + "\n").join(""),
    { sh: true, files: /^hooks\/readonly-bash\.sh$/, required: /case \$1 in \*awk\*\) \[\[ \$1 =~ system\[\[:space:\]\]\*\\\(\|getline\|@include\|@load\|@\[\[:space:\]\]/ }),
  R(/( +)ls\|cat\|head\|tail\|wc\|grep\|egrep\|fgrep\|rg\|find\|file\|(.*)\n( +)which\|command\|type\|echo\|printf\|jq\|yq\|sort\|uniq\|cut\|tr\|column\|date\|test\|true\|diff\) continue ;;\n( +)# safe only because the write-tell case above already took sed -i and any redirect\n( +)sed\|awk\|nl\|tac\|comm\|xxd\|base64\) continue ;;\n/g,
    (_m, a, rest) => [
      `ls|cat|head|tail|wc|grep|egrep|fgrep|${rest}`,
      "which|type|echo|printf|jq|cut|tr|column|test|true|diff) continue ;;",
      "# the verbs that read until a flag or an operand says otherwise.",
      "# find's -exec/-ok/-delete/-fprint/-fls and git's --output are read off",
      "# the quote-resolved words; a git segment with neither falls through to",
      "# the read-only subcommand list below",
      String.raw`find) kru_words "$seg" && ! kru_any '^-(exec|ok|delete|fls|fprint)' && continue; return 1 ;;`,
      String.raw`git) kru_words "$seg" || return 1; kru_any '^--output(=|$)' && return 1 ;;`,
      String.raw`sort) kru_words "$seg" && ! kru_any '^(-[^-]*o|--o|--co)' && continue; return 1 ;;`,
      String.raw`rg) kru_words "$seg" && ! kru_any '^--pre(=|$)' && continue; return 1 ;;`,
      String.raw`sed) kru_words "$seg" && kru_sed_reads "${"$"}{KRU_W[@]:1}" && continue; return 1 ;;`,
      String.raw`awk) kru_words "$seg" && ! [[ ${"$"}{KRU_W[*]} =~ $kru_awk_runs ]] && kru_awk_reads "${"$"}{KRU_W[@]:1}" && continue; return 1 ;;`,
      String.raw`yq) kru_words "$seg" && ! kru_any '^(-[a-zA-Z]*[is]|--inplace|--split-exp)' && continue; return 1 ;;`,
      String.raw`date) kru_words "$seg" && ! kru_any '^(-[^-dfrI]*s|--s|[0-9.]{4,}$)' && continue; return 1 ;;`,
      String.raw`command) kru_words "$seg" && [[ ${"$"}{KRU_W[1]:-} == -[vV] ]] && continue; return 1 ;;`,
      String.raw`uniq) kru_words "$seg" && kru_operands 1 '^-[fsw]$' "${"$"}{KRU_W[@]:1}" && continue; return 1 ;;`,
      String.raw`file) kru_words "$seg" && ! kru_any '^(-[^-]*C|--co)' && continue; return 1 ;;`,
      String.raw`base64) kru_words "$seg" && ! kru_any '^(-[^-]*o|--o)' && continue; return 1 ;;`,
      "# safe only because the write-tell case above already took any redirect",
      "nl|tac|comm) continue ;;",
    ].map((l) => a + l + "\n").join(""),
    { sh: true, files: /^hooks\/readonly-bash\.sh$/, required: /find\) kru_words "\$seg" && ! kru_any '\^-\(exec\|ok\|delete\|fls\|fprint\)'[\s\S]*git\) kru_words "\$seg" \|\| return 1; kru_any '\^--output\(=\|\$\)'/ }),
  // | ; & inside sed '/x/{p;q}' or awk '{print $1; print $2}' stay in the
  // program; a raw newline always splits (kru_segments, inserted above).
  // `kru_fn_def "$seg"` is inserted at `[ -z "$seg" ] && continue`. if that
  // anchor drifts, this regex still matches and `kru_segments` is still
  // emitted, so the skipped insert would count as applied. a missed insert
  // is recorded here. `required` demands the per-segment `kru_fn_def "$seg"`
  // so --check fails closed once the upstream loop is gone. a normal port
  // runs this rewrite before it renames or writes (guardSegmentAnchor) and
  // exits on the miss, so the hook without the check is never written.
  R(/^( +)while IFS= read -r seg; do\n +seg=\$\(printf '%s' "\$seg" \| sed 's\/\^\[\[:space:\]\]\*\/\/; s\/\[\[:space:\]\]\*\$\/\/'\)\n([\s\S]*?)\n( +)done < <\(printf '%s\\n' "\$1" \| tr '\|;&' '\\n'\)\n/m,
    (_m, a, mid, a2) => {
      const marked = mid.replace(
        /^([ \t]*)\[ -z "\$seg" \] && continue\n/,
        '$1[ -z "$seg" ] && continue\n$1kru_fn_def "$seg" && return 1\n',
      )
      if (marked === mid) problems.push('hooks/readonly-bash.sh: per-segment kru_fn_def "$seg" was not inserted; [ -z "$seg" ] && continue drifted')
      return [
        `${a}kru_segments "$1" || return 1`,
        `${a}for seg in "\${KRU_S[@]}"; do`,
        `${a}  seg=\${seg#"\${seg%%[![:space:]]*}"}; seg=\${seg%"\${seg##*[![:space:]]}"}`,
        marked,
        `${a2}done`,
      ].join("\n") + "\n"
    },
    { sh: true, files: /^hooks\/readonly-bash\.sh$/, required: /^ +kru_segments "\$1" \|\| return 1\n[\s\S]*?^ +kru_fn_def "\$seg" && return 1$/m }),
  // a hung remote must not hold the hook: the first preToolUse has 15s and the
  // stop hook 30s, and the stop path's push, pull, push would take three
  // separate timeouts past that. every call shares one budget, and a watchdog
  // ends the call's whole process group — coreutils timeout signals only its
  // child, leaving an ssh in connect holding the output open, and macOS ships
  // none (tests: scripts/cursor-hooks.test.sh, store-sync on a hung remote)
  R(/^g\(\) \{ git -C "\$home" "\$@"; \}\n(?!# a remote that hangs)/m, () => [
    'g() { git -C "$home" "$@"; }',
    "# a remote that hangs must not hold the hook: every network call this run",
    "# makes shares one budget (KRU_STORE_SYNC_TIMEOUT; 10s at start, 20s at stop),",
    "# and the watchdog kills the call's process group, so the ssh or remote helper",
    "# git spawned ends with it. git's low-speed abort ends a stalled transfer sooner",
    "# a value that isn't a positive count of seconds gets the default; 0 falls back, 08 is eight",
    "budget=${KRU_STORE_SYNC_TIMEOUT:-}",
    '[[ $budget =~ ^[0-9]+$ ]] && [ "$((10#$budget))" -gt 0 ] && budget=$((10#$budget)) || budget=$([ "$mode" = stop ] && echo 20 || echo 10)',
    "deadline=$((SECONDS + budget))",
    "net() {",
    "  local left=$((deadline - SECONDS)) pid dog rc",
    '  [ "$left" -gt 0 ] || { echo "no answer from the remote in time" >&2; return 124; }',
    "  set -m",
    '  git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime="$left" "$@" &',
    "  pid=$!",
    "  set +m",
    '  ( trap \'kill "$s"; exit\' TERM; sleep "$left" & s=$!; wait "$s"; kill -TERM -- "-$pid" ) >/dev/null 2>&1 &',
    "  dog=$!",
    '  wait "$pid"; rc=$?',
    '  kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null',
    '  [ "$rc" -gt 128 ] && echo "no answer from the remote in ${left}s" >&2',
    '  return "$rc"',
    "}",
    "",
  ].join("\n"), { sh: true, files: /^hooks\/store-sync\.sh$/, required: /\[\[ \$budget =~ \^\[0-9\]\+\$ \]\] && \[ "\$\(\(10#\$budget\)\)" -gt 0 \]/ }),
  // a budget that ran out says so, keeping what still holds, instead of the
  // sign-in hint its failure line carries (tests: scripts/cursor-hooks.test.sh)
  R(/^(  local msg="kru store: \$1" raw=\$\{2:-\}\n)(?!  # a budget)/m, (_m, a) => a + [
    "  # a budget that ran out says so, not the sign-in hint the failure line carries.",
    "  # the clock decides, not git's words: ssh or a helper may print before the kill",
    '  [ -n "$raw" ] && [ "$SECONDS" -ge "$deadline" ] && msg="kru store: ${1%%; sync failed*}; sync timed out after ${budget}s. A large store needs a higher KRU_STORE_SYNC_TIMEOUT"',
    "",
  ].join("\n"), { sh: true, files: /^hooks\/store-sync\.sh$/, required: /^  # a budget that ran out says so/m }),
  R(/\$\(git clone -q "\$url"/g, '$(net clone -q "$url"', { sh: true, files: /^hooks\/store-sync\.sh$/, required: /\$\(net clone -q "\$url"/ }),
  R(/\bg (pull|push) -q\b/g, 'net -C "$home" $1 -q', { sh: true, files: /^hooks\/store-sync\.sh$/, required: /net -C "\$home" pull -q --rebase --autostash/ }),
  // a cloud vm: cursor's managed vms expose the agent metadata socket
  R(/kru_is_cloud\(\) \{ \[ "\$\{CLAUDE_CODE_REMOTE:-\}" = "true" \]; \}/g,
    'kru_is_cloud() { [ "${KRU_CLOUD:-}" = "0" ] && return 1; [ "${KRU_CLOUD:-}" = "1" ] || [ -n "${CURSOR_AGENT_SOCKET:-}" ] || [ -S /run/cursor/api.sock ]; }', { sh: true, files: /^scripts\/kru-store\.sh$/, required: /CURSOR_AGENT_SOCKET/ }),
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
  // a seat's model is one of the ids port.mjs confirmed off cursor's docs (MODELS.md)
  R(/\[\[ \$m =~ \^claude-\(opus\|sonnet\|haiku\)-\[0-9\]\+-\[0-9\]\+\$ \]\] \|\| bad "\$f model '\$m' is not a full pinned ID"/g,
    () => `grep -qxF "\${m%%\\[*}" <(node scripts/port.mjs --list-models) || bad "$f model '$m' is not a confirmed Cursor model id (scripts/port.mjs → CONFIRMED_MODELS)"`, { sh: true, files: /^scripts\/audit\.sh$/, required: /<\(node scripts\/port\.mjs --list-models\)/ }),
  R(/grep -l '\^memory: local' agents\/\*\.md/g, `grep -l '${MEMORY_DIR}/' agents/*.md`, { sh: true, files: /^scripts\/audit\.sh$/, required: /agent-memory-local\/. agents/ }),
  R(/"Block Q heading and memory: local seat lists differ"/g, '"Block Q heading and memory line seat lists differ"', { sh: true, files: /^scripts\/audit\.sh$/ }),
  R(/for h in \$\(grep -oE 'hooks\/\[a-z0-9-\]\+\\\.sh' hooks\/hooks\.json \| sort -u\); do/g,
    "for h in $(grep -oE 'hooks/[a-z0-9-]+\\.sh' hooks/hooks.json | sort -u) $(jq -r '.hooks[][].command' hooks/hooks.json | grep -oE ' [a-z0-9-]+\\.sh( |$)' | tr -d ' ' | sed 's#^#hooks/#' | sort -u); do", { sh: true, files: /^scripts\/audit\.sh$/, required: /jq -r .\.hooks\[\]\[\]\.command/ }),

  // the asset generator's xai backend (scripts/asset/xai.mjs, hand-owned):
  // Grok Imagine stills and edits when XAI_API_KEY is set, the google path
  // otherwise. run.sh copies the module beside the generator it imports from
  R(/^(cmp -s "\$src\/gen-asset\.ts" "\$data\/gen-asset\.ts" \|\| cp "\$src\/gen-asset\.ts" "\$data\/"\n)(?!cmp -s "\$src\/xai\.mjs")/m, '$1cmp -s "$src/xai.mjs" "$data/xai.mjs" || cp "$src/xai.mjs" "$data/"\n', { sh: true, files: /^scripts\/asset\/run\.sh$/, required: /cp "\$src\/xai\.mjs" "\$data\/"/ }),
  R(/^(import \{ fileURLToPath \} from "node:url";\n)(?!import \* as xai)/m, '$1import * as xai from "./xai.mjs";\n', { files: /^scripts\/asset\/gen-asset\.ts$/, required: /^import \* as xai from "\.\/xai\.mjs";$/m }),
  R(/^(\/\/ env: GOOGLE_API_KEY \(or GEMINI_API_KEY\) — a Google AI Studio key\.)(?! Or\n)/m,
    "$1 Or\n// XAI_API_KEY, an xAI key: with it set, stills and edits (no --model, or a\n// grok-imagine-* one) go through Grok Imagine (./xai.mjs); --backend google opts\n// out, --xai-quality low|medium picks its quality. Keys are", { files: /^scripts\/asset\/gen-asset\.ts$/, required: /^\/\/ XAI_API_KEY, an xAI key: with it set/m }),
  R(/^const apiKey = process\.env\.GOOGLE_API_KEY \?\? process\.env\.GEMINI_API_KEY;\nif \(!apiKey && !isCutout\) \{/m, () => [
    "// xai backend: stills and edits when XAI_API_KEY is set; video, cutouts and an",
    "// explicit google model take the path below, as does every run without the key",
    "const choice = xai.pickBackend({ env: process.env, backend: args.backend, model: args.model, isVideo, isCutout });",
    "if (choice.note) console.error(choice.note);",
    'const useXai = choice.backend === "xai";',
    "",
    "const apiKey = process.env.GOOGLE_API_KEY ?? process.env.GEMINI_API_KEY;",
    "if (!apiKey && !isCutout && !useXai) {",
  ].join("\n"), { files: /^scripts\/asset\/gen-asset\.ts$/, required: /^if \(!apiKey && !isCutout && !useXai\) \{$/m }),
  R(/(?<!return out\.bytes;\n\}\n\n)^\/\/ --- optimize \+ write -+\n/m, () => [
    "// the xai path returns the same raw bytes generate() does, so the sharp pass",
    "// below treats both alike",
    "async function generateXai(): Promise<Buffer> {",
    "  const out = await xai.generate({",
    "    apiKey: process.env.XAI_API_KEY,",
    "    prompt,",
    '    model: args.model?.startsWith("grok-imagine") ? args.model : undefined,',
    "    aspect: imgAspect,",
    "    resolution: imageSize,",
    '    quality: args["xai-quality"],',
    "    // the edits endpoint takes jpeg, png or webp; the source may be avif, so send png",
    '    inputB64: inputPath ? (await sharp(inputPath).png().toBuffer()).toString("base64") : undefined,',
    '    inputMime: "image/png",',
    "    log: (l: string) => console.error(l),",
    "  });",
    "  console.error(`xai served ${out.model}`);",
    "  return out.bytes;",
    "}",
    "",
    "// --- optimize + write -----------------------------------------------------",
    "",
  ].join("\n"), { files: /^scripts\/asset\/gen-asset\.ts$/, required: /^async function generateXai\(\): Promise<Buffer> \{$/m }),
  // the google client warns on construction without its key; an xai run never calls it
  R(/^const ai = new GoogleGenAI\(\{ apiKey \}\);$/m, "const ai = useXai ? (undefined as unknown as GoogleGenAI) : new GoogleGenAI({ apiKey });", { files: /^scripts\/asset\/gen-asset\.ts$/, required: /^const ai = useXai \? /m }),
  R(/`generating with \$\{model\}\$\{inputPath/g, '`generating with ${useXai ? `xAI ${args.model ?? xai.XAI_IMAGE_MODELS[0]}` : model}${inputPath', { files: /^scripts\/asset\/gen-asset\.ts$/, required: /generating with \$\{useXai \?/ }),
  R(/written = await optimizeAndWrite\(await generate\(\)\);/g, "written = await optimizeAndWrite(useXai ? await generateXai() : await generate());", { files: /^scripts\/asset\/gen-asset\.ts$/, required: /useXai \? await generateXai\(\) : await generate\(\)/ }),

  // --- prose (markdown) ---------------------------------------------------------
  // the instruction files: cursor reads AGENTS.md and .cursor/rules/*.mdc.
  // ~/.claude/CLAUDE.md is shielded from the CLAUDE.md → AGENTS.md rewrite, then
  // restored, so a fork edit can point skill prose at .cursor/rules and AGENTS.md.
  // the handoff gate reads root AGENTS.md and alwaysApply rules, and the home
  // file only as a fallback (check-handoff.sh).
  R(/(~|\$HOME)\/\.claude\/CLAUDE\.md/g, "{USER_RULES}$1", { md: true }),
  R(/(^|[\s`('"(\/])\.claude\/CLAUDE\.md/gm, "$1AGENTS.md", { md: true }),
  R(/\bCLAUDE\.md\b/g, "AGENTS.md", { md: true }),
  R(/\{USER_RULES\}(~|\$HOME)/g, "$1/.claude/CLAUDE.md", { md: true }),
  R(/(`?)AGENTS\.md\1(?:\s*(?:\/|,|\bor\b)\s*\1AGENTS\.md\1)+/g, "$1AGENTS.md$1", { md: true }),
  R(/\ba (`?)AGENTS\.md/g, "an $1AGENTS.md", { md: true }),
  R(/`\.claude\/rules\/`/g, "`.cursor/rules/`", { md: true }),
  // `.claude/rules/*` is not the backtick-closed form above; setup's read-the-repo
  // line is this shape. *.mdc is what Cursor loads (cursor.com/docs/rules).
  // the fork edit then writes **/*.mdc; required accepts both so a second port
  // still sees the rule's output.
  R(/\.claude\/rules\/\*/g, ".cursor/rules/*.mdc", { md: true, files: /^skills\/kru-setup\/SKILL\.md$/, required: /\.cursor\/rules\/(?:\*\*\/)?\*\.mdc/ }),
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
  R(/ and the claude\.ai connector to `MCP claude_ai_Context7__\*` —\n  either leaves those seats holding entries that resolve to nothing\./g, " —\n  that leaves those seats holding entries that resolve to nothing. The claude.ai connector (`MCP claude_ai_Context7__*`) is Claude-only and is not a Cursor failure mode.", { md: true, files: /^skills\/kru-setup\/SKILL\.md$/, required: /is Claude-only and is not a Cursor failure mode/ }),
  R(/ the same way, and the `svelte@svelte` plugin namespaces its server to\n  `\*` \(`plugin_svelte_svelte` MCP\) — a Svelte repo registers a bare `svelte` entry in its `\.mcp\.json`\n  \(http `https:\/\/mcp\.svelte\.dev\/mcp`\)\./g,
    " the same way — a Svelte repo registers a bare `svelte` entry in `.cursor/mcp.json` (http `https://mcp.svelte.dev/mcp`) for local Cursor use. Cloud agents only get it once it is added as a team MCP server in the Cursor dashboard (they ignore the repo's `.cursor/mcp.json`).",
    { md: true, files: /^skills\/kru-setup\/SKILL\.md$/, required: /Cloud agents only get it once it is added as a team MCP server/ }),
  R(/\(`TESTING\.md` → \*Verify before shipping\*\)/g, "(`PORTING.md` — the verify gate at the top)", { md: true, required: /`PORTING\.md` — the verify gate at the top/ }),
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
  // upstream's tiers stand as written; MODELS.md's map overrides them here
  R(/^## Model tiers\n(?:In kru-cursor[^\n]*\n\n)?/m, () => "## Model tiers\nIn kru-cursor `MODELS.md` is the map, and it overrides this section where they differ: " +
    `${Object.keys(SEAT_MODELS).length} seats run on models other than upstream's pin (${Object.keys(SEAT_MODELS).map((n) => "`" + n + "`").join(", ")}), every pick has a fallback, ` +
    "`effort` becomes the model id's `[effort=…]` parameter, `experimental.cacheTtl` has no Cursor equivalent, and `scripts/port.mjs` writes every seat's `model:` line.\n\n",
    { md: true, files: /^ROSTER\.md$/, required: /^In kru-cursor `MODELS\.md` is the map/m }),
  // the store's cloud surface
  R(/cloud session \(`CLAUDE_CODE_REMOTE=true`\)/g, "cloud agent (`CURSOR_AGENT_SOCKET` set, or `KRU_CLOUD=1`)", { md: true }),
  // the asset key: an xai key is the alternative for stills and edits
  R(/Generation needs `GOOGLE_API_KEY` \(Google AI Studio\) in the environment\./g, "Generation needs `GOOGLE_API_KEY` (Google AI Studio) or `XAI_API_KEY` (xAI) in the environment: with `XAI_API_KEY` set, stills and edits go through xAI's Grok Imagine (`grok-imagine-image-2.0`, falling back to `grok-imagine-image`) unless you pass a Google `--model` or `--backend google`; video and cutouts stay on the Google path.", { md: true }),
  R(/generation needs `GOOGLE_API_KEY` and Node\.js on PATH/g, "generation needs `GOOGLE_API_KEY` (or `XAI_API_KEY` for stills and edits) and Node.js on PATH", { md: true }),
  R(/needs `GOOGLE_API_KEY`\. Verify model ids\/params via Context7, never memory\. \|/g, "needs `GOOGLE_API_KEY`, or `XAI_API_KEY` for the xAI backend (`scripts/asset/xai.mjs`, Grok Imagine stills and edits; source: docs.x.ai → Inference API → Images). Verify model ids/params via Context7, never memory. |", { md: true, files: /^SOURCES\.md$/, required: /or `XAI_API_KEY` for the xAI backend/ }),
  // the fork's release and sync runbooks are hand-owned files beside the roster skill
  R(/(?<!follow `release\.md`\.\n\n)^## Wiring map — the single source of truth$/m, "**This fork's release and upstream sync** are `release.md` (version, tag, Cursor's marketplace) and `fork-sync.md` (the weekly upstream pull request), beside this file. The version and git rows below follow `release.md`.\n\n## Wiring map — the single source of truth", { md: true, files: /^skills\/kru-roster\/SKILL\.md$/, required: /^\*\*This fork's release and upstream sync\*\*/m }),
  // the harness itself. "Claude Code channel(s)" is a product extension-builder
  // builds, not the harness, so it stays. the system-prompt and todo-tool
  // phrases stay too, so the calibration fork edit replaces those sentences whole.
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
  // design is outside engineering (v0.156). cursor surfaces for the external designer.
  R(/Engineering never runs a mockup or canvas step\.(?!\n+\*\*External designer on Cursor)/g, () => "Engineering never runs a mockup or canvas step." + block("ui-design-cursor.md"), { md: true, files: /^references\/ui-practice\.md$/, required: /External designer on Cursor/ }),
  R(/Invoke the bundled \*\*`\/design` skill\*\* for artboards and publish:/g, "Invoke **`/kru-design`** and publish with Cursor's `/canvas` ([canvas](https://cursor.com/docs/agent/tools/canvas)) for artboards:", { md: true, files: /^references\/designer-handoff\.md$/, required: /publish with Cursor's `\/canvas`/ }),
  R(/^(# The sync lane — designing out of the repo's real components\n)(?!\n\*\*Cursor has no)/m, "$1\n**Cursor has no claude.ai/design project — engineering does not run this lane.** External designers on Cursor use `/kru-design` with `/canvas` ([canvas](https://cursor.com/docs/agent/tools/canvas)). The procedure below stays so a repo that already has a `.design-sync/` can still be read.\n", { md: true, files: /^references\/design-sync\.md$/, required: /engineering does not run this lane/ }),
  R(/\*\*A `\.design-sync\/` bundle, if present, is for the designer\*\* — keep components accurate so a designer-run `\/design-sync` sees real parts \(`\$\{CURSOR_PLUGIN_ROOT\}\/references\/design-sync\.md`\)\. When your slice touches published components, expect all of:/g, "**A `.design-sync/` bundle, if present, is for the designer** — keep components accurate so a designer-run `/design-sync` sees real parts (`${CURSOR_PLUGIN_ROOT}/references/design-sync.md`). Cursor has no claude.ai/design host; engineering does not run the sync lane. When your slice touches published components in such a tree, expect all of:", { md: true, files: /^agents\/react-ui-builder\.md$/, required: /engineering does not run the sync lane/ }),
  R(/- \*\*The values and the look\*\* — the designer's approved spec \(`\/design` \+ handoff to PM\), transcribed once by a builder\./g, "- **The values and the look** — the designer's approved spec (mockups + build spec handed to the PM), transcribed once by a builder.", { md: true, files: /^skills\/kru-design-system\/SKILL\.md$/, required: /mockups \+ build spec handed to the PM/ }),
  R(/\*\*bundled `\/design` skill\*\* \(Cursor CLI\) \| \*\*Never vendored\*\*\. Engineering lead never invokes it\. Returns a picture transcribed once into the repo by builders\. Optional sync lane: `references\/design-sync\.md`\./g, "**`/kru-design`** plus Cursor's `/canvas` ([skills](https://cursor.com/docs/skills), [canvas](https://cursor.com/docs/agent/tools/canvas)) | **Not vendored into engineering.** The lead never invokes it. `.dc.html` when `/canvas` isn't available. Optional sync lane: `references/design-sync.md` — Cursor has no claude.ai/design host (known gap).", { md: true, files: /^SOURCES\.md$/, required: /Not vendored into engineering/ }),
  R(/`design` skill/g, "`kru-design` skill", { md: true }),
  R(/made in \*\*Claude Design\*\*/g, "made on **the canvas**", { md: true }),
  R(/made in Claude Design/g, "made on the canvas", { md: true }),
  R(/(?<!design bundle for )\bClaude Design\b/g, "the canvas", { md: true }),
  // eval grader fixtures: Task subagent_type is kru-<seat>; the NOT_UX regex keeps (?:kru:)? because kru: before ) is not rewritten
  R(/NOT_UX='"subagent_type"\\s\*:\\s\*"\(\?:kru:\)\?ux-designer"\\s\*,\\s\*"prompt"'/g, 'NOT_UX=\'"subagent_type"\\s*:\\s*"(?:kru-)?ux-designer"\\s*,\\s*"prompt"\'', { files: /^hooks\/eval-graders\.test\.sh$/, required: /\(\?:kru-\)\?ux-designer/ }),
  R(/built-in agents \(`Explore`, Plan mode\) and skills \(`\/review`, `\/run`\)/g, "built-in agents (`Explore`, Plan mode, the Browser subagent — [subagents](https://cursor.com/docs/subagents)) and skills (`/review`)", { md: true, files: /^ROSTER\.md$/, required: /Plan mode, the Browser subagent/ }),
  R(/(?<!Built-in subagent: the Browser subagent \(\[subagents\]\(https:\/\/cursor\.com\/docs\/subagents\)\)\. )Optional official subagent: `svelte:svelte-file-editor`\./g, "Built-in subagent: the Browser subagent ([subagents](https://cursor.com/docs/subagents)). Optional official subagent: `svelte:svelte-file-editor`.", { md: true, files: /^ROSTER\.md$/, required: /Built-in subagent: the Browser subagent/ }),
  R(/- Behavior: `\/run` to confirm it actually works\./g, "- Behavior: the Browser subagent to confirm it actually works ([browser](https://cursor.com/docs/agent/tools/browser), [subagents](https://cursor.com/docs/subagents)). Cursor's own `/run` is Shell Mode, an alias of `/shell` ([slash commands](https://cursor.com/docs/cli/reference/slash-commands)), which does not confirm a running product.", { md: true, files: /^skills\/kru-lead\/references\/gates\.md$/, required: /the Browser subagent to confirm it actually works/ }),
  R(/`\/research` subagents/g, "Cursor subagents ([subagents](https://cursor.com/docs/subagents))", { md: true, required: /cursor\.com\/docs\/subagents/ }),
  R(/Resolved by a subagent that calls the Skill tool with "research"\./g, "Resolved by a Cursor subagent for a long research task ([subagents](https://cursor.com/docs/subagents)).", { md: true, files: /^skills\/kru-wayfinder\/SKILL\.md$/, required: /Resolved by a Cursor subagent/ }),
  R(/spin up a subagent that calls the Skill tool with "research" to resolve it in parallel/g, "spin up a Cursor subagent ([subagents](https://cursor.com/docs/subagents)) to resolve it in parallel", { md: true, files: /^skills\/kru-wayfinder\/SKILL\.md$/, required: /spin up a Cursor subagent/ }),
  R(/What the count can't say is which of that cost buys nothing: `\/skill-doctor` lists the loaded skills that go unused and what each charges in context\. It's a slash command, so name it for the user to type and read its list against the same `always-on` column\. `\/doctor prompt-audit` reads the prompt text itself: run in this repo it audits the installed plugin's skills and agents for patterns written for older models, and only reports\. Name it for the user to type too; a hit becomes an edit only through `writing-for-agents` → `CALIBRATION\.md`\./g, "What the count can't say is how that cost splits: Cursor's context usage report breaks tokens across the system prompt, tool definitions, rules and skills ([changelog](https://cursor.com/changelog/canvas-improvements)). No built-in lists unused skills or audits prompts written for older models. Those two reads stay a gap (`PORTING.md`).", { md: true, files: /^skills\/kru-roster\/audit\.md$/, required: /context usage report/ }),
  R(/Every candidate is confirmed against the binary, the diff, or the skill's own lines before it reaches a verdict\./g, "Every candidate is confirmed against [Cursor's docs](https://cursor.com/docs) and the [changelog](https://cursor.com/changelog), the diff, or the skill's own lines before it reaches a verdict.", { md: true, files: /^skills\/kru-update\/SKILL\.md$/, required: /cursor\.com\/changelog/ }),
  R(/A bare version number \(`2\.1\.240`\) is `claude 2\.1\.240`\./g, "A bare changelog date (`2026-04-15`) is `claude 2026-04-15`.", { md: true, files: /^skills\/kru-update\/SKILL\.md$/, required: /A bare changelog date/ }),
  R(/a candidate frontmatter key is confirmed against the zod schema in the binary \(`claude plugin validate` passes on any unknown agent key, so it answers a different question\), a subcommand against its `--help`/g, "a candidate frontmatter key is confirmed against [Cursor's plugin docs](https://cursor.com/docs/plugins) and the [changelog](https://cursor.com/changelog) (there is no `claude` binary to grep), a subcommand against the installed CLI's `--help` where that command exists", { md: true, files: /^ROSTER\.md$/, required: /there is no `claude` binary to grep/ }),
  R(/claude mcp list/g, "agent mcp list", { md: true, files: /^skills\/kru-setup\/sheet\.md$/, required: /agent mcp list/ }),
  R(/in claude\.ai artifacts or any browser/g, "in any browser", { md: true, files: /^skills\/kru-algorithmic-art\/SKILL\.md$/, required: /works immediately in any browser/ }),
  R(/in claude\.ai or any browser/g, "in any browser", { md: true, files: /^skills\/kru-algorithmic-art\/SKILL\.md$/, required: /works immediately in any browser/ }),
  R(/1\. \*\*In claude\.ai\*\*: Displayed as an interactive artifact - runs instantly\n2\. \*\*As a file\*\*: Save and open in any browser - no server needed\n3\. \*\*Sharing\*\*: Send the HTML file - it's completely self-contained/g, "1. **In a browser**: save the HTML file and open it. No server. This file is not a Cursor canvas ([canvas](https://cursor.com/docs/agent/tools/canvas) is React)\n2. **Sharing**: Send the HTML file - it's completely self-contained", { md: true, files: /^skills\/kru-algorithmic-art\/SKILL\.md$/, required: /This file is not a Cursor canvas/ }),
  R(/\(https:\/\/cursor\.com\/docs\/agent\/tools\/canvas\) is React\)\n3\. \*\*Sharing\*\*:/g, "(https://cursor.com/docs/agent/tools/canvas) is React)\n2. **Sharing**:", { md: true, files: /^skills\/kru-algorithmic-art\/SKILL\.md$/, required: /is React\)\n2\. \*\*Sharing\*\*:/ }),
  R(/\*\*Single HTML Artifact\*\*/g, "**Single HTML file**", { md: true, files: /^skills\/kru-algorithmic-art\/SKILL\.md$/ }),
  R(/\*\*3\. Single Artifact Structure\*\*/g, "**3. Single file structure**", { md: true, files: /^skills\/kru-algorithmic-art\/SKILL\.md$/ }),
  R(/(?<!design bundle for )\bClaude Design\b/g, "the canvas", { md: true }),
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
const WATCH = [
  /\bClaude Design\b/,
  /\bclaude\.ai\b/,
  /(^|[\s`(])\/design(?!-)\b/,
  /\bArtifact\b(?! Signing)/,
  /(^|[\s`(])\/run(?!\/)\b/,
  /(^|[\s`(])\/(simplify|research|verify)\b/,
  /\/skill-doctor\b/,
  /\/doctor prompt-audit\b/,
  /You should know/,
]

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
    // a fork-owned file inside a ported skill dir (skills/kru-roster/release.md)
    // is laid over a fresh upstream tree before the port runs, so the ported dir
    // exists holding only those files: upstream's dir moves in beside them
    const overlayOnly = existsSync(to) && !existsSync(join(to, "SKILL.md")) && walk(to).every((p) => FORK_OWNED.has(relative(ROOT, p)))
    if (overlayOnly) {
      changed.push(`skills/${d} → skills/${PREFIX}${d} (beside its fork-owned files)`)
      if (!CHECK) {
        for (const e of readdirSync(join(skillsDir, d))) {
          if (existsSync(join(to, e))) problems.push(`skills/${d}/${e}: upstream added a file this fork owns at skills/${PREFIX}${d}/${e} — rename the fork's copy`)
          else renameSync(join(skillsDir, d, e), join(to, e))
        }
        rmSync(join(skillsDir, d), { recursive: true, force: true })
      }
      continue
    }
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
const TEST_CREDENTIALS_BLOCK = `## Test credentials
Before the first test run in a slice that needs secrets or a database, read \`\${CURSOR_PLUGIN_ROOT}/skills/kru-lead/references/test-credentials.md\` and follow it — the lead runs the same guards before a scoped test-count check, a \`kru-test-writer\` dispatch, or a Browser check that needs secrets or a database.
`

const TEST_CREDENTIALS_HEADING = "## Test credentials"

function testCredentialsLines() {
  return TEST_CREDENTIALS_BLOCK.trimEnd().split("\n")
}

function markdownSectionRanges(lines) {
  const ranges = []
  for (let i = 0; i < lines.length; i++) {
    if (!/^## /.test(lines[i])) continue
    const startLine = i
    let endLine = lines.length
    for (let j = i + 1; j < lines.length; j++) {
      if (/^## /.test(lines[j])) {
        endLine = j
        break
      }
    }
    ranges.push({ heading: lines[startLine], startLine, endLine })
    i = endLine - 1
  }
  return ranges
}

function withTrailingNewline(was, text) {
  return was.endsWith("\n") ? `${text}\n` : text
}

function sectionText(lines, range) {
  const chunk = lines.slice(range.startLine, range.endLine)
  let end = chunk.length
  while (end > 0 && chunk[end - 1] === "") end--
  return chunk.slice(0, end).join("\n")
}

function oneBlankLineBefore(lines, lineIndex) {
  if (lineIndex <= 0) return false
  if (lines[lineIndex - 1] !== "") return false
  if (lineIndex >= 2 && lines[lineIndex - 2] === "") return false
  return true
}

function oneBlankLineAfterSection(lines, range) {
  if (range.endLine >= lines.length) {
    let end = lines.length
    while (end > range.startLine && lines[end - 1] === "") end--
    return end === range.endLine || (end === range.endLine - 1 && lines[end] === undefined)
  }
  if (!oneBlankLineBefore(lines, range.endLine)) return false
  if (range.endLine + 1 < lines.length && lines[range.endLine + 1] === "") return false
  return true
}

function credentialsPlacementOk(lines, ranges, anchorIdx, credText) {
  const cred = ranges[anchorIdx + 1]
  if (!cred || cred.heading !== TEST_CREDENTIALS_HEADING) return false
  if (sectionText(lines, cred) !== credText) return false
  if (!oneBlankLineBefore(lines, cred.startLine)) return false
  return oneBlankLineAfterSection(lines, cred)
}

function stripTestCredentialsBlock(body) {
  const lines = body.split("\n")
  const ranges = markdownSectionRanges(lines)
  const idx = ranges.findIndex((r) => r.heading === TEST_CREDENTIALS_HEADING)
  if (idx < 0) return body
  const { startLine, endLine } = ranges[idx]
  const next = [...lines.slice(0, startLine), ...lines.slice(endLine)]
  return withTrailingNewline(body, next.join("\n"))
}

function injectTestCredentialsBlock(body, seat) {
  const anchor =
    seat === "test-writer"
      ? "## The craft (shared skill)"
      : body.includes("## Test-first (shared skill)")
        ? "## Test-first (shared skill)"
        : null
  if (!anchor) return body

  const lines = body.split("\n")
  const ranges = markdownSectionRanges(lines)
  const anchorIdx = ranges.findIndex((r) => r.heading === anchor)
  if (anchorIdx < 0) return body

  const credLines = testCredentialsLines()
  const credText = credLines.join("\n")
  const credRanges = ranges.filter((r) => r.heading === TEST_CREDENTIALS_HEADING)
  if (
    credRanges.length === 1 &&
    credentialsPlacementOk(lines, ranges, anchorIdx, credText)
  ) {
    return body
  }

  const stripped = stripTestCredentialsBlock(body)
  const workLines = stripped.split("\n")
  const workRanges = markdownSectionRanges(workLines)
  const workAnchorIdx = workRanges.findIndex((r) => r.heading === anchor)
  if (workAnchorIdx < 0) return stripped

  const insertAt = workRanges[workAnchorIdx + 1]?.startLine ?? workLines.length
  let before = workLines.slice(0, insertAt)
  while (before.length && before[before.length - 1] === "") before.pop()
  let after = workLines.slice(insertAt)
  while (after.length && after[0] === "") after.shift()

  const merged = [...before, "", ...credLines, ...(after.length ? ["", ...after] : [])]
  return withTrailingNewline(body, merged.join("\n"))
}

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
    // Cursor delegates from the description. "Use proactively" is the phrase the
    // Task tool hints on (cursor.com/docs/subagents → Automatic delegation).
    // Idempotent: a fresh upstream file gains it once; a second port leaves it.
    let description = unquote(value(get(fm, "description")))
    if (!description) problems.push(`agents/${seat}.md: no description`)
    else if (!description.includes("Use proactively"))
      description = `${description.replace(/\s+$/, "")} Use proactively for this seat's stack; dispatch it with the Task tool as kru-${seat}.`
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

    const model = seatModel(seat, fm)

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
    body = injectTestCredentialsBlock(body, seat)
    body = body.replace(/\n{3,}$/, "\n\n")
    write(path, joinFm(out, body))
  }
  return noEdit.sort()
}

// a seat's model line: the fork's pick when SEAT_MODELS names the seat, else
// upstream's pin with its effort as a parameter. a pick whose id isn't confirmed
// falls back; a fallback that isn't either is a problem
const seatPlan = new Map()
function seatModel(seat, fm) {
  let up = unquote(value(get(fm, "model"))) ?? "inherit"
  up = MODEL_ALIAS[up] ?? up
  const effort = value(get(fm, "effort"))
  if (effort) {
    if (!EFFORTS.has(effort)) problems.push(`agents/${seat}.md: effort ${effort} is not one cursor takes`)
    up = `${baseModel(up)}[effort=${effort}]`
  }
  const [pick, fallback] = SEAT_MODELS[seat] ?? [up, TIER_FALLBACK[baseModel(up)] ?? "inherit"]
  seatPlan.set(seat, { pick, fallback })
  if (CURSOR_MODELS.has(baseModel(pick))) return pick
  if (CURSOR_MODELS.has(baseModel(fallback))) {
    log(`  ! agents/${seat}.md: ${pick} is not a confirmed cursor model — using its fallback ${fallback}`)
    return fallback
  }
  problems.push(`agents/${seat}.md: neither ${pick} nor its fallback ${fallback} is in CONFIRMED_MODELS (MODELS.md)`)
  return pick
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
      if (droppedSkillName(name)) continue
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
  return applyEdits(out, rel)
}

// the fork's own edits (scripts/cursor/edits.mjs), last, on the ported text.
// replace the original passage while it is still in the file. the replacement
// counting as already applied is only true once that passage is gone — a file
// that contains the replacement somewhere else, with the original still
// present, is not a silent pass. a replacement that quotes the passage it
// replaced still contains it; that copy is not the original. a file the port
// never reaches leaves its edits unapplied, which the check below reports.
function indexOutside(text, needle, cover) {
  const quoted = cover.includes(needle)
  let from = 0
  while (from <= text.length) {
    const at = text.indexOf(needle, from)
    if (at === -1) return -1
    if (!quoted) return at
    let inside = false
    let cFrom = 0
    while (cFrom <= at) {
      const cAt = text.indexOf(cover, cFrom)
      if (cAt === -1 || cAt > at) break
      if (at + needle.length <= cAt + cover.length) {
        inside = true
        break
      }
      cFrom = cAt + 1
    }
    if (!inside) return at
    from = at + 1
  }
  return -1
}
function applyEditList(text, rel, edits) {
  let out = text
  for (const e of edits) {
    if (e.file !== rel) continue
    const at = indexOutside(out, e.before, e.after)
    if (at !== -1) {
      out = out.slice(0, at) + e.after + out.slice(at + e.before.length)
      e.applied = true
    } else if (out.includes(e.after)) e.applied = true
  }
  return out
}
function applyEdits(text, rel) {
  return applyEditList(text, rel, EDITS)
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
    // gen-asset.ts is the one typescript file a rule edits (the xai hook)
    if (!/\.(md|mdc|sh|mjs|txt)$/.test(rel) && rel !== "scripts/asset/gen-asset.ts") continue
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
  for (const e of EDITS)
    if (!e.applied) problems.push(`fork edit no longer matches ${e.file} (${e.why}): ${JSON.stringify(e.before.slice(0, 90))}… — upstream reworded it; copy the new passage into scripts/cursor/edits.mjs`)
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
        // the first tool call of a conversation waits on this one; store-sync
        // bounds its network calls to fit (KRU_STORE_SYNC_TIMEOUT)
        h("preToolUse", "first-turn.sh", { matcher: "*", timeout: 15 }),
        h("preToolUse", "require-lead.sh", { matcher: "*", timeout: 10 }),
        // cursor tests a matcher as an unanchored regex (new RegExp(m).test(tool)
        // in cursor-agent 2026.10.01), so every name is anchored: `Write` alone
        // would also match a tool named WriteShellStdin
        h("preToolUse", "check-handoff.sh", { matcher: "^Task$", timeout: 10 }),
        h("preToolUse", "brainstorm-guard.sh", { matcher: "^(Shell|Write|Delete)$", timeout: 10 }),
        h("preToolUse", "seat-guard.sh", { matcher: "^(Write|Delete)$", timeout: 10 }, noEdit),
        // product repos wire the guard from .cursor/hooks.json (hooks.repo.mcp-guard.json);
        // plugin installs load the same script here (cloud agents skip plugin hooks).
        h("preToolUse", "mcp-outbound-guard.sh", { matcher: "^CallDynamicTool$", timeout: 10, failClosed: true }),
        h("preToolUse", "mcp-outbound-guard.sh", { matcher: "^MCP:.*$", timeout: 10, failClosed: true }),
      ],
      beforeMCPExecution: [
        h("beforeMCPExecution", "mcp-outbound-guard.sh", { matcher: "*", timeout: 10, failClosed: true }),
      ],
      subagentStart: [h("subagentStart", "seat-guard.sh", { timeout: 10 }, noEdit)],
      postToolUse: [h("postToolUse", "log-dispatch.sh", { matcher: "^Task$", timeout: 10 })],
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
// and a cloud agent never runs. the PR babysit loop is the one procedure this
// rule carries: a cloud agent follows it on every wake, and the skill only points.
// the skill's lead-owned paragraph, copied after the fork edits have applied,
// so the always-on rule cannot paraphrase it into "anything else is dispatched".
function leadOwnedParagraph() {
  const skill = readF(join(ROOT, "skills", "kru-lead", "SKILL.md")) ?? ""
  const start = skill.indexOf("**Lead-owned work is not that list")
  const end = skill.indexOf("\n\n**No covering seat:")
  if (start < 0 || end <= start) {
    problems.push("skills/kru-lead/SKILL.md has no lead-owned paragraph for rules/kru-lead.mdc")
    return ""
  }
  return skill.slice(start, end)
}

function portTestCredentialsReference() {
  const src = join(ROOT, "scripts/cursor/test-credentials.md")
  const dest = join(ROOT, "skills/kru-lead/references/test-credentials.md")
  if (!existsSync(src)) return
  const body = readF(src)
  mkdirSync(dirname(dest), { recursive: true })
  if (readF(dest) !== body) write(dest, body)
}

function portRules(version) {
  const owned = leadOwnedParagraph()
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
    "- Seats are custom subagents. Dispatch is a Task tool call with `subagent_type` `kru-<seat>` (`kru-code-reviewer`, `kru-react-ui-builder`), the `name:` in `agents/<seat>.md`. Never do that seat's work in the main thread. Try the call. If the Task tool rejects `kru-<seat>` or does not offer it, report the types it offered and stop. Do not do the seat's work inline, and do not decide that from a directory listing. The closed inline list does not depend on file type. Only these edits run in the main thread: a typo, a rename, a string the user dictates, a comment, docs, a version pin, a reviewer's exact replacement after the loop closed. A typo or a comment in a CSS, component, route, or test file is still on this list. A behavior, CSS, component, route, or test change that is not on this list is dispatched.",
    "",
    owned,
    "",
    "- A slice no seat covers: report and stop. Do not implement it.",
    "- The PM is the bot or person that briefed this session; the owner approves hard-to-reverse calls (the `kru-lead` skill says what reaches the owner). The PM bot's own operating rules govern escalation and approval; the plugin's generic default applies only when the PM has none.",
    "- Team skills are `kru-<name>` (`kru-testing`), and the PM's commands are `/kru-<name>` (`/kru-brief`, `/kru-setup`).",
    "- The install dir is `${CURSOR_PLUGIN_ROOT}`; the store resolver is `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\"`.",
    "- **Cloud agents: no outbound connector MCP.** On a cloud agent, never send, post, reply, forward, share, publish, schedule, upload, comment, react, or delete through team connectors (Gmail, Slack, Linear comments, Google Docs/Drive edits and shares, GitHub comments or merges via MCP). Hand any other connector tool back to the PM bot with the exact tool name and arguments. When Cursor runs hooks on MCP calls, the repo hook is default-deny: only reads, drafts, and Linear `save_issue` pass. Cursor cloud agents do not currently run those hooks for connector MCP (verified Oct 2026); this rule is the only guard there.",
    "- **PR babysit loop.** After you open or own a pull request, subscribe to its reviews, comments, and CI and check. Clean means CI green and every review thread answered. On AngelProtocolFinance/better-giving, wait until Greptile's review is posted and no Greptile P0 or P1 is still open; never wait for Greptile on any other repo. Already clean: tell the PM that requested the work it is ready to merge (the plugin maintainer for this plugin after CI (`verify`); the owner for product repos — `skills/kru-lead/SKILL.md` → *Who acts at the door*). Not clean: fix a valid finding, `commit` locally on the branch, reply on each thread — say why when the finding stands — and return proof for the PM bot to push; if nothing is left to fix, end the turn. Repeat on the next wake until it is clean. That report is the only message out.",
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
    "A repo that has run `/kru-setup` carries a sheet in its root `AGENTS.md`, stamped `<!-- kru v… -->`. When the working repo's `AGENTS.md` has no such stamp, name `/kru-setup` to the PM once this conversation (the PM bot runs it itself; a headless run says it in its return), then carry on: brainstorming, briefs and grilling need no setup, and on a blank repo setup is where the stack gets settled. Skip it in the kru-cursor repo itself.",
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
    if (!/\.(md|mdc|sh|json|mjs)$/.test(rel) || FORK_OWNED.has(rel) || FORK_OWNED_DIRS.test(rel)) continue
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

// --test-edits: the apply order, including a replacement that quotes its own
// original passage (eleven edits do) and one that already sits elsewhere in
// the file. exits before the port.
if (process.argv.includes("--test-edits")) {
  const file = "t.md"
  const fail = (name) => {
    console.error(`edit apply: ${name}`)
    process.exit(1)
  }
  const run = (before, after, text) => {
    const e = { file, before, after, applied: false }
    return { out: applyEditList(text, file, [e]), applied: e.applied }
  }
  {
    const { out, applied } = run("ALPHA passage", "BETA passage", "intro BETA passage middle ALPHA passage end")
    if (out !== "intro BETA passage middle BETA passage end" || !applied) fail("replacement elsewhere hid the original")
    const again = run("ALPHA passage", "BETA passage", out)
    if (again.out !== out || !again.applied) fail("second pass rewrote a finished edit")
  }
  {
    const { out, applied } = run("keep this", "keep this, and more", "keep this")
    if (out !== "keep this, and more" || !applied) fail("did not extend the passage")
    const again = run("keep this", "keep this, and more", out)
    if (again.out !== out || !again.applied) fail("a replacement that quotes the original was applied again")
  }
  {
    const { out, applied } = run("keep this", "keep this, and more", "keep this, and more\n\nkeep this")
    if (out !== "keep this, and more\n\nkeep this, and more" || !applied) fail("replaced inside the existing replacement")
  }
  {
    const { applied } = run("gone", "new", "unrelated")
    if (applied) fail("a missing passage counted as applied")
  }
  console.log("edit apply: ok")
  process.exit(0)
}

// --test-inject-credentials: heading-aware strip/replace ## Test credentials.
if (process.argv.includes("--test-inject-credentials")) {
  const fail = (name) => {
    console.error(`inject credentials: ${name}`)
    process.exit(1)
  }
  const credPara = testCredentialsLines().slice(1).join("\n")
  const assertTwice = (name, body, seat, check) => {
    const once = injectTestCredentialsBlock(body, seat)
    check(once)
    const twice = injectTestCredentialsBlock(once, seat)
    if (once !== twice) fail(`${name}: second inject changed output`)
  }
  const hasCanonical = (text) =>
    text.includes("## Test credentials\n") &&
    text.includes(credPara) &&
    !text.includes("stale line")

  assertTwice("anchor last in file", "## Test-first (shared skill)\nlast line\n", "hono-builder", (out) => {
    if (!hasCanonical(out)) fail("anchor last: missing canonical block")
    if (!out.trimEnd().endsWith(credPara)) fail("anchor last: credentials not at EOF")
    if (out.includes("## Memory")) fail("anchor last: invented trailing section")
  })

  assertTwice(
    "existing credentials section at EOF",
    "## Test-first (shared skill)\ncontent\n\n## Test credentials\nstale line\n",
    "hono-builder",
    (out) => {
      if (!hasCanonical(out)) fail("EOF stale: missing canonical block")
      if (out.includes("stale line")) fail("EOF stale: left stale content")
    },
  )

  assertTwice(
    "next heading with no blank line after credentials",
    "## Test-first (shared skill)\ncontent\n\n## Test credentials\nstale line\n## Memory (this repo's facts)\nmem\n",
    "hono-builder",
    (out) => {
      if (!hasCanonical(out)) fail("tight heading: missing canonical block")
      if (!out.includes("## Memory (this repo's facts)\nmem")) fail("tight heading: swallowed next section")
    },
  )

  assertTwice(
    "existing credentials with one blank line before next section",
    "## Test-first (shared skill)\ncontent\n\n## Test credentials\nstale line\n\n## Memory (this repo's facts)\nmem\n",
    "hono-builder",
    (out) => {
      if (!hasCanonical(out)) fail("blank before next: missing canonical block")
      const i = out.indexOf("## Memory (this repo's facts)")
      if (i < 0) fail("blank before next: lost memory section")
      if (out.slice(i - 2, i) !== "\n\n") fail("blank before next: wrong spacing before memory")
    },
  )

  assertTwice(
    "test-writer anchor after craft",
    "## The craft (shared skill)\ncraft\n\n## Capture\nmore\n",
    "test-writer",
    (out) => {
      if (!hasCanonical(out)) fail("test-writer: missing canonical block")
      const craft = out.indexOf("## The craft (shared skill)")
      const cred = out.indexOf("## Test credentials")
      const capture = out.indexOf("## Capture")
      if (craft < 0 || cred < craft || capture < cred) fail("test-writer: wrong section order")
    },
  )

  const stripped = stripTestCredentialsBlock("## Tail\n\n## Test credentials\nstale line\n")
  if (stripped !== stripTestCredentialsBlock(stripped)) fail("strip alone not idempotent at EOF")
  if (stripped.includes("stale line")) fail("strip at EOF left stale content")

  console.log("inject credentials: ok")
  process.exit(0)
}

// --list-models: the confirmed ids, one per line (scripts/verify.sh checks every
// agent's model against them); --list-models --seats: seat, pick and fallback,
// tab-separated — the source of MODELS.md's map
if (process.argv.includes("--list-models")) {
  if (process.argv.includes("--seats")) {
    for (const seat of seatNames()) {
      const fm = splitFrontmatter(readF(join(ROOT, "agents", `${seat}.md`)))
      if (fm) seatModel(seat, fm)
      const p = seatPlan.get(seat)
      if (p) console.log([seat, p.pick, p.fallback].join("\t"))
    }
  } else console.log(Object.keys(CONFIRMED_MODELS).join("\n"))
  process.exit(0)
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

// --check-porting-hand-owned: every FORK_OWNED file is cited in PORTING.md's table
if (process.argv.includes("--check-porting-hand-owned")) {
  const porting = readF(join(ROOT, "PORTING.md"))
  const missing = [...FORK_OWNED].filter((f) => existsSync(join(ROOT, f)) && !porting.includes("`" + f + "`"))
  if (missing.length) {
    console.error("PORTING.md hand-owned table missing FORK_OWNED entries:\n" + missing.map((f) => "  " + f).join("\n"))
    process.exit(1)
  }
  console.log(`PORTING.md cites all ${[...FORK_OWNED].filter((f) => existsSync(join(ROOT, f))).length} FORK_OWNED files`)
  process.exit(0)
}

// the per-segment insert is decided inside the readonly-bash rewrite, which
// also builds the text a later write() would save. run that rewrite once
// before any rename or write and discard the pass. a drifted anchor still
// matches the loop, and the rule would otherwise emit the hook without
// `kru_fn_def "$seg"` and write it before the failure at the bottom. this
// pass restores the rule and edit state so a clean tree ports as before.
// --check never writes, so it keeps reporting the miss with the rest of the port.
function guardSegmentAnchor() {
  if (CHECK) return
  const rel = "hooks/readonly-bash.sh"
  const path = join(ROOT, rel)
  if (!existsSync(path)) return
  const saved = RULES.map((rule) =>
    rule === PATHS_END
      ? null
      : { hits: rule.hits, re: rule.re.lastIndex, required: rule.required ? rule.required.lastIndex : 0 },
  )
  const savedApplied = EDITS.map((e) => e.applied)
  const savedKeys = new Set(contents.keys())
  const before = problems.length
  rewrite(readFileSync(path, "utf8"), rel)
  if (problems.length > before) {
    console.error(`\n${problems.length} problem(s):`)
    for (const p of problems) console.error(`  ! ${p}`)
    process.exit(1)
  }
  RULES.forEach((rule, i) => {
    if (rule === PATHS_END) return
    if (saved[i].hits === undefined) delete rule.hits
    else rule.hits = saved[i].hits
    rule.re.lastIndex = saved[i].re
    if (rule.required) rule.required.lastIndex = saved[i].required
  })
  EDITS.forEach((e, i) => {
    if (savedApplied[i] === undefined) delete e.applied
    else e.applied = savedApplied[i]
  })
  for (const k of [...contents.keys()]) if (!savedKeys.has(k)) contents.delete(k)
}

guardSegmentAnchor()
relayout()
const noEdit = portAgents()
portSkills()
portText()
const version = portVersion()
portManifest(version)
portHooks(noEdit)
portRules(version)
portTestCredentialsReference()
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
