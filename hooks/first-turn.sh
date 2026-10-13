#!/bin/bash
# sessionStart locally, and the first preToolUse of a conversation everywhere:
# the work upstream runs at session start — store-sync's pull and the
# /kru-setup nudge — once per conversation. a cloud agent never runs
# sessionStart (cursor.com/docs/hooks → Cloud agent support), so the first tool
# call is the earliest moment a hook sees there; a local session gets it from
# sessionStart and the mark makes the preToolUse pass a no-op.
#
# the mark lives in a temp dir keyed by the conversation id: session-lived
# state, the same lifetime as the conversation it marks. a subagent's tool call
# (parent_tool_call_id set) is the lead's conversation's business, not its own.
# fail open: an allow, whatever happens.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
input=$(cat) || exit 0

conv=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$conv" ] || exit 0
[ -n "$(printf '%s' "$input" | jq -r '.parent_tool_call_id // empty' 2>/dev/null)" ] && exit 0
case "$conv" in */*|*..*) exit 0 ;; esac
state="${TMPDIR:-/tmp}/kru-cursor-$(id -u)/$conv"
mkdir -p "$state" 2>/dev/null || exit 0
[ -e "$state/started" ] && exit 0
: > "$state/started"

sync=$(printf '%s' "$input" | bash "$plugin_root/hooks/store-sync.sh" start "$plugin_root" 2>/dev/null)
nudge=$(printf '%s' "$input" | bash "$plugin_root/hooks/setup-nudge.sh" "$plugin_root" 2>/dev/null)

# both speak claude's sessionStart shape; cursor-hook.sh maps the result
jq -nc --arg a "$sync" --arg b "$nudge" '
  def j: try fromjson catch {};
  ($a | j) as $s | ($b | j) as $n
  | ([$s.hookSpecificOutput.additionalContext, $n.hookSpecificOutput.additionalContext] | map(select(. != null and . != "")) | join("\n\n")) as $ctx
  | {}
  + (if $ctx != "" then {hookSpecificOutput: {additionalContext: $ctx}} else {} end)
  + (if ($s.systemMessage // "") != "" then {systemMessage: $s.systemMessage} else {} end)'
exit 0
