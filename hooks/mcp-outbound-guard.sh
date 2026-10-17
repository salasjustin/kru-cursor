#!/bin/bash
# preToolUse: block outbound/destructive team connector (MCP) calls on cloud agents.
# Matcher should cover CallDynamicTool and MCP:* tool names; non-MCP tools exit 0.
# Denylist: scripts/cursor/mcp-outbound-denylist.mjs
# Kill switch: KRU_NO_MCP_OUTBOUND_GUARD=1
plugin_root="${1:-${CURSOR_PLUGIN_ROOT:-}}"
[ -n "$plugin_root" ] || exit 0
script="$plugin_root/scripts/cursor/mcp-outbound-classify.mjs"
[ -f "$script" ] || exit 0
input=$(cat) || exit 0
[ -n "$input" ] || exit 0
printf '%s' "$input" | node "$script"
exit $?
