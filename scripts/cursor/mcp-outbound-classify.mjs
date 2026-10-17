#!/usr/bin/env node
// stdin: one preToolUse or beforeMCPExecution JSON object. exit 0 = allow; exit 2 = deny (message on stderr).
import { appendFileSync, readFileSync } from "node:fs"
import { classifyMcpTool, extractMcpToolId } from "./mcp-outbound-denylist.mjs"

const TRACE = process.env.KRU_HOOK_TRACE || "/tmp/kru-hook-trace.log"

function trace(entry) {
  try {
    appendFileSync(TRACE, `${JSON.stringify(entry)}\n`)
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
if (!tool) process.exit(0)

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
