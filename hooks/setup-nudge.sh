#!/bin/bash
# sessionstart: a repo that never ran /kru-setup has no sheet, so the lead routes
# with no answers and the seats work from defaults. the stamp setup writes into
# .claude/CLAUDE.md is the one proof it ran, and its absence is the only thing
# this checks — whether the sheet is *behind* is lead Step 0's, read from the
# stamp itself.
#
# an alert, never a block: a greenfield session is often a brainstorm with no
# stack yet, and /kru-setup's own blank-repo grill is where that stack gets
# settled. so the context says name it once and carry on.
#
# skipped outside a git work tree (no repo to set up) and in the plugin's own
# repo (it has no sheet by design). kill switches: the lead gate's — touch the
# resolver's `lead-gate/off`, or KRU_NO_LEAD_GATE.
command -v jq >/dev/null 2>&1 || exit 0
plugin_root="${1:-$CURSOR_PLUGIN_ROOT}"
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
[ -n "$KRU_NO_LEAD_GATE" ] && exit 0
[ -e "$(kru_path lead-gate/off)" ] && exit 0

input=$(cat 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$top/.cursor-plugin/plugin.json" ] && exit 0
grep -q '<!-- kru v' "$top/AGENTS.md" 2>/dev/null && exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: "kru: this repo has not run /kru-setup — there is no sheet in AGENTS.md. Name /kru-setup to the PM once this session (the PM bot runs it itself; a headless run says it in its return), then carry on: brainstorming, briefs and grilling need no setup, and on a blank repo setup is where the stack gets settled."
  }
}'
exit 0
