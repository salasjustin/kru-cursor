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
. "$plugin_root/hooks/cursor-state.sh" 2>/dev/null || exit 0
state=$(kru_cursor_state "$conv") || exit 0
# mkdir is the atomic test-and-set: parallel tool calls fire this hook
# concurrently, and only the one that creates the mark runs the work
mkdir "$state/started" 2>/dev/null || exit 0

# the store's first pull gets the budget of the hook it runs in: sessionStart
# waits up to 60s, the first tool call 15s (hooks.json), and the setup nudge
# runs after it. an explicit KRU_STORE_SYNC_TIMEOUT wins
if [ -z "${KRU_STORE_SYNC_TIMEOUT:-}" ]; then
  case "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" in
    sessionStart) export KRU_STORE_SYNC_TIMEOUT=45 ;;
    *) export KRU_STORE_SYNC_TIMEOUT=10 ;;
  esac
fi
sync=$(printf '%s' "$input" | bash "$plugin_root/hooks/store-sync.sh" start "$plugin_root" 2>/dev/null)
nudge=$(printf '%s' "$input" | bash "$plugin_root/hooks/setup-nudge.sh" "$plugin_root" 2>/dev/null)

# names Cursor will actually offer the Task tool. plugin agents/ is not one of
# these dirs (cursor.com/docs/subagents → File locations). same cloud test as
# scripts/kru-store.sh kru_is_cloud.
front_name() {
  local line
  line=$(awk 'BEGIN{fm=0} /^---$/{fm++; if(fm==2) exit; next} fm==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$1")
  line=${line#\"}; line=${line%\"}; line=${line#\'}; line=${line%\'}
  printf '%s' "$line"
}
registered_names() {
  local d f name
  for d in "$@"; do
    [ -d "$d" ] || continue
    for f in "$d"/*.md; do
      [ -f "$f" ] || continue
      name=$(front_name "$f")
      [ -n "$name" ] && printf '%s\n' "$name"
    done
  done
}
plugin_kru=0
if [ -d "$plugin_root/agents" ]; then
  for f in "$plugin_root/agents"/*.md; do
    [ -f "$f" ] || continue
    front_name "$f" | grep -q '^kru-' && plugin_kru=$((plugin_kru + 1))
  done
fi
reg_dirs=("$PWD/.cursor/agents" "$PWD/.claude/agents" "$PWD/.codex/agents")
if [ -n "${HOME:-}" ]; then
  reg_dirs+=("$HOME/.cursor/agents" "$HOME/.claude/agents" "$HOME/.codex/agents")
fi
names=$(registered_names "${reg_dirs[@]}" | sort -u)
kru=$(printf '%s\n' "$names" | grep '^kru-' || true)
if [ -n "$kru" ]; then
  seats_msg="Registered subagents: $(printf '%s\n' "$kru" | paste -sd ', ' -)"
  seats_sys=""
else
  shown=${names:-none}
  seats_msg="KRU SEATS MISSING from Cursor's subagent load paths (.cursor/agents, .claude/agents, .codex/agents, and the same three under the home directory). Registered subagents: ${shown}. Plugin agents on disk whose name starts with kru-: ${plugin_kru}. If the Task tool does not offer a kru-<seat> subagent_type, report and stop rather than going inline."
  seats_sys="$seats_msg"
fi
# a cloud agent with no kru seat in those dirs is the session that does the
# seat's work itself. refuse the first tool of the conversation and say why.
# the mark above makes it once. KRU_CLOUD=0 keeps a machine with the metadata
# socket on the local path (scripts/kru-store.sh).
kru_is_cloud=1
[ "${KRU_CLOUD:-}" = "0" ] && kru_is_cloud=0
if [ "$kru_is_cloud" = 1 ]; then
  [ "${KRU_CLOUD:-}" = "1" ] || [ -n "${CURSOR_AGENT_SOCKET:-}" ] || [ -S /run/cursor/api.sock ] || kru_is_cloud=0
fi
if [ -z "$kru" ] && [ "$kru_is_cloud" = 1 ]; then
  printf '%s\n' "$seats_msg" >&2
  exit 2
fi

# both speak claude's sessionStart shape; cursor-hook.sh maps the result
jq -nc --arg a "$sync" --arg b "$nudge" --arg c "$seats_msg" --arg m "$seats_sys" '
  def j: try fromjson catch {};
  ($a | j) as $s | ($b | j) as $n
  | ([$s.hookSpecificOutput.additionalContext, $n.hookSpecificOutput.additionalContext, $c] | map(select(. != null and . != "")) | join("\n\n")) as $ctx
  | ([$s.systemMessage, $m] | map(select(. != null and . != "")) | join("\n")) as $sys
  | {}
  + (if $ctx != "" then {hookSpecificOutput: {additionalContext: $ctx}} else {} end)
  + (if $sys != "" then {systemMessage: $sys} else {} end)'
exit 0
