#!/bin/bash
# the fork edits (scripts/cursor/edits.mjs) against a fresh upstream tree:
# (1) every edit applies and the result is the checked-in tree, (2) a second
# port changes nothing, (3) upstream rewording an edited passage fails the
# port by name instead of silently dropping the edit.
# run: bash scripts/port-edits.test.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
pass=0 fail=0
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: %s\n' "$name"; fi; }

base=""
for c in $(git -C "$repo" rev-list HEAD); do git -C "$repo" cat-file -e "$c:scripts/port.mjs" 2>/dev/null || { base=$c; break; }; done
[ -n "$base" ] || { echo "port-edits.test: no upstream commit in history (fetch-depth 0)"; exit 1; }

fresh() { # <dir> — upstream at the base commit, the fork-owned files over it
  mkdir -p "$1" && git -C "$repo" archive "$base" | tar -x -C "$1"
  (cd "$repo" && node scripts/port.mjs --list-fork-owned) | while IFS= read -r f; do
    mkdir -p "$1/$(dirname "$f")" && cp -p "$repo/$f" "$1/$f"
  done
}

n=$(cd "$repo" && node -e 'import("./scripts/cursor/edits.mjs").then((m) => console.log(m.EDITS.length))')
fresh "$t/a"
check "a fresh port applies every edit" bash -c 'cd "$1" && node scripts/port.mjs --quiet' _ "$t/a"
check "…and a second port changes nothing" bash -c 'cd "$1" && node scripts/port.mjs --check --quiet' _ "$t/a"
first=$(cd "$repo" && node -e 'import("./scripts/cursor/edits.mjs").then((m) => { const e = m.EDITS.find((e) => !e.file.startsWith("skills/")) ?? m.EDITS[0]; if (e) console.log(JSON.stringify(e)) })')
if [ -n "$first" ]; then
  file=$(jq -r .file <<<"$first")
  check "…leaving the edited passage in $file" bash -c 'grep -qF -- "$(jq -r .after <<<"$2" | head -n 1)" "$1/$3"' _ "$t/a" "$first" "$file"
  # upstream rewords the passage the edit targets (upstream's path: skills/<name>)
  fresh "$t/b"
  up=$(sed -E 's#^skills/kru-#skills/#' <<<"$file")
  word=$(jq -r .before <<<"$first" | grep -oE '[A-Za-z]{5,}' | head -n 1)
  sed -i "s/$word/${word}Reworded/g" "$t/b/$up"
  out=$(cd "$t/b" && node scripts/port.mjs --quiet 2>&1); code=$?
  check "upstream rewording an edited passage fails the port" test "$code" != 0
  check "…naming the edit" grep -q "fork edit no longer matches $file" <<<"$out"
fi
printf '%d passed, %d failed (%s edits)\n' "$pass" "$fail" "$n"
[ "$fail" -eq 0 ]
