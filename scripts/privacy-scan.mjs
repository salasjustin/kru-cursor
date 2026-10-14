#!/usr/bin/env node
// the privacy gate: nothing in the tree — or, with --history, in any commit on
// any ref — that would leak a secret, a private email, a path off the author's
// machine, client data or a private repo's name once the repo is public.
//
//   node scripts/privacy-scan.mjs            the working tree (tracked + untracked, not ignored)
//   node scripts/privacy-scan.mjs --history  every commit's patch and author/committer email (git log -p --all)
//
// the tree has no exceptions beyond the generic ones below (reserved example
// domains, placeholder secrets that say they are placeholders, the vendored
// cloudflare sandbox docs' container path). history is upstream kru's public
// history plus this fork's commits: a hit there that was reviewed is listed in
// HISTORY_REVIEWED with the commit, the file and why it stays — anything else
// fails. PORTING.md → Privacy carries the review.
// a fixed roster of case-sensitive whole words, plus one phrase, is checked on
// the tree only. history keeps the commits that introduced them. the words are
// code points so this file does not spell them.
// a fixed roster of case-sensitive whole words, plus one phrase, is checked on
// the tree only. history keeps the commits that introduced them. the words are
// code points so this file does not spell them.
// gitleaks, when it is on PATH, runs too (detect over the tree / git log).
import { execFileSync, spawnSync } from "node:child_process"
import { createHash } from "node:crypto"
import { readFileSync, mkdtempSync, rmSync, realpathSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { EMAIL_SOURCE, secretRegs } from "./leak-patterns.mjs"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const HISTORY = process.argv.includes("--history")
const git = (...a) => execFileSync("git", a, { cwd: ROOT, encoding: "utf8", maxBuffer: 1 << 30 })

// --- what counts as a leak --------------------------------------------------
export const PATTERNS = [
  // credentials — the same objects scripts/leak-patterns.mjs exports
  ...secretRegs(),
  // people and machines. mail uses that module's source too; the allow-list
  // below is this scan's, not the tracker's.
  { id: "email", re: new RegExp(EMAIL_SOURCE, "g"), each: true },
  { id: "internal-path", re: /\/home\/box\b|\/cursor\/stores\b|(^|[^\w.-])\/workspace\b/ },
  // a private repo addressed by owner: any of the author's repos but this one,
  // and the store repo by its name (the script it shares a name with is public)
  { id: "private-repo", re: /\bsalasjustin\/(?!kru-cursor\b)[\w.-]+|\b[\w-]+\/kru-store(?![\w.-])/i },
]

// client names and private repo names, matched by hash: a public scanner that
// spelled them out would publish what it exists to keep out. a line's words are
// lower-cased to their letters and digits, alone and joined with the next word
// ("Some Name" and "some-name" both read "somename"), and each candidate's
// sha-256 prefix is looked up here. adding a term: printf '%s' term | sha256sum.
const HASHED = new Map([
  ["5463fd68df01bf6c", "client-data"],
  ["a6882c1b0053f94e", "client-data"],
  ["a107577b02bcd33d", "client-data"],
  ["c588d8717b7c6a89", "private-repo"],
  ["c6858b85615ed647", "private-repo"],
])
const HASHED_LENGTHS = new Set([3, 7, 12, 13, 20])
const sha = (w) => createHash("sha256").update(w).digest("hex").slice(0, 16)
function hashedHits(line) {
  const out = []
  const words = line.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean)
  for (let i = 0; i < words.length; i++) {
    for (const w of words[i + 1] ? [words[i], words[i] + words[i + 1]] : [words[i]]) {
      if (!HASHED_LENGTHS.has(w.length)) continue
      const id = HASHED.get(sha(w))
      if (id) out.push({ id, value: `<term ${sha(w).slice(0, 6)}>` })
    }
  }
  return out
}

// reserved for documentation (rfc 2606 / 6761), github's and anthropic's
// no-reply senders, the placeholder addresses the vendored and first-party
// docs use in examples — each one a made-up mailbox, listed exactly — and
// known bot identities that author commits on this fork.
const EMAIL_OK = (e) =>
  /@([a-z0-9-]+\.)*example(\.(com|org|net))?$/i.test(e) ||
  /\.(invalid|test|localhost)$/i.test(e) ||
  /@users\.noreply\.github\.com$/i.test(e) ||
  /^noreply@(github|anthropic)\.com$/i.test(e) ||
  PLACEHOLDER_EMAILS.has(e.toLowerCase()) ||
  BOT_EMAILS.has(e.toLowerCase())
const BOT_EMAILS = new Set(["cursoragent@cursor.com"])
const PLACEHOLDER_EMAILS = new Set(
  ("+@mcp.tool a@a.com a@ex.com b@ex.com noreply@ex.com alice@company.com name@company.com you@company.com " +
    "alice@sender.com bounce@sender.com archive@corp.com billing@corp.com general@corp.com inbox@corp.com " +
    "oncall@corp.com support@corp.com trusted@corp.com noreply@yourdomain.com reply@yourdomain.com " +
    "sales@yourdomain.com support@yourdomain.com you@yourdomain.com verified@destination.com " +
    "neil@x.com x@y.zz your@email.com").split(" "),
)

// a secret-shaped value that announces itself as a placeholder — judged on the
// matched value alone, never the line around it, so a real key beside a
// `${VAR}` or an `example` on the same line still fails
const PLACEHOLDER_SECRET = /your[_-]?|xxx|example|abc123|<[^>]*>|\$\{|\.\.\.|dummy|placeholder|test_|fake/i

// per-path exceptions, for the tree and history alike
const PATH_OK = [
  // cloudflare's sandbox sdk runs code in a container whose working dir is /workspace
  { id: "internal-path", path: /^skills\/(kru-)?cloudflare\/references\/sandbox\// },
  // this scanner names what it scans for, and PORTING.md reports what it found
  { id: "*", path: /^(scripts\/privacy-scan\.mjs|scripts\/leak-patterns\.mjs|scripts\/guard-text\.mjs|PORTING\.md)$/ },
  // the tracker test spells the probes guard_text must refuse
  { id: "*", path: /^scripts\/kru-tracker\.test\.sh$/ },
  // the store-resolver test pins a fictional owner's store repo (`acme/kru-store`)
  { id: "private-repo", path: /^scripts\/kru-store\.test\.sh$/, line: /acme\/kru-store/ },
]

// history hits reviewed and kept: upstream kru's public history, unchanged in
// this fork so `git merge upstream/main` keeps working (PORTING.md → Privacy).
// each entry: the pattern id, the commit (abbrev ok), the file, the reason.
const HISTORY_REVIEWED = [
  { id: "client-data", commit: "82976d23", file: /^evals\/homepage-copy\/prompt\.md$/, why: "upstream eval prompt naming a public nonprofit platform as the example client; evals/ is dropped from this tree" },
  { id: "client-data", commit: "b10943af", file: /^(skills\/lead\/)?references\/lossless-doc-compaction\.md$/, why: "upstream reference naming the public repo its procedure was exercised on; rewritten in this tree by scripts/port.mjs" },
  { id: "assignment", commit: "b10943af", file: /^skills\/cloudflare\/references\//, why: "upstream cloudflare docs showing example CLI flags and catalog tokens, not a credential this repo holds; gone from this tree" },
]

function allowed(id, path, line, value) {
  if (id === "email" && EMAIL_OK(value)) return true
  if (["openai/anthropic-key", "stripe-live-key", "bearer-token", "github-token"].includes(id) && PLACEHOLDER_SECRET.test(value)) return true
  return PATH_OK.some((p) => (p.id === "*" || p.id === id) && p.path.test(path) && (!p.line || p.line.test(line)))
}

// code points, not letters: a tree grep for the roster stays at zero.
const ROSTER_WORDS = [
  [75, 97, 105],
  [79, 116, 116, 111],
  [86, 101, 114, 97],
  [73, 118, 121],
  [84, 97, 108, 105],
  [74, 117, 110, 111],
  [78, 111, 114, 97],
  [82, 104, 101, 97],
  [74, 117, 115, 116, 105, 110],
].map((codes) => String.fromCharCode(...codes))
const ROSTER_PHRASE = String.fromCharCode(71, 114, 111, 107, 32, 66, 111, 116, 32, 80, 77)

export function rosterHits(line, { history = false } = {}) {
  if (history) return []
  const out = []
  for (const w of ROSTER_WORDS) {
    if (new RegExp(`\\b${w}\\b`).test(line)) out.push({ id: "team-name", value: w })
  }
  if (line.includes(ROSTER_PHRASE)) out.push({ id: "team-name", value: ROSTER_PHRASE })
  return out
}
export { ROSTER_WORDS, ROSTER_PHRASE }

function scanLine(path, line, hits, where) {
  for (const h of hashedHits(line)) if (!allowed(h.id, path, line, h.value)) hits.push({ ...where, id: h.id, path, value: h.value, line })
  for (const p of PATTERNS) {
    if (p.each) {
      for (const m of line.matchAll(p.re)) if (!allowed(p.id, path, line, m[0])) hits.push({ ...where, id: p.id, path, value: m[0], line })
    } else {
      const m = line.match(p.re)
      if (m && !allowed(p.id, path, line, m[0])) hits.push({ ...where, id: p.id, path, value: m[0], line })
    }
  }
  for (const h of rosterHits(line, { history: HISTORY })) {
    if (!allowed(h.id, path, line, h.value)) hits.push({ ...where, id: h.id, path, value: h.value, line })
  }
}

function main() {
const hits = []
if (!HISTORY) {
  const files = git("ls-files", "-co", "--exclude-standard", "-z").split("\0").filter(Boolean)
  for (const f of files) {
    let text
    try {
      text = readFileSync(join(ROOT, f), "utf8")
    } catch {
      continue
    }
    if (text.includes("\0")) continue // binary
    text.split("\n").forEach((line, i) => scanLine(f, line, hits, { lineNo: i + 1 }))
  }
} else {
  // commit metadata: every author and committer email on every ref
  for (const row of git("log", "--all", "--format=%H %ae %ce").trim().split("\n")) {
    const [commit, ae, ce] = row.split(" ")
    for (const e of [ae, ce]) if (e && !EMAIL_OK(e)) hits.push({ commit, id: "email", path: "(commit metadata)", value: e, line: row })
  }
  // every added line of every patch: all content enters history as an addition
  // (the root commit adds everything), so a removal shows nothing new
  // merges show their first-parent diff, so content added while resolving a
  // `git merge upstream/main` conflict is scanned too
  const log = git("log", "-p", "--all", "--no-color", "--diff-merges=first-parent", "--format=COMMIT %H")
  let commit = "", file = "", inHunk = false
  for (const line of log.split("\n")) {
    if (line.startsWith("COMMIT ")) { commit = line.slice(7); inHunk = false; continue }
    if (line.startsWith("diff --git ")) { file = line.replace(/^diff --git a\/(.*) b\/.*$/, "$1"); inHunk = false; continue }
    // a file header's +++/--- lines come before the first hunk; inside one, an
    // added line that itself starts with "++" is content
    if (line.startsWith("@@")) { inHunk = true; continue }
    if (!inHunk || !line.startsWith("+")) continue
    scanLine(file, line.slice(1), hits, { commit })
  }
}

// --- gitleaks, when installed ---------------------------------------------------
let gitleaks = "not installed"
const gl = spawnSync("gitleaks", ["version"], { encoding: "utf8" })
if (gl.status === 0) {
  const dir = mkdtempSync(join(tmpdir(), "kru-gitleaks-"))
  const report = join(dir, "report.json")
  // unredacted: the report lives in a temp dir deleted below, and a redacted
  // secret can't be told from a placeholder
  const args = [HISTORY ? "git" : "dir", "--no-banner", "--exit-code", "0", "--report-format", "json", "--report-path", report, "."]
  const r = spawnSync("gitleaks", args, { cwd: ROOT, encoding: "utf8", maxBuffer: 1 << 28 })
  let found
  try { found = JSON.parse(readFileSync(report, "utf8")) } catch (err) {
    console.log(`FAIL: gitleaks ran but left no readable report (exit ${r.status}): ${String(err.message).split("\n")[0]}`)
    process.exit(1)
  } finally { rmSync(dir, { recursive: true, force: true }) }
  // a placeholder is judged on the secret gitleaks extracted, never the line
  const real = found.filter((f) => !PLACEHOLDER_SECRET.test(f.Secret ?? ""))
  gitleaks = `${gl.stdout.trim()}: ${found.length} finding(s), ${found.length - real.length} placeholder(s)`
  for (const f of real) hits.push({ commit: f.Commit, id: `gitleaks:${f.RuleID}`, path: f.File, value: "REDACTED", line: `line ${f.StartLine}` })
}

// --- report ---------------------------------------------------------------------
const reviewed = []
const open = []
for (const h of hits) {
  const r = HISTORY && HISTORY_REVIEWED.find((x) => x.id === h.id && x.file.test(h.path) && (x.commit === "*" || h.commit?.startsWith(x.commit)))
  ;(r ? reviewed : open).push(r ? { ...h, why: r.why } : h)
}
const short = (h) => `${h.commit ? h.commit.slice(0, 8) + " " : ""}${h.path}${h.lineNo ? ":" + h.lineNo : ""}  [${h.id}] ${h.value}`
console.log(`privacy scan (${HISTORY ? "history: every commit on every ref" : "tree"}) — gitleaks ${gitleaks}`)
if (reviewed.length) {
  const seen = new Set()
  console.log(`reviewed and kept (${reviewed.length} line(s)):`)
  for (const h of reviewed) {
    const k = `${h.commit?.slice(0, 8)} ${h.path} ${h.id}`
    if (seen.has(k)) continue
    seen.add(k)
    console.log(`  ~ ${short(h)} — ${h.why}`)
  }
}
if (open.length) {
  console.log(`FAIL: ${open.length} hit(s):`)
  for (const h of open.slice(0, 60)) console.log(`  ! ${short(h)}\n      ${h.line.trim().slice(0, 160)}`)
  process.exit(1)
}
console.log("clean")
}

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) main()
