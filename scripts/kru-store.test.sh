#!/bin/bash
# table tests for kru-store.sh: each case runs the CLI with one surface's
# environment and checks the root it resolves. the store's two roots are the
# one thing every skill, seat and hook derives a path from, so a wrong answer
# here is a store nobody finds.
# run: bash scripts/kru-store.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
store="$here/kru-store.sh"

# pwd -P: on macos mktemp hands back /var/... while git and pwd resolve the
# symlink to /private/var/..., and the two spellings never compare equal
sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
repo="$sandbox/acme-web"
mkdir -p "$home" "$repo"
git -C "$repo" init -q 2>/dev/null
git -C "$repo" commit -q --allow-empty -m init 2>/dev/null

pass=0 fail=0
report() {
  local name=$1 ok=$2 out=$3
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$out"
  fi
}

# run <dir> <args...> [VAR=value...] via env; sets $out and $code.
# every KRU_* and every surface variable is stripped, so a value set in the
# parent shell can't make a case pass for the wrong reason.
# KRU_CLOUD=0 is the default so a host /run/cursor/api.sock does not flip these
# cases; a case that passes KRU_CLOUD=1 overrides it.
run() {
  local dir=$1; shift
  local args=() envs=()
  local seen_env=false
  for a in "$@"; do
    case "$a" in
      *=*) seen_env=true; envs+=("$a") ;;
      *) $seen_env && envs+=("$a") || args+=("$a") ;;
    esac
  done
  out=$(cd "$dir" && env -u KRU_HOME -u KRU_PROJECT -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_STORE_REPO \
    -u CLAUDE_PLUGIN_OPTION_KRU_STORE_REPO -u KRU_NO_AUDIT -u CLAUDE_PLUGIN_OPTION_KRU_NO_AUDIT \
    -u KRU_CLOUD -u CURSOR_AGENT_SOCKET -u CLAUDE_PROJECT_DIR \
    HOME="$home" KRU_CLOUD=0 ${envs[@]+"${envs[@]}"} bash "$store" "${args[@]}" 2>&1)
  code=$?
}

# a case pattern inside $( ) trips the parser, so matching gets a function
contains() { case "$2" in *"$1"*) return 0 ;; esac; return 1; }

is() {
  local name=$1 want=$2
  report "$name" "$([ "$out" = "$want" ] && echo true || echo false)" "want [$want] got [$out]"
}

# --- home: the cross-project root -------------------------------------------
run "$repo" home
is "home defaults under \$HOME" "$home/.kru"

run "$repo" home KRU_HOME="$sandbox/elsewhere"
is "home honours KRU_HOME" "$sandbox/elsewhere"

# --- project: the plan of record --------------------------------------------
run "$repo" project
is "project sits under the cross-project root, keyed by slug" "$home/.kru/management/acme-web"

run "$repo" project KRU_CLOUD=1
is "project moves into the clone on a cloud vm" "$repo/.kru"

run "$repo" project KRU_CLOUD=1 KRU_HOME="$sandbox/elsewhere"
is "an explicit KRU_HOME outranks the cloud default" "$sandbox/elsewhere/management/acme-web"

run "$repo" project KRU_CLOUD=1 KRU_HOME="$sandbox/elsewhere" KRU_PROJECT_STORE="$sandbox/pinned"
is "KRU_PROJECT_STORE outranks both" "$sandbox/pinned"

run "$repo" project KRU_CLOUD=1 KRU_STORE_REPO=acme/kru-store
is "a store repo keeps the project half under home on a cloud vm" "$home/.kru/management/acme-web"

run "$repo" project KRU_CLOUD=1 KRU_STORE_REPO=acme/kru-store KRU_PROJECT_STORE="$sandbox/pinned"
is "KRU_PROJECT_STORE outranks a store repo" "$sandbox/pinned"

# --- slug: one name across both stores --------------------------------------
run "$repo" slug
is "slug is the repo's dir name" "acme-web"

run "$repo/.git" slug
is "slug is stable from a subdir" "acme-web"

# a slice dispatched into a worktree keeps the dispatching session's store
if git -C "$repo" worktree add -q "$sandbox/wt-feature" -b feature 2>/dev/null; then
  run "$sandbox/wt-feature" slug
  is "a linked worktree resolves to the main repo's slug" "acme-web"
else
  printf 'SKIP: git worktree unavailable\n'
fi

run "$sandbox" slug
is "no repo falls back to the cwd's name" "$(basename "$sandbox")"

run "$repo" slug KRU_PROJECT=acme-oss
is "KRU_PROJECT outranks the dir name" "acme-oss"

run "$repo" project KRU_CLOUD=1 KRU_STORE_REPO=acme/kru-store KRU_PROJECT=acme-oss
is "KRU_PROJECT names the plan dir under a store repo" "$home/.kru/management/acme-oss"

# --- backend ----------------------------------------------------------------
run "$repo" backend
is "backend is files until a store url says otherwise" "fs"

run "$repo" backend KRU_STORE_URL=https://claude.ai/code/artifact/abc
is "a store url selects the artifact backend" "artifact"

# --- path: the logical vocabulary -------------------------------------------
run "$repo" path inbox
is "inbox is cross-project" "$home/.kru/inbox.md"

run "$repo" path refusals
is "refusals is cross-project" "$home/.kru/refusals.jsonl"

run "$repo" path patterns/card-grid
is "a pattern is cross-project" "$home/.kru/patterns/card-grid.md"

run "$repo" path audit/sess-1
is "the audit ledger is cross-project" "$home/.kru/audit/sess-1.jsonl"

run "$repo" path lead-gate/sess-1
is "the lead-gate mark is cross-project" "$home/.kru/lead-gate/sess-1"

run "$repo" path todos
is "todos is project-scoped" "$home/.kru/management/acme-web/TODOS.md"

run "$repo" path issues/flaky-login
is "a defect file is project-scoped" "$home/.kru/management/acme-web/issues/flaky-login.md"

run "$repo" path plan/checkout/brief.md
is "a plan file is project-scoped" "$home/.kru/management/acme-web/plan/checkout/brief.md"

run "$repo" path todos KRU_CLOUD=1
is "the project half follows the cloud root" "$repo/.kru/TODOS.md"

run "$repo" path inbox KRU_CLOUD=1
is "the cross-project half does not" "$home/.kru/inbox.md"

run "$repo" path agent-memory
is "agent memory is project-scoped" "$home/.kru/management/acme-web/agent-memory"

run "$repo" path agent-memory KRU_CLOUD=1 KRU_STORE_REPO=acme/kru-store
is "agent memory follows the store repo on a cloud vm" "$home/.kru/management/acme-web/agent-memory"

run "$repo" path nope
report "an unknown logical name is a usage error" \
  "$([ "$code" = 64 ] && echo true || echo false)" "exit $code: $out"

# --- where: the line a skill reports ----------------------------------------
run "$repo" where
report "where says nothing when both roots sit at their defaults" \
  "$([ -z "$out" ] && echo true || echo false)" "got [$out]"

run "$repo" where KRU_CLOUD=1
report "where names the in-repo plan store" \
  "$(contains 'ships in the branch' "$out" && echo true || echo false)" "got [$out]"

run "$repo" where KRU_STORE_URL=https://claude.ai/code/artifact/abc
report "where names the artifact backend" \
  "$(contains 'artifact' "$out" && echo true || echo false)" "got [$out]"

run "$repo" where KRU_CLOUD=1 KRU_STORE_REPO=acme/kru-store
report "where names the store repo, not the branch" \
  "$(contains 'acme/kru-store' "$out" && ! contains 'ships in the branch' "$out" && echo true || echo false)" "got [$out]"

# --- options: /plugin values fill an unset env var --------------------------
run "$repo" where CLAUDE_PLUGIN_OPTION_KRU_STORE_REPO=acme/from-option
report "the store-repo option stands in for an unset KRU_STORE_REPO" \
  "$(contains 'synced to acme/from-option' "$out" && echo true || echo false)" "got [$out]"

run "$repo" where KRU_STORE_REPO=acme/from-env CLAUDE_PLUGIN_OPTION_KRU_STORE_REPO=acme/from-option
report "an exported KRU_STORE_REPO outranks the option" \
  "$(contains 'synced to acme/from-env' "$out" && ! contains 'from-option' "$out" && echo true || echo false)" "got [$out]"

# a switch reads only after sourcing, so these source the resolver directly
switch() {
  out=$(env -u KRU_NO_AUDIT -u CLAUDE_PLUGIN_OPTION_KRU_NO_AUDIT HOME="$home" "$@" \
    bash -c '. "$1"; printf %s "${KRU_NO_AUDIT:-unset}"' _ "$store" 2>&1)
}
switch CLAUDE_PLUGIN_OPTION_KRU_NO_AUDIT=true
is "a switch option set true turns the switch on" "1"
switch CLAUDE_PLUGIN_OPTION_KRU_NO_AUDIT=false
is "a switch option set false leaves it off" "unset"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
