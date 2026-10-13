#!/bin/bash
# table tests for brainstorm-guard.sh, cursor-shaped: the lock is set and lifted
# by the user's own prompts (prompt-state.sh at beforeSubmitPrompt) and read at
# preToolUse, both through hooks/cursor-hook.sh. run: bash hooks/brainstorm-guard.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" TMPDIR="$sandbox/tmp"
mkdir -p "$HOME" "$TMPDIR"

pass=0 fail=0
say() { # <conv> <prompt> [attachment path]
  jq -nc --arg c "$1" --arg p "$2" --arg a "${3:-}" '{conversation_id:$c, prompt:$p,
    attachments: (if $a == "" then [] else [{type:"rule", file_path:$a}] end)}' |
    bash "$here/cursor-hook.sh" beforeSubmitPrompt prompt-state.sh >/dev/null
}
check() { # <expect> <conv> <tool> <tool_input> <name>
  local out
  out=$(jq -nc --arg c "$2" --arg t "$3" --argjson i "$4" '{conversation_id:$c, tool_name:$t, tool_input:$i}' |
    (cd "$root" && bash "$here/cursor-hook.sh" preToolUse brainstorm-guard.sh))
  if [ "$(jq -r .permission <<<"$out" 2>/dev/null)" = "$1" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL (%s): %s\n  %s\n' "$1" "$5" "$out"; fi
}

check allow a Write '{"path":"x"}' "no brainstorm, no lock"
say a '/kru-brainstorm a referral program'
check deny a Write '{"path":"x"}' "a write under the lock"
check deny a Delete '{"path":"x"}' "a delete under the lock"
check deny a Shell '{"command":"echo x > f"}' "a shell write under the lock"
check deny a Shell '{"command":"ls; touch x"}' "a chained write under the lock"
check allow a Shell '{"command":"git log --oneline -3"}' "read-only shell under the lock"
check allow b Write '{"path":"x"}' "the lock is per conversation"
say a 'what about payouts?'
check deny a Write '{"path":"x"}' "an ordinary turn keeps it"
say a 'Go ahead.'
check allow a Write '{"path":"x"}' "the user's go lifts it"
say a '/kru-brainstorm again'
say a 'going further, what about fees?'
check deny a Write '{"path":"x"}' "a word starting with go is not a go"
say a 'brief it'
check allow a Write '{"path":"x"}' "brief it lifts it"
say c 'help' "$root/skills/kru-brainstorm/SKILL.md"
check deny c Write '{"path":"x"}' "the skill attached from the / menu locks too"
say c '/kru-brief'
check allow c Write '{"path":"x"}' "/kru-brief lifts it"
# headless: the PM bot's brief carries its go up front, as a line of its own
say d $'/kru-brainstorm a referral program\n\nDecisions resolved: payouts monthly.\ngo'
check allow d Write '{"path":"x"}' "headless: a go line in the brainstorm prompt lifts the lock up front"
say e $'/kru-brainstorm a referral program\nwe should go slow on payouts'
check deny e Write '{"path":"x"}' "headless: go inside a sentence is not a go"
say f $'go\n/kru-brainstorm later'
check allow f Write '{"path":"x"}' "a go on the first line is not a brainstorm"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
