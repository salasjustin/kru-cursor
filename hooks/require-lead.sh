#!/bin/bash
# pretooluse on every tool: the mechanized half of the lead contract's own
# precondition — skills/kru-lead/SKILL.md loaded before building, reviewing or
# dispatching a seat. rules/kru-lead.mdc says so in every conversation; an
# instruction is discretionary and a hook is not.
#
# cursor-native rewrite of upstream's require-lead.sh (hand-owned, PORTING.md):
# upstream reads claude's transcript for the skill load, cursor's transcript is
# another format and may be absent, so the evidence here is what cursor shows a
# hook —
#   - the agent reading skills/kru-lead/SKILL.md (how cursor loads a skill the
#     agent picks), marked on the spot;
#   - the user typing /kru-lead, or any /kru-<command> as the latest word
#     (hooks/prompt-state.sh records both at beforeSubmitPrompt).
# the transcript is not read: an always-on rule naming /kru-lead may sit in it
# whether or not the skill was ever loaded.
#
# it gates the first tool call that could build — a write, a delete, a
# dispatch, an mcp call, a shell command that doesn't only read — named one by
# one, so a tool this list doesn't know (a fetch, a lint read, a question to the
# user, the todo list) passes. reads pass too: cursor loads a skill by reading
# it, so gating the first read would close the only door out.
#
# once per conversation: the mark is written whether or not the block lands, so
# a conversation that declines is nagged no further. a subagent's call
# (parent_tool_call_id set) never trips a gate meant for the lead. fail open on
# anything that isn't a clear miss. kill switch: touch the resolver's
# `lead-gate/off`, or export KRU_NO_LEAD_GATE=1.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
[ -n "$KRU_NO_LEAD_GATE" ] && exit 0
[ -e "$(kru_path lead-gate/off)" ] && exit 0
[ -f "$plugin_root/skills/kru-lead/SKILL.md" ] || exit 0
input=$(cat) || exit 0

conv=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$conv" ] || exit 0
[ -n "$(printf '%s' "$input" | jq -r '.parent_tool_call_id // empty' 2>/dev/null)" ] && exit 0
. "$plugin_root/hooks/cursor-state.sh" 2>/dev/null || exit 0
state=$(kru_cursor_state "$conv") || exit 0

tool=$(printf '%s' "$input" | jq -r '.cursor_tool_name // .tool_name // empty' 2>/dev/null)
case "$tool" in
  Shell|Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    . "$plugin_root/hooks/readonly-bash.sh" 2>/dev/null || exit 0
    if kru_readonly_bash "$cmd"; then
      printf '%s' "$cmd" | grep -qE 'skills/kru-lead/SKILL\.md' && : > "$state/lead.loaded"
      exit 0
    fi ;;
  Write|Edit|MultiEdit|StrReplace|ApplyPatch|NotebookEdit|Delete|Task|Agent|MCP*|mcp*) ;;
  *)
    # a read, or a tool this gate doesn't build with; reading the skill loads it
    printf '%s' "$input" | jq -r '.tool_input | [.. | strings] | .[]' 2>/dev/null |
      grep -qE '(^|/)skills/kru-lead/SKILL\.md$' && : > "$state/lead.loaded"
    exit 0 ;;
esac

[ -e "$state/lead.loaded" ] && exit 0
# a /kru-<command> run is that command's contract, not the lead's — the ones
# that dispatch load the lead themselves — while it is still the latest word
[ -s "$state/command" ] && exit 0

# atomic, so parallel tool calls produce one refusal, not one each
mkdir "$state/lead-gated" 2>/dev/null || exit 0
printf 'kru: this conversation has not loaded the lead contract. Load the kru-lead skill (read %s/skills/kru-lead/SKILL.md), then take the action again — nothing else about the request has changed. This fires once per conversation, from the kru-cursor plugin, and reads are exempt. To run without it: touch %s\n' "$plugin_root" "$(kru_path lead-gate/off)" >&2
exit 2
