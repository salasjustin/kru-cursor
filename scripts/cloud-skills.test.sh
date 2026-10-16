#!/usr/bin/env bash
# cloud-skills.sh against local source repos, so verify.sh stays offline.
# the installer is fed on a pipe, the way curl | bash runs it.
# run: bash scripts/cloud-skills.test.sh
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

kru="$sandbox/src-kru"
plugins="$sandbox/src-plugins"
mkdir -p "$kru/skills/kru-alpha" "$kru/skills/shared" "$kru/skills/not-a-skill" "$kru/agents"
mkdir -p "$plugins/pstack/skills/pstack-beta" "$plugins/pstack/skills/shared" \
  "$plugins/pstack/skills/foo" "$plugins/pstack/agents" \
  "$plugins/other-plugin/skills/nope"
printf 'kru alpha\n' > "$kru/skills/kru-alpha/SKILL.md"
printf 'kru shared\n' > "$kru/skills/shared/SKILL.md"
printf 'not a skill\n' > "$kru/skills/not-a-skill/README.md"
printf '%s\n' '---' 'name: kru-lead' '---' 'kru lead' > "$kru/agents/lead.md"
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
    cat "$script" | env \
      HOME="$sandbox/home" \
      KRU_CLOUD_SKILLS_CACHE="$cache" \
      KRU_CLOUD_SKILLS_KRU_URL="$kru" \
      KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
      bash -s -- "$@"
  )
}

out=$(run_install "$sandbox" "$target" 2>"$sandbox/err1")
code=$?
report "piped run exits 0" "$([ "$code" = 0 ] && echo yes || echo no)" "exit $code; $(cat "$sandbox/err1")"
report "summary names the target" "$(printf '%s' "$out" | grep -q "cloud-skills: 3 skills, 2 agents -> $target" && echo yes || echo no)" "$out"
report "lists the kru seat" "$(printf '%s\n' "$out" | grep -qx 'registered subagents: kru-lead' && echo yes || echo no)" "$out"
report "kru skill copied" "$([ "$(cat "$target/.claude/skills/kru-alpha/SKILL.md")" = "kru alpha" ] && echo yes || echo no)" "missing kru-alpha"
report "pstack skill copied" "$([ "$(cat "$target/.claude/skills/pstack-beta/SKILL.md")" = "pstack beta" ] && echo yes || echo no)" "missing pstack-beta"
report "kru wins the shared skill" "$([ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared" ] && echo yes || echo no)" "$(cat "$target/.claude/skills/shared/SKILL.md" 2>/dev/null)"
report "kru wins the shared agent" "$([ "$(cat "$target/.claude/agents/lead.md")" = "$(cat "$kru/agents/lead.md")" ] && echo yes || echo no)" "$(cat "$target/.claude/agents/lead.md" 2>/dev/null)"
report "home agent installed" "$([ "$(cat "$sandbox/home/.cursor/agents/lead.md")" = "$(cat "$kru/agents/lead.md")" ] && echo yes || echo no)" "$(cat "$sandbox/home/.cursor/agents/lead.md" 2>/dev/null)"
report "home copy includes a tracked repo agent" "$([ "$(cat "$sandbox/home/.cursor/agents/kept.md")" = "pstack kept" ] && echo yes || echo no)" "$(cat "$sandbox/home/.cursor/agents/kept.md" 2>/dev/null)"
report "pstack agent copied" "$([ "$(cat "$target/.claude/agents/helper.md")" = "pstack helper" ] && echo yes || echo no)" "missing helper"
report "tracked skill skipped" "$([ "$(cat "$target/.claude/skills/foo/SKILL.md")" = "tracked foo" ] && echo yes || echo no)" "$(cat "$target/.claude/skills/foo/SKILL.md")"
report "tracked agent skipped" "$([ "$(cat "$target/.claude/agents/kept.md")" = "tracked kept" ] && echo yes || echo no)" "$(cat "$target/.claude/agents/kept.md")"
report "dir without SKILL.md skipped" "$([ ! -e "$target/.claude/skills/not-a-skill" ] && echo yes || echo no)" "not-a-skill was copied"
report "plugin outside pstack skipped" "$([ ! -e "$target/.claude/skills/nope" ] && [ ! -e "$cache/plugins/other-plugin" ] && echo yes || echo no)" "nope was copied"
report "non-agent file skipped" "$([ ! -e "$target/.claude/agents/notes.txt" ] && echo yes || echo no)" "notes.txt was copied"
report "no nested gitignore" "$([ ! -e "$target/.claude/skills/.gitignore" ] && [ ! -e "$target/.claude/agents/.gitignore" ] && echo yes || echo no)" "$(find "$target/.claude" -name .gitignore -print)"

status=$(git -C "$target" status --porcelain)
exclude=$(cat "$target/.git/info/exclude")
ignore=$(git -C "$target" check-ignore -v .claude/skills/shared/SKILL.md .claude/agents/helper.md || true)
report "git status clean" "$([ -z "$status" ] && echo yes || echo no)" "$status"
report ".gitignore unchanged" "$([ "$(sha256sum "$target/.gitignore" | awk '{print $1}')" = "$gitignore_before" ] && echo yes || echo no)" "gitignore changed"
report "pre-existing exclude lines kept" "$(printf '%s\n' "$exclude" | grep -qx '# keep me' && printf '%s\n' "$exclude" | grep -qx '*.tmp' && echo yes || echo no)" "$exclude"
report "exclude lists a copied skill and agent" "$(printf '%s\n' "$exclude" | grep -qx '.claude/skills/kru-alpha/' && printf '%s\n' "$exclude" | grep -qx '.claude/agents/helper.md' && echo yes || echo no)" "$exclude"
report "exclude does not list the tracked skill" "$(printf '%s\n' "$exclude" | grep -q '.claude/skills/foo' && echo no || echo yes)" "$exclude"
report "exclude block is marked" "$(printf '%s\n' "$exclude" | grep -qx '# kru-cloud-skills begin' && printf '%s\n' "$exclude" | grep -qx '# kru-cloud-skills end' && echo yes || echo no)" "$exclude"
report "info/exclude hides the copies" "$(printf '%s\n' "$ignore" | grep -q 'info/exclude' && echo yes || echo no)" "$ignore"

tree_hash() {
  (
    cd "$1" || exit 1
    find .claude -type f -print | sort | while IFS= read -r f; do sha256sum "$f"; done
    sha256sum .git/info/exclude
  ) | sha256sum | awk '{print $1}'
}
before=$(tree_hash "$target")
out2=$(run_install "$target/nested" 2>"$sandbox/err2")
code2=$?
after=$(tree_hash "$target")
status2=$(git -C "$target" status --porcelain)
report "second run exits 0" "$([ "$code2" = 0 ] && echo yes || echo no)" "exit $code2; $(cat "$sandbox/err2")"
report "second run is idempotent" "$([ "$before" = "$after" ] && echo yes || echo no)" "tree hash $before -> $after"
report "second run leaves git status clean" "$([ -z "$status2" ] && echo yes || echo no)" "$status2"
report "no-arg run from a subdir uses the toplevel" "$(printf '%s' "$out2" | grep -F -q -- "-> $target " && echo yes || echo no)" "$out2"

printf 'kru shared v2\n' > "$kru/skills/shared/SKILL.md"
commit_repo "$kru" "shared v2"
out_v2=$(run_install "$target" 2>"$sandbox/err-v2")
code_v2=$?
status_v2=$(git -C "$target" status --porcelain)
report "untracked installer copy is overwritten" \
  "$([ "$code_v2" = 0 ] && [ "$(cat "$target/.claude/skills/shared/SKILL.md")" = "kru shared v2" ] && [ -z "$status_v2" ] && echo yes || echo no)" \
  "exit $code_v2; status [$status_v2]; $(cat "$target/.claude/skills/shared/SKILL.md" 2>/dev/null)"

offline_cache="$sandbox/empty-cache"
offline_target="$sandbox/offline-repo"
mkdir -p "$offline_target/.claude/skills/foo"
printf 'tracked foo\n' > "$offline_target/.claude/skills/foo/SKILL.md"
init_repo "$offline_target"
commit_repo "$offline_target" "init"
offline_out=$(
  cd "$sandbox"
  cat "$script" | env \
    KRU_CLOUD_SKILLS_CACHE="$offline_cache" \
    KRU_CLOUD_SKILLS_KRU_URL="https://127.0.0.1:9/kru.git" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="https://127.0.0.1:9/plugins.git" \
    bash -s -- "$offline_target" 2>"$sandbox/offline.err"
)
offline_code=$?
report "offline run exits 0" "$([ "$offline_code" = 0 ] && echo yes || echo no)" "exit $offline_code; $offline_out"
report "offline run warns" "$(grep -q 'cloud-skills:' "$sandbox/offline.err" && echo yes || echo no)" "$(cat "$sandbox/offline.err")"
report "offline run leaves the checkout alone" \
  "$([ "$(cat "$offline_target/.claude/skills/foo/SKILL.md")" = "tracked foo" ] && [ ! -e "$offline_target/.claude/skills/shared" ] && echo yes || echo no)" \
  "$(find "$offline_target/.claude" -type f -print)"

shell_repo="$sandbox/shell-repo"
mkdir -p "$shell_repo"
init_repo "$shell_repo"
git -C "$shell_repo" commit -q --allow-empty -m init
shell_out=$(
  cd /tmp
  cat "$script" | env SHELLOPTS=errexit:pipefail:nounset \
    HOME="$sandbox/home" \
    KRU_CLOUD_SKILLS_CACHE="$cache" \
    KRU_CLOUD_SKILLS_KRU_URL="$kru" \
    KRU_CLOUD_SKILLS_PLUGINS_URL="$plugins" \
    bash -s -- "$shell_repo" 2>"$sandbox/shell.err"
)
shell_code=$?
shell_status=$(git -C "$shell_repo" status --porcelain)
report "piped SHELLOPTS run exits 0" \
  "$([ "$shell_code" = 0 ] && echo yes || echo no)" \
  "exit $shell_code; $(cat "$sandbox/shell.err"); $shell_out"
report "piped SHELLOPTS run copies a skill and stays clean" \
  "$([ "$(cat "$shell_repo/.claude/skills/shared/SKILL.md" 2>/dev/null)" = "kru shared v2" ] && [ -z "$shell_status" ] && echo yes || echo no)" \
  "status [$shell_status]; $shell_out"

printf '%s\n' '---' 'name: helper' '---' 'not a kru seat' > "$kru/agents/lead.md"
commit_repo "$kru" "no kru seat"
missing_out=$(run_install "$target" 2>"$sandbox/err-missing")
missing_code=$?
report "missing kru seat exits non-zero" "$([ "$missing_code" != 0 ] && echo yes || echo no)" "exit $missing_code; $missing_out"
report "missing kru seat names the failure" "$(grep -q 'no kru seat' "$sandbox/err-missing" && echo yes || echo no)" "$(cat "$sandbox/err-missing")"

printf 'cloud-skills tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
