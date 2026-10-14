#!/bin/bash
# the work tracker: bugs and product wants. one command so a skill never
# calls `gh` or the Linear API itself and drifts from the setting.
#
#   KRU_TRACKER                 github (default: unset or empty) | linear
#   KRU_LINEAR_TEAM             Linear team key — required for linear.
#                               an example is BG, not a default.
#   KRU_LINEAR_PROJECT          Linear project name — required for linear.
#                               an example is Connector, not a default.
#   KRU_LINEAR_SECURITY_TEAM    optional. linear only. security findings go
#                               to this team. unset: the main team, with the
#                               label security, in KRU_LINEAR_PROJECT.
#   LINEAR_API_KEY              optional. the API fallback when Linear MCP
#                               tools are not connected. from the environment
#                               only: never committed, never read from a
#                               plugin option, never printed
#
# anything else in KRU_TRACKER is a refusal (exit 2), not a fall-through to
# GitHub. on github, a security finding is refused (exit 3): the store's
# issues/, or a GitHub private security advisory and that advisory's private
# fork. on linear it is filed, internal to the team. bug and want issues may
# carry a plain repro; a security issue is a short pointer to the store file.
# a comment or an update on a security issue stays pointer-only, including
# when --kind security is given. the sentence is TRACKER_TEXT, the same one
# TRACKER.md states once.
# exit 4 means this process can't take an item. on linear with no key, that is
# the API fallback only — a session whose Linear MCP tools are connected files
# there instead (TRACKER.md) and does not treat exit 4 as a reason to use the
# store.
# exit 5 is auth, network, or a tool error from show or list-effort. it is not
# "no such issue". the caller stops and reports it, and does not treat the id
# as missing.
#
# prefer those MCP tools when the agent has them. this script calls
# https://api.linear.app/graphql only as the fallback, and only with a key.
#
# pull requests stay on GitHub. `link --id` prints the body line: `Fixes #<n>`
# or `Linear: ENG-123`. merge closes the GitHub issue; a Linear issue closes
# with `close`.
#
#   file        --kind bug|want|security --title T --body B   prints id<TAB>url
#   list        --kind bug|want|security                      JSON [{id,title,body,url}]
#   list-effort --brief plan/<effort>/brief.md               JSON [{id,title,body,url,state}]
#               issues whose body contains that path, every page.
#               state is open, done, or canceled. a GitHub issue closed as
#               not_planned is canceled. the path goes through the outbound
#               guard before gh or the API.
#   search      --kind bug|want|security --query Q            the same JSON, at most 10
#   show        --id ID                                       one issue, list-effort shape
#               a leading # is stripped; a Linear id is uppercased.
#               exit 1 and the text "no such issue" means it does not exist.
#               exit 5 is auth, network, or a tool error.
#   comment     --id ID --body B                       prints id
#   update      --id ID --body B                       prints id
#   close       --id ID                                prints id
#   link        --id ID                                the pull-request line
#   ready                                              exit 0 when file would be accepted
#   backend                                            prints github or linear
#
# sourcing defines nothing useful; run it.

set -u
set -o pipefail

for _kru_key in KRU_TRACKER KRU_LINEAR_TEAM KRU_LINEAR_PROJECT KRU_LINEAR_SECURITY_TEAM; do
  _kru_opt="CLAUDE_PLUGIN_OPTION_$_kru_key"
  [ -z "${!_kru_key:-}" ] && [ -n "${!_kru_opt:-}" ] && export "$_kru_key=${!_kru_opt}"
done
unset _kru_key _kru_opt

kru_tmp=$(mktemp -d)
trap 'rm -rf "$kru_tmp"' EXIT

die() { printf 'kru tracker: %s\n' "$*" >&2; exit 1; }
missing_issue() { printf 'kru tracker: no such issue\n' >&2; exit 1; }
tracker_error() { printf 'kru tracker: %s\n' "$*" >&2; exit 5; }
not_ready() { printf 'kru tracker: %s\n' "$*" >&2; exit 4; }
refuse_security() {
  printf '%s\n' "kru tracker: on the GitHub tracker a security finding stays in the store's issues/ or a GitHub private security advisory (or that advisory's private fork). It is never a public GitHub issue." >&2
  exit 3
}

usage() {
  printf '%s\n' "usage: kru-tracker.sh backend|ready|file|list|list-effort|search|show|comment|update|close|link ..." >&2
  exit 1
}

tracker_name() {
  local t
  t=$(printf '%s' "${KRU_TRACKER:-}" | tr -d '[:space:]')
  case "$t" in
    ""|github) printf github ;;
    linear) printf linear ;;
    *) printf 'kru tracker: KRU_TRACKER must be github or linear (unset counts as github); got %s\n' "$t" >&2; exit 2 ;;
  esac
}

is_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

# tracker_name exits 2. a call inside $(...) would only exit that subshell,
# so every command records the name in the current shell first.
BACKEND=""
require_backend() { BACKEND=$(tracker_name) || exit $?; }

label_for() {
  case "$1" in
    bug) printf bug ;;
    want) printf enhancement ;;
    security)
      if [ "$BACKEND" = linear ]; then printf security
      else refuse_security
      fi
      ;;
    *) die "kind must be bug, want, or security" ;;
  esac
}

# one guard, every outbound field, every kind, every command. the patterns are
# scripts/leak-patterns.mjs — the same list scripts/privacy-scan.mjs uses.
# that check scans the original text, a copy with newlines turned into spaces,
# and a copy with newlines deleted, so a key on the next line keeps its word
# boundary and a key split across lines is one token.
kru_dir=$(cd "$(dirname "$0")" && pwd)
TRACKER_TEXT='bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand'
SECURITY_BODY_MAX=300
SECURITY_TITLE_MAX=120
# anywhere in the text, not only as a heading. a bug or want may still say
# these. a security title, body, comment, or update may not: reproduc, steps
# to, repro, root cause, exploit, poc, proof of concept, payload, or an HTTP
# method followed by a path (POST /login).
SECURITY_POINTER='reproduc|steps[[:space:]]+to|repro|root[[:space:]]+cause|exploit|poc|proof[[:space:]]+of[[:space:]]+concept|payload|(^|[^[:alpha:]])(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)[[:space:]]+/'

guard_text() {
  local text=$1 code
  printf '%s' "$text" | node "$kru_dir/guard-text.mjs"
  code=$?
  case "$code" in
    0) return 0 ;;
    1) die "$TRACKER_TEXT" ;;
    *) die "could not check tracker text" ;;
  esac
}

# a security title, body, comment, or update is a short pointer. a comment or
# an update on a security issue stays pointer-only, including when --kind
# security is given. bug and want text is not checked here.
guard_security_pointer() {
  local text=$1 max=$2
  [ "${#text}" -le "$max" ] || die "$TRACKER_TEXT"
  if printf '%s\n' "$text" | grep -Eiq "$SECURITY_POINTER"; then
    die "$TRACKER_TEXT"
  fi
}

guard_security_body() { guard_security_pointer "$1" "$SECURITY_BODY_MAX"; }
guard_security_title() { guard_security_pointer "$1" "$SECURITY_TITLE_MAX"; }

# the only way a user string reaches gh or Linear. send functions call
# require_outbound and refuse a string that never came through here, so a
# command cannot skip the check by passing TITLE, BODY, or QUERY itself.
# --kind security pointer-checks a title and a body here. a comment or an
# update whose target issue is security is pointer-checked at the send, after
# the label is read, because --kind may be unset.
outbound() {
  local text=$1 role=${2:-}
  guard_text "$text"
  if [ "${KIND:-}" = security ]; then
    case "$role" in
      body) guard_security_body "$text" ;;
      title) guard_security_title "$text" ;;
    esac
  fi
  printf '%s\0' "$text" >> "$kru_tmp/outbound"
}

require_outbound() {
  local text=$1 rec
  [ -f "$kru_tmp/outbound" ] || die "refusing to send tracker text that was not checked"
  while IFS= read -r -d '' rec || [ -n "$rec" ]; do
    [ "$rec" = "$text" ] && return 0
  done < "$kru_tmp/outbound"
  die "refusing to send tracker text that was not checked"
}

linear_id() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]] || die "a Linear id is the issue identifier, like ENG-123"
}

# strip a leading # and uppercase a Linear identifier. a bad shape dies here,
# before gh or the API, and the message is not "no such issue".
normalize_show_id() {
  local id=$1
  id=${id#\#}
  id=$(printf '%s' "$id" | tr -d '[:space:]')
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$((10#$id))"
    return 0
  fi
  if [[ "$id" =~ ^[A-Za-z][A-Za-z0-9]*-[0-9]+$ ]]; then
    printf '%s\n' "$id" | tr '[:lower:]' '[:upper:]'
    return 0
  fi
  die "an id is a GitHub issue number or a Linear identifier, like 12 or ENG-123"
}

need_jq() { command -v jq >/dev/null 2>&1 || die "need jq on PATH"; }

# --- arguments ----------------------------------------------------------------
KIND="" TITLE="" BODY="" ID="" QUERY="" BRIEF=""
KIND_SET=0 BODY_SET=0

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) [ $# -ge 2 ] || die "--kind needs a value"; KIND=$2; KIND_SET=1; shift 2 ;;
      --title) [ $# -ge 2 ] || die "--title needs a value"; TITLE=$2; shift 2 ;;
      --body) [ $# -ge 2 ] || die "--body needs a value"; BODY=$2; BODY_SET=1; shift 2 ;;
      --id) [ $# -ge 2 ] || die "--id needs a value"; ID=$2; shift 2 ;;
      --query) [ $# -ge 2 ] || die "--query needs a value"; QUERY=$2; shift 2 ;;
      --brief) [ $# -ge 2 ] || die "--brief needs a value"; BRIEF=$2; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
}

# --- github -------------------------------------------------------------------
github_ready() {
  command -v gh >/dev/null 2>&1 || not_ready "gh is not on PATH"
  local enabled
  if ! enabled=$(gh repo view --json hasIssuesEnabled -q .hasIssuesEnabled 2>"$kru_tmp/gh.err"); then
    not_ready "no GitHub remote, or gh is not signed in"
  fi
  [ "$enabled" = true ] || not_ready "GitHub issues are turned off on this repo"
}

github_id_from_url() {
  local url=$1 id
  url=${url//$'\r'/}
  url=$(printf '%s\n' "$url" | tail -n 1)
  id=${url##*/}
  id=${id%%\?*}
  case "$id" in
    ""|*[!0-9]*) die "gh did not return an issue url" ;;
  esac
  printf '%s\t%s\n' "$id" "$url"
}

github_file() {
  local label=$1 title=$2 body=$3 url
  require_outbound "$title"
  require_outbound "$body"
  if url=$(gh issue create --label "$label" --title "$title" --body "$body" 2>"$kru_tmp/gh.err"); then
    :
  elif grep -qi 'label' "$kru_tmp/gh.err"; then
    printf 'kru tracker: gh refused the label %s; filing without it\n' "$label" >&2
    url=$(gh issue create --title "$title" --body "$body" 2>"$kru_tmp/gh.err") || {
      cat "$kru_tmp/gh.err" >&2
      die "gh issue create failed"
    }
  else
    cat "$kru_tmp/gh.err" >&2
    die "gh issue create failed"
  fi
  github_id_from_url "$url"
}

github_rows() {
  need_jq
  jq -c '[.[] | {id: (.number | tostring), title, body, url}]'
}

github_number() {
  case "$1" in
    ""|*[!0-9]*) die "a GitHub id is the issue number" ;;
  esac
}

github_list() {
  local label=$1
  gh issue list --label "$label" --state open --limit 100 --json number,title,body,url | github_rows
}

# CLOSED is done, except not_planned, which is canceled. status lives here.
github_state_jq='if ((.state // "") | ascii_upcase) != "CLOSED" then "open" elif ((.stateReason // "") | ascii_upcase) == "NOT_PLANNED" then "canceled" else "done" end'

# effort issues, every page. the client keeps a body that contains the path.
# search is only the fetch. a stuck cursor is an error, not a short list.
github_list_effort() {
  local path=$1 repo cursor="" page=0 raw nodes has next acc="[]"
  require_outbound "$path"
  need_jq
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>"$kru_tmp/gh.err") || {
    cat "$kru_tmp/gh.err" >&2
    tracker_error "gh repo view failed"
  }
  local query='query($q:String!, $after:String){ search(first:100, after:$after, type:ISSUE, query:$q){ pageInfo { hasNextPage endCursor } nodes { ... on Issue { number title body url state stateReason } } } }'
  while :; do
    page=$((page + 1))
    [ "$page" -le 50 ] || tracker_error "gh issue search did not finish"
    if [ -n "$cursor" ]; then
      raw=$(gh api graphql -f query="$query" -f q="repo:${repo} is:issue ${path} in:body" -f after="$cursor" 2>"$kru_tmp/gh.err") || {
        cat "$kru_tmp/gh.err" >&2
        tracker_error "gh issue search failed"
      }
    else
      raw=$(gh api graphql -f query="$query" -f q="repo:${repo} is:issue ${path} in:body" 2>"$kru_tmp/gh.err") || {
        cat "$kru_tmp/gh.err" >&2
        tracker_error "gh issue search failed"
      }
    fi
    nodes=$(printf '%s\n' "$raw" | jq -ce --arg path "$path" '[.data.search.nodes[]? | select(.number != null) | select((.body // "") | contains($path)) | {id: (.number | tostring), title, body, url, state: ('"$github_state_jq"')}]') || tracker_error "could not read the GitHub search"
    acc=$(jq -nc --argjson a "$acc" --argjson b "$nodes" '$a + $b') || tracker_error "could not read the GitHub search"
    has=$(printf '%s\n' "$raw" | jq -r '.data.search.pageInfo.hasNextPage // false') || tracker_error "could not read the GitHub search"
    [ "$has" = true ] || break
    next=$(printf '%s\n' "$raw" | jq -r '.data.search.pageInfo.endCursor // empty') || tracker_error "could not read the GitHub search"
    if [ -z "$next" ] || [ "$next" = "$cursor" ]; then
      tracker_error "gh issue search did not advance"
    fi
    cursor=$next
  done
  printf '%s\n' "$acc"
}

github_show() {
  local id=$1 raw
  github_number "$id"
  if ! raw=$(gh issue view "$id" --json number,title,body,url,state,stateReason 2>"$kru_tmp/gh.err"); then
    if grep -Eqi 'could not resolve|not found|no such issue' "$kru_tmp/gh.err"; then
      missing_issue
    fi
    cat "$kru_tmp/gh.err" >&2
    tracker_error "gh issue view failed"
  fi
  printf '%s\n' "$raw" | jq -ce '{id: (.number | tostring), title, body, url, state: ('"$github_state_jq"')}' || tracker_error "could not read the GitHub issue"
}

# labeled matches, plus open issues with no label. a label gh refuses is filed
# with none, and a labeled-only glance misses that duplicate. the unlabeled
# pass is capped so it cannot pull the whole repo.
github_search() {
  local label=$1 query=$2 labeled bare
  require_outbound "$query"
  need_jq
  labeled=$(gh issue list --label "$label" --state open --limit 10 --search "$query" --json number,title,body,url) || die "gh issue list failed"
  bare=$(gh issue list --state open --limit 20 --search "no:label $query" --json number,title,body,url) || die "gh issue list failed"
  jq -n --argjson a "$labeled" --argjson b "$bare" '$a + $b | unique_by(.number)' | github_rows
}

github_issue_is_security() {
  local labels
  labels=$(gh issue view "$1" --json labels --jq '[.labels[].name] | join(",")') || die "could not read the GitHub issue"
  printf '%s\n' "$labels" | grep -qi security
}

# the label, not --kind. a security issue's comment or update stays pointer-only.
github_guard_security_issue() {
  local id=$1 body=$2
  github_issue_is_security "$id" || return 0
  guard_security_body "$body"
}

github_comment() {
  local id=$1 body=$2
  github_number "$id"
  require_outbound "$body"
  github_guard_security_issue "$id" "$body"
  gh issue comment "$id" --body "$body" >/dev/null || die "gh issue comment failed"
  printf '%s\n' "$id"
}

github_update() {
  local id=$1 body=$2
  github_number "$id"
  require_outbound "$body"
  github_guard_security_issue "$id" "$body"
  gh issue edit "$id" --body "$body" >/dev/null || die "gh issue edit failed"
  printf '%s\n' "$id"
}
github_close() { github_number "$1"; gh issue close "$1" >/dev/null || die "gh issue close failed"; printf '%s\n' "$1"; }

# --- linear -------------------------------------------------------------------
_team_id=""
_project_id=""

linear_key_missing() {
  not_ready "LINEAR_API_KEY is unset. The key is optional. When Linear MCP tools are connected, use those — team key ${KRU_LINEAR_TEAM:-<KRU_LINEAR_TEAM>}, project name ${KRU_LINEAR_PROJECT:-<KRU_LINEAR_PROJECT>}, labels bug and enhancement; a security finding uses ${KRU_LINEAR_SECURITY_TEAM:-the main team} and the label security — and do not fall back to the store. This script is the API fallback for when those tools are not connected, so this tracker is not ready. Never commit a key. Tracker text follows TRACKER.md."
}

# show and list-effort set this so a transport failure is exit 5, not "no such issue".
GQL_ERROR_IS_TRACKER=0
gql_fail() {
  if [ "${GQL_ERROR_IS_TRACKER:-}" = 1 ]; then
    tracker_error "$*"
  fi
  die "$*"
}

linear_gql() {
  local query=$1 vars=$2 payload code
  [ -n "${LINEAR_API_KEY:-}" ] || linear_key_missing
  case "$LINEAR_API_KEY" in
    *$'\r'*|*$'\n'*) die "LINEAR_API_KEY must not contain a carriage return or a line feed" ;;
  esac
  command -v curl >/dev/null 2>&1 || not_ready "curl is not on PATH. When Linear MCP tools are connected, use those instead; the key is optional. Otherwise this tracker is not ready."
  need_jq
  payload=$(jq -nc --arg q "$query" --argjson v "$vars" '{query:$q, variables:$v}') || gql_fail "could not encode the Linear request"
  code=$(curl -sS --max-time 30 --proto '=https' -o "$kru_tmp/body" -w '%{http_code}' \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "$payload" \
    https://api.linear.app/graphql) || gql_fail "Linear API request failed"
  [ "$code" = 200 ] || gql_fail "Linear API returned HTTP $code"
  if jq -e '.errors | type == "array" and length > 0' >/dev/null <"$kru_tmp/body"; then
    gql_fail "Linear API error: $(jq -r '.errors[0].message // "request failed"' <"$kru_tmp/body")"
  fi
  jq -c '.data' <"$kru_tmp/body"
}

linear_team_id() {
  local raw=$1 what=${2:-KRU_LINEAR_TEAM} data id
  [ -n "$raw" ] || not_ready "$what is unset. Set the team key, for example BG."
  if is_uuid "$raw"; then
    data=$(linear_gql 'query($id:String!){ team(id:$id){ id } }' "$(jq -n --arg id "$raw" '{id:$id}')") || exit $?
    id=$(jq -r '.team.id // empty' <<<"$data")
    [ -n "$id" ] || not_ready "no Linear team with id $raw"
    printf '%s' "$id"
    return 0
  fi
  data=$(linear_gql 'query($key:String!){ teams(filter:{key:{eq:$key}}){ nodes { id } } }' "$(jq -n --arg key "$raw" '{key:$key}')") || exit $?
  id=$(jq -r '.teams.nodes[0].id // empty' <<<"$data")
  if [ -z "$id" ]; then
    local upper
    upper=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')
    if [ "$upper" != "$raw" ]; then
      data=$(linear_gql 'query($key:String!){ teams(filter:{key:{eq:$key}}){ nodes { id } } }' "$(jq -n --arg key "$upper" '{key:$key}')") || exit $?
      id=$(jq -r '.teams.nodes[0].id // empty' <<<"$data")
    fi
  fi
  [ -n "$id" ] || not_ready "no Linear team with key $raw"
  printf '%s' "$id"
}

linear_project_id() {
  local raw=${KRU_LINEAR_PROJECT:-} data id count
  [ -n "$raw" ] || not_ready "KRU_LINEAR_PROJECT is unset. Set the project name, for example Connector."
  if is_uuid "$raw"; then
    data=$(linear_gql 'query($id:String!){ project(id:$id){ id } }' "$(jq -n --arg id "$raw" '{id:$id}')") || exit $?
    id=$(jq -r '.project.id // empty' <<<"$data")
    [ -n "$id" ] || not_ready "no Linear project with id $raw"
    printf '%s' "$id"
    return 0
  fi
  data=$(linear_gql 'query($name:String!){ projects(filter:{name:{eqIgnoreCase:$name}}, first:10){ nodes { id } } }' "$(jq -n --arg name "$raw" '{name:$name}')") || exit $?
  count=$(jq '.projects.nodes | length' <<<"$data")
  [ "$count" -gt 0 ] || not_ready "no Linear project named $raw"
  [ "$count" -eq 1 ] || not_ready "more than one Linear project named $raw; set KRU_LINEAR_PROJECT to the project id"
  jq -r '.projects.nodes[0].id' <<<"$data"
}

ensure_linear() {
  [ -n "$_team_id" ] || { _team_id=$(linear_team_id "$KRU_LINEAR_TEAM" KRU_LINEAR_TEAM) || exit $?; }
  [ -n "$_project_id" ] || { _project_id=$(linear_project_id) || exit $?; }
}

# security uses KRU_LINEAR_SECURITY_TEAM when set, and then no product project
# (that project belongs to the main team). otherwise the main team, the
# product project, and the label security.
use_security_scope() {
  [ "$KIND" = security ] || return 0
  [ "$BACKEND" = linear ] || return 0
  if [ -n "${KRU_LINEAR_SECURITY_TEAM:-}" ]; then
    _team_id=$(linear_team_id "$KRU_LINEAR_SECURITY_TEAM" KRU_LINEAR_SECURITY_TEAM) || exit $?
    _project_id=""
  fi
}

linear_ready() {
  [ -n "${KRU_LINEAR_TEAM:-}" ] || not_ready "KRU_LINEAR_TEAM is unset. Set the team key, for example BG."
  [ -n "${KRU_LINEAR_PROJECT:-}" ] || not_ready "KRU_LINEAR_PROJECT is unset. Set the project name, for example Connector."
  [ -n "${LINEAR_API_KEY:-}" ] || linear_key_missing
  command -v curl >/dev/null 2>&1 || not_ready "curl is not on PATH. When Linear MCP tools are connected, use those instead; the key is optional. Otherwise this tracker is not ready."
  ensure_linear
}

linear_label_id() {
  local name=$1 create=$2 data id
  data=$(linear_gql 'query($team:ID!){ issueLabels(filter:{team:{id:{eq:$team}}}, first:250){ nodes { id name } } }' "$(jq -n --arg team "$_team_id" '{team:$team}')") || exit $?
  id=$(jq -r --arg n "$name" '[.issueLabels.nodes[] | select(((.name // "") | ascii_downcase) == ($n | ascii_downcase))][0].id // empty' <<<"$data")
  if [ -n "$id" ]; then
    printf '%s' "$id"
    return 0
  fi
  [ "$create" = create ] || return 0
  data=$(linear_gql 'mutation($input:IssueLabelCreateInput!){ issueLabelCreate(input:$input){ success issueLabel { id } } }' "$(jq -n --arg name "$name" --arg team "$_team_id" '{input:{name:$name, teamId:$team}}')") || exit $?
  id=$(jq -r '.issueLabelCreate.issueLabel.id // empty' <<<"$data")
  [ -n "$id" ] || die "could not create the Linear label $name"
  printf '%s' "$id"
}

linear_rows() {
  # stdin is .data from a query whose issues.nodes carry identifier/title/description/url
  jq -c '[.issues.nodes[] | {id: .identifier, title, body: (.description // ""), url}]'
}

# the product project, every state, every page. the client keeps a description
# that contains the path. completed is done; canceled stays canceled.
linear_list_effort() {
  local path=$1 data cursor="" page=0 nodes has next acc="[]"
  require_outbound "$path"
  ensure_linear
  GQL_ERROR_IS_TRACKER=1
  local query='query($team:ID!, $project:ID!, $path:String!, $after:String){ issues(first:100, after:$after, filter:{team:{id:{eq:$team}}, project:{id:{eq:$project}}, description:{containsIgnoreCase:$path}}){ pageInfo { hasNextPage endCursor } nodes { identifier title description url state { type } } } }'
  while :; do
    page=$((page + 1))
    [ "$page" -le 50 ] || tracker_error "Linear issue search did not finish"
    data=$(linear_gql "$query" "$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg path "$path" --arg after "$cursor" '{team:$team, project:$project, path:$path, after:(if $after == "" then null else $after end)}')") || exit $?
    nodes=$(jq -c --arg path "$path" '[.issues.nodes[] | select((.description // "") | contains($path)) | {id: .identifier, title, body: (.description // ""), url, state: (if .state.type == "completed" then "done" elif .state.type == "canceled" then "canceled" else "open" end)}]' <<<"$data") || tracker_error "could not read the Linear issues"
    acc=$(jq -nc --argjson a "$acc" --argjson b "$nodes" '$a + $b') || tracker_error "could not read the Linear issues"
    has=$(jq -r '.issues.pageInfo.hasNextPage // false' <<<"$data") || tracker_error "could not read the Linear issues"
    [ "$has" = true ] || break
    next=$(jq -r '.issues.pageInfo.endCursor // empty' <<<"$data") || tracker_error "could not read the Linear issues"
    if [ -z "$next" ] || [ "$next" = "$cursor" ]; then
      tracker_error "Linear issue search did not advance"
    fi
    cursor=$next
  done
  printf '%s\n' "$acc"
}

linear_show() {
  local key=$1 data
  GQL_ERROR_IS_TRACKER=1
  data=$(linear_gql 'query($id:String!){ issue(id:$id){ identifier title description url state { type } } }' "$(jq -n --arg id "$key" '{id:$id}')") || exit $?
  if jq -e '.issue == null or .issue.identifier == null' >/dev/null <<<"$data"; then
    missing_issue
  fi
  jq -ce 'def st: if .state.type == "completed" then "done" elif .state.type == "canceled" then "canceled" else "open" end; .issue | {id: .identifier, title, body: (.description // ""), url, state: st}' <<<"$data" || tracker_error "could not read the Linear issue"
}

linear_list() {
  local label=$1 data
  if [ -n "$_project_id" ]; then
    data=$(linear_gql 'query($team:ID!, $project:ID!, $label:String!){ issues(first:100, filter:{team:{id:{eq:$team}}, project:{id:{eq:$project}}, labels:{name:{eqIgnoreCase:$label}}, state:{type:{nin:[completed, canceled]}}}){ nodes { identifier title description url } } }' \
      "$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg label "$label" '{team:$team, project:$project, label:$label}')") || exit $?
  else
    data=$(linear_gql 'query($team:ID!, $label:String!){ issues(first:100, filter:{team:{id:{eq:$team}}, labels:{name:{eqIgnoreCase:$label}}, state:{type:{nin:[completed, canceled]}}}){ nodes { identifier title description url } } }' \
      "$(jq -n --arg team "$_team_id" --arg label "$label" '{team:$team, label:$label}')") || exit $?
  fi
  linear_rows <<<"$data"
}

linear_search() {
  local label=$1 query=$2 data
  require_outbound "$query"
  if [ -n "$_project_id" ]; then
    data=$(linear_gql 'query($team:ID!, $project:ID!, $label:String!, $q:String!){ issues(first:10, filter:{team:{id:{eq:$team}}, project:{id:{eq:$project}}, labels:{name:{eqIgnoreCase:$label}}, state:{type:{nin:[completed, canceled]}}, or:[{title:{containsIgnoreCase:$q}}, {description:{containsIgnoreCase:$q}}]}){ nodes { identifier title description url } } }' \
      "$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg label "$label" --arg q "$query" '{team:$team, project:$project, label:$label, q:$q}')") || exit $?
  else
    data=$(linear_gql 'query($team:ID!, $label:String!, $q:String!){ issues(first:10, filter:{team:{id:{eq:$team}}, labels:{name:{eqIgnoreCase:$label}}, state:{type:{nin:[completed, canceled]}}, or:[{title:{containsIgnoreCase:$q}}, {description:{containsIgnoreCase:$q}}]}){ nodes { identifier title description url } } }' \
      "$(jq -n --arg team "$_team_id" --arg label "$label" --arg q "$query" '{team:$team, label:$label, q:$q}')") || exit $?
  fi
  linear_rows <<<"$data"
}

linear_issue() {
  local key=$1 data
  data=$(linear_gql 'query($id:String!){ issue(id:$id){ id identifier url team { id } state { type } labels { nodes { name } } } }' "$(jq -n --arg id "$key" '{id:$id}')") || exit $?
  jq -e '.issue | select(.id != null)' <<<"$data" || die "no Linear issue $key"
}

linear_issue_is_security() {
  local hit
  hit=$(jq -r '[.labels.nodes[]?.name // empty | ascii_downcase] | map(select(index("security") != null)) | length' <<<"$1") || die "could not read Linear labels"
  [ "$hit" != 0 ]
}

# the label, not --kind. a security issue's comment or update stays pointer-only.
linear_guard_security_issue() {
  local issue=$1 body=$2
  linear_issue_is_security "$issue" || return 0
  guard_security_body "$body"
}

linear_file() {
  local label=$1 title=$2 body=$3 lid data id url input
  require_outbound "$title"
  require_outbound "$body"
  lid=$(linear_label_id "$label" create) || exit $?
  if [ -n "$_project_id" ]; then
    input=$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg title "$title" --arg body "$body" --arg label "$lid" '{input:{teamId:$team, projectId:$project, title:$title, description:$body, labelIds:[$label]}}')
  else
    input=$(jq -n --arg team "$_team_id" --arg title "$title" --arg body "$body" --arg label "$lid" '{input:{teamId:$team, title:$title, description:$body, labelIds:[$label]}}')
  fi
  data=$(linear_gql 'mutation($input:IssueCreateInput!){ issueCreate(input:$input){ success issue { identifier url } } }' "$input") || exit $?
  id=$(jq -r '.issueCreate.issue.identifier // empty' <<<"$data")
  url=$(jq -r '.issueCreate.issue.url // empty' <<<"$data")
  [ -n "$id" ] && [ -n "$url" ] || die "Linear did not return an issue"
  printf '%s\t%s\n' "$id" "$url"
}

linear_comment() {
  local key=$1 body=$2 issue uuid
  require_outbound "$body"
  issue=$(linear_issue "$key") || exit $?
  linear_guard_security_issue "$issue" "$body"
  uuid=$(jq -r '.id' <<<"$issue")
  linear_gql 'mutation($input:CommentCreateInput!){ commentCreate(input:$input){ success } }' \
    "$(jq -n --arg id "$uuid" --arg body "$body" '{input:{issueId:$id, body:$body}}')" >/dev/null || exit $?
  jq -r '.identifier' <<<"$issue"
}

linear_update() {
  local key=$1 body=$2 issue uuid
  require_outbound "$body"
  issue=$(linear_issue "$key") || exit $?
  linear_guard_security_issue "$issue" "$body"
  uuid=$(jq -r '.id' <<<"$issue")
  linear_gql 'mutation($id:String!, $input:IssueUpdateInput!){ issueUpdate(id:$id, input:$input){ success } }' \
    "$(jq -n --arg id "$uuid" --arg body "$body" '{id:$id, input:{description:$body}}')" >/dev/null || exit $?
  jq -r '.identifier' <<<"$issue"
}

linear_close() {
  local key=$1 issue uuid team state data sid
  issue=$(linear_issue "$key") || exit $?
  if [ "$(jq -r '.state.type' <<<"$issue")" = completed ]; then
    jq -r '.identifier' <<<"$issue"
    return 0
  fi
  uuid=$(jq -r '.id' <<<"$issue")
  team=$(jq -r '.team.id' <<<"$issue")
  data=$(linear_gql 'query($team:ID!){ workflowStates(filter:{team:{id:{eq:$team}}, type:{eq:completed}}){ nodes { id name position } } }' \
    "$(jq -n --arg team "$team" '{team:$team}')") || exit $?
  sid=$(jq -r '[.workflowStates.nodes[]] | sort_by(.position) | .[0].id // empty' <<<"$data")
  [ -n "$sid" ] || die "the Linear team has no completed state"
  linear_gql 'mutation($id:String!, $input:IssueUpdateInput!){ issueUpdate(id:$id, input:$input){ success } }' \
    "$(jq -n --arg id "$uuid" --arg state "$sid" '{id:$id, input:{stateId:$state}}')" >/dev/null || exit $?
  jq -r '.identifier' <<<"$issue"
}

# --- commands -----------------------------------------------------------------
cmd_ready() {
  require_backend
  case "$BACKEND" in
    github) github_ready ;;
    linear) linear_ready ;;
  esac
}

cmd_file() {
  [ "$KIND_SET" = 1 ] || die "file needs --kind bug|want|security"
  [ -n "$TITLE" ] || die "file needs --title"
  [ "$BODY_SET" = 1 ] || die "file needs --body"
  outbound "$TITLE" title
  outbound "$BODY" body
  require_backend
  local label
  label=$(label_for "$KIND") || exit $?
  cmd_ready
  use_security_scope
  case "$BACKEND" in
    github) github_file "$label" "$TITLE" "$BODY" ;;
    linear) linear_file "$label" "$TITLE" "$BODY" ;;
  esac
}

cmd_list() {
  [ "$KIND_SET" = 1 ] || die "list needs --kind bug|want|security"
  require_backend
  local label
  label=$(label_for "$KIND") || exit $?
  cmd_ready
  use_security_scope
  case "$BACKEND" in
    github) github_list "$label" ;;
    linear) linear_list "$label" ;;
  esac
}

cmd_list_effort() {
  # the brief path is the only text sent. outbound runs before gh or the API,
  # same guard as a title or a body.
  [ -n "$BRIEF" ] || die "list-effort needs --brief"
  [ "$KIND_SET" = 0 ] || die "list-effort takes --brief, not --kind"
  outbound "$BRIEF"
  [[ "$BRIEF" =~ ^plan/[a-z0-9]+(-[a-z0-9]+)*/brief\.md$ ]] || die "a brief path is plan/<effort>/brief.md"
  require_backend
  cmd_ready
  case "$BACKEND" in
    github) github_list_effort "$BRIEF" ;;
    linear) linear_list_effort "$BRIEF" ;;
  esac
}

cmd_show() {
  [ -n "$ID" ] || die "show needs --id"
  ID=$(normalize_show_id "$ID") || exit $?
  require_backend
  [ "$BACKEND" = linear ] && linear_id "$ID"
  cmd_ready
  case "$BACKEND" in
    github) github_show "$ID" ;;
    linear) linear_show "$ID" ;;
  esac
}

cmd_search() {
  [ "$KIND_SET" = 1 ] || die "search needs --kind bug|want|security"
  [ -n "$QUERY" ] || die "search needs --query"
  outbound "$QUERY"
  require_backend
  local label
  label=$(label_for "$KIND") || exit $?
  cmd_ready
  use_security_scope
  case "$BACKEND" in
    github) github_search "$label" "$QUERY" ;;
    linear) linear_search "$label" "$QUERY" ;;
  esac
}

cmd_comment() {
  [ -n "$ID" ] || die "comment needs --id"
  [ "$BODY_SET" = 1 ] || die "comment needs --body"
  outbound "$BODY" body
  require_backend
  [ "$BACKEND" = linear ] && linear_id "$ID"
  cmd_ready
  case "$BACKEND" in
    github) github_comment "$ID" "$BODY" ;;
    linear) linear_comment "$ID" "$BODY" ;;
  esac
}

cmd_update() {
  [ -n "$ID" ] || die "update needs --id"
  [ "$BODY_SET" = 1 ] || die "update needs --body"
  outbound "$BODY" body
  require_backend
  [ "$BACKEND" = linear ] && linear_id "$ID"
  cmd_ready
  case "$BACKEND" in
    github) github_update "$ID" "$BODY" ;;
    linear) linear_update "$ID" "$BODY" ;;
  esac
}

cmd_close() {
  [ -n "$ID" ] || die "close needs --id"
  require_backend
  [ "$BACKEND" = linear ] && linear_id "$ID"
  cmd_ready
  case "$BACKEND" in
    github) github_close "$ID" ;;
    linear) linear_close "$ID" ;;
  esac
}

cmd_link() {
  [ -n "$ID" ] || die "link needs --id"
  require_backend
  case "$BACKEND" in
    github)
      case "$ID" in
        *[!0-9]*) die "a GitHub link id is the issue number" ;;
      esac
      printf 'Fixes #%s\n' "$ID"
      ;;
    linear)
      linear_id "$ID"
      printf 'Linear: %s\n' "$ID"
      ;;
  esac
}

[ $# -ge 1 ] || usage
cmd=$1
shift
case "$cmd" in
  backend) [ $# -eq 0 ] || usage; require_backend; printf '%s\n' "$BACKEND" ;;
  ready) [ $# -eq 0 ] || usage; cmd_ready ;;
  file) parse_args "$@"; cmd_file ;;
  list) parse_args "$@"; cmd_list ;;
  list-effort) parse_args "$@"; cmd_list_effort ;;
  search) parse_args "$@"; cmd_search ;;
  show) parse_args "$@"; cmd_show ;;
  comment) parse_args "$@"; cmd_comment ;;
  update) parse_args "$@"; cmd_update ;;
  close) parse_args "$@"; cmd_close ;;
  link) parse_args "$@"; cmd_link ;;
  help|-h|--help) usage ;;
  *) die "unknown command: $cmd" ;;
esac
