#!/bin/bash
# kru-tracker.sh: the work-tracker setting. github is the default, including
# when KRU_TRACKER is unset or empty; linear is opt-in.
# A security finding goes to Linear, internal to the team: the title and body carry no secret, key, or customer data, and the evidence stays in the store file.
# On GitHub it is refused. gh and curl are mocks, so nothing here reaches a network.
# run: bash scripts/kru-tracker.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
tracker="$here/kru-tracker.sh"
sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
bin="$sandbox/bin"
mkdir -p "$bin"

cat > "$bin/gh" << 'EOF'
#!/bin/bash
log=${KRU_TEST_LOG:?}
printf '%s\n' "$*" >> "$log"
if [ "${KRU_TEST_REFUSE_LABEL:-}" = 1 ] && [[ "$*" == *"issue create"* ]] && [[ "$*" == *"--label"* ]]; then
  printf '%s\n' "could not add label: 'bug' not found" >&2
  exit 1
fi
case "$*" in
  *"repo view"*) printf '%s\n' true ;;
  *"issue create"*) printf '%s\n' "https://github.com/acme/web/issues/12" ;;
  *"issue list"*)
    if [[ "$*" == *no:label* ]]; then
      printf '%s\n' '[{"number":13,"title":"Unlabeled login","body":"dropped label","url":"https://github.com/acme/web/issues/13"}]'
    else
      printf '%s\n' '[{"number":12,"title":"Flaky login","body":"value: 4","url":"https://github.com/acme/web/issues/12"}]'
    fi
    ;;
  *"issue comment"*|*"issue edit"*|*"issue close"*) ;;
  *) printf 'unexpected gh: %s\n' "$*" >&2; exit 1 ;;
esac
EOF

cat > "$bin/curl" << 'EOF'
#!/bin/bash
log=${KRU_TEST_LOG:?}
out=""
data=""
prev=""
for a in "$@"; do
  case "$prev" in
    -o) out=$a ;;
    --data-binary) data=$a ;;
    -H) printf '%s\n' "$a" >> "$log.headers" ;;
  esac
  prev=$a
done
printf '%s\n' "$data" >> "$log"
[ -n "$out" ] || { echo "curl mock: no -o" >&2; exit 1; }
q=$(jq -r .query <<<"$data")
body=""
case "$q" in
  *'team(id:'*) body='{"data":{"team":{"id":"team-1"}}}' ;;
  *'teams(filter'*)
    case "$(jq -r .variables.key <<<"$data")" in
      BG) body='{"data":{"teams":{"nodes":[{"id":"team-1"}]}}}' ;;
      SEC) body='{"data":{"teams":{"nodes":[{"id":"team-sec"}]}}}' ;;
      *) body='{"data":{"teams":{"nodes":[]}}}' ;;
    esac
    ;;
  *'project(id:'*) body='{"data":{"project":{"id":"proj-1"}}}' ;;
  *'projects(filter'*)
    if [ "${KRU_TEST_PROJECTS:-1}" = 2 ]; then
      body='{"data":{"projects":{"nodes":[{"id":"proj-1"},{"id":"proj-2"}]}}}'
    elif [ "${KRU_TEST_PROJECTS:-1}" = 0 ]; then
      body='{"data":{"projects":{"nodes":[]}}}'
    else
      body='{"data":{"projects":{"nodes":[{"id":"proj-1"}]}}}'
    fi
    ;;
  *issueLabelCreate*) body='{"data":{"issueLabelCreate":{"success":true,"issueLabel":{"id":"lab-sec"}}}}' ;;
  *issueLabels*) body='{"data":{"issueLabels":{"nodes":[{"id":"lab-bug","name":"Bug"},{"id":"lab-enh","name":"enhancement"}]}}}' ;;
  *issueCreate*) body='{"data":{"issueCreate":{"success":true,"issue":{"identifier":"BG-41","url":"https://linear.app/acme/issue/BG-41"}}}}' ;;
  *'issue(id:'*) body='{"data":{"issue":{"id":"11111111-1111-1111-1111-111111111111","identifier":"BG-41","url":"https://linear.app/acme/issue/BG-41","team":{"id":"team-1"},"state":{"type":"started"}}}}' ;;
  *commentCreate*) body='{"data":{"commentCreate":{"success":true}}}' ;;
  *workflowStates*) body='{"data":{"workflowStates":{"nodes":[{"id":"state-done","name":"Done","position":1}]}}}' ;;
  *issueUpdate*) body='{"data":{"issueUpdate":{"success":true}}}' ;;
  *'issues(first:'*) body='{"data":{"issues":{"nodes":[{"identifier":"BG-41","title":"Flaky login","description":"value: 4","url":"https://linear.app/acme/issue/BG-41"}]}}}' ;;
  *) printf 'unexpected linear query\n' >&2; exit 1 ;;
esac
printf '%s' "$body" > "$out"
printf '%s\n' 200
EOF
chmod +x "$bin/gh" "$bin/curl" "$tracker"

pass=0 fail=0
report() {
  local name=$1 ok=$2 detail=$3
  if $ok; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$detail"
  fi
}
contains() { case "$2" in *"$1"*) return 0 ;; esac; return 1; }

# every KRU_* / LINEAR_* / plugin option is stripped, so the parent environment
# cannot make a case pass. PATH points at the mocks first.
run() {
  local args=() envs=() seen=false a
  for a in "$@"; do
    case "$a" in
      *=*) seen=true; envs+=("$a") ;;
      *) $seen && envs+=("$a") || args+=("$a") ;;
    esac
  done
  : > "$sandbox/log"
  : > "$sandbox/log.headers"
  err=$(mktemp)
  out=$(env -u KRU_TRACKER -u KRU_LINEAR_TEAM -u KRU_LINEAR_PROJECT -u KRU_LINEAR_SECURITY_TEAM -u LINEAR_API_KEY \
    -u CLAUDE_PLUGIN_OPTION_KRU_TRACKER -u CLAUDE_PLUGIN_OPTION_KRU_LINEAR_TEAM \
    -u CLAUDE_PLUGIN_OPTION_KRU_LINEAR_PROJECT -u CLAUDE_PLUGIN_OPTION_KRU_LINEAR_SECURITY_TEAM \
    -u CLAUDE_PLUGIN_OPTION_LINEAR_API_KEY \
    -u KRU_TEST_REFUSE_LABEL -u KRU_TEST_PROJECTS \
    PATH="$bin:$PATH" KRU_TEST_LOG="$sandbox/log" \
    ${envs[@]+"${envs[@]}"} bash "$tracker" "${args[@]}" 2>"$err")
  code=$?
  err_out=$(cat "$err")
  rm -f "$err"
  log=$(cat "$sandbox/log")
}

is() { report "$1" "$([ "$out" = "$2" ] && [ "$code" = "${3:-0}" ] && echo true || echo false)" "want [$2] exit ${3:-0}; got [$out] exit $code; err [$err_out]"; }
ok() { report "$1" "$([ "$code" = "${2:-0}" ] && echo true || echo false)" "exit $code, want ${2:-0}; out [$out]; err [$err_out]"; }
logged() { report "$1" "$(contains "$2" "$log" && echo true || echo false)" "log missing [$2]; log [$log]"; }
not_logged() { report "$1" "$(contains "$2" "$log" && echo false || echo true)" "log unexpectedly has [$2]"; }
err_has() { report "$1" "$(contains "$2" "$err_out" && echo true || echo false)" "stderr missing [$2]; err [$err_out]"; }
quiet_key() {
  report "$1" "$(contains "$KEY" "$out$err_out" && echo false || echo true)" "the key was printed"
}

KEY=lin_api_test_placeholder

run backend
is "unset KRU_TRACKER is github" github

run backend KRU_TRACKER=
is "empty KRU_TRACKER is github" github

run backend KRU_TRACKER=github
is "KRU_TRACKER=github" github

run backend KRU_TRACKER=linear
is "KRU_TRACKER=linear" linear

run backend KRU_TRACKER=jira
ok "an unknown tracker is refused" 2
err_has "…and names the two allowed values" "github or linear"
not_logged "…and calls neither gh nor curl" "issue"
not_logged "…curl stays quiet too" "query"

run ready
ok "github ready asks gh whether issues are on" 0
logged "…via repo view" "repo view"

run file --kind bug --title "Flaky login" --body "severity: medium"
is "github file prints the issue number and url" $'12\thttps://github.com/acme/web/issues/12'
logged "…creates a bug issue" "issue create --label bug --title Flaky login --body severity: medium"

run file --kind want --title "Remember me" --body "value: 4"
logged "a want is an enhancement" "issue create --label enhancement"

run file --kind bug --title "Flaky login" --body "x" KRU_TEST_REFUSE_LABEL=1
is "a refused label is retried without it" $'12\thttps://github.com/acme/web/issues/12'
err_has "…and says so" "refused the label"
logged "…the second create has no label" "issue create --title Flaky login"

run list --kind bug
is "github list is id/title/body/url" '[{"id":"12","title":"Flaky login","body":"value: 4","url":"https://github.com/acme/web/issues/12"}]'
logged "…open bug label" "issue list --label bug --state open"

run search --kind want --query "remember"
ok "github search exits 0" 0
logged "github search keeps the kind" "issue list --label enhancement --state open --limit 10 --search remember"
logged "…and reads unlabeled open issues" "no:label remember"
logged "…capped" "--limit 20"
is "…and returns the labeled issue plus the unlabeled duplicate" '[{"id":"12","title":"Flaky login","body":"value: 4","url":"https://github.com/acme/web/issues/12"},{"id":"13","title":"Unlabeled login","body":"dropped label","url":"https://github.com/acme/web/issues/13"}]'

run comment --id 12 --body "more"
ok "github comment" 0
logged "…issue comment" "issue comment 12 --body more"

run update --id 12 --body "value: 5"
logged "github update is issue edit" "issue edit 12 --body value: 5"

run close --id 12
logged "github close" "issue close 12"

run comment --id BG-41 --body "more"
ok "a GitHub comment id must be digits" 1
err_has "…and names the issue number" "issue number"
not_logged "…and does not comment" "issue comment"

run update --id 12x --body "value: 5"
ok "a GitHub update id must be digits" 1
not_logged "…and does not edit" "issue edit"

run close --id "12 "
ok "a GitHub close id must be digits" 1
not_logged "…and does not close" "issue close"

run comment --id 12 --body "ghp_abcdefghijklmnopqrst"
ok "a comment body that carries a token is refused" 1
err_has "…and names the pointer rule" "pointer to where the evidence is kept"
not_logged "…before gh" "issue comment"

run update --id 12 --body "lin_api_abcdefghijklmnopqrst"
ok "an update body that carries a lin_api_ key is refused" 1
not_logged "…before gh" "issue edit"

run link --id 12
is "a github pull request closes with Fixes" "Fixes #12"

run link --id BG-41
ok "a Linear id is not a github Fixes line" 1

run file --kind security --title "token in the log" --body "secret"
ok "security is refused on github" 3
err_has "…and names the private destinations" "private security advisory"
not_logged "…and does not call gh" "issue"

run ready KRU_TRACKER=linear
ok "linear without a team key is not ready" 4
err_has "…names the team key" "KRU_LINEAR_TEAM"
not_logged "…and does not call the API" "query"

run ready KRU_TRACKER=linear KRU_LINEAR_TEAM=BG
ok "linear without a project name is not ready" 4
err_has "…names the project" "KRU_LINEAR_PROJECT"

run ready KRU_TRACKER=linear KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Connector
ok "linear without a key defers to MCP" 4
err_has "…the key is optional" "optional"
err_has "…names MCP" "Linear MCP"
err_has "…names the project name" "project name"
not_logged "…and does not call the API" "query"

run ready KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG
ok "linear with a key still needs a project name" 4
err_has "…names the project" "KRU_LINEAR_PROJECT"

run file --kind bug --title "Flaky login" --body "severity: medium" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear file prints the identifier and url" $'BG-41\thttps://linear.app/acme/issue/BG-41'
quiet_key "the key is not printed"
logged "…the create carries the team, the project and the bug label" '"teamId":"team-1"'
logged "…project id" '"projectId":"proj-1"'
logged "…label id, matched case-insensitively off Bug" '"labelIds":["lab-bug"]'
if grep -q "Authorization: $KEY" "$sandbox/log.headers"; then
  report "the key is sent only as the Authorization header" true ""
else
  report "the key is sent only as the Authorization header" false "headers [$(cat "$sandbox/log.headers")]"
fi

run file --kind want --title "Remember me" --body "value: 4" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=bg KRU_LINEAR_PROJECT=Platform
logged "a lowercase team key is retried in uppercase" '"key":"BG"'
logged "a want uses the enhancement label" "lab-enh"

run list --kind want \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear list uses the identifier as id" '[{"id":"BG-41","title":"Flaky login","body":"value: 4","url":"https://linear.app/acme/issue/BG-41"}]'

run search --kind bug --query "flaky" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
logged "linear search is the team, the project and the query" '"q":"flaky"'

run comment --id BG-41 --body "more" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear comment prints the identifier" BG-41
logged "…commentCreate uses the issue uuid" '"issueId":"11111111-1111-1111-1111-111111111111"'

run update --id BG-41 --body "value: 5" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
logged "linear update writes the description" '"description":"value: 5"'

run close --id BG-41 \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear close prints the identifier" BG-41
logged "…and sets the completed state" '"stateId":"state-done"'

run link --id BG-41 KRU_TRACKER=linear
is "a linear pull request links the identifier" "Linear: BG-41"

run link --id 12 KRU_TRACKER=linear
ok "a github number is not a Linear link" 1

run link --id ENG-123 KRU_TRACKER=linear
is "an uppercase Linear id links" "Linear: ENG-123"

run link --id A1-9 KRU_TRACKER=linear
is "a team key with a digit links" "Linear: A1-9"

run link --id bg-41 KRU_TRACKER=linear
ok "a lowercase Linear id is refused" 1
err_has "…and names the identifier" "ENG-123"

run link --id BG-41a KRU_TRACKER=linear
ok "a Linear id with a trailing letter is refused" 1

run link --id BG- KRU_TRACKER=linear
ok "a Linear id without a number is refused" 1

SEC_BODY='A token is written to the log. Evidence: the private store file issues/token-in-the-log.md'
run file --kind security --title "token in the log" --body "$SEC_BODY" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear security on the main team prints the identifier" $'BG-41\thttps://linear.app/acme/issue/BG-41'
logged "…uses the main team and the product project" '"teamId":"team-1"'
logged "…project" '"projectId":"proj-1"'
logged "…and the security label" '"labelIds":["lab-sec"]'
quiet_key "…and the key stays unprinted"

run file --kind security --title "token in the log" --body "$SEC_BODY" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_LINEAR_SECURITY_TEAM=SEC
logged "a security team replaces the main team" '"teamId":"team-sec"'
not_logged "…and does not attach the product project" '"projectId"'

run file --kind security --title "token in the log" --body "ghp_abcdefghijklmnopqrst" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body that carries a token is refused" 1
err_has "…and names the body rule" "pointer to where the evidence is kept"
not_logged "…before any API call" "issueCreate"

run file --kind security --title "ghp_abcdefghijklmnopqrst" --body "$SEC_BODY" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security title that carries a token is refused" 1
not_logged "…before any API call" "query"

run file --kind security --title "token in the log" --body "see lin_api_abcdefghijklmnopqrst" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a lin_api_ key in a security body is refused" 1
not_logged "…before any API call" "query"

run file --kind security --title "lin_api_abcdefghijklmnopqrst leaked" --body "$SEC_BODY" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a lin_api_ key in a security title is refused" 1

run file --kind security --title "token in the log" --body "mail a@ex.com" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body that carries an email is refused" 1
err_has "…and names the email rule" "email address"
not_logged "…before any API call" "query"

run file --kind security --title "a@ex.com is the reporter" --body "$SEC_BODY" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security title that carries an email is refused" 1

run file --kind bug --title "Flaky login" --body "ping a@ex.com"
ok "a bug body may name an email" 0
logged "…and still files" "issue create"

run comment --id BG-41 --body "ghp_abcdefghijklmnopqrst" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a linear comment body that carries a token is refused" 1
not_logged "…before any API call" "query"

run update --id BG-41 --body "lin_api_abcdefghijklmnopqrst" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a linear update body that carries a lin_api_ key is refused" 1
not_logged "…before any API call" "query"

run comment --kind security --id BG-41 --body "see a@ex.com" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security comment that carries an email is refused" 1
err_has "…and names the email rule" "email address"

run comment --id BG-41 --body "see a@ex.com" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a comment without --kind security may name an email" 0
logged "…and comments" "commentCreate"

run ready KRU_TRACKER=linear LINEAR_API_KEY=$'lin_api_test_placeholder\nX-Injected: 1' KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a key with a line feed is refused" 1
err_has "…and names the line feed" "line feed"
not_logged "…and does not call the API" "query"
quiet_key "…and does not print the key"

run ready KRU_TRACKER=linear LINEAR_API_KEY=$'lin_api_test_placeholder\r' KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a key with a carriage return is refused" 1
err_has "…and names the carriage return" "carriage return"
not_logged "…and does not call the API" "query"

run list --kind security \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_LINEAR_SECURITY_TEAM=sec
logged "a lowercase security team key is retried in uppercase" '"key":"SEC"'
not_logged "…list on that team has no product project" '"project"'

run ready KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_PROJECTS=2
ok "two projects with one name are not ready" 4
err_has "…asks for the project id" "project id"

run backend CLAUDE_PLUGIN_OPTION_KRU_TRACKER=linear
is "a claude plugin option fills KRU_TRACKER when unset" linear

run backend KRU_TRACKER=github CLAUDE_PLUGIN_OPTION_KRU_TRACKER=linear
is "an exported KRU_TRACKER beats the plugin option" github

run ready KRU_TRACKER=linear CLAUDE_PLUGIN_OPTION_LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "the API key is never taken from a plugin option" 4
err_has "…still asks for the environment key" "LINEAR_API_KEY"

# the setting is what the filing skills call. a raw gh issue command in a
# skill, seat, hook or reference would ignore KRU_TRACKER.
repo=$(cd "$here/.." && pwd)
banned=$(grep -nE 'gh issue (create|list|edit|comment|close)' -r \
  --include='*.md' --include='*.sh' --include='*.mjs' \
  "$repo/skills" "$repo/agents" "$repo/hooks" "$repo/commands" "$repo/references" \
  "$repo/TRACKER.md" "$repo/README.md" "$repo/PORTING.md" "$repo/scripts/cursor/edits.mjs" \
  2>/dev/null || true)
report "no skill, seat, hook, reference or fork edit calls gh issue directly" \
  "$([ -z "$banned" ] && echo true || echo false)" "$banned"

needles=(
  "TRACKER.md|KRU_LINEAR_SECURITY_TEAM"
  "skills/kru-issue/SKILL.md|pointer"
  "TRACKER.md|Linear MCP"
  "README.md|LINEAR_API_KEY"
  "PORTING.md|KRU_TRACKER"
  "README.md|KRU_LINEAR_TEAM"
  "references/store.md|kru-tracker.sh"
  "references/routing.md|kru-tracker.sh"
  "skills/kru-issue/SKILL.md|kru-tracker.sh"
  "skills/kru-todo/SKILL.md|kru-tracker.sh"
  "skills/kru-issues/SKILL.md|kru-tracker.sh"
  "skills/kru-todos/SKILL.md|kru-tracker.sh"
  "skills/kru-issues-loop/SKILL.md|kru-tracker.sh"
  "skills/kru-todos-loop/SKILL.md|kru-tracker.sh"
  "skills/kru-brief/SKILL.md|kru-tracker.sh"
  "skills/kru-lead/SKILL.md|kru-tracker.sh"
  "skills/kru-lead/references/reconcile.md|kru-tracker.sh"
  "skills/kru-to-tickets/SKILL.md|kru-tracker.sh"
  "skills/kru-to-spec/SKILL.md|kru-tracker.sh"
  "skills/kru-wayfinder/SKILL.md|KRU_TRACKER"
  "skills/kru-setup/SKILL.md|KRU_LINEAR_TEAM"
)
for pair in "${needles[@]}"; do
  f=${pair%%|*} n=${pair#*|}
  report "$f names $n" "$(grep -qF "$n" "$repo/$f" && echo true || echo false)" "missing"
done

# the same security rule in the lead, the reconcile step, the tracker doc,
# the issue skill, and this file's header. a fresh port re-applies the fork
# edit, so the edit source has to say it too.
policy=(
  "skills/kru-lead/SKILL.md|goes to Linear when the tracker is Linear, internal to the team"
  "skills/kru-lead/references/reconcile.md|goes to Linear, internal to the team"
  "TRACKER.md|internal to the team"
  "skills/kru-issue/SKILL.md|goes to Linear, internal to the team"
  "scripts/cursor/edits.mjs|goes to Linear when the tracker is Linear, internal to the team"
)
for pair in "${policy[@]}"; do
  f=${pair%%|*} n=${pair#*|}
  report "$f files security on Linear" "$(grep -qF "$n" "$repo/$f" && echo true || echo false)" "missing [$n]"
done
for f in skills/kru-lead/SKILL.md skills/kru-lead/references/reconcile.md TRACKER.md skills/kru-issue/SKILL.md scripts/cursor/edits.mjs scripts/kru-tracker.test.sh; do
  report "$f keeps secrets out of the title and body" "$(grep -qF "title and body carry no secret, key, or customer data" "$repo/$f" && echo true || echo false)" "missing the title/body rule"
  report "$f keeps the evidence in the store" "$(grep -qF "evidence stays in the store" "$repo/$f" && echo true || echo false)" "missing the store rule"
done
header=$(sed -n '1,7p' "$repo/scripts/kru-tracker.test.sh" | sed 's/^# *//')
report "the test header files security on Linear" "$(printf '%s\n' "$header" | grep -qF "A security finding goes to Linear, internal to the team: the title and body carry no secret, key, or customer data, and the evidence stays in the store file." && echo true || echo false)" "header [$header]"
report "the lead no longer keeps security off Linear" "$(grep -qF "or to Linear" "$repo/skills/kru-lead/SKILL.md" && echo false || echo true)" "still says or to Linear"
report "the lead fork edit no longer keeps security off Linear" "$(grep -qF "or to Linear" "$repo/scripts/cursor/edits.mjs" && echo false || echo true)" "edit still says or to Linear"
report "kru-issue files security through MCP without the script" "$(grep -qF "do not call the script" "$repo/skills/kru-issue/SKILL.md" && echo true || echo false)" "missing"
report "…and a missing key is not exit 4" "$(grep -qF "not exit 4" "$repo/skills/kru-issue/SKILL.md" && echo true || echo false)" "missing"
report "TRACKER tells an MCP session to apply the secret rule by hand" "$(grep -qF "apply the same rule by hand" "$repo/TRACKER.md" && echo true || echo false)" "missing"
report "…and names lin_api_" "$(grep -qF "lin_api_" "$repo/TRACKER.md" && echo true || echo false)" "missing"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
