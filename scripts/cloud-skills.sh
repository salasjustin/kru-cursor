#!/usr/bin/env bash
# Piped: curl -fsSL .../scripts/cloud-skills.sh | bash -s -- [target_repo_dir]
# Target: argument, else git toplevel of $PWD, else /workspace. Never reads $0.
# Shallow-clones kru-cursor skills/ + agents/ and pstack into ~/.cache/kru-cloud-skills.
# Copies each skill flat to .claude/skills/<name>/ and each agent to
# .claude/agents/<name>.md and to ~/.cursor/agents/<name>.md (KRU_CURSOR_AGENTS_DIR
# overrides the home dir). When pstack installs, copies rules/pstack-models.mdc to
# ~/.cursor/rules/pstack-models.mdc (KRU_CURSOR_RULES_DIR overrides the rules dir).
# Overwrites an untracked copy, skips a tracked name
# in the repo, and lets kru-cursor win a shared name. The home copy replaces a
# file whose frontmatter name starts with kru-, and a file that is not there
# yet. An existing home agent whose name: is not kru-* is left untouched.
# One line per repo copy in info/exclude
# (git rev-parse --git-path info/exclude), between begin and end markers,
# rewritten every run. A repo using this must not negate .claude/skills or
# .claude/agents in .gitignore. The kru clone or fetch failure warns and exits
# 1. A plugins clone or fetch failure warns and still installs the kru seats.
# After the copy, list registered subagent name: values. Exit 1 when none start
# with kru- — a missing seat, including when plugins failed and nothing landed.
# KRU_CLOUD_SKILLS_CACHE KRU_CLOUD_SKILLS_KRU_URL KRU_CLOUD_SKILLS_PLUGINS_URL KRU_CLOUD_SKILLS_FALLBACK
set -euo pipefail
export LC_ALL=C

warn() { printf 'cloud-skills: %s\n' "$*" >&2; }

gitc() {
  git -c http.connectTimeout=15 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 "$@"
}

resolve_target() {
  local top fb
  if [ -n "${1:-}" ]; then
    [ -d "$1" ] || { warn "target is not a directory: $1"; return 1; }
    (cd -- "$1" && pwd)
    return
  fi
  if top=$(git rev-parse --show-toplevel 2>/dev/null); then
    printf '%s\n' "$top"
    return
  fi
  fb=${KRU_CLOUD_SKILLS_FALLBACK:-/workspace}
  [ -d "$fb" ] || { warn "no target: pass a repo directory, run inside a git checkout, or use $fb"; return 1; }
  (cd -- "$fb" && pwd)
}

# clone or update one sparse checkout. a failed fetch of a checkout that
# already has the paths keeps that checkout. any other failure returns 1.
refresh() {
  local url=$1 dest=$2
  shift 2
  local p
  mkdir -p -- "$(dirname -- "$dest")"
  if [ -d "$dest/.git" ]; then
    if gitc -C "$dest" remote set-url origin "$url" \
      && gitc -C "$dest" fetch --quiet --depth 1 --no-tags origin main \
      && gitc -C "$dest" sparse-checkout set "$@" \
      && gitc -C "$dest" reset --quiet --hard FETCH_HEAD; then
      return 0
    fi
    for p in "$@"; do
      [ -e "$dest/$p" ] || { warn "fetch failed for $url"; return 1; }
    done
    warn "fetch failed for $url; using the cached checkout"
    return 0
  fi
  rm -rf -- "$dest"
  gitc clone --quiet --depth 1 --sparse --branch main --no-tags "$url" "$dest" \
    || { warn "git clone failed for $url"; rm -rf -- "$dest"; return 1; }
  gitc -C "$dest" sparse-checkout set "$@" || { warn "sparse-checkout failed for $url"; return 1; }
}

safe_name() { [ "$1" != "." ] && [ "$1" != ".." ] && [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }

# pstack is collected first. kru-cursor overwrites a shared name.
collect() {
  local root=$1 kind=$2 d name
  [ -d "$root" ] || return 0
  if [ "$kind" = skill ]; then
    while IFS= read -r -d '' d; do
      name=${d##*/}
      [ -f "$d/SKILL.md" ] || continue
      safe_name "$name" || { warn "skipping skill with an unsafe name: $name"; continue; }
      skill_src["$name"]=$d
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0)
  else
    while IFS= read -r -d '' d; do
      name=${d##*/}
      [[ "$name" == *.md ]] || continue
      safe_name "${name%.md}" || { warn "skipping agent with an unsafe name: $name"; continue; }
      agent_src["$name"]=$d
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type f -print0)
  fi
}

place() {
  local kind=$1
  local -n map=$2
  local name rel dest
  for name in "${!map[@]}"; do
    if [ "$kind" = skill ]; then rel=".claude/skills/$name"; else rel=".claude/agents/$name"; fi
    if gitc -C "$target" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
      skipped+=("$rel")
      continue
    fi
    dest="$target/$rel"
    rm -rf -- "$dest"
    mkdir -p -- "$(dirname -- "$dest")"
    cp -a -- "${map[$name]}" "$dest"
    if [ "$kind" = skill ]; then pats+=("$rel/"); n_skills=$((n_skills + 1)); else pats+=("$rel"); n_agents=$((n_agents + 1)); fi
  done
}

# replace only this script's block. every other exclude line stays.
write_exclude() {
  local file=$1
  shift
  local info body tmp
  info=$(dirname -- "$file")
  mkdir -p -- "$info"
  body=$(mktemp)
  tmp=$(mktemp)
  if [ -f "$file" ]; then
    awk '
      $0 == "# kru-cloud-skills begin" { skip = 1; next }
      $0 == "# kru-cloud-skills end" { skip = 0; next }
      !skip { print }
    ' "$file" > "$body"
  fi
  {
    if [ -s "$body" ]; then cat "$body"; fi
    printf '%s\n' '# kru-cloud-skills begin'
    if [ "$#" -gt 0 ]; then printf '%s\n' "$@" | sort -u; fi
    printf '%s\n' '# kru-cloud-skills end'
  } > "$tmp"
  mv -- "$tmp" "$file"
  rm -f -- "$body"
}

main() {
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
  export GIT_TERMINAL_PROMPT=0
  local target cache kru_url plugins_url exclude
  local -a skipped=() pats=()
  local n_skills=0 n_agents=0
  declare -A skill_src=() agent_src=()

  target=$(resolve_target "${1:-}") || exit 0
  gitc -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { warn "not a git checkout: $target"; exit 0; }

  cache=${KRU_CLOUD_SKILLS_CACHE:-${HOME:-/tmp}/.cache/kru-cloud-skills}
  kru_url=${KRU_CLOUD_SKILLS_KRU_URL:-https://github.com/salasjustin/kru-cursor.git}
  plugins_url=${KRU_CLOUD_SKILLS_PLUGINS_URL:-https://github.com/cursor/plugins.git}
  refresh "$kru_url" "$cache/kru-cursor" skills agents rules || exit 1
  # pstack is optional. a plugins failure must not skip the kru copy, and the
  # run still exits 1 below when no kru-* agent is on disk.
  local pstack_ok=1
  if ! refresh "$plugins_url" "$cache/plugins" pstack; then
    pstack_ok=0
    warn "plugins clone or fetch failed; installing kru seats without pstack"
  fi

  collect "$cache/plugins/pstack/skills" skill
  collect "$cache/kru-cursor/skills" skill
  collect "$cache/plugins/pstack/agents" agent
  collect "$cache/kru-cursor/agents" agent
  place skill skill_src
  place agent agent_src

  exclude=$(gitc -C "$target" rev-parse --path-format=absolute --git-path info/exclude) \
    || { warn "cannot resolve info/exclude"; exit 0; }
  if [ "${#pats[@]}" -gt 0 ]; then write_exclude "$exclude" "${pats[@]}"; else write_exclude "$exclude"; fi

  printf 'cloud-skills: %d skills, %d agents -> %s (%d tracked left untouched)\n' \
    "$n_skills" "$n_agents" "$target" "${#skipped[@]}"

  # Cursor loads custom subagents from these dirs, not from a plugin's agents/
  # (cursor.com/docs/subagents). The home copy is what a cloud agent sees at
  # startup when this script ran in the environment install.
  home_agents=${KRU_CURSOR_AGENTS_DIR:-${HOME:-/tmp}/.cursor/agents}
  mkdir -p -- "$home_agents"
  local name dest existing
  for name in "${!agent_src[@]}"; do
    dest="$home_agents/$name"
    # only replace a file this script owns. a home agent whose name: is not
    # kru-* belongs to the user and stays, even when the source has the same filename.
    if [ -f "$dest" ]; then
      existing=$(front_name "$dest")
      if [[ "$existing" != kru-* ]]; then
        warn "leaving home agent $name (name is not kru-*)"
        continue
      fi
    fi
    rm -rf -- "$dest"
    cp -a -- "${agent_src[$name]}" "$dest"
  done
  if [ "$pstack_ok" = 1 ]; then
    install_pstack_models_rule "$cache/kru-cursor/rules/pstack-models.mdc"
  fi
  if ! list_registered "$home_agents" "$target/.claude/agents"; then
    exit 1
  fi
}

# print sorted unique frontmatter name: values. exit 1 when none start with kru-.
front_name() {
  local line
  line=$(awk 'BEGIN{fm=0} /^---$/{fm++; if(fm==2) exit; next} fm==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$1")
  line=${line#\"}; line=${line%\"}; line=${line#\'}; line=${line%\'}
  printf '%s' "$line"
}
# when pstack landed, install the fork's pstack model rule for cloud agents.
# an existing home file that already has a # budget: line is left alone so
# local edits survive re-runs; a file without that marker is replaced.
install_pstack_models_rule() {
  local src=$1
  local dest=${KRU_CURSOR_RULES_DIR:-${HOME:-/tmp}/.cursor/rules}/pstack-models.mdc
  [ -f "$src" ] || return 0
  mkdir -p -- "$(dirname -- "$dest")"
  if [ -f "$dest" ] && grep -q '^# budget:' "$dest"; then
    warn "leaving home rule pstack-models.mdc (# budget line present)"
    return 0
  fi
  cp -a -- "$src" "$dest"
}

list_registered() {
  local d f name
  local -a found=() kru=()
  for d in "$@"; do
    [ -d "$d" ] || continue
    for f in "$d"/*.md; do
      [ -f "$f" ] || continue
      name=$(front_name "$f")
      [ -n "$name" ] || continue
      found+=("$name")
      [[ "$name" == kru-* ]] && kru+=("$name")
    done
  done
  if [ "${#kru[@]}" -eq 0 ]; then
    warn "no kru seat registered in $*"
    if [ "${#found[@]}" -eq 0 ]; then
      printf 'registered subagents:\n'
    else
      printf 'registered subagents: %s\n' "$(printf '%s\n' "${found[@]}" | sort -u | paste -sd ' ' -)"
    fi
    return 1
  fi
  printf 'registered subagents: %s\n' "$(printf '%s\n' "${kru[@]}" | sort -u | paste -sd ' ' -)"
}

main "$@"
