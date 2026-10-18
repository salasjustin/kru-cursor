// Single source of truth: which MCP tool names cloud agents may call (default deny).
// Only reads, drafts, Linear save_issue, and the cursor namespace pass; everything else is denied.

/** @typedef {{ id: string, stem: string }} ToolId */

export const DENY_MESSAGE =
  "kru: this cloud agent cannot run that connector MCP tool. Hand the exact tool name and arguments back to the PM bot to run outside the agent. Only reads, drafts, and Linear save_issue are allowed through team connectors."

/**
 * @param {unknown} payload cursor preToolUse JSON (native or cursor-hook normalized)
 * @returns {ToolId | null} null when this is not an MCP / dynamic MCP tool call
 */
export function extractMcpToolId(payload) {
  if (!payload || typeof payload !== "object") return null
  const raw = String(payload.cursor_tool_name ?? payload.tool_name ?? "")
  if (raw === "CallDynamicTool") {
    const input = payload.tool_input
    if (!input || typeof input !== "object") return null
    const ns = input.namespace
    const tool = input.toolName
    if (typeof ns === "string" && ns.toLowerCase() === "cursor") return null
    if (typeof ns === "string" && typeof tool === "string" && ns && tool) {
      const id = `${ns}/${tool}`
      return { id: id.toLowerCase(), stem: tool.toLowerCase() }
    }
    return null
  }
  if (payload.mcp_server_name && payload.tool_name && !/^MCP:/i.test(raw)) {
    const server = String(payload.mcp_server_name)
    if (server.toLowerCase() === "cursor") return null
    const tool = String(payload.tool_name)
    const id = `${server}/${tool}`
    return { id: id.toLowerCase(), stem: tool.toLowerCase() }
  }
  if (/^MCP:/i.test(raw)) {
    const rest = raw.replace(/^MCP:/i, "")
    const server = (rest.split(/[:/]/)[0] ?? "").toLowerCase()
    if (server === "cursor") return null
    const stem = (rest.split(/[:/]/).pop() ?? rest).toLowerCase()
    return { id: rest.toLowerCase(), stem }
  }
  if (/^mcp/i.test(raw)) return { id: raw.toLowerCase(), stem: raw.toLowerCase() }
  return null
}

/** Exact tool stems always allowed (in addition to prefix/suffix rules). */
export const ALLOW_STEMS = new Set([
  "create_draft",
  "update_draft",
  "get_draft",
  "list_drafts",
  "slack_send_message_draft",
  "save_issue",
  "read_document",
  "find_text",
  "query-docs",
  "extract_images",
  "check_dependency_vulnerabilities",
  "semantic_issue_similarity_search",
  "github_support_docs_search",
  "projects_get",
  "projects_list",
  "actions_get",
  "actions_list",
  "ui_get",
  "resolve-library-id",
])

/** Stem prefixes for read-only connector tools. */
export const ALLOW_STEM_PREFIXES = [
  "get_",
  "list_",
  "search_",
  "read_",
  "query_",
  "find_",
  "fetch_",
  "slack_read_",
  "slack_search_",
  "slack_list_",
  "slack_get_",
]

/** Stems denied even when they would match an allow rule (upload handshakes, draft delete). */
export const DENY_STEMS = new Set([
  "delete_draft",
  "slack_get_file_upload_url",
  "prepare_attachment_upload",
  "mark_all_notifications_read",
  "resolve_diff_thread",
])

/**
 * @param {ToolId} tool
 * @returns {{ action: "allow" } | { action: "deny", reason: string, rule: string }}
 */
export function classifyMcpTool(tool) {
  const stem = tool.stem
  if (DENY_STEMS.has(stem)) {
    return { action: "deny", reason: DENY_MESSAGE, rule: "explicit deny stem" }
  }
  if (ALLOW_STEMS.has(stem)) return { action: "allow" }
  for (const p of ALLOW_STEM_PREFIXES) {
    if (stem.startsWith(p)) return { action: "allow" }
  }
  if (stem.endsWith("_read")) return { action: "allow" }
  return { action: "deny", reason: DENY_MESSAGE, rule: "default deny (not on allowlist)" }
}
