#!/bin/bash
# sessionstart + stop: keeps the store's home a git checkout of KRU_STORE_REPO,
# so it outlives a cloud vm and reaches every surface. `start` clones or pulls
# it and restores this repo's agent memory from it; `stop` saves the agent
# memory back and pushes whatever changed. stop, not session end: a vm is
# reclaimed without a reliable end event, so every turn end is a save point.
#
# KRU_STORE_REPO is `owner/repo` on github, or any url or path git can clone.
# unset, this hook does nothing. fail soft: a sync failure prints one line and
# the session continues. kill switch: export KRU_NO_STORE_SYNC=1.
mode=${1:-}
command -v git >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null)

# a stop re-entered by a blocking stop hook syncs too: the continuation turn
# can write to the store, and a clean tree with nothing ahead is a no-op
plugin_root="${2:-$CURSOR_PLUGIN_ROOT}"
. "$plugin_root/scripts/kru-store.sh" 2>/dev/null || exit 0
# both read after the resolver, which maps the /plugin options onto them
[ -z "${KRU_STORE_REPO:-}" ] && exit 0
[ -n "${KRU_NO_STORE_SYNC:-}" ] && exit 0

export GIT_TERMINAL_PROMPT=0
home=$(kru_home)
memory="$(kru_repo_root)/.claude/agent-memory-local"
stored=$(kru_path agent-memory)

# $1 is the user's line: what still holds, then one plain action. $2, the raw
# git error, is for the model — sessionstart carries it as additionalContext;
# stop has no model-only field short of blocking, so there it goes to stderr
say() {
  local msg="kru store: $1" raw=${2:-}
  # a budget that ran out says so, not the sign-in hint the failure line carries.
  # the clock decides, not git's words: ssh or a helper may print before the kill
  [ -n "$raw" ] && [ "$SECONDS" -ge "$deadline" ] && msg="kru store: ${1%%; sync failed*}; sync timed out after ${budget}s. A large store needs a higher KRU_STORE_SYNC_TIMEOUT"
  if command -v jq >/dev/null 2>&1; then
    if [ "$mode" = start ] && [ -n "$raw" ]; then
      jq -nc --arg m "$msg" --arg r "kru store sync error: $raw" \
        '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $r}}'
      exit 0
    fi
    jq -nc --arg m "$msg" '{systemMessage: $m}'
  else printf '%s\n' "$msg"; fi
  [ -n "$raw" ] && printf 'kru store: %s\n' "$raw" >&2
  exit 0
}

case "$KRU_STORE_REPO" in
  *://*|/*|.*|*@*:*) url=$KRU_STORE_REPO ;;
  *) url="https://github.com/$KRU_STORE_REPO.git" ;;
esac

g() { git -C "$home" "$@"; }
# a remote that hangs must not hold the hook: every network call this run
# makes shares one budget (KRU_STORE_SYNC_TIMEOUT; 10s at start, 20s at stop),
# and the watchdog kills the call's process group, so the ssh or remote helper
# git spawned ends with it. git's low-speed abort ends a stalled transfer sooner
# a value that isn't a positive count of seconds gets the default; 0 falls back, 08 is eight
budget=${KRU_STORE_SYNC_TIMEOUT:-}
[[ $budget =~ ^[0-9]+$ ]] && [ "$((10#$budget))" -gt 0 ] && budget=$((10#$budget)) || budget=$([ "$mode" = stop ] && echo 20 || echo 10)
deadline=$((SECONDS + budget))
net() {
  local left=$((deadline - SECONDS)) pid dog rc
  [ "$left" -gt 0 ] || { echo "no answer from the remote in time" >&2; return 124; }
  set -m
  git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime="$left" "$@" &
  pid=$!
  set +m
  ( trap 'kill "$s"; exit' TERM; sleep "$left" & s=$!; wait "$s"; kill -TERM -- "-$pid" ) >/dev/null 2>&1 &
  dog=$!
  wait "$pid"; rc=$?
  kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null
  [ "$rc" -gt 128 ] && echo "no answer from the remote in ${left}s" >&2
  return "$rc"
}
first_line() { printf '%s' "$1" | head -n 1 | cut -c1-160; }

# newer file wins, both directions; a dir that doesn't exist yet is skipped
copy_newer() {
  local from=$1 to=$2
  [ -d "$from" ] || return 0
  mkdir -p "$to" || return 1
  if command -v rsync >/dev/null 2>&1; then rsync -a --update "$from/" "$to/"
  else cp -Rp "$from/." "$to/"; fi
}

# a store repo nobody seeded still keeps hook state local and merges appends.
# a store seeded with `merge=union` moves to the line merge, since union
# brings back a line one side deleted whenever the other appended beside it
seed_defaults() {
  [ -f "$home/.gitignore" ] || printf '%s\n' '# session-lived hook state' 'audit/' 'lead-gate/' 'tmp/' '.DS_Store' > "$home/.gitignore"
  [ -f "$home/.gitattributes" ] || printf '%s\n' \
    '# line files: both sides of a concurrent append land, and a deletion holds' \
    'inbox.md merge=kru-lines' 'refusals.jsonl merge=kru-lines' 'management/*/TODOS.md merge=kru-lines' > "$home/.gitattributes"
  if grep -q 'merge=union' "$home/.gitattributes"; then
    sed -e 's/merge=union/merge=kru-lines/' \
      -e 's/^# append-only files: keep both sides of a concurrent append$/# line files: both sides of a concurrent append land, and a deletion holds/' \
      "$home/.gitattributes" > "$home/.gitattributes.tmp" && mv "$home/.gitattributes.tmp" "$home/.gitattributes"
  fi
}

# the driver lives in .git/config, which no clone carries, so every run sets it
# to this install's copy. a client without it falls back to a text merge, and
# its rebase fails soft below
register_driver() {
  g config merge.kru-lines.name 'kru line files' &&
    g config merge.kru-lines.driver "bash '$plugin_root/scripts/kru-merge-lines.sh' %O %A %B"
}

case "$mode" in
  start)
    if [ ! -d "$home/.git" ]; then
      tmp=$(mktemp -d) || say "not loaded; sync failed. Free some disk space and restart the session"
      err=$(net clone -q "$url" "$tmp/store" 2>&1) || { rm -rf "$tmp"; say "not loaded; sync failed. Check that $KRU_STORE_REPO exists and you're signed in to GitHub (gh auth status)" "$(first_line "$err")"; }
      mkdir -p "$home"
      # a home that already holds files — hook state from this session — keeps
      # them; the checkout only fills in what the remote tracks
      mv "$tmp/store/.git" "$home/.git" && rm -rf "$tmp"
      g checkout -q -- . 2>/dev/null
    else
      register_driver
      err=$(net -C "$home" pull -q --rebase --autostash 2>&1) || say "using the local copy; sync failed. Check your network or GitHub sign-in (gh auth status)" "$(first_line "$err")"
    fi
    register_driver
    seed_defaults
    copy_newer "$stored" "$memory" || say "the team's notes for this repo weren't restored. Check free disk space"
    ;;
  stop)
    [ -d "$home/.git" ] || exit 0
    register_driver
    seed_defaults
    copy_newer "$memory" "$stored" || say "the team's notes for this repo weren't saved. Check free disk space"
    if [ -n "$(g status --porcelain 2>/dev/null)" ]; then
      sid=$(printf '%s' "$input" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | cut -c1-8)
      g add -A >/dev/null 2>&1
      err=$(g commit -q -m "store: $(kru_slug) ${sid:-session}" 2>&1) || say "saved locally; sync failed. Run git -C $home status to see what's blocking it" "$(first_line "$err")"
    fi
    # a push that failed on an earlier turn left commits ahead of the remote
    ahead=$(g rev-list --count '@{u}..HEAD' 2>/dev/null)
    [ "${ahead:-0}" = 0 ] && exit 0
    if ! net -C "$home" push -q 2>/dev/null; then
      err=$(net -C "$home" pull -q --rebase 2>&1) || { g rebase --abort >/dev/null 2>&1; say "saved locally; sync failed. Another machine's changes conflict: run git -C $home pull --rebase to merge them" "$(first_line "$err")"; }
      err=$(net -C "$home" push -q 2>&1) || say "saved locally; sync failed. Check your network or GitHub sign-in (gh auth status)" "$(first_line "$err")"
    fi
    ;;
esac
exit 0
