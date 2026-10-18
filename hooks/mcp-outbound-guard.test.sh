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

# round-2 must-deny (default-deny allowlist)
run 2 "GitHub discussion_comment_write" "$(payload_mcp 'MCP:GitHub:discussion_comment_write')"
run 2 "GitHub sub_issue_write" "$(payload_mcp 'MCP:GitHub:sub_issue_write')"
run 2 "GitHub label_write" "$(payload_mcp 'MCP:GitHub:label_write')"
run 2 "GitHub projects_write" "$(payload_mcp 'MCP:GitHub:projects_write')"
run 2 "GitHub issue_dependency_write" "$(payload_mcp 'MCP:GitHub:issue_dependency_write')"
run 2 "GitHub custom_properties_write" "$(payload_mcp 'MCP:GitHub:custom_properties_write')"
run 2 "GitHub actions_run_trigger" "$(payload_mcp 'MCP:GitHub:actions_run_trigger')"
run 2 "GitHub assign_copilot_to_issue" "$(payload_mcp 'MCP:GitHub:assign_copilot_to_issue')"
run 2 "GitHub assign_copilot_to_issue_with_intent" "$(payload_mcp 'MCP:GitHub:assign_copilot_to_issue_with_intent')"
run 2 "GitHub request_copilot_review" "$(payload_mcp 'MCP:GitHub:request_copilot_review')"
run 2 "GitHub create_gist" "$(payload_mcp 'MCP:GitHub:create_gist')"
run 2 "GitHub update_gist" "$(payload_mcp 'MCP:GitHub:update_gist')"
run 2 "GitHub create_repository" "$(payload_mcp 'MCP:GitHub:create_repository')"
run 2 "GitHub fork_repository" "$(payload_mcp 'MCP:GitHub:fork_repository')"
run 2 "GitHub create_repository_ruleset" "$(payload_mcp 'MCP:GitHub:create_repository_ruleset')"
run 2 "GitHub star_repository" "$(payload_mcp 'MCP:GitHub:star_repository')"
run 2 "GitHub unstar_repository" "$(payload_mcp 'MCP:GitHub:unstar_repository')"
run 2 "GitHub dismiss_notification" "$(payload_mcp 'MCP:GitHub:dismiss_notification')"
run 2 "GitHub manage_notification_subscription" "$(payload_mcp 'MCP:GitHub:manage_notification_subscription')"
run 2 "GitHub mark_all_notifications_read" "$(payload_mcp 'MCP:GitHub:mark_all_notifications_read')"
run 2 "Gmail label_thread" "$(payload_mcp 'MCP:Gmail:label_thread')"
run 2 "Gmail unlabel_thread" "$(payload_mcp 'MCP:Gmail:unlabel_thread')"
run 2 "Gmail label_message" "$(payload_mcp 'MCP:Gmail:label_message')"
run 2 "Gmail unlabel_message" "$(payload_mcp 'MCP:Gmail:unlabel_message')"
run 2 "Gmail update_message_labels" "$(payload_mcp 'MCP:Gmail:update_message_labels')"
run 2 "Gmail apply_sensitive_thread_label" "$(payload_mcp 'MCP:Gmail:apply_sensitive_thread_label')"
run 2 "Gmail apply_sensitive_message_label" "$(payload_mcp 'MCP:Gmail:apply_sensitive_message_label')"
run 2 "Gmail mark_thread_spam" "$(payload_mcp 'MCP:Gmail:mark_thread_spam')"
run 2 "Gmail unmark_thread_spam" "$(payload_mcp 'MCP:Gmail:unmark_thread_spam')"
run 2 "Gmail mark_message_spam" "$(payload_mcp 'MCP:Gmail:mark_message_spam')"
run 2 "Gmail unmark_message_spam" "$(payload_mcp 'MCP:Gmail:unmark_message_spam')"
run 2 "Gmail create_label" "$(payload_mcp 'MCP:Gmail:create_label')"
run 2 "Gmail update_label" "$(payload_mcp 'MCP:Gmail:update_label')"
run 2 "Linear update_diff" "$(payload_dyn Linear update_diff)"
run 2 "Linear resolve_diff_thread" "$(payload_dyn Linear resolve_diff_thread)"
run 2 "Linear retire_issue_label" "$(payload_dyn Linear retire_issue_label)"
run 2 "Linear restore_issue_label" "$(payload_dyn Linear restore_issue_label)"
run 2 "Linear create_initiative_label" "$(payload_dyn Linear create_initiative_label)"
run 2 "Linear mark_notification" "$(payload_dyn Linear mark_notification)"
run 2 "Slack slack_update_list_record" "$(payload_mcp 'MCP:Slack:slack_update_list_record')"
run 2 "Slack slack_get_file_upload_url" "$(payload_mcp 'MCP:Slack:slack_get_file_upload_url')"
run 2 "Linear prepare_attachment_upload" "$(payload_dyn Linear prepare_attachment_upload)"

# round-2 must-allow
run 0 "GitHub pull_request_read" "$(payload_mcp 'MCP:GitHub:pull_request_read')"
run 0 "GitHub list_pull_requests" "$(payload_mcp 'MCP:GitHub:list_pull_requests')"
run 0 "GitHub search_pull_requests" "$(payload_mcp 'MCP:GitHub:search_pull_requests')"
run 0 "GitHub issue_read" "$(payload_mcp 'MCP:GitHub:issue_read')"
run 0 "GitHub get_file_contents" "$(payload_mcp 'MCP:GitHub:get_file_contents')"
run 0 "Slack slack_read_channel" "$(payload_mcp 'MCP:Slack:slack_read_channel')"
run 0 "Gmail get_draft" "$(payload_mcp 'MCP:Gmail:get_draft')"
run 0 "Gmail list_drafts" "$(payload_mcp 'MCP:Gmail:list_drafts')"
run 0 "Context7 resolve-library-id" "$(payload_dyn Context7 resolve-library-id)"

# module-level stem checks
(cd "$root" && node --input-type=module -e "
import { classifyMcpTool } from './scripts/cursor/mcp-outbound-denylist.mjs';
const deny = (stem) => classifyMcpTool({ id: 'x/'+stem, stem }).action === 'deny';
const allow = (stem) => classifyMcpTool({ id: 'x/'+stem, stem }).action === 'allow';
const cases = [
  ['list_teams', allow], ['delete_comment', deny], ['create_draft', allow], ['pull_request_read', allow],
  ['add_issue_comment', deny], ['create_pull_request', deny], ['push_files', deny],
  ['discussion_comment_write', deny], ['prepare_attachment_upload', deny],
  ['slack_get_file_upload_url', deny], ['save_issue', allow],
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

resp=$(printf '%s' 'not-json' | bash "$here/mcp-outbound-guard.sh" "$root" 2>/dev/null; true)
if printf '%s' "$resp" | jq -e '.permission == "allow"' >/dev/null 2>&1; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo "FAIL: non-MCP invalid JSON should allow"; echo "  resp: $resp"
fi
resp=$(printf '%s' '{"tool_name":"CallDynamicTool","tool_input":{"namespace":"Linear","toolName":"list_teams"},broken' | bash "$here/mcp-outbound-guard.sh" "$root" 2>/dev/null; true)
if printf '%s' "$resp" | jq -e '.permission == "deny"' >/dev/null 2>&1; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo "FAIL: MCP invalid JSON should deny"; echo "  resp: $resp"
fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
