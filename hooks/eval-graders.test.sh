#!/bin/bash
# Offline checks for eval grader input_match patterns (billing-settings-copy).
set -u
pass=0 fail=0

py_match() {
  python3 - "$1" "$2" <<'PY'
import re, sys
pat, text = sys.argv[1], sys.argv[2]
print(len(re.findall(pat, text)))
PY
}

check_no_match() {
  local name=$1 pattern=$2 text=$3
  local n
  n=$(py_match "$pattern" "$text")
  if [ "$n" -eq 0 ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL %s: expected 0 matches, got %s\n  %s\n' "$name" "$n" "$text"
  fi
}

check_match() {
  local name=$1 pattern=$2 text=$3
  local n
  n=$(py_match "$pattern" "$text")
  if [ "$n" -ge 1 ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL %s: expected match, got 0\n  %s\n' "$name" "$text"
  fi
}

AGENT_SEAT='"subagent_type"\s*:\s*"(?:kru:)?[a-z0-9]+(?:-[a-z0-9]+)*"\s*,\s*"prompt"'
NOT_UX='"subagent_type"\s*:\s*"(?:kru:)?ux-designer"\s*,\s*"prompt"'
NOT_CC='"subagent_type"\s*:\s*"(?:kru:)?conversion-copywriter"\s*,\s*"prompt"'

GOOD_DISPATCH='{"name":"Agent","input":{"subagent_type":"kru-react-ui-builder","prompt":"Build the card.","description":"t"}}'
BAD_UX_KRU='{"name":"Agent","input":{"subagent_type":"kru-ux-designer","prompt":"Fix copy.","description":"t"}}'
BAD_UX='{"name":"Agent","input":{"subagent_type":"ux-designer","prompt":"Fix copy.","description":"t"}}'
BAD_CC='{"name":"Agent","input":{"subagent_type":"conversion-copywriter","prompt":"Write deck.","description":"t"}}'
FALSE_POSITIVE_UX='{"name":"Agent","input":{"subagent_type":"kru-code-reviewer","prompt":"Do not dispatch ux-designer for this.","description":"t"}}'
NO_DISPATCH='Tell the PM the billing screen copy belongs in the approved design spec.'

check_match no-seat-detects-dispatch "$AGENT_SEAT" "$GOOD_DISPATCH"
check_no_match no-seat-no-agent-json "$AGENT_SEAT" "$NO_DISPATCH"
check_match not-ux-kru "$NOT_UX" "$BAD_UX_KRU"
check_match not-ux-plain "$NOT_UX" "$BAD_UX"
check_no_match not-ux-prose "$NOT_UX" "$FALSE_POSITIVE_UX"
check_match not-cc "$NOT_CC" "$BAD_CC"
check_no_match not-cc-prose "$NOT_CC" "$FALSE_POSITIVE_UX"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
