#!/bin/bash
# posttooluse on the subagent-dispatch tool: append one jsonl line per team-seat
# dispatch to the session ledger dispatch-auditor reads. fail open everywhere —
# a logging miss must never break the session.
command -v jq >/dev/null 2>&1 || exit 0
# plugin root arrives as $1 (passed by hooks/cursor-hook.sh) — it is not a
# guaranteed env var here, and an empty root would silence logging forever
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
[ -d "$plugin_root/agents" ] || exit 0
# unreadable only on a broken install, and every guard here fails open on those
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
input=$(cat) || exit 0

seat=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
seat="${seat#kru-}"
[ -z "$seat" ] && exit 0
# the auditor's own dispatch would re-create the ledger it just deleted
[ "$seat" = "dispatch-auditor" ] && exit 0
# only team seats are auditable against the lead contract
[ -f "$plugin_root/agents/${seat}.md" ] || exit 0

# seats carrying Block O owe a `Return pass:` line. whether a return carried it
# is log-return.sh's to check at subagentstop: this hook fires at launch for a
# background seat, when there is no return to read
block_o=false
grep -q '^## The return pass' "$plugin_root/agents/${seat}.md" 2>/dev/null && block_o=true

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

# the git root is the engagement stamp, same walk as check-handoff.sh
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
cwd_slug=""
d="$cwd"
while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
  [ -e "$d/.git" ] && { cwd_slug=$(basename "$d"); break; }
  d=$(dirname "$d")
done
[ -z "$cwd_slug" ] && [ -n "$cwd" ] && cwd_slug=$(basename "$cwd")

dir="$(kru_path audit)"
mkdir -p "$dir" 2>/dev/null || exit 0
# crashed sessions leave ledgers nothing will audit, and the stop nudge's mark
# beside each one; keep the dir bounded
find "$dir" \( -name '*.jsonl' -o -name '*.jsonl.nudged' \) -mtime +7 -delete 2>/dev/null

# the prompt is logged whole up to a 32000-char guard: the seven handoff items
# sit anywhere in a real brief, and a ledger holds one turn's dispatches before
# the audit deletes it. `truncated` tells the auditor an absent clause past the
# guard is not evidence.
# the response is never read here, so the ledger stays a record of the lead's
# process, not of seat output
printf '%s' "$input" | jq -c --arg seat "$seat" --arg slug "$cwd_slug" \
  --argjson block_o "$block_o" '{
  ts: (now | todate),
  cwd: $slug,
  seat: $seat,
  desc: (.tool_input.description // ""),
  prompt: ((.tool_input.prompt // "")[0:32000]),
  truncated: (((.tool_input.prompt // "") | length) > 32000),
  refused: false,
  block_o: $block_o
}' >> "$dir/$sid.jsonl" 2>/dev/null

exit 0
