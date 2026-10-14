#!/bin/bash
# brief-drift.mjs against mocked tracker JSON. no gh, no network.
# the brief stores ids; status arrives only as the issue's state field.
# run: bash scripts/brief-drift.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
drift="$here/brief-drift.mjs"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
pass=0 fail=0
path=plan/onboarding/brief.md

report() {
  local name=$1 ok=$2 detail=$3
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$detail"
  fi
}

run() {
  local brief=$1 issues=$2
  printf '%s\n' "$brief" > "$t/brief.md"
  printf '%s\n' "$issues" > "$t/issues.json"
  cp "$t/brief.md" "$t/brief.before"
  err=$(mktemp)
  out=$(node "$drift" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" 2>"$err")
  code=$?
  err_out=$(cat "$err")
  rm -f "$err"
}

is() {
  report "$1" "$( [ "$out" = "$2" ] && [ "$code" = "${3:-0}" ] && echo true || echo false )" "want [$2] exit ${3:-0}; got [$out] exit $code; err [$err_out]"
}
ok() { report "$1" "$( [ "$code" = "${2:-0}" ] && echo true || echo false )" "exit $code, want ${2:-0}; out [$out]; err [$err_out]"; }
lacks() { report "$1" "$( case "$out" in *"$2"*) echo false ;; *) echo true ;; esac )" "report contained [$2]"; }
unchanged() { report "$1" "$( cmp -s "$t/brief.before" "$t/brief.md" && echo true || echo false )" "the brief was modified"; }

marker='ada@example.com +1-415-555-0199 SYMPTOM-TOKEN'

clean_issues='[
  {"id":"12","title":"Invite","body":"Brief: plan/onboarding/brief.md\n'"$marker"'","url":"https://example.com/12","state":"done"},
  {"id":"BG-41","title":"Limit","body":"see plan/onboarding/brief.md","url":"https://example.com/41","state":"open"}
]'

run '# Onboarding

## Tracker
- ship the invite email — #12
- rate-limit sign-in — BG-41

## Done when
- [ ] the invite arrives
' "$clean_issues"
is "a listed issue that links is no drift, whatever its state" $'plan/onboarding/brief.md\nno drift'
lacks "…and the report omits an email from the body" "ada@example.com"
lacks "…and a phone" "+1-415-555-0199"
lacks "…and the rest of the body" "SYMPTOM-TOKEN"
unchanged "…and the brief is not rewritten"

run '# Onboarding

## Tracker
- ship — #12 done
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a status word in the brief is not status" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- limit — `bg-41`
' '[{"id":"BG-41","body":"Brief: plan/onboarding/brief.md","state":"completed"}]'
is "a backticked lowercase linear id matches, and completed counts as done" $'plan/onboarding/brief.md\nno drift'

drift_issues='[
  {"id":"12","title":"'"$marker"'","body":"no path here","state":"open"},
  {"id":7,"body":"elsewhere","state":"closed"},
  {"id":"40","body":"Brief: plan/onboarding/brief.md\n'"$marker"'","state":"done"},
  {"id":"BG-8","body":"Brief: plan/onboarding/brief.md","state":"open"},
  {"id":"BG-9","body":"Brief: plan/onboarding/brief.md","state":"canceled"},
  {"id":"41","body":"plan/onboarding/brief.md.bak","state":"done"},
  {"id":"42","body":"xplan/onboarding/brief.md","state":"done"}
]'

run '# Onboarding

## Why now
context

## Tracker
- ship the invite email — #12
- missing one — #99
- closed elsewhere — #7
- export the audit log
- [x] remember this device

## Done when
- [ ] the invite arrives — #12
' "$drift_issues"
is "the four drift lines" $'plan/onboarding/brief.md\n(a) listed, missing or not linked: #12 (not linked), #99 (missing), #7 (not linked)\n(b) linked, not listed: #40, BG-8, BG-9\n(c) done, never planned: #40\n(d) planned, no issue: export the audit log; remember this device'
lacks "a done-when line is not a planned tracker item" "the invite arrives"
lacks "a longer path is not a link" "#41"
lacks "a prefixed path is not a link" "#42"
lacks "a title is not copied into the report" "SYMPTOM-TOKEN"
ok "drift is a report, not a failed command" 0

run '# Onboarding

## Tracker
- ship #12 tomorrow
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "an id that is not at the end is not stored" $'plan/onboarding/brief.md\n(b) linked, not listed: #12\n(d) planned, no issue: ship #12 tomorrow'

run '# Onboarding

## Done when
- [ ] ships
' '[{"id":"40","body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "no tracker section: a done linked issue is unlisted and unplanned" $'plan/onboarding/brief.md\n(b) linked, not listed: #40\n(c) done, never planned: #40'

run '# Onboarding

## Tracker
- ship the invite email — #40
' '[{"id":"40","body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "a done issue the brief listed was planned" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — #12
- same number, padded — #012
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"}]'
is "a hash id and a padded hash id are the same github issue" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship — #12 completed
- drop — BG-9 canceled
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"},{"id":"BG-9","body":"Brief: plan/onboarding/brief.md","state":"canceled"}]'
is "trailing completed or canceled in the brief is not status" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — #12
' '[{"id":"12","body":"no path","state":"open"},{"id":12,"body":"Brief: plan/onboarding/brief.md","state":"done"}]'
is "a duplicate id keeps the object that links" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — #12
' '[{"id":"12","body":"Brief: plan/onboarding/brief.md","state":"open"},{"id":"12","body":"no path","state":"open"}]'
is "a later unlinked duplicate does not replace the linked one" $'plan/onboarding/brief.md\nno drift'

run '# Onboarding

## Tracker
- ship the invite email — nope
' '[{"id":"40","body":"Brief: plan/onboarding/brief.md","state":"canceled"}]'
is "a non-numeric token is a planned item, and a canceled issue is not done" $'plan/onboarding/brief.md\n(b) linked, not listed: #40\n(d) planned, no issue: ship the invite email — nope'

printf '%s\n' '# Onboarding' > "$t/brief.md"
printf '%s\n' '[]' > "$t/issues.json"
out=$(node "$drift" --path 'plan/not a slug/brief.md' --brief "$t/brief.md" --issues "$t/issues.json" 2>"$t/err")
code=$?
err_out=$(cat "$t/err")
ok "a brief path has to be plan/<effort>/brief.md" 1
report "…and says so" "$(case "$err_out" in *'plan/<effort>/brief.md'*) echo true ;; *) echo false ;; esac)" "err [$err_out]"

out=$(node "$drift" --path "$path" --brief "$t/missing.md" --issues "$t/issues.json" 2>"$t/err")
code=$?
ok "a missing brief is an error" 1

printf '%s\n' 'not json' > "$t/issues.json"
out=$(node "$drift" --path "$path" --brief "$t/brief.md" --issues "$t/issues.json" 2>"$t/err")
code=$?
err_out=$(cat "$t/err")
ok "issues JSON that is not an array is an error" 1
report "…without echoing the payload" "$(case "$err_out" in *'not json'*) echo false ;; *) echo true ;; esac)" "err [$err_out]"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
