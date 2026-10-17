#!/bin/bash
# copy a chosen set of skills into <library-dir>/<name>/.
# a copy is refreshed only when the first line after its frontmatter is the
# exact synced-from marker this script writes, or when the folder is not
# there yet. anything else is foreign or unmarked: logged and left untouched.
# a name that leaves the list is reported and stays on disk.
#
# threat model: this script runs from /release against a library only this
# user writes to. no concurrent writer. a process that already has write
# access to the library can change those files itself; this script does not
# try to win a race against one. an exclusive flock on <library>/.sync.lock
# keeps two syncs from overlapping. if that lock is held, or the lock path is
# a symlink, exit non-zero and write nothing. a missing lock is created
# without following links.
#
# a skill directory that is itself a symlink is skipped. a symlink anywhere
# in the source skill is an error: that skill is not installed. an extra file
# whose path contains a symlink is not copied and is not followed. the new
# tree is built in a fresh directory and moved into place with mv -T. if that
# move fails, the parked tree is moved back. it is removed only after the new
# tree is in place.
#
# the line inserted after each copy's frontmatter is the ownership marker.
# version comes from .cursor-plugin/plugin.json.
#
# usage: sync-bot-skills.sh [--] <library-dir> [--list FILE]
# test seams, unset in normal use:
#   KRU_SYNC_SKILL_ROOT    directory used instead of <repo>/skills
#   KRU_SYNC_BEFORE_REPLACE  script run after the old tree is parked and
#     before the new tree is moved into place. arguments: dest, name, stage, parked
# logs:
#   synced <name>
#   skipped <name>: foreign owner (<owner>)
#   skipped <name>: no owner marker
#   skipped <name>: symlink
#   skipped <name>: cannot scan for symlinks
#   skipped <name>: extra symlink <path>
#   error: <name>: source contains a symlink
#   error: <name>: cannot scan source
#   error: <name>: could not install
#   error: sync already running
#   error: lock file is a symlink
#   parked skill left at <path>
#   dropped <name>: not in the list, left in place
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
caller_pwd=$(pwd)

usage() {
  echo "usage: sync-bot-skills.sh [--] <library-dir> [--list FILE]" >&2
}

library=""
list="$root/scripts/bot-skills.txt"
while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      [ $# -ge 2 ] || { usage; exit 2; }
      list=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      # the next argument is the library path, even when it starts with -
      shift
      [ $# -ge 1 ] || { usage; exit 2; }
      [ -z "$library" ] || { usage; exit 2; }
      library=$1
      shift
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      [ -z "$library" ] || { usage; exit 2; }
      library=$1
      shift
      ;;
  esac
done
[ -n "$library" ] || { usage; exit 2; }
case "$library" in
  /*) ;;
  *) library="$caller_pwd/$library" ;;
esac
case "$list" in
  /*) ;;
  *) list="$caller_pwd/$list" ;;
esac
[ -f "$list" ] || { echo "no such list: $list" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

version=$(jq -r '.version // empty' "$root/.cursor-plugin/plugin.json")
[ -n "$version" ] || { echo "plugin manifest has no version" >&2; exit 1; }

skill_root=$root/skills
if [ -n "${KRU_SYNC_SKILL_ROOT:-}" ]; then
  skill_root=${KRU_SYNC_SKILL_ROOT}
  case "$skill_root" in
    /*) ;;
    *) skill_root="$caller_pwd/$skill_root" ;;
  esac
fi

declare -A listed=()
names=()
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%%#*}
  line=${line#"${line%%[![:space:]]*}"}
  line=${line%"${line##*[![:space:]]}"}
  [ -n "$line" ] || continue
  [[ $line =~ ^[a-z0-9-]+$ ]] || { echo "bad skill name: $line" >&2; exit 1; }
  [ -n "${listed[$line]:-}" ] && continue
  listed[$line]=1
  names+=("$line")
done < "$list"

# frontmatter counts only when line 1 is exactly `---`, with no BOM and no CR.
# the end fence is the next line that is exactly `---`. the marker is the line
# right after that fence. a BOM anywhere, or no valid leading frontmatter,
# is unmarked. prints the marker line and returns 0, or returns 1.
frontmatter_marker() {
  local file=$1 sig
  if grep -a -q $'\xef\xbb\xbf' "$file"; then
    return 1
  fi
  sig=$(od -An -N 2 -t x1 "$file" 2>/dev/null | tr -d ' \n' || true)
  case "$sig" in
    fffe|feff) return 1 ;;
  esac
  awk '
    BEGIN { seen = 0 }
    NR == 1 {
      if ($0 != "---") exit 1
      next
    }
    seen == 0 && $0 == "---" {
      seen = 1
      if ((getline line) > 0) print line
      exit 0
    }
    END { if (!seen) exit 1 }
  ' "$file"
}

# the only line that counts as kru:
#   <!-- synced-from: kru@<ver> skills/<name> | owner: kru | edit the source, not this copy -->
# <ver> is any non-space token. the rest of the line matches exactly.
marker_is_kru() {
  local name=$1 line=$2 ver rest
  local prefix="<!-- synced-from: kru@"
  local suffix=" skills/${name} | owner: kru | edit the source, not this copy -->"
  case "$line" in
    "$prefix"*) ;;
    *) return 1 ;;
  esac
  rest=${line#"$prefix"}
  ver=${rest%% *}
  [ -n "$ver" ] || return 1
  [ "$rest" = "${ver}${suffix}" ]
}

is_kru_owned() {
  local name=$1 file=$2 line
  if ! line=$(frontmatter_marker "$file"); then
    return 1
  fi
  marker_is_kru "$name" "$line"
}

# kru | foreign | unmarked. ownership comes only from that exact marker line.
# no valid leading frontmatter, or any BOM, is unmarked.
owner_kind() {
  local name=$1 file=$2 line
  if ! line=$(frontmatter_marker "$file"); then
    printf 'unmarked'
    return 0
  fi
  if marker_is_kru "$name" "$line"; then
    printf 'kru'
  elif grep -E -q 'owner: [^[:space:]|]+' "$file"; then
    printf 'foreign'
  else
    printf 'unmarked'
  fi
}

# symlink | inside | error | clean.
# symlink: the path itself is a link. inside: find -P saw a link below it.
# find's non-zero status is an error: fail closed. a dangling link counts.
scan_symlinks() {
  local dest=$1 found status
  if [ -h "$dest" ] || [ -L "$dest" ]; then
    printf 'symlink'
    return 0
  fi
  if [ ! -d "$dest" ]; then
    printf 'clean'
    return 0
  fi
  found=$(find -P "$dest" -type l -print -quit 2>/dev/null) && status=0 || status=$?
  if [ "$status" -ne 0 ]; then
    printf 'error'
    return 0
  fi
  if [ -n "$found" ]; then
    printf 'inside'
  else
    printf 'clean'
  fi
}

# true when any component of root/rel is a symlink. does not follow.
# split on / without globbing, so a component named * stays literal.
path_has_symlink() {
  local root=$1 rel=$2 acc="" part
  local -a parts=()
  local IFS=/
  read -ra parts <<< "$rel" || true
  for part in "${parts[@]}"; do
    [ -n "$part" ] || continue
    if [ -z "$acc" ]; then
      acc=$part
    else
      acc="$acc/$part"
    fi
    if [ -h "$root/$acc" ] || [ -L "$root/$acc" ]; then
      return 0
    fi
  done
  return 1
}

foreign_owner() {
  grep -oE 'owner: [^[:space:]|]+' "$1" | head -n1 | sed 's/^owner: //'
}

insert_marker() {
  local file=$1 marker=$2 tmp
  # keep the temp next to the staged file, not under TMPDIR.
  tmp=$(mktemp "$(dirname -- "$file")/.marker.XXXXXX") || return 1
  if ! awk -v marker="$marker" '
    BEGIN { closed = 0 }
    NR == 1 {
      if ($0 != "---") exit 1
      print
      next
    }
    closed == 0 && $0 == "---" {
      print
      print marker
      closed = 1
      next
    }
    { print }
    END { if (!closed) exit 1 }
  ' "$file" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if ! mv "$tmp" "$file"; then
    rm -f "$tmp"
    return 1
  fi
}

# stage_dir is the new tree, removed on failure. parked_dir is the previous
# tree. the exit trap restores a parked tree; it never deletes one.
stage_dir=""
parked_dir=""
parked_dest=""
drop_stage() {
  if [ -n "$stage_dir" ] && { [ -e "$stage_dir" ] || [ -h "$stage_dir" ]; }; then
    rm -rf "$stage_dir"
  fi
  stage_dir=""
}
on_exit() {
  local rc=$?
  set +e
  drop_stage
  if [ -n "$parked_dir" ] && { [ -e "$parked_dir" ] || [ -h "$parked_dir" ]; }; then
    if [ -n "$parked_dest" ] && [ ! -e "$parked_dest" ] && [ ! -h "$parked_dest" ]; then
      if ! mv -T -- "$parked_dir" "$parked_dest"; then
        echo "parked skill left at $parked_dir" >&2
        rc=1
      fi
    else
      echo "parked skill left at $parked_dir" >&2
      rc=1
    fi
  fi
  exit "$rc"
}
trap on_exit EXIT

# copy files that exist only in dest into the fresh stage. find -P on both
# trees, so a symlink is not descended. an extra whose path contains a symlink
# is skipped, not followed. returns 2 on a scan error.
preserve_extras() {
  local dest=$1 stage=$2 name=$3 rel list status
  if [ ! -d "$dest" ] || [ -h "$dest" ] || [ -L "$dest" ]; then
    return 0
  fi
  list=$(find -P "$dest" -mindepth 1 -printf '%P\n' 2>/dev/null) && status=0 || status=$?
  [ "$status" -eq 0 ] || return 2
  find -P "$stage" -mindepth 1 -printf '%P\n' >/dev/null 2>/dev/null && status=0 || status=$?
  [ "$status" -eq 0 ] || return 2
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    if path_has_symlink "$dest" "$rel" || path_has_symlink "$stage" "$rel"; then
      echo "skipped $name: extra symlink $rel"
      continue
    fi
    if [ -e "$stage/$rel" ] || [ -h "$stage/$rel" ]; then
      continue
    fi
    if [ -d "$dest/$rel" ]; then
      mkdir -p -- "$stage/$rel" || return 2
      continue
    fi
    if [ -f "$dest/$rel" ] && [ ! -h "$dest/$rel" ] && [ ! -L "$dest/$rel" ]; then
      mkdir -p -- "$stage/$(dirname -- "$rel")" || return 2
      cp -a -- "$dest/$rel" "$stage/$rel" || return 2
    fi
  done <<< "$list"
}

# build the skill in a fresh directory under the library, then move it onto
# dest with mv -T. never cp into an existing path. the old tree is parked as
# .sync-old.* and removed only after the new tree is in place. if the second
# mv fails, the exit trap moves the parked tree back and never deletes it.
# returns 1 when the skill is skipped, 2 when the install failed.
# KRU_SYNC_BEFORE_REPLACE, when set, runs after the park and before the second
# mv. arguments: dest, name, stage, parked.
copy_skill() {
  local name=$1 src=$2 dest=$3 extra=0 old_slot=""
  stage_dir=$(mktemp -d "$library/.sync.XXXXXX") || {
    echo "error: $name: could not install" >&2
    return 2
  }
  if ! cp -a -- "$src"/. "$stage_dir"/; then
    drop_stage
    echo "error: $name: could not install" >&2
    return 2
  fi
  if ! insert_marker "$stage_dir/SKILL.md" \
    "<!-- synced-from: kru@${version} skills/${name} | owner: kru | edit the source, not this copy -->"; then
    drop_stage
    echo "error: $name: could not install" >&2
    return 2
  fi
  preserve_extras "$dest" "$stage_dir" "$name" || extra=$?
  if [ "$extra" -ne 0 ]; then
    drop_stage
    echo "skipped $name: cannot scan for symlinks"
    return 1
  fi
  if [ -h "$dest" ] || [ -L "$dest" ]; then
    drop_stage
    echo "skipped $name: symlink"
    return 1
  fi
  if [ -e "$dest" ]; then
    old_slot=$(mktemp -d "$library/.sync-old.XXXXXX") || {
      drop_stage
      echo "error: $name: could not install" >&2
      return 2
    }
    if ! rmdir "$old_slot"; then
      rm -rf "$old_slot"
      drop_stage
      echo "error: $name: could not install" >&2
      return 2
    fi
    if ! mv -T -- "$dest" "$old_slot"; then
      drop_stage
      echo "error: $name: could not install" >&2
      return 2
    fi
    parked_dir=$old_slot
    parked_dest=$dest
    if [ -n "${KRU_SYNC_BEFORE_REPLACE:-}" ]; then
      bash "$KRU_SYNC_BEFORE_REPLACE" "$dest" "$name" "$stage_dir" "$parked_dir" || true
    fi
    if ! mv -T -- "$stage_dir" "$dest"; then
      drop_stage
      echo "error: $name: could not install" >&2
      exit 1
    fi
    stage_dir=""
    if ! rm -rf "$parked_dir"; then
      echo "parked skill left at $parked_dir" >&2
      parked_dir=""
      parked_dest=""
      exit 1
    fi
    parked_dir=""
    parked_dest=""
  else
    if ! mv -T -- "$stage_dir" "$dest"; then
      drop_stage
      echo "error: $name: could not install" >&2
      return 2
    fi
    stage_dir=""
  fi
  return 0
}

command -v flock >/dev/null 2>&1 || { echo "flock is required" >&2; exit 1; }
mkdir -p "$library"
# refuse a symlink before opening it. create a missing lock with noclobber,
# which does not follow a link, then open it only if it is a regular file.
# a held lock exits before any skill is written. <> does not truncate.
lock=$library/.sync.lock
if [ -h "$lock" ] || [ -L "$lock" ]; then
  echo "error: lock file is a symlink" >&2
  exit 1
fi
if [ ! -e "$lock" ]; then
  set -o noclobber
  if ! : >"$lock"; then
    set +o noclobber
    if [ -h "$lock" ] || [ -L "$lock" ]; then
      echo "error: lock file is a symlink" >&2
    else
      echo "error: cannot create lock file" >&2
    fi
    exit 1
  fi
  set +o noclobber
fi
if [ -h "$lock" ] || [ -L "$lock" ] || [ ! -f "$lock" ]; then
  echo "error: lock file is a symlink" >&2
  exit 1
fi
exec 9<>"$lock"
if ! flock -n 9; then
  echo "error: sync already running" >&2
  exit 1
fi

sync_failed=0
for name in "${names[@]}"; do
  src="$skill_root/$name"
  dest="$library/$name"
  [ -f "$src/SKILL.md" ] || { echo "no such skill: $name" >&2; exit 1; }
  case "$(scan_symlinks "$src")" in
    symlink|inside)
      echo "error: $name: source contains a symlink" >&2
      sync_failed=1
      continue
      ;;
    error)
      echo "error: $name: cannot scan source" >&2
      sync_failed=1
      continue
      ;;
    clean) ;;
    *)
      echo "error: $name: cannot scan source" >&2
      sync_failed=1
      continue
      ;;
  esac
  case "$(scan_symlinks "$dest")" in
    symlink)
      echo "skipped $name: symlink"
      continue
      ;;
    inside|clean) ;;
    error|*)
      echo "skipped $name: cannot scan for symlinks"
      continue
      ;;
  esac
  if [ -e "$dest" ]; then
    if [ ! -d "$dest" ] || [ -h "$dest" ] || [ -L "$dest" ] || [ ! -f "$dest/SKILL.md" ]; then
      echo "skipped $name: no owner marker"
      continue
    fi
    case "$(owner_kind "$name" "$dest/SKILL.md")" in
      kru) ;;
      foreign)
        echo "skipped $name: foreign owner ($(foreign_owner "$dest/SKILL.md"))"
        continue
        ;;
      unmarked)
        echo "skipped $name: no owner marker"
        continue
        ;;
    esac
  fi
  if copy_skill "$name" "$src" "$dest"; then
    echo "synced $name"
  else
    copy_status=$?
    if [ "$copy_status" -ne 1 ]; then
      sync_failed=1
    fi
  fi
done

shopt -s nullglob
for dir in "$library"/*/; do
  name=$(basename "$dir")
  [ -n "${listed[$name]:-}" ] && continue
  [ -f "$dir/SKILL.md" ] || continue
  if is_kru_owned "$name" "$dir/SKILL.md"; then
    echo "dropped $name: not in the list, left in place"
  fi
done

if [ "$sync_failed" -ne 0 ]; then
  exit 1
fi
