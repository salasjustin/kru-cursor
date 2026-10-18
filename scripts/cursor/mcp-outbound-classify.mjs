#!/usr/bin/env node
// stdin: one preToolUse or beforeMCPExecution JSON object. exit 0 = allow; exit 2 = deny (message on stderr).
import { appendFileSync, readFileSync } from "node:fs"
import { classifyMcpTool, extractMcpToolId, isMcpShapedPayload } from "./mcp-outbound-allowlist.mjs"

function trace(entry) {
  const path = process.env.KRU_HOOK_TRACE
  if (!path) return
  try {
    appendFileSync(path, `${JSON.stringify(entry)}\n`)
  } catch {
    // ignore trace failures
  }
}

if (process.env.KRU_NO_MCP_OUTBOUND_GUARD === "1") process.exit(0)

let payload
try {
  payload = JSON.parse(readFileSync(0, "utf8"))
} catch {
  process.exit(0)
}

const tool = extractMcpToolId(payload)
if (!tool) {
  if (isMcpShapedPayload(payload)) {
    process.stderr.write(
      "kru: MCP outbound guard could not identify connector tool. Denying connector MCP.\n",
    )
    process.exit(2)
  }
  process.exit(0)
}

const decision = classifyMcpTool(tool)
trace({
  ts: new Date().toISOString(),
  source: "mcp-outbound-classify",
  tool_id: tool.id,
  stem: tool.stem,
  action: decision.action,
  rule: decision.action === "deny" ? decision.rule : undefined,
})

if (decision.action === "deny") {
  process.stderr.write(decision.reason + "\n")
  process.exit(2)
}
process.exit(0)
