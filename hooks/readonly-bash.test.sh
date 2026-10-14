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

# the second review: sed reads only on an allowlist (its read flags, addresses,
# p d D q = G g h H N P x l y and s///[gpIiMm0-9]*), every tool's flags are read
# off the unquoted words, and awk -f / sed -f hide a program the line can't show
for c in "sed -n 's/[/]/x/gp' a" "sed -nE '/a/,/b/p' a" "sed -n '\$=' a" "sed -z 's/\\n/ /g' a" \
  "sed -n '1~2p' a" "sed 'y/abc/xyz/' a" 'sed --quiet 10q a' "sed -s -n '\$p' a b" 'sed -e p -e 2d a' \
  "sed -n '/x/I,+3p' a" "sed 's,a,b,2' a" "sed -n '/w/{p}' a" "sed -u -r 's/(e)/\\1/' a" 'sed --expr=p a' 'sed -n l a' "sed -n 'p' -- -i" \
  "awk -v x=1 '{print x}' a" "awk -F, '{print \$1}' a" "awk -F : '{print}' a" \
  'column --output-separator , a' 'column -t --output-width 80 a' 'date -Iseconds' 'date -I' 'date --iso-8601=seconds' \
  'date -d tuesday +%F' "date -ud 'next sunday'" \
  'uniq -c in' 'uniq -f 1 in' 'file a.txt' 'file -b a' 'base64 a' 'base64 -d a' \
  'find . -name x' 'find . -type f -print'; do
  expect read "$c"
done

for c in "sed '1eid' a" 'sed 1e\ id a' "sed \$'1e\\tid' a" 'sed --expression=e a' "sed -n 's/a/b/w/tmp/x' a" \
  "sed -n '1w/tmp/x' a" "sed -n 's/a/b/ew out' a" "sed \"1e id\" a" "sed 's/a/b/2w out' a" "sed '1!e id' a" \
  "sed \$'1{\\ne id\\n}' a" 'sed -f s.sed a' 'sed --file=s.sed a' 'sed --expr=e a' 'sed --fi=s.sed a' \
  'sed -n p a -i' 'sed -ni p a' 'sed --in-pl p a' "sed -e 'w x' a" "sed p -e 'w x' a" \
  "sed 's/x/y/m e' a" "sed -n '1W/tmp/x' a" 'sed -s -i p a' \
  "rg '--pre' ./p.sh foo" 'rg "--pre=./p.sh" foo' 'rg "$PRE" foo' \
  'awk -f prog.awk a' 'awk --file=prog.awk a' 'awk -fprog.awk a' "awk '-f' p a" "awk '@include \"x\"' a" \
  "yq '-i' '.a = 1' f.yaml" 'yq "--inplace" .a f' 'date "--set=x"' "command '-p' ls" \
  'cat <(rm -rf build)' 'uniq in out' 'xxd in out' 'file -C -m magic' 'base64 -i a -o b'; do
  expect write "$c"
done

# the third review: awk's system/getline/@name() check also runs on the
# quote-resolved words, segments split only where bash splits them, sed D reads,
# and find -ok/-okdir writes
for c in "sed -n '/x/{p;q}' a" "sed -n '1!G;h;\$p' a" "sed -n '\$!N;P;D' a" "awk '{print \$1; print \$2}' a" \
  "awk '{print \$1; print \$2}' a | sort -u" "grep -n 'a|b' f" "grep -E 'x;y' f | head -3" "echo 'a & b'" \
  "grep system f | awk '{print \$1}'" 'cat a && ls' "awk 'a || b' f" "find . -name 'a;b'"; do
  expect read "$c"
done

for c in "awk 'BEGIN{sys''tem(\"touch /tmp/pwn\")}'" "awk \$'BEGIN{\\x73ystem(\"touch /tmp/pwn\")}'" \
  "awk 'BEGIN{get''line x < \"f\"}'" "awk 'BEGIN{@f(\"id\")}'" \
  "awk 'BEGIN{f=\"sys\" \"tem\"; @f(\"touch /tmp/pwn\")}'" "awk 'BEGIN{f=\"x\"; @ f (\"y\")}'" \
  "awk \$'BEGIN{@\\x66(\"id\")}'" "awk '{print | \"sh\"}' a" "awk '{print > \"out\"}' a" \
  'find . -ok rm {} \;' 'find . -okdir rm {} \;' "find . '-ok' rm {} \;" \
  'ls; rm -rf build' 'cat a | sh' 'cat a & rm b' $'grep a f\nrm -rf build' \
  $'sort \\\n-o out a' $'grep -n foo \\\nbar' "ls 'unclosed" \
  $'ls #\'\ntouch /tmp/x #\'' \
  $'cat <<ls\necho \'\nls\ntouch /tmp/x\ncat <<ls\necho \'\nls'; do
  expect write "$c"
done

# the fourth review: $$' is a pid plus a single quote, not $'…', so the ;
# after it runs. find's -exec/-ok/-delete/-fprint/-fls and git's --output are
# read off the quote-resolved words. an unquoted $ other than $$ and $'…', and
# an unescaped $ inside "…", fails closed (${var@P} runs a command)
for c in 'echo $$' "echo \$'a;b'" "find . -printf '%f\\n'" 'git diff' 'git diff --output-separator=,' \
  'find . -name x -print' 'column --output-separator , a'; do
  expect read "$c"
done

for c in \
  $'echo $$\'\\\'; touch x; echo \'\\\'' \
  $'ls $$\'\\\' && touch x && ls \'\\\'' \
  $'echo $$$\'a\'; touch x' \
  $'echo $$$$\'\\\'; touch x; echo \'\\\'' \
  "git diff --out''put=/tmp/x" "git diff --out\$'put'=/tmp/x" 'git log -p --output x' \
  "find . -ex''ec touch x \\;" "find . -ex\\ec touch x \\;" "find . \$'-exec' touch x \\;" \
  "find . -\"exec\" touch x \\;" "find . -o''k touch x \\;" "find . -de''lete" \
  "find . -fp''rint /tmp/x" "find . -f''ls /tmp/x" "find . -fprint''f /tmp/x %f" \
  $'x=$\'\\044(touch x)\'; echo ${x@P}' \
  $'x=$\'\\044(touch x)\'; echo "${x@P}"' \
  $'echo $"a"; touch x'; do
  expect write "$c"
done

# a function definition whose name is a read verb, then a call of that name.
# quoted parens stay reads. the same pattern on the whole command (no ';') too.
for c in "grep '()' f" "sed -n '/()/p' a" "echo 'ls () ( touch x )'" 'find . \( -name x \)' 'ls -la'; do
  expect read "$c"
done

for c in 'ls () ( touch x ); ls' 'ls () ( touch x )' 'grep () ( touch x ); grep x' \
  'ls ( ) ( touch x ); ls' 'cat () ( touch x ); cat'; do
  expect write "$c"
done

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
