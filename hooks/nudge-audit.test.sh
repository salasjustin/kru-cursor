#!/bin/bash
# table tests for nudge-audit.sh: each case sets up a session's ledger and mark,
# runs the stop hook, and checks whether it blocks and what it leaves behind.
# cases run in order — the mark one writes is state the next reads.
# run: bash hooks/nudge-audit.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/nudge-audit.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
audit="$home/.kru/audit"
mkdir -p "$audit"

pass=0 fail=0
report() {
  local name=$1 ok=$2 code=$3 out=$4
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (exit %s): %s\n  %s\n' "$code" "$name" "$out"
  fi
}

# run_hook <stdin json> [VAR=value...] — sets $out and $code
run_hook() {
  local input=$1; shift
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_AUDIT -u CURSOR_PLUGIN_ROOT \
    HOME="$home" "$@" bash "$hook" "$root" 2>&1)
  code=$?
}

stop_input() { jq -nc --arg s "$1" '{session_id:$s, stop_hook_active:false}'; }
ledger_lines() { : > "$audit/$1.jsonl"; local i; for ((i = 0; i < $2; i++)); do echo '{"seat":"x"}' >> "$audit/$1.jsonl"; done; }

# expect_silent <name> — exit 0, no output
expect_silent() {
  local ok=true
  [ "$code" -eq 0 ] && [ -z "$out" ] || ok=false
  report "$1" "$ok" "$code" "$out"
}

expect_absent() {
  local ok=true
  [ ! -e "$2" ] || ok=false
  report "$1" "$ok" "$code" "$2 exists"
}

# expect_block <name> <sid> <n> — block json naming n and the ledger, mark holds n
expect_block() {
  local ok=true ledger="$audit/$2.jsonl"
  [ "$code" -eq 0 ] || ok=false
  printf '%s' "$out" | jq -e --arg n "$3" --arg l "$ledger" '
    .decision == "block"
    and (.reason | contains("\($n) team-seat dispatch(es)"))
    and (.reason | contains("logged at \($l)."))
    and (.reason | contains("kru-dispatch-auditor"))' >/dev/null 2>&1 || ok=false
  [ "$(cat "$ledger.nudged" 2>/dev/null)" = "$3" ] || ok=false
  report "$1" "$ok" "$code" "$out"
}

# no ledger: silent, and a stale mark from an audited ledger goes with it
echo 3 > "$audit/s1.jsonl.nudged"
run_hook "$(stop_input s1)"
expect_silent "no ledger is silent"
expect_absent "no ledger removes stale mark" "$audit/s1.jsonl.nudged"

# empty ledger counts as no ledger
: > "$audit/s1.jsonl"
run_hook "$(stop_input s1)"
expect_silent "empty ledger is silent"
rm -f "$audit/s1.jsonl"

# first nudge, then quiet at the same count, then again once the ledger grows
ledger_lines s2 2
run_hook "$(stop_input s2)"
expect_block "ledger with no mark nudges" s2 2
run_hook "$(stop_input s2)"
expect_silent "same count after nudge is silent"
ledger_lines s2 5
run_hook "$(stop_input s2)"
expect_block "grown ledger nudges again with new count" s2 5
run_hook "$(stop_input s2)"
expect_silent "grown count after its nudge is silent"

# a mark that isn't a count is read as zero
ledger_lines s3 1
printf 'garbage' > "$audit/s3.jsonl.nudged"
run_hook "$(stop_input s3)"
expect_block "non-numeric mark treated as zero" s3 1

# guards — each would otherwise nudge on s4's unmarked ledger
ledger_lines s4 4
run_hook "$(jq -nc '{session_id:"s4", stop_hook_active:true}')"
expect_silent "stop_hook_active is silent"
run_hook '{"stop_hook_active":false}'
expect_silent "missing session_id is silent"
run_hook "$(stop_input s4)" KRU_NO_AUDIT=1
expect_silent "KRU_NO_AUDIT is silent"
expect_absent "guards write no mark" "$audit/s4.jsonl.nudged"
# and with the guards lifted it does nudge, so the silences above are the guards'
run_hook "$(stop_input s4)"
expect_block "unguarded s4 nudges" s4 4

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
