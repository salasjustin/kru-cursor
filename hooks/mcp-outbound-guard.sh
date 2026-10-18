#!/bin/bash
# preToolUse / beforeMCPExecution: block outbound team connector MCP when Cursor runs these hooks.
# Project hooks (`.cursor/hooks.json`) invoke this from the repo root; plugin hooks use cursor-hook.sh.
# Denylist: scripts/cursor/mcp-outbound-denylist.mjs
# Kill switch: KRU_NO_MCP_OUTBOUND_GUARD=1
# Cursor cloud agents do not currently run hooks for MCP connector calls (verified Oct 2026);
# rules/kru-lead.mdc is the only guard there. Optional trace: set KRU_HOOK_TRACE to a log path.
set -u

resolve_root() {
  if [ -n "${1:-}" ]; then
    printf '%s' "$1"
    return
  fi
  if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
    printf '%s' "$CURSOR_PROJECT_DIR"
    return
  fi
  local self_root
  self_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  printf '%s' "$self_root"
}

emit_allow() {
  printf '{"permission":"allow"}\n'
  exit 0
}

emit_deny() {
  local msg=${1:-kru: MCP outbound action denied}
  printf '%s\n' "$msg" >&2
  jq -nc --arg m "$msg" '{permission: "deny", user_message: $m, agent_message: $m}'
  exit 2
}

trace_line() {
  [ -n "${KRU_HOOK_TRACE:-}" ] || return 0
  local kind=$1 payload=$2
  command -v jq >/dev/null 2>&1 || return 0
  local line
  line=$(printf '%s' "$payload" | jq -c --arg k "$kind" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)" \
    '{ts:$ts, source:"mcp-outbound-guard", kind:$k, tool_name:(.tool_name//null), mcp_server_name:(.mcp_server_name//null), decision:(.decision//null)}' 2>/dev/null) || return 0
  printf '%s\n' "$line" >>"$KRU_HOOK_TRACE" 2>/dev/null || true
}

looks_like_mcp() {
  # jq-only probe when the classifier script is missing (fail closed for MCP only).
  printf '%s' "$1" | jq -e '
    def dyn_cursor: (.tool_name == "CallDynamicTool") and (.tool_input.namespace? == "cursor");
    if dyn_cursor then false
    elif .tool_name == "CallDynamicTool" then true
    elif (.tool_name // "") | test("^MCP:") then true
    elif (has("mcp_server_name") and (.mcp_server_name | type) == "string" and (.mcp_server_name | length) > 0) then
      (.mcp_server_name != "cursor")
    else false end
  ' >/dev/null 2>&1
}

root=$(resolve_root "${1:-}")
classify="$root/scripts/cursor/mcp-outbound-classify.mjs"

input=$(cat 2>/dev/null) || input=""
[ -n "$input" ] || emit_allow

if [ "${KRU_NO_MCP_OUTBOUND_GUARD:-}" = "1" ]; then
  emit_allow
fi

if [ ! -f "$classify" ]; then
  if looks_like_mcp "$input"; then
    emit_deny "kru: MCP outbound guard is misconfigured (missing classifier at scripts/cursor/mcp-outbound-classify.mjs). Denying connector MCP until project hooks point at the repo copy."
  fi
  emit_allow
fi

errf=$(mktemp 2>/dev/null) || emit_allow
out=$(printf '%s' "$input" | node "$classify" 2>"$errf")
code=$?
err=$(cat "$errf" 2>/dev/null)
rm -f "$errf"

if [ "$code" = 2 ]; then
  msg=${err:-kru: this cloud agent cannot send, post, share, or delete through team connectors (MCP). Hand this action back to the PM bot to run outside the agent.}
  trace_line "deny" "$(printf '%s' "$input" | jq -c --arg d "deny" '. + {decision:$d}' 2>/dev/null || printf '{}')"
  emit_deny "$msg"
fi

trace_line "allow" "$(printf '%s' "$input" | jq -c --arg d "allow" '. + {decision:$d}' 2>/dev/null || printf '{}')"
emit_allow
