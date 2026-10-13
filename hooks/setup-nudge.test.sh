#!/bin/bash
# table tests for setup-nudge.sh: each case is a working directory the session
# started in and whether the hook nudges. run: bash hooks/setup-nudge.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/setup-nudge.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
mkdir -p "$home"

repo() { mkdir -p "$sandbox/$1" && git -C "$sandbox/$1" init -q; }
repo bare
repo stamped; mkdir -p "$sandbox/stamped/.claude"
printf '# notes\n\n<!-- kru v0.141.0 · derived 2026-10-01 · /kru-setup to re-derive -->\n' > "$sandbox/stamped/AGENTS.md"
repo unstamped; mkdir -p "$sandbox/unstamped/.claude"
printf '# notes\nno team section\n' > "$sandbox/unstamped/AGENTS.md"
repo plugin; mkdir -p "$sandbox/plugin/.cursor-plugin"; printf '{}' > "$sandbox/plugin/.cursor-plugin/plugin.json"
repo nested; mkdir -p "$sandbox/nested/a/b"
mkdir -p "$sandbox/nogit"

pass=0 fail=0
# check <expect> <dir> [VAR=value...] — expect: nudge | silent
check() {
  local expect=$1 dir=$2; shift 2
  local input out code ok=true
  input=$(jq -nc --arg c "$dir" '{session_id:"s", hook_event_name:"SessionStart", source:"startup", cwd:$c}')
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_LEAD_GATE \
    HOME="$home" "$@" bash "$hook" "$root" 2>&1)
  code=$?
  [ "$code" -eq 0 ] || ok=false
  if [ "$expect" = nudge ]; then
    printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | test("/kru-setup")' >/dev/null 2>&1 || ok=false
  else
    [ -z "$out" ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s %s\n  %s\n' "$expect" "$code" "$dir" "$*" "$out"
  fi
}

check nudge "$sandbox/bare"
check nudge "$sandbox/unstamped"
check nudge "$sandbox/nested/a/b"
check silent "$sandbox/stamped"
check silent "$sandbox/plugin"
check silent "$sandbox/nogit"

# kill switches win over a repo with no sheet
check silent "$sandbox/bare" KRU_NO_LEAD_GATE=1
mkdir -p "$home/.kru/lead-gate" && touch "$home/.kru/lead-gate/off"
check silent "$sandbox/bare"
rm -f "$home/.kru/lead-gate/off"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
