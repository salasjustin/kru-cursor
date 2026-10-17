#!/bin/bash
# DIAGNOSTIC (branch-only): append hook metadata to /tmp/kru-hook-trace.log — no args/secrets.
# Safe to remove after confirming cloud-agent hook tool names and matchers.
set -u
event=${1:-unknown}
log="${KRU_HOOK_TRACE:-/tmp/kru-hook-trace.log}"
input=$(cat 2>/dev/null) || input="{}"

if command -v jq >/dev/null 2>&1; then
  line=$(printf '%s' "$input" | jq -c --arg ev "$event" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)" '
    {
      ts: $ts,
      hook: $ev,
      tool_name: (.tool_name // null),
      mcp_server_name: (.mcp_server_name // null),
      hook_event_name: (.hook_event_name // null),
      keys: (keys | sort),
      dynamic: (
        if (.tool_input | type) == "object" then
          {namespace: (.tool_input.namespace // null), toolName: (.tool_input.toolName // null)}
        else null end
      )
    }
  ' 2>/dev/null) || line=$(jq -nc --arg ev "$event" --arg ts "$(date +%s)" '{ts:$ts, hook:$ev, parse_error:true}')
  printf '%s\n' "$line" >>"$log" 2>/dev/null || true
fi

case "$event" in
  preToolUse|beforeMCPExecution|subagentStart|beforeShellExecution|beforeReadFile)
    printf '{"permission":"allow"}\n'
    ;;
esac
exit 0
