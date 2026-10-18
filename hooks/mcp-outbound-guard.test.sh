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
run 0 "Linear save_issue" "$(payload_dyn Linear save_issue)"
run 0 "cursor namespace CallDynamicTool" "$(payload_dyn cursor Delete)"
run 2 "Gmail send_message" "$(payload_mcp 'MCP:Gmail:send_message')"
run 2 "Gmail delete_draft" "$(payload_mcp 'MCP:Gmail:delete_draft')"
run 2 "Slack slack_send_message" "$(payload_mcp 'MCP:Slack:slack_send_message')"
run 2 "Slack add_reaction" "$(payload_mcp 'MCP:Slack:slack_add_reaction')"
run 2 "Slack create_canvas" "$(payload_mcp 'MCP:Slack:slack_create_canvas')"
run 2 "Google Docs insert_text" "$(payload_mcp 'MCP:Google-docs:insert_text')"
run 2 "GitHub create_pr" "$(payload_mcp 'MCP:GitHub:create_pr')"
run 2 "GitHub post_comment" "$(payload_mcp 'MCP:GitHub:post_comment')"
run 2 "GitHub add_issue_comment" "$(payload_mcp 'MCP:GitHub:add_issue_comment')"
run 2 "GitHub create_pull_request" "$(payload_mcp 'MCP:GitHub:create_pull_request')"
run 2 "GitHub update_pull_request" "$(payload_mcp 'MCP:GitHub:update_pull_request')"
run 2 "GitHub push_files" "$(payload_mcp 'MCP:GitHub:push_files')"
run 2 "GitHub create_or_update_file" "$(payload_mcp 'MCP:GitHub:create_or_update_file')"
run 2 "GitHub merge_pull_request" "$(payload_mcp 'MCP:GitHub:merge_pull_request')"
run 2 "GitHub delete_file" "$(payload_mcp 'MCP:GitHub:delete_file')"
run 2 "GitHub create_branch" "$(payload_mcp 'MCP:GitHub:create_branch')"
run 2 "GitHub issue_write" "$(payload_mcp 'MCP:GitHub:issue_write')"
run 2 "GitHub update_issue_comment" "$(payload_mcp 'MCP:GitHub:update_issue_comment')"
run 2 "GitHub pull_request_review_write" "$(payload_mcp 'MCP:GitHub:pull_request_review_write')"
run 2 "GitHub add_reply_to_pull_request_comment" "$(payload_mcp 'MCP:GitHub:add_reply_to_pull_request_comment')"
run 2 "GitHub create_pull_request_review" "$(payload_mcp 'MCP:GitHub:create_pull_request_review')"
run 2 "GitHub add_comment_to_pending_review" "$(payload_mcp 'MCP:GitHub:add_comment_to_pending_review')"
run 2 "legacy MCP deploy" "$(payload_mcp 'MCP:deploy')"
run 0 "MCP:cursor:Delete allowed" "$(payload_mcp 'MCP:cursor:Delete')"
run 2 "Google Docs create_list" "$(payload_mcp 'MCP:Google-docs:create_list')"
run 2 "Google Docs set_paragraph_format" "$(payload_mcp 'MCP:Google-docs:set_paragraph_format')"
run 2 "Google Docs set_table_column_width" "$(payload_mcp 'MCP:Google-docs:set_table_column_width')"
run 2 "Google Docs set_table_cell_shading" "$(payload_mcp 'MCP:Google-docs:set_table_cell_shading')"
run 2 "Google Docs insert_page_break" "$(payload_mcp 'MCP:Google-docs:insert_page_break')"
run 0 "Google Docs find_text" "$(payload_mcp 'MCP:Google-docs:find_text')"
run 2 "Slack slack_complete_file_upload" "$(payload_mcp 'MCP:Slack:slack_complete_file_upload')"
run 2 "Gmail create_filter" "$(payload_mcp 'MCP:Gmail:create_filter')"
run 2 "Linear create_attachment" "$(payload_dyn Linear create_attachment)"
run 2 "Linear create_attachment_from_upload" "$(payload_dyn Linear create_attachment_from_upload)"
run 2 "Linear unshare_issue" "$(payload_dyn Linear unshare_issue)"
run 2 "Gmail untrash_thread" "$(payload_mcp 'MCP:Gmail:untrash_thread')"
run 2 "Gmail untrash_message" "$(payload_mcp 'MCP:Gmail:untrash_message')"
run 2 "Slack slack_create_conversation" "$(payload_mcp 'MCP:Slack:slack_create_conversation')"
run 2 "Slack slack_update_list" "$(payload_mcp 'MCP:Slack:slack_update_list')"
run 2 "Slack slack_add_list_record" "$(payload_mcp 'MCP:Slack:slack_add_list_record')"
run 2 "Slack slack_create_list" "$(payload_mcp 'MCP:Slack:slack_create_list')"
run 2 "beforeMCPExecution delete_comment" "$(jq -nc '{tool_name:"delete_comment",mcp_server_name:"Linear",hook_event_name:"beforeMCPExecution"}')"

# module-level stem checks
(cd "$root" && node --input-type=module -e "
import { classifyMcpTool } from './scripts/cursor/mcp-outbound-denylist.mjs';
const deny = (stem) => classifyMcpTool({ id: 'x/'+stem, stem }).action === 'deny';
const allow = (stem) => classifyMcpTool({ id: 'x/'+stem, stem }).action === 'allow';
const cases = [
  ['list_teams', allow], ['delete_comment', deny], ['create_draft', allow], ['reply', deny],
  ['add_issue_comment', deny], ['create_pull_request', deny], ['push_files', deny],
  ['create_or_update_file', deny], ['merge_pull_request', deny], ['slack_complete_file_upload', deny],
  ['create_filter', deny], ['create_attachment', deny], ['unshare_issue', deny],
];
let bad = 0;
for (const [s, fn] of cases) if (!fn(s)) { console.error('classify', s); bad++; }
process.exit(bad);
") && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: classifyMcpTool direct checks"; }

KRU_NO_MCP_OUTBOUND_GUARD=1 run 0 "kill switch" "$(payload_dyn Linear delete_comment)"

# project-hook path: must emit cursor permission JSON (not only exit codes)
resp=$(printf '%s' "$(payload_dyn Linear list_teams)" | bash "$here/mcp-outbound-guard.sh" "$root" 2>/dev/null)
if printf '%s' "$resp" | jq -e '.permission == "allow"' >/dev/null 2>&1; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo "FAIL: guard project allow JSON"; echo "  resp: $resp"
fi
resp=$(printf '%s' "$(payload_dyn Linear delete_comment)" | bash "$here/mcp-outbound-guard.sh" "$root" 2>/dev/null; true)
if printf '%s' "$resp" | jq -e '.permission == "deny"' >/dev/null 2>&1; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo "FAIL: guard project deny JSON"; echo "  resp: $resp"
fi
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
resp=$(printf '%s' "$(payload_dyn Linear delete_comment)" | bash "$here/mcp-outbound-guard.sh" "$tmpdir" 2>/dev/null; true)
if printf '%s' "$resp" | jq -e '.permission == "deny" and (.agent_message | test("misconfigured"))' >/dev/null 2>&1; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL: missing classifier should fail closed for MCP"; echo "  resp: $resp"
fi

broken_classify="$tmpdir/scripts/cursor/mcp-outbound-classify.mjs"
mkdir -p "$tmpdir/scripts/cursor"
printf '#!/usr/bin/env node\nprocess.exit(1)\n' > "$broken_classify"
chmod +x "$broken_classify"
resp=$(printf '%s' "$(payload_dyn Linear list_teams)" | bash "$here/mcp-outbound-guard.sh" "$tmpdir" 2>/dev/null; true)
if printf '%s' "$resp" | jq -e '.permission == "deny" and (.agent_message | test("classifier failed"))' >/dev/null 2>&1; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL: classifier non-zero should fail closed for MCP"; echo "  resp: $resp"
fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
