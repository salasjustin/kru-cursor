#!/bin/bash
# table tests for require-lead.sh, cursor-shaped: each case is a payload as
# cursor sends it, through hooks/cursor-hook.sh the way hooks/hooks.json calls
# it, and the decision the gate returns. scripts/cursor-hooks.test.sh runs the
# same gate end to end from hooks.json. run: bash hooks/require-lead.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" TMPDIR="$sandbox/tmp"
mkdir -p "$HOME" "$TMPDIR" "$sandbox/work"
unset KRU_HOME KRU_NO_LEAD_GATE KRU_PROJECT_STORE KRU_STORE_URL

pass=0 fail=0
# run <hook> <conv> <tool> <tool_input> [extra] — sets $out
run() {
  local input
  input=$(jq -nc --arg c "$2" --arg t "$3" --argjson i "$4" --argjson x "${5:-{\}}" --arg w "$sandbox/work" \
    '{conversation_id:$c, tool_name:$t, tool_input:$i, cwd:$w, transcript_path:null} + $x')
  out=$(cd "$root" && printf '%s' "$input" | bash "$here/cursor-hook.sh" preToolUse "$1")
}
say() { printf '%s' "$(jq -nc --arg c "$1" --arg p "$2" '{conversation_id:$c, prompt:$p}')" | bash "$here/cursor-hook.sh" beforeSubmitPrompt prompt-state.sh >/dev/null; }
check() { # <expect allow|deny> <name>
  if [ "$(jq -r .permission <<<"$out" 2>/dev/null)" = "$1" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL (%s): %s\n  %s\n' "$1" "$2" "$out"; fi
}

run require-lead.sh a Write '{"path":"x"}'; check deny "first write, no lead"
run require-lead.sh a Write '{"path":"x"}'; check allow "fires once per conversation"
run require-lead.sh b Read '{"path":"src/a.ts"}'; check allow "a read is an inspection"
run require-lead.sh b Grep '{"pattern":"x"}'; check allow "a grep is an inspection"
for c in 'ls -la' 'git status' 'grep -rn foo src | head -5' 'git log --oneline -3'; do
  run require-lead.sh b Shell "$(jq -nc --arg c "$c" '{command:$c}')"; check allow "read-only shell: $c"
done
run require-lead.sh c Shell '{"command":"rm -rf build"}'; check deny "a writing shell command"
run require-lead.sh d Read "$(jq -nc --arg p "$root/skills/kru-lead/SKILL.md" '{path:$p}')"
run require-lead.sh d Task '{"subagent_type":"kru-node-developer","prompt":"x","description":"x"}'; check allow "the skill read loads the lead"
run require-lead.sh e Shell "$(jq -nc --arg p "$root/skills/kru-lead/SKILL.md" '{command:("cat " + $p)}')"
run require-lead.sh e Write '{"path":"x"}'; check allow "a shell read of the skill loads it too"
say f '/kru-lead add billing'; run require-lead.sh f Write '{"path":"x"}'; check allow "/kru-lead typed"
say g '/kru-issue the flaky test'; run require-lead.sh g Write '{"path":"x"}'; check allow "a kru command is its own contract"
say h '/kru-issue the flaky test'; say h 'now build it'; run require-lead.sh h Write '{"path":"x"}'; check deny "an ordinary turn after the command is gated again"
run require-lead.sh i Write '{"path":"x"}' '{"parent_tool_call_id":"tc1"}'; check allow "a subagent's call"
printf 'x skills/kru-lead/SKILL.md x\n' > "$sandbox/transcript.txt"
run require-lead.sh j Write '{"path":"x"}' "$(jq -nc --arg t "$sandbox/transcript.txt" '{transcript_path:$t}')"; check allow "a transcript naming the skill"
KRU_NO_LEAD_GATE=1 run require-lead.sh k Write '{"path":"x"}'; check allow "KRU_NO_LEAD_GATE"
mkdir -p "$HOME/.kru/lead-gate" && : > "$HOME/.kru/lead-gate/off"
run require-lead.sh l Write '{"path":"x"}'; check allow "the lead-gate/off file"
rm -f "$HOME/.kru/lead-gate/off"
run require-lead.sh '' Write '{"path":"x"}'; check allow "no conversation id: fail open"
run require-lead.sh '../../etc' Write '{"path":"x"}'; check allow "a path-shaped id is never a dir"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
