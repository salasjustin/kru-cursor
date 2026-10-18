#!/bin/bash
# the store's roots, resolved in one place. hooks source it; skills and seats
# call it as a command — `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh" project` —
# so no prompt re-derives a path and drifts from this one.
#
# two roots, because the store holds two lifetimes. the CROSS-PROJECT root is
# the preference loop and the hooks' own bookkeeping: it follows the user, not a
# repo. the PROJECT root is one project's plan of record. they diverge on a
# cloud vm, where there is no user level that outlives the session — the clone
# is the only thing that leaves the machine, so the plan of record goes in it.
#
# precedence, both roots: an explicit env var, then the surface's default.
# KRU_HOME set means the user has chosen a root and it wins everywhere,
# cloud included. KRU_STORE_REPO set means the home is a git checkout that
# hooks/store-sync.sh clones, pulls and pushes, so it outlives the vm and the
# plan of record stays in it rather than in the branch.
#
# sourcing defines functions and prints nothing.

# claude's /plugin options reach a hook as CLAUDE_PLUGIN_OPTION_<KEY>; cursor has
# no equivalent, so on cursor only the env vars below are read. kept for a
# claude install of the same tree (CLAUDE_PLUGIN_OPTION_<KEY>). each fills the env var of the same name only
# when that var is unset, so an export or a settings `env` entry still wins —
# a cloud vm sets KRU_STORE_REPO that way. a boolean option arrives as the
# string "true" or "false", and only "true" turns a switch on.
[ -z "${KRU_STORE_REPO:-}" ] && [ -n "${CLAUDE_PLUGIN_OPTION_KRU_STORE_REPO:-}" ] &&
  export KRU_STORE_REPO="$CLAUDE_PLUGIN_OPTION_KRU_STORE_REPO"
for _kru_switch in KRU_NO_LEAD_GATE KRU_NO_GATE KRU_NO_AUDIT KRU_NO_STORE_SYNC; do
  _kru_option="CLAUDE_PLUGIN_OPTION_$_kru_switch"
  [ -z "${!_kru_switch:-}" ] && [ "${!_kru_option:-}" = "true" ] && export "$_kru_switch=1"
done
unset _kru_switch _kru_option

# the repo the session is working in. a linked worktree resolves to the MAIN
# repo (--git-common-dir), so a slice dispatched into a worktree keeps the same
# slug — and the same store — as the session that spawned it.
kru_repo_root() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  case "$common" in
    */.git) printf '%s' "${common%/.git}"; return 0 ;;
    /*) printf '%s' "$common"; return 0 ;;
  esac
  common=$(git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$common" ] && { printf '%s' "$common"; return 0; }
  printf '%s' "${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"
}

# one name identifies a project across both stores — the inbox line `skills/kru-remember/SKILL.md`
# stamps and the plan dir the planner writes carry the same slug. the dir name
# differs by machine — a cloud vm names the clone after the github repo — so
# KRU_PROJECT pins it; set in the repo's committed .claude/settings.json `env`,
# it reaches every surface.
kru_slug() { printf '%s' "${KRU_PROJECT:-$(basename "$(kru_repo_root)")}"; }

kru_is_cloud() { [ "${KRU_CLOUD:-}" = "0" ] && return 1; [ "${KRU_CLOUD:-}" = "1" ] || [ -n "${CURSOR_AGENT_SOCKET:-}" ] || [ -S /run/cursor/api.sock ]; }

kru_home() { printf '%s' "${KRU_HOME:-$HOME/.kru}"; }

kru_project() {
  [ -n "${KRU_PROJECT_STORE:-}" ] && { printf '%s' "$KRU_PROJECT_STORE"; return 0; }
  # no user level survives a cloud vm, so the plan rides in the branch instead.
  # committed, not ignored: a .kru/ nobody commits dies with the machine.
  if [ -z "${KRU_HOME:-}" ] && [ -z "${KRU_STORE_REPO:-}" ] && kru_is_cloud; then
    printf '%s/.kru' "$(kru_repo_root)"; return 0
  fi
  printf '%s/management/%s' "$(kru_home)" "$(kru_slug)"
}

# which backend holds the cross-project root. the project root is always files.
kru_backend() {
  [ -n "${KRU_STORE_URL:-}" ] && { printf 'artifact'; return 0; }
  printf 'fs'
}

# logical name -> filesystem path. the names are the seam's vocabulary
# (references/store.md); callers name the thing, never the layout.
kru_path() {
  case "${1:-}" in
    inbox)       printf '%s/inbox.md' "$(kru_home)" ;;
    refusals)    printf '%s/refusals.jsonl' "$(kru_home)" ;;
    patterns)    printf '%s/patterns' "$(kru_home)" ;;
    patterns/*)  printf '%s/patterns/%s.md' "$(kru_home)" "${1#patterns/}" ;;
    audit)       printf '%s/audit' "$(kru_home)" ;;
    audit/*)     printf '%s/audit/%s.jsonl' "$(kru_home)" "${1#audit/}" ;;
    lead-gate)   printf '%s/lead-gate' "$(kru_home)" ;;
    lead-gate/*) printf '%s/lead-gate/%s' "$(kru_home)" "${1#lead-gate/}" ;;
    todos)       printf '%s/TODOS.md' "$(kru_project)" ;;
    issues)      printf '%s/issues' "$(kru_project)" ;;
    issues/*)    printf '%s/issues/%s.md' "$(kru_project)" "${1#issues/}" ;;
    notes)       printf '%s/notes' "$(kru_project)" ;;
    notes/*)     printf '%s/notes/%s.md' "$(kru_project)" "${1#notes/}" ;;
    plan)        printf '%s/plan' "$(kru_project)" ;;
    plan/*)      printf '%s/plan/%s' "$(kru_project)" "${1#plan/}" ;;
    agent-memory) printf '%s/agent-memory' "$(kru_project)" ;;
    *) return 1 ;;
  esac
}

# the line a skill reports when the store is not where a reader assumes.
# silent when both roots sit at their local defaults and files hold them.
kru_where() {
  local h p b notes=""
  h=$(kru_home); p=$(kru_project); b=$(kru_backend)
  [ "$h" != "$HOME/.kru" ] && notes="preferences: $h"
  [ "$b" = artifact ] && notes="${notes:+$notes; }preferences: artifact store $KRU_STORE_URL"
  [ -n "${KRU_STORE_REPO:-}" ] && notes="${notes:+$notes; }synced to $KRU_STORE_REPO"
  case "$p" in
    "$h/management/"*) ;;
    *) notes="${notes:+$notes; }plan store: $p — in the repo, and it ships in the branch" ;;
  esac
  [ -n "$notes" ] && printf 'kru store — %s\n' "$notes"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    home)    kru_home; echo ;;
    project) kru_project; echo ;;
    slug)    kru_slug; echo ;;
    backend) kru_backend; echo ;;
    where)   kru_where ;;
    path)
      [ $# -ge 2 ] || { printf 'usage: kru-store.sh path <logical>\n' >&2; exit 64; }
      kru_path "$2" || { printf 'kru-store: no such logical path: %s\n' "$2" >&2; exit 64; }
      echo ;;
    *)
      printf 'usage: kru-store.sh home|project|slug|backend|where|path <logical>\n' >&2
      exit 64 ;;
  esac
fi
