#!/bin/bash
# the roster check: case-sensitive whole words, one phrase, and history skips
# them. the words are built inside the scanner, so this file does not spell them.
# run: bash scripts/privacy-scan.test.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo" || exit 1
node --input-type=module <<'EOF'
import assert from "node:assert/strict"
import { rosterHits, ROSTER_WORDS, ROSTER_PHRASE } from "./scripts/privacy-scan.mjs"

assert.ok(ROSTER_WORDS.length >= 8)
assert.ok(ROSTER_PHRASE.includes(" "))
for (const w of ROSTER_WORDS) {
  assert.equal(rosterHits(`see ${w} now`).length, 1)
  assert.equal(rosterHits(w.toLowerCase()).length, 0)
  assert.equal(rosterHits(`xx${w.toLowerCase()}yy`).length, 0)
  assert.equal(rosterHits(`${w}zen`).length, 0)
  assert.equal(rosterHits(`pre${w}`).length, 0)
  assert.equal(rosterHits(`${w}'s`).length, 1)
  assert.equal(rosterHits(`see ${w}`, { history: true }).length, 0)
}
assert.equal(rosterHits(`the ${ROSTER_PHRASE} briefed`).length, 1)
assert.equal(rosterHits(ROSTER_PHRASE.toLowerCase()).length, 0)
assert.equal(rosterHits(`the ${ROSTER_PHRASE}`, { history: true }).length, 0)
assert.equal(rosterHits("salasjustin/kru-cursor").length, 0)
assert.equal(rosterHits("ap-justin/kru").length, 0)
const both = rosterHits(`${ROSTER_WORDS[0]} and ${ROSTER_PHRASE}`)
assert.equal(both.length, 2)
console.log(`roster: ${ROSTER_WORDS.length} words, phrase, history skipped`)
EOF
