#!/bin/bash
# table tests for log-return.sh: each case is one seat stopping, and whether it
# is kept running, logged, or let go. run: bash hooks/log-return.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/log-return.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
audit="$home/.kru/audit"
mkdir -p "$home"

blocko=better-auth-specialist plain=code-reviewer
grep -q '^## The return pass' "$root/agents/$blocko.md" || { echo "fixture drift: $blocko lost Block O"; exit 1; }
grep -q '^## The return pass' "$root/agents/$plain.md" && { echo "fixture drift: $plain gained Block O"; exit 1; }

pass=0 fail=0
report() {
  if $2; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$1" "$3"
  fi
}

# stop <sid> <agent_type> <message> [active] [transcript] — sets $out and $code
stop() {
  local input
  input=$(jq -nc --arg s "$1" --arg t "$2" --arg m "$3" --argjson a "${4:-false}" --arg tp "${5:-}" \
    '{session_id:$s, cwd:"/work/myrepo", hook_event_name:"SubagentStop", stop_hook_active:$a,
      agent_id:"x1", agent_type:$t, last_assistant_message:$m, agent_transcript_path:$tp}')
  out=$(printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u CURSOR_PLUGIN_ROOT HOME="$home" bash "$hook" "$root" 2>&1)
  code=$?
}
lines() { if [ -f "$audit/$1.jsonl" ]; then wc -l < "$audit/$1.jsonl" | tr -d ' '; else echo 0; fi; }
quiet() { [ "$code" -eq 0 ] && [ -z "$out" ] && [ "$(lines "$2")" = 0 ] && ok=true || ok=false; report "$1" "$ok" "exit $code, lines $(lines "$2"), out: $out"; }

stop a1 "kru-$blocko" "done. Return pass: read the slice whole"
quiet "block o return with the line lets go" a1
stop a2 "kru-$blocko" "Look-back: three findings"
quiet "a look-back trace counts as the line" a2
stop a3 "kru-$plain" "findings: none"
quiet "a seat without block o lets go" a3
stop a4 "Explore" "done"
quiet "a non-team agent lets go" a4
stop a5 "" "done"
quiet "an internal agent (empty type) lets go" a5

stop b1 "kru-$blocko" "all done"
ok=true
[ "$code" -eq 0 ] && [ "$(lines b1)" = 0 ] || ok=false
printf '%s' "$out" | jq -e '.decision == "block" and (.reason | test("Return pass:"))' >/dev/null 2>&1 || ok=false
report "block o return without the line is kept running" "$ok" "exit $code, out: $out"

stop b2 "kru-$blocko" "still done" true
ok=true
[ "$code" -eq 0 ] && [ -z "$out" ] && [ "$(lines b2)" = 1 ] || ok=false
tail -1 "$audit/b2.jsonl" 2>/dev/null | jq -e --arg seat "$blocko" '
  .seat == $seat and .event == "return" and .return_pass == false and .cwd == "myrepo"' >/dev/null 2>&1 || ok=false
report "second stop without the line is logged, not blocked" "$ok" "exit $code, out: $out"

tp="$sandbox/agent.jsonl"
printf '%s\n' '{"type":"tool_use","input":{"message":"Return pass: whole slice"}}' > "$tp"
stop c1 "kru-$blocko" "" false "$tp"
quiet "the line found in the seat's own transcript lets go" c1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
