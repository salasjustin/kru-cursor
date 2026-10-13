#!/bin/bash
# table tests for store-sync.sh: a bare repo stands in for the store remote,
# and each case runs the hook against a sandboxed HOME the way the harness
# would — `start` at SessionStart, `stop` at every turn end.
# run: bash hooks/store-sync.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
hook="$here/store-sync.sh"

sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=t@t

remote="$sandbox/remote.git"
git init -q --bare -b main "$remote"
seed="$sandbox/seed"
git clone -q "$remote" "$seed" 2>/dev/null
mkdir -p "$seed/management/acme-web/agent-memory/kru-test-writer"
printf 'seed\n' > "$seed/inbox.md"
printf '# memory\n' > "$seed/management/acme-web/agent-memory/kru-test-writer/MEMORY.md"
git -C "$seed" add -A && git -C "$seed" commit -qm seed && git -C "$seed" push -q origin HEAD:main 2>/dev/null

repo="$sandbox/acme-web"
mkdir -p "$repo" && git -C "$repo" init -q && git -C "$repo" commit -q --allow-empty -m init

pass=0 fail=0
report() {
  local name=$1 ok=$2 out=$3
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$out"
  fi
}
check() { report "$1" "$( eval "$2" && echo true || echo false)" "${3:-}"; }

# run <home> <mode> [VAR=value...]; sets $out and $code. $stdin overrides the hook input
run() {
  local home=$1 mode=$2; shift 2
  local in=${stdin:-$(printf '{"session_id":"sess-%s"}' "$RANDOM")}
  out=$(cd "$repo" && printf '%s' "$in" | env -u KRU_HOME -u KRU_PROJECT_STORE \
    -u KRU_STORE_URL -u KRU_STORE_REPO -u KRU_CLOUD -u CURSOR_AGENT_SOCKET -u CLAUDE_PROJECT_DIR -u KRU_NO_STORE_SYNC \
    HOME="$home" KRU_STORE_REPO="$remote" "$@" bash "$hook" "$mode" "$root" 2>&1)
  code=$?
}
remote_has() { git -C "$remote" show "main:$1" 2>/dev/null; }

# --- off unless a store repo is named ---------------------------------------
h0="$sandbox/h0"; mkdir -p "$h0"
out=$(cd "$repo" && echo '{}' | env -u KRU_STORE_REPO -u KRU_HOME HOME="$h0" bash "$hook" start "$root" 2>&1); code=$?
check "unset: no clone, silent, exit 0" '[ $code = 0 ] && [ -z "$out" ] && [ ! -e "$h0/.kru" ]' "exit $code [$out]"

run "$sandbox/h1" start KRU_NO_STORE_SYNC=1
check "kill switch: no clone" '[ $code = 0 ] && [ ! -e "$sandbox/h1/.kru" ]' "exit $code [$out]"

# --- start ------------------------------------------------------------------
h1="$sandbox/h1"; mkdir -p "$h1"
run "$h1" start
check "start clones the store into home" '[ $code = 0 ] && [ -f "$h1/.kru/inbox.md" ]' "exit $code [$out]"
check "start restores agent memory into the repo" \
  '[ -f "$repo/.claude/agent-memory-local/kru-test-writer/MEMORY.md" ]' "[$out]"

printf 'from seed\n' >> "$seed/inbox.md"; git -C "$seed" commit -qam more && git -C "$seed" push -q origin HEAD:main 2>/dev/null
run "$h1" start
check "start pulls a newer store" 'grep -q "from seed" "$h1/.kru/inbox.md"' "[$out]"

h2="$sandbox/h2"; mkdir -p "$h2/.kru/lead-gate"; printf 'x' > "$h2/.kru/lead-gate/s1"
run "$h2" start
check "start into a non-git home keeps local files and gets tracked ones" \
  '[ -f "$h2/.kru/lead-gate/s1" ] && [ -f "$h2/.kru/inbox.md" ] && [ -d "$h2/.kru/.git" ]' "exit $code [$out]"

# --- stop -------------------------------------------------------------------
run "$h1" stop
check "stop pushes the defaults start seeded into an unseeded store" \
  'remote_has .gitattributes | grep -q "inbox.md merge=kru-lines"' "[$out]"

before=$(git -C "$remote" rev-parse main)
run "$h1" stop
check "stop on a clean store makes no commit" '[ "$(git -C "$remote" rev-parse main)" = "$before" ]' "[$out]"

mkdir -p "$h1/.kru/management/acme-web/plan/checkout"; printf 'brief\n' > "$h1/.kru/management/acme-web/plan/checkout/brief.md"
run "$h1" stop
check "stop commits and pushes a new plan file" \
  '[ $code = 0 ] && [ "$(remote_has management/acme-web/plan/checkout/brief.md)" = brief ]' "exit $code [$out]"

mkdir -p "$h1/.kru/audit"; printf '{}\n' > "$h1/.kru/audit/s.jsonl"
run "$h1" stop
check "session-lived hook state never reaches the remote" '! remote_has audit/s.jsonl >/dev/null' "[$out]"

printf 'learned\n' > "$repo/.claude/agent-memory-local/kru-test-writer/quirk.md"
run "$h1" stop
check "stop saves repo agent memory into the store" \
  '[ "$(remote_has management/acme-web/agent-memory/kru-test-writer/quirk.md)" = learned ]' "[$out]"

# two sessions append to the inbox without seeing each other
run "$h2" start
printf 'line a\n' >> "$h1/.kru/inbox.md"; printf 'line b\n' >> "$h2/.kru/inbox.md"
run "$h1" stop; run "$h2" stop
inbox=$(remote_has inbox.md)
check "concurrent inbox appends both land" \
  'case "$inbox" in *"line a"*"line b"*|*"line b"*"line a"*) true ;; *) false ;; esac' "[$inbox] [$out]"

# a sweep drains the last line while a session that hasn't pulled it appends one:
# the drain holds and the append lands
run "$h1" start; run "$h2" start
grep -v '^line b$' "$h1/.kru/inbox.md" > "$sandbox/drained" && mv "$sandbox/drained" "$h1/.kru/inbox.md"
printf 'line c\n' >> "$h2/.kru/inbox.md"
run "$h1" stop; run "$h2" stop
inbox=$(remote_has inbox.md)
check "a drained line stays drained past a concurrent append" \
  'case "$inbox" in *"line b"*) false ;; *"line a"*"line c"*) true ;; *) false ;; esac' "[$inbox] [$out]"

run "$h1" start
check "an existing store's union rule moves to the line merge" \
  'grep -q "inbox.md merge=kru-lines" "$h1/.kru/.gitattributes" && ! grep -q "merge=union" "$h1/.kru/.gitattributes"' "[$(cat "$h1/.kru/.gitattributes")]"

# a push that failed leaves a commit ahead of the remote, and the next stop
# sends it even when nothing new changed
mv "$remote" "$remote.away"
printf 'offline\n' > "$h1/.kru/management/acme-web/plan/checkout/offline.md"
run "$h1" stop
mv "$remote.away" "$remote"
run "$h1" stop
check "a commit left by a failed push goes out on the next stop" \
  '[ "$(remote_has management/acme-web/plan/checkout/offline.md)" = offline ]' "[$out]"

# a stop re-entered by a blocking stop hook still pushes what its turn wrote
printf 'reentered\n' > "$h1/.kru/management/acme-web/plan/checkout/reentered.md"
stdin='{"session_id":"sess-re","stop_hook_active":true}' run "$h1" stop
check "a re-entered stop pushes the store" \
  '[ "$(remote_has management/acme-web/plan/checkout/reentered.md)" = reentered ]' "[$out]"

# --- fail soft --------------------------------------------------------------
h3="$sandbox/h3"; mkdir -p "$h3"
run "$h3" start KRU_STORE_REPO="$sandbox/missing.git"
check "unreachable remote: exit 0 and one line" \
  '[ $code = 0 ] && [ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 1 ] && case "$out" in *"kru store"*) true ;; *) false ;; esac' \
  "exit $code [$out]"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
