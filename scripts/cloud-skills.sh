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
# reads $0. a path that contains a newline is refused: command substitution
# would otherwise strip a trailing newline and the script would operate on a
# different directory.
#
# shallow, sparse clones (latest main) land in ~/.cache/kru-cloud-skills:
#   skills/ and agents/ from salasjustin/kru-cursor
#   pstack/ from https://github.com/cursor/plugins
# each skill directory is copied flat to .claude/skills/<name>/, each agent
# file to .claude/agents/<name>.md. a name the repo already tracks
# (`git ls-files`) is left alone, and so is an untracked path this script did
# not install. kru-cursor wins when pstack has the same name. a name that is
# not one safe path segment (`^[A-Za-z0-9._-]+$`, agents ending in `.md`) is
# skipped. symlinks at `.claude`, `.claude/skills`, `.claude/agents`, or a
# destination are not followed. copied paths are appended to .git/info/exclude
# — not .gitignore — so they stay out of git status and cannot be committed
# by accident.
#
# files this script copied are listed, one path per line, in
# $GIT_DIR/kru-cloud-skills.manifest (the target checkout's own git dir, not
# a path-hashed file in the cache). a later run rewrites only those files:
# a source file is updated, a file the source no longer has is removed, and
# an extra file the user added is left in place. a fresh repository created
# at the same path has a new git dir, so it starts with no ownership. an
# owned directory that is a mount point (its device differs from its parent)
# is left alone. recursive removes pass --one-file-system.
#
# a network or git failure warns and exits 0, so the environment step still
# succeeds.
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

# physical path of a directory. pwd's own trailing newline is removed; a
# newline that is part of the path is kept, because the sentinel is not a
# newline and command substitution only strips trailing newlines.
phys_dir() {
  local d=$1 out
  out=$(cd -- "$d" && pwd -P && printf x) || return 1
  out=${out%x}
  out=${out%$'\n'}
  printf '%s' "$out"
}

# prints one absolute path and a newline, or returns 1. a path containing a
# newline is refused so the caller's command substitution cannot turn it into
# a different directory by stripping a trailing newline. the sentinel has to
# sit inside this command substitution: phys_dir keeps a trailing newline, and
# $(phys_dir) would strip it again.
emit_dir() {
  local d=$1 out
  out=$(phys_dir "$d" && printf x) || return 1
  out=${out%x}
  case "$out" in
    *$'\n'*) warn "refusing a target path that contains a newline"; return 1 ;;
  esac
  printf '%s\n' "$out"
}

# prints the absolute target, or returns 1 after a warning. an exit inside
# $() would only leave the subshell, so callers turn a failure into exit 0.
resolve_target() {
  local arg=${1:-} top fallback
  if [ -n "$arg" ]; then
    [ -d "$arg" ] || { warn "target is not a directory: $arg"; return 1; }
    emit_dir "$arg"
    return
  fi
  if top=$(git rev-parse --show-toplevel 2>/dev/null && printf x); then
    top=${top%x}
    top=${top%$'\n'}
    case "$top" in
      *$'\n'*) warn "refusing a target path that contains a newline"; return 1 ;;
    esac
    emit_dir "$top"
    return
  fi
  fallback=${KRU_CLOUD_SKILLS_FALLBACK:-/workspace}
  if [ -d "$fallback" ]; then
    emit_dir "$fallback"
    return
  fi
  warn "no target: pass a repo directory, run inside a git checkout, or use $fallback"
  return 1
}

# true when path is a mount point: its device differs from its parent's.
# a symlink is not treated as one (stat would follow it).
is_mount_point() {
  local path=$1 parent dev pdev
  [ -L "$path" ] && return 1
  [ -e "$path" ] || return 1
  parent=$(dirname -- "$path")
  dev=$(stat -c '%d' -- "$path") || return 1
  pdev=$(stat -c '%d' -- "$parent") || return 1
  [ "$dev" != "$pdev" ]
}

# the cache repo is the one we are allowed to fetch and reset. anything else
# — a symlink, a gitfile, a worktree, a core.worktree — is not, and the
# caller deletes the real cache directory and reclones instead of resetting.
cache_repo_sane() {
  local dest=$1 top dest_phys top_phys gitdir gitdir_phys dotgit_phys
  [ -L "$dest" ] && return 1
  [ -d "$dest" ] || return 1
  # a gitfile or a symlinked .git names some other repository.
  [ -d "$dest/.git" ] && [ ! -L "$dest/.git" ] || return 1
  if gitc -C "$dest" config --local --get core.worktree >/dev/null 2>&1; then
    return 1
  fi
  gitc -C "$dest" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  dest_phys=$(phys_dir "$dest" && printf x) || return 1
  dest_phys=${dest_phys%x}
  top=$(gitc -C "$dest" rev-parse --show-toplevel && printf x) || return 1
  top=${top%x}
  top=${top%$'\n'}
  case "$dest_phys" in *$'\n'*) return 1 ;; esac
  case "$top" in *$'\n'*) return 1 ;; esac
  top_phys=$(phys_dir "$top" && printf x) || return 1
  top_phys=${top_phys%x}
  [ "$top_phys" = "$dest_phys" ] || return 1
  gitdir=$(gitc -C "$dest" rev-parse --absolute-git-dir && printf x) || return 1
  gitdir=${gitdir%x}
  gitdir=${gitdir%$'\n'}
  case "$gitdir" in *$'\n'*) return 1 ;; esac
  gitdir_phys=$(phys_dir "$gitdir" && printf x) || return 1
  gitdir_phys=${gitdir_phys%x}
  dotgit_phys=$(phys_dir "$dest/.git" && printf x) || return 1
  dotgit_phys=${dotgit_phys%x}
  [ "$gitdir_phys" = "$dotgit_phys" ]
}

# cache itself must be a real directory. a symlink is unlinked and not
# followed: mkdir -p would create the clone inside the symlink's target.
open_cache() {
  local cache=$1 parent
  parent=$(dirname -- "$cache")
  if [ ! -d "$parent" ] || [ -L "$parent" ]; then
    # a missing parent is created. a symlinked parent is left as it is when
    # it is already a directory (-d follows); only a broken or non-dir parent
    # is replaced, and only when it is not a symlink we would have to follow.
    if [ -L "$parent" ]; then
      :
    elif [ ! -d "$parent" ]; then
      mkdir -p -- "$parent" || return 1
    fi
  fi
  if [ -L "$cache" ]; then
    warn "cache path is a symlink; unlinking it without following"
    rm -- "$cache" || return 1
  elif [ -e "$cache" ] && [ ! -d "$cache" ]; then
    warn "cache path is not a directory: $cache"
    return 1
  fi
  if [ ! -d "$cache" ]; then
    mkdir -- "$cache" || return 1
  fi
}

# delete a real cache directory. a symlink is never passed to rm -rf.
wipe_cache() {
  local cache=$1
  if [ -L "$cache" ] || [ ! -d "$cache" ]; then
    warn "refusing to delete cache through a symlink: $cache"
    return 1
  fi
  if is_mount_point "$cache"; then
    warn "refusing to delete a cache directory that is a mount point: $cache"
    return 1
  fi
  rm -rf --one-file-system -- "$cache" || return 1
  mkdir -- "$cache" || return 1
}

cache_ready() {
  local dest=$1 p
  shift
  gitc -C "$dest" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  for p in "$@"; do
    [ -e "$dest/$p" ] || return 1
  done
}

# clone into a path that does not yet exist. a leftover real directory is
# removed with --one-file-system; a symlink is not.
clone_sparse() {
  local url=$1 dest=$2
  shift 2
  local -a paths=("$@")
  local err=""
  if [ -L "$dest" ]; then
    warn "refusing to remove symlink cache repo: $dest"
    return 1
  fi
  if [ -e "$dest" ]; then
    if is_mount_point "$dest"; then
      warn "refusing to remove mount point: $dest"
      return 1
    fi
    rm -rf --one-file-system -- "$dest" || return 1
  fi
  local -a clone_args=(clone --quiet --depth 1 --sparse --branch main --no-tags)
  case "$url" in
    https://*|http://*) clone_args+=(--filter=blob:none) ;;
  esac
  if ! err=$(gitc "${clone_args[@]}" "$url" "$dest" 2>&1); then
    if [ ! -L "$dest" ]; then rm -rf --one-file-system -- "$dest" 2>/dev/null || true; fi
    if ! err=$(gitc clone --quiet --depth 1 --sparse --branch main --no-tags "$url" "$dest" 2>&1); then
      warn "git clone failed for $url: ${err##*$'\n'}"
      if [ ! -L "$dest" ]; then rm -rf --one-file-system -- "$dest" 2>/dev/null || true; fi
      return 1
    fi
  fi
  if ! err=$(gitc -C "$dest" sparse-checkout set "${paths[@]}" 2>&1); then
    warn "sparse-checkout failed for $url: ${err##*$'\n'}"
    return 1
  fi
  if ! cache_repo_sane "$dest"; then
    warn "refusing to reset a clone that failed checks: $dest"
    return 1
  fi
  gitc -C "$dest" reset --quiet --hard HEAD || { warn "git reset failed for $url"; return 1; }
}

# if either cached repo fails the checks, delete the real cache directory
# once, before any fetch or reset. a repo that fails is never reset.
prepare_cache() {
  local cache=$1 dest bad=0
  open_cache "$cache" || return 1
  for dest in "$cache/kru-cursor" "$cache/plugins"; do
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if ! cache_repo_sane "$dest"; then
        bad=1
      fi
    fi
  done
  if [ "$bad" -eq 1 ]; then
    warn "cache repo failed checks; deleting the cache directory and recloning"
    wipe_cache "$cache" || return 1
  fi
}

# clone or fast-forward a sparse checkout. returns 0 when dest has the
# requested paths (a failed fetch of a checkout we already have counts).
# set -e is off when the caller uses `if`, so every failure is returned.
refresh_sparse() {
  local url=$1 dest=$2
  shift 2
  local -a paths=("$@")
  local err="" sha=""
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if ! cache_repo_sane "$dest"; then
      # prepare_cache should have wiped this. do not reset it.
      warn "refusing to reset cache repo that failed checks: $dest"
      return 1
    fi
    if gitc -C "$dest" remote set-url origin "$url" \
      && err=$(gitc -C "$dest" fetch --quiet --depth 1 --no-tags origin main 2>&1) \
      && sha=$(gitc -C "$dest" rev-parse FETCH_HEAD 2>/dev/null); then
      if ! cache_repo_sane "$dest"; then
        warn "refusing to reset cache repo that failed checks: $dest"
        return 1
      fi
      gitc -C "$dest" sparse-checkout set "${paths[@]}" >/dev/null 2>&1 || {
        warn "sparse-checkout failed for $url"
        return 1
      }
      if ! cache_repo_sane "$dest"; then
        warn "refusing to reset cache repo that failed checks: $dest"
        return 1
      fi
      gitc -C "$dest" reset --quiet --hard "$sha" || {
        warn "git reset failed for $url"
        return 1
      }
      return 0
    fi
    if cache_repo_sane "$dest" && cache_ready "$dest" "${paths[@]}"; then
      warn "fetch failed for $url; using the cached checkout"
      return 0
    fi
    warn "fetch failed for $url${err:+: ${err##*$'\n'}}"
    return 1
  fi
  clone_sparse "$url" "$dest" "${paths[@]}"
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

# a file component we are willing to delete. skill and agent names are
# tighter; a file inside a skill may be copied from upstream, so the check
# is "cannot climb out" rather than the skill-name class. newline and slash
# cannot appear in one component.
component_ok() {
  local c=$1
  [ -n "$c" ] || return 1
  [ "$c" != "." ] && [ "$c" != ".." ] || return 1
  case "$c" in
    *$'\n'*|*'/'*) return 1 ;;
  esac
}

# a manifest entry we are willing to delete: a file under one safe skill
# name, or one safe agent file. ".." in any component is rejected.
valid_owned_file() {
  local rel=$1 rest name part
  case "$rel" in
    .claude/skills/*/*)
      rest=${rel#.claude/skills/}
      name=${rest%%/*}
      safe_skill_name "$name" || return 1
      rest=${rest#*/}
      [ -n "$rest" ] || return 1
      while [ -n "$rest" ]; do
        part=${rest%%/*}
        if [ "$part" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
        component_ok "$part" || return 1
      done
      ;;
    .claude/agents/*)
      rest=${rel#.claude/agents/}
      case "$rest" in */*) return 1 ;; esac
      safe_agent_name "$rest"
      ;;
    *) return 1 ;;
  esac
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
    [ -d "$dir" ] && [ -f "$dir/SKILL.md" ] && [ ! -L "$dir/SKILL.md" ] || continue
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

# NUL-delimited paths relative to root. regular files only, so a symlink is
# neither copied nor followed. a newline in a relative path is skipped.
collect_files() {
  local root=$1 f rel
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  while IFS= read -r -d '' f; do
    rel=${f#"$root"/}
    case "$rel" in
      *$'\n'*)
        warn "skipping source file whose path contains a newline"
        continue
        ;;
    esac
    [ -n "$rel" ] || continue
    printf '%s\0' "$rel"
  done < <(find -P "$root" -type f -print0)
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

# info and info/exclude must be real. writing through either symlink would
# change a file outside this git dir.
refuse_linked_exclude() {
  local gitdir=$1 info="$1/info" file="$1/info/exclude"
  if [ -L "$info" ]; then
    warn "refusing to follow symlink: info"
    return 1
  fi
  if [ -e "$info" ] && [ ! -d "$info" ]; then
    warn "refusing to use info because it is not a directory"
    return 1
  fi
  if [ -L "$file" ]; then
    warn "refusing to follow symlink: info/exclude"
    return 1
  fi
  if [ -e "$file" ] && [ ! -f "$file" ]; then
    warn "refusing to use info/exclude because it is not a file"
    return 1
  fi
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

# true when the manifest lists this skill (any file under it, or the dir).
skill_owned() {
  local name=$1 line
  [ -n "${owned[".claude/skills/$name"]+x}" ] && return 0
  for line in "${!owned[@]}"; do
    case "$line" in
      .claude/skills/"$name"/*) return 0 ;;
    esac
  done
  return 1
}

agent_owned() {
  [ -n "${owned[".claude/agents/$1"]+x}" ]
}

# literal file only. a symlink is unlinked. a mount point is left alone.
# rm --one-file-system so a remove cannot cross into another filesystem.
remove_owned_file() {
  local rel=$1 path="$target/$1"
  if ! valid_owned_file "$rel"; then
    warn "refusing to remove unexpected manifest path: $rel"
    return 0
  fi
  if parent_has_symlink "$rel"; then
    warn "refusing to remove through symlink: $rel"
    return 0
  fi
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi
  if [ -L "$path" ]; then
    rm -- "$path" || warn "could not unlink $rel"
    return 0
  fi
  if is_mount_point "$path"; then
    warn "skipping mount point: $rel"
    return 0
  fi
  if [ -d "$path" ]; then
    rm -rf --one-file-system -- "$path" || warn "could not remove $rel"
    return 0
  fi
  rm -f --one-file-system -- "$path" || warn "could not remove $rel"
}

# drop empty directories left after a file we copied was removed. rmdir
# fails on a directory that still holds a user file, which is what we want.
prune_empty_dirs() {
  local dir=$1 d
  [ -d "$dir" ] && [ ! -L "$dir" ] || return 0
  if is_mount_point "$dir"; then
    warn "skipping mount point: $dir"
    return 0
  fi
  while IFS= read -r -d '' d; do
    [ -L "$d" ] && continue
    rmdir -- "$d" 2>/dev/null || true
  done < <(find -P "$dir" -depth -type d -print0)
}

# a skill directory we own that the sources no longer ship. only the files
# the manifest lists are removed. a symlink is unlinked and not followed.
remove_stale_skill() {
  local name=$1 dest_rel=".claude/skills/$1" dest="$target/.claude/skills/$1" line
  if parent_has_symlink "$dest_rel"; then
    warn "refusing to remove through symlink: $dest_rel"
    return 0
  fi
  if [ -L "$dest" ]; then
    rm -- "$dest" || warn "could not unlink $dest_rel"
    return 0
  fi
  if [ -d "$dest" ] && is_mount_point "$dest"; then
    warn "skipping mount point: $dest_rel"
    return 0
  fi
  for line in "${!owned[@]}"; do
    case "$line" in
      .claude/skills/"$name"/*) remove_owned_file "$line" ;;
    esac
  done
  prune_empty_dirs "$dest"
}

# copy one regular file. the destination symlink is unlinked, not written
# through. a mount point is skipped.
install_file() {
  local src=$1 rel=$2 dest="$target/$2" parent
  parent=${rel%/*}
  if ! valid_owned_file "$rel"; then
    warn "refusing to copy unexpected path: $rel"
    return 1
  fi
  if parent_has_symlink "$rel"; then
    warn "refusing to follow symlink: $rel"
    return 1
  fi
  if [ -L "$src" ] || [ ! -f "$src" ]; then
    warn "refusing to copy symlink source: $src"
    return 1
  fi
  ensure_dir "$parent" || return 1
  if [ -L "$dest" ]; then
    rm -- "$dest" || return 1
  elif [ -e "$dest" ]; then
    if is_mount_point "$dest"; then
      warn "skipping mount point: $rel"
      return 1
    fi
    if [ -d "$dest" ]; then
      rm -rf --one-file-system -- "$dest" || return 1
    else
      rm -f --one-file-system -- "$dest" || return 1
    fi
  fi
  cp -a -- "$src" "$dest"
}

# update a skill we own, or create one that is not there. files the source
# has are copied. files the manifest says we copied before, and the source
# no longer has, are removed. anything else in the directory stays.
sync_skill() {
  local name=$1 src=$2 dest_rel=".claude/skills/$1" dest="$target/.claude/skills/$1"
  local rel tail line
  declare -A want=()
  local -a copied=()
  if parent_has_symlink "$dest_rel"; then
    warn "refusing to follow symlink: $dest_rel"
    return 0
  fi
  if [ -L "$dest" ]; then
    if ! skill_owned "$name"; then
      warn "leaving pre-existing untracked path in place: $dest_rel"
      return 0
    fi
    rm -- "$dest" || return 0
  elif [ -d "$dest" ] && is_mount_point "$dest"; then
    warn "skipping mount point: $dest_rel"
    return 0
  elif [ -e "$dest" ] && [ ! -d "$dest" ]; then
    if ! skill_owned "$name"; then
      warn "leaving pre-existing untracked path in place: $dest_rel"
      return 0
    fi
    if is_mount_point "$dest"; then
      warn "skipping mount point: $dest_rel"
      return 0
    fi
    rm -f --one-file-system -- "$dest" || return 0
  elif [ -e "$dest" ] && ! skill_owned "$name"; then
    warn "leaving pre-existing untracked path in place: $dest_rel"
    return 0
  fi
  while IFS= read -r -d '' rel; do
    [ -n "$rel" ] || continue
    want["$rel"]=1
    if install_file "$src/$rel" "$dest_rel/$rel"; then
      copied+=("$dest_rel/$rel")
    else
      warn "copy failed: $dest_rel/$rel"
    fi
  done < <(collect_files "$src")
  if skill_owned "$name"; then
    for line in "${!owned[@]}"; do
      case "$line" in
        .claude/skills/"$name"/*) ;;
        *) continue ;;
      esac
      tail=${line#"$dest_rel"/}
      if [ -z "${want[$tail]+x}" ]; then
        remove_owned_file "$line"
      fi
    done
    prune_empty_dirs "$dest"
  fi
  if [ "${#copied[@]}" -eq 0 ]; then
    return 0
  fi
  n_skills=$((n_skills + 1))
  exclude_pats+=("$dest_rel/")
  installed_files+=("${copied[@]}")
}

sync_agent() {
  local name=$1 src=$2 rel=".claude/agents/$1" dest="$target/.claude/agents/$1"
  if parent_has_symlink "$rel"; then
    warn "refusing to follow symlink: $rel"
    return 0
  fi
  if [ -L "$dest" ]; then
    if ! agent_owned "$name"; then
      warn "leaving pre-existing untracked path in place: $rel"
      return 0
    fi
    rm -- "$dest" || return 0
  elif [ -e "$dest" ]; then
    if is_mount_point "$dest"; then
      warn "skipping mount point: $rel"
      return 0
    fi
    if ! agent_owned "$name"; then
      warn "leaving pre-existing untracked path in place: $rel"
      return 0
    fi
  fi
  if ! install_file "$src" "$rel"; then
    warn "copy failed: $rel"
    return 0
  fi
  n_agents=$((n_agents + 1))
  exclude_pats+=("$rel")
  installed_files+=("$rel")
}

# true when a begin marker is still open at EOF. an end closes one begin.
# a begin that never closes must not cause the lines after it to be deleted.
exclude_has_open_begin() {
  local file=$1
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  awk '
    $0 == "# kru-cloud-skills begin" { depth++; next }
    $0 == "# kru-cloud-skills end" { if (depth > 0) depth--; next }
    END { exit (depth > 0 ? 0 : 1) }
  ' "$file"
}

# rewrite only the block this script owns. every other line stays, so a
# checkout's own excludes are not touched. the block is sorted, so a second
# run writes the same bytes. an unclosed begin is left byte for byte and a
# new block is appended after it.
write_exclude() {
  local gitdir=$1
  shift
  local info="$gitdir/info"
  # a second name on the same local is expanded before info is assigned.
  local file="$info/exclude" tmp body
  if [ -L "$info" ] || [ -L "$file" ]; then
    warn "refusing to follow symlink: info/exclude"
    return 1
  fi
  if [ -d "$info" ]; then
    :
  elif [ -e "$info" ]; then
    warn "refusing to use info because it is not a directory"
    return 1
  else
    mkdir -- "$info" || return 1
  fi
  tmp=$(mktemp) || return 1
  if [ -f "$file" ] && exclude_has_open_begin "$file"; then
    warn "exclude block has a begin marker without an end; appending a new block"
    cat -- "$file" > "$tmp" || return 1
    # command substitution would strip the newline we are trying to detect.
    if [ -s "$tmp" ]; then
      local last
      last=$(tail -c 1 "$tmp" && printf x) || return 1
      last=${last%x}
      if [ "$last" != $'\n' ]; then
        printf '\n' >> "$tmp" || return 1
      fi
    fi
    {
      cat -- "$tmp"
      printf '%s\n' '# kru-cloud-skills begin'
      if [ "$#" -gt 0 ]; then printf '%s\n' "$@" | sort -u; fi
      printf '%s\n' '# kru-cloud-skills end'
    } > "$tmp.append" || return 1
    mv -- "$tmp.append" "$file" || return 1
    rm -f -- "$tmp"
    return 0
  fi
  body=$(mktemp) || return 1
  if [ -f "$file" ]; then
    awk '
      $0 == "# kru-cloud-skills begin" { skip = 1; next }
      $0 == "# kru-cloud-skills end" { skip = 0; next }
      !skip { print }
    ' "$file" > "$body" || return 1
  fi
  {
    if [ -s "$body" ]; then cat "$body"; fi
    printf '%s\n' '# kru-cloud-skills begin'
    if [ "$#" -gt 0 ]; then printf '%s\n' "$@" | sort -u; fi
    printf '%s\n' '# kru-cloud-skills end'
  } > "$tmp" || return 1
  mv -- "$tmp" "$file" || return 1
  rm -f -- "$body"
}

read_manifest() {
  local file=$1
  [ -f "$file" ] && [ ! -L "$file" ] || return 0
  awk '$0 !~ /^#/ && $0 != "" { print }' "$file"
}

write_manifest() {
  local file=$1
  shift
  local tmp
  if [ -L "$file" ]; then
    warn "refusing to follow symlink: kru-cloud-skills.manifest"
    return 1
  fi
  tmp=$(mktemp) || return 1
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@" | sort -u > "$tmp" || return 1
  else
    : > "$tmp" || return 1
  fi
  mv -- "$tmp" "$file" || return 1
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

  local gitdir
  gitdir=$(gitc -C "$target" rev-parse --absolute-git-dir && printf x) || {
    warn "cannot resolve git dir: $target"
    exit 0
  }
  gitdir=${gitdir%x}
  gitdir=${gitdir%$'\n'}
  case "$gitdir" in
    *$'\n'*) warn "refusing a git dir that contains a newline"; exit 0 ;;
  esac

  local cache kru_url plugins_url
  cache=${KRU_CLOUD_SKILLS_CACHE:-${HOME:-/tmp}/.cache/kru-cloud-skills}
  kru_url=${KRU_CLOUD_SKILLS_KRU_URL:-https://github.com/salasjustin/kru-cursor.git}
  plugins_url=${KRU_CLOUD_SKILLS_PLUGINS_URL:-https://github.com/cursor/plugins.git}
  if ! prepare_cache "$cache"; then
    warn "cannot prepare cache $cache; leaving $target unchanged"
    exit 0
  fi

  if ! refresh_sparse "$kru_url" "$cache/kru-cursor" skills agents; then
    warn "kru-cursor unavailable; leaving $target unchanged"
    exit 0
  fi
  if ! refresh_sparse "$plugins_url" "$cache/plugins" pstack; then
    warn "pstack unavailable; leaving $target unchanged"
    exit 0
  fi
  # a wipe is refused above; if one source's repo was replaced by a real
  # clone, the other path is still the checkout prepare_cache left in place.

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
  if ! refuse_linked_exclude "$gitdir"; then
    exit 0
  fi
  local manifest="$gitdir/kru-cloud-skills.manifest"
  if [ -L "$manifest" ]; then
    warn "refusing to follow symlink: kru-cloud-skills.manifest"
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

  local -a skipped=()
  declare -A want_skill=() want_agent=()
  local rel
  for name in "${!skill_src[@]}"; do
    rel=".claude/skills/$name"
    if is_tracked "$target" "$rel"; then
      skipped+=("$rel")
      continue
    fi
    want_skill["$name"]=1
  done
  for name in "${!agent_src[@]}"; do
    rel=".claude/agents/$name"
    if is_tracked "$target" "$rel"; then
      skipped+=("$rel")
      continue
    fi
    want_agent["$name"]=1
  done

  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! valid_owned_file "$line"; then
      warn "ignoring unexpected manifest path: $line"
      continue
    fi
    owned["$line"]=1
  done < <(read_manifest "$manifest")

  if ! ensure_dir .claude/skills || ! ensure_dir .claude/agents; then
    exit 0
  fi

  # drop owned skills the sources no longer ship, and owned agent files.
  # a tracked path is no longer ours to delete.
  declare -A stale_skills=()
  local sname
  for line in "${!owned[@]}"; do
    case "$line" in
      .claude/skills/*)
        sname=${line#.claude/skills/}
        sname=${sname%%/*}
        if [ -n "${want_skill[$sname]+x}" ]; then
          continue
        fi
        if is_tracked "$target" ".claude/skills/$sname"; then
          continue
        fi
        stale_skills["$sname"]=1
        ;;
      .claude/agents/*)
        sname=${line#.claude/agents/}
        if [ -n "${want_agent[$sname]+x}" ]; then
          continue
        fi
        if is_tracked "$target" "$line"; then
          continue
        fi
        remove_owned_file "$line"
        ;;
    esac
  done
  for sname in "${!stale_skills[@]}"; do
    remove_stale_skill "$sname"
  done

  local -a installed_files=() exclude_pats=()
  local n_skills=0 n_agents=0
  for name in "${!want_skill[@]}"; do
    sync_skill "$name" "${skill_src[$name]}"
  done
  for name in "${!want_agent[@]}"; do
    sync_agent "$name" "${agent_src[$name]}"
  done

  if [ "${#exclude_pats[@]}" -gt 0 ]; then
    write_exclude "$gitdir" "${exclude_pats[@]}" || warn "could not write $gitdir/info/exclude"
  else
    write_exclude "$gitdir" || warn "could not write $gitdir/info/exclude"
  fi
  if [ "${#installed_files[@]}" -gt 0 ]; then
    write_manifest "$manifest" "${installed_files[@]}" || warn "could not write the manifest"
  else
    write_manifest "$manifest" || warn "could not write the manifest"
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
