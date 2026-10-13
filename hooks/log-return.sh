#!/bin/bash
# subagentstop: a seat carrying Block O owes a `Return pass:` line (a reflect
# look-back owes `Look-back:` instead). this is the one moment the return
# exists — posttooluse on the dispatch fires at launch for a background seat,
# with nothing to read — so the check lives here. a seat stopping without the
# line is kept running once and asked for it; one that still stops without it
# is logged to the session ledger for dispatch-auditor. fail open everywhere.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
[ -d "$plugin_root/agents" ] || exit 0
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
input=$(cat) || exit 0

seat=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)
seat="${seat#kru-}"
[ -z "$seat" ] && exit 0
[ "$seat" = "dispatch-auditor" ] && exit 0
[ -f "$plugin_root/agents/${seat}.md" ] || exit 0
grep -q '^## The return pass' "$plugin_root/agents/${seat}.md" 2>/dev/null || exit 0

trace='Return pass:|Look-back:'
printf '%s' "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null | grep -qE "$trace" && exit 0
# a seat that hands back through a tool leaves its report out of
# last_assistant_message; its own transcript still carries it
tpath=$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
tpath="${tpath/#\~/$HOME}"
[ -n "$tpath" ] && [ -f "$tpath" ] && tail -c 200000 "$tpath" 2>/dev/null | grep -qE "$trace" && exit 0

active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$active" != "true" ]; then
  jq -n '{ decision: "block",
    reason: "kru: your seat prompt carries `## The return pass` and this return states no `Return pass:` line. Run the pass over the slice as that section describes, then end your return with the line." }'
  exit 0
fi

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
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
jq -nc --arg seat "$seat" --arg slug "$cwd_slug" '{
  ts: (now | todate), cwd: $slug, seat: $seat, event: "return", return_pass: false
}' >> "$dir/$sid.jsonl" 2>/dev/null
exit 0
