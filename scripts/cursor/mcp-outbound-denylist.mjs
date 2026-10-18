// Single source of truth: which MCP tool names cloud agents may call.
// Reads and drafts stay allowed; outbound or destructive connector actions are denied.
// Matched against the normalized tool stem (last segment, lowercased) and the full id.

/** @typedef {{ id: string, stem: string }} ToolId */

const GOOGLE_DOCS_DENY_MESSAGE =
  "kru: this cloud agent cannot send, post, share, or delete through team connectors (MCP). Hand this action back to the PM bot to run outside the agent. Reads and drafts are still allowed."

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

// --- allow (checked before deny) -------------------------------------------------

/** Exact stems always allowed (drafts). */
export const ALLOW_STEMS = new Set([
  "create_draft",
  "update_draft",
  "slack_send_message_draft",
  "save_issue",
])

/** Stem prefixes for read-only connector tools. */
export const ALLOW_STEM_PREFIXES = ["get_", "list_", "search_", "read_", "query_", "find_", "fetch_"]

/** Exact stems always denied (connector writes that do not match verb rules). */
export const DENY_STEMS = new Set([
  "add_issue_comment",
  "add_comment_to_pending_review",
  "add_reply_to_pull_request_comment",
  "create_attachment",
  "create_attachment_from_upload",
  "create_branch",
  "create_filter",
  "create_list",
  "create_or_update_file",
  "create_pull_request",
  "create_pull_request_review",
  "delete_file",
  "issue_write",
  "merge_pull_request",
  "pull_request_review_write",
  "push_files",
  "slack_add_list_record",
  "slack_complete_file_upload",
  "slack_create_conversation",
  "slack_create_list",
  "slack_update_list",
  "unshare_issue",
  "untrash_message",
  "untrash_thread",
  "update_issue_comment",
  "update_pull_request",
])

// --- deny ------------------------------------------------------------------------

/**
 * Each entry is tested against stem and full id (lowercase). First match denies unless
 * an allow rule above already matched.
 */
export const DENY_RULES = [
  {
    label: "outbound verbs (send, post, reply, forward, share, publish, schedule, deploy, upload)",
    test: (s) =>
      /(?:^|[_:/-])(send|post|reply|forward|share|publish|schedule|deploy|upload)(?:$|[_:/-])/.test(s) &&
      !/send_message_draft$/.test(s) &&
      s !== "slack_send_message_draft" &&
      !/^untrash_/.test(s) &&
      !/^unshare_/.test(s),
  },
  {
    label: "destructive verbs (delete, trash, remove, merge)",
    test: (s) =>
      /(?:^|[_:/-])(delete|trash|remove|merge)(?:$|[_:/-])/.test(s) && !/^untrash_/.test(s),
  },
  {
    label: "comments and reactions (Linear, GitHub, …)",
    test: (s) =>
      /(create_comment|add_comment|save_comment|add_reaction|post_comment|create_review|issue_comment|pull_request_review)/.test(
        s,
      ),
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
    test: (s) =>
      /(?:^|[_:/-])(save|submit)(?:_|$)/.test(s) && !/^prepare_/.test(s) && s !== "save_issue",
  },
  {
    label: "Google Docs mutations",
    test: (s) =>
      /(create_document|insert_|replace_text|delete_content|apply_paragraph|apply_text|merge_table|insert_table|insert_image|set_header|set_paragraph|set_table|create_list|insert_page_break)/.test(
        s,
      ),
  },
  {
    label: "GitHub PR / issue writes",
    test: (s) =>
      /(create_pr|update_pr|merge_pull|edit_pull_request|create_issue|update_issue|add_labels|remove_labels|pull_request|push_files|or_update_file)/.test(
        s,
      ),
  },
]

const DENY_MESSAGE =
  "kru: this cloud agent cannot send, post, share, or delete through team connectors (MCP). Hand this action back to the PM bot to run outside the agent. Reads and drafts are still allowed."

function isGoogleDocsTool(tool) {
  const id = tool.id
  return (
    id.startsWith("google-docs/") ||
    id.startsWith("google-docs:") ||
    id.includes("/google-docs/") ||
    /^google-docs[:/]/.test(id)
  )
}

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
  if (isGoogleDocsTool(tool) && stem !== "read_document" && stem !== "find_text") {
    return { action: "deny", reason: GOOGLE_DOCS_DENY_MESSAGE, rule: "Google Docs (non-read)" }
  }
  if (DENY_STEMS.has(stem)) {
    return { action: "deny", reason: DENY_MESSAGE, rule: "explicit deny stem" }
  }
  for (const rule of DENY_RULES) {
    if (rule.test(hay) || rule.test(stem)) {
      return { action: "deny", reason: DENY_MESSAGE, rule: rule.label }
    }
  }
  return { action: "allow" }
}
