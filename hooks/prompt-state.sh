#!/bin/bash
# beforeSubmitPrompt: the user's own words, as they send them. upstream's two
# transcript-reading gates (require-lead, brainstorm-guard) read claude's jsonl
# transcript for a slash command the user typed; cursor's transcript is its own
# format and may be absent (transcript_path is null when transcripts are off),
# so the state they need is recorded here, per conversation, from the prompt
# itself — a hook cloud agents run too.
#
#   /kru-brainstorm …            → the brainstorm lock (writes refused)
#   go | brief it | /kru-brief   → the user's go: the lock lifts
#   /kru-lead …                  → the lead contract is loaded
#   /kru-<any> …                 → a kru command is the latest word (require-lead exempts it)
#   anything else                → an ordinary turn again
#
# a skill picked from the / menu may arrive as an attachment instead of text,
# so an attached skills/kru-<name>/SKILL.md or commands/kru-<name>.md counts
# as typing it. never blocks: {"continue":true} on every path.
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat) || exit 0
conv=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$conv" ] || exit 0
case "$conv" in */*|*..*) exit 0 ;; esac
state="${TMPDIR:-/tmp}/kru-cursor-$(id -u)/$conv"
mkdir -p "$state" 2>/dev/null || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)
# the command the turn opens with, typed or attached
cmd=$(printf '%s' "$prompt" | sed -n '1s/^[[:space:]]*\/\(kru-[a-z0-9-]*\).*/\1/p')
[ -z "$cmd" ] && cmd=$(printf '%s' "$input" | jq -r '[.attachments[]?.file_path // empty
  | capture("/(skills/(?<s>kru-[a-z0-9-]+)/SKILL\\.md|commands/(?<c>kru-[a-z0-9-]+)\\.md)$")? | (.s // .c)] | first // empty' 2>/dev/null)

case "$cmd" in
  kru-brainstorm) : > "$state/brainstorm.lock" ;;
  kru-brief) rm -f "$state/brainstorm.lock" ;;
  kru-lead) : > "$state/lead.loaded" ;;
esac
if [ -z "$cmd" ] && printf '%s' "$prompt" | grep -qiE '^[[:space:]]*(go|brief it)([^[:alnum:]]|$)'; then
  rm -f "$state/brainstorm.lock"
fi
if [ -n "$cmd" ]; then printf '%s\n' "$cmd" > "$state/command"; else rm -f "$state/command"; fi
printf '{"continue":true}\n'
exit 0
