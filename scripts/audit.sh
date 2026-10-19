#!/bin/bash
# the mechanical half of skills/kru-roster/audit.md: the assertions a grep settles. the rest of that
# file (cohort drift, tailored slots, countable prose, context load) is read, not scripted.
# exit 0 when clean.
cd "$(dirname "$0")/.." || exit 2
fail=0; bad() { echo "FAIL: $*"; fail=1; }

# 1. version
v=$(tr -d '[:space:]' < VERSION)
[ "$(sed -n '1s/^# Roster — v//p' ROSTER.md)" = "$v" ] || bad "ROSTER.md header != VERSION ($v)"
[ "$(jq -r .version .cursor-plugin/plugin.json)" = "$v" ] || bad "plugin.json version != VERSION ($v)"
[ "$(jq -r '.plugins[] | select(.name == "kru-cursor") | .version' .cursor-plugin/marketplace.json)" = "$v" ] \
  || bad "marketplace.json kru entry version != VERSION ($v)"

# 2–4. registration, orphans, model pins
for f in agents/*.md; do
  n=$(basename "$f" .md)
  [ "$(sed -n '2,/^---$/s/^name: *//p' "$f" | tr -d '"')" = "kru-$n" ] || bad "$f name != kru-<file stem>"
  grep -q "^| \`$n\` |" ROSTER.md || bad "$n has no ROSTER.md specialists row"
  m=$(sed -n '2,/^---$/s/^model: *//p' "$f")
  grep -qxF "${m%%\[*}" <(node scripts/port.mjs --list-models) || bad "$f model '$m' is not a confirmed Cursor model id (scripts/port.mjs → CONFIRMED_MODELS)"
done
while read -r n; do
  [ -f "agents/$n.md" ] || bad "ROSTER.md row names missing agent $n"
done < <(sed -n '/^## Current specialists/,/^## /p' ROSTER.md | grep -oE '^\| `[a-z0-9-]+` \|' | tr -d '|` ')
for n in $(grep -oE '`[a-z0-9]+(-[a-z0-9]+)+`' references/routing.md | tr -d '`' | sort -u); do
  case "$n" in kru-*) n=${n#kru-};; esac
  case "$n" in *-builder|*-specialist|*-architect|*-reviewer|*-engineer|*-designer|*-developer|*-auditor|*-writer|*-optimizer|*-copywriter)
    [ -f "agents/$n.md" ] || bad "references/routing.md names missing agent $n";; esac
done

# 5. shared-block integrity, the grep-settled clauses
miss=$(grep -L 'Comments (earn the line)' $(grep -l 'TypeScript (shared skill)' agents/*.md))
[ -z "$miss" ] || bad "TypeScript block without Comments block: $miss"
miss=$(grep -L "## Design for what they'll actually do" agents/*.md)
[ -z "$miss" ] || bad "missing Block R: $miss"
[ "$(grep -c 'earn the line' agents/code-reviewer.md)" -gt 0 ] || bad "code-reviewer lost the comment read side"
[ "$(grep -c 'comment bar' skills/kru-lead/SKILL.md)" -gt 0 ] || bad "lead lost the inline comment clause"
for k in 'Hand-rolled past what ships' 'Left across the slice'; do
  grep -q "$k" agents/code-reviewer.md || bad "code-reviewer lost read-side bullet '$k'"
done
[ "$(grep -l 'before you write around it' agents/*.md)" = "$(grep -l 'The return pass' agents/*.md)" ] \
  || bad "Block N and Block O seat lists differ"
[ "$(grep -l 'The return pass' agents/*.md)" = "$(grep -l 'Return pass: <what you re-read>' agents/*.md)" ] \
  || bad "Block O seats without the Return pass trace line"
[ "$(grep -l "## Memory (this repo's facts)" agents/*.md)" = "$(grep -l '.claude/agent-memory-local/' agents/*.md)" ] \
  || bad "Block Q heading and memory line seat lists differ"
[ "$( (grep -l 'The return pass' agents/*.md; echo agents/test-writer.md) | sort -u)" = "$(grep -l "## Memory (this repo's facts)" agents/*.md)" ] \
  || bad "Block Q seats != Block O seats + test-writer"
for f in $(grep -l 'Never re-read a file you just edited' agents/*.md); do
  grep -q 'to confirm the edit landed' "$f" || bad "$f: Block A hygiene bullet lost its return-pass bound"
done
# Block O has no tailored slot: every copy byte-identical
blocks=$(for f in $(grep -l '^## The return pass' agents/*.md); do
  sed -n '/^## The return pass/,/^## /{/^## /!p}' "$f" | md5sum; done | sort -u | wc -l)
[ "$blocks" -le 1 ] || bad "## The return pass differs across seats ($blocks variants)"

# skills and hooks wiring
for d in skills/kru-*/; do [ -f "$d/SKILL.md" ] || bad "$d has no SKILL.md"; done
for f in skills/kru-*/SKILL.md; do
  [ "$(sed -n '2,/^---$/s/^name: *//p' "$f" | tr -d '"')" = "$(basename "$(dirname "$f")")" ] || bad "$f name != dir"
done
for h in $(grep -oE 'hooks/[a-z0-9-]+\.sh' hooks/hooks.json | sort -u) $(jq -r '.hooks[][].command' hooks/hooks.json | grep -oE ' [a-z0-9-]+\.sh( |$)' | tr -d ' ' | sed 's#^#hooks/#' | sort -u); do
  [ -f "$h" ] || bad "hooks.json names missing $h"
done

echo "agents: $(ls agents/*.md | wc -l) · skills: $(ls -d skills/kru-*/ | wc -l) · version $v"
[ $fail = 0 ] && echo "audit: clean"; exit $fail
