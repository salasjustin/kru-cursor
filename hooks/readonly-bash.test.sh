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
  'rg -n foo src' 'rg --pretty foo' 'rg --pre-glob "*.gz" foo' 'date' 'cat x | jq .a' \
  'sort --check a.txt' 'sort -r -t, -k2 a.txt' \
  "sed -n '1,5p' a.txt" "sed 's/a/b/' a.txt" "sed -e 's/x/y/g' a.txt" "sed -E 's/we/x/' a.txt" "sed -n '/code/p' some.txt" \
  "yq '.a' f.yaml" 'yq -o json f.yaml' 'yq --indent 4 . f.yaml' \
  'date +%s' 'date +%F' 'date -u' 'date -d yesterday +%F' 'grep -rn getline src' "rg 'system(' src" 'yq -P e .a f.yaml' \
  'command -v jq' 'command -V git'; do
  expect read "$c"
done

for c in \
  "awk 'BEGIN { system(\"rm -rf build\") }'" \
  "awk '{ \"date\" | getline d; print d }' a.txt" \
  "awk 'BEGIN { while ((getline line < \"/etc/passwd\") > 0) print line }'" \
  'sort -o a.txt a.txt' 'sort -uo a.txt b.txt' 'sort --output=a.txt b.txt' 'sort -k1 -o out a' \
  "awk 'BEGIN{system (\"touch /tmp/x\")}'" "awk 'BEGIN{system	(\"touch /tmp/x\")}'" \
  'sort --out=x a' 'sort --o x a' 'sort --outp=x a' "sort '-o' x a" 'sort "--out=x" a' \
  'sort --compress-program=./x a' 'sort --co ./x a' \
  "sed 'w out' a.txt" "sed -n 's/a/b/w out' a.txt" "sed 's/a/b/gw out' a.txt" "sed '\$w out' a.txt" \
  "sed 's/a/b/e' a.txt" "sed '1e date' a.txt" "sed -n 'W out' a.txt" \
  "yq -i '.a = 1' f.yaml" "yq --inplace '.a = 1' f.yaml" "yq -Pi '.a = 1' f.yaml" "yq -s '.name' f.yaml" "yq --split-exp '.name' f.yaml" \
  'git diff --output=patch.diff' 'git log -p --output x' \
  'rg --pre ./run.sh foo' 'rg --pre=./run.sh foo' 'ls | rg --pre sh foo' \
  'date -s "2020-01-01"' 'date --set=tomorrow' 'date --se=tomorrow' "date '-s' x" 'date -us 12:00' 'date -s12:00' 'date 01011200' \
  "awk 'BEGIN { print 1; echo system(\"rm -rf build\") }'" "grep -c x f | awk '{ \"date\" | getline d }'" \
  'command rm -rf build' 'command -p rm x' \
  'rm -rf build' 'echo hi > notes.md' 'sed -i s/a/b/ f' 'git branch -D main'; do
  expect write "$c"
done

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
