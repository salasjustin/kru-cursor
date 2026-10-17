#!/usr/bin/env node
// stdin: one preToolUse JSON object. exit 0 = allow; exit 2 = deny (message on stderr).
import { readFileSync } from "node:fs"
import { classifyMcpTool, extractMcpToolId } from "./mcp-outbound-denylist.mjs"

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
if (decision.action === "deny") {
  process.stderr.write(decision.reason + "\n")
  process.exit(2)
}
process.exit(0)
