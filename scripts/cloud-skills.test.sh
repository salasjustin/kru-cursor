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
report() {
  local name=$1 ok=$2 detail=$3
  if [ "$ok" = yes ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$detail"
  fi
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
run_install() {
  local dir=$1
  shift
  (
    cd "$dir"
    # shellcheck disable=SC2086
    env \
      KRU_CLOUD_SKILLS_CACHE="$cache" \
      KRU_CLOUD_SKILLS_KRU_URL="$kru" \
      KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
      KRU_CLOUD_SKILLS_FALLBACK="${KRU_CLOUD_SKILLS_FALLBACK:-}" \
      bash -s -- "$@" < "$script"
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

status=$(git -C "$target" status --porcelain)
report "git status clean" "$([ -z "$status" ] && echo yes || echo no)" "$status"
report ".gitignore unchanged" "$([ "$(sha256sum "$target/.gitignore" | awk '{print $1}')" = "$gitignore_before" ] && echo yes || echo no)" "gitignore changed"
exclude=$(cat "$target/.git/info/exclude")
report "pre-existing exclude lines kept" "$(printf '%s\n' "$exclude" | grep -qx '# keep me' && printf '%s\n' "$exclude" | grep -qx '*.tmp' && echo yes || echo no)" "$exclude"
report "exclude lists a copied skill" "$(printf '%s\n' "$exclude" | grep -qx '.claude/skills/kru-alpha/' && echo yes || echo no)" "$exclude"
report "exclude does not list the tracked skill" "$(printf '%s\n' "$exclude" | grep -q '.claude/skills/foo' && echo no || echo yes)" "$exclude"
ignore_out=$(git -C "$target" check-ignore -v .claude/skills/kru-alpha/SKILL.md .claude/agents/helper.md)
report "exclude, not gitignore, hides copies" "$(printf '%s\n' "$ignore_out" | grep -q 'info/exclude' && ! printf '%s\n' "$ignore_out" | grep -q '.gitignore' && echo yes || echo no)" "$ignore_out"

manifest=$(find "$cache/manifests" -type f)
report "sparse clone skipped the other plugin" "$([ ! -e "$cache/plugins/other-plugin" ] && [ -f "$cache/plugins/pstack/skills/pstack-beta/SKILL.md" ] && [ -f "$cache/kru-cursor/skills/kru-alpha/SKILL.md" ] && echo yes || echo no)" "$(find "$cache" -type d -name other-plugin -o -name skills)"
report "one manifest file in the cache" "$([ "$(printf '%s\n' "$manifest" | wc -l | tr -d ' ')" = 1 ] && echo yes || echo no)" "$manifest"
report "manifest records the owned skill" "$(tail -n +2 "$manifest" | grep -qx '.claude/skills/shared/' && echo yes || echo no)" "$(cat "$manifest")"
report "manifest does not record the tracked skill" "$(grep -q 'foo' "$manifest" && echo no || echo yes)" "$(cat "$manifest")"

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

# drop a skill we still own. the next run removes that directory.
rm -rf "$plugins/pstack/skills/pstack-beta"
commit_repo "$plugins" "drop pstack-beta"
out4=$(run_install "$target" 2>"$sandbox/err4")
code4=$?
report "owned stale skill is removed" "$([ "$code4" = 0 ] && [ ! -e "$target/.claude/skills/pstack-beta" ] && echo yes || echo no)" "exit $code4; $(ls "$target/.claude/skills")"
report "exclude drops the removed skill" "$(grep -q 'pstack-beta' "$target/.git/info/exclude" && echo no || echo yes)" "$(cat "$target/.git/info/exclude")"
report "sibling skill stays" "$([ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" "shared missing"
status4=$(git -C "$target" status --porcelain)
report "status clean after stale removal" "$([ -z "$status4" ] && echo yes || echo no)" "$status4"

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
report "script names the cloud checkout as the default fallback" \
  "$(grep -q '/workspace' "$script" && echo yes || echo no)" "fallback path missing"

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

printf 'cloud-skills tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
