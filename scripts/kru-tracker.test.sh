#!/bin/bash
# kru-tracker.sh: the work-tracker setting. github is the default, including
# when KRU_TRACKER is unset or empty; linear is opt-in.
# A security finding goes to Linear, internal to the team. bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand.
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
  *"repo view"*)
    if [[ "$*" == *nameWithOwner* ]]; then printf '%s\n' acme/web
    else printf '%s\n' true
    fi
    ;;
  *"issue create"*) printf '%s\n' "https://github.com/acme/web/issues/12" ;;
  *"issue list"*)
    if [[ "$*" == *"plan/"* ]]; then
      printf '%s\n' '[{"number":12,"title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/12","state":"OPEN"},{"number":40,"title":"Extra","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/40","state":"CLOSED"},{"number":41,"title":"Other","body":"unrelated","url":"https://github.com/acme/web/issues/41","state":"OPEN"}]'
    elif [[ "$*" == *no:label* ]]; then
      printf '%s\n' '[{"number":13,"title":"Unlabeled login","body":"dropped label","url":"https://github.com/acme/web/issues/13"}]'
    else
      printf '%s\n' '[{"number":12,"title":"Flaky login","body":"value: 4","url":"https://github.com/acme/web/issues/12"}]'
    fi
    ;;
  *"issue view"*)
    if [[ "$*" == *"number,title,body,url,state"* ]]; then
      if [ "${KRU_TEST_GH_ERROR:-}" = 1 ]; then
        printf '%s\n' "authentication required" >&2
        exit 1
      fi
      id=$(printf '%s\n' "$*" | sed -n 's/.*issue view \([0-9][0-9]*\).*/\1/p')
      if [ "$id" = 404 ]; then
        printf '%s\n' "not found" >&2
        exit 1
      fi
      if [ "$id" = 77 ]; then
        printf '%s\n' '{"number":77,"title":"Wontfix","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/77","state":"CLOSED","stateReason":"NOT_PLANNED"}'
      else
        printf '%s\n' "{\"number\":$id,\"title\":\"Orphan\",\"body\":\"no link\",\"url\":\"https://github.com/acme/web/issues/$id\",\"state\":\"OPEN\"}"
      fi
    elif [ "${KRU_TEST_SECURITY_ISSUE:-}" = 1 ]; then printf '%s\n' security
    else printf '%s\n' bug
    fi
    ;;
  *"api graphql"*)
    if [ "${KRU_TEST_GH_LOOSE:-}" = 1 ]; then
      if [[ "$*" == *"after=page-3"* ]]; then
        printf '%s\n' '{"data":{"search":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"number":12,"title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/12","state":"OPEN"}]}}}'
      elif [[ "$*" == *"after=page-2"* ]]; then
        printf '%s\n' '{"data":{"search":{"pageInfo":{"hasNextPage":true,"endCursor":"page-3"},"nodes":[{"number":44,"title":"Old","body":"plan/onboarding/brief.md-old","url":"https://github.com/acme/web/issues/44","state":"OPEN"}]}}}'
      else
        printf '%s\n' '{"data":{"search":{"pageInfo":{"hasNextPage":true,"endCursor":"page-2"},"nodes":[{"number":43,"title":"Other","body":"my-plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/43","state":"OPEN"}]}}}'
      fi
    elif [[ "$*" == *"after=page-2"* ]]; then
      printf '%s\n' '{"data":{"search":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"number":40,"title":"Extra","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/40","state":"CLOSED","stateReason":"COMPLETED"}]}}}'
    else
      printf '%s\n' '{"data":{"search":{"pageInfo":{"hasNextPage":true,"endCursor":"page-2"},"nodes":[{"number":12,"title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/12","state":"OPEN"},{"number":41,"title":"Other","body":"unrelated","url":"https://github.com/acme/web/issues/41","state":"OPEN"},{"number":50,"title":"Wontfix","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/50","state":"CLOSED","stateReason":"NOT_PLANNED"}]}}}'
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
  *'issue(id:'*)
    if [ "${KRU_TEST_CURL_FAIL:-}" = 1 ]; then
      printf '%s\n' "curl: (6) could not resolve host" >&2
      exit 1
    fi
    if [ "$(jq -r .variables.id <<<"$data")" = "BG-404" ]; then
      body='{"data":{"issue":null}}'
    elif [[ "$q" == *description* ]]; then
      body='{"data":{"issue":{"identifier":"BG-41","title":"Invite","description":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":{"type":"completed"}}}}'
    elif [ "${KRU_TEST_SECURITY_ISSUE:-}" = 1 ]; then
      body='{"data":{"issue":{"id":"11111111-1111-1111-1111-111111111111","identifier":"BG-41","url":"https://linear.app/acme/issue/BG-41","team":{"id":"team-1"},"state":{"type":"started"},"labels":{"nodes":[{"name":"security"}]}}}}'
    else
      body='{"data":{"issue":{"id":"11111111-1111-1111-1111-111111111111","identifier":"BG-41","url":"https://linear.app/acme/issue/BG-41","team":{"id":"team-1"},"state":{"type":"started"}}}}'
    fi
    ;;
  *commentCreate*) body='{"data":{"commentCreate":{"success":true}}}' ;;
  *workflowStates*) body='{"data":{"workflowStates":{"nodes":[{"id":"state-done","name":"Done","position":1}]}}}' ;;
  *issueUpdate*) body='{"data":{"issueUpdate":{"success":true}}}' ;;
  *'issues(first:'*)
    if [[ "$q" == *'$path:String!'* ]]; then
      after=$(jq -r '.variables.after // empty' <<<"$data")
      if [ "${KRU_TEST_LINEAR_LOOSE:-}" = 1 ]; then
        if [ "$after" = "page-3" ]; then
          body='{"data":{"issues":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"identifier":"BG-41","title":"Invite","description":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":{"type":"completed"}}]}}}'
        elif [ "$after" = "page-2" ]; then
          body='{"data":{"issues":{"pageInfo":{"hasNextPage":true,"endCursor":"page-3"},"nodes":[{"identifier":"BG-44","title":"Old","description":"plan/onboarding/brief.md-old","url":"https://linear.app/acme/issue/BG-44","state":{"type":"started"}}]}}}'
        else
          body='{"data":{"issues":{"pageInfo":{"hasNextPage":true,"endCursor":"page-2"},"nodes":[{"identifier":"BG-43","title":"Other","description":"my-plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-43","state":{"type":"started"}}]}}}'
        fi
      elif [ "$after" = "page-2" ]; then
        body='{"data":{"issues":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"identifier":"BG-8","title":"Extra","description":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-8","state":{"type":"started"}}]}}}'
      else
        body='{"data":{"issues":{"pageInfo":{"hasNextPage":true,"endCursor":"page-2"},"nodes":[{"identifier":"BG-41","title":"Invite","description":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":{"type":"completed"}},{"identifier":"BG-9","title":"Dropped","description":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-9","state":{"type":"canceled"}},{"identifier":"BG-7","title":"Other","description":"unrelated","url":"https://linear.app/acme/issue/BG-7","state":{"type":"started"}}]}}}'
      fi
    else
      body='{"data":{"issues":{"nodes":[{"identifier":"BG-41","title":"Flaky login","description":"value: 4","url":"https://linear.app/acme/issue/BG-41"}]}}}'
    fi
    ;;
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
# cannot make a case pass. PATH points at the mocks first. only those prefixes
# are environment; a body may contain '=' (password=…) and stay an argument.
run() {
  local args=() envs=() a
  for a in "$@"; do
    case "$a" in
      KRU_*=*|LINEAR_*=*|CLAUDE_PLUGIN_OPTION_*=*) envs+=("$a") ;;
      *) args+=("$a") ;;
    esac
  done
  : > "$sandbox/log"
  : > "$sandbox/log.headers"
  err=$(mktemp)
  out=$(env -u KRU_TRACKER -u KRU_LINEAR_TEAM -u KRU_LINEAR_PROJECT -u KRU_LINEAR_SECURITY_TEAM -u LINEAR_API_KEY \
    -u CLAUDE_PLUGIN_OPTION_KRU_TRACKER -u CLAUDE_PLUGIN_OPTION_KRU_LINEAR_TEAM \
    -u CLAUDE_PLUGIN_OPTION_KRU_LINEAR_PROJECT -u CLAUDE_PLUGIN_OPTION_KRU_LINEAR_SECURITY_TEAM \
    -u CLAUDE_PLUGIN_OPTION_LINEAR_API_KEY \
    -u KRU_TEST_REFUSE_LABEL -u KRU_TEST_PROJECTS -u KRU_TEST_SECURITY_ISSUE \
    -u KRU_TEST_GH_ERROR -u KRU_TEST_CURL_FAIL \
    -u KRU_TEST_GH_LOOSE -u KRU_TEST_LINEAR_LOOSE \
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
err_lacks() { report "$1" "$(contains "$2" "$err_out" && echo false || echo true)" "stderr unexpectedly has [$2]; err [$err_out]"; }
no_writes() {
  local name=$1 bad
  for bad in create edit comment close mutation; do
    if contains "$bad" "$log"; then
      report "$name log has no $bad" false "log [$log]"
      return
    fi
  done
  report "$name log has no create, edit, comment, close, or mutation" true ""
}
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

run comment --id 12 --body "ghp_abcdefghijklmnopqrstuvwxyz1234"
ok "a comment body that carries a token is refused" 1
err_has "…and names the tracker-text rule" "link to the store file"
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

run file --kind security --title "token in the log" --body "ghp_abcdefghijklmnopqrstuvwxyz1234" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body that carries a token is refused" 1
err_has "…and names the tracker-text rule" "link to the store file"
not_logged "…before any API call" "issueCreate"

run file --kind security --title "ghp_abcdefghijklmnopqrstuvwxyz1234" --body "$SEC_BODY" \
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
err_has "…and names the tracker-text rule" "customer emails"
not_logged "…before any API call" "query"

run file --kind security --title "a@ex.com is the reporter" --body "$SEC_BODY" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security title that carries an email is refused" 1

run file --kind bug --title "Flaky login" --body "ping a@ex.com"
ok "a bug body that names an email is refused" 1
not_logged "…and does not file" "issue create"

run comment --id BG-41 --body "ghp_abcdefghijklmnopqrstuvwxyz1234" \
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
err_has "…and names the tracker-text rule" "customer emails"
not_logged "…before any API call" "query"

run comment --id BG-41 --body "see a@ex.com" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a comment without --kind that names an email is refused" 1
not_logged "…and does not comment" "commentCreate"

run update --id BG-41 --body "ping a@ex.com" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "an update without --kind that names an email is refused" 1
not_logged "…and does not update" "issueUpdate"

# the review's probes. every one is a bug or a want, or a comment/update
# with no --kind, so a kind gate cannot be what catches it.
run file --kind bug --title "short key" --body "see lin_api_abcdefghijklmnopqrs" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a 19-character lin_api_ suffix in a bug body is refused" 1
not_logged "…before any API call" "query"

run file --kind want --title "LIN_API_abcdefgh leaked" --body "value: 4"
ok "an uppercase LIN_API_ key in a want title is refused" 1
not_logged "…before gh" "issue create"

run comment --id 12 --body "see lin_api_abcd-efgh"
ok "a hyphenated lin_api_ key in a comment is refused" 1
not_logged "…before gh" "issue comment"

run update --id 12 --body $'see lin_api_abcd\nefghijkl'
ok "a lin_api_ key split across a newline is refused" 1
not_logged "…before gh" "issue edit"

run file --kind bug --title "stripe" --body "sk_live_0123456789abcdef"
ok "an sk_live_ key in a bug body is refused" 1
not_logged "…before gh" "issue create"

run file --kind want --title "stripe test" --body "sk_test_0123456789abcdef"
ok "an sk_test_ key in a want body is refused" 1

run file --kind bug --title "header" --body "Bearer abcdefghijklmnopqrstuvwx"
ok "a Bearer token in a bug body is refused" 1

run comment --id 12 --body "AIzaSy0123456789ABCDEFGHIJKLMNOPQRSTUVW"
ok "an AIza key in a comment is refused" 1

run update --id 12 --body "ASIA0123456789ABCDEF"
ok "an ASIA key in an update is refused" 1

run file --kind bug --title "password=hunter2" --body "severity: medium"
ok "a password assignment in a bug title is refused" 1
not_logged "…before gh" "issue create"

run file --kind want --title "callback" --body "call +1-415-555-0199"
ok "a phone number in a want body is refused" 1

run file --kind bug --title "token" --body "API_TOKEN=abc"
ok "an API_TOKEN assignment in a bug body is refused" 1
not_logged "…before gh" "issue create"

run file --kind bug --title "db" --body "DB_PASSWORD=hunter2"
ok "a DB_PASSWORD assignment in a bug body is refused" 1

run file --kind want --title "key" --body "SECRET_KEY=xyz"
ok "a SECRET_KEY assignment in a want body is refused" 1

run file --kind bug --title "phone" --body "call (415)555-0199"
ok "a parenthesized phone number in a bug body is refused" 1

run search --kind bug --query "see a@ex.com"
ok "a github search query that names an email is refused" 1
not_logged "…before gh" "issue list"

run search --kind want --query "ghp_abcdefghijklmnopqrstuvwxyz1234"
ok "a github search query that carries a token is refused" 1
not_logged "…before gh" "issue list"

run search --kind bug --query $'lin_api_abcd\nefghijkl'
ok "a github search query with a newline-split lin_api_ key is refused" 1
not_logged "…before gh" "issue list"

run search --kind bug --query "see a@ex.com" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a linear search query that names an email is refused" 1
not_logged "…before any API call" "query"

run search --kind want --query "ghp_abcdefghijklmnopqrstuvwxyz1234" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a linear search query that carries a token is refused" 1
not_logged "…before any API call" "query"

run search --kind bug --query $'lin_api_abcd\nefghijkl' \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a linear search query with a newline-split lin_api_ key is refused" 1
not_logged "…before any API call" "query"

run file --kind security --title "token in the log" --body $'See issues/token.md\n**Repro:** open /login' \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body with a Repro section is refused" 1
err_has "…and names the pointer-only rule" "pointer-only"
not_logged "…before any API call" "query"

run file --kind security --title "token in the log" --body "**Root cause:** the check" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body with a Root cause section is refused" 1

run file --kind security --title "token in the log" --body "**Exploit:** send the payload" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body with an Exploit section is refused" 1

long=$(printf 'x%.0s' {1..301})
run file --kind security --title "token in the log" --body "$long" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security body longer than 300 characters is refused" 1
not_logged "…before any API call" "query"

short=$(printf 'x%.0s' {1..300})
run file --kind security --title "token in the log" --body "$short" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a 300-character security pointer is filed" 0
logged "…and creates the issue" "issueCreate"

run file --kind bug --title "Blank page" --body $'**Observed:** blank page\n**Repro:** open /login\n**Call sites:** src/login.ts:4'
ok "a bug body may carry a plain repro" 0
logged "…and still files" "issue create"

run file --kind bug --title "short" --body "lin_api_abcdefg"
ok "a 7-character lin_api_ suffix is not a key" 0
logged "…and still files" "issue create"

# a secret that already sits on the next line. deleting the newline glues the
# previous word on and the word boundary in front of the key disappears.
boundary_probes=(
  $'The leaked token\nghp_abcdefghijklmnopqrstuvwxyz1234'
  $'key\nAKIA0123456789ABCDEF\nwas in the log'
  $'see\nlin_api_abcdefgh'
  $'here\nsk-abcdefghijklmnopqrstuvwx'
  $'notes\nSECRET_KEY=hunter2'
)
for probe in "${boundary_probes[@]}"; do
  tag=${probe%%$'\n'*}
  run file --kind bug --title "note" --body "$probe"
  ok "github file refuses a next-line secret [$tag]" 1
  not_logged "…before gh [$tag]" "issue create"
  run search --kind bug --query "$probe"
  ok "github search refuses a next-line secret [$tag]" 1
  not_logged "…before gh [$tag]" "issue list"
  run comment --id 12 --body "$probe"
  ok "github comment refuses a next-line secret [$tag]" 1
  not_logged "…before gh [$tag]" "issue comment"
  run update --id 12 --body "$probe"
  ok "github update refuses a next-line secret [$tag]" 1
  not_logged "…before gh [$tag]" "issue edit"
  run file --kind bug --title "note" --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear file refuses a next-line secret [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
  run search --kind bug --query "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear search refuses a next-line secret [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
  run comment --id BG-41 --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear comment refuses a next-line secret [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
  run update --id BG-41 --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear update refuses a next-line secret [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
done

run file --kind bug --title "aws" --body "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI"
ok "a multi-segment AWS secret assignment is refused" 1
not_logged "…before gh" "issue create"

run file --kind want --title "login" --body "password: hunter2"
ok "a colon assignment with a space after it is refused" 1
not_logged "…before gh" "issue create"

# quoted JSON/YAML keys, a raw JWT, a Slack webhook, and a long API_KEY.
quoted_names=(
  "json password"
  "yaml client_secret"
  "quoted access_token"
  "quoted refresh_token"
  "quoted AWS secret"
  "api_key assignment"
  "json api_key"
  "apikey colon"
  "json apikey"
  "private_key assignment"
  "json private_key"
  "raw jwt"
  "slack webhook"
  "long API_KEY"
)
quoted_probes=(
  '{"password": "hunter2"}'
  "'client_secret': '...'"
  '"access_token"'
  '"refresh_token"'
  '"AWS_SECRET_ACCESS_KEY"'
  'api_key=abc'
  '{"api_key": "abc"}'
  'apikey: 0123456789abcdef'
  '{"apikey": "abc"}'
  'private_key=abc'
  '{"private_key": "abc"}'
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c'
  'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
  'API_KEY=0123456789abcdef'
)
for i in "${!quoted_probes[@]}"; do
  probe=${quoted_probes[$i]}
  tag=${quoted_names[$i]}
  run file --kind bug --title "note" --body "$probe"
  ok "github file refuses [$tag]" 1
  not_logged "…before gh [$tag]" "issue create"
  run search --kind bug --query "$probe"
  ok "github search refuses [$tag]" 1
  not_logged "…before gh [$tag]" "issue list"
  run comment --id 12 --body "$probe"
  ok "github comment refuses [$tag]" 1
  not_logged "…before gh [$tag]" "issue comment"
  run update --id 12 --body "$probe"
  ok "github update refuses [$tag]" 1
  not_logged "…before gh [$tag]" "issue edit"
  run file --kind bug --title "note" --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear file refuses [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
  run search --kind bug --query "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear search refuses [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
  run comment --id BG-41 --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear comment refuses [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
  run update --id BG-41 --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "linear update refuses [$tag]" 1
  not_logged "…before any API call [$tag]" "query"
done

run file --kind security --title "**Exploit:** in the title" --body "see issues/token.md" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security title with an Exploit section is refused" 1
err_has "…and names the pointer-only rule" "pointer-only"
not_logged "…before any API call" "query"

run file --kind security --title "**Repro:** open /login" --body "see issues/token.md"
ok "a security title with a Repro section is refused on github before the advisory exit" 1
not_logged "…and does not call gh" "issue"

long_title=$(printf 't%.0s' {1..121})
run file --kind security --title "$long_title" --body "see issues/token.md" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a security title longer than 120 characters is refused" 1
not_logged "…before any API call" "query"

ok_title=$(printf 't%.0s' {1..120})
run file --kind security --title "$ok_title" --body "see issues/token.md" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a 120-character security title is filed" 0
logged "…and creates the issue" "issueCreate"

run comment --kind security --id 12 --body $'**Repro:** open /login'
ok "a github comment with --kind security and a Repro section is refused" 1
not_logged "…before gh" "issue comment"

run update --kind security --id BG-41 --body $'**Root cause:** the check' \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a linear update with --kind security and a Root cause section is refused" 1
not_logged "…before any API call" "query"

run comment --id 12 --body $'**Repro:** open /login' KRU_TEST_SECURITY_ISSUE=1
ok "a comment on a github security issue with a Repro section is refused" 1
not_logged "…and does not comment" "issue comment"

run update --id 12 --body $'**Exploit:** send the payload' KRU_TEST_SECURITY_ISSUE=1
ok "an update on a github security issue with an Exploit section is refused" 1
not_logged "…and does not edit" "issue edit"

run comment --id BG-41 --body $'**Repro:** open /login' \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_SECURITY_ISSUE=1
ok "a comment on a linear security issue with a Repro section is refused" 1
not_logged "…and does not comment" "commentCreate"

run update --id BG-41 --body $'**Exploit:** send the payload' \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_SECURITY_ISSUE=1
ok "an update on a linear security issue with an Exploit section is refused" 1
not_logged "…and does not update" "issueUpdate"

run comment --id 12 --body $'**Repro:** open /login'
ok "a comment on a normal github issue may carry a repro" 0
logged "…and still comments" "issue comment"

run comment --id 12 --body "see issues/token.md" KRU_TEST_SECURITY_ISSUE=1
ok "a short pointer comment on a github security issue is sent" 0
logged "…and still comments" "issue comment"

# security text is pointer-only wherever the words appear, not only as headings.
pointer_names=(
  "reproduc"
  "steps to"
  "repro"
  "root cause"
  "exploit"
  "poc"
  "proof of concept"
  "payload"
  "POST /"
  "GET /"
)
pointer_probes=(
  "how to reproduce"
  "steps to log in"
  "a repro note"
  "root cause unknown"
  "an exploit note"
  "a poc note"
  "proof of concept"
  "the payload"
  "POST /login"
  "get /health"
)
for i in "${!pointer_probes[@]}"; do
  probe=${pointer_probes[$i]}
  tag=${pointer_names[$i]}
  run file --kind security --title "token in the log" --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
  ok "a linear security body containing [$tag] is refused" 1
  not_logged "…before any API call [$tag]" "query"
  run file --kind security --title "$probe" --body "see issues/token.md"
  ok "a github security title containing [$tag] is refused" 1
  not_logged "…and does not call gh [$tag]" "issue"
  run comment --kind security --id 12 --body "$probe"
  ok "a github security comment containing [$tag] is refused" 1
  not_logged "…before gh [$tag]" "issue comment"
  run update --id BG-41 --body "$probe" \
    KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_SECURITY_ISSUE=1
  ok "an update on a linear security issue containing [$tag] is refused" 1
  not_logged "…and does not update [$tag]" "issueUpdate"
done

run file --kind bug --title "Blank page" --body $'steps to log in\nPOST /login\nproof of concept\nthe payload'
ok "a bug body may name a repro, a payload, and a path" 0
logged "…and still files" "issue create"

run update --id BG-41 --body "see issues/token.md" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_SECURITY_ISSUE=1
ok "a short pointer update on a linear security issue is sent" 0
logged "…and still updates" "issueUpdate"

run comment --id "BG-41;touch" --body "more" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a Linear comment id must match the link grammar" 1
err_has "…and names the identifier" "ENG-123"
not_logged "…before any API call" "query"

run update --id "BG-41;touch" --body "value: 5" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a Linear update id must match the link grammar" 1
not_logged "…before any API call" "query"

run close --id "BG-41;touch" \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a Linear close id must match the link grammar" 1
not_logged "…before any API call" "query"

run link --id "BG-41;touch" KRU_TRACKER=linear
ok "a Linear link id rejects the same injection" 1

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
RULE='bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand'
for f in skills/kru-lead/SKILL.md skills/kru-lead/references/reconcile.md TRACKER.md skills/kru-issue/SKILL.md scripts/cursor/edits.mjs; do
  report "$f states the tracker-text rule" "$(grep -qF "$RULE" "$repo/$f" && echo true || echo false)" "missing the rule"
done
rule_count=$(grep -cF "$RULE" "$repo/TRACKER.md" || true)
report "TRACKER.md states the rule once" "$([ "$rule_count" = 1 ] && echo true || echo false)" "count $rule_count"
report "lead line 8 states the rule" "$(sed -n '8p' "$repo/skills/kru-lead/SKILL.md" | grep -qF "$RULE" && echo true || echo false)" "line 8"
report "reconcile line 12 states the rule" "$(sed -n '12p' "$repo/skills/kru-lead/references/reconcile.md" | grep -qF "$RULE" && echo true || echo false)" "line 12"
report "kru-issue line 17 states the rule" "$(sed -n '17p' "$repo/skills/kru-issue/SKILL.md" | grep -qF "$RULE" && echo true || echo false)" "line 17"
report "kru-issue line 42 states the rule" "$(sed -n '42p' "$repo/skills/kru-issue/SKILL.md" | grep -qF "$RULE" && echo true || echo false)" "line 42"
header=$(sed -n '1,7p' "$repo/scripts/kru-tracker.test.sh" | sed 's/^# *//')
report "the test header states the rule" "$(printf '%s\n' "$header" | grep -qF "$RULE" && echo true || echo false)" "header [$header]"
report "the lead puts a period after the tracker-text rule" "$(sed -n '8p' "$repo/skills/kru-lead/SKILL.md" | grep -qF 'hand. It never' && echo true || echo false)" "missing period"
report "the lead fork edit puts a period after the tracker-text rule" "$(grep -qF 'hand. It never' "$repo/scripts/cursor/edits.mjs" && echo true || echo false)" "missing period"
report "TRACKER.md keeps comments on a security issue pointer-only" "$(grep -qF 'A comment or an update on a security issue stays pointer-only' "$repo/TRACKER.md" && echo true || echo false)" "missing"
report "the lead no longer keeps security off Linear" "$(grep -qF "or to Linear" "$repo/skills/kru-lead/SKILL.md" && echo false || echo true)" "still says or to Linear"
report "the lead fork edit no longer keeps security off Linear" "$(grep -qF "or to Linear" "$repo/scripts/cursor/edits.mjs" && echo false || echo true)" "edit still says or to Linear"
report "kru-issue files security through MCP without the script" "$(grep -qF "do not call the script" "$repo/skills/kru-issue/SKILL.md" && echo true || echo false)" "missing"
report "…and a missing key is not exit 4" "$(grep -qF "not exit 4" "$repo/skills/kru-issue/SKILL.md" && echo true || echo false)" "missing"

# every command the dispatcher implements, and the user strings it sends.
# outbound marks a string; the send functions refuse one that was not marked.
expected_cmds=$(printf '%s\n' backend ready file list list-effort search show comment update close link 'help|-h|--help')
actual_cmds=$(awk '
  /^case "\$cmd" in$/ { on=1; next }
  on && /^esac$/ { exit }
  on && /^  \*\)/ { next }
  on && /^  [^ )]+\)/ {
    name=$1
    sub(/\).*/, "", name)
    print name
  }
' "$repo/scripts/kru-tracker.sh")
report "the dispatcher commands match the census" "$([ "$actual_cmds" = "$expected_cmds" ] && echo true || echo false)" "got [$actual_cmds]"
fn_body() {
  awk -v fn="$1" '
    index($0, fn "()")==1 { p=1 }
    p && index($0, fn "()")!=1 && /^[A-Za-z_][A-Za-z0-9_]*\(\)/ { exit }
    p { print }
  ' "$repo/scripts/kru-tracker.sh"
}
report "file sends the title and the body through outbound" "$(fn_body cmd_file | grep -qF 'outbound "$TITLE"' && fn_body cmd_file | grep -qF 'outbound "$BODY" body' && echo true || echo false)" "missing"
report "search sends the query through outbound" "$(fn_body cmd_search | grep -qF 'outbound "$QUERY"' && echo true || echo false)" "missing"
report "comment sends the body through outbound" "$(fn_body cmd_comment | grep -qF 'outbound "$BODY" body' && echo true || echo false)" "missing"
report "update sends the body through outbound" "$(fn_body cmd_update | grep -qF 'outbound "$BODY" body' && echo true || echo false)" "missing"
for quiet in cmd_list cmd_ready cmd_close cmd_link; do
  report "$quiet sends no user text" "$(fn_body "$quiet" | grep -qF outbound && echo false || echo true)" "calls outbound"
done
for sender in github_file github_search github_comment github_update github_list_effort linear_file linear_search linear_comment linear_update linear_list_effort; do
  report "$sender refuses unchecked text" "$(fn_body "$sender" | grep -qF require_outbound && echo true || echo false)" "missing require_outbound"
done

if (cd "$repo" && node --input-type=module -e '
import { readFileSync } from "node:fs"
import { EMAIL_SOURCE, SECRET_PATTERNS, leakIn } from "./scripts/leak-patterns.mjs"
import { PATTERNS } from "./scripts/privacy-scan.mjs"
const fail = (m) => { console.error(m); process.exit(1) }
if (PATTERNS.length < SECRET_PATTERNS.length) fail("privacy-scan dropped a secret pattern")
for (let i = 0; i < SECRET_PATTERNS.length; i++) {
  const p = SECRET_PATTERNS[i]
  const got = PATTERNS[i]
  if (!got || got.id !== p.id) fail("id " + i + ": " + (got && got.id) + " != " + p.id)
  if (got.re.source !== p.source) fail("source " + p.id)
  if (got.re.flags !== (p.flags || "")) fail("flags " + p.id + ": " + got.re.flags)
}
const email = PATTERNS[SECRET_PATTERNS.length]
if (!email || email.id !== "email" || email.re.source !== EMAIL_SOURCE) fail("email source drifted")
const guard = readFileSync("scripts/guard-text.mjs", "utf8")
if (!guard.includes("leak-patterns.mjs")) fail("guard-text does not import leak-patterns")
if (/lin_api_|sk_live_|AIza/.test(guard)) fail("guard-text copies a pattern")
const scan = readFileSync("scripts/privacy-scan.mjs", "utf8")
if (!scan.includes("secretRegs()")) fail("privacy-scan does not call secretRegs")
if (scan.includes("lin_api_")) fail("privacy-scan copies lin_api_")
if (!leakIn("lin_api_abcd\nefghijkl")) fail("newline-split lin_api_ was missed")
if (leakIn("lin_api_abcdefg")) fail("a 7-character suffix was treated as a key")
if (!leakIn("password=hunter2")) fail("password assignment missed")
if (!leakIn("API_TOKEN=abc")) fail("API_TOKEN assignment missed")
if (!leakIn("DB_PASSWORD=hunter2")) fail("DB_PASSWORD assignment missed")
if (!leakIn("SECRET_KEY=xyz")) fail("SECRET_KEY assignment missed")
if (leakIn("const token = abc")) fail("a spaced token assignment was treated as a leak")
if (!leakIn("AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI")) fail("multi-segment assignment missed")
if (!leakIn("password: hunter2")) fail("colon assignment missed")
if (!leakIn("password: \"hunter2\"")) fail("quoted colon assignment missed")
if (!leakIn("{\"password\": \"hunter2\"}")) fail("json password missed")
if (!leakIn("\x27client_secret\x27: \x27...\x27")) fail("yaml client_secret missed")
if (!leakIn("\"access_token\"")) fail("quoted access_token missed")
if (!leakIn("\"refresh_token\"")) fail("quoted refresh_token missed")
if (!leakIn("\"AWS_SECRET_ACCESS_KEY\"")) fail("quoted AWS secret missed")
if (!leakIn("api_key=abc")) fail("api_key assignment missed")
if (!leakIn("{\"api_key\": \"abc\"}")) fail("json api_key missed")
if (!leakIn("{\"apikey\": \"abc\"}")) fail("json apikey missed")
if (!leakIn("private_key=abc")) fail("private_key assignment missed")
if (!leakIn("{\"private_key\": \"abc\"}")) fail("json private_key missed")
if (!leakIn("apikey: 0123456789abcdef")) fail("long apikey colon missed")
if (!leakIn("API_KEY=0123456789abcdef")) fail("long API_KEY missed")
if (!leakIn("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")) fail("jwt missed")
if (!leakIn("https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX")) fail("slack webhook missed")
const generic = SECRET_PATTERNS.find((p) => p.id === "generic-api-key")
if (!generic) fail("generic-api-key missing")
const genericRe = new RegExp(generic.source, generic.flags || "")
if (genericRe.test("apikey: 0123456789abcde")) fail("a 15-character api key met the 16-character rule")
if (!genericRe.test("apikey: 0123456789abcdef")) fail("a 16-character api key missed the generic rule")
if (leakIn("authToken=abc")) fail("a camelCase token assignment was treated as a leak")
if (leakIn("secret: the")) fail("prose after a colon was treated as a leak")
if (leakIn("The secret: consistency.")) fail("prose after a colon was treated as a leak")
if (!leakIn("The leaked token\nghp_abcdefghijklmnopqrstuvwxyz1234")) fail("next-line ghp_ was missed")
if (!leakIn("key\nAKIA0123456789ABCDEF\nwas in the log")) fail("next-line AKIA was missed")
if (!leakIn("see\nlin_api_abcdefgh")) fail("next-line lin_api_ was missed")
if (!leakIn("here\nsk-abcdefghijklmnopqrstuvwx")) fail("next-line sk- was missed")
if (!leakIn("notes\nSECRET_KEY=hunter2")) fail("next-line SECRET_KEY was missed")
if (!leakIn("+1-415-555-0199")) fail("phone missed")
if (!leakIn("(415)555-0199")) fail("parenthesized phone missed")
'); then
  report "privacy-scan and guard_text share one secret list" true ""
else
  report "privacy-scan and guard_text share one secret list" false "patterns diverged"
fi

run list-effort --brief plan/onboarding/brief.md
is "github list-effort returns linked issues and maps closed to done" '[{"id":"12","title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/12","state":"open"},{"id":"50","title":"Wontfix","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/50","state":"canceled"},{"id":"40","title":"Extra","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/40","state":"done"}]'
logged "…searches every state in the body" "plan/onboarding/brief.md in:body"
logged "…and follows the next page" "after=page-2"
not_logged "…past a single page of issue list" "issue list --limit 100"
no_writes "github list-effort"

run list-effort --brief plan/onboarding/brief.md KRU_TEST_GH_LOOSE=1
is "github list-effort follows every page before the exact path check" '[{"id":"12","title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/12","state":"open"}]'
logged "…through the second page" "after=page-2"
logged "…and the third" "after=page-3"
no_writes "github list-effort loose search"

run list-effort --brief 'plan/onboarding/brief.md user@example.com'
ok "a brief path carrying an email is refused" 1
err_has "…by the outbound guard" "customer emails"
not_logged "…before gh" "issue"
not_logged "…and before repo view" "repo view"

run list-effort --brief README.md
ok "list-effort wants a brief path" 1
err_has "…and names the shape" "plan/<effort>/brief.md"
not_logged "…and does not search" "issue list"

run list-effort --brief plan/onboarding/brief.md --kind bug
ok "list-effort does not take a kind" 1
not_logged "…and does not search" "issue list"

run show --id 99
is "github show prints one issue" '{"id":"99","title":"Orphan","body":"no link","url":"https://github.com/acme/web/issues/99","state":"open"}'
logged "…issue view" "issue view 99 --json number,title,body,url,state"

run show --id 404
ok "a missing github issue is an error" 1
err_has "…and says so" "no such issue"

run show --id '#12'
is "a hash-prefixed github id is normalized before show" '{"id":"12","title":"Orphan","body":"no link","url":"https://github.com/acme/web/issues/12","state":"open"}'
logged "…and the view uses the bare number" "issue view 12 --json"
not_logged "…without the hash" "issue view #"
no_writes "github show"

run show --id '#012'
is "leading zeros collapse to the same github number" '{"id":"12","title":"Orphan","body":"no link","url":"https://github.com/acme/web/issues/12","state":"open"}'
logged "…viewed as 12" "issue view 12 --json"

run show --id nope
ok "a non-numeric id is rejected before gh" 1
err_has "…and names the id shape" "an id is a GitHub issue number or a Linear identifier"
err_lacks "…and is not reported missing" "no such issue"
not_logged "…and does not view an issue" "issue view"

run show --id 99 KRU_TEST_GH_ERROR=1
ok "a github auth failure is not a missing issue" 5
err_has "…and names the tool error" "gh issue view failed"
err_lacks "…and does not say the issue is missing" "no such issue"

run show --id 77
is "a closed not_planned github issue is canceled" '{"id":"77","title":"Wontfix","body":"Brief: plan/onboarding/brief.md","url":"https://github.com/acme/web/issues/77","state":"canceled"}'

run list-effort --brief plan/onboarding/brief.md \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear list-effort includes completed and canceled" '[{"id":"BG-41","title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":"done"},{"id":"BG-9","title":"Dropped","body":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-9","state":"canceled"},{"id":"BG-8","title":"Extra","body":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-8","state":"open"}]'
logged "…sends the path as a variable" '"path":"plan/onboarding/brief.md"'
logged "…and follows the next page" '"after":"page-2"'
not_logged "…and does not skip completed" "nin:"
no_writes "linear list-effort"

run list-effort --brief plan/onboarding/brief.md \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_LINEAR_LOOSE=1
is "linear list-effort follows every page before the exact path check" '[{"id":"BG-41","title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":"done"}]'
logged "…through the second page" '"after":"page-2"'
logged "…and the third" '"after":"page-3"'
no_writes "linear list-effort loose search"

run show --id BG-41 \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "linear show maps completed to done" '{"id":"BG-41","title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":"done"}'

run show --id bg-41 \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
is "a lowercase linear id is uppercased before show" '{"id":"BG-41","title":"Invite","body":"Brief: plan/onboarding/brief.md","url":"https://linear.app/acme/issue/BG-41","state":"done"}'
logged "…and the query uses the uppercase id" '"id":"BG-41"'
no_writes "linear show"

run show --id BG-404 \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform
ok "a missing linear issue is an error" 1
err_has "…and says so" "no such issue"

run show --id BG-41 \
  KRU_TRACKER=linear LINEAR_API_KEY="$KEY" KRU_LINEAR_TEAM=BG KRU_LINEAR_PROJECT=Platform KRU_TEST_CURL_FAIL=1
ok "a linear transport failure is not a missing issue" 5
err_has "…and names the request failure" "Linear API request failed"
err_lacks "…and does not say the issue is missing" "no such issue"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
