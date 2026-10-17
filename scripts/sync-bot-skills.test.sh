#!/bin/bash
# sync-bot-skills.sh: create, overwrite, skip a foreign owner, skip an
# unmarked folder, and a second run that changes nothing. a name that leaves
# the list is reported and left on disk. a skill directory that is itself a
# symlink is skipped. a symlink inside a source skill fails that skill. an
# extra whose path contains a symlink is not followed. a failed swap puts the
# parked tree back. a held lock exits non-zero and writes nothing. nothing
# outside the library changes. a live, dangling, or relative lock symlink is
# refused before it is opened. an extra named * is logged as a symlink.
# ownership is the exact synced-from line, so
# `owner: kru-other` and prose that mentions `owner: kru` are not kru.
# `-- -dir` takes a library path that starts with -. an unreadable directory,
# missing frontmatter, and a BOM are skipped.
# run: bash scripts/sync-bot-skills.test.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
sync=$root/scripts/sync-bot-skills.sh
sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT

pass=0
fail=0
report() {
  local name=$1 ok=$2 out=$3
  if $ok; then pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$name" "$out"
  fi
}

version=$(jq -r .version "$root/.cursor-plugin/plugin.json")
marker_for() {
  printf '<!-- synced-from: kru@%s skills/%s | owner: kru | edit the source, not this copy -->' "$version" "$1"
}
line_after_fm() {
  awk '/^---[[:space:]]*$/ { n++; if (n == 2) { getline; print; exit } }' "$1"
}
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }
# empty output means the tree outside the library is unchanged.
outside_diff() { diff -rq "$1" "$2" 2>&1 || true; }
seal() {
  rm -rf "$2"
  mkdir -p "$2"
  cp -a "$1"/. "$2"/
}

expected=(
  writing-for-agents
  brief
  grilling
  brainstorm
  copywriting
  copy-editing
  ux-copy
  diagnosing-bugs
  claude-code-delegation
  reliable-work
)

# --- the default list is the contract ---------------------------------------
got=$(grep -v '^[[:space:]]*#' "$root/scripts/bot-skills.txt" | grep -v '^[[:space:]]*$')
want=$(printf '%s\n' "${expected[@]}")
report "default list is the ten skills" "$([ "$got" = "$want" ] && echo true || echo false)" "got [$got]"

# --- create: default list into an empty library -----------------------------
lib=$sandbox/lib
out=$(bash "$sync" "$lib" 2>&1)
code=$?
report "create exits 0" "$([ "$code" = 0 ] && echo true || echo false)" "code $code $out"

create_ok=true
create_why=""
for name in "${expected[@]}"; do
  dest=$lib/$name
  src=$root/skills/$name
  if [ ! -f "$dest/SKILL.md" ]; then
    create_ok=false
    create_why="$name missing"
    break
  fi
  got_line=$(line_after_fm "$dest/SKILL.md")
  want_line=$(marker_for "$name")
  if [ "$got_line" != "$want_line" ]; then
    create_ok=false
    create_why="$name marker [$got_line]"
    break
  fi
  if [ "$(grep -c 'synced-from:' "$dest/SKILL.md")" != 1 ]; then
    create_ok=false
    create_why="$name marker count"
    break
  fi
  while IFS= read -r f; do
    rel=${f#"$src"/}
    if [ "$(basename "$f")" = SKILL.md ]; then
      stripped=$(awk 'index($0, "<!-- synced-from:") == 1 { next } { print }' "$dest/$rel")
      if [ "$stripped" != "$(cat "$f")" ]; then
        create_ok=false
        create_why="$name SKILL.md body drifted"
        break
      fi
    elif ! cmp -s "$f" "$dest/$rel"; then
      create_ok=false
      create_why="$name missing or changed $rel"
      break
    fi
  done < <(find "$src" -type f)
  $create_ok || break
  case "$out" in
    *"synced $name"*) ;;
    *) create_ok=false; create_why="log missing synced $name"; break ;;
  esac
done
report "create copies each skill and stamps the marker" "$create_ok" "$create_why"
report "create keeps a sibling file" \
  "$([ -f "$lib/writing-for-agents/CALIBRATION.md" ] && [ -f "$lib/diagnosing-bugs/scripts/hitl-loop.template.sh" ] && echo true || echo false)" \
  "sibling missing"

# --- idempotence: a second run matches the first ----------------------------
snap=$sandbox/snap
cp -a "$lib" "$snap"
out2=$(bash "$sync" "$lib" 2>&1)
code2=$?
diff_out=$(diff -rq "$snap" "$lib" || true)
report "second run exits 0 and changes nothing" \
  "$([ "$code2" = 0 ] && [ -z "$diff_out" ] && echo true || echo false)" \
  "code $code2 diff [$diff_out]"

# --- overwrite: a kru-owned copy takes the source again ---------------------
echo 'LOCAL EDIT' >> "$lib/writing-for-agents/SKILL.md"
echo 'keep me' > "$lib/writing-for-agents/local-note.md"
out3=$(bash "$sync" "$lib" 2>&1)
code3=$?
body=$(awk 'index($0, "<!-- synced-from:") == 1 { next } { print }' "$lib/writing-for-agents/SKILL.md")
src_body=$(cat "$root/skills/writing-for-agents/SKILL.md")
overwrite_ok=false
if [ "$code3" = 0 ] \
  && [ "$body" = "$src_body" ] \
  && [ "$(grep -c 'synced-from:' "$lib/writing-for-agents/SKILL.md")" = 1 ] \
  && grep -q 'keep me' "$lib/writing-for-agents/local-note.md" \
  && ! grep -q 'LOCAL EDIT' "$lib/writing-for-agents/SKILL.md"; then
  overwrite_ok=true
fi
report "overwrite replaces a kru-owned SKILL.md and keeps an extra file" "$overwrite_ok" "code $code3"

report "overwrite restores the skill the first run wrote" \
  "$(cmp -s "$snap/writing-for-agents/CALIBRATION.md" "$lib/writing-for-agents/CALIBRATION.md" && [ "$(line_after_fm "$lib/writing-for-agents/SKILL.md")" = "$(marker_for writing-for-agents)" ] && echo true || echo false)" \
  "sibling or marker drifted"

# --- a name that leaves the list is reported, not deleted -------------------
short=$sandbox/short.txt
printf 'writing-for-agents\n' > "$short"
out4=$(bash "$sync" "$lib" --list "$short" 2>&1)
code4=$?
drop_ok=true
drop_why=""
[ "$code4" = 0 ] || { drop_ok=false; drop_why="code $code4"; }
for name in "${expected[@]}"; do
  [ "$name" = writing-for-agents ] && continue
  [ -d "$lib/$name" ] || { drop_ok=false; drop_why="$name deleted"; break; }
  case "$out4" in
    *"dropped $name: not in the list, left in place"*) ;;
    *) drop_ok=false; drop_why="no drop line for $name"; break ;;
  esac
done
case "$out4" in
  *"dropped writing-for-agents"*) drop_ok=false; drop_why="listed skill reported dropped" ;;
esac
report "a skill dropped from the list is reported and kept" "$drop_ok" "$drop_why"

# --- skip-foreign and skip-unmarked -----------------------------------------
skip=$sandbox/skip
mkdir -p "$skip/brief" "$skip/grilling" "$skip/stranger" "$skip/old-skill"
cat > "$skip/brief/SKILL.md" << 'EOF'
---
name: brief
description: kept locally
---
FOREIGN BODY
<!-- owner: foreign -->
EOF
cat > "$skip/grilling/SKILL.md" << 'EOF'
---
name: grilling
description: kept locally
---
UNMARKED BODY
EOF
cat > "$skip/stranger/SKILL.md" << 'EOF'
---
name: stranger
description: not ours
---
STRANGER BODY
EOF
cat > "$skip/old-skill/SKILL.md" << EOF
---
name: old-skill
description: was synced
---
$(marker_for old-skill)
OLD BODY
EOF
brief_m=$(mtime "$skip/brief/SKILL.md")
grill_m=$(mtime "$skip/grilling/SKILL.md")
stranger_m=$(mtime "$skip/stranger/SKILL.md")
# mtime resolution is one second on some filesystems
sleep 1
skiplist=$sandbox/skip.txt
printf 'writing-for-agents\nbrief\ngrilling\n' > "$skiplist"
out5=$(bash "$sync" "$skip" --list "$skiplist" 2>&1)
code5=$?
report "skip run exits 0" "$([ "$code5" = 0 ] && echo true || echo false)" "code $code5 $out5"
report "skip-foreign leaves the folder untouched" \
  "$(grep -q 'FOREIGN BODY' "$skip/brief/SKILL.md" && ! grep -q 'synced-from:' "$skip/brief/SKILL.md" && [ "$(mtime "$skip/brief/SKILL.md")" = "$brief_m" ] && echo true || echo false)" \
  "brief changed"
report "skip-foreign is logged" \
  "$(case "$out5" in *"skipped brief: foreign owner (foreign)"*) echo true ;; *) echo false ;; esac)" \
  "$out5"
report "skip-unmarked leaves the folder untouched" \
  "$(grep -q 'UNMARKED BODY' "$skip/grilling/SKILL.md" && ! grep -q 'synced-from:' "$skip/grilling/SKILL.md" && [ "$(mtime "$skip/grilling/SKILL.md")" = "$grill_m" ] && echo true || echo false)" \
  "grilling changed"
report "skip-unmarked is logged" \
  "$(case "$out5" in *"skipped grilling: no owner marker"*) echo true ;; *) echo false ;; esac)" \
  "$out5"
report "an unmarked folder outside the list is left alone" \
  "$(grep -q 'STRANGER BODY' "$skip/stranger/SKILL.md" && [ "$(mtime "$skip/stranger/SKILL.md")" = "$stranger_m" ] && echo true || echo false)" \
  "stranger changed"
case "$out5" in
  *"dropped stranger"*|*"synced brief"*|*"synced grilling"*) stray=true ;;
  *) stray=false ;;
esac
report "skip does not sync a foreign or unmarked skill" "$([ "$stray" = false ] && echo true || echo false)" "$out5"
report "a kru-owned skill outside the list is reported and kept" \
  "$( [ -f "$skip/old-skill/SKILL.md" ] && grep -q 'OLD BODY' "$skip/old-skill/SKILL.md" && case "$out5" in *"dropped old-skill: not in the list, left in place"*) echo true ;; *) echo false ;; esac )" \
  "$out5"
report "skip still creates a missing listed skill" \
  "$([ -f "$skip/writing-for-agents/SKILL.md" ] && [ "$(line_after_fm "$skip/writing-for-agents/SKILL.md")" = "$(marker_for writing-for-agents)" ] && echo true || echo false)" \
  "writing-for-agents not created"

# --- symlinks: skip, write nothing, leave everything outside the library ----
one=$sandbox/one.txt
printf 'writing-for-agents\n' > "$one"

linkdir_out=$sandbox/linkdir-out
linkdir_lib=$sandbox/linkdir-lib
mkdir -p "$linkdir_out/skill" "$linkdir_lib"
echo sentinel > "$linkdir_out/sentinel.txt"
cat > "$linkdir_out/skill/SKILL.md" << EOF
---
name: writing-for-agents
description: outside
---
$(marker_for writing-for-agents)
LINKDIR CANARY
EOF
echo 'linkdir cal' > "$linkdir_out/skill/CALIBRATION.md"
ln -s "$linkdir_out/skill" "$linkdir_lib/writing-for-agents"
seal "$linkdir_out" "$sandbox/linkdir-out.snap"
linkdir_log=$(bash "$sync" "$linkdir_lib" --list "$one" 2>&1)
linkdir_code=$?
linkdir_ok=true
linkdir_why=""
linkdir_diff=$(outside_diff "$sandbox/linkdir-out.snap" "$linkdir_out")
if [ "$linkdir_code" != 0 ]; then
  linkdir_ok=false
  linkdir_why="code $linkdir_code [$linkdir_log]"
elif [ -n "$linkdir_diff" ]; then
  linkdir_ok=false
  linkdir_why="outside changed [$linkdir_diff]"
elif ! grep -q 'LINKDIR CANARY' "$linkdir_out/skill/SKILL.md" \
  || ! grep -q 'linkdir cal' "$linkdir_out/skill/CALIBRATION.md"; then
  linkdir_ok=false
  linkdir_why="canary overwritten"
elif [ ! -h "$linkdir_lib/writing-for-agents" ] || [ ! -L "$linkdir_lib/writing-for-agents" ]; then
  linkdir_ok=false
  linkdir_why="symlink replaced"
elif ! case "$linkdir_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  linkdir_ok=false
  linkdir_why="log [$linkdir_log]"
elif case "$linkdir_log" in *"synced writing-for-agents"*) true ;; *) false ;; esac; then
  linkdir_ok=false
  linkdir_why="synced through the link [$linkdir_log]"
fi
report "symlinked skill dir is skipped and nothing outside changes" "$linkdir_ok" "$linkdir_why"

linkmd_out=$sandbox/linkmd-out
linkmd_lib=$sandbox/linkmd-lib
mkdir -p "$linkmd_out" "$linkmd_lib/writing-for-agents"
echo sentinel > "$linkmd_out/sentinel.txt"
cat > "$linkmd_out/SKILL.md" << EOF
---
name: writing-for-agents
description: outside
---
$(marker_for writing-for-agents)
LINKMD CANARY
EOF
ln -s "$linkmd_out/SKILL.md" "$linkmd_lib/writing-for-agents/SKILL.md"
echo 'keep local' > "$linkmd_lib/writing-for-agents/local.txt"
seal "$linkmd_out" "$sandbox/linkmd-out.snap"
linkmd_log=$(bash "$sync" "$linkmd_lib" --list "$one" 2>&1)
linkmd_code=$?
linkmd_ok=true
linkmd_why=""
linkmd_diff=$(outside_diff "$sandbox/linkmd-out.snap" "$linkmd_out")
if [ "$linkmd_code" != 0 ]; then
  linkmd_ok=false
  linkmd_why="code $linkmd_code [$linkmd_log]"
elif [ -n "$linkmd_diff" ]; then
  linkmd_ok=false
  linkmd_why="outside changed [$linkmd_diff]"
elif ! grep -q 'LINKMD CANARY' "$linkmd_out/SKILL.md"; then
  linkmd_ok=false
  linkmd_why="linked SKILL.md overwritten"
elif [ -h "$linkmd_lib/writing-for-agents/SKILL.md" ] || [ -L "$linkmd_lib/writing-for-agents/SKILL.md" ]; then
  linkmd_ok=false
  linkmd_why="SKILL.md is still a symlink"
elif [ "$(line_after_fm "$linkmd_lib/writing-for-agents/SKILL.md")" != "$(marker_for writing-for-agents)" ]; then
  linkmd_ok=false
  linkmd_why="marker missing"
elif ! grep -q 'keep local' "$linkmd_lib/writing-for-agents/local.txt"; then
  linkmd_ok=false
  linkmd_why="local file changed"
elif ! case "$linkmd_log" in *"synced writing-for-agents"*) true ;; *) false ;; esac; then
  linkmd_ok=false
  linkmd_why="log [$linkmd_log]"
elif ! case "$linkmd_log" in *"skipped writing-for-agents: extra symlink SKILL.md"*) true ;; *) false ;; esac; then
  linkmd_ok=false
  linkmd_why="did not skip the symlinked extra [$linkmd_log]"
fi
report "symlinked SKILL.md is not followed and nothing outside changes" "$linkmd_ok" "$linkmd_why"

linksib_out=$sandbox/linksib-out
linksib_lib=$sandbox/linksib-lib
mkdir -p "$linksib_out" "$linksib_lib/writing-for-agents"
echo sentinel > "$linksib_out/sentinel.txt"
echo 'SIB CANARY' > "$linksib_out/CALIBRATION.md"
cat > "$linksib_lib/writing-for-agents/SKILL.md" << EOF
---
name: writing-for-agents
description: local
---
$(marker_for writing-for-agents)
SIB BODY CANARY
EOF
ln -s "$linksib_out/CALIBRATION.md" "$linksib_lib/writing-for-agents/CALIBRATION.md"
seal "$linksib_out" "$sandbox/linksib-out.snap"
linksib_log=$(bash "$sync" "$linksib_lib" --list "$one" 2>&1)
linksib_code=$?
linksib_ok=true
linksib_why=""
linksib_diff=$(outside_diff "$sandbox/linksib-out.snap" "$linksib_out")
if [ "$linksib_code" != 0 ]; then
  linksib_ok=false
  linksib_why="code $linksib_code [$linksib_log]"
elif [ -n "$linksib_diff" ]; then
  linksib_ok=false
  linksib_why="outside changed [$linksib_diff]"
elif ! grep -q 'SIB CANARY' "$linksib_out/CALIBRATION.md"; then
  linksib_ok=false
  linksib_why="linked sibling overwritten"
elif [ -h "$linksib_lib/writing-for-agents/CALIBRATION.md" ] \
  || [ -L "$linksib_lib/writing-for-agents/CALIBRATION.md" ]; then
  linksib_ok=false
  linksib_why="sibling is still a symlink"
elif grep -q 'SIB CANARY' "$linksib_lib/writing-for-agents/CALIBRATION.md"; then
  linksib_ok=false
  linksib_why="followed the sibling symlink"
elif ! cmp -s "$root/skills/writing-for-agents/CALIBRATION.md" "$linksib_lib/writing-for-agents/CALIBRATION.md"; then
  linksib_ok=false
  linksib_why="source sibling was not installed"
elif ! case "$linksib_log" in *"synced writing-for-agents"*) true ;; *) false ;; esac; then
  linksib_ok=false
  linksib_why="log [$linksib_log]"
elif ! case "$linksib_log" in *"skipped writing-for-agents: extra symlink CALIBRATION.md"*) true ;; *) false ;; esac; then
  linksib_ok=false
  linksib_why="did not skip the symlinked extra [$linksib_log]"
fi
report "symlinked sibling is not followed and nothing outside changes" "$linksib_ok" "$linksib_why"

dangle_out=$sandbox/dangle-out
dangle_lib=$sandbox/dangle-lib
mkdir -p "$dangle_out" "$dangle_lib"
echo sentinel > "$dangle_out/sentinel.txt"
ln -s "$dangle_out/missing-skill" "$dangle_lib/writing-for-agents"
seal "$dangle_out" "$sandbox/dangle-out.snap"
dangle_log=$(bash "$sync" "$dangle_lib" --list "$one" 2>&1)
dangle_code=$?
dangle_ok=true
dangle_why=""
dangle_diff=$(outside_diff "$sandbox/dangle-out.snap" "$dangle_out")
if [ "$dangle_code" != 0 ]; then
  dangle_ok=false
  dangle_why="code $dangle_code [$dangle_log]"
elif [ -n "$dangle_diff" ]; then
  dangle_ok=false
  dangle_why="outside changed [$dangle_diff]"
elif [ -e "$dangle_out/missing-skill" ] || [ -d "$dangle_out/missing-skill" ]; then
  dangle_ok=false
  dangle_why="dangling target was created"
elif [ ! -h "$dangle_lib/writing-for-agents" ]; then
  dangle_ok=false
  dangle_why="dangling link replaced"
elif ! case "$dangle_log" in *"skipped writing-for-agents: symlink"*) true ;; *) false ;; esac; then
  dangle_ok=false
  dangle_why="log [$dangle_log]"
fi
report "dangling link is skipped and nothing outside changes" "$dangle_ok" "$dangle_why"

danglein_out=$sandbox/danglein-out
danglein_lib=$sandbox/danglein-lib
mkdir -p "$danglein_out" "$danglein_lib/writing-for-agents"
echo sentinel > "$danglein_out/sentinel.txt"
cat > "$danglein_lib/writing-for-agents/SKILL.md" << EOF
---
name: writing-for-agents
description: local
---
$(marker_for writing-for-agents)
DANGLEIN BODY
EOF
ln -s "$danglein_out/missing-cal" "$danglein_lib/writing-for-agents/CALIBRATION.md"
seal "$danglein_out" "$sandbox/danglein-out.snap"
danglein_log=$(bash "$sync" "$danglein_lib" --list "$one" 2>&1)
danglein_code=$?
danglein_ok=true
danglein_why=""
danglein_diff=$(outside_diff "$sandbox/danglein-out.snap" "$danglein_out")
if [ "$danglein_code" != 0 ]; then
  danglein_ok=false
  danglein_why="code $danglein_code [$danglein_log]"
elif [ -n "$danglein_diff" ]; then
  danglein_ok=false
  danglein_why="outside changed [$danglein_diff]"
elif [ -e "$danglein_out/missing-cal" ] || [ -h "$danglein_out/missing-cal" ]; then
  danglein_ok=false
  danglein_why="dangling target was created"
elif [ -h "$danglein_lib/writing-for-agents/CALIBRATION.md" ] \
  || [ -L "$danglein_lib/writing-for-agents/CALIBRATION.md" ]; then
  danglein_ok=false
  danglein_why="dangling sibling was kept"
elif ! cmp -s "$root/skills/writing-for-agents/CALIBRATION.md" "$danglein_lib/writing-for-agents/CALIBRATION.md"; then
  danglein_ok=false
  danglein_why="source sibling was not installed"
elif ! case "$danglein_log" in *"synced writing-for-agents"*) true ;; *) false ;; esac; then
  danglein_ok=false
  danglein_why="log [$danglein_log]"
elif ! case "$danglein_log" in *"skipped writing-for-agents: extra symlink CALIBRATION.md"*) true ;; *) false ;; esac; then
  danglein_ok=false
  danglein_why="did not skip the dangling extra [$danglein_log]"
fi
report "dangling link inside a skill is not followed and nothing outside changes" "$danglein_ok" "$danglein_why"

# --- ownership is the exact marker line, not an unanchored owner: kru -------
own_out=$sandbox/own-out
own_lib=$sandbox/own-lib
mkdir -p "$own_out" "$own_lib/brief" "$own_lib/grilling" "$own_lib/stale-other" "$own_lib/stale-prose"
echo sentinel > "$own_out/sentinel.txt"
cat > "$own_lib/brief/SKILL.md" << 'EOF'
---
name: brief
description: kru-other
---
<!-- synced-from: kru@0.1.0 skills/kru-brief | owner: kru-other | edit the source, not this copy -->
KRU-OTHER BODY
EOF
cat > "$own_lib/grilling/SKILL.md" << 'EOF'
---
name: grilling
description: foreign prose
---
<!-- synced-from: other@1.0 skills/kru-grilling | owner: other | prose mentions owner: kru -->
FOREIGN PROSE BODY
EOF
cat > "$own_lib/stale-other/SKILL.md" << 'EOF'
---
name: stale-other
description: unlisted kru-other
---
<!-- synced-from: kru@0.1.0 skills/kru-stale-other | owner: kru-other | edit the source, not this copy -->
STALE OTHER BODY
EOF
cat > "$own_lib/stale-prose/SKILL.md" << 'EOF'
---
name: stale-prose
description: unlisted prose
---
<!-- synced-from: other@1.0 skills/kru-stale-prose | owner: other | prose mentions owner: kru -->
STALE PROSE BODY
EOF
own_list=$sandbox/own-list.txt
printf 'brief\ngrilling\n' > "$own_list"
seal "$own_out" "$sandbox/own-out.snap"
own_log=$(bash "$sync" "$own_lib" --list "$own_list" 2>&1)
own_code=$?
own_diff=$(outside_diff "$sandbox/own-out.snap" "$own_out")
other_ok=true
other_why=""
if [ "$own_code" != 0 ]; then
  other_ok=false
  other_why="code $own_code [$own_log]"
elif [ -n "$own_diff" ]; then
  other_ok=false
  other_why="outside changed [$own_diff]"
elif ! grep -q 'KRU-OTHER BODY' "$own_lib/brief/SKILL.md" \
  || ! grep -q 'owner: kru-other' "$own_lib/brief/SKILL.md"; then
  other_ok=false
  other_why="kru-other copy was rewritten"
elif ! grep -q 'STALE OTHER BODY' "$own_lib/stale-other/SKILL.md"; then
  other_ok=false
  other_why="unlisted kru-other copy was rewritten"
elif ! case "$own_log" in *"skipped brief: foreign owner (kru-other)"*) true ;; *) false ;; esac; then
  other_ok=false
  other_why="log [$own_log]"
elif case "$own_log" in *"synced brief"*|*"dropped stale-other"*) true ;; *) false ;; esac; then
  other_ok=false
  other_why="treated kru-other as kru [$own_log]"
fi
report "owner kru-other is not kru and nothing outside changes" "$other_ok" "$other_why"

prose_ok=true
prose_why=""
if [ "$own_code" != 0 ]; then
  prose_ok=false
  prose_why="code $own_code [$own_log]"
elif [ -n "$own_diff" ]; then
  prose_ok=false
  prose_why="outside changed [$own_diff]"
elif ! grep -q 'FOREIGN PROSE BODY' "$own_lib/grilling/SKILL.md" \
  || ! grep -q 'prose mentions owner: kru' "$own_lib/grilling/SKILL.md"; then
  prose_ok=false
  prose_why="foreign prose copy was rewritten"
elif ! grep -q 'STALE PROSE BODY' "$own_lib/stale-prose/SKILL.md"; then
  prose_ok=false
  prose_why="unlisted prose copy was rewritten"
elif ! case "$own_log" in *"skipped grilling: foreign owner (other)"*) true ;; *) false ;; esac; then
  prose_ok=false
  prose_why="log [$own_log]"
elif case "$own_log" in *"synced grilling"*|*"dropped stale-prose"*) true ;; *) false ;; esac; then
  prose_ok=false
  prose_why="treated prose owner: kru as kru [$own_log]"
fi
report "foreign marker with owner kru in prose is not kru and nothing outside changes" "$prose_ok" "$prose_why"

oldver_out=$sandbox/oldver-out
oldver_lib=$sandbox/oldver-lib
mkdir -p "$oldver_out" "$oldver_lib/brief"
echo sentinel > "$oldver_out/sentinel.txt"
cat > "$oldver_lib/brief/SKILL.md" << 'EOF'
---
name: brief
description: old version
---
<!-- synced-from: kru@0.0.1 skills/kru-brief | owner: kru | edit the source, not this copy -->
OLD VER BODY
EOF
oldver_list=$sandbox/oldver-list.txt
printf 'brief\n' > "$oldver_list"
seal "$oldver_out" "$sandbox/oldver-out.snap"
oldver_log=$(bash "$sync" "$oldver_lib" --list "$oldver_list" 2>&1)
oldver_code=$?
oldver_ok=true
oldver_why=""
oldver_diff=$(outside_diff "$sandbox/oldver-out.snap" "$oldver_out")
if [ "$oldver_code" != 0 ]; then
  oldver_ok=false
  oldver_why="code $oldver_code [$oldver_log]"
elif [ -n "$oldver_diff" ]; then
  oldver_ok=false
  oldver_why="outside changed [$oldver_diff]"
elif grep -q 'OLD VER BODY' "$oldver_lib/brief/SKILL.md" \
  || [ "$(line_after_fm "$oldver_lib/brief/SKILL.md")" != "$(marker_for brief)" ]; then
  oldver_ok=false
  oldver_why="older marker was not refreshed"
elif ! case "$oldver_log" in *"synced brief"*) true ;; *) false ;; esac; then
  oldver_ok=false
  oldver_why="log [$oldver_log]"
fi
report "older exact marker is still kru and nothing outside changes" "$oldver_ok" "$oldver_why"

# --- `--` takes the next argument as the library path -----------------------
dashroot=$sandbox/dashroot
mkdir -p "$dashroot/outside"
echo sentinel > "$dashroot/outside/sentinel.txt"
echo 'nested' > "$dashroot/outside/nested.txt"
seal "$dashroot/outside" "$sandbox/dash-out.snap"
dash_log=$(cd "$dashroot" && bash "$sync" -- -dir 2>&1)
dash_code=$?
dash_ok=true
dash_why=""
dash_diff=$(outside_diff "$sandbox/dash-out.snap" "$dashroot/outside")
dash_extras=$(cd "$dashroot" && find . -mindepth 1 -maxdepth 1 ! -name '-dir' ! -name 'outside' -print)
if [ "$dash_code" != 0 ]; then
  dash_ok=false
  dash_why="code $dash_code [$dash_log]"
elif [ -n "$dash_diff" ]; then
  dash_ok=false
  dash_why="outside changed [$dash_diff]"
elif [ ! -f "$dashroot/-dir/brief/SKILL.md" ] \
  || [ "$(line_after_fm "$dashroot/-dir/brief/SKILL.md")" != "$(marker_for brief)" ]; then
  dash_ok=false
  dash_why="library was not created at -dir"
elif [ -e "$root/-dir" ]; then
  dash_ok=false
  dash_why="wrote -dir outside the sandbox"
elif [ -n "$dash_extras" ]; then
  dash_ok=false
  dash_why="wrote outside -dir [$dash_extras]"
elif ! case "$dash_log" in *"synced brief"*) true ;; *) false ;; esac; then
  dash_ok=false
  dash_why="log [$dash_log]"
fi
report "-- -dir takes the library path and nothing outside changes" "$dash_ok" "$dash_why"

# --- failed swap, source symlink, symlinked extra, held lock ----------------
swap_out=$sandbox/swap-out
swap_lib=$sandbox/swap-lib
mkdir -p "$swap_out" "$swap_lib/brief"
echo sentinel > "$swap_out/sentinel.txt"
cat > "$swap_lib/brief/SKILL.md" << EOF
---
name: brief
description: local
---
$(marker_for brief)
ORIGINAL BODY
EOF
echo 'KEEP SIBLING' > "$swap_lib/brief/note.txt"
swap_list=$sandbox/swap-list.txt
printf 'brief\n' > "$swap_list"
swap_hook=$sandbox/swap-hook.sh
cat > "$swap_hook" << EOF
#!/bin/bash
dest=\$1
stage=\$3
parked=\$4
if [ -e "\$dest" ] || [ -h "\$dest" ]; then
  echo 'NOT PARKED' > "\$dest/SKILL.md"
fi
if [ ! -f "\$parked/SKILL.md" ] || ! grep -q 'ORIGINAL BODY' "\$parked/SKILL.md"; then
  echo 'PARK MISSING' > "$swap_out/park-missing"
fi
rm -rf -- "\$stage"
EOF
seal "$swap_out" "$sandbox/swap-out.snap"
swap_log=$(KRU_SYNC_BEFORE_REPLACE="$swap_hook" bash "$sync" "$swap_lib" --list "$swap_list" 2>&1)
swap_code=$?
swap_ok=true
swap_why=""
swap_diff=$(outside_diff "$sandbox/swap-out.snap" "$swap_out")
swap_left=$(find "$swap_lib" -name '.sync-old.*' -print)
if [ "$swap_code" = 0 ]; then
  swap_ok=false
  swap_why="code $swap_code [$swap_log]"
elif [ -n "$swap_diff" ]; then
  swap_ok=false
  swap_why="outside changed [$swap_diff]"
elif ! grep -q 'ORIGINAL BODY' "$swap_lib/brief/SKILL.md"; then
  swap_ok=false
  swap_why="original body was not restored"
elif ! grep -q 'KEEP SIBLING' "$swap_lib/brief/note.txt"; then
  swap_ok=false
  swap_why="sibling was not restored"
elif grep -q 'NOT PARKED' "$swap_lib/brief/SKILL.md"; then
  swap_ok=false
  swap_why="dest was still in place when the hook ran"
elif [ -n "$swap_left" ]; then
  swap_ok=false
  swap_why="left a parked tree [$swap_left]"
elif ! case "$swap_log" in *"error: brief: could not install"*) true ;; *) false ;; esac; then
  swap_ok=false
  swap_why="log [$swap_log]"
elif case "$swap_log" in *"synced brief"*) true ;; *) false ;; esac; then
  swap_ok=false
  swap_why="reported synced [$swap_log]"
fi
report "failed swap restores the original and nothing outside changes" "$swap_ok" "$swap_why"

srcsym_out=$sandbox/srcsym-out
srcsym_lib=$sandbox/srcsym-lib
srcsym_root=$sandbox/srcsym-root
mkdir -p "$srcsym_out" "$srcsym_lib/brief" "$srcsym_root/brief"
echo sentinel > "$srcsym_out/sentinel.txt"
echo 'SECRET BODY' > "$srcsym_out/target"
cat > "$srcsym_root/brief/SKILL.md" << 'EOF'
---
name: brief
description: source
---
SOURCE BODY
EOF
ln -s "$srcsym_out/target" "$srcsym_root/brief/extra"
cat > "$srcsym_lib/brief/SKILL.md" << 'EOF'
---
name: brief
description: foreign
---
FOREIGN SOURCE BODY
EOF
srcsym_list=$sandbox/srcsym-list.txt
printf 'brief\n' > "$srcsym_list"
seal "$srcsym_out" "$sandbox/srcsym-out.snap"
srcsym_log=$(KRU_SYNC_SKILL_ROOT="$srcsym_root" bash "$sync" "$srcsym_lib" --list "$srcsym_list" 2>&1)
srcsym_code=$?
srcsym_ok=true
srcsym_why=""
srcsym_diff=$(outside_diff "$sandbox/srcsym-out.snap" "$srcsym_out")
if [ "$srcsym_code" = 0 ]; then
  srcsym_ok=false
  srcsym_why="code $srcsym_code [$srcsym_log]"
elif [ -n "$srcsym_diff" ]; then
  srcsym_ok=false
  srcsym_why="outside changed [$srcsym_diff]"
elif ! grep -q 'SECRET BODY' "$srcsym_out/target"; then
  srcsym_ok=false
  srcsym_why="symlink target was overwritten"
elif ! grep -q 'FOREIGN SOURCE BODY' "$srcsym_lib/brief/SKILL.md"; then
  srcsym_ok=false
  srcsym_why="foreign content was overwritten"
elif [ -e "$srcsym_lib/brief/extra" ] || [ -h "$srcsym_lib/brief/extra" ]; then
  srcsym_ok=false
  srcsym_why="source symlink was installed"
elif ! case "$srcsym_log" in *"error: brief: source contains a symlink"*) true ;; *) false ;; esac; then
  srcsym_ok=false
  srcsym_why="log [$srcsym_log]"
elif case "$srcsym_log" in *"synced brief"*) true ;; *) false ;; esac; then
  srcsym_ok=false
  srcsym_why="synced a source that contains a symlink [$srcsym_log]"
fi
report "source symlink is refused and nothing outside changes" "$srcsym_ok" "$srcsym_why"

extra_out=$sandbox/extra-out
extra_lib=$sandbox/extra-lib
mkdir -p "$extra_out/via" "$extra_lib/brief/nest"
echo sentinel > "$extra_out/sentinel.txt"
echo 'SECRET BODY' > "$extra_out/secret"
echo 'VIA BODY' > "$extra_out/via/secret.txt"
cat > "$extra_lib/brief/SKILL.md" << EOF
---
name: brief
description: local
---
$(marker_for brief)
OLD EXTRA BODY
EOF
echo 'KEEP EXTRA' > "$extra_lib/brief/keep.txt"
echo 'KEEP NEST' > "$extra_lib/brief/nest/plain.txt"
ln -s "$extra_out/secret" "$extra_lib/brief/linked.txt"
ln -s "$extra_out/secret" "$extra_lib/brief/nest/link"
ln -s "$extra_out/via" "$extra_lib/brief/via"
extra_list=$sandbox/extra-list.txt
printf 'brief\n' > "$extra_list"
seal "$extra_out" "$sandbox/extra-out.snap"
extra_log=$(bash "$sync" "$extra_lib" --list "$extra_list" 2>&1)
extra_code=$?
extra_ok=true
extra_why=""
extra_diff=$(outside_diff "$sandbox/extra-out.snap" "$extra_out")
if [ "$extra_code" != 0 ]; then
  extra_ok=false
  extra_why="code $extra_code [$extra_log]"
elif [ -n "$extra_diff" ]; then
  extra_ok=false
  extra_why="outside changed [$extra_diff]"
elif ! grep -q 'SECRET BODY' "$extra_out/secret" || ! grep -q 'VIA BODY' "$extra_out/via/secret.txt"; then
  extra_ok=false
  extra_why="symlink target was overwritten"
elif ! grep -q 'KEEP EXTRA' "$extra_lib/brief/keep.txt"; then
  extra_ok=false
  extra_why="plain extra was dropped"
elif ! grep -q 'KEEP NEST' "$extra_lib/brief/nest/plain.txt"; then
  extra_ok=false
  extra_why="nested plain extra was dropped"
elif [ -e "$extra_lib/brief/linked.txt" ] || [ -h "$extra_lib/brief/linked.txt" ] \
  || [ -e "$extra_lib/brief/nest/link" ] || [ -h "$extra_lib/brief/nest/link" ] \
  || [ -e "$extra_lib/brief/via" ] || [ -h "$extra_lib/brief/via" ]; then
  extra_ok=false
  extra_why="symlinked extra was kept or followed"
elif grep -q 'OLD EXTRA BODY' "$extra_lib/brief/SKILL.md"; then
  extra_ok=false
  extra_why="skill was not refreshed"
elif ! case "$extra_log" in *"synced brief"*) true ;; *) false ;; esac; then
  extra_ok=false
  extra_why="log [$extra_log]"
elif ! case "$extra_log" in *"skipped brief: extra symlink linked.txt"*) true ;; *) false ;; esac \
  || ! case "$extra_log" in *"skipped brief: extra symlink nest/link"*) true ;; *) false ;; esac \
  || ! case "$extra_log" in *"skipped brief: extra symlink via"*) true ;; *) false ;; esac; then
  extra_ok=false
  extra_why="did not skip the symlinked extras [$extra_log]"
fi
report "symlinked extra is skipped and nothing outside changes" "$extra_ok" "$extra_why"

lock_out=$sandbox/lock-out
lock_lib=$sandbox/lock-lib
mkdir -p "$lock_out" "$lock_lib"
echo sentinel > "$lock_out/sentinel.txt"
echo 'LOCK SENTINEL' > "$lock_lib/sentinel.txt"
exec 8<>"$lock_lib/.sync.lock"
lock_held=false
if flock -n 8; then
  lock_held=true
fi
lock_list=$sandbox/lock-list.txt
printf 'brief\n' > "$lock_list"
seal "$lock_out" "$sandbox/lock-out.snap"
lock_log=$(bash "$sync" "$lock_lib" --list "$lock_list" 9>&- 2>&1)
lock_code=$?
exec 8>&-
lock_ok=true
lock_why=""
lock_diff=$(outside_diff "$sandbox/lock-out.snap" "$lock_out")
if [ "$lock_held" != true ]; then
  lock_ok=false
  lock_why="test could not take the lock"
elif [ "$lock_code" = 0 ]; then
  lock_ok=false
  lock_why="code $lock_code [$lock_log]"
elif [ -n "$lock_diff" ]; then
  lock_ok=false
  lock_why="outside changed [$lock_diff]"
elif ! grep -q 'LOCK SENTINEL' "$lock_lib/sentinel.txt"; then
  lock_ok=false
  lock_why="library sentinel changed"
elif [ -e "$lock_lib/brief" ] || [ -h "$lock_lib/brief" ]; then
  lock_ok=false
  lock_why="wrote a skill while the lock was held"
elif ! case "$lock_log" in *"error: sync already running"*) true ;; *) false ;; esac; then
  lock_ok=false
  lock_why="log [$lock_log]"
fi
report "held lock exits non-zero and writes nothing" "$lock_ok" "$lock_why"

locklink_list=$sandbox/locklink-list.txt
printf 'brief\n' > "$locklink_list"
for kind in live dangling relative; do
  ll_out=$sandbox/ll-$kind-out
  ll_lib=$sandbox/ll-$kind-lib
  mkdir -p "$ll_out" "$ll_lib"
  echo sentinel > "$ll_out/sentinel.txt"
  echo 'LOCKLINK SENTINEL' > "$ll_lib/sentinel.txt"
  case "$kind" in
    live)
      echo 'LIVE SECRET' > "$ll_out/secret"
      ln -s "$ll_out/secret" "$ll_lib/.sync.lock"
      ll_want=$ll_out/secret
      ;;
    dangling)
      ln -s "$ll_out/missing-lock" "$ll_lib/.sync.lock"
      ll_want=$ll_out/missing-lock
      ;;
    relative)
      echo 'REL SECRET' > "$ll_out/secret"
      ln -s ../ll-relative-out/secret "$ll_lib/.sync.lock"
      ll_want=../ll-relative-out/secret
      ;;
  esac
  seal "$ll_out" "$sandbox/ll-$kind-out.snap"
  ll_log=$(bash "$sync" "$ll_lib" --list "$locklink_list" 2>&1)
  ll_code=$?
  ll_ok=true
  ll_why=""
  ll_diff=$(outside_diff "$sandbox/ll-$kind-out.snap" "$ll_out")
  ll_target=$(readlink "$ll_lib/.sync.lock" 2>/dev/null || true)
  if [ "$ll_code" = 0 ]; then
    ll_ok=false
    ll_why="code $ll_code [$ll_log]"
  elif [ -n "$ll_diff" ]; then
    ll_ok=false
    ll_why="outside changed [$ll_diff]"
  elif [ ! -h "$ll_lib/.sync.lock" ] || [ ! -L "$ll_lib/.sync.lock" ]; then
    ll_ok=false
    ll_why="lock symlink was replaced"
  elif [ "$ll_target" != "$ll_want" ]; then
    ll_ok=false
    ll_why="link target changed [$ll_target]"
  elif [ -e "$ll_lib/brief" ] || [ -h "$ll_lib/brief" ]; then
    ll_ok=false
    ll_why="wrote a skill"
  elif ! grep -q 'LOCKLINK SENTINEL' "$ll_lib/sentinel.txt"; then
    ll_ok=false
    ll_why="library sentinel changed"
  elif ! grep -F -q 'error: lock file is a symlink' <<< "$ll_log"; then
    ll_ok=false
    ll_why="log [$ll_log]"
  elif [ "$kind" = live ] && ! grep -q 'LIVE SECRET' "$ll_out/secret"; then
    ll_ok=false
    ll_why="live target was overwritten"
  elif [ "$kind" = dangling ] && { [ -e "$ll_out/missing-lock" ] || [ -h "$ll_out/missing-lock" ]; }; then
    ll_ok=false
    ll_why="dangling target was created"
  elif [ "$kind" = relative ] && ! grep -q 'REL SECRET' "$ll_out/secret"; then
    ll_ok=false
    ll_why="relative target was overwritten"
  fi
  report "$kind lock symlink is refused and nothing is written" "$ll_ok" "$ll_why"
done

star_out=$sandbox/star-out
star_lib=$sandbox/star-lib
mkdir -p "$star_out" "$star_lib/brief"
echo sentinel > "$star_out/sentinel.txt"
echo 'STAR SECRET' > "$star_out/secret"
cat > "$star_lib/brief/SKILL.md" << EOF
---
name: brief
description: local
---
$(marker_for brief)
OLD STAR BODY
EOF
echo 'KEEP STAR' > "$star_lib/brief/keep.txt"
# quotes keep the asterisk literal: the extra's name is *
ln -s "$star_out/secret" "$star_lib/brief/*"
star_list=$sandbox/star-list.txt
printf 'brief\n' > "$star_list"
seal "$star_out" "$sandbox/star-out.snap"
star_log=$(bash "$sync" "$star_lib" --list "$star_list" 2>&1)
star_code=$?
star_ok=true
star_why=""
star_diff=$(outside_diff "$sandbox/star-out.snap" "$star_out")
if [ "$star_code" != 0 ]; then
  star_ok=false
  star_why="code $star_code [$star_log]"
elif [ -n "$star_diff" ]; then
  star_ok=false
  star_why="outside changed [$star_diff]"
elif ! grep -q 'STAR SECRET' "$star_out/secret"; then
  star_ok=false
  star_why="symlink target was overwritten"
elif ! grep -q 'KEEP STAR' "$star_lib/brief/keep.txt"; then
  star_ok=false
  star_why="plain extra was dropped"
elif [ -e "$star_lib/brief/*" ] || [ -h "$star_lib/brief/*" ]; then
  star_ok=false
  star_why="extra named * was kept or followed"
elif grep -q 'OLD STAR BODY' "$star_lib/brief/SKILL.md"; then
  star_ok=false
  star_why="skill was not refreshed"
elif ! grep -F -q 'skipped brief: extra symlink *' <<< "$star_log"; then
  star_ok=false
  star_why="did not log the extra named * [$star_log]"
elif ! case "$star_log" in *"synced brief"*) true ;; *) false ;; esac; then
  star_ok=false
  star_why="log [$star_log]"
fi
report "extra named * is logged as a symlink and nothing outside changes" "$star_ok" "$star_why"

unread_out=$sandbox/unread-out
unread_lib=$sandbox/unread-lib
mkdir -p "$unread_out" "$unread_lib/brief/hidden"
echo sentinel > "$unread_out/sentinel.txt"
echo 'SECRET BODY' > "$unread_out/secret"
ln -s "$unread_out/secret" "$unread_lib/brief/hidden/link"
cat > "$unread_lib/brief/SKILL.md" << EOF
---
name: brief
description: local
---
$(marker_for brief)
UNREAD BODY
EOF
chmod 333 "$unread_lib/brief/hidden"
unread_list=$sandbox/unread-list.txt
printf 'brief\n' > "$unread_list"
seal "$unread_out" "$sandbox/unread-out.snap"
unread_log=$(bash "$sync" "$unread_lib" --list "$unread_list" 2>&1)
unread_code=$?
chmod 755 "$unread_lib/brief/hidden" 2>/dev/null || true
unread_ok=true
unread_why=""
unread_diff=$(outside_diff "$sandbox/unread-out.snap" "$unread_out")
if [ "$unread_code" != 0 ]; then
  unread_ok=false
  unread_why="code $unread_code [$unread_log]"
elif [ -n "$unread_diff" ]; then
  unread_ok=false
  unread_why="outside changed [$unread_diff]"
elif ! grep -q 'SECRET BODY' "$unread_out/secret"; then
  unread_ok=false
  unread_why="foreign target was overwritten"
elif ! grep -q 'UNREAD BODY' "$unread_lib/brief/SKILL.md"; then
  unread_ok=false
  unread_why="skill was written despite the unreadable dir"
elif [ ! -h "$unread_lib/brief/hidden/link" ]; then
  unread_ok=false
  unread_why="hidden symlink was replaced"
elif ! case "$unread_log" in *"skipped brief: cannot scan for symlinks"*) true ;; *) false ;; esac; then
  unread_ok=false
  unread_why="log [$unread_log]"
elif case "$unread_log" in *"synced brief"*) true ;; *) false ;; esac; then
  unread_ok=false
  unread_why="synced an unscanned tree [$unread_log]"
fi
report "unreadable subdir skips the skill and foreign content survives" "$unread_ok" "$unread_why"

nofm_out=$sandbox/nofm-out
nofm_lib=$sandbox/nofm-lib
mkdir -p "$nofm_out" "$nofm_lib/brief"
echo sentinel > "$nofm_out/sentinel.txt"
cat > "$nofm_lib/brief/SKILL.md" << EOF
This copy has no frontmatter.
---
a horizontal rule
---
$(marker_for brief)
NOFM BODY
EOF
nofm_list=$sandbox/nofm-list.txt
printf 'brief\n' > "$nofm_list"
seal "$nofm_out" "$sandbox/nofm-out.snap"
nofm_log=$(bash "$sync" "$nofm_lib" --list "$nofm_list" 2>&1)
nofm_code=$?
nofm_ok=true
nofm_why=""
nofm_diff=$(outside_diff "$sandbox/nofm-out.snap" "$nofm_out")
if [ "$nofm_code" != 0 ]; then
  nofm_ok=false
  nofm_why="code $nofm_code [$nofm_log]"
elif [ -n "$nofm_diff" ]; then
  nofm_ok=false
  nofm_why="outside changed [$nofm_diff]"
elif ! grep -q 'NOFM BODY' "$nofm_lib/brief/SKILL.md" \
  || ! grep -q 'This copy has no frontmatter.' "$nofm_lib/brief/SKILL.md"; then
  nofm_ok=false
  nofm_why="foreign content was overwritten"
elif ! case "$nofm_log" in *"skipped brief: no owner marker"*) true ;; *) false ;; esac; then
  nofm_ok=false
  nofm_why="log [$nofm_log]"
elif case "$nofm_log" in *"synced brief"*) true ;; *) false ;; esac; then
  nofm_ok=false
  nofm_why="synced a file with no frontmatter [$nofm_log]"
fi
report "no frontmatter with two rules is unmarked and foreign content survives" "$nofm_ok" "$nofm_why"

bom_out=$sandbox/bom-out
bom_lib=$sandbox/bom-lib
mkdir -p "$bom_out" "$bom_lib/brief"
echo sentinel > "$bom_out/sentinel.txt"
{
  printf '\xef\xbb\xbf'
  cat << EOF
---
name: brief
description: bom
---
$(marker_for brief)
BOM BODY
EOF
} > "$bom_lib/brief/SKILL.md"
bom_list=$sandbox/bom-list.txt
printf 'brief\n' > "$bom_list"
seal "$bom_out" "$sandbox/bom-out.snap"
bom_log=$(bash "$sync" "$bom_lib" --list "$bom_list" 2>&1)
bom_code=$?
bom_ok=true
bom_why=""
bom_diff=$(outside_diff "$sandbox/bom-out.snap" "$bom_out")
bom_head=$(od -An -N 3 -t x1 "$bom_lib/brief/SKILL.md" | tr -d ' \n')
if [ "$bom_code" != 0 ]; then
  bom_ok=false
  bom_why="code $bom_code [$bom_log]"
elif [ -n "$bom_diff" ]; then
  bom_ok=false
  bom_why="outside changed [$bom_diff]"
elif ! grep -a -q 'BOM BODY' "$bom_lib/brief/SKILL.md"; then
  bom_ok=false
  bom_why="foreign content was overwritten"
elif [ "$bom_head" != "efbbbf" ]; then
  bom_ok=false
  bom_why="BOM was stripped [$bom_head]"
elif ! case "$bom_log" in *"skipped brief: no owner marker"*) true ;; *) false ;; esac; then
  bom_ok=false
  bom_why="log [$bom_log]"
elif case "$bom_log" in *"synced brief"*|*"foreign owner"*) true ;; *) false ;; esac; then
  bom_ok=false
  bom_why="did not treat the BOM as unmarked [$bom_log]"
fi
report "BOM skips the skill and foreign content survives" "$bom_ok" "$bom_why"

# usage
set +e
bash "$sync" >/dev/null 2>&1
usage_code=$?
set -e
report "missing library-dir exits 2" "$([ "$usage_code" = 2 ] && echo true || echo false)" "code $usage_code"

echo
echo "sync-bot-skills: $pass passed, $fail failed"
[ "$fail" = 0 ]
