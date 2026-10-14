// one list. scripts/privacy-scan.mjs and scripts/kru-tracker.sh (guard_text) both
// import it. a copy in either file is a drift the tracker test refuses.
//
// lin_api_ is case-insensitive, suffix length >= 8, hyphens allowed.
// password=/secret=/token= is the assignment with no space before '=', so a
// `const token = …` in vendored docs is not a hit. the tracker flattens
// newlines before these run, so a key split across lines is one token.

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
  { id: "assignment", source: String.raw`\b(?:password|secret|token)=[^\s]+`, flags: "i" },
]

// customer data. the privacy scan allow-lists placeholder mailboxes; the
// tracker does not. a phone is the tracker rule only — the scan does not
// treat a number in vendored docs as a leak.
export const EMAIL_SOURCE = String.raw`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`
export const PHONE_SOURCE = String.raw`(?:\+\d{1,3}[-. ]?)?\(?\d{3}\)?[-. ]\d{3}[-. ]\d{4}`

export function secretRegs() {
  return SECRET_PATTERNS.map((p) => ({ id: p.id, re: new RegExp(p.source, p.flags || "") }))
}

// newlines are removed first, so a token split across lines is matched whole.
export function flatten(text) {
  return String(text).replace(/[\r\n]/g, "")
}

export function leakIn(text) {
  const flat = flatten(text)
  const regs = [
    ...secretRegs().map((p) => p.re),
    new RegExp(EMAIL_SOURCE),
    new RegExp(PHONE_SOURCE),
  ]
  return regs.some((re) => re.test(flat))
}
