#!/bin/bash
# every static check this fork has, in one run — what CI runs on each pull
# request and push to main, and what to run before a commit. runs every check,
# then exits non-zero when any failed.
# run: bash scripts/verify.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo" || exit 1

names=() states=()
record() { names+=("$1"); states+=("$2"); }

# step <name> <command...> — runs it, keeps the tail, and the whole output on a failure
step() {
  local name=$1; shift
  local out
  printf '\n== %s\n' "$name"
  if out=$("$@" 2>&1); then
    printf '%s\n' "$out" | tail -n 8
    record "$name" ok
  else
    printf '%s\n' "$out" | tail -n 60
    record "$name" FAIL
  fi
}

# --- prerequisites ------------------------------------------------------------
missing=""
for c in node jq git bash; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
[ -n "$missing" ] && { echo "verify: missing on PATH:$missing" >&2; exit 1; }
node_major=$(node -p 'process.versions.node.split(".")[0]')
[ "$node_major" -ge 22 ] || { echo "verify: node 22+ required, found $(node --version)" >&2; exit 1; }
python3 -c 'import yaml' 2>/dev/null || command -v uv >/dev/null 2>&1 ||
  { echo "verify: need python3 with PyYAML (or uv) for the frontmatter parse" >&2; exit 1; }

syntax() {
  local f rc=0
  while IFS= read -r f; do bash -n "$f" || { echo "bash -n: $f"; rc=1; }; done < <(git ls-files -co --exclude-standard '*.sh')
  while IFS= read -r f; do node --check "$f" || { echo "node --check: $f"; rc=1; }; done < <(git ls-files -co --exclude-standard '*.mjs')
  echo "$(git ls-files -co --exclude-standard '*.sh' | wc -l | tr -d ' ') shell + $(git ls-files -co --exclude-standard '*.mjs' | wc -l | tr -d ' ') node scripts parse"
  return $rc
}

# the port is a function of upstream: the newest upstream commit in history,
# with the fork-owned files laid over it, ported once, has to be this tree
# byte for byte. that is what makes `git merge upstream/main && node
# scripts/port.mjs` a safe loop, and it catches a hand edit to a ported file.
fresh_port() {
  local base="" c tmp rc=0
  for c in $(git rev-list HEAD 2>/dev/null); do
    git cat-file -e "$c:scripts/port.mjs" 2>/dev/null || { base=$c; break; }
  done
  [ -n "$base" ] || { echo "no upstream commit in this clone's history (CI: checkout with fetch-depth 0)"; return 1; }
  tmp=$(mktemp -d)
  git archive "$base" | tar -x -C "$tmp" || { rm -rf "$tmp"; return 1; }
  # the fork owns .github/ outright; upstream's is not taken (scripts/sync-upstream.sh)
  rm -rf "$tmp/.github"
  while IFS= read -r f; do
    mkdir -p "$tmp/$(dirname "$f")" && cp -p "$f" "$tmp/$f"
  done < <(node scripts/port.mjs --list-fork-owned)
  (cd "$tmp" && node scripts/port.mjs --quiet) || { echo "the port failed on a fresh upstream tree"; rm -rf "$tmp"; return 1; }
  # compare the file sets and every file's bytes
  diff <(git ls-files -co --exclude-standard | sort) <(cd "$tmp" && find . -type f ! -path './.git/*' | sed 's#^\./##' | sort) > "$tmp.list" ||
    { echo "file sets differ (< this tree, > fresh port):"; head -40 "$tmp.list"; rc=1; }
  while IFS= read -r f; do
    [ -f "$tmp/$f" ] && ! cmp -s "$f" "$tmp/$f" && { echo "differs from a fresh port: $f"; rc=1; }
  done < <(git ls-files -co --exclude-standard)
  echo "fresh port of upstream ${base:0:8} + $(node scripts/port.mjs --list-fork-owned | wc -l | tr -d ' ') fork-owned files reproduces the tree"
  rm -rf "$tmp" "$tmp.list"
  return $rc
}

# every seat runs on an id port.mjs confirmed off cursor's docs (MODELS.md);
# a pick that lost its confirmation falls back in the port, never silently here
seat_models() {
  local f m confirmed rc=0 all=""
  confirmed=$(node scripts/port.mjs --list-models) || return 1
  for f in agents/*.md; do
    m=$(sed -n '2,/^---$/s/^model: *//p' "$f")
    all="$all${m%%\[*}"$'\n'
    grep -qxF "${m%%\[*}" <<<"$confirmed" || { echo "$f: model '$m' is not in scripts/port.mjs CONFIRMED_MODELS"; rc=1; }
  done
  printf '%s' "$all" | sort | uniq -c | sort -rn | awk '{ printf "%s%s×%s", s, $1, $2; s = " · " } END { print "" }'
  return $rc
}

run_tests() {
  local t rc=0
  for t in hooks/*.test.sh scripts/*.test.sh; do
    printf '%s: ' "$t"
    bash "$t" > "/tmp/kru-verify-test.$$" 2>&1 && tail -n 1 "/tmp/kru-verify-test.$$" || { echo FAIL; cat "/tmp/kru-verify-test.$$"; rc=1; }
  done
  rm -f "/tmp/kru-verify-test.$$"
  return $rc
}

step "port normalized (port.mjs --check)" node scripts/port.mjs --check --quiet
step "PORTING.md cites every FORK_OWNED file" node scripts/port.mjs --check-porting-hand-owned
step "fresh port of upstream reproduces the tree" fresh_port
step "script syntax (bash -n, node --check)" syntax
step "roster audit (scripts/audit.sh)" bash scripts/audit.sh
step "seat models are confirmed cursor ids (port.mjs CONFIRMED_MODELS)" seat_models
step "hook + script tests (*.test.sh, cursor-shaped)" run_tests
step "asset generator: xai backend (node --test, mocked fetch)" node --test scripts/asset/xai.test.mjs
step "tree: manifest, frontmatter, hooks.json, versions, seats, leftovers" node scripts/verify-tree.mjs
step "privacy: tree" node scripts/privacy-scan.mjs
step "privacy: history (git log -p --all)" node scripts/privacy-scan.mjs --history

# --- summary --------------------------------------------------------------------
failed=0
printf '\n== summary\n'
for i in "${!names[@]}"; do
  printf '  %-4s %s\n' "${states[$i]}" "${names[$i]}"
  [ "${states[$i]}" = ok ] || failed=$((failed + 1))
done
if [ "$failed" -gt 0 ]; then
  printf '\nverify: %d of %d checks failed\n' "$failed" "${#names[@]}"
  exit 1
fi
printf '\nverify: all %d checks passed\n' "${#names[@]}"
