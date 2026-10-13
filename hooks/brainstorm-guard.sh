#!/bin/bash
# pretooluse on Shell|Write|Delete: the mechanized half of /kru-brainstorm's
# "write nothing". from the user's /kru-brainstorm until their go — a turn that
# opens with "go" or "brief it", or a /kru-brief — every write is refused;
# read-only shell passes.
#
# cursor-native rewrite of upstream's brainstorm-guard.sh (hand-owned,
# PORTING.md): upstream reads the lock out of claude's transcript; here
# hooks/prompt-state.sh sets and lifts it at beforeSubmitPrompt, from the
# user's own words, so a second brainstorm in the same conversation locks again
# with nothing to reset. fail open on anything that isn't a clear lock.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
input=$(cat) || exit 0
conv=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$conv" ] || exit 0
case "$conv" in */*|*..*) exit 0 ;; esac
[ -e "${TMPDIR:-/tmp}/kru-cursor-$(id -u)/$conv/brainstorm.lock" ] || exit 0

tool=$(printf '%s' "$input" | jq -r '.cursor_tool_name // .tool_name // empty' 2>/dev/null)
if [ "$tool" = "Shell" ] || [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  . "$plugin_root/hooks/readonly-bash.sh" 2>/dev/null || exit 0
  kru_readonly_bash "$cmd" && exit 0
fi

printf 'kru: /kru-brainstorm writes nothing until the user says go — reads stay open. Keep grilling; the brief is written on their go.\n' >&2
exit 2
