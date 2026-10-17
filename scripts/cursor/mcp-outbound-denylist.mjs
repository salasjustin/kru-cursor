// Single source of truth: which MCP tool names cloud agents may call.
// Reads and drafts stay allowed; outbound or destructive connector actions are denied.
// Matched against the normalized tool stem (last segment, lowercased) and the full id.

/** @typedef {{ id: string, stem: string }} ToolId */

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
    if (typeof ns === "string" && typeof tool === "string" && ns && tool) {
      const id = `${ns}/${tool}`
      return { id: id.toLowerCase(), stem: tool.toLowerCase() }
    }
    return null
  }
  if (/^MCP:/i.test(raw)) {
    const rest = raw.replace(/^MCP:/i, "")
    const stem = (rest.split(/[:/]/).pop() ?? rest).toLowerCase()
    return { id: rest.toLowerCase(), stem }
  }
  if (/^mcp/i.test(raw)) return { id: raw.toLowerCase(), stem: raw.toLowerCase() }
  return null
}

// --- allow (checked before deny) -------------------------------------------------

/** Exact stems always allowed (drafts). */
export const ALLOW_STEMS = new Set(["create_draft", "update_draft", "slack_send_message_draft"])

/** Stem prefixes for read-only connector tools. */
export const ALLOW_STEM_PREFIXES = ["get_", "list_", "search_", "read_", "query_", "find_", "fetch_"]

// --- deny ------------------------------------------------------------------------

/**
 * Each entry is tested against stem and full id (lowercase). First match denies unless
 * an allow rule above already matched.
 */
export const DENY_RULES = [
  {
    label: "outbound verbs (send, post, reply, forward, share, publish, schedule, deploy)",
    test: (s) =>
      /(?:^|[_:/-])(send|post|reply|forward|share|publish|schedule|deploy)(?:$|[_:/-])/.test(s) &&
      !/send_message_draft$/.test(s) &&
      s !== "slack_send_message_draft",
  },
  {
    label: "destructive verbs (delete, trash, remove, merge)",
    test: (s) => /(?:^|[_:/-])(delete|trash|remove|merge)(?:$|[_:/-])/.test(s),
  },
  {
    label: "comments and reactions (Linear, GitHub, …)",
    test: (s) => /(create_comment|add_comment|save_comment|add_reaction|post_comment|create_review)/.test(s),
  },
  {
    label: "Slack canvas writes",
    test: (s) => /(create_canvas|update_canvas)/.test(s),
  },
  {
    label: "Slack send (not draft)",
    test: (s) => /slack_send_message(?!_draft)/.test(s) || s === "send_message",
  },
  {
    label: "Gmail send",
    test: (s) => /^send_message$/.test(s) || /(^|_)send_message($|_)/.test(s),
  },
  {
    label: "Linear / tracker writes (save_*, submit_*)",
    test: (s) => /(?:^|[_:/-])(save|submit)(?:_|$)/.test(s) && !/^prepare_/.test(s),
  },
  {
    label: "Google Docs mutations",
    test: (s) =>
      /(create_document|insert_text|replace_text|delete_content|apply_paragraph|apply_text|merge_table|insert_table|insert_image|set_header)/.test(
        s,
      ),
  },
  {
    label: "GitHub PR / issue writes",
    test: (s) =>
      /(create_pr|update_pr|merge_pull|edit_pull_request|create_issue|update_issue|add_labels|remove_labels)/.test(s),
  },
]

const DENY_MESSAGE =
  "kru: this cloud agent cannot send, post, share, or delete through team connectors (MCP). Hand this action back to the PM bot to run outside the agent. Reads and drafts are still allowed."

/**
 * @param {ToolId} tool
 * @returns {{ action: "allow" } | { action: "deny", reason: string, rule: string }}
 */
export function classifyMcpTool(tool) {
  const stem = tool.stem
  const hay = `${tool.id} ${stem}`
  if (ALLOW_STEMS.has(stem)) return { action: "allow" }
  for (const p of ALLOW_STEM_PREFIXES) {
    if (stem.startsWith(p)) return { action: "allow" }
  }
  for (const rule of DENY_RULES) {
    if (rule.test(hay) || rule.test(stem)) {
      return { action: "deny", reason: DENY_MESSAGE, rule: rule.label }
    }
  }
  return { action: "allow" }
}
