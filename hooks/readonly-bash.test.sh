#!/bin/bash
# table tests for hooks/readonly-bash.sh, the read-only test the shell gates
# share (require-lead, brainstorm-guard). the port rewrites part of it (the
# verbs that write on a flag — scripts/port.mjs), so these cover the ported
# file. run: bash hooks/readonly-bash.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/readonly-bash.sh"

pass=0 fail=0
expect() { # <read|write> <command>
  local got=write
  kru_readonly_bash "$2" && got=read
  if [ "$got" = "$1" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: want %s, got %s: %s\n' "$1" "$got" "$2"; fi
}

for c in 'ls -la' 'git status' 'grep -rn foo src | head -5' 'git log --oneline -3' 'git log --pretty=oneline' \
  "awk '{print \$1}' a.txt" 'sort a.txt' 'sort -u -k2 a.txt' 'sort -rn a.txt | uniq -c' \
  'rg -n foo src' 'rg --pretty foo' 'rg --pre-glob "*.gz" foo' 'date' 'cat x | jq .a'; do
  expect read "$c"
done

for c in \
  "awk 'BEGIN { system(\"rm -rf build\") }'" \
  "awk '{ \"date\" | getline d; print d }' a.txt" \
  "awk 'BEGIN { while ((getline line < \"/etc/passwd\") > 0) print line }'" \
  'sort -o a.txt a.txt' 'sort -uo a.txt b.txt' 'sort --output=a.txt b.txt' 'sort -k1 -o out a' \
  'git diff --output=patch.diff' 'git log -p --output x' \
  'rg --pre ./run.sh foo' 'rg --pre=./run.sh foo' 'ls | rg --pre sh foo' \
  'date -s "2020-01-01"' 'date --set=tomorrow' 'date +%s' \
  'rm -rf build' 'echo hi > notes.md' 'sed -i s/a/b/ f' 'git branch -D main'; do
  expect write "$c"
done

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
