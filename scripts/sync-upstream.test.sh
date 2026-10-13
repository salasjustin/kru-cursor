#!/bin/bash
# scripts/sync-upstream.sh against a fake upstream: a copy of this tree as the
# fork, the upstream commit it was ported from as upstream, then (1) nothing
# new → "no changes", (2) a new upstream commit → one merge commit whose tree
# a fresh port reproduces, (3) upstream rewords a line a required rule needs →
# exit 2, a report, nothing committed. run: bash scripts/sync-upstream.test.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
pass=0 fail=0
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: %s\n' "$name"; fi; }
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset GITHUB_OUTPUT

base=""
for c in $(git -C "$repo" rev-list HEAD); do git -C "$repo" cat-file -e "$c:scripts/port.mjs" 2>/dev/null || { base=$c; break; }; done
[ -n "$base" ] || { echo "sync-upstream.test: no upstream commit in history (fetch-depth 0)"; exit 1; }

# the fork: this clone's history plus the working tree as one commit, so the
# script and rules under test are the ones on disk
git clone -q "$repo" "$t/fork"
(cd "$repo" && git ls-files -co --exclude-standard -z | xargs -0 -I{} cp --parents {} "$t/fork/") 2>/dev/null
(cd "$t/fork" && git add -A && git commit -q -m "test: working tree" --allow-empty)
# upstream: the commit the fork was ported from
git init -q "$t/up" && git -C "$t/up" fetch -q "$repo" "$base" && git -C "$t/up" checkout -q -b main FETCH_HEAD
export KRU_UPSTREAM_URL="$t/up" KRU_UPSTREAM_REF=main KRU_SYNC_REPORT="$t/report.md"

out=$(cd "$t/fork" && bash scripts/sync-upstream.sh 2>&1)
check "nothing new upstream: no changes" grep -q '^no changes' <<<"$out"

# (2) upstream edits a seat's prose and adds a skill
printf '\nA line upstream added.\n' >> "$t/up/agents/code-reviewer.md"
mkdir -p "$t/up/skills/sync-probe"
printf -- '---\nname: sync-probe\ndescription: A probe skill. Use when testing the fork sync.\n---\n\nRead skills/lead/SKILL.md first.\n' > "$t/up/skills/sync-probe/SKILL.md"
git -C "$t/up" add -A && git -C "$t/up" commit -q -m "upstream: probe"
head_before=$(git -C "$t/fork" rev-parse HEAD)
dry=$(cd "$t/fork" && bash scripts/sync-upstream.sh --dry-run 2>&1)
check "dry run names the change and commits nothing" bash -c 'grep -q "would change" <<<"$1" && [ "$(git -C "$2" rev-parse HEAD)" = "$3" ]' _ "$dry" "$t/fork" "$head_before"
out=$(cd "$t/fork" && bash scripts/sync-upstream.sh 2>&1)
check "a new upstream commit syncs" grep -q '^synced' <<<"$out"
check "…as one merge commit with upstream as a parent" bash -c '[ "$(git -C "$1" rev-list --parents -n1 HEAD | wc -w)" = 3 ] && git -C "$1" merge-base --is-ancestor "$(git -C "$2" rev-parse HEAD)" HEAD' _ "$t/fork" "$t/up"
check "…the upstream skill lands ported" grep -q 'skills/kru-lead/SKILL.md' "$t/fork/skills/kru-sync-probe/SKILL.md"
check "…the seat edit lands" grep -q 'A line upstream added' "$t/fork/agents/code-reviewer.md"
check "…the tree is normalized" bash -c 'cd "$1" && node scripts/port.mjs --check --quiet' _ "$t/fork"
check "…and verify.sh's fresh port reproduces it" bash -c 'cd "$1" && source <(sed -n "/^fresh_port()/,/^}/p" scripts/verify.sh) && fresh_port' _ "$t/fork"
check "…and the working tree is clean" bash -c '[ -z "$(git -C "$1" status --porcelain)" ]' _ "$t/fork"

# (3) upstream rewords a line a required rule exists for
sed -i 's#"$cwd"/.claude/rules/\*.md#"$cwd"/.claude/rules/*.markdown#' "$t/up/hooks/check-handoff.sh"
git -C "$t/up" commit -q -am "upstream: reword"
head_before=$(git -C "$t/fork" rev-parse HEAD)
(cd "$t/fork" && bash scripts/sync-upstream.sh >/dev/null 2>&1); code=$?
check "a port failure exits 2" test "$code" = 2
check "…commits nothing" bash -c '[ "$(git -C "$1" rev-parse HEAD)" = "$2" ] && [ -z "$(git -C "$1" status --porcelain)" ]' _ "$t/fork" "$head_before"
check "…and the report carries the port's problem" grep -q 'required rule no longer matches' "$t/report.md"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
