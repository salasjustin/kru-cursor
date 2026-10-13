#!/bin/bash
# subagentStart + preToolUse on Write|Delete: the seats upstream gives no Edit
# or Write tool stay without one. args after the plugin root: those seats, as
# scripts/port.mjs read them off upstream's `tools:` lines.
#
# most of them also carry cursor's `readonly` (agents/<seat>.md), which cursor
# enforces itself; `planner` and `dispatch-auditor` can't — they write the store
# through the shell, which `readonly` refuses — so this is their line, and a
# second one for the rest. cursor names no subagent on a tool call, so the map
# is built at subagentStart (the Task call's tool_call_id → its subagent_type)
# and read at preToolUse through the call's parent_tool_call_id.
#
# fail open: an unmapped call is the lead's, or a seat this can't see — allowed.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
shift
seats=" $* "
input=$(cat) || exit 0
. "$plugin_root/hooks/cursor-state.sh" 2>/dev/null || exit 0
dir=$(kru_cursor_state subagents) || exit 0
safe() { case "$1" in ''|*/*|*..*|.*) return 1 ;; esac; return 0; }

case "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" in
  subagentStart)
    type=$(printf '%s' "$input" | jq -r '.subagent_type // empty' 2>/dev/null)
    for id in $(printf '%s' "$input" | jq -r '.tool_call_id // empty, .subagent_id // empty' 2>/dev/null); do
      safe "$id" && printf '%s\n' "$type" > "$dir/$id" 2>/dev/null
    done
    # keep the map bounded: a conversation's subagents, not a machine's history
    find "$dir" -type f -mtime +2 -delete 2>/dev/null
    exit 0 ;;
esac

parent=$(printf '%s' "$input" | jq -r '.parent_tool_call_id // empty' 2>/dev/null)
safe "$parent" || exit 0
[ -f "$dir/$parent" ] || exit 0
seat=$(cat "$dir/$parent" 2>/dev/null)
seat=${seat#kru-}
case "$seats" in *" $seat "*) ;; *) exit 0 ;; esac
tool=$(printf '%s' "$input" | jq -r '.cursor_tool_name // .tool_name // empty' 2>/dev/null)
printf 'kru: %s carries no edit tool (agents/%s.md) — it reports, and what it writes to the store goes through the shell as its prompt says. %s refused.\n' "$seat" "$seat" "$tool" >&2
exit 2
