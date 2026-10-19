#!/bin/bash
# table tests for check-handoff.sh: each case is a brief, the seat it goes to,
# and whether the gate refuses it. run: bash hooks/check-handoff.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
hook="$here/check-handoff.sh"

# a sandboxed home so refusals log nowhere real, and a cwd holding no files the
# verbatim check could treat as canon.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/home/.claude" "$sandbox/cwd"
printf '# machine\n- MacBook Air — **8 cores, 8 GB RAM**.\n' > "$sandbox/home/.claude/CLAUDE.md"

pass=0 fail=0
# expect: refuse | allow | supply. needle: text the refusal reason must contain,
# or on supply, the text the hook appends to the brief instead of refusing.
check() {
  local expect=$1 seat=$2 prompt=$3 needle=${4:-}
  local input out code
  # inbox.md keeps the channel injection out of the allow path's output
  input=$(jq -nc --arg s "$seat" --arg p "$prompt inbox.md" \
    '{session_id:"test", cwd:"/x", tool_input:{subagent_type:$s, prompt:$p, description:"t"}}')
  out=$(cd "$sandbox/cwd" && printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_GATE -u CURSOR_PLUGIN_ROOT HOME="$sandbox/home" bash "$hook" "$root" 2>&1)
  code=$?
  local ok=true
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle" && ok=false
  elif [ "$expect" = supply ]; then
    [ "$code" -eq 0 ] || ok=false
    printf '%s' "$out" | grep -qF "$needle" || ok=false
  else
    [ "$code" -eq 0 ] || ok=false
    printf '%s' "$out" | grep -q 'updatedInput' && printf '%s' "$out" | grep -qv 'learnings channel' && ok=$ok
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s\n  %s\n' "$expect" "$code" "$prompt" "$out"
  fi
}

ui=kru-react-ui-builder

# comment standard — the paraphrase is refused
check refuse $ui "Build the form. Preserve existing comments in the file." "comment standard"
check refuse $ui "Build the form. Comments already in the file survive your edit." "comment standard"
check refuse $ui "Build the form. Keep all comments." "comment standard"
check refuse $ui "Build the form. Write comments in lowercase." "comment standard"
check refuse $ui "Build the form. Write comments in the file's own voice." "comment standard"
check refuse $ui "Build the form. Match the case and grammar of the surrounding comments." "comment standard"
check refuse $ui "Build the form. Comments should be full sentences, capitalized." "comment standard"

# ...and slice content naming one comment is not the standard — each of these
# was a real refusal the gate had no business making
check allow $ui "Add \`readonly ticker: string;\` with a lowercase doc comment naming the base asset."
check allow $ui "Add a comment on the empty-input case: the API returns 204, not an empty list."
check allow $ui "Must keep: same 50px field height (\`--field-size\` comment in that css file)."
check allow $ui "Keep the narrowing on the path that confirms, and keep what its comment says true."
check allow $ui "Update the comments above the effect to match the new mechanism."
# a class-wide quantifier holds the refusal even beside a backticked identifier
check refuse $ui "Keep existing comments; update the \`SKIP_STATUSES\` comment if it goes stale." "comment standard"
# comment standard — a brief naming what one comment says is not the standard
check allow $ui "Add a comment about the contact email being kept for receipts."
check allow $ui "Keep the comment on the fee calc."
# a singular comment the slice writes or fixes is slice content — each was a real refusal
check allow $ui "Make it count the row's real floor, keep the comment exact."
check allow $ui "Keep their names and assertions; add a one-line comment naming the case."
check allow $ui "Make the key a plain object; keep lazy read only if a real reason exists, and fix the comment."
check allow $ui "Write that rule as the comment at the place the sentence is kept."
check allow $ui "Leave a comment explaining why the draft is retained."
# one file's own comments, named with its other contents — each was a real refusal
check allow $ui "Fix the script so a fresh session gets pnpm first on PATH. Keep its existing structure and comments."
check allow $ui "Fold the column into 0062 (regenerate with drizzle-kit, keep its hand edits: lock_timeout, npos-before-dists order, comments, NOT VALID check)."

check allow $ui "Keep it as one named constant in the module, with a comment naming the docs URL."
# ...even under markdown emphasis, and "existing" on one comment points at it
check allow $ui "\`Coded\` becomes \`Coding\`. **Keep its existing comment** about the two a catalogue would most plausibly grow back."
# a preservation list names its own slice; only the comments clause is the standard
check refuse $ui "No hamburger menu; keep h-16, scrolled/unscrolled color logic, and existing comments intact." "cut that clause"

# scan 3 report-back — a fallback whose trigger is named resolves the call
check refuse $ui "Use a spinner or a skeleton for the press, and say which one you chose." "open design call"
check allow $ui "Show a loading state on the press. If the wiring can't do that without a route change, give the Chat entry in \`EditorEntries\` a busy state instead, and say which one you chose."
# a mechanism the seat measures against a named bound, or a named fix it may
# depart from, reports back without delegating — each was a real refusal
check allow kru-postgres-architect "Choose the key that gives both; say what you chose."
check allow kru-postgres-architect "Key it on the owed total. Depart from this key if the code shows otherwise, and say what you used instead."
check allow $ui "Fall back to a USD figure derived from the dist's own USD columns if they exist (report what you used)."
check allow $ui "Assert the init call by mocking the module, or whatever is practical — say what you chose."
check refuse $ui "Pick a modal or a drawer for the editor and report what you decided." "open design call"

# machine budget
check refuse $ui "Run vitest one file at a time on this machine." "machine budget"
check refuse $ui "The box has 8 GB so be careful." "machine budget"
check allow $ui "Migrate one table at a time."
check allow $ui "The R2 object cap is 5 GB."
# a figure about the deployed resource is slice content, not the dev machine
check allow kru-fly-platform-engineer "Resize the Machine to 8 GB in fly.toml."

# root AGENTS.md and an alwaysApply rule are budget canon; a rule without it is not.
# the legacy home file stays the fallback (the cases above). cwd is the repo, not /x.
budget_repo=$sandbox/budget
mkdir -p "$budget_repo/.cursor/rules/nested" "$budget_repo/pkg"
git -C "$budget_repo" init -q
printf '%s\n' 'The dev box has 16 GB.' > "$budget_repo/AGENTS.md"
printf '%s\n' '---' 'alwaysApply: true' '---' 'One suite: 32 GB is the cap.' > "$budget_repo/.cursor/rules/nested/budget.mdc"
printf '%s\n' '---' 'alwaysApply: false' '---' 'The laptop has 64 GB.' > "$budget_repo/.cursor/rules/optional.mdc"
budget_check() {
  local expect=$1 seat=$2 prompt=$3 needle=${4:-} cwd=${5:-$budget_repo}
  local input out code
  input=$(jq -nc --arg s "$seat" --arg p "$prompt inbox.md" --arg c "$cwd" \
    '{session_id:"test", cwd:$c, tool_input:{subagent_type:$s, prompt:$p, description:"t"}}')
  out=$(cd "$sandbox/cwd" && printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_GATE -u CURSOR_PLUGIN_ROOT HOME="$sandbox/home" bash "$hook" "$root" 2>&1)
  code=$?
  local ok=true
  if [ "$expect" = refuse ]; then
    [ "$code" -eq 2 ] || ok=false
    [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle" && ok=false
  else
    [ "$code" -eq 0 ] || ok=false
  fi
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL (%s, exit %s): %s\n  %s\n' "$expect" "$code" "$prompt" "$out"
  fi
}
budget_check refuse $ui "The box has 16 GB so be careful." "machine budget" "$budget_repo/pkg"
budget_check refuse $ui "Stay under 32 GB." "machine budget"
budget_check allow $ui "The laptop has 64 GB."
# the home file is a fallback, not a second canon: its 8 GB must not refuse a
# brief once the repo has an AGENTS.md or an alwaysApply rule.
budget_check allow $ui "The box has 8 GB so be careful."
rules_only=$sandbox/rules-only
mkdir -p "$rules_only/.cursor/rules"
git -C "$rules_only" init -q
printf '%s\n' '---' 'alwaysApply: true' '---' 'One suite: 32 GB is the cap.' > "$rules_only/.cursor/rules/budget.mdc"
budget_check allow $ui "The box has 8 GB so be careful." "" "$rules_only"
budget_check refuse $ui "Stay under 32 GB." "machine budget" "$rules_only"
bare=$sandbox/bare
mkdir -p "$bare"
git -C "$bare" init -q
budget_check refuse $ui "The box has 8 GB so be careful." "machine budget" "$bare"
# a space in the repo path, and in a rule's filename, still reaches the figure
space_repo="$sandbox/budget box"
mkdir -p "$space_repo/.cursor/rules"
git -C "$space_repo" init -q
printf '%s\n' 'The workstation has 24 GB.' > "$space_repo/AGENTS.md"
printf '%s\n' '---' 'alwaysApply: true' '---' 'Cap the suite at 48 GB.' > "$space_repo/.cursor/rules/my budget.mdc"
budget_check refuse $ui "The workstation has 24 GB." "machine budget" "$space_repo"
budget_check refuse $ui "Cap the suite at 48 GB." "machine budget" "$space_repo"
budget_check allow $ui "The box has 8 GB so be careful." "" "$space_repo"

# verbatim shingle uses the same always-loaded set as the budget: a rule
# without alwaysApply is not canon, a nested alwaysApply rule is, and
# ~/.claude/CLAUDE.md is scanned only when the repo has neither.
printf '%s\n' 'Purple kettles never boil on tuesdays in the annex.' >> "$sandbox/home/.claude/CLAUDE.md"
shingle_repo=$sandbox/shingle
mkdir -p "$shingle_repo/.cursor/rules/nested" "$shingle_repo/pkg"
git -C "$shingle_repo" init -q
printf '%s\n' 'Root agents prose stays the shingle canon for this repo.' > "$shingle_repo/AGENTS.md"
printf '%s\n' '---' 'alwaysApply: true' '---' 'Nested amber rule text loads with every session.' > "$shingle_repo/.cursor/rules/nested/amber.mdc"
printf '%s\n' '---' 'alwaysApply: false' '---' 'Optional crimson rule text stays out of the brief scan.' > "$shingle_repo/.cursor/rules/optional.mdc"
printf '%s\n' 'Root claude file text must not count as shingle canon.' > "$shingle_repo/CLAUDE.md"
budget_check refuse $ui "Root agents prose stays the shingle canon for this repo." "AGENTS.md" "$shingle_repo/pkg"
budget_check refuse $ui "Nested amber rule text loads with every session." "nested/amber.mdc" "$shingle_repo"
budget_check allow $ui "Optional crimson rule text stays out of the brief scan." "" "$shingle_repo"
budget_check allow $ui "Root claude file text must not count as shingle canon." "" "$shingle_repo"
budget_check allow $ui "Purple kettles never boil on tuesdays in the annex." "" "$shingle_repo"
# a non-alwaysApply rule is not primary, so the home file is the fallback
shingle_optional=$sandbox/shingle-optional
mkdir -p "$shingle_optional/.cursor/rules"
git -C "$shingle_optional" init -q
printf '%s\n' '---' 'alwaysApply: false' '---' 'Optional crimson rule text stays out of the brief scan.' > "$shingle_optional/.cursor/rules/optional.mdc"
budget_check allow $ui "Optional crimson rule text stays out of the brief scan." "" "$shingle_optional"
budget_check refuse $ui "Purple kettles never boil on tuesdays in the annex." ".claude/CLAUDE.md" "$shingle_optional"
shingle_bare=$sandbox/shingle-bare
mkdir -p "$shingle_bare"
git -C "$shingle_bare" init -q
budget_check refuse $ui "Purple kettles never boil on tuesdays in the annex." ".claude/CLAUDE.md" "$shingle_bare"

# coordinates and hedges
check refuse $ui "Edit src/Form.tsx:42 to add the field." "coordinates"
check refuse $ui "The cursor math in \`donor.ts ~:54-59\` drops the last page." "coordinates"
check refuse $ui "The guard in \`donor.ts\` ~L218-233 drops the last page." "coordinates"
check refuse $ui "The guard in donor.ts:~175 drops the last page." "coordinates"
check refuse $ui "Status may mean archived here." "hedged term"
check allow $ui "Edit the SignupForm component in src/Form.tsx."
# a coordinate inside quoted tool output is evidence, not an asserted location
check allow $ui "Fix the crash in \`addToCart\` (src/cart.ts). The failing run:
\`\`\`
TypeError: cannot read 'qty' of undefined
    at addToCart (src/cart.ts:42:7)
\`\`\`"
check allow $ui "Fix the crash in \`addToCart\`. Observed:
> at addToCart (src/cart.ts:42:7)"
# ...but one outside the quote is still refused
check refuse $ui "Fix src/cart.ts:42. Observed:
\`\`\`
at addToCart (src/cart.ts:42:7)
\`\`\`" "coordinates"
# a hedge over named causes, each answer's action named, is the investigation
check allow $ui "Unclear whether the stale total comes from the cache or the query: reproduce, report which, fix that one."
check allow $ui "An empty \`status\` may mean the IPN beat the order row; handle both."

# a review seat's report path is supplied, not refused over — the same literal
# on every review brief, where a refusal costs a whole re-dispatch
check allow kru-code-reviewer "Review the signup diff."
# the supplied path carries the slice slug from the description, so two reviews don't share a file
check allow kru-code-reviewer "Review the signup diff."
check allow kru-code-reviewer "Review the signup diff. report: /tmp/kru-review/p/code-reviewer-signup.md"

# shadow scans log to the refusal log and let the dispatch through
shadow_lines() { find "$sandbox/home" -name refusals.jsonl -exec grep -c '"shadow":true' {} + 2>/dev/null | awk -F: '{ n += $NF } END { print n + 0 }'; }
before=$(shadow_lines)
# a brief asking for the return-pass line restates Block O
check refuse $ui "Build the form. Return with a \`Return pass: <typecheck> · <tests>\` line." "Block O"
check refuse $ui "Build the form. **Return:** files changed, tests added, your Return pass line." "Block O"
after=$(shadow_lines)
# a clean brief writes nothing
check allow $ui "Build the form. The field is required."
[ "$(shadow_lines)" -eq "$after" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); printf 'FAIL (clean): shadow line written\n'; }

# grouping: a file under another seat's sheet directory logs a shadow line
mkdir -p "$sandbox/sheet/.claude"
printf 'ui         kru-react-ui-builder     ← `packages/ui` components\nroutes     kru-react-router-builder ← `apps/console/src/routes`, `apps/console/src/api`\nemails     `packages/emails` templates; schema via kru-drizzle\n' > "$sandbox/sheet/AGENTS.md"
sheet_check() {
  local seat=$1 prompt=$2 want=$3 reason_needle=${4:-'grouping: "'}
  local b a input out rlog
  b=$(shadow_lines)
  input=$(jq -nc --arg s "$seat" --arg p "$prompt inbox.md" --arg c "$sandbox/sheet" \
    '{session_id:"test", cwd:$c, tool_input:{subagent_type:$s, prompt:$p, description:"t"}}')
  out=$(cd "$sandbox/cwd" && printf '%s' "$input" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_GATE -u CURSOR_PLUGIN_ROOT HOME="$sandbox/home" bash "$hook" "$root" 2>&1)
  a=$(shadow_lines)
  if [ "$a" -eq $((b + want)) ]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL (grouping %s): %s -> %s on: %s\n  %s\n' "$want" "$b" "$a" "$prompt" "$out"; fi
  if [ "$want" -eq 1 ]; then
    rlog=$(find "$sandbox/home" -name refusals.jsonl 2>/dev/null | head -1)
    tail -1 "$rlog" | jq -r '.reasons' | grep -qF "$reason_needle" && pass=$((pass + 1)) || { fail=$((fail + 1)); printf 'FAIL (grouping reason): %s (want %s)\n' "$prompt" "$reason_needle"; }
  fi
}
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\` and wire \`apps/console/src/api/client.ts\`." 1
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\`." 0
sheet_check kru-react-router-builder "Mount it in \`apps/console/src/routes/home.tsx\`, importing \`packages/ui/card.tsx\`." 1
# a skill named on a sheet line owns no directory
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\` and the note in \`packages/emails/CLAUDE.md\`." 0
sheet_check kru-code-reviewer "Review \`packages/ui/card.tsx\` and \`apps/console/src/api/client.ts\`. report: /tmp/kru-review/p/code-reviewer-x.md" 0
# a read-only seat reads every lane, even one the sheet gives it directories in
printf 'review     kru-code-reviewer        ← `apps/console/src/routes`\n' >> "$sandbox/sheet/AGENTS.md"
sheet_check kru-code-reviewer "Review \`apps/console/src/routes/home.tsx\` and \`packages/ui/card.tsx\`. report: /tmp/kru-review/p/code-reviewer-x.md" 0

# a scoped package is a dependency, not a directory the sheet hands out
printf 'data       kru-turso-specialist     ← `src/db`, `@libsql/client`\n' >> "$sandbox/sheet/AGENTS.md"
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\`; the store reads through \`@libsql/client\` 0.18.0." 0
# a path handed to its owner is named for reading
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\`. Read how \`src/db/store.ts\` loads it (one line in your report if it's off; the data seat owns that file)." 0
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\` and the query in \`src/db/store.ts\`." 1

# a version or a passage the brief names is slice content: no shadow line
printf 'routes     kru-react-router-builder ← react-router 8.3.0 framework mode\n' >> "$sandbox/sheet/AGENTS.md"
sheet_check kru-react-router-builder "Fix the loader in \`apps/console/src/routes/home.tsx\` — it runs on 8.3.0." 0
# a path named only as context for another seat's mount is not an edit target
printf 'pages      kru-sveltekit-builder    ← `src/routes`\n' >> "$sandbox/sheet/AGENTS.md"
sheet_check kru-react-ui-builder "Style the card in \`packages/ui/card.tsx\`; mounted by \`src/routes/+page.svelte\`, leave it." 0
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\` and wire \`src/routes/+page.svelte\`." 1 'grouping: "src/routes/+page.svelte"'
sheet_check kru-react-ui-builder "Build the card in \`packages/ui/card.tsx\`; the pages under \`src/routes\` import it." 1 'grouping-mention:'
# the gate stays out of unknown seats
check allow general-purpose "Preserve existing comments in the file."

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
