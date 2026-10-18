#!/bin/bash
# preToolUse / beforeMCPExecution: default-deny outbound team connector MCP when hooks run.
# Repo `.cursor/hooks.json` calls this from the repo root; the plugin routes through cursor-hook.sh.
# Policy: scripts/cursor/mcp-outbound-allowlist.mjs. Kill switch: KRU_NO_MCP_OUTBOUND_GUARD=1.
# Cloud agents often skip MCP hooks (Oct 2026); rules/kru-lead.mdc covers that gap. Trace: KRU_HOOK_TRACE.
set -u

resolve_root() {
  if [ -n "${1:-}" ]; then
    printf '%s' "$1"
    return
  fi
  if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
    printf '%s' "$CURSOR_PROJECT_DIR"
    return
  fi
  local self_root
  self_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  printf '%s' "$self_root"
}

emit_allow() {
  printf '{"permission":"allow"}\n'
  exit 0
}

emit_deny() {
  local msg=${1:-kru: MCP outbound action denied}
  printf '%s\n' "$msg" >&2
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg m "$msg" '{permission: "deny", user_message: $m, agent_message: $m}'
  else
    # fail-closed when jq is missing; still emit valid JSON
    node -e 'const m=process.argv[1]; process.stdout.write(JSON.stringify({permission:"deny",user_message:m,agent_message:m})+"\n")' "$msg"
  fi
  exit 2
}

trace_line() {
  [ -n "${KRU_HOOK_TRACE:-}" ] || return 0
  local kind=$1 payload=$2
  command -v jq >/dev/null 2>&1 || return 0
  local line
  line=$(printf '%s' "$payload" | jq -c --arg k "$kind" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)" \
    '{ts:$ts, source:"mcp-outbound-guard", kind:$k, tool_name:(.tool_name//null), mcp_server_name:(.mcp_server_name//null), decision:(.decision//null)}' 2>/dev/null) || return 0
  printf '%s\n' "$line" >>"$KRU_HOOK_TRACE" 2>/dev/null || true
}

looks_like_mcp() {
  # when the classifier is missing, fail closed for MCP-shaped payloads only (tool_name / mcp_server_name — never body substrings)
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -e '
      def dyn_cursor: (.tool_name == "CallDynamicTool") and (.tool_input.namespace? == "cursor");
      if dyn_cursor then false
      elif .tool_name == "CallDynamicTool" then true
      elif (.tool_name // "") | test("^MCP:") then true
      elif (has("mcp_server_name") and (.mcp_server_name | type) == "string" and (.mcp_server_name | length) > 0) then
        (.mcp_server_name != "cursor")
      else false end
    ' >/dev/null 2>&1
    return $?
  fi
  node -e '
    let p; try { p = JSON.parse(process.argv[1]); } catch { process.exit(1); }
    const raw = String(p.tool_name ?? "");
    const ns = p.tool_input?.namespace;
    if (raw === "CallDynamicTool" && typeof ns === "string" && ns.toLowerCase() === "cursor") process.exit(1);
    if (raw === "CallDynamicTool") process.exit(0);
    if (/^MCP:/.test(raw)) {
      const server = (raw.replace(/^MCP:/i, "").split(/[:/]/)[0] ?? "").toLowerCase();
      process.exit(server === "cursor" ? 1 : 0);
    }
    const srv = p.mcp_server_name;
    if (typeof srv === "string" && srv.length > 0) process.exit(srv.toLowerCase() === "cursor" ? 1 : 0);
    process.exit(1);
  ' "$1"
}

root=$(resolve_root "${1:-}")
classify="$root/scripts/cursor/mcp-outbound-classify.mjs"

input=""
if [ ! -t 0 ]; then
  input=$(</dev/stdin) || input=""
fi
[ -n "$input" ] || emit_allow

if ! node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{JSON.parse(s);process.exit(0)}catch{process.exit(1)}})' <<<"$input"; then
  case "$input" in
    *'"tool_name":"CallDynamicTool"'*|*'"tool_name": "CallDynamicTool"'*|*'"tool_name":"MCP:'*|*'"tool_name": "MCP:'*)
      emit_deny "kru: MCP outbound guard received invalid JSON. Denying connector MCP."
      ;;
  esac
  emit_allow
fi

if [ "${KRU_NO_MCP_OUTBOUND_GUARD:-}" = "1" ]; then
  emit_allow
fi

is_mcp=0
if looks_like_mcp "$input"; then
  is_mcp=1
fi

if [ ! -f "$classify" ]; then
  if [ "$is_mcp" = 1 ]; then
    emit_deny "kru: MCP outbound guard is misconfigured (missing classifier at scripts/cursor/mcp-outbound-classify.mjs). Denying connector MCP until project hooks point at the repo copy."
  fi
  emit_allow
fi

if [ "$is_mcp" = 1 ]; then
  if command -v jq >/dev/null 2>&1; then
    if ! printf '%s' "$input" | jq -e 'type == "object"' >/dev/null 2>&1; then
      emit_deny "kru: MCP outbound guard received invalid JSON. Denying connector MCP."
    fi
  elif ! node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const v=JSON.parse(s);process.exit(typeof v==="object"&&v!==null&&!Array.isArray(v)?0:1)}catch{process.exit(1)}})' <<<"$input"; then
    emit_deny "kru: MCP outbound guard received invalid JSON. Denying connector MCP."
  fi
fi

errf=$(mktemp 2>/dev/null) || {
  if [ "$is_mcp" = 1 ]; then
    emit_deny "kru: MCP outbound guard could not run (mktemp failed). Denying connector MCP."
  fi
  emit_allow
}
out=$(printf '%s' "$input" | node "$classify" 2>"$errf")
code=$?
err=$(cat "$errf" 2>/dev/null)
rm -f "$errf"

if [ "$code" = 2 ]; then
  msg=${err:-kru: this cloud agent cannot run that connector MCP tool. Hand the exact tool name and arguments back to the PM bot to run outside the agent.}
  trace_line "deny" "$(printf '%s' "$input" | jq -c --arg d "deny" '. + {decision:$d}' 2>/dev/null || printf '{}')"
  emit_deny "$msg"
fi

if [ "$is_mcp" = 1 ] && [ "$code" != 0 ]; then
  msg=${err:-kru: MCP outbound guard classifier failed (exit $code). Denying connector MCP.}
  trace_line "deny" "$(printf '%s' "$input" | jq -c --arg d "deny" '. + {decision:$d}' 2>/dev/null || printf '{}')"
  emit_deny "$msg"
fi

trace_line "allow" "$(printf '%s' "$input" | jq -c --arg d "allow" '. + {decision:$d}' 2>/dev/null || printf '{}')"
emit_allow
