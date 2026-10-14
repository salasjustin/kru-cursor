// one list. scripts/privacy-scan.mjs and scripts/kru-tracker.sh (guard_text) both
// import it. a copy in either file is a drift the tracker test refuses.
//
// lin_api_ is case-insensitive, suffix length >= 8, hyphens allowed.
// an assignment is password, secret, token, api_key, apikey, or private_key
// inside the name. quotes around the name and the value are optional, so a
// JSON or YAML key counts ("password": "hunter2", 'client_secret': '...',
// "access_token", "refresh_token", "AWS_SECRET_ACCESS_KEY"). there is no
// space before '=' or ':' unless a closing quote sits there. a `const token
// = …` does not count, because of the space before '='. leakIn tries the
// original text, a copy whose newlines are spaces, and a copy whose newlines
// are deleted, so a key on its own line keeps its word boundary and a key
// split across lines is one token.

export const SECRET_PATTERNS = [
  { id: "github-token", source: String.raw`\b(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b` },
  { id: "openai/anthropic-key", source: String.raw`\bsk-(ant-)?[A-Za-z0-9_-]{24,}\b` },
  { id: "aws-key", source: String.raw`\b(AKIA|ASIA)[0-9A-Z]{16}\b` },
  { id: "slack-token", source: String.raw`\bxox[abposr]-[A-Za-z0-9-]{10,}\b` },
  { id: "private-key", source: String.raw`-----BEGIN [A-Z ]*PRIVATE KEY-----` },
  { id: "google-api-key", source: String.raw`\bAIza[0-9A-Za-z_-]{35}\b` },
  { id: "stripe-live-key", source: String.raw`\b[rs]k_live_[0-9A-Za-z]{16,}\b` },
  { id: "stripe-test-key", source: String.raw`\bsk_test_[0-9A-Za-z]{16,}\b` },
  { id: "cursor-api-key", source: String.raw`\bkey_[0-9a-f]{40,}\b` },
  { id: "bearer-token", source: String.raw`\bBearer\s+[A-Za-z0-9._~+/-]{24,}={0,2}` },
  { id: "linear-api-key", source: String.raw`\blin_api_[A-Za-z0-9-]{8,}`, flags: "i" },
  // _ is not a word boundary, so API_TOKEN= and DB_PASSWORD= need an explicit
  // separator. more than one _segment is the same name (AWS_SECRET_ACCESS_KEY=).
  // quotes may wrap the name, the value, or both. a quoted name with no value
  // still counts for access_token, refresh_token, client_secret, api_key,
  // apikey, private_key, and AWS_SECRET_ACCESS_KEY. ':' is the same assignment
  // as '=', and a space belongs after it (`password: hunter2`) or after the
  // closing quote. an unquoted colon value has to look like a credential — a
  // digit, quotes, or ${ — so prose ("secret: the") is not one. a letter
  // glued on the front (authToken=) is not this shape, and neither is a
  // space before '=' (`const token = …`).
  { id: "assignment", source: String.raw`(?:^|[^A-Za-z0-9])(?:['"](?:[A-Za-z0-9]+_)*(?:password|secret|token|private_key|api[_-]?key)(?:_[A-Za-z0-9]+)*['"]\s*[:=]\s*(?:'[^']+'|"[^"]+"|\$\{[^\s]+|[^\s]*[0-9][^\s]*)|(?:[A-Za-z0-9]+_)*(?:password|secret|token|private_key|api[_-]?key)(?:_[A-Za-z0-9]+)*(?:=[^\s]+|:\s*(?:'[^']+'|"[^"]+"|\$\{[^\s]+|[^\s]*[0-9][^\s]*))|['"](?:access_token|refresh_token|client_secret|aws_secret_access_key|(?:[A-Za-z0-9]+_)*(?:private_key|api[_-]?key))['"])`, flags: "i" },
  // a raw JWT: header and payload both start with eyJ, then a signature.
  { id: "jwt", source: String.raw`eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}` },
  { id: "slack-webhook", source: String.raw`hooks\.slack\.com\/services\/` },
  // API_KEY= or apikey: whose value is one opaque token of at least 16 chars.
  // a space before '=' is not this shape. shorter values are the assignment
  // pattern above when the name is api_key or apikey.
  { id: "generic-api-key", source: String.raw`(?:^|[^A-Za-z0-9])(?:['"](?:[A-Za-z0-9]+_)*api[_-]?key['"]\s*[:=]\s*['"]?[A-Za-z0-9+/=_-]{16,}|(?:[A-Za-z0-9]+_)*api[_-]?key[:=]\s*['"]?[A-Za-z0-9+/=_-]{16,})`, flags: "i" },
]

// customer data. the privacy scan allow-lists placeholder mailboxes; the
// tracker does not. a phone is the tracker rule only — the scan does not
// treat a number in vendored docs as a leak.
export const EMAIL_SOURCE = String.raw`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`
export const PHONE_SOURCE = String.raw`(?:\+\d{1,3}[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]\d{4}(?!\d)`

export function secretRegs() {
  return SECRET_PATTERNS.map((p) => ({ id: p.id, re: new RegExp(p.source, p.flags || "") }))
}

// the newline-deleted copy. a key split across lines is one token there.
// leakIn also scans the original and a copy whose newlines are spaces: deleting
// the break glues the previous word onto the key and drops the \b in front of it.
export function flatten(text) {
  return String(text).replace(/[\r\n]/g, "")
}

export function leakIn(text) {
  const raw = String(text)
  const versions = [raw, raw.replace(/[\r\n]+/g, " "), flatten(raw)]
  const regs = [
    ...secretRegs().map((p) => p.re),
    new RegExp(EMAIL_SOURCE),
    new RegExp(PHONE_SOURCE),
  ]
  return versions.some((version) => regs.some((re) => re.test(version)))
}
