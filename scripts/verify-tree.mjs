#!/usr/bin/env node
// the static checks over the tree itself, for scripts/verify.sh: the plugin is
// one cursor will load and the marketplace will accept (cursor.com/docs/
// reference/plugins → Submission checklist), every component's frontmatter
// parses the way cursor reads it, hooks.json names only real events, the
// version agrees everywhere it is stated, the read-only seats can't edit, and
// no claude-code vocabulary survived outside the files that discuss it on
// purpose. each check prints one line; any failure exits 1.
//
// yaml is parsed by python3's PyYAML (or `uv run --with pyyaml`), the same
// parser upstream's verify uses, so the fork adds no npm dependency.
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs"
import { join, dirname, relative, basename, isAbsolute, normalize } from "node:path"
import { fileURLToPath } from "node:url"
import { execFileSync, spawnSync } from "node:child_process"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const read = (p) => readFileSync(join(ROOT, p), "utf8")
const rel = (p) => relative(ROOT, p)
const results = []
const notes = []
const fail = (check, msg) => results.push([check, msg])
// a tool matcher's names, or null when it isn't one. cursor tests a matcher as
// an unanchored regex, so a tool name is only matched exactly when anchored:
// `^Name$` or `^(A|B)$` ("*" matches all). one that doesn't compile matches
// every tool (`catch{return!0}` in cursor-agent 2026.10.01)
const TOOL_NAME = "[A-Za-z][A-Za-z0-9:_-]*"
const ANCHORED = new RegExp(`^\\^(?:(${TOOL_NAME})|\\((${TOOL_NAME}(?:\\|${TOOL_NAME})*)\\))\\$$`)
function matcherNames(m) {
  if (m === "*") return ["*"]
  if (m === "^MCP:.*$") return ["MCP:*"]
  try { new RegExp(m) } catch { return null }
  const a = ANCHORED.exec(m)
  return a ? (a[1] ?? a[2]).split("|") : null
}
// `--matcher <m>`: exit 0 when the check takes m (scripts/cursor-hooks.test.sh)
if (process.argv[2] === "--matcher") process.exit(matcherNames(String(process.argv[3])) ? 0 : 1)
const git = (...a) => execFileSync("git", a, { cwd: ROOT, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim()
const files = git("ls-files", "-co", "--exclude-standard").split("\n").filter(Boolean).filter((f) => existsSync(join(ROOT, f)))

const SEAT_COUNT = 37
// upstream's no-edit seats (no Edit/Write in their tools: allowlist). the ones
// whose work writes nothing carry cursor's `readonly`; the two store writers
// are refused the Write tool by hooks/seat-guard.sh instead (scripts/port.mjs → STORE_WRITERS)
const READ_ONLY = ["accessibility-reviewer", "architecture-reviewer", "code-reviewer", "conversion-copywriter", "ux-auditor", "visual-reviewer"]
const STORE_WRITERS = ["dispatch-auditor", "planner"]
const PREFIX = "kru-"
const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/
// the shape of a model line: an id plus cursor's optional `[key=value,…]`
// parameters. which ids are allowed is verify.sh's seat-models check
// (scripts/port.mjs → CONFIRMED_MODELS)
const MODEL = /^[a-z0-9][a-z0-9.-]*(\[(effort=(low|medium|high|xhigh|max)|fast=(true|false)|context=\d+k)(,(effort=(low|medium|high|xhigh|max)|fast=(true|false)|context=\d+k))*\])?$/
// seats bill only against Cursor's included usage pool (cursor.com/docs/models)
const INCLUDED_POOL = new Set(["grok-4.7", "grok-4.6", "grok-4.5", "composer-2.5"])
const baseModelId = (m) => m.replace(/\[.*\]$/, "")

// --- yaml, via python ------------------------------------------------------------
function pyYaml(paths) {
  const prog = `
import json, sys, yaml
out = {}
for f in sys.argv[1:]:
    text = open(f, encoding="utf-8").read()
    try:
        if f.endswith((".yml", ".yaml")):
            list(yaml.safe_load_all(text)); out[f] = {"ok": True}; continue
        if not text.startswith("---\\n"):
            out[f] = {"error": "no frontmatter"}; continue
        end = text.find("\\n---\\n", 4)
        if end < 0:
            out[f] = {"error": "frontmatter not closed"}; continue
        fm = yaml.safe_load(text[4:end])
        out[f] = {"fm": fm if isinstance(fm, dict) else None, "error": None if isinstance(fm, dict) else "frontmatter is not a mapping"}
    except Exception as e:
        out[f] = {"error": str(e).splitlines()[0]}
print(json.dumps(out, default=str))
`
  const tries = [["python3", ["-c", prog]], ["uv", ["run", "-q", "--no-project", "--with", "pyyaml", "python3", "-c", prog]]]
  for (const [cmd, args] of tries) {
    const r = spawnSync(cmd, [...args, ...paths], { cwd: ROOT, encoding: "utf8", maxBuffer: 1 << 26 })
    if (r.status === 0) return JSON.parse(r.stdout)
  }
  console.log("FAIL yaml: need python3 with PyYAML, or uv")
  process.exit(1)
}

const agentFiles = files.filter((f) => /^agents\/[^/]+\.md$/.test(f))
const skillFiles = files.filter((f) => /^skills\/[^/]+\/SKILL\.md$/.test(f))
const ruleFiles = files.filter((f) => /^rules\/[^/]+\.(mdc|md)$/.test(f))
const commandFiles = files.filter((f) => /^commands\/[^/]+\.md$/.test(f))
const yamlFiles = files.filter((f) => /\.ya?ml$/.test(f))
const parsed = pyYaml([...agentFiles, ...skillFiles, ...ruleFiles, ...commandFiles, ...yamlFiles])
const fmOf = (f) => {
  const p = parsed[f]
  if (!p || p.error) return fail("frontmatter", `${f}: ${p?.error ?? "unparsed"}`), null
  return p.fm
}
const str = (v) => typeof v === "string" && v.trim().length > 0

// --- manifest ------------------------------------------------------------------------
const relPathOk = (p) => typeof p === "string" && !isAbsolute(p) && !/^[a-z]+:\/\//i.test(p) && !normalize(p).split(/[\\/]/).includes("..")
let manifest = {}
{
  const path = ".cursor-plugin/plugin.json"
  try {
    manifest = JSON.parse(read(path))
  } catch (err) {
    fail("manifest", `${path}: ${err.message}`)
  }
  if (!/^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$/.test(manifest.name ?? "")) fail("manifest", `name ${manifest.name} is not lower-case kebab-case`)
  if (manifest.name !== "kru-cursor") fail("manifest", `name is ${manifest.name}, want kru-cursor`)
  if (!str(manifest.description)) fail("manifest", "no description")
  if (!/^\d+\.\d+\.\d+(\+[0-9A-Za-z.-]+)?$/.test(manifest.version ?? "")) fail("manifest", `version ${manifest.version} is not semver`)
  if (!str(manifest.author?.name)) fail("manifest", "author.name is required")
  if (manifest.license !== "MIT") fail("manifest", `license ${manifest.license}, want MIT`)
  if (!str(manifest.repository)) fail("manifest", "no repository")
  if (manifest.logo !== undefined) {
    if (!relPathOk(manifest.logo)) fail("manifest", `logo ${manifest.logo} is not a relative path inside the repo`)
    else if (!existsSync(join(ROOT, manifest.logo))) fail("manifest", `logo ${manifest.logo} is not in the tree`)
    else if (!files.includes(manifest.logo)) fail("manifest", `logo ${manifest.logo} is not committed`)
  }
  for (const k of ["rules", "agents", "skills", "commands", "hooks", "mcpServers"]) {
    const v = manifest[k]
    if (v === undefined || (typeof v === "object" && !Array.isArray(v))) continue
    for (const p of [v].flat()) if (!relPathOk(p) || !existsSync(join(ROOT, p))) fail("manifest", `${k}: ${p} is not a relative path to something in the tree`)
  }
  const known = new Set(["name", "displayName", "description", "version", "author", "homepage", "repository", "license", "keywords", "logo", "rules", "agents", "skills", "commands", "hooks", "mcpServers", "variables"])
  for (const k of Object.keys(manifest)) if (!known.has(k)) fail("manifest", `unknown manifest key ${k}`)
  if (existsSync(join(ROOT, "mcp.json"))) notes.push("mcp.json present — check its ${VAR}s are declared under variables")
  let mkt = {}
  try {
    mkt = JSON.parse(read(".cursor-plugin/marketplace.json"))
  } catch (err) {
    fail("manifest", `.cursor-plugin/marketplace.json: ${err.message}`)
  }
  if (!KEBAB.test(mkt.name ?? "") || !str(mkt.owner?.name) || !Array.isArray(mkt.plugins)) fail("manifest", "marketplace.json needs name, owner.name and plugins")
  const names = (mkt.plugins ?? []).map((p) => p.name)
  if (new Set(names).size !== names.length) fail("manifest", "marketplace.json plugin names are not unique")
  const entry = (mkt.plugins ?? []).find((p) => p.name === manifest.name)
  if (!entry) fail("manifest", `marketplace.json has no ${manifest.name} entry`)
  else {
    const src = typeof entry.source === "string" ? entry.source : entry.source?.path
    if (!relPathOk(src) || !existsSync(join(ROOT, src, ".cursor-plugin", "plugin.json"))) fail("manifest", `marketplace entry source ${src} doesn't lead to this manifest`)
    if (entry.version !== manifest.version || mkt.metadata?.version !== manifest.version) fail("manifest", "marketplace.json versions disagree with plugin.json")
  }
  if (existsSync(join(ROOT, ".claude-plugin"))) fail("manifest", ".claude-plugin/ is still in the tree")
  if (!existsSync(join(ROOT, "README.md"))) fail("manifest", "README.md is required")
}

// --- components ----------------------------------------------------------------------------
const seats = agentFiles.map((f) => basename(f, ".md"))
const agentFm = new Map()
for (const f of agentFiles) {
  const fm = fmOf(f)
  if (!fm) continue
  const seat = basename(f, ".md")
  agentFm.set(seat, fm)
  if (fm.name !== PREFIX + seat) fail("frontmatter", `${f}: name ${fm.name}, want ${PREFIX}${seat}`)
  if (!KEBAB.test(String(fm.name))) fail("frontmatter", `${f}: name is not kebab-case`)
  if (!str(fm.description)) fail("frontmatter", `${f}: no description`)
  // cursor's subagent parser reads one line per key
  const raw = read(f).split("\n---\n")[0]
  if (!/^description: \S.*$/m.test(raw) || /^description: [>|]/m.test(raw)) fail("frontmatter", `${f}: description must sit on one line`)
  if (!MODEL.test(String(fm.model))) fail("frontmatter", `${f}: model ${fm.model} is not a cursor model id (MODELS.md)`)
  if ("readonly" in fm && typeof fm.readonly !== "boolean") fail("frontmatter", `${f}: readonly is not a boolean`)
  if ("permissionMode" in fm && fm.permissionMode !== "readonly") fail("frontmatter", `${f}: permissionMode ${fm.permissionMode} — only readonly is read`)
  if (("permissionMode" in fm) !== (fm.readonly === true)) fail("frontmatter", `${f}: readonly and permissionMode: readonly travel together`)
  for (const k of Object.keys(fm))
    if (!["name", "description", "model", "readonly", "permissionMode", "is_background"].includes(k)) fail("frontmatter", `${f}: key \`${k}\` is not one cursor reads (claude-only?)`)
}
const skillNames = []
for (const f of skillFiles) {
  const fm = fmOf(f)
  if (!fm) continue
  const dir = basename(dirname(f))
  skillNames.push(dir)
  if (fm.name !== dir) fail("frontmatter", `${f}: name ${fm.name} ≠ directory ${dir}`)
  if (!KEBAB.test(String(fm.name)) || String(fm.name).length > 64) fail("frontmatter", `${f}: name is not 1–64 lower-case words joined by hyphens`)
  if (!dir.startsWith(PREFIX)) fail("frontmatter", `${f}: skill dir lacks the ${PREFIX} prefix`)
  if (!str(fm.description)) fail("frontmatter", `${f}: no description`)
  else if (fm.description.length > 1024) fail("frontmatter", `${f}: description is ${fm.description.length} chars (max 1024)`)
  for (const k of ["user-invocable", "allowed-tools"]) if (k in fm) fail("frontmatter", `${f}: claude-only key \`${k}\` survived the port`)
  if ("disable-model-invocation" in fm && typeof fm["disable-model-invocation"] !== "boolean") fail("frontmatter", `${f}: disable-model-invocation is not a boolean`)
}
for (const d of readdirSync(join(ROOT, "skills"))) if (statSync(join(ROOT, "skills", d)).isDirectory() && !existsSync(join(ROOT, "skills", d, "SKILL.md"))) fail("frontmatter", `skills/${d}: no SKILL.md`)
for (const f of ruleFiles) {
  const fm = fmOf(f)
  if (!fm) continue
  if (!f.endsWith(".mdc")) fail("frontmatter", `${f}: rules are .mdc files`)
  if (!str(fm.description)) fail("frontmatter", `${f}: no description`)
  if (typeof fm.alwaysApply !== "boolean") fail("frontmatter", `${f}: alwaysApply is not a boolean`)
  if ("globs" in fm && !(typeof fm.globs === "string" || Array.isArray(fm.globs))) fail("frontmatter", `${f}: globs is not a string or list`)
}
if (!ruleFiles.includes("rules/kru-lead.mdc")) fail("frontmatter", "rules/kru-lead.mdc is missing")
for (const f of commandFiles) {
  const fm = fmOf(f)
  if (!fm) continue
  const name = basename(f, ".md")
  if (fm.name !== name || !KEBAB.test(name)) fail("frontmatter", `${f}: name ${fm.name} ≠ file stem ${name}`)
  if (!str(fm.description)) fail("frontmatter", `${f}: no description`)
  if (!skillNames.includes(name)) fail("frontmatter", `${f}: names no skill`)
}

// --- json + yaml -------------------------------------------------------------------------------
for (const f of files.filter((f) => f.endsWith(".json"))) {
  try {
    JSON.parse(read(f))
  } catch (err) {
    fail("json/yaml", `${f}: ${err.message}`)
  }
}
for (const f of yamlFiles) if (parsed[f]?.error) fail("json/yaml", `${f}: ${parsed[f].error}`)

// --- hooks.json ----------------------------------------------------------------------------------
const EVENTS = new Set(["sessionStart", "sessionEnd", "preToolUse", "postToolUse", "postToolUseFailure", "subagentStart", "subagentStop", "beforeShellExecution", "afterShellExecution", "beforeMCPExecution", "afterMCPExecution", "beforeReadFile", "afterFileEdit", "beforeSubmitPrompt", "preCompact", "stop", "afterAgentResponse", "afterAgentThought", "beforeTabFileRead", "afterTabFileEdit", "workspaceOpen"])
const TOOL_MATCHERS = new Set(["Shell", "Read", "Write", "Grep", "Delete", "Task", "CallDynamicTool", "*"])
let hooks = {}
try {
  hooks = JSON.parse(read("hooks/hooks.json"))
} catch (err) {
  fail("hooks", `hooks/hooks.json: ${err.message}`)
}
if (hooks.version !== 1) fail("hooks", "version must be 1")
for (const [event, list] of Object.entries(hooks.hooks ?? {})) {
  if (!EVENTS.has(event)) fail("hooks", `${event} is not a cursor hook event`)
  if (!Array.isArray(list)) { fail("hooks", `${event} is not a list`); continue }
  for (const e of list) {
    if ("hooks" in e) fail("hooks", `${event}: nested hooks arrays are claude's format`)
    if (typeof e.command !== "string") fail("hooks", `${event}: entry without a command`)
    if (e.type !== undefined && e.type !== "command") fail("hooks", `${event}: type ${e.type} — cloud agents run command hooks only`)
    for (const k of Object.keys(e)) if (!["command", "type", "timeout", "matcher", "loop_limit", "failClosed"].includes(k)) fail("hooks", `${event}: unknown key ${k}`)
    if (["preToolUse", "postToolUse", "postToolUseFailure"].includes(event) && e.matcher !== undefined)
    {
      const m = String(e.matcher)
      const names = matcherNames(m)
      if (!names) fail("hooks", `${event}: matcher ${m} is not anchored (^Name$ or ^(A|B)$) — cursor reads it as an unanchored regex`)
      else for (const n of names)
        if (!TOOL_MATCHERS.has(n) && !/^MCP:/.test(n) && n !== "MCP:*")
          fail("hooks", `${event}: matcher ${n} is not a cursor tool (claude's Bash/Edit/Agent?)`)
    }
    for (const s of String(e.command).match(/[a-z0-9-]+\.sh/g) ?? []) if (!existsSync(join(ROOT, "hooks", s))) fail("hooks", `${event}: ${s} is not in hooks/`)
    if (!/^bash "\$\{CURSOR_PLUGIN_ROOT\}\/hooks\/cursor-hook\.sh" /.test(e.command)) fail("hooks", `${event}: ${e.command} skips the adapter`)
  }
}

// --- version ----------------------------------------------------------------------------------------
{
  const version = read("VERSION").trim()
  if (!/^\d+\.\d+\.\d+\+kru\d+\.\d+\.\d+$/.test(version)) fail("version", `VERSION ${version} is not <fork>+kru<upstream>`)
  if (manifest.version !== version) fail("version", `plugin.json version ${manifest.version} ≠ VERSION ${version}`)
  const roster = read("ROSTER.md").match(/^# Roster — v(\S+)/m)?.[1]
  if (roster !== version) fail("version", `ROSTER.md header v${roster} ≠ VERSION ${version}`)
  if (!read("rules/kru-lead.mdc").includes(`kru-cursor v${version}`)) fail("version", "rules/kru-lead.mdc carries another version")
  for (const f of files.filter((f) => /\.md$/.test(f)))
    for (const m of read(f).matchAll(/\bv?(\d+\.\d+\.\d+)\+kru(\d+\.\d+\.\d+)\b/g))
      if (m[0].replace(/^v/, "") !== version) fail("version", `${f}: names ${m[0]}, VERSION is ${version}`)
  // the upstream half is the VERSION of the newest upstream commit merged in —
  // the newest commit in history that predates the port
  let upstream = null
  try {
    for (const c of git("rev-list", "HEAD").split("\n")) {
      if (spawnSync("git", ["cat-file", "-e", `${c}:scripts/port.mjs`], { cwd: ROOT }).status !== 0) {
        upstream = git("show", `${c}:VERSION`)
        break
      }
    }
  } catch {}
  if (upstream === null) notes.push("upstream pin not checked (no upstream commit in this clone's history — fetch with depth 0)")
  else if (upstream !== version.split("+kru")[1])
    fail(
      "version",
      `VERSION pins kru ${version.split("+kru")[1]}, the newest upstream commit in history says ${upstream} — upstream must be recorded as a merge parent (never squash or rebase a port/sync pull request; see skills/kru-roster/fork-sync.md)`,
    )
}

// --- seats --------------------------------------------------------------------------------------------
{
  if (seats.length !== SEAT_COUNT) fail("seats", `agents/ holds ${seats.length} seats, want ${SEAT_COUNT}`)
  const roster = read("ROSTER.md")
  const section = roster.split(/^## Current specialists.*$/m)[1]?.split(/^## /m)[0] ?? ""
  const rows = [...section.matchAll(/^\| `([a-z0-9-]+)` \|/gm)].map((m) => m[1])
  for (const s of seats) if (!rows.includes(s)) fail("seats", `${s}: no ROSTER.md → Current specialists row`)
  for (const r of rows) if (!seats.includes(r)) fail("seats", `ROSTER.md row \`${r}\` names no agents/${r}.md`)
  for (const [s, fm] of agentFm) {
    const ro = fm.readonly === true
    if (ro !== READ_ONLY.includes(s)) fail("seats", `${s}: readonly is ${ro}, the read-only list says ${READ_ONLY.includes(s)}`)
  }
  const guard = (hooks.hooks?.preToolUse ?? []).find((e) => /seat-guard\.sh/.test(e.command))
  const guarded = guard ? guard.command.split(/\s+/).slice(4).sort() : []
  const want = [...READ_ONLY, ...STORE_WRITERS].sort()
  if (JSON.stringify(guarded) !== JSON.stringify(want)) fail("seats", `seat-guard refuses edits to [${guarded}], want [${want}]`)
  if (!guard || !/Write\|Delete|Delete\|Write/.test(guard.matcher ?? "")) fail("seats", "seat-guard must match Write and Delete")
  const start = (hooks.hooks?.subagentStart ?? []).find((e) => /seat-guard\.sh/.test(e.command))
  if (!start || start.command !== guard?.command.replace("preToolUse", "subagentStart")) fail("seats", "subagentStart must map seats for seat-guard with the same list")
  const gate = read("hooks/check-handoff.sh")
  if (!gate.includes(`grep -q '^readonly: true' "$plugin_root/agents/$seat.md"`)) fail("seats", "hooks/check-handoff.sh lost the ported read-only test (scripts/port.mjs)")
  if (/\^tools:/.test(gate)) fail("seats", "hooks/check-handoff.sh still reads a tools: line, which no ported seat has")
  const anthropic = /claude|opus|sonnet|haiku/i
  for (const [s, fm] of agentFm) {
    const m = String(fm.model ?? "")
    if (anthropic.test(m)) fail("seats", `agents/${s}.md: model '${m}' must not name an Anthropic id (scripts/port.mjs → SEAT_MODELS)`)
    const base = baseModelId(m)
    if (!INCLUDED_POOL.has(base)) fail("seats", `agents/${s}.md: model '${m}' must be in Cursor's included pool (${[...INCLUDED_POOL].join(", ")})`)
  }
}

// --- dispatch names -----------------------------------------------------------------------
// agents/<seat>.md declares name: kru-<seat>. The lead, the gates, and the
// roster have to send that string as the Task subagent_type. A bare seat name
// there is how a cloud agent does the seat's work itself.
{
  const lead = read("skills/kru-lead/SKILL.md")
  const need = [
    "subagent_type",
    "kru-<seat>",
    "Try the call. If the Task tool rejects `kru-<seat>` or does not offer it, report the types it offered and stop.",
    "do not decide that from a directory listing.",
    "the list does not depend on file type",
    "A typo or a comment in a CSS, component, route, or test file is still on this list.",
    "Lead-owned work is not that list",
    "No covering seat: report and stop.",
    "Until that seat exists, report and stop on the slice.",
    "a typo, a rename, a string the user dictates, a comment, docs, a version pin, a reviewer's exact replacement after the loop closed",
    "only deeper nesting can't",
  ]
  for (const s of need) if (!lead.includes(s)) fail("dispatch", `skills/kru-lead/SKILL.md is missing: ${s}`)
  if (lead.includes("subagents can't spawn subagents"))
    fail("dispatch", "skills/kru-lead/SKILL.md still says subagents can't spawn subagents")
  if (lead.includes("fully specified and checkable inline")) fail("dispatch", "the inline exception is still open")
  if (lead.includes("on the seat's skills")) fail("dispatch", "inline work still offers the seat's skills")
  if (lead.includes("any CSS/component/route/test change is dispatched")) fail("dispatch", "file type still overrides the closed inline list")
  if (lead.includes("the general path")) fail("dispatch", "a slice with no seat still offers the general path")
  if (lead.includes("config tweak")) fail("dispatch", "inline still names a config tweak")
  if (lead.includes("If that list has no")) fail("dispatch", "the stop still keys off a directory list")
  const rule = read("rules/kru-lead.mdc")
  if (!rule.includes("report the types it offered and stop"))
    fail("dispatch", "rules/kru-lead.mdc does not stop on Task rejection")
  if (!rule.includes("does not depend on file type"))
    fail("dispatch", "rules/kru-lead.mdc does not keep the closed list independent of file type")
  if (!rule.includes("Lead-owned"))
    fail("dispatch", "rules/kru-lead.mdc does not list lead-owned work")
  if (!rule.includes("a reviewer's exact replacement after the loop closed"))
    fail("dispatch", "rules/kru-lead.mdc lacks the loop-closed timing on a reviewer's exact replacement")
  if (rule.includes("Anything not on that list is dispatched"))
    fail("dispatch", "rules/kru-lead.mdc says anything off the inline list is dispatched, which includes lead-owned work")
  const ownedStart = lead.indexOf("**Lead-owned work is not that list")
  const ownedEnd = lead.indexOf("\n\n**No covering seat:")
  const owned = ownedStart >= 0 && ownedEnd > ownedStart ? lead.slice(ownedStart, ownedEnd) : ""
  if (!owned) fail("dispatch", "skills/kru-lead/SKILL.md has no lead-owned paragraph")
  else if (!rule.includes(owned)) fail("dispatch", "rules/kru-lead.mdc does not match the skill's lead-owned paragraph")
  if (!rule.includes("Do not implement it"))
    fail("dispatch", "rules/kru-lead.mdc still lets a slice with no seat be implemented")
  const passes = read("skills/kru-lead/references/screen-passes.md")
  if (!passes.includes("They are lead-owned"))
    fail("dispatch", "screen-passes.md does not list the user-named passes as lead-owned")
  const gates = read("skills/kru-lead/references/gates.md")
  if (!gates.includes("the comment pass stays lead-owned"))
    fail("dispatch", "gates.md does not list the comment pass as lead-owned")
  if (!gates.includes("a scoped test-count check is lead-owned"))
    fail("dispatch", "gates.md does not list the scoped test-count check as lead-owned")
  if (read("references/routing.md").includes("the general path only on their say-so"))
    fail("dispatch", "routing.md still sends an uncovered slice down the general path")
  if (read("SOURCES.md").includes("use the general path"))
    fail("dispatch", "SOURCES.md still sends an uncovered stack down the general path")
  // `spawn \`kru-<seat>\`` is one shape. The screen passes name the same seats
  // as `— \`kru-accessibility-reviewer\`` and `and \`kru-visual-reviewer\``.
  // Every backtick kru-* name in gates.md has to be a real agent, and a bare
  // seat in backticks is the Task name with the prefix dropped.
  const named = new Set()
  for (const m of gates.matchAll(/`kru-([a-z0-9-]+)`/gi)) named.add(m[1])
  for (const seat of ["accessibility-reviewer", "visual-reviewer"]) {
    if (!named.has(seat)) fail("dispatch", `gates.md does not name kru-${seat}`)
  }
  for (const seat of named) {
    if (!seats.includes(seat)) fail("dispatch", `gates.md names kru-${seat}, which has no agents/${seat}.md`)
  }
  for (const seat of seats) {
    if (new RegExp("(?<!kru-)`" + seat + "`").test(gates))
      fail("dispatch", `gates.md names \`${seat}\`; the Task subagent_type is kru-${seat}`)
  }
  const dispatchDoc = /^(skills|references|rules)\//
  const skipDispatchDoc = new Set(
    execFileSync("node", ["scripts/port.mjs", "--list-dispatch-seat-prefix-skip"], { cwd: ROOT, encoding: "utf8" })
      .trim()
      .split("\n")
      .filter(Boolean),
  )
  for (const f of files) {
    if (!dispatchDoc.test(f) || skipDispatchDoc.has(f)) continue
    const body = read(f)
    for (const seat of seats) {
      const plain = f === "skills/kru-roster/shared-blocks.md"
        ? body.split(/(```[\s\S]*?```)/g).filter((_, i) => i % 2 === 0).join("")
        : body
      if (new RegExp("(?<!kru-)`" + seat.replace(/-/g, "\\-") + "`").test(plain))
        fail("dispatch", `${f} names \`${seat}\`; the Task subagent_type is kru-${seat}`)
    }
  }
  for (const seat of seats) {
    const fm = agentFm.get(seat)
    const description = String(fm?.description ?? "")
    if (!description.includes("Use proactively")) fail("dispatch", `agents/${seat}.md description is missing "Use proactively"`)
    if (!description.includes(`kru-${seat}`)) fail("dispatch", `agents/${seat}.md description does not name kru-${seat}`)
  }
  const roster = read("ROSTER.md")
  if (!roster.includes("Task `subagent_type` is `kru-<seat>`"))
    fail("dispatch", "ROSTER.md does not say the Task subagent_type is kru-<seat>")
}

// --- leftover claude-code vocabulary --------------------------------------------------------------------
// files that name claude's surfaces on purpose: the fork's own docs and
// checks, and the update skill's claude release ledger (PORTING.md → Known gaps)
const ABOUT_CLAUDE = /^(PORTING\.md|MODELS\.md|scripts\/(port\.mjs|verify\.sh|verify-tree\.mjs|privacy-scan\.mjs)|skills\/kru-update\/(claude|reviewed)\.md)$/
const SCANS = [
  { name: "CLAUDE_PLUGIN_ROOT", re: /CLAUDE_PLUGIN_ROOT/ },
  { name: ".claude-plugin", re: /\.claude-plugin/ },
  { name: "claude plugin install text", re: /claude plugin (install|marketplace|enable)|\/plugin (install|marketplace|enable)\b/ },
  { name: "/kru: command", re: /\/kru:[a-z]/ },
  { name: "kru: name", re: /\bkru:[a-z]/ },
  { name: "mcp__ tool id", re: /\bmcp__/ },
  { name: "claude task tools", re: /\b(TaskCreate|TaskUpdate|TaskList|SendMessage)\b/ },
  { name: "CLAUDE_CODE_ env", re: /\bCLAUDE_CODE_[A-Z_]+/ },
]
for (const f of files) {
  if (!/\.(md|mdc|sh|mjs|json|ya?ml|txt)$/.test(f) || ABOUT_CLAUDE.test(f)) continue
  read(f).split("\n").forEach((line, i) => {
    for (const s of SCANS) if (s.re.test(line)) fail("claude leftovers", `${f}:${i + 1}: ${s.name} — ${line.trim().slice(0, 110)}`)
  })
}
// claude's event names and matchers in hooks.json are the hooks check's above;
// upstream's hooks still answer hooks/cursor-hook.sh in claude's shape inside
// the plugin, which the adapter translates, so those lines are not leftovers

// --- report -----------------------------------------------------------------------------------------------
const CHECKS = ["manifest", "frontmatter", "json/yaml", "hooks", "version", "seats", "dispatch", "claude leftovers"]
const detail = {
  manifest: `${manifest.name}@${manifest.version} · marketplace.json · logo ${manifest.logo}`,
  frontmatter: `${agentFiles.length} agents · ${skillFiles.length} skills · ${ruleFiles.length} rules · ${commandFiles.length} commands`,
  "json/yaml": `${files.filter((f) => /\.(json|ya?ml)$/.test(f)).length} files`,
  hooks: `${Object.values(hooks.hooks ?? {}).flat().length} hooks on ${Object.keys(hooks.hooks ?? {}).length} events`,
  version: read("VERSION").trim(),
  seats: `${seats.length} seats · ${READ_ONLY.length} readonly · ${STORE_WRITERS.length} store writers guarded`,
  dispatch: "Task subagent_type kru-<seat> · closed inline list · Use proactively",
  "claude leftovers": `${SCANS.length} patterns`,
}
for (const n of notes) console.log(`note ${n}`)
for (const c of CHECKS) {
  const hits = results.filter(([k]) => k === c)
  console.log(`${hits.length ? "FAIL" : "ok  "} ${c.padEnd(17)} ${hits.length ? `${hits.length} problem(s)` : detail[c]}`)
  for (const [, msg] of hits.slice(0, Number(process.env.VERIFY_SHOW ?? 25))) console.log(`       ${msg}`)
  if (hits.length > 25) console.log(`       … ${hits.length - 25} more`)
}
process.exit(results.length ? 1 : 0)
