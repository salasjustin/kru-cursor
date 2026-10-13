#!/bin/bash
# every hook in hooks/hooks.json, run the way cursor runs a plugin's hook: the
# command string from hooks.json with ${CURSOR_PLUGIN_ROOT} substituted (cursor
# does it at load) and also set in the env (cursor does that too), executed by
# a shell with the install dir as cwd (the workspace for stop/subagentStop),
# cursor-shaped json on stdin (cursor.com/docs/hooks → Reference, plus the
# fields cursor-agent 2026.10.01 adds: session_id, parent_tool_call_id). the
# matcher is tested the way cursor tests it — an unanchored regex against the
# tool name, or the subagent type. responses merge like cursor's: any deny wins.
#
# every permission response (preToolUse, subagentStart) must be valid json on
# every path, since cursor blocks the action on anything else.
#
# the plugin is copied into a sandbox HOME's ~/.cursor/plugins/local/kru-cursor,
# so the tree under test is the installed layout, not the checkout.
# run: bash scripts/cursor-hooks.test.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
command -v jq >/dev/null 2>&1 || { echo "cursor-hooks.test: jq is required" >&2; exit 1; }

sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" TMPDIR="$sandbox/tmp"
unset KRU_HOME KRU_NO_GATE KRU_NO_LEAD_GATE KRU_NO_AUDIT KRU_STORE_REPO KRU_PROJECT KRU_PROJECT_STORE KRU_CLOUD CURSOR_AGENT_SOCKET KRU_NO_STORE_SYNC
mkdir -p "$HOME" "$TMPDIR"
export KRU_HOOK_LOG="$sandbox/hooks.log"

plugin="$HOME/.cursor/plugins/local/kru-cursor"
mkdir -p "$plugin"
(cd "$repo" && git ls-files -co --exclude-standard -z | xargs -0 -I{} cp --parents {} "$plugin/") 2>/dev/null ||
  { echo "FAIL: copy the plugin into $plugin"; exit 1; }
work="$sandbox/acme-web"
mkdir -p "$work" && git -C "$work" init -q
hooks_json="$plugin/hooks/hooks.json"

pass=0 fail=0
check() {
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: %s\n' "$name"; [ -n "${resp:-}" ] && printf '  resp: %s\n' "$resp" | cut -c1-400; fi
}
not() { ! "$@"; }
has() { jq -e "$1" <<<"$resp" >/dev/null 2>&1; }

# fire <event> <payload> — runs every matching hook; sets $resp (the merged
# response) and records a malformed permission response as a failure
fire() {
  local event=$1 payload=$2 key cmds cwd out code merged='[]' bad=""
  case "$event" in
    preToolUse|postToolUse) key=$(jq -r '.tool_name // ""' <<<"$payload") ;;
    subagentStart|subagentStop) key=$(jq -r '.subagent_type // ""' <<<"$payload") ;;
    *) key="" ;;
  esac
  case "$event" in stop|subagentStop) cwd="$work" ;; *) cwd="$plugin" ;; esac
  payload=$(jq -c --arg ev "$event" --arg w "$work" '. + {hook_event_name: $ev, workspace_roots: [$w], cursor_version: "test"}' <<<"$payload")
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    local m cmd
    m=$(jq -r '.matcher // ""' <<<"$entry")
    if [ -n "$m" ] && [ "$m" != "*" ] && [ -n "$key" ] && ! [[ "$key" =~ $m ]]; then continue; fi
    # cursor skips a stop/subagentStop hook once loop_count reaches its
    # loop_limit (default 5; null = no limit)
    case "$event" in stop|subagentStop)
      jq -e --argjson p "$payload" '(if has("loop_limit") then .loop_limit else 5 end) as $l
        | $l != null and ($p.loop_count // 0) >= $l' <<<"$entry" >/dev/null 2>&1 && continue ;;
    esac
    cmd=$(jq -r '.command' <<<"$entry")
    cmd=${cmd//'${CURSOR_PLUGIN_ROOT}'/$plugin}
    out=$(cd "$cwd" && printf '%s' "$payload" | CURSOR_PLUGIN_ROOT="$plugin" CURSOR_PROJECT_DIR="$work" bash -c "$cmd" 2>/dev/null)
    code=$?
    case "$event" in
      preToolUse|subagentStart)
        if [ "$code" = 2 ]; then out='{"permission":"deny"}'
        elif ! jq -e '(.permission == "allow" or .permission == "deny")' <<<"$out" >/dev/null 2>&1; then
          bad="$bad [$cmd → exit $code: $out]"
        fi ;;
      *) jq -e 'type == "object"' <<<"$out" >/dev/null 2>&1 || bad="$bad [$cmd → exit $code: $out]" ;;
    esac
    merged=$(printf '%s\n%s\n' "$merged" "${out:-null}" | jq -cs '.[0] + [.[1]]' 2>/dev/null || printf '%s' "$merged")
  done < <(jq -c --arg ev "$event" '.hooks[$ev][]?' "$hooks_json")
  if [ -n "$bad" ]; then fail=$((fail + 1)); printf 'FAIL: %s response is not cursor-valid:%s\n' "$event" "$bad"; fi
  resp=$(jq -c 'map(select(type == "object")) |
    (if any(.[]; .permission == "deny") then {permission: "deny"} elif any(.[]; .permission == "allow") then {permission: "allow"} else {} end)
    + (map(.user_message // empty) | if length > 0 then {user_message: join("\n")} else {} end)
    + (map(.agent_message // empty) | if length > 0 then {agent_message: join("\n")} else {} end)
    + (map(.updated_input // empty) | if length > 0 then {updated_input: last} else {} end)
    + (map(.additional_context // empty) | if length > 0 then {additional_context: join("\n")} else {} end)
    + (map(.followup_message // empty) | if length > 0 then {followup_message: last} else {} end)
    + (map(select(has("continue")) | .continue) | if length > 0 then {continue: all} else {} end)' <<<"$merged")
}
tool() { # <conv> <tool_name> <tool_input-json> [extra-json]
  jq -nc --arg c "$1" --arg t "$2" --argjson i "$3" --argjson x "${4:-{\}}" --arg w "$work" \
    '{conversation_id: $c, session_id: $c, generation_id: "g", tool_name: $t, tool_input: $i, tool_use_id: "tu", cwd: $w, transcript_path: null} + $x'
}
prompt() { jq -nc --arg c "$1" --arg p "$2" '{conversation_id: $c, session_id: $c, prompt: $p, attachments: []}'; }

# --- the manifest's hooks are cursor's format ---------------------------------
check "hooks.json: version 1, flat entries, command strings" jq -e '.version == 1 and ([.hooks[][] | (has("hooks") | not) and (.command | type == "string")] | all)' "$hooks_json"
check "every command goes through the adapter by \${CURSOR_PLUGIN_ROOT}" jq -e '[.hooks[][] | .command | startswith("bash \"${CURSOR_PLUGIN_ROOT}/hooks/cursor-hook.sh\" ")] | all' "$hooks_json"

# --- session start: local (sessionStart) and cloud (first preToolUse) ----------
fire sessionStart "$(jq -nc '{session_id: "loc1", conversation_id: "loc1", is_background_agent: false, composer_mode: "agent"}')"
check "sessionStart: an unset repo gets the /kru-setup nudge" has '.additional_context | test("/kru-setup")'
fire preToolUse "$(tool loc1 Read '{"path":"README.md"}')"
check "sessionStart already ran: the first preToolUse adds nothing" not has '.additional_context'
check "a read before the lead loads is allowed" has '.permission == "allow"'
fire preToolUse "$(tool cloud1 Read '{"path":"README.md"}')"
check "cloud (no sessionStart): the first preToolUse carries the nudge" has '.additional_context | test("/kru-setup")'
check "…and allows the call" has '.permission == "allow"'
printf '<!-- kru v0.150.0 -->\n' > "$work/AGENTS.md"
fire preToolUse "$(tool cloud2 Read '{"path":"README.md"}')"
check "a repo with a sheet gets no nudge" not has '.additional_context'
rm -f "$work/AGENTS.md"

# --- require-lead ------------------------------------------------------------------
fire preToolUse "$(tool rl1 Write '{"path":"src/a.ts","contents":"x"}')"
check "require-lead: a write before the lead loads is denied" has '.permission == "deny" and (.agent_message | test("kru-lead"))'
fire preToolUse "$(tool rl1 Write '{"path":"src/a.ts","contents":"x"}')"
check "require-lead: once per conversation" has '.permission == "allow"'
fire preToolUse "$(tool rl2 Shell '{"command":"git status && ls -la","working_directory":"/x"}')"
check "require-lead: read-only shell passes" has '.permission == "allow"'
fire preToolUse "$(tool rl2 Read "{\"path\":\"$plugin/skills/kru-lead/SKILL.md\"}")"
fire preToolUse "$(tool rl2 Write '{"path":"src/a.ts","contents":"x"}')"
check "require-lead: reading the lead skill loads it" has '.permission == "allow"'
fire beforeSubmitPrompt "$(prompt rl3 '/kru-lead add a settings page')"
check "beforeSubmitPrompt answers {continue:true}" has '.continue == true'
fire preToolUse "$(tool rl3 Task '{"subagent_type":"kru-node-developer","prompt":"Build the `exportCommand` handler in src/cli.ts. inbox.md","description":"x"}')"
check "require-lead: /kru-lead typed loads it" not has '.agent_message // "" | test("lead contract")'
fire beforeSubmitPrompt "$(prompt rl4 '/kru-todo the login flash')"
fire preToolUse "$(tool rl4 Shell '{"command":"touch x"}')"
check "require-lead: a /kru-<command> run is exempt" has '.permission == "allow"'
fire preToolUse "$(tool rl5 Write '{"path":"a"}' '{"parent_tool_call_id":"tc-parent"}')"
check "require-lead: a subagent's call is not the lead's" has '.permission == "allow"'
touch_off() { mkdir -p "$HOME/.kru/lead-gate" && : > "$HOME/.kru/lead-gate/off"; }
touch_off; fire preToolUse "$(tool rl6 Write '{"path":"a"}')"
check "require-lead: the kill switch file" has '.permission == "allow"'
rm -f "$HOME/.kru/lead-gate/off"
for c in rl7 rl8; do fire preToolUse "$(tool $c Read "{\"path\":\"$plugin/skills/kru-lead/SKILL.md\"}")"; done

# --- check-handoff (preToolUse on Task) ------------------------------------------------
fire preToolUse "$(tool rl7 Task '{"subagent_type":"kru-node-developer","prompt":"Add a --json flag to the export command in src/cli.ts:42 and cover it.","description":"json flag"}')"
check "check-handoff: a coordinate is refused" has '.permission == "deny" and (.agent_message | test("coordinates"))'
fire preToolUse "$(tool rl7 Task '{"subagent_type":"kru-node-developer","prompt":"Add a --json flag to the export command (the `exportCommand` handler in src/cli.ts) and cover it with a test.","description":"json flag","model":"m1"}')"
check "check-handoff: a clean brief is allowed" has '.permission == "allow"'
check "…with the learnings channel supplied in updated_input" has '.updated_input.prompt | test("inbox.md")'
check "…keeping cursor's own tool_input keys" has '.updated_input.subagent_type == "kru-node-developer" and .updated_input.model == "m1" and .updated_input.description == "json flag"'
fire preToolUse "$(tool rl7 Task '{"subagent_type":{"custom":"kru-node-developer"},"prompt":"Fix src/cli.ts:10 now.","description":"x"}')"
check "check-handoff: an object-shaped subagent_type still reads as the seat" has '.permission == "deny"'
fire preToolUse "$(tool rl7 Task '{"subagent_type":"explore","prompt":"look at src/cli.ts:42","description":"x"}')"
check "check-handoff: a non-team subagent passes" has '.permission == "allow" and (has("updated_input") | not)'
fire preToolUse "$(tool rl7 Task '{"subagent_type":"kru-code-reviewer","prompt":"Review the signup diff. inbox.md","description":"signup"}')"
check "check-handoff: a readonly review seat gets no report path" not has '.updated_input.prompt // "" | test("kru-review")'
check "check-handoff: refusals reach the store's log" test -s "$HOME/.kru/refusals.jsonl"

# --- log-dispatch (postToolUse on Task) ---------------------------------------------------
fire postToolUse "$(tool rl8 Task '{"subagent_type":"kru-code-reviewer","prompt":"Review the diff.","description":"review"}' '{"tool_output":"{}","duration":10}')"
check "postToolUse answers an object" has 'type == "object"'
check "log-dispatch: the seat lands in the conversation's ledger" jq -e 'select(.seat == "code-reviewer" and .cwd == "acme-web")' "$HOME/.kru/audit/rl8.jsonl"
fire postToolUse "$(tool rl9 Task '{"subagent_type":"kru-dispatch-auditor","prompt":"x","description":"a"}')"
check "log-dispatch: the auditor's own dispatch is not logged" test ! -e "$HOME/.kru/audit/rl9.jsonl"

# --- log-return (subagentStop) ------------------------------------------------------------
# the subagent's own conversation id differs from the lead's; the ledger is the lead's
stopsub() { jq -nc --arg c "$1" --arg s "$2" --argjson n "$3" '{conversation_id: ("sub-" + $c), session_id: ("sub-" + $c), parent_conversation_id: $c, subagent_type: "kru-node-developer", status: "completed", task: "t", description: "d", summary: $s, loop_count: $n, modified_files: [], agent_transcript_path: null}'; }
fire subagentStop "$(stopsub rl8 'done' 0)"
check "log-return: a missing Return pass line is asked for once" has '.followup_message | test("Return pass")'
fire subagentStop "$(stopsub rl8 $'done\nReturn pass: re-read the diff, clean' 0)"
check "log-return: a stated line passes" not has '.followup_message'
fire subagentStop "$(stopsub rl8 'done' 1)"
check "log-return: the second miss is ledgered, not asked again" not has '.followup_message'
check "…as a return event" jq -e 'select(.event == "return" and .return_pass == false)' "$HOME/.kru/audit/rl8.jsonl"

# --- nudge-audit + store-sync (stop) ------------------------------------------------------
stop() { jq -nc --arg c "$1" --argjson n "$2" '{conversation_id: $c, session_id: $c, status: "completed", loop_count: $n}'; }
fire stop "$(stop rl8 0)"
check "nudge-audit: a ledger asks for the dispatch auditor" has '.followup_message | test("kru-dispatch-auditor")'
fire stop "$(stop rl8 1)"
check "nudge-audit: once per dispatch count" not has '.followup_message'
fire stop "$(stop nothing 0)"
check "stop with no ledger answers {}" has '. == {}'

# --- brainstorm-guard -----------------------------------------------------------------------
fire preToolUse "$(tool bs1 Read "{\"path\":\"$plugin/skills/kru-lead/SKILL.md\"}")"
fire beforeSubmitPrompt "$(prompt bs1 '/kru-brainstorm a referral program')"
fire preToolUse "$(tool bs1 Write '{"path":"notes.md"}')"
check "brainstorm-guard: a write is refused while the lock stands" has '.permission == "deny" and (.agent_message | test("brainstorm"))'
fire preToolUse "$(tool bs1 Shell '{"command":"ls -la"}')"
check "brainstorm-guard: read-only shell passes" has '.permission == "allow"'
fire preToolUse "$(tool bs1 Shell '{"command":"echo hi > notes.md"}')"
check "brainstorm-guard: a shell write is refused" has '.permission == "deny"'
fire preToolUse "$(tool bs1 Delete '{"path":"notes.md"}')"
check "brainstorm-guard: a delete is refused" has '.permission == "deny"'
# cursor tests a matcher as an unanchored regex: an unanchored `Write` would
# put the guards on any tool whose name contains it
fire preToolUse "$(tool bs1 WriteShellStdin '{"shellId":"s1","chars":"y"}')"
check "brainstorm-guard: WriteShellStdin is not the Write tool" has '.permission == "allow"'
fire beforeSubmitPrompt "$(prompt bs1 'go')"
fire preToolUse "$(tool bs1 Write '{"path":"notes.md"}')"
check "brainstorm-guard: the user's go lifts it" has '.permission == "allow"'
fire beforeSubmitPrompt "$(prompt bs1 '/kru-brainstorm round two')"
fire beforeSubmitPrompt "$(prompt bs1 '/kru-brief')"
fire preToolUse "$(tool bs1 Write '{"path":"notes.md"}')"
check "brainstorm-guard: /kru-brief lifts it too" has '.permission == "allow"'

# --- seat-guard (subagentStart + preToolUse on Write|Delete) -----------------------------------
sub() { jq -nc --arg c "$1" --arg t "$2" --arg id "$3" '{conversation_id: $c, session_id: $c, subagent_id: ("sa-" + $id), subagent_type: $t, task: "t", parent_conversation_id: $c, tool_call_id: $id, subagent_model: "m", is_parallel_worker: false}'; }
fire subagentStart "$(sub bs1 kru-planner tc-plan)"
check "subagentStart answers allow" has '.permission == "allow"'
fire subagentStart "$(sub bs1 kru-node-developer tc-node)"
fire preToolUse "$(tool sa-plan Write '{"path":"plan.md"}' '{"parent_tool_call_id":"tc-plan"}')"
check "seat-guard: planner is refused the Write tool" has '.permission == "deny" and (.agent_message | test("planner"))'
fire preToolUse "$(tool sa-plan Shell '{"command":"mkdir -p /tmp/x"}' '{"parent_tool_call_id":"tc-plan"}')"
check "seat-guard: planner keeps the shell" has '.permission == "allow"'
fire preToolUse "$(tool sa-plan WriteShellStdin '{"shellId":"s1","chars":"y"}' '{"parent_tool_call_id":"tc-plan"}')"
check "seat-guard: WriteShellStdin is not the Write tool" has '.permission == "allow"'
check "every tool matcher is anchored (or *)" jq -e '[.hooks[][] | select(has("matcher")) | .matcher | . == "*" or test("^\\^([A-Za-z][A-Za-z0-9:_-]*|\\([A-Za-z][A-Za-z0-9:_-]*(\\|[A-Za-z][A-Za-z0-9:_-]*)*\\))\\$$")] | all' "$hooks_json"
# verify-tree's anchoring check: a name list is exact only as ^Name$ or
# ^(A|B)$, and a matcher that doesn't compile matches every tool in cursor
for m in '*' '^Task$' '^(Shell|Write|Delete)$' '^MCP:acme$'; do
  check "verify-tree takes matcher $m" node "$repo/scripts/verify-tree.mjs" --matcher "$m"
done
for m in 'Write' 'Write$' '^Write' '^Write|Delete$' '^(Write$' '^Write)$' '^(Write|Delete' '^((Write)$' '^(|Write)$' '^(Write||Delete)$'; do
  check "verify-tree refuses matcher $m" not node "$repo/scripts/verify-tree.mjs" --matcher "$m"
done
fire preToolUse "$(tool sa-node Write '{"path":"src/a.ts"}' '{"parent_tool_call_id":"tc-node"}')"
check "seat-guard: a builder writes" has '.permission == "allow"'

# --- store-sync on a hung remote ------------------------------------------------------------------
# the first preToolUse waits on the store's clone; a remote that never answers
# has to give up inside the hook's 15s, and the call still goes through
mkdir -p "$sandbox/bin"
real_git=$(command -v git)
printf '#!/bin/bash\ncase " $* " in *" clone "*|*" pull "*) exec sleep 60 ;; esac\nexec "%s" "$@"\n' "$real_git" > "$sandbox/bin/git"
chmod +x "$sandbox/bin/git"
t0=$(date +%s)
PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store KRU_STORE_SYNC_TIMEOUT=2 fire preToolUse "$(tool hung1 Read '{"path":"README.md"}')"
t1=$(date +%s)
check "store-sync: a hung clone gives up inside the first-turn budget" test $((t1 - t0)) -lt 12
check "…and the tool call is allowed" has '.permission == "allow"'
resp=$(cd "$work" && printf '{}' | PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store KRU_STORE_SYNC_TIMEOUT=1 bash "$plugin/hooks/store-sync.sh" start "$plugin" 2>/dev/null)
check "…and says it timed out, not that the repo or sign-in is wrong" has '.systemMessage | test("not loaded; sync timed out after 1s")'
# the verdict comes from the budget, not git's words: a remote that prints first
# (ssh's banner, a helper's progress) and then hangs still reads as a timeout
printf '#!/bin/bash\ncase " $* " in *" clone "*) echo "ssh: connect to host github.com port 22" >&2; exec sleep 60 ;; esac\nexec "%s" "$@"\n' "$real_git" > "$sandbox/bin/git"
resp=$(cd "$work" && printf '{}' | PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store KRU_STORE_SYNC_TIMEOUT=1 bash "$plugin/hooks/store-sync.sh" start "$plugin" 2>/dev/null)
check "…even when git printed something before it hung" has '.systemMessage | test("not loaded; sync timed out after 1s")'
# the first pull gets the budget of the hook it runs in, unless the variable is set
printf '#!/bin/bash\ncase " $* " in *" clone "*) echo "$KRU_STORE_SYNC_TIMEOUT" >> "%s"; exit 1 ;; esac\nexec "%s" "$@"\n' "$sandbox/budget" "$real_git" > "$sandbox/bin/git"
PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store fire sessionStart "$(jq -nc '{session_id: "bud1", conversation_id: "bud1"}')"
PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store fire preToolUse "$(tool bud2 Read '{"path":"README.md"}')"
PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store KRU_STORE_SYNC_TIMEOUT=7 fire preToolUse "$(tool bud3 Read '{"path":"README.md"}')"
check "first-turn: 45s from sessionStart, 10s from the first tool call, an explicit value wins" test "$(tr '\n' ' ' < "$sandbox/budget")" = "45 10 7 "
# a budget that isn't a positive count of seconds falls back to the default
# (0 included), and 08 is eight rather than an octal error. a clone that fails
# at once is a failure, not a timeout
for v in abc 10s 08 -5 0; do
  resp=$(cd "$work" && printf '{}' | PATH="$sandbox/bin:$PATH" KRU_STORE_REPO=acme/store KRU_STORE_SYNC_TIMEOUT=$v bash "$plugin/hooks/store-sync.sh" start "$plugin" 2>"$sandbox/budget.err")
  check "store-sync: KRU_STORE_SYNC_TIMEOUT=$v is not an arithmetic error" test ! -s "$sandbox/budget.err"
  check "…and a clone that fails at once doesn't read as a timeout ($v)" has '.systemMessage | test("sync failed")'
done
# the stop path's push, pull and push share one budget (30s stop hook), and a
# call that hangs in a child — ssh, a remote helper — still ends on time:
# the child holds the output pipe, so killing git alone would leave it waiting
git init -q --bare "$sandbox/store.git"
git clone -q "$sandbox/store.git" "$sandbox/store-home" 2>/dev/null
git -C "$sandbox/store-home" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m seed
git -C "$sandbox/store-home" push -q origin HEAD 2>/dev/null
git -C "$sandbox/store-home" config user.name t && git -C "$sandbox/store-home" config user.email t@example.com
echo note > "$sandbox/store-home/inbox.md"
printf '#!/bin/bash\ncase " $* " in *" push "*|*" pull "*) sleep 20 & wait; exit 1 ;; esac\nexec "%s" "$@"\n' "$real_git" > "$sandbox/bin/git"
t0=$(date +%s)
PATH="$sandbox/bin:$PATH" KRU_STORE_REPO="$sandbox/store.git" KRU_HOME="$sandbox/store-home" KRU_STORE_SYNC_TIMEOUT=3 fire stop "$(stop hung2 0)"
t1=$(date +%s)
check "store-sync: a hung push, pull and push end inside one budget" test $((t1 - t0)) -lt 6
check "…and the note is committed locally" test "$(git -C "$sandbox/store-home" rev-list --count '@{u}..HEAD')" = 1

# --- adapter hardening --------------------------------------------------------------------------------
{ printf 'Build the `exportCommand` handler in src/cli.ts. '; head -c 160000 /dev/zero | tr '\0' 'a'; } > "$sandbox/big.txt"
fire preToolUse "$(jq -nc --rawfile p "$sandbox/big.txt" --arg w "$work" '{conversation_id: "rl7", session_id: "rl7", tool_name: "Task", cwd: $w,
  tool_input: {subagent_type: "kru-node-developer", prompt: $p, description: "big"}}')"
check "a 160 KB brief keeps its rewrite (no argv limit)" has '.permission == "allow" and (.updated_input.prompt | test("inbox.md"))'
# another user's planted dir: state is refused, the gate fails open
mkdir -p "$TMPDIR/kru-cursor-$(id -u)" && ln -s "$sandbox/elsewhere" "$TMPDIR/kru-cursor-$(id -u)/evil1"
fire beforeSubmitPrompt "$(prompt evil1 '/kru-brainstorm x')"
check "a symlinked conversation dir is never written through" test ! -e "$sandbox/elsewhere"
fire preToolUse "$(tool evil1 Write '{"path":"a"}')"
check "…and the gates fail open there" has '.permission == "allow"'

# --- fail open ------------------------------------------------------------------------------------
resp=$(cd "$plugin" && printf 'not json' | bash "$plugin/hooks/cursor-hook.sh" preToolUse require-lead.sh)
check "adapter: garbage in is an allow, as valid json" has '.permission == "allow"'
resp=$(cd "$plugin" && printf '{}' | bash "$plugin/hooks/cursor-hook.sh" preToolUse no-such-hook.sh)
check "adapter: a missing hook is an allow" has '.permission == "allow"'
resp=$(cd "$plugin" && printf '{}' | bash "$plugin/hooks/cursor-hook.sh" stop no-such-hook.sh)
check "adapter: a non-permission event answers {}" has '. == {}'

# --- the marker ------------------------------------------------------------------------------------
check "every call left a line in KRU_HOOK_LOG" test "$(wc -l < "$KRU_HOOK_LOG")" -gt 40
check "no hook exited outside 0/2" bash -c '! jq -e "select(.exit != 0 and .exit != 2)" "$1" >/dev/null' _ "$KRU_HOOK_LOG"

printf '%d passed, %d failed (%d hook calls)\n' "$pass" "$fail" "$(wc -l < "$KRU_HOOK_LOG" | tr -d ' ')"
[ "$fail" -eq 0 ]
