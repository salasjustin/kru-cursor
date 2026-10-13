#!/bin/bash
# the live half of scripts/verify.sh: a real cursor-agent, signed in, loads this
# checkout as a plugin in a throwaway git repo and runs one headless turn. it
# passes when the plugin's hooks fired (KRU_HOOK_LOG has their lines) and the
# agent can see the kru rule and skills it was handed.
# local only — it spends a request. needs a signed-in cli (`cursor-agent status`)
# or CURSOR_API_KEY; it never logs in for you.
#
# run: bash scripts/cursor-smoke.sh
# env: KRU_AGENT_BIN (default: cursor-agent on PATH, else ~/.local/bin/cursor-agent)
#      SMOKE_MODEL  (optional --model for the turn)
#      SMOKE_KEEP=1 keeps the sandbox for a look afterwards
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
agent=${KRU_AGENT_BIN:-$(command -v cursor-agent || echo "$HOME/.local/bin/cursor-agent")}
[ -x "$agent" ] || { echo "smoke: no cursor-agent at $agent (curl https://cursor.com/install -fsS | bash)" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "smoke: jq is required" >&2; exit 2; }
if [ -z "${CURSOR_API_KEY:-}" ] && "$agent" status 2>&1 | grep -qi 'not logged in'; then
  echo "smoke: cursor-agent is not signed in — run 'cursor-agent login' (or set CURSOR_API_KEY), then re-run" >&2
  exit 2
fi

sandbox=$(cd "$(mktemp -d)" && pwd -P)
[ -n "${SMOKE_KEEP:-}" ] && echo "smoke: sandbox kept at $sandbox" || trap 'rm -rf "$sandbox"' EXIT
# the plugin as a copy, the way ~/.cursor/plugins/local holds one
plugin="$sandbox/kru-cursor"
mkdir -p "$plugin" && (cd "$repo" && git ls-files -co --exclude-standard -z | xargs -0 -I{} cp --parents {} "$plugin/")
work="$sandbox/acme-web"
mkdir -p "$work" && git -C "$work" init -q && printf '# acme-web\n' > "$work/README.md"
export KRU_HOOK_LOG="$sandbox/hooks.log" KRU_HOME="$sandbox/store"

pass=0 fail=0
check() {
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); printf 'ok   %s\n' "$name"; else fail=$((fail + 1)); printf 'FAIL %s\n' "$name"; fi
}

prompt='Without editing anything: 1) run `ls` in the shell, 2) name the always-on rule from the kru-cursor plugin that tells you what to load before building, 3) name the kru skill it points at and the subagent name for the kru code reviewer. Answer in three short lines.'
out=$(cd "$work" && timeout 300 "$agent" -p "$prompt" --print --trust --output-format text \
  --plugin-dir "$plugin" ${SMOKE_MODEL:+--model "$SMOKE_MODEL"} 2>&1)
code=$?
printf '%s\n' "$out" | tail -n 20

check "the headless turn exited 0" test "$code" -eq 0
check "a kru hook fired (KRU_HOOK_LOG)" test -s "$KRU_HOOK_LOG"
check "preToolUse ran through the adapter" grep -q '"event":"preToolUse"' "$KRU_HOOK_LOG"
check "every hook exited 0 or 2" bash -c '! jq -e "select(.exit != 0 and .exit != 2)" "$1"' _ "$KRU_HOOK_LOG"
check "the agent saw the kru-lead skill" grep -q 'kru-lead' <<<"$out"
check "the agent saw a kru seat" grep -q 'kru-code-reviewer' <<<"$out"
[ -s "$KRU_HOOK_LOG" ] && { echo "hook calls:"; jq -r '"  \(.event) \(.script) exit \(.exit)"' "$KRU_HOOK_LOG" | sort | uniq -c; }

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
