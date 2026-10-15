#!/usr/bin/env bash
# cloud-skills.sh against local source repos, so verify.sh stays offline.
# the installer is fed on stdin (the way a curl pipe runs it) and must not
# need its own path. run: bash scripts/cloud-skills.test.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
script="$repo/scripts/cloud-skills.sh"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

pass=0
fail=0
skip=0
report() {
  local name=$1 ok=$2 detail=$3
  if [ "$ok" = yes ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$detail"
  fi
}
skip_case() {
  skip=$((skip + 1))
  printf 'SKIP: %s\n' "$1"
}

init_repo() {
  git init -q -b main "$1"
  git -C "$1" config user.email dev@example.com
  git -C "$1" config user.name Dev
}

commit_repo() {
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

# sources: a kru checkout (skills/ + agents/ at the root) and a plugins
# checkout (skills and agents nested under pstack/). one name is in both,
# and one name matches a skill the target already tracks.
kru="$sandbox/src-kru"
plugins="$sandbox/src-plugins"
mkdir -p "$kru/skills/kru-alpha" "$kru/skills/shared" "$kru/skills/not-a-skill" "$kru/agents"
mkdir -p "$plugins/pstack/skills/pstack-beta" "$plugins/pstack/skills/shared" \
  "$plugins/pstack/skills/foo" "$plugins/pstack/agents" \
  "$plugins/other-plugin/skills/nope"
printf 'kru alpha\n' > "$kru/skills/kru-alpha/SKILL.md"
printf 'kru shared\n' > "$kru/skills/shared/SKILL.md"
printf 'not a skill\n' > "$kru/skills/not-a-skill/README.md"
printf 'kru lead\n' > "$kru/agents/lead.md"
printf 'notes\n' > "$kru/agents/notes.txt"
# names that are not one safe segment: a glob metacharacter, a newline, a space.
star_skill='bad*name'
nl_skill=$'bad\nname'
mkdir -p "$kru/skills/$star_skill" "$kru/skills/$nl_skill"
printf 'star\n' > "$kru/skills/$star_skill/SKILL.md"
printf 'newline\n' > "$kru/skills/$nl_skill/SKILL.md"
printf 'space\n' > "$kru/agents/bad name.md"
printf 'star agent\n' > "$kru/agents/has*star.md"
printf 'pstack beta\n' > "$plugins/pstack/skills/pstack-beta/SKILL.md"
printf 'pstack shared\n' > "$plugins/pstack/skills/shared/SKILL.md"
printf 'pstack foo\n' > "$plugins/pstack/skills/foo/SKILL.md"
printf 'pstack helper\n' > "$plugins/pstack/agents/helper.md"
printf 'pstack lead\n' > "$plugins/pstack/agents/lead.md"
printf 'pstack kept\n' > "$plugins/pstack/agents/kept.md"
printf 'not installed\n' > "$plugins/other-plugin/skills/nope/SKILL.md"
init_repo "$kru"
init_repo "$plugins"
commit_repo "$kru" "kru skills"
commit_repo "$plugins" "pstack skills"

target="$sandbox/repo"
mkdir -p "$target/.claude/skills/foo" "$target/.claude/agents" "$target/nested"
printf 'tracked foo\n' > "$target/.claude/skills/foo/SKILL.md"
printf 'tracked kept\n' > "$target/.claude/agents/kept.md"
printf '*.log\n' > "$target/.gitignore"
init_repo "$target"
commit_repo "$target" "tracked skill"
printf '# keep me\n*.tmp\n' > "$target/.git/info/exclude"
gitignore_before=$(sha256sum "$target/.gitignore" | awk '{print $1}')

cache="$sandbox/cache"
# a real pipe, the way curl | bash runs the installer. a redirect is not a pipe.
run_install() {
  local dir=$1
  shift
  (
    cd "$dir"
    cat "$script" | env \
      KRU_CLOUD_SKILLS_CACHE="$cache" \
      KRU_CLOUD_SKILLS_KRU_URL="$kru" \
      KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
      KRU_CLOUD_SKILLS_FALLBACK="${KRU_CLOUD_SKILLS_FALLBACK:-}" \
      bash -s -- "$@"
  )
}
run_cached() {
  local dir=$1 cache_dir=$2
  shift 2
  (
    cd "$dir"
    cat "$script" | env \
      KRU_CLOUD_SKILLS_CACHE="$cache_dir" \
      KRU_CLOUD_SKILLS_KRU_URL="$kru" \
      KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
      bash -s -- "$@"
  )
}

out=$(run_install "$sandbox" "$target" 2>"$sandbox/err1")
code=$?
report "piped run exits 0" "$([ "$code" = 0 ] && echo yes || echo no)" "exit $code"
report "summary names the target" "$(printf '%s' "$out" | grep -q "cloud-skills: 3 skills, 2 agents -> $target" && echo yes || echo no)" "$out"

report "tracked skill untouched" "$([ "$(cat "$target/.claude/skills/foo/SKILL.md")" = "tracked foo" ] && echo yes || echo no)" "$(cat "$target/.claude/skills/foo/SKILL.md")"
report "tracked agent untouched" "$([ "$(cat "$target/.claude/agents/kept.md")" = "tracked kept" ] && echo yes || echo no)" "$(cat "$target/.claude/agents/kept.md")"
report "kru skill copied" "$([ "$(cat "$target/.claude/skills/kru-alpha/SKILL.md")" = "kru alpha" ] && echo yes || echo no)" "missing kru-alpha"
report "pstack skill copied" "$([ "$(cat "$target/.claude/skills/pstack-beta/SKILL.md")" = "pstack beta" ] && echo yes || echo no)" "missing pstack-beta"
report "kru wins the shared name" "$([ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" "$(cat "$target/.claude/skills/shared/SKILL.md" 2>/dev/null)"
report "kru wins the shared agent" "$([ "$(cat "$target/.claude/agents/lead.md")" = "kru lead" ] && echo yes || echo no)" "$(cat "$target/.claude/agents/lead.md" 2>/dev/null)"
report "pstack agent copied" "$([ "$(cat "$target/.claude/agents/helper.md")" = "pstack helper" ] && echo yes || echo no)" "missing helper"
report "dir without SKILL.md skipped" "$([ ! -e "$target/.claude/skills/not-a-skill" ] && echo yes || echo no)" "not-a-skill was copied"
report "plugin outside pstack/ skipped" "$([ ! -e "$target/.claude/skills/nope" ] && echo yes || echo no)" "nope was copied"
report "non-agent file skipped" "$([ ! -e "$target/.claude/agents/notes.txt" ] && echo yes || echo no)" "notes.txt was copied"
report "star skill not copied" "$([ ! -e "$target/.claude/skills/$star_skill" ] && echo yes || echo no)" "$(find "$target/.claude/skills" -mindepth 1 -maxdepth 1 -printf '%f\n')"
report "newline skill not copied" "$([ ! -e "$target/.claude/skills/$nl_skill" ] && echo yes || echo no)" "newline name was copied"
report "unsafe agent names not copied" "$([ ! -e "$target/.claude/agents/bad name.md" ] && [ ! -e "$target/.claude/agents/has*star.md" ] && echo yes || echo no)" "$(find "$target/.claude/agents" -printf '%f\n')"
report "unsafe names warned" "$(grep -q 'unsafe name' "$sandbox/err1" && echo yes || echo no)" "$(cat "$sandbox/err1")"
report "exclude paths are a single safe segment" "$(
  awk '
    $0 == "# kru-cloud-skills begin" { p = 1; next }
    $0 == "# kru-cloud-skills end" { p = 0; next }
    p && $0 !~ /^\.claude\/skills\/[A-Za-z0-9._-]+\/$/ && $0 !~ /^\.claude\/agents\/[A-Za-z0-9._-]+\.md$/ { bad = 1 }
    END { exit bad }
  ' "$target/.git/info/exclude" && echo yes || echo no
)" "$(cat "$target/.git/info/exclude")"

status=$(git -C "$target" status --porcelain)
report "git status clean" "$([ -z "$status" ] && echo yes || echo no)" "$status"
report ".gitignore unchanged" "$([ "$(sha256sum "$target/.gitignore" | awk '{print $1}')" = "$gitignore_before" ] && echo yes || echo no)" "gitignore changed"
exclude=$(cat "$target/.git/info/exclude")
report "pre-existing exclude lines kept" "$(printf '%s\n' "$exclude" | grep -qx '# keep me' && printf '%s\n' "$exclude" | grep -qx '*.tmp' && echo yes || echo no)" "$exclude"
report "exclude lists a copied skill" "$(printf '%s\n' "$exclude" | grep -qx '.claude/skills/kru-alpha/' && echo yes || echo no)" "$exclude"
report "exclude does not list the tracked skill" "$(printf '%s\n' "$exclude" | grep -q '.claude/skills/foo' && echo no || echo yes)" "$exclude"
ignore_out=$(git -C "$target" check-ignore -v .claude/skills/kru-alpha/SKILL.md .claude/agents/helper.md)
report "exclude, not gitignore, hides copies" "$(printf '%s\n' "$ignore_out" | grep -q 'info/exclude' && ! printf '%s\n' "$ignore_out" | grep -q '.gitignore' && echo yes || echo no)" "$ignore_out"

manifest=$(git -C "$target" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "sparse clone skipped the other plugin" "$([ ! -e "$cache/plugins/other-plugin" ] && [ -f "$cache/plugins/pstack/skills/pstack-beta/SKILL.md" ] && [ -f "$cache/kru-cursor/skills/kru-alpha/SKILL.md" ] && echo yes || echo no)" "$(find "$cache" -type d -name other-plugin -o -name skills)"
report "manifest lives in the git dir" "$([ -f "$manifest" ] && [ ! -L "$manifest" ] && echo yes || echo no)" "$manifest"
report "cache does not hold the ownership manifest" "$([ ! -e "$cache/manifests" ] && echo yes || echo no)" "$(find "$cache" -type d -name manifests -print)"
report "manifest records the owned file" "$(grep -qx '.claude/skills/shared/SKILL.md' "$manifest" && echo yes || echo no)" "$(cat "$manifest")"
report "manifest records files, not the skill directory" "$(grep -qx '.claude/skills/shared/' "$manifest" && echo no || echo yes)" "$(cat "$manifest")"
report "manifest does not record the tracked skill" "$(grep -q 'foo' "$manifest" && echo no || echo yes)" "$(cat "$manifest")"
report "cache repo is not a symlink and has no core.worktree" "$(
  [ ! -L "$cache" ] && [ ! -L "$cache/kru-cursor" ] && [ ! -L "$cache/plugins" ] \
    && [ "$(git -C "$cache/kru-cursor" rev-parse --show-toplevel)" = "$cache/kru-cursor" ] \
    && ! git -C "$cache/kru-cursor" config --local --get core.worktree >/dev/null 2>&1 \
    && echo yes || echo no
)" "$(git -C "$cache/kru-cursor" rev-parse --show-toplevel 2>&1)"

tree_hash() {
  (
    cd "$1" || exit 1
    find .claude -type f ! -path './.git/*' -print | sort | while IFS= read -r f; do
      sha256sum "$f"
    done
    sha256sum .git/info/exclude
  ) | sha256sum | awk '{print $1}'
}
before=$(tree_hash "$target")
out2=$(run_install "$target/nested" 2>"$sandbox/err2")
code2=$?
after=$(tree_hash "$target")
status2=$(git -C "$target" status --porcelain)
report "second run exits 0" "$([ "$code2" = 0 ] && echo yes || echo no)" "exit $code2"
report "second run is idempotent" "$([ "$before" = "$after" ] && echo yes || echo no)" "tree hash $before -> $after"
report "second run leaves git status clean" "$([ -z "$status2" ] && echo yes || echo no)" "$status2"
report "no-arg run from a subdir uses the toplevel" "$(printf '%s' "$out2" | grep -F -q -- "-> $target " && echo yes || echo no)" "$out2"

# an owned skill is replaced when the source changes, then put back so later
# checks still see the original bytes.
printf 'kru shared v2\n' > "$kru/skills/shared/SKILL.md"
commit_repo "$kru" "shared v2"
out_v2=$(run_install "$target" 2>"$sandbox/err-v2")
code_v2=$?
report "owned skill is replaced from the source" \
  "$([ "$code_v2" = 0 ] && [ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared v2" ] && echo yes || echo no)" \
  "exit $code_v2; $(cat "$target/.claude/skills/shared/SKILL.md" 2>/dev/null)"
printf 'kru shared\n' > "$kru/skills/shared/SKILL.md"
commit_repo "$kru" "shared restored"
run_install "$target" >/dev/null 2>/dev/null
report "owned skill restores with the source" \
  "$([ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "$(cat "$target/.claude/skills/shared/SKILL.md" 2>/dev/null)"

# refresh copies files the source has and removes only files we previously
# copied. a file the user added, including one next to a file we drop, stays.
printf 'user extra\n' > "$target/.claude/skills/shared/USER.md"
mkdir -p "$target/.claude/skills/shared/notes"
printf 'user note\n' > "$target/.claude/skills/shared/notes/USER.md"
printf 'ref body\n' > "$kru/skills/shared/reference.md"
mkdir -p "$kru/skills/shared/notes"
printf 'note\n' > "$kru/skills/shared/notes/extra.md"
printf 'kru shared v3\n' > "$kru/skills/shared/SKILL.md"
commit_repo "$kru" "shared files"
file_out=$(run_install "$target" 2>"$sandbox/file.err")
file_code=$?
report "owned skill refresh keeps a user file" \
  "$([ "$file_code" = 0 ] && [ "$(cat "$target/.claude/skills/shared/USER.md")" = "user extra" ] && [ "$(cat "$target/.claude/skills/shared/notes/USER.md")" = "user note" ] && echo yes || echo no)" \
  "exit $file_code; $(find "$target/.claude/skills/shared" -printf '%p\n' 2>/dev/null)"
report "owned skill refresh updates and adds source files" \
  "$([ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared v3" ] && [ "$(cat "$target/.claude/skills/shared/reference.md")" = "ref body" ] && [ "$(cat "$target/.claude/skills/shared/notes/extra.md")" = "note" ] && echo yes || echo no)" \
  "$file_out"
file_manifest=$(git -C "$target" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "manifest lists copied files and not the user file" \
  "$(grep -qx '.claude/skills/shared/SKILL.md' "$file_manifest" && grep -qx '.claude/skills/shared/reference.md' "$file_manifest" && grep -qx '.claude/skills/shared/notes/extra.md' "$file_manifest" && ! grep -q 'USER.md' "$file_manifest" && echo yes || echo no)" \
  "$(cat "$file_manifest")"
rm -f "$kru/skills/shared/reference.md"
rm -rf "$kru/skills/shared/notes"
printf 'kru shared\n' > "$kru/skills/shared/SKILL.md"
commit_repo "$kru" "drop shared extras"
run_install "$target" >/dev/null 2>"$sandbox/file2.err"
report "refresh removes only a file the source dropped" \
  "$([ ! -e "$target/.claude/skills/shared/reference.md" ] && [ ! -e "$target/.claude/skills/shared/notes/extra.md" ] && [ "$(cat "$target/.claude/skills/shared/USER.md")" = "user extra" ] && [ "$(cat "$target/.claude/skills/shared/notes/USER.md")" = "user note" ] && [ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "$(find "$target/.claude/skills/shared" -printf '%p\n' 2>/dev/null); $(cat "$sandbox/file2.err")"
file_manifest=$(git -C "$target" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "manifest drops the file the source dropped" \
  "$(grep -qx '.claude/skills/shared/SKILL.md' "$file_manifest" && ! grep -q 'reference.md' "$file_manifest" && ! grep -q 'notes/extra.md' "$file_manifest" && echo yes || echo no)" \
  "$(cat "$file_manifest")"

# a directory the repo did not commit and this script did not install stays.
collide="$sandbox/collide"
mkdir -p "$collide/.claude/skills/shared" "$collide/.claude/agents"
printf 'user shared\n' > "$collide/.claude/skills/shared/SKILL.md"
printf 'user helper\n' > "$collide/.claude/agents/helper.md"
init_repo "$collide"
git -C "$collide" commit -q --allow-empty -m init
col_out=$(run_install "$sandbox" "$collide" 2>"$sandbox/col.err")
col_code=$?
col_manifest=$(git -C "$collide" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "untracked collision run exits 0" "$([ "$col_code" = 0 ] && echo yes || echo no)" "exit $col_code"
report "untracked skill preserved" \
  "$([ "$(cat "$collide/.claude/skills/shared/SKILL.md")" = "user shared" ] && echo yes || echo no)" \
  "$(cat "$collide/.claude/skills/shared/SKILL.md" 2>/dev/null)"
report "untracked agent preserved" \
  "$([ "$(cat "$collide/.claude/agents/helper.md")" = "user helper" ] && echo yes || echo no)" \
  "$(cat "$collide/.claude/agents/helper.md" 2>/dev/null)"
report "untracked collision warned" "$(grep -q 'pre-existing untracked' "$sandbox/col.err" && echo yes || echo no)" "$(cat "$sandbox/col.err")"
report "untracked skill is not in the manifest" \
  "$([ -n "$col_manifest" ] && ! grep -q 'skills/shared' "$col_manifest" && echo yes || echo no)" \
  "manifest $(cat "$col_manifest" 2>/dev/null)"
report "a new skill is copied beside the collision" \
  "$([ "$(cat "$collide/.claude/skills/kru-alpha/SKILL.md")" = "kru alpha" ] && echo yes || echo no)" \
  "$col_out"

# .claude/skills as a symlink: refuse before anything is written through it.
outside="$sandbox/outside-skills"
mkdir -p "$outside"
printf 'marker\n' > "$outside/marker"
slink="$sandbox/slink-repo"
mkdir -p "$slink/.claude"
ln -s "$outside" "$slink/.claude/skills"
init_repo "$slink"
git -C "$slink" commit -q --allow-empty -m init
sl_out=$(run_install "$sandbox" "$slink" 2>"$sandbox/sl.err")
sl_code=$?
report "symlinked skills dir exits 0" "$([ "$sl_code" = 0 ] && echo yes || echo no)" "exit $sl_code; $sl_out"
report "symlinked skills dir is refused" "$(grep -q 'refusing to follow symlink: .claude/skills' "$sandbox/sl.err" && echo yes || echo no)" "$(cat "$sandbox/sl.err")"
report "symlink target untouched" \
  "$([ "$(cat "$outside/marker")" = "marker" ] && [ ! -e "$outside/shared" ] && [ ! -e "$outside/kru-alpha" ] && echo yes || echo no)" \
  "$(find "$outside" -printf '%p\n')"
report "skills path is still that symlink" "$([ -L "$slink/.claude/skills" ] && echo yes || echo no)" "$(ls -l "$slink/.claude")"
report "refusing the skills symlink installs no agents" \
  "$([ ! -e "$slink/.claude/agents/lead.md" ] && echo yes || echo no)" \
  "$(find "$slink/.claude" -printf '%p\n' 2>/dev/null)"

# a destination that is a symlink is not followed and, because we do not own
# it, is not replaced.
precious_dest="$sandbox/precious-dest"
mkdir -p "$precious_dest"
printf 'keep dest\n' > "$precious_dest/keep"
destrepo="$sandbox/dest-link"
mkdir -p "$destrepo/.claude/skills"
ln -s "$precious_dest" "$destrepo/.claude/skills/shared"
init_repo "$destrepo"
git -C "$destrepo" commit -q --allow-empty -m init
dest_out=$(run_install "$sandbox" "$destrepo" 2>"$sandbox/dest.err")
dest_code=$?
report "dest symlink run exits 0" "$([ "$dest_code" = 0 ] && echo yes || echo no)" "exit $dest_code; $dest_out"
report "dest symlink target untouched" \
  "$([ "$(cat "$precious_dest/keep")" = "keep dest" ] && [ ! -e "$precious_dest/SKILL.md" ] && echo yes || echo no)" \
  "$(find "$precious_dest" -printf '%p\n')"
report "dest symlink left in place" "$([ -L "$destrepo/.claude/skills/shared" ] && echo yes || echo no)" "$(ls -l "$destrepo/.claude/skills")"
report "other skill copied despite the dest symlink" \
  "$([ "$(cat "$destrepo/.claude/skills/kru-alpha/SKILL.md")" = "kru alpha" ] && echo yes || echo no)" \
  "$(find "$destrepo/.claude/skills" -printf '%p\n')"

# install a second checkout now, while pstack-beta still exists, so a later
# stale run can find that path in its manifest.
linkrepo="$sandbox/link-repo"
mkdir -p "$linkrepo"
init_repo "$linkrepo"
git -C "$linkrepo" commit -q --allow-empty -m init
link_out=$(run_install "$sandbox" "$linkrepo" 2>"$sandbox/link.err")
link_code=$?
report "link repo installed" \
  "$([ "$link_code" = 0 ] && [ -d "$linkrepo/.claude/skills/pstack-beta" ] && [ ! -L "$linkrepo/.claude/skills/pstack-beta" ] && echo yes || echo no)" \
  "exit $link_code; $link_out"

# SHELLOPTS is applied by bash at startup, before the script's own set line.
shell_repo="$sandbox/shell-repo"
mkdir -p "$shell_repo"
init_repo "$shell_repo"
git -C "$shell_repo" commit -q --allow-empty -m init
shell_out=$(
  cd /tmp
  cat "$script" | env SHELLOPTS=errexit:pipefail:nounset \
    KRU_CLOUD_SKILLS_CACHE="$cache" \
    KRU_CLOUD_SKILLS_KRU_URL="$kru" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
    bash -s -- "$shell_repo" 2>"$sandbox/shell.err"
)
shell_code=$?
report "errexit pipefail nounset run exits 0" \
  "$([ "$shell_code" = 0 ] && echo yes || echo no)" \
  "exit $shell_code; $(cat "$sandbox/shell.err"); $shell_out"
report "errexit run installed a skill" \
  "$([ "$(cat "$shell_repo/.claude/skills/shared/SKILL.md" 2>/dev/null)" = "kru shared" ] && echo yes || echo no)" \
  "$shell_out"

# a skill we installed, then the repo commits, must survive a later removal
# from the source: it is tracked now, so it is no longer ours to delete.
git -C "$target" add -f .claude/skills/kru-alpha
commit_repo "$target" "adopt kru-alpha"
rm -rf "$kru/skills/kru-alpha"
commit_repo "$kru" "drop kru-alpha"
out3=$(run_install "$target" 2>"$sandbox/err3")
code3=$?
report "stale-removal run exits 0" "$([ "$code3" = 0 ] && echo yes || echo no)" "exit $code3; $(cat "$sandbox/err3")"
# pstack-beta is still shipped; kru-alpha was dropped from the source but is
# now tracked, so the directory stays and its content stays the installed copy.
report "tracked skill is not deleted after it leaves the source" \
  "$([ "$(cat "$target/.claude/skills/kru-alpha/SKILL.md")" = "kru alpha" ] && echo yes || echo no)" \
  "$(cat "$target/.claude/skills/kru-alpha/SKILL.md" 2>/dev/null)"
report "summary no longer counts the adopted skill as copied" \
  "$(printf '%s' "$out3" | grep -q 'cloud-skills: 2 skills, 2 agents' && echo yes || echo no)" "$out3"
status3=$(git -C "$target" status --porcelain)
report "status clean after the adopted skill drops out of the source" "$([ -z "$status3" ] && echo yes || echo no)" "$status3"

# a file the user added inside a skill we own must survive when that skill
# leaves the source. only the files the manifest lists are removed.
extra="$sandbox/extra-repo"
mkdir -p "$extra"
init_repo "$extra"
git -C "$extra" commit -q --allow-empty -m init
extra_install=$(run_install "$sandbox" "$extra" 2>"$sandbox/extra.err")
extra_install_code=$?
printf 'user extra\n' > "$extra/.claude/skills/pstack-beta/USER.md"
mkdir -p "$extra/.claude/skills/pstack-beta/keep"
printf 'keep\n' > "$extra/.claude/skills/pstack-beta/keep/mine.md"
report "extra repo installed before the skill leaves the source" \
  "$([ "$extra_install_code" = 0 ] && [ -f "$extra/.claude/skills/pstack-beta/SKILL.md" ] && echo yes || echo no)" \
  "exit $extra_install_code; $extra_install"

# drop a skill we still own. the next run removes that directory.
# on the other checkout the owned path is a symlink; removal must unlink it
# and leave the directory it points at alone.
precious="$sandbox/precious"
mkdir -p "$precious"
printf 'precious\n' > "$precious/keep-me"
rm -rf "$linkrepo/.claude/skills/pstack-beta"
ln -s "$precious" "$linkrepo/.claude/skills/pstack-beta"
rm -rf "$plugins/pstack/skills/pstack-beta"
commit_repo "$plugins" "drop pstack-beta"
out4=$(run_install "$target" 2>"$sandbox/err4")
code4=$?
report "owned stale skill is removed" "$([ "$code4" = 0 ] && [ ! -e "$target/.claude/skills/pstack-beta" ] && echo yes || echo no)" "exit $code4; $(ls "$target/.claude/skills")"
report "exclude drops the removed skill" "$(grep -q 'pstack-beta' "$target/.git/info/exclude" && echo no || echo yes)" "$(cat "$target/.git/info/exclude")"
report "sibling skill stays" "$([ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" "shared missing"
status4=$(git -C "$target" status --porcelain)
report "status clean after stale removal" "$([ -z "$status4" ] && echo yes || echo no)" "$status4"
link_stale=$(run_install "$sandbox" "$linkrepo" 2>"$sandbox/link-stale.err")
link_stale_code=$?
report "owned symlink stale run exits 0" "$([ "$link_stale_code" = 0 ] && echo yes || echo no)" "exit $link_stale_code; $link_stale; $(cat "$sandbox/link-stale.err")"
report "owned symlink was unlinked" "$([ ! -L "$linkrepo/.claude/skills/pstack-beta" ] && [ ! -e "$linkrepo/.claude/skills/pstack-beta" ] && echo yes || echo no)" "$(ls -l "$linkrepo/.claude/skills")"
report "owned symlink target was not removed" \
  "$([ "$(cat "$precious/keep-me")" = "precious" ] && [ -d "$precious" ] && echo yes || echo no)" \
  "$(find "$precious" -printf '%p\n' 2>/dev/null)"
extra_out=$(run_install "$sandbox" "$extra" 2>"$sandbox/extra-stale.err")
extra_code=$?
report "stale skill keeps a user file" \
  "$([ "$extra_code" = 0 ] && [ "$(cat "$extra/.claude/skills/pstack-beta/USER.md")" = "user extra" ] && [ "$(cat "$extra/.claude/skills/pstack-beta/keep/mine.md")" = "keep" ] && [ ! -e "$extra/.claude/skills/pstack-beta/SKILL.md" ] && echo yes || echo no)" \
  "exit $extra_code; $(find "$extra/.claude/skills/pstack-beta" -printf '%p\n' 2>/dev/null); $extra_out"
extra_manifest=$(git -C "$extra" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "stale skill file leaves the manifest" \
  "$(grep -q 'pstack-beta/SKILL.md' "$extra_manifest" && echo no || echo yes)" \
  "$(cat "$extra_manifest")"

# no network, no cache: warn and exit 0, and do not touch the checkout.
offline_cache="$sandbox/empty-cache"
offline_target="$sandbox/offline-repo"
mkdir -p "$offline_target/.claude/skills/foo"
printf 'tracked foo\n' > "$offline_target/.claude/skills/foo/SKILL.md"
init_repo "$offline_target"
commit_repo "$offline_target" "init"
offline_out=$(
  cd "$sandbox"
  env \
    KRU_CLOUD_SKILLS_CACHE="$offline_cache" \
    KRU_CLOUD_SKILLS_KRU_URL="https://127.0.0.1:9/kru.git" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="https://127.0.0.1:9/plugins.git" \
    bash -s -- "$offline_target" < "$script" 2>"$sandbox/offline.err"
)
offline_code=$?
report "offline run exits 0" "$([ "$offline_code" = 0 ] && echo yes || echo no)" "exit $offline_code"
report "offline run warns" "$(grep -q 'cloud-skills:' "$sandbox/offline.err" && echo yes || echo no)" "$(cat "$sandbox/offline.err")"
report "offline run leaves the checkout alone" \
  "$([ "$(cat "$offline_target/.claude/skills/foo/SKILL.md")" = "tracked foo" ] && [ ! -e "$offline_target/.claude/skills/shared" ] && echo yes || echo no)" \
  "$(find "$offline_target/.claude" -type f)"

# one source missing and an empty cache: still exit 0, still no partial copy.
partial_cache="$sandbox/partial-cache"
partial_out=$(
  cd "$target"
  env \
    KRU_CLOUD_SKILLS_CACHE="$partial_cache" \
    KRU_CLOUD_SKILLS_KRU_URL="$kru" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="https://127.0.0.1:9/plugins.git" \
    bash -s -- "$offline_target" < "$script" 2>"$sandbox/partial.err"
)
partial_code=$?
report "git failure of one source exits 0" "$([ "$partial_code" = 0 ] && echo yes || echo no)" "exit $partial_code; $(cat "$sandbox/partial.err")"
report "a failed source does not partially install" \
  "$([ ! -e "$offline_target/.claude/skills/shared" ] && echo yes || echo no)" \
  "$(find "$offline_target/.claude" -type f)"

# a warm cache whose fetch fails is still a successful, idempotent install.
warm_err=$(
  cd "$target"
  env \
    KRU_CLOUD_SKILLS_CACHE="$cache" \
    KRU_CLOUD_SKILLS_KRU_URL="https://127.0.0.1:9/kru.git" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="https://127.0.0.1:9/plugins.git" \
    bash -s -- "$target" < "$script" 2>&1 >/dev/null
)
warm_code=$?
report "warm cache survives an offline fetch" \
  "$([ "$warm_code" = 0 ] && printf '%s\n' "$warm_err" | grep -q 'using the cached checkout' && [ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "exit $warm_code; $warm_err"

# no argument and no git toplevel: the fallback directory.
fallback="$sandbox/fallback-repo"
nowhere="$sandbox/not-a-repo"
mkdir -p "$nowhere"
init_repo "$fallback"
git -C "$fallback" commit -q --allow-empty -m init
fb_out=$(
  cd "$nowhere"
  env \
    KRU_CLOUD_SKILLS_CACHE="$cache" \
    KRU_CLOUD_SKILLS_KRU_URL="$kru" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
    KRU_CLOUD_SKILLS_FALLBACK="$fallback" \
    bash -s < "$script" 2>"$sandbox/fb.err"
)
fb_code=$?
report "fallback directory is used outside a git checkout" \
  "$([ "$fb_code" = 0 ] && [ "$(cat "$fallback/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "exit $fb_code; $fb_out; $(cat "$sandbox/fb.err")"

# the default fallback is the literal /workspace path, with the env var unset.
# a mount namespace puts a scratch repo there so the real checkout is not the
# target. GitHub-hosted runners reject unshare, so those cases skip there and
# still run where the namespace is allowed. the owned-path mount check needs
# the same namespace (tmpfs is a different device from its parent).
script_copy="$sandbox/cloud-skills.sh"
cp "$script" "$script_copy"
if unshare --user --map-root-user --mount true >/dev/null 2>&1; then
  fake_ws="$sandbox/workspace-mount"
  mkdir -p "$fake_ws"
  init_repo "$fake_ws"
  git -C "$fake_ws" commit -q --allow-empty -m init
  ws_out=$(
    unshare --user --map-root-user --mount bash -c '
      mount --bind "$1" /workspace
      cd /
      env -u KRU_CLOUD_SKILLS_FALLBACK -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
        KRU_CLOUD_SKILLS_CACHE="$2" \
        KRU_CLOUD_SKILLS_KRU_URL="$3" \
        KRU_CLOUD_SKILLS_PLUGINS_URL="$4" \
        bash -s < "$5"
    ' _ "$fake_ws" "$cache" "$kru" "$plugins" "$script_copy" 2>"$sandbox/ws.err"
  )
  ws_code=$?
  report "default /workspace fallback exits 0" "$([ "$ws_code" = 0 ] && echo yes || echo no)" "exit $ws_code; $(cat "$sandbox/ws.err"); $ws_out"
  report "default fallback installs into /workspace" \
    "$(printf '%s\n' "$ws_out" | grep -F -q -- '-> /workspace ' && [ "$(cat "$fake_ws/.claude/skills/shared/SKILL.md" 2>/dev/null)" = "kru shared" ] && echo yes || echo no)" \
    "$ws_out"
  report "default fallback does not write the real checkout" \
    "$([ ! -e "$repo/.claude" ] && echo yes || echo no)" "$(find "$repo/.claude" -printf '%p\n' 2>/dev/null)"

  mount_repo="$sandbox/mount-repo"
  mkdir -p "$mount_repo"
  init_repo "$mount_repo"
  git -C "$mount_repo" commit -q --allow-empty -m init
  mount_first=$(run_install "$sandbox" "$mount_repo" 2>"$sandbox/mount-first.err")
  mount_first_code=$?
  report "mount fixture installed" \
    "$([ "$mount_first_code" = 0 ] && [ -f "$mount_repo/.claude/skills/shared/SKILL.md" ] && echo yes || echo no)" \
    "exit $mount_first_code; $mount_first"
  mount_out=$(
    unshare --user --map-root-user --mount bash -c '
      mount -t tmpfs tmpfs "$1"
      printf "mount-marker\n" > "$1/marker"
      cat "$2" | env \
        KRU_CLOUD_SKILLS_CACHE="$3" \
        KRU_CLOUD_SKILLS_KRU_URL="$4" \
        KRU_CLOUD_SKILLS_PLUGINS_URL="$5" \
        bash -s -- "$6"
      code=$?
      printf "mount-marker-after:%s\n" "$(cat "$1/marker" 2>/dev/null || echo missing)"
      if [ -e "$1/SKILL.md" ]; then printf "skill-on-mount:yes\n"; else printf "skill-on-mount:no\n"; fi
      exit "$code"
    ' _ "$mount_repo/.claude/skills/shared" "$script" "$cache" "$kru" "$plugins" "$mount_repo" 2>"$sandbox/mount.err"
  )
  mount_code=$?
  report "owned mount point is not removed" \
    "$([ "$mount_code" = 0 ] && printf '%s\n' "$mount_out" | grep -qx 'mount-marker-after:mount-marker' && printf '%s\n' "$mount_out" | grep -qx 'skill-on-mount:no' && grep -q 'skipping mount point' "$sandbox/mount.err" && [ "$(cat "$mount_repo/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
    "exit $mount_code; $mount_out; $(cat "$sandbox/mount.err")"
else
  skip_case "/workspace fallback (unshare unavailable)"
  skip_case "default fallback installs into /workspace (unshare unavailable)"
  skip_case "default fallback does not write the real checkout (unshare unavailable)"
  skip_case "owned mount point is not removed (unshare unavailable)"
fi

# an explicit argument wins over the current directory.
other="$sandbox/other-repo"
mkdir -p "$other/.claude/skills/foo"
printf 'other foo\n' > "$other/.claude/skills/foo/SKILL.md"
init_repo "$other"
commit_repo "$other" "init"
arg_out=$(
  cd "$nowhere"
  env \
    KRU_CLOUD_SKILLS_CACHE="$cache" \
    KRU_CLOUD_SKILLS_KRU_URL="$kru" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
    bash -s -- "$other" < "$script"
)
report "argument selects the target" \
  "$([ "$(cat "$other/.claude/skills/foo/SKILL.md")" = "other foo" ] && [ "$(cat "$other/.claude/skills/shared/SKILL.md")" = "kru shared" ] && printf '%s' "$arg_out" | grep -F -q -- "-> $other " && echo yes || echo no)" \
  "$arg_out"
report "removes pass --one-file-system" "$(grep -q -- '--one-file-system' "$script" && echo yes || echo no)" "rm is missing --one-file-system"

# a fresh repository created at a path we already installed into has a new
# git dir, so the old manifest does not apply. a path-hashed cache file would
# still claim ownership; plant one and prove it is ignored.
reuse="$sandbox/reuse"
mkdir -p "$reuse"
init_repo "$reuse"
git -C "$reuse" commit -q --allow-empty -m init
reuse_first=$(run_install "$sandbox" "$reuse" 2>"$sandbox/reuse-first.err")
reuse_first_code=$?
reuse_manifest=$(git -C "$reuse" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "first checkout at a path records ownership in its git dir" \
  "$([ "$reuse_first_code" = 0 ] && grep -qx '.claude/skills/shared/SKILL.md' "$reuse_manifest" && echo yes || echo no)" \
  "exit $reuse_first_code; $(cat "$reuse_manifest" 2>/dev/null)"
rm -rf "$reuse"
mkdir -p "$reuse"
init_repo "$reuse"
git -C "$reuse" commit -q --allow-empty -m init
mkdir -p "$reuse/.claude/skills/shared"
printf 'user now\n' > "$reuse/.claude/skills/shared/SKILL.md"
mkdir -p "$cache/manifests"
printf '%s\n' "$reuse" '.claude/skills/shared/' '.claude/skills/shared/SKILL.md' > "$cache/manifests/planted"
reuse_out=$(run_install "$sandbox" "$reuse" 2>"$sandbox/reuse.err")
reuse_code=$?
reuse_manifest=$(git -C "$reuse" rev-parse --absolute-git-dir)/kru-cloud-skills.manifest
report "fresh repo at the same path does not inherit ownership" \
  "$([ "$reuse_code" = 0 ] && [ "$(cat "$reuse/.claude/skills/shared/SKILL.md")" = "user now" ] && ! grep -q 'skills/shared' "$reuse_manifest" && grep -q 'pre-existing untracked' "$sandbox/reuse.err" && echo yes || echo no)" \
  "exit $reuse_code; $(cat "$reuse/.claude/skills/shared/SKILL.md" 2>/dev/null); $(cat "$reuse_manifest" 2>/dev/null); $(cat "$sandbox/reuse.err"); $reuse_out"

# a target whose path contains a newline is refused. stripping the newline
# would install into the sibling directory instead.
nl_parent="$sandbox/nlparent"
mkdir -p "$nl_parent/repo"
init_repo "$nl_parent/repo"
git -C "$nl_parent/repo" commit -q --allow-empty -m init
nl_dir="$nl_parent/repo"$'\n'
mkdir -p -- "$nl_dir"
init_repo "$nl_dir"
git -C "$nl_dir" commit -q --allow-empty -m init
nl_out=$(run_install "$sandbox" "$nl_dir" 2>"$sandbox/nl.err")
nl_code=$?
report "newline target is refused" \
  "$([ "$nl_code" = 0 ] && grep -q 'newline' "$sandbox/nl.err" && [ ! -e "$nl_dir/.claude/skills/shared" ] && [ ! -e "$nl_parent/repo/.claude/skills/shared" ] && echo yes || echo no)" \
  "exit $nl_code; $(cat "$sandbox/nl.err"); $nl_out"

# an unclosed begin marker must not eat the lines that follow it.
exrepo="$sandbox/exclude-open"
mkdir -p "$exrepo"
init_repo "$exrepo"
git -C "$exrepo" commit -q --allow-empty -m init
printf '# kru-cloud-skills begin\nKEEPME\n' > "$exrepo/.git/info/exclude"
ex_out=$(run_install "$sandbox" "$exrepo" 2>"$sandbox/ex.err")
ex_code=$?
ex_file=$(cat "$exrepo/.git/info/exclude")
report "unclosed exclude begin keeps existing lines" \
  "$([ "$ex_code" = 0 ] && printf '%s\n' "$ex_file" | grep -qx 'KEEPME' && printf '%s\n' "$ex_file" | grep -qx '# kru-cloud-skills end' && grep -q 'begin marker without an end' "$sandbox/ex.err" && [ "$(cat "$exrepo/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "exit $ex_code; $ex_file; $(cat "$sandbox/ex.err"); $ex_out"

# info and info/exclude as symlinks are not written through.
precious_info="$sandbox/precious-info"
mkdir -p "$precious_info"
printf 'keep-info\n' > "$precious_info/marker"
inforepo="$sandbox/info-link"
mkdir -p "$inforepo"
init_repo "$inforepo"
git -C "$inforepo" commit -q --allow-empty -m init
rm -rf "$inforepo/.git/info"
ln -s "$precious_info" "$inforepo/.git/info"
info_out=$(run_install "$sandbox" "$inforepo" 2>"$sandbox/info.err")
info_code=$?
report "symlinked info dir is refused" \
  "$([ "$info_code" = 0 ] && grep -q 'refusing to follow symlink: info' "$sandbox/info.err" && [ "$(cat "$precious_info/marker")" = "keep-info" ] && [ ! -e "$precious_info/exclude" ] && [ ! -e "$inforepo/.claude/skills/shared" ] && echo yes || echo no)" \
  "exit $info_code; $(cat "$sandbox/info.err"); $(find "$precious_info" -printf '%p\n'); $info_out"
precious_exclude="$sandbox/precious-exclude"
printf 'original\n' > "$precious_exclude"
exlink="$sandbox/exclude-link"
mkdir -p "$exlink"
init_repo "$exlink"
git -C "$exlink" commit -q --allow-empty -m init
ln -sf "$precious_exclude" "$exlink/.git/info/exclude"
exlink_out=$(run_install "$sandbox" "$exlink" 2>"$sandbox/exlink.err")
exlink_code=$?
report "symlinked exclude file is refused" \
  "$([ "$exlink_code" = 0 ] && grep -q 'refusing to follow symlink: info/exclude' "$sandbox/exlink.err" && [ "$(cat "$precious_exclude")" = "original" ] && [ ! -e "$exlink/.claude/skills/shared" ] && echo yes || echo no)" \
  "exit $exlink_code; $(cat "$precious_exclude"); $(cat "$sandbox/exlink.err"); $exlink_out"

# a manifest line that climbs out of .claude is not deleted.
poison="$sandbox/poison"
mkdir -p "$poison"
init_repo "$poison"
git -C "$poison" commit -q --allow-empty -m init
printf 'safe\n' > "$poison/escaped"
poison_git=$(git -C "$poison" rev-parse --absolute-git-dir)
printf '%s\n' '.claude/skills/shared/../../escaped' > "$poison_git/kru-cloud-skills.manifest"
poison_out=$(run_install "$sandbox" "$poison" 2>"$sandbox/poison.err")
poison_code=$?
report "manifest path with .. is not removed" \
  "$([ "$poison_code" = 0 ] && [ "$(cat "$poison/escaped")" = "safe" ] && grep -q 'unexpected manifest path' "$sandbox/poison.err" && echo yes || echo no)" \
  "exit $poison_code; $(cat "$poison/escaped" 2>/dev/null); $(cat "$sandbox/poison.err"); $poison_out"

# cache directory is a symlink: unlink it, do not clone into its target.
precious_cache="$sandbox/precious-cache"
mkdir -p "$precious_cache"
printf 'cache-marker\n' > "$precious_cache/marker"
ln -s "$precious_cache" "$sandbox/link-cache"
link_cache_repo="$sandbox/link-cache-repo"
mkdir -p "$link_cache_repo"
init_repo "$link_cache_repo"
git -C "$link_cache_repo" commit -q --allow-empty -m init
link_cache_out=$(run_cached "$sandbox" "$sandbox/link-cache" "$link_cache_repo" 2>"$sandbox/link-cache.err")
link_cache_code=$?
report "symlink cache is not followed" \
  "$([ "$link_cache_code" = 0 ] && [ "$(cat "$precious_cache/marker")" = "cache-marker" ] && [ ! -e "$precious_cache/kru-cursor" ] && [ ! -L "$sandbox/link-cache" ] && [ -d "$sandbox/link-cache/kru-cursor" ] && [ "$(cat "$link_cache_repo/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "exit $link_cache_code; $(find "$precious_cache" -printf '%p\n'); $(cat "$sandbox/link-cache.err"); $link_cache_out"

# a cache repo that is a symlink is not reset. the real cache dir is deleted
# and cloned again; the symlink target keeps its dirty tree.
sym_cache="$sandbox/sym-cache"
mkdir -p "$sym_cache"
precious_repo="$sandbox/precious-repo"
mkdir -p "$precious_repo"
printf 'safe-content\n' > "$precious_repo/tracked.txt"
init_repo "$precious_repo"
commit_repo "$precious_repo" "precious"
printf 'dirty-content\n' > "$precious_repo/tracked.txt"
ln -s "$precious_repo" "$sym_cache/kru-cursor"
sym_repo="$sandbox/sym-repo"
mkdir -p "$sym_repo"
init_repo "$sym_repo"
git -C "$sym_repo" commit -q --allow-empty -m init
sym_out=$(run_cached "$sandbox" "$sym_cache" "$sym_repo" 2>"$sandbox/sym.err")
sym_code=$?
report "symlink cache repo is not reset" \
  "$([ "$sym_code" = 0 ] && [ "$(cat "$precious_repo/tracked.txt")" = "dirty-content" ] && [ ! -L "$sym_cache/kru-cursor" ] && [ -d "$sym_cache/kru-cursor/.git" ] && [ "$(cat "$sym_repo/.claude/skills/shared/SKILL.md")" = "kru shared" ] && grep -q 'failed checks' "$sandbox/sym.err" && echo yes || echo no)" \
  "exit $sym_code; $(cat "$precious_repo/tracked.txt" 2>/dev/null); $(cat "$sandbox/sym.err"); $sym_out"

# core.worktree set: do not reset that worktree. delete the real cache and reclone.
wt_cache="$sandbox/wt-cache"
wt_repo="$sandbox/wt-repo"
mkdir -p "$wt_repo"
init_repo "$wt_repo"
git -C "$wt_repo" commit -q --allow-empty -m init
wt_first=$(run_cached "$sandbox" "$wt_cache" "$wt_repo" 2>"$sandbox/wt-first.err")
wt_first_code=$?
precious_wt="$sandbox/precious-wt"
mkdir -p "$precious_wt"
printf 'do-not-reset\n' > "$precious_wt/marker"
git -C "$wt_cache/kru-cursor" config core.worktree "$precious_wt"
wt_out=$(run_cached "$sandbox" "$wt_cache" "$wt_repo" 2>"$sandbox/wt.err")
wt_code=$?
report "core.worktree cache repo is not reset" \
  "$([ "$wt_first_code" = 0 ] && [ "$wt_code" = 0 ] && [ "$(cat "$precious_wt/marker")" = "do-not-reset" ] && [ ! -e "$precious_wt/skills" ] && ! git -C "$wt_cache/kru-cursor" config --local --get core.worktree >/dev/null 2>&1 && [ "$(cat "$wt_repo/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "exit $wt_first_code/$wt_code; $(find "$precious_wt" -printf '%p\n' 2>/dev/null); $(cat "$sandbox/wt.err"); $wt_out; $wt_first"

# a gitfile whose git dir lives outside the cache is not reset either.
gf_cache="$sandbox/gf-cache"
mkdir -p "$gf_cache/kru-cursor"
outside_git="$sandbox/outside-git"
mkdir -p "$outside_git"
printf 'safe-content\n' > "$outside_git/tracked.txt"
init_repo "$outside_git"
commit_repo "$outside_git" "outside"
printf 'dirty-content\n' > "$outside_git/tracked.txt"
printf 'gitdir: %s\n' "$outside_git/.git" > "$gf_cache/kru-cursor/.git"
gf_repo="$sandbox/gf-repo"
mkdir -p "$gf_repo"
init_repo "$gf_repo"
git -C "$gf_repo" commit -q --allow-empty -m init
gf_out=$(run_cached "$sandbox" "$gf_cache" "$gf_repo" 2>"$sandbox/gf.err")
gf_code=$?
report "cache gitfile is not reset" \
  "$([ "$gf_code" = 0 ] && [ "$(cat "$outside_git/tracked.txt")" = "dirty-content" ] && [ -d "$gf_cache/kru-cursor/.git" ] && [ ! -L "$gf_cache/kru-cursor/.git" ] && [ "$(cat "$gf_repo/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" \
  "exit $gf_code; $(cat "$outside_git/tracked.txt" 2>/dev/null); $(cat "$sandbox/gf.err"); $gf_out"

printf 'cloud-skills tests: %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
