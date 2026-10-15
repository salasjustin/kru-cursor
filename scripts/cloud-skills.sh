#!/usr/bin/env bash
# install kru-cursor and pstack skills where a Cursor cloud agent actually
# loads them: <repo>/.claude/skills/<name>/SKILL.md (tracked or not). cloud
# agents do not load <repo>/.cursor/skills or ~/.cursor/skills.
#
# piped from an environment install or start step, in any repo:
#   curl -fsSL https://raw.githubusercontent.com/salasjustin/kru-cursor/main/scripts/cloud-skills.sh | bash -s -- [target_repo_dir]
#
# the target is the first argument, else `git rev-parse --show-toplevel` of
# $PWD, else /workspace. a pipe has no path of its own, so this script never
# reads $0.
#
# shallow, sparse clones (latest main) land in ~/.cache/kru-cloud-skills:
#   skills/ and agents/ from salasjustin/kru-cursor
#   pstack/ from https://github.com/cursor/plugins
# each skill directory is copied flat to .claude/skills/<name>/, each agent
# file to .claude/agents/<name>.md. a name the repo already tracks
# (`git ls-files`) is left alone, and so is an untracked path this script did
# not install (the manifest in the cache is the ownership list). kru-cursor
# wins when pstack has the same name. a name that is not one safe path
# segment (`^[A-Za-z0-9._-]+$`, agents ending in `.md`) is skipped.
# symlinks at `.claude`, `.claude/skills`, `.claude/agents`, or a destination
# are not followed. copied paths are appended to .git/info/exclude — not
# .gitignore — so they stay out of git status and cannot be committed by accident.
#
# paths this script owns are listed in a manifest file under the cache, one
# file per target. a later run deletes a path it owns that the sources no
# longer ship. a network or git failure warns and exits 0, so the environment
# step still succeeds.
#
# tests point the clones at local repos with:
#   KRU_CLOUD_SKILLS_CACHE KRU_CLOUD_SKILLS_KRU_URL
#   KRU_CLOUD_SKILLS_PLUGINS_URL KRU_CLOUD_SKILLS_FALLBACK
# a cloud image may export SHELLOPTS=errexit:pipefail:nounset. the script is
# written for that, and LC_ALL=C keeps the name check on ASCII ranges.
set -euo pipefail
export LC_ALL=C

warn() { printf 'cloud-skills: %s\n' "$*" >&2; }

# bounded so a blackhole host cannot hang an environment install step.
# http.* is a no-op for a local path, which is what the tests use.
gitc() {
  git \
    -c http.connectTimeout=15 \
    -c http.lowSpeedLimit=1000 \
    -c http.lowSpeedTime=30 \
    "$@"
}

# prints the absolute target, or returns 1 after a warning. an exit inside
# $() would only leave the subshell, so callers turn a failure into exit 0.
resolve_target() {
  local arg=${1:-} top fallback
  if [ -n "$arg" ]; then
    [ -d "$arg" ] || { warn "target is not a directory: $arg"; return 1; }
    (cd "$arg" && pwd -P) || return 1
    return 0
  fi
  if top=$(git rev-parse --show-toplevel 2>/dev/null); then
    (cd "$top" && pwd -P) || return 1
    return 0
  fi
  fallback=${KRU_CLOUD_SKILLS_FALLBACK:-/workspace}
  if [ -d "$fallback" ]; then
    (cd "$fallback" && pwd -P) || return 1
    return 0
  fi
  warn "no target: pass a repo directory, run inside a git checkout, or use $fallback"
  return 1
}

cache_ready() {
  local dest=$1 p
  shift
  gitc -C "$dest" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  for p in "$@"; do
    [ -e "$dest/$p" ] || return 1
  done
}

# clone or fast-forward a sparse checkout. returns 0 when dest has the
# requested paths (a failed fetch of a checkout we already have counts).
refresh_sparse() {
  local url=$1 dest=$2
  shift 2
  local -a paths=("$@")
  local err="" sha=""
  mkdir -p "$(dirname "$dest")" || { warn "cannot create $(dirname "$dest")"; return 1; }
  if [ -d "$dest/.git" ] || [ -f "$dest/.git" ]; then
    # remember the fetched tip before sparse-checkout: a partial clone may
    # fetch blobs and replace FETCH_HEAD.
    if gitc -C "$dest" remote set-url origin "$url" \
      && err=$(gitc -C "$dest" fetch --quiet --depth 1 --no-tags origin main 2>&1) \
      && sha=$(gitc -C "$dest" rev-parse FETCH_HEAD 2>/dev/null); then
      gitc -C "$dest" sparse-checkout set "${paths[@]}" >/dev/null 2>&1 || {
        warn "sparse-checkout failed for $url"
        return 1
      }
      gitc -C "$dest" reset --quiet --hard "$sha" || {
        warn "git reset failed for $url"
        return 1
      }
      return 0
    fi
    if cache_ready "$dest" "${paths[@]}"; then
      warn "fetch failed for $url; using the cached checkout"
      return 0
    fi
    warn "fetch failed for $url${err:+: ${err##*$'\n'}}"
    return 1
  fi
  rm -rf "$dest"
  local -a clone_args=(clone --quiet --depth 1 --sparse --branch main --no-tags)
  case "$url" in
    https://*|http://*) clone_args+=(--filter=blob:none) ;;
  esac
  if ! err=$(gitc "${clone_args[@]}" "$url" "$dest" 2>&1); then
    rm -rf "$dest"
    if ! err=$(gitc clone --quiet --depth 1 --sparse --branch main --no-tags "$url" "$dest" 2>&1); then
      warn "git clone failed for $url: ${err##*$'\n'}"
      rm -rf "$dest"
      return 1
    fi
  fi
  if ! err=$(gitc -C "$dest" sparse-checkout set "${paths[@]}" 2>&1); then
    warn "sparse-checkout failed for $url: ${err##*$'\n'}"
    return 1
  fi
  gitc -C "$dest" reset --quiet --hard HEAD || { warn "git reset failed for $url"; return 1; }
}

# one path segment. "." and ".." match the class and are still rejected:
# they are not names we can copy. locale is C, so the range is ASCII.
safe_skill_name() {
  local name=$1
  [ "$name" != "." ] && [ "$name" != ".." ] && [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]
}

# agents are the same segment plus the .md suffix.
safe_agent_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+\.md$ ]]
}

# NUL-delimited skill names. a symlink is not a skill directory; find -P
# does not descend into one. an unsafe name is skipped with a warning.
collect_skills() {
  local root=$1 dir name
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  while IFS= read -r -d '' dir; do
    name=${dir##*/}
    if [ -L "$dir" ]; then
      warn "skipping symlinked skill: $(printf '%q' "$name")"
      continue
    fi
    [ -d "$dir" ] && [ -f "$dir/SKILL.md" ] || continue
    if ! safe_skill_name "$name"; then
      warn "skipping skill with an unsafe name: $(printf '%q' "$name")"
      continue
    fi
    printf '%s\0' "$name"
  done < <(find -P "$root" -mindepth 1 -maxdepth 1 -print0)
}

# NUL-delimited agent file names. notes and other non-md files are not agents.
collect_agents() {
  local root=$1 f name
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  while IFS= read -r -d '' f; do
    name=${f##*/}
    if [ -L "$f" ]; then
      warn "skipping symlinked agent: $(printf '%q' "$name")"
      continue
    fi
    [ -f "$f" ] || continue
    case "$name" in
      *.md) ;;
      *) continue ;;
    esac
    if ! safe_agent_name "$name"; then
      warn "skipping agent with an unsafe name: $(printf '%q' "$name")"
      continue
    fi
    printf '%s\0' "$name"
  done < <(find -P "$root" -mindepth 1 -maxdepth 1 -print0)
}

is_tracked() {
  local target=$1 rel=$2 out
  # a trailing slash is an exclude pattern, not a path git ls-files stores.
  # a git failure is treated as tracked so we do not delete or overwrite.
  rel=${rel%/}
  if ! out=$(gitc -C "$target" ls-files -- "$rel"); then
    return 0
  fi
  [ -n "$out" ]
}

# a manifest entry we are willing to delete: one safe skill or agent name,
# no extra components, so a poisoned line cannot climb out of .claude.
valid_owned_rel() {
  local rel=${1%/} rest
  case "$rel" in
    .claude/skills/*)
      rest=${rel#.claude/skills/}
      case "$rest" in */*) return 1 ;; esac
      safe_skill_name "$rest"
      ;;
    .claude/agents/*)
      rest=${rel#.claude/agents/}
      case "$rest" in */*) return 1 ;; esac
      safe_agent_name "$rest"
      ;;
    *) return 1 ;;
  esac
}

# true when a parent of rel is a symlink. the final component is not checked,
# so a skill path that itself is a symlink can still be unlinked.
parent_has_symlink() {
  local rel=${1%/}
  local parent=${rel%/*} acc="" part rest
  [ "$parent" != "$rel" ] || return 1
  rest=$parent
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    if [ "$part" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
    [ -n "$part" ] || continue
    [ "$part" = "." ] || [ "$part" = ".." ] && return 0
    acc="${acc:+$acc/}$part"
    [ -L "$target/$acc" ] && return 0
  done
  return 1
}

# .claude, .claude/skills, and .claude/agents must be real directories when
# they exist. a symlink there would send every copy and every delete outside
# the repo. mkdir is not used here, so a refusal changes nothing.
refuse_linked_claude() {
  local rel
  for rel in .claude .claude/skills .claude/agents; do
    if [ -L "$target/$rel" ]; then
      warn "refusing to follow symlink: $rel"
      return 1
    fi
    if [ -e "$target/$rel" ] && [ ! -d "$target/$rel" ]; then
      warn "refusing to use $rel because it is not a directory"
      return 1
    fi
  done
}

# create each component with mkdir, never mkdir -p, which follows a symlink.
ensure_dir() {
  local rel=$1 acc="" part rest=$1
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    if [ "$part" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
    [ -n "$part" ] || continue
    acc="${acc:+$acc/}$part"
    if [ -L "$target/$acc" ]; then
      warn "refusing to follow symlink: $acc"
      return 1
    fi
    if [ -e "$target/$acc" ] && [ ! -d "$target/$acc" ]; then
      warn "refusing to replace non-directory: $acc"
      return 1
    fi
    if [ ! -d "$target/$acc" ]; then
      mkdir -- "$target/$acc" || return 1
    fi
  done
}

# literal path only. a symlink is unlinked; rm is not given a trailing slash
# and realpath is not used, so the symlink's target stays.
remove_literal() {
  local rel=$1 path="$target/${1%/}"
  if ! valid_owned_rel "$rel"; then
    warn "refusing to remove unexpected manifest path: $rel"
    return 0
  fi
  if parent_has_symlink "$rel"; then
    warn "refusing to remove through symlink: ${rel%/}"
    return 0
  fi
  if [ -L "$path" ]; then
    rm -- "$path" || warn "could not unlink ${rel%/}"
    return 0
  fi
  if [ -d "$path" ]; then
    rm -rf -- "$path"
    return 0
  fi
  if [ -f "$path" ]; then
    rm -f -- "$path"
    return 0
  fi
}

# replace a path we already own, or create one that is not there. cp -a does
# not follow symlinks in the source. the destination is removed first, and a
# symlink is unlinked rather than written through.
replace_path() {
  local src=$1 dest=$2
  case "$dest" in
    "$target"/.claude/skills/*|"$target"/.claude/agents/*) ;;
    *) warn "refusing path outside the repo: $dest"; return 1 ;;
  esac
  if [ -L "$src" ] || [ ! -e "$src" ]; then
    warn "refusing to copy symlink source: $src"
    return 1
  fi
  if [ -L "$dest" ]; then
    rm -- "$dest" || return 1
  elif [ -d "$dest" ]; then
    rm -rf -- "$dest" || return 1
  elif [ -e "$dest" ]; then
    rm -f -- "$dest" || return 1
  fi
  cp -a -- "$src" "$dest"
}

# rewrite only the block this script owns. every other line stays, so a
# checkout's own excludes are not touched. the block is sorted, so a second
# run writes the same bytes.
write_exclude() {
  local file=$1
  shift
  local tmp body
  mkdir -p -- "$(dirname "$file")" || return 1
  tmp=$(mktemp)
  body=$(mktemp)
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

manifest_path() {
  local cache=$1 target=$2 id
  if command -v sha256sum >/dev/null 2>&1; then
    id=$(printf '%s' "$target" | sha256sum | awk '{print $1}')
  else
    id=$(printf '%s' "$target" | shasum -a 256 | awk '{print $1}')
  fi
  printf '%s\n' "$cache/manifests/$id"
}

read_manifest() {
  local file=$1 target=$2
  [ -f "$file" ] || return 0
  # a file whose first line is a different checkout is not this target's list
  [ "$(head -n 1 "$file")" = "$target" ] || { warn "manifest is for a different target; not pruning"; return 0; }
  awk 'NR > 1 && $0 !~ /^#/ && $0 != "" { print }' "$file"
}

write_manifest() {
  local file=$1 target=$2
  shift 2
  local tmp
  mkdir -p -- "$(dirname "$file")" || return 1
  tmp=$(mktemp)
  {
    printf '%s\n' "$target"
    if [ "$#" -gt 0 ]; then printf '%s\n' "$@" | sort -u; fi
  } > "$tmp"
  mv -- "$tmp" "$file"
}

main() {
  # a parent environment install step may export these; they would make every
  # git call in here operate on the wrong repository.
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
  export GIT_TERMINAL_PROMPT=0

  local target
  target=$(resolve_target "${1:-}") || exit 0
  gitc -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    warn "not a git checkout: $target"
    exit 0
  }

  local cache kru_url plugins_url
  cache=${KRU_CLOUD_SKILLS_CACHE:-${HOME:-/tmp}/.cache/kru-cloud-skills}
  kru_url=${KRU_CLOUD_SKILLS_KRU_URL:-https://github.com/salasjustin/kru-cursor.git}
  plugins_url=${KRU_CLOUD_SKILLS_PLUGINS_URL:-https://github.com/cursor/plugins.git}
  mkdir -p -- "$cache" || { warn "cannot create cache $cache"; exit 0; }

  refresh_sparse "$kru_url" "$cache/kru-cursor" skills agents || {
    warn "kru-cursor unavailable; leaving $target unchanged"
    exit 0
  }
  refresh_sparse "$plugins_url" "$cache/plugins" pstack || {
    warn "pstack unavailable; leaving $target unchanged"
    exit 0
  }

  local kru_skills="$cache/kru-cursor/skills"
  local kru_agents="$cache/kru-cursor/agents"
  local ps_skills="$cache/plugins/pstack/skills"
  local ps_agents="$cache/plugins/pstack/agents"
  if [ ! -d "$kru_skills" ] || [ ! -d "$ps_skills" ]; then
    warn "clone is missing skills/; leaving $target unchanged"
    exit 0
  fi
  # a symlink anywhere in this chain would make later mkdir and rm operate
  # outside the checkout. refuse before the repo is modified.
  if ! refuse_linked_claude; then
    exit 0
  fi

  # pstack first, kru-cursor second, so a shared name keeps kru's copy.
  declare -A skill_src=() agent_src=() owned=()
  local name
  while IFS= read -r -d '' name; do
    [ -n "$name" ] || continue
    skill_src["$name"]="$ps_skills/$name"
  done < <(collect_skills "$ps_skills")
  while IFS= read -r -d '' name; do
    [ -n "$name" ] || continue
    skill_src["$name"]="$kru_skills/$name"
  done < <(collect_skills "$kru_skills")
  while IFS= read -r -d '' name; do
    [ -n "$name" ] || continue
    agent_src["$name"]="$ps_agents/$name"
  done < <(collect_agents "$ps_agents")
  while IFS= read -r -d '' name; do
    [ -n "$name" ] || continue
    agent_src["$name"]="$kru_agents/$name"
  done < <(collect_agents "$kru_agents")

  local -a desired=() skipped=()
  local rel src dest
  for name in "${!skill_src[@]}"; do
    rel=".claude/skills/$name/"
    if is_tracked "$target" "$rel"; then
      skipped+=(".claude/skills/$name")
      continue
    fi
    desired+=("$rel")
  done
  for name in "${!agent_src[@]}"; do
    rel=".claude/agents/$name"
    if is_tracked "$target" "$rel"; then
      skipped+=("$rel")
      continue
    fi
    desired+=("$rel")
  done

  local manifest
  manifest=$(manifest_path "$cache" "$target")
  local -a old=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    old+=("$line")
    owned["$line"]=1
  done < <(read_manifest "$manifest" "$target")

  if ! ensure_dir .claude/skills || ! ensure_dir .claude/agents; then
    exit 0
  fi

  # drop owned paths the sources no longer ship. the path string is used as
  # written in the manifest: no realpath, so a symlink is not resolved.
  local stale keep
  for stale in "${old[@]+"${old[@]}"}"; do
    keep=0
    for rel in "${desired[@]+"${desired[@]}"}"; do
      [ "$rel" = "$stale" ] && keep=1 && break
    done
    [ "$keep" -eq 1 ] && continue
    if is_tracked "$target" "$stale"; then
      continue
    fi
    remove_literal "$stale"
  done

  # a pre-existing untracked path is not ours unless the manifest lists it.
  # replacing it would delete someone else's skill. a symlink we do not own
  # is left in place; one we own is unlinked inside replace_path.
  local -a install_rels=()
  for rel in "${desired[@]+"${desired[@]}"}"; do
    if parent_has_symlink "$rel"; then
      warn "refusing to follow symlink: ${rel%/}"
      continue
    fi
    dest="$target/${rel%/}"
    if [ -L "$dest" ] || [ -e "$dest" ]; then
      if [ -z "${owned[$rel]+x}" ]; then
        warn "leaving pre-existing untracked path in place: ${rel%/}"
        continue
      fi
    fi
    install_rels+=("$rel")
  done

  local exclude n_skills=0 n_agents=0
  exclude=$(gitc -C "$target" rev-parse --absolute-git-dir)/info/exclude
  local -a installed=()
  for rel in "${install_rels[@]+"${install_rels[@]}"}"; do
    case "$rel" in
      .claude/skills/*/)
        name=${rel#".claude/skills/"}
        name=${name%/}
        src=${skill_src[$name]}
        ;;
      .claude/agents/*)
        name=${rel#".claude/agents/"}
        src=${agent_src[$name]}
        ;;
      *) continue ;;
    esac
    if ! replace_path "$src" "$target/${rel%/}"; then
      warn "copy failed: ${rel%/}"
      continue
    fi
    case "$rel" in
      .claude/skills/*/) n_skills=$((n_skills + 1)) ;;
      .claude/agents/*) n_agents=$((n_agents + 1)) ;;
    esac
    installed+=("$rel")
  done

  if [ "${#installed[@]}" -gt 0 ]; then
    write_exclude "$exclude" "${installed[@]}" || warn "could not write $exclude"
    write_manifest "$manifest" "$target" "${installed[@]}" || warn "could not write the manifest"
  else
    write_exclude "$exclude" || warn "could not write $exclude"
    write_manifest "$manifest" "$target" || warn "could not write the manifest"
  fi

  printf 'cloud-skills: %d skills, %d agents -> %s (%d tracked left untouched)\n' \
    "$n_skills" "$n_agents" "$target" "${#skipped[@]}"
  if [ "${#skipped[@]}" -gt 0 ]; then
    printf 'cloud-skills: tracked, not replaced:'
    for rel in "${skipped[@]}"; do printf ' %s' "$rel"; done
    printf '\n'
  fi
}

main "$@"
