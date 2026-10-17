#!/bin/bash
# Unit tests for MCP outbound classification (Gmail, Slack, Linear, GitHub, Google Docs).
# run: bash hooks/mcp-outbound-guard.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
classify="$root/scripts/cursor/mcp-outbound-classify.mjs"
denylist="$root/scripts/cursor/mcp-outbound-denylist.mjs"

pass=0 fail=0

run() {
  # run <expect 0|2> <name> <json>
  local code
  code=$(printf '%s' "$3" | node "$classify" 2>/dev/null; echo $?)
  if [ "$code" = "$1" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (want exit %s): %s\n  payload: %s\n' "$1" "$2" "$3"
    printf '%s' "$3" | node "$classify" 2>&1 | sed 's/^/  /'
  fi
}

payload_mcp() {
  jq -nc --arg t "$1" --argjson a "${2:-{}}" '{tool_name:$t, tool_input:$a, conversation_id:"t"}'
}
payload_dyn() {
  jq -nc --arg ns "$1" --arg tn "$2" '{tool_name:"CallDynamicTool", tool_input:{namespace:$ns, toolName:$tn}, conversation_id:"t"}'
}

# non-MCP passes through
run 0 "Read is not MCP" '{"tool_name":"Read","tool_input":{"path":"x"}}'

# allows — reads
run 0 "Linear list_teams" "$(payload_dyn Linear list_teams)"
run 0 "Linear list_issues" "$(payload_dyn Linear list_issues)"
run 0 "Linear get_issue" "$(payload_dyn Linear get_issue)"
run 0 "GitHub get_me (MCP form)" "$(payload_mcp 'MCP:GitHub:get_me')"
run 0 "Gmail list_labels" "$(payload_mcp 'MCP:Gmail:list_labels')"
run 0 "Gmail get_message" "$(payload_mcp 'MCP:Gmail:get_message')"
run 0 "Slack search_public" "$(payload_mcp 'MCP:Slack:slack_search_public')"
run 0 "Google Docs read_document" "$(payload_mcp 'MCP:Google-docs:read_document')"
run 0 "Gmail create_draft" "$(payload_mcp 'MCP:Gmail:create_draft')"
run 0 "Gmail update_draft" "$(payload_mcp 'MCP:Gmail:update_draft')"
run 0 "Slack send draft" "$(payload_mcp 'MCP:Slack:slack_send_message_draft')"

# denies — destructive / outbound
run 2 "Linear delete_comment" "$(payload_dyn Linear delete_comment)"
run 2 "Linear save_comment" "$(payload_dyn Linear save_comment)"
run 2 "Linear save_issue" "$(payload_dyn Linear save_issue)"
run 2 "Gmail send_message" "$(payload_mcp 'MCP:Gmail:send_message')"
run 2 "Gmail delete_draft" "$(payload_mcp 'MCP:Gmail:delete_draft')"
run 2 "Slack slack_send_message" "$(payload_mcp 'MCP:Slack:slack_send_message')"
run 2 "Slack add_reaction" "$(payload_mcp 'MCP:Slack:slack_add_reaction')"
run 2 "Slack create_canvas" "$(payload_mcp 'MCP:Slack:slack_create_canvas')"
run 2 "Google Docs insert_text" "$(payload_mcp 'MCP:Google-docs:insert_text')"
run 2 "GitHub create_pr" "$(payload_mcp 'MCP:GitHub:create_pr')"
run 2 "GitHub post_comment" "$(payload_mcp 'MCP:GitHub:post_comment')"
run 2 "legacy MCP deploy" "$(payload_mcp 'MCP:deploy')"

# module-level stem checks
(cd "$root" && node --input-type=module -e "
import { classifyMcpTool } from './scripts/cursor/mcp-outbound-denylist.mjs';
const deny = (stem) => classifyMcpTool({ id: 'x/'+stem, stem }).action === 'deny';
const allow = (stem) => classifyMcpTool({ id: 'x/'+stem, stem }).action === 'allow';
const cases = [
  ['list_teams', allow], ['delete_comment', deny], ['create_draft', allow], ['reply', deny],
];
let bad = 0;
for (const [s, fn] of cases) if (!fn(s)) { console.error('classify', s); bad++; }
process.exit(bad);
") && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: classifyMcpTool direct checks"; }

KRU_NO_MCP_OUTBOUND_GUARD=1 run 0 "kill switch" "$(payload_dyn Linear delete_comment)"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
