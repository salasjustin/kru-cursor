#!/bin/bash
# the one entry point hooks/hooks.json calls: cursor-hook.sh <event> <script> [args...]
#
# cursor runs a plugin's hook with the install dir as cwd (the workspace for
# stop and subagentStop), sends its own payload, and reads its own response
# schema. the hooks behind this file are upstream kru's, written against claude
# code's payload, plus the cursor-native ones (first-turn, prompt-state,
# require-lead, brainstorm-guard, seat-guard). this adapter is the seam:
#
#   in   cursor's payload, with the fields upstream reads added beside it —
#        session_id (cursor's conversation_id), cwd, tool_name in claude's
#        spelling (Shell→Bash, Task→Agent, Write/Delete→Write; cursor's own
#        kept as cursor_tool_name), a subagent_type flattened to a string, and
#        agent_type / last_assistant_message / stop_hook_active for subagentStop.
#   cwd  the project, so a hook's `git rev-parse` sees the repo, not the plugin.
#   out  cursor's schema. a permission hook (preToolUse, subagentStart) must
#        print valid json on every path — exit 0 with anything else blocks the
#        action — so: exit 2 → {"permission":"deny", …} with the hook's stderr
#        as the message; updatedInput → updated_input built from cursor's own
#        tool_input (only the prompt changes); anything else → allow. a stop
#        hook's {decision:"block",reason} becomes followup_message.
#
# fail open, like every upstream hook: a crash or a timeout is an allow, never a
# block. connector MCP fails closed on missing jq or invalid JSON (see
# mcp-outbound-guard.sh; jq gate below). KRU_HOOK_LOG=<file> appends one line per
# call (the harness reads it).
event=${1:-}
script=${2:-}
shift 2 2>/dev/null
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

case "$event" in
  preToolUse|subagentStart|beforeShellExecution|beforeReadFile|beforeMCPExecution) perm=true ;;
  *) perm=false ;;
esac
allow() {
  case "$event" in
    preToolUse|subagentStart|beforeShellExecution|beforeReadFile|beforeMCPExecution) printf '{"permission":"allow"}\n' ;;
    beforeSubmitPrompt) printf '{"continue":true}\n' ;;
    *) printf '{}\n' ;;
  esac
  exit 0
}
deny_mcp() {
  local msg=${1:-kru: MCP outbound guard failed. Denying connector MCP.}
  case "$event" in
    preToolUse|subagentStart|beforeShellExecution|beforeReadFile|beforeMCPExecution)
      jq -nc --arg m "$msg" '{permission: "deny", user_message: $m, agent_message: $m}'
      exit 0
      ;;
    beforeSubmitPrompt) jq -nc --arg m "$msg" '{continue: false, user_message: $m}'; exit 0 ;;
    *) allow ;;
  esac
}
mcp_payload_heuristic() {
  case "$1" in
    *CallDynamicTool*|*\"MCP:*|*mcp_server_name*) return 0 ;;
  esac
  return 1
}
mcp_guard_context() {
  [ "$event" = beforeMCPExecution ] && return 0
  [ "$script" = mcp-outbound-guard.sh ] && return 0
  return 1
}
input=$(cat 2>/dev/null)
if ! command -v jq >/dev/null 2>&1; then
  if mcp_guard_context || mcp_payload_heuristic "$input"; then
    deny_mcp "kru: MCP outbound guard requires jq. Denying connector MCP."
  fi
  allow
fi
[ -f "$root/hooks/$script" ] || allow
if ! printf '%s' "$input" | jq -e 'type == "object"' >/dev/null 2>&1; then
  if mcp_guard_context || mcp_payload_heuristic "$input"; then
    deny_mcp "kru: MCP outbound guard received invalid JSON. Denying connector MCP."
  fi
  allow
fi

norm=$(printf '%s' "$input" | jq -c --arg ev "$event" --arg pd "${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}" '
  def flat: if type == "object" or type == "array" then ([.. | strings] | first // "") else (. // "") end;
  . + {
    hook_event_name: $ev,
    session_id: (.session_id // .conversation_id // ""),
    cwd: (.cwd // (.workspace_roots // [])[0] // (if $pd == "" then null else $pd end))
  }
  | if has("tool_name") then
      .cursor_tool_name = .tool_name
      | .tool_name = ({"Shell": "Bash", "Task": "Agent", "Write": "Write", "Delete": "Write"}[.tool_name] // .tool_name)
    else . end
  | if (.tool_input | type) == "object" and (.tool_input | has("subagent_type")) then
      .tool_input.subagent_type |= flat
    else . end
  # a subagent event belongs to the lead'"'"'s conversation: its ledger is where
  # nudge-audit and the auditor look
  | if $ev == "subagentStop" or $ev == "subagentStart" then
      .session_id = (.parent_conversation_id // .session_id)
      | .subagent_type = (.subagent_type | flat)
      | .agent_type = .subagent_type
      | .last_assistant_message = (.summary // "")
      | .stop_hook_active = ((.loop_count // 0) > 0)
    else . end
  # a stop follow-up is guarded by the hook'"'"'s own mark (nudge-audit.sh), not by
  # loop_count, whose span the docs leave open
  | if $ev == "stop" then .stop_hook_active = false else . end
' 2>/dev/null) || allow

cwd=$(printf '%s' "$norm" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null

errf=$(mktemp 2>/dev/null) || {
  if mcp_guard_context || mcp_payload_heuristic "$input"; then
    deny_mcp "kru: MCP outbound guard could not run (mktemp failed). Denying connector MCP."
  fi
  allow
}
inf=$(mktemp 2>/dev/null) || {
  rm -f "$errf"
  if mcp_guard_context || mcp_payload_heuristic "$input"; then
    deny_mcp "kru: MCP outbound guard could not run (mktemp failed). Denying connector MCP."
  fi
  allow
}
trap 'rm -f "$errf" "$inf"' EXIT
# the original payload rides in a file: a long brief passed as an argument
# would hit the argv limit and silently lose the rewrite
printf '%s' "$input" > "$inf"
case "$script" in
  store-sync.sh) out=$(printf '%s' "$norm" | bash "$root/hooks/$script" "${1:-}" "$root" 2>"$errf") ;;
  *) out=$(printf '%s' "$norm" | bash "$root/hooks/$script" "$root" "$@" 2>"$errf") ;;
esac
code=$?
err=$(cat "$errf" 2>/dev/null)

if [ -n "${KRU_HOOK_LOG:-}" ]; then
  jq -nc --arg ev "$event" --arg s "$script" --argjson c "$code" --arg conv "$(printf '%s' "$norm" | jq -r '.session_id' 2>/dev/null)" \
    '{ts: (now | todate), event: $ev, script: $s, exit: $c, conversation: $conv}' >> "$KRU_HOOK_LOG" 2>/dev/null
fi

# a deny, from either side's spelling
if [ "$code" = 2 ]; then
  if $perm; then
    msg=${err:-kru: refused by $script}
    jq -nc --arg m "$msg" '{permission: "deny", user_message: $m, agent_message: $m}'
    exit 0
  fi
  case "$event" in
    beforeSubmitPrompt) jq -nc --arg m "${err:-kru: refused}" '{continue: false, user_message: $m}'; exit 0 ;;
  esac
  allow
fi
if [ "$code" != 0 ] && [ "$code" != 2 ]; then
  if [ "$script" = mcp-outbound-guard.sh ] || mcp_payload_heuristic "$input" || [ "$event" = beforeMCPExecution ]; then
    msg=${err:-kru: MCP outbound guard failed (exit $code). Denying connector MCP.}
    deny_mcp "$msg"
  fi
  [ -n "$err" ] && printf '%s\n' "$err" >&2
  allow
fi
[ -n "$err" ] && printf '%s\n' "$err" >&2
# one answer, the hook's last json object; anything else is an allow
out=$(printf '%s' "$out" | jq -cs 'map(select(type == "object")) | last // empty' 2>/dev/null)
[ -n "$out" ] || allow

case "$event" in
  preToolUse|subagentStart|beforeMCPExecution)
    # rebuilt from named fields only, so a hook can never hand cursor a key or
    # a value outside the schema
    printf '%s' "$out" | jq -c --slurpfile o "$inf" '
      $o[0] as $orig
      | if .permission == "deny" then
        {permission: "deny", user_message: (.user_message // .agent_message // "kru: refused"),
         agent_message: (.agent_message // .user_message // "kru: refused")}
      elif .permission == "allow" then
        {permission: "allow"}
        + (if (.updated_input | type) == "object" then {updated_input} else {} end)
        + (if (.additional_context // "") != "" then {additional_context} else {} end)
      elif .hookSpecificOutput.permissionDecision == "deny" then
        {permission: "deny", user_message: (.hookSpecificOutput.permissionDecisionReason // "kru: refused"),
         agent_message: (.hookSpecificOutput.permissionDecisionReason // "kru: refused")}
      else
        {permission: "allow"}
        + (if (.hookSpecificOutput.updatedInput.prompt? // null) != null and ($orig.tool_input | type) == "object"
           then {updated_input: ($orig.tool_input + {prompt: .hookSpecificOutput.updatedInput.prompt})} else {} end)
        + (if (.hookSpecificOutput.additionalContext // "") != "" then {additional_context: .hookSpecificOutput.additionalContext} else {} end)
      end' 2>/dev/null || allow
    ;;
  stop|subagentStop)
    printf '%s' "$out" | jq -c '
      if has("followup_message") then {followup_message}
      elif .decision == "block" and (.reason // "") != "" then {followup_message: .reason}
      else {} end' 2>/dev/null || allow
    printf '%s' "$out" | jq -r '.systemMessage // empty' 2>/dev/null >&2
    ;;
  sessionStart|postToolUse)
    printf '%s' "$out" | jq -c '
      (.additional_context // .hookSpecificOutput.additionalContext // "") as $c
      | if $c == "" then {} else {additional_context: $c} end' 2>/dev/null || allow
    printf '%s' "$out" | jq -r '.systemMessage // empty' 2>/dev/null >&2
    ;;
  beforeSubmitPrompt)
    printf '%s' "$out" | jq -c 'if has("continue") then . else {continue: true} end' 2>/dev/null || allow
    ;;
  *) allow ;;
esac
exit 0
