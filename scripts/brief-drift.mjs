#!/usr/bin/env node
// drift between one effort's brief and its tracker issues.
// the brief stores issue ids in ## Tracker. an issue links back when its body
// contains the brief path (plan/<effort>/brief.md). status is the issue's
// state field — open, done, or canceled — and is never read from the brief.
// stdout is a short report. this command does not write to the tracker.
// a path sent to the tracker goes through kru-tracker.sh (list-effort), which
// runs the same outbound guard as every other tracker field.
//
//   node scripts/brief-drift.mjs --path plan/<effort>/brief.md --brief <file> --issues <json|->
//
// issues JSON is an array of {id, title, body, url, state}. state completed or
// closed counts as done. a canceled issue is kept: unlisted, it is (b), and
// it is never (c). two objects with one id keep the one whose body links.

import { readFileSync } from "node:fs"

const PATH_RE = /^plan\/[a-z0-9]+(?:-[a-z0-9]+)*\/brief\.md$/

function fail(message) {
  process.stderr.write(`brief drift: ${message}\n`)
  process.exit(1)
}

function arg(name) {
  const i = process.argv.indexOf(name)
  if (i === -1 || process.argv[i + 1] == null || process.argv[i + 1].startsWith("--")) fail(`need ${name}`)
  return process.argv[i + 1]
}

const known = new Set(["--path", "--brief", "--issues"])
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i]
  if (!a.startsWith("--")) continue
  if (!known.has(a)) fail(`unknown argument: ${a}`)
  i++
}

const briefPath = arg("--path")
const briefFile = arg("--brief")
const issuesFile = arg("--issues")
if (!PATH_RE.test(briefPath)) fail("a brief path is plan/<effort>/brief.md")

let brief
try {
  brief = readFileSync(briefFile, "utf8")
} catch {
  fail("could not read the brief")
}

let raw
try {
  raw = issuesFile === "-" ? readFileSync(0, "utf8") : readFileSync(issuesFile, "utf8")
} catch {
  fail("could not read the issues")
}
let issues
try {
  issues = JSON.parse(raw)
} catch {
  fail("issues JSON must be an array")
}
if (!Array.isArray(issues)) fail("issues JSON must be an array")

function normId(id) {
  if (id == null) return null
  const s = String(id).trim()
  if (/^#?\d+$/.test(s)) {
    const n = String(Number(s.replace(/^#/, "")))
    if (n === "NaN") return null
    return { key: `gh:${n}`, display: `#${n}` }
  }
  const lin = s.match(/^[A-Za-z][A-Za-z0-9]*-\d+$/)
  if (!lin) return null
  const up = s.toUpperCase()
  return { key: `lin:${up}`, display: up }
}

function normState(state) {
  const v = String(state ?? "").trim().toLowerCase()
  if (v === "done" || v === "completed" || v === "closed") return "done"
  if (v === "canceled" || v === "cancelled") return "canceled"
  return "open"
}

function links(body, path) {
  const b = String(body ?? "")
  let from = 0
  while (from <= b.length) {
    const at = b.indexOf(path, from)
    if (at === -1) return false
    const before = at === 0 ? "" : b[at - 1]
    const after = b.slice(at + path.length)
    // a following ".bak" is a different path; a sentence period still counts
    const beforeOk = before === "" || !/[A-Za-z0-9_/]/.test(before)
    const afterOk = after === "" || (/^[^A-Za-z0-9_/]/.test(after) && !/^\.[A-Za-z0-9]/.test(after))
    if (beforeOk && afterOk) return true
    from = at + 1
  }
  return false
}

function trackerItems(markdown) {
  const items = []
  let inSection = false
  let fence = false
  for (const rawLine of String(markdown).replace(/\r\n/g, "\n").split("\n")) {
    const line = rawLine.replace(/\r$/, "")
    if (/^```/.test(line)) {
      fence = !fence
      continue
    }
    if (fence) continue
    if (/^##\s+Tracker\s*$/.test(line)) {
      inSection = true
      continue
    }
    if (inSection && /^##\s+/.test(line)) break
    if (!inSection) continue
    const box = line.match(/^- \[[ xX]\]\s+(.*)$/)
    const plain = line.match(/^- (.*)$/)
    const hit = box || plain
    if (!hit) continue
    items.push(parseItem(hit[1]))
  }
  return items
}

function parseItem(raw) {
  let text = String(raw).trim()
  text = text.replace(/(`?(?:#\d+|[A-Za-z][A-Za-z0-9]*-\d+)`?)\s+`?(?:done|open|closed|todo|completed|canceled|cancelled)`?\s*$/i, "$1").trim()
  const idMatch = text.match(/`?(#\d+|[A-Za-z][A-Za-z0-9]*-\d+)`?$/i)
  if (!idMatch) return { text, id: null }
  const id = normId(idMatch[0].replace(/`/g, ""))
  if (!id) return { text, id: null }
  const label = text.slice(0, idMatch.index).replace(/[\s—–-]+$/u, "").trim()
  return { text: label, id }
}

function sortIds(displays) {
  return [...displays].sort((a, b) => {
    const ag = a.startsWith("#")
    const bg = b.startsWith("#")
    if (ag && bg) return Number(a.slice(1)) - Number(b.slice(1))
    if (ag !== bg) return ag ? -1 : 1
    return a.localeCompare(b)
  })
}

const listed = []
const listedSet = new Set()
const planned = []
for (const item of trackerItems(brief)) {
  if (item.id) {
    if (!listedSet.has(item.id.key)) {
      listedSet.add(item.id.key)
      listed.push(item.id)
    }
  } else if (item.text) planned.push(item.text)
}

const byKey = new Map()
for (const issue of issues) {
  if (!issue || typeof issue !== "object") continue
  const id = normId(issue.id)
  if (!id) continue
  const prev = byKey.get(id.key)
  if (!prev || (!links(prev.body, briefPath) && links(issue.body, briefPath))) byKey.set(id.key, issue)
}

const missing = []
for (const id of listed) {
  const issue = byKey.get(id.key)
  if (!issue) missing.push(`${id.display} (missing)`)
  else if (!links(issue.body, briefPath)) missing.push(`${id.display} (not linked)`)
}

const unlisted = []
const doneUnplanned = []
for (const issue of byKey.values()) {
  const id = normId(issue.id)
  if (!id || listedSet.has(id.key) || !links(issue.body, briefPath)) continue
  unlisted.push(id.display)
  if (normState(issue.state) === "done") doneUnplanned.push(id.display)
}

const lines = [briefPath]
if (missing.length) lines.push(`(a) listed, missing or not linked: ${missing.join(", ")}`)
if (unlisted.length) lines.push(`(b) linked, not listed: ${sortIds(unlisted).join(", ")}`)
if (doneUnplanned.length) lines.push(`(c) done, never planned: ${sortIds(doneUnplanned).join(", ")}`)
if (planned.length) lines.push(`(d) planned, no issue: ${planned.join("; ")}`)
if (lines.length === 1) lines.push("no drift")
process.stdout.write(`${lines.join("\n")}\n`)
