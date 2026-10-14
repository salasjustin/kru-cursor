#!/bin/bash
# the work tracker: bugs and product wants. one command so a skill never
# calls `gh` or the Linear API itself and drifts from the setting.
#
#   KRU_TRACKER          github (default: unset or empty) | linear
#   KRU_LINEAR_TEAM      Linear team key (ENG) or id — required for linear
#   KRU_LINEAR_PROJECT   Linear project name or id — required for linear
#   LINEAR_API_KEY       Linear API key, from the environment only. never
#                        committed, never read from a plugin option, never printed
#
# anything else in KRU_TRACKER is a refusal (exit 2), not a fall-through to
# GitHub. a security finding is refused on both settings (exit 3): the store's
# issues/, or a GitHub private security advisory and that advisory's private
# fork. exit 4 means the chosen tracker can't take an item — the caller falls
# back to the store and repeats the reason.
#
# linear calls https://api.linear.app/graphql. when LINEAR_API_KEY is unset and
# the Linear MCP server is connected, TRACKER.md allows the same file, list,
# search, comment, update and close operations through its tools (same team,
# same project, labels bug and enhancement, still never security). this script
# is the path the tests cover and the path when MCP is absent.
#
# pull requests stay on GitHub. `link --id` prints the body line: `Fixes #<n>`
# or `Linear: ENG-123`. merge closes the GitHub issue; a Linear issue closes
# with `close`.
#
#   file    --kind bug|want --title T --body B     prints id<TAB>url
#   list    --kind bug|want                        JSON [{id,title,body,url}]
#   search  --kind bug|want --query Q              the same JSON, at most 10
#   comment --id ID --body B                       prints id
#   update  --id ID --body B                       prints id
#   close   --id ID                                prints id
#   link    --id ID                                the pull-request line
#   ready                                          exit 0 when file would be accepted
#   backend                                        prints github or linear
#
# sourcing defines nothing useful; run it.

set -u
set -o pipefail

for _kru_key in KRU_TRACKER KRU_LINEAR_TEAM KRU_LINEAR_PROJECT; do
  _kru_opt="CLAUDE_PLUGIN_OPTION_$_kru_key"
  [ -z "${!_kru_key:-}" ] && [ -n "${!_kru_opt:-}" ] && export "$_kru_key=${!_kru_opt}"
done
unset _kru_key _kru_opt

kru_tmp=$(mktemp -d)
trap 'rm -rf "$kru_tmp"' EXIT

die() { printf 'kru tracker: %s\n' "$*" >&2; exit 1; }
not_ready() { printf 'kru tracker: %s\n' "$*" >&2; exit 4; }
refuse_security() {
  printf '%s\n' "kru tracker: a security finding stays in the store's issues/ or a GitHub private security advisory (or that advisory's private fork). It is never filed on the work tracker — not a public GitHub issue, and not Linear." >&2
  exit 3
}

usage() {
  printf '%s\n' "usage: kru-tracker.sh backend|ready|file|list|search|comment|update|close|link ..." >&2
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
    security) refuse_security ;;
    *) die "kind must be bug or want" ;;
  esac
}

need_jq() { command -v jq >/dev/null 2>&1 || die "need jq on PATH"; }

# --- arguments ----------------------------------------------------------------
KIND="" TITLE="" BODY="" ID="" QUERY=""
KIND_SET=0 BODY_SET=0

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) [ $# -ge 2 ] || die "--kind needs a value"; KIND=$2; KIND_SET=1; shift 2 ;;
      --title) [ $# -ge 2 ] || die "--title needs a value"; TITLE=$2; shift 2 ;;
      --body) [ $# -ge 2 ] || die "--body needs a value"; BODY=$2; BODY_SET=1; shift 2 ;;
      --id) [ $# -ge 2 ] || die "--id needs a value"; ID=$2; shift 2 ;;
      --query) [ $# -ge 2 ] || die "--query needs a value"; QUERY=$2; shift 2 ;;
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

github_list() {
  local label=$1
  gh issue list --label "$label" --state open --limit 100 --json number,title,body,url | github_rows
}

github_search() {
  local label=$1 query=$2
  gh issue list --label "$label" --state open --limit 10 --search "$query" --json number,title,body,url | github_rows
}

github_comment() { gh issue comment "$1" --body "$2" >/dev/null || die "gh issue comment failed"; printf '%s\n' "$1"; }
github_update() { gh issue edit "$1" --body "$2" >/dev/null || die "gh issue edit failed"; printf '%s\n' "$1"; }
github_close() { gh issue close "$1" >/dev/null || die "gh issue close failed"; printf '%s\n' "$1"; }

# --- linear -------------------------------------------------------------------
_team_id=""
_project_id=""

linear_gql() {
  local query=$1 vars=$2 payload code
  [ -n "${LINEAR_API_KEY:-}" ] || not_ready "LINEAR_API_KEY is unset. Export it (never commit it). When the Linear MCP server is connected, file, list, search, comment, update and close through its tools instead — team ${KRU_LINEAR_TEAM:-<KRU_LINEAR_TEAM>}, project ${KRU_LINEAR_PROJECT:-<KRU_LINEAR_PROJECT>}, labels bug and enhancement — and still never send a security finding."
  command -v curl >/dev/null 2>&1 || not_ready "curl is not on PATH; the Linear API needs it. When the Linear MCP server is connected, use its tools instead."
  need_jq
  payload=$(jq -nc --arg q "$query" --argjson v "$vars" '{query:$q, variables:$v}') || die "could not encode the Linear request"
  code=$(curl -sS --max-time 30 --proto '=https' -o "$kru_tmp/body" -w '%{http_code}' \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "$payload" \
    https://api.linear.app/graphql) || die "Linear API request failed"
  [ "$code" = 200 ] || die "Linear API returned HTTP $code"
  if jq -e '.errors | type == "array" and length > 0' >/dev/null <"$kru_tmp/body"; then
    die "Linear API error: $(jq -r '.errors[0].message // "request failed"' <"$kru_tmp/body")"
  fi
  jq -c '.data' <"$kru_tmp/body"
}

linear_team_id() {
  local raw=${KRU_LINEAR_TEAM:-} data id
  [ -n "$raw" ] || not_ready "KRU_LINEAR_TEAM is unset"
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
  [ -n "$raw" ] || not_ready "KRU_LINEAR_PROJECT is unset"
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
  [ -n "$_team_id" ] || { _team_id=$(linear_team_id) || exit $?; }
  [ -n "$_project_id" ] || { _project_id=$(linear_project_id) || exit $?; }
}

linear_ready() {
  [ -n "${LINEAR_API_KEY:-}" ] || not_ready "LINEAR_API_KEY is unset. Export it (never commit it). When the Linear MCP server is connected, file, list, search, comment, update and close through its tools instead — team ${KRU_LINEAR_TEAM:-<KRU_LINEAR_TEAM>}, project ${KRU_LINEAR_PROJECT:-<KRU_LINEAR_PROJECT>}, labels bug and enhancement — and still never send a security finding."
  command -v curl >/dev/null 2>&1 || not_ready "curl is not on PATH; the Linear API needs it. When the Linear MCP server is connected, use its tools instead."
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

linear_list() {
  local label=$1 data
  data=$(linear_gql 'query($team:ID!, $project:ID!, $label:String!){ issues(first:100, filter:{team:{id:{eq:$team}}, project:{id:{eq:$project}}, labels:{name:{eqIgnoreCase:$label}}, state:{type:{nin:[completed, canceled]}}}){ nodes { identifier title description url } } }' \
    "$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg label "$label" '{team:$team, project:$project, label:$label}')") || exit $?
  linear_rows <<<"$data"
}

linear_search() {
  local label=$1 query=$2 data
  data=$(linear_gql 'query($team:ID!, $project:ID!, $label:String!, $q:String!){ issues(first:10, filter:{team:{id:{eq:$team}}, project:{id:{eq:$project}}, labels:{name:{eqIgnoreCase:$label}}, state:{type:{nin:[completed, canceled]}}, or:[{title:{containsIgnoreCase:$q}}, {description:{containsIgnoreCase:$q}}]}){ nodes { identifier title description url } } }' \
    "$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg label "$label" --arg q "$query" '{team:$team, project:$project, label:$label, q:$q}')") || exit $?
  linear_rows <<<"$data"
}

linear_issue() {
  local key=$1 data
  data=$(linear_gql 'query($id:String!){ issue(id:$id){ id identifier url team { id } state { type } } }' "$(jq -n --arg id "$key" '{id:$id}')") || exit $?
  jq -e '.issue | select(.id != null)' <<<"$data" || die "no Linear issue $key"
}

linear_file() {
  local label=$1 title=$2 body=$3 lid data id url
  lid=$(linear_label_id "$label" create) || exit $?
  data=$(linear_gql 'mutation($input:IssueCreateInput!){ issueCreate(input:$input){ success issue { identifier url } } }' \
    "$(jq -n --arg team "$_team_id" --arg project "$_project_id" --arg title "$title" --arg body "$body" --arg label "$lid" '{input:{teamId:$team, projectId:$project, title:$title, description:$body, labelIds:[$label]}}')") || exit $?
  id=$(jq -r '.issueCreate.issue.identifier // empty' <<<"$data")
  url=$(jq -r '.issueCreate.issue.url // empty' <<<"$data")
  [ -n "$id" ] && [ -n "$url" ] || die "Linear did not return an issue"
  printf '%s\t%s\n' "$id" "$url"
}

linear_comment() {
  local key=$1 body=$2 issue uuid
  issue=$(linear_issue "$key") || exit $?
  uuid=$(jq -r '.id' <<<"$issue")
  linear_gql 'mutation($input:CommentCreateInput!){ commentCreate(input:$input){ success } }' \
    "$(jq -n --arg id "$uuid" --arg body "$body" '{input:{issueId:$id, body:$body}}')" >/dev/null || exit $?
  jq -r '.identifier' <<<"$issue"
}

linear_update() {
  local key=$1 body=$2 issue uuid
  issue=$(linear_issue "$key") || exit $?
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
  [ "$KIND_SET" = 1 ] || die "file needs --kind bug|want"
  [ -n "$TITLE" ] || die "file needs --title"
  [ "$BODY_SET" = 1 ] || die "file needs --body"
  local label
  label=$(label_for "$KIND") || exit $?
  cmd_ready
  case "$BACKEND" in
    github) github_file "$label" "$TITLE" "$BODY" ;;
    linear) linear_file "$label" "$TITLE" "$BODY" ;;
  esac
}

cmd_list() {
  [ "$KIND_SET" = 1 ] || die "list needs --kind bug|want"
  local label
  label=$(label_for "$KIND") || exit $?
  cmd_ready
  case "$BACKEND" in
    github) github_list "$label" ;;
    linear) linear_list "$label" ;;
  esac
}

cmd_search() {
  [ "$KIND_SET" = 1 ] || die "search needs --kind bug|want"
  [ -n "$QUERY" ] || die "search needs --query"
  local label
  label=$(label_for "$KIND") || exit $?
  cmd_ready
  case "$BACKEND" in
    github) github_search "$label" "$QUERY" ;;
    linear) linear_search "$label" "$QUERY" ;;
  esac
}

cmd_comment() {
  [ -n "$ID" ] || die "comment needs --id"
  [ "$BODY_SET" = 1 ] || die "comment needs --body"
  cmd_ready
  case "$BACKEND" in
    github) github_comment "$ID" "$BODY" ;;
    linear) linear_comment "$ID" "$BODY" ;;
  esac
}

cmd_update() {
  [ -n "$ID" ] || die "update needs --id"
  [ "$BODY_SET" = 1 ] || die "update needs --body"
  cmd_ready
  case "$BACKEND" in
    github) github_update "$ID" "$BODY" ;;
    linear) linear_update "$ID" "$BODY" ;;
  esac
}

cmd_close() {
  [ -n "$ID" ] || die "close needs --id"
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
      case "$ID" in
        [A-Za-z]*-[0-9]*) printf 'Linear: %s\n' "$ID" ;;
        *) die "a Linear link id is the issue identifier, like ENG-123" ;;
      esac
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
  search) parse_args "$@"; cmd_search ;;
  comment) parse_args "$@"; cmd_comment ;;
  update) parse_args "$@"; cmd_update ;;
  close) parse_args "$@"; cmd_close ;;
  link) parse_args "$@"; cmd_link ;;
  help|-h|--help) usage ;;
  *) die "unknown command: $cmd" ;;
esac
