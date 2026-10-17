#!/bin/bash
# the fork edits (scripts/cursor/edits.mjs) against a fresh upstream tree:
# (1) every edit applies and the result is the checked-in tree, (2) a second
# port changes nothing, (3) upstream rewording an edited passage fails the
# port by name instead of silently dropping the edit, (4) a drifted
# per-segment anchor fails a normal port before any file is written.
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

check "an edit replaces its passage even when the replacement is already in the file" bash -c 'cd "$1" && node scripts/port.mjs --test-edits' _ "$repo"
check "test credentials heading-aware inject (anchor EOF, tight next heading, idempotent)" bash -c 'cd "$1" && node scripts/port.mjs --test-inject-credentials' _ "$repo"

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

# the per-segment kru_fn_def insert anchors on `[ -z "$seg" ] && continue`
# inside a loop the rule still matches after that line moves. a normal port
# must exit before it writes the hook — or any other file. --check fails on
# the same miss and still writes nothing.
fresh "$t/drift"
hook="$t/drift/hooks/readonly-bash.sh"
grep -qF '[ -z "$seg" ] && continue' "$hook" || { echo "port-edits.test: upstream anchor missing"; exit 1; }
sed -i 's/\[ -z "\$seg" \] && continue/[ -z "$seg" ] \&\& drifted/' "$hook"
grep -qF '[ -z "$seg" ] && drifted' "$hook" || { echo "port-edits.test: anchor drift did not apply"; exit 1; }
manifest() { (cd "$1" && find . -type f ! -path './.git/*' -print0 | sort -z | xargs -0 sha256sum); }
manifest "$t/drift" > "$t/drift-before"
cp -p "$hook" "$t/hook-before"
out=$(cd "$t/drift" && node scripts/port.mjs --quiet 2>&1); code=$?
manifest "$t/drift" > "$t/drift-after"
check "a drifted per-segment anchor fails a normal port" test "$code" != 0
check "…naming the drifted anchor" grep -q 'per-segment kru_fn_def "$seg" was not inserted' <<<"$out"
check "…leaving the hook untouched" cmp -s "$t/hook-before" "$hook"
check "…and writing nothing" cmp -s "$t/drift-before" "$t/drift-after"
out=$(cd "$t/drift" && node scripts/port.mjs --check --quiet 2>&1); code=$?
manifest "$t/drift" > "$t/drift-check"
check "a drifted per-segment anchor fails --check" test "$code" != 0
check "…still naming the drifted anchor" grep -q 'per-segment kru_fn_def "$seg" was not inserted' <<<"$out"
check "…and --check writes nothing" cmp -s "$t/drift-before" "$t/drift-check"

printf '%d passed, %d failed (%s edits)\n' "$pass" "$fail" "$n"
[ "$fail" -eq 0 ]
