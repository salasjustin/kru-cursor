// fork edits: the prose and script changes this fork makes to upstream's text
// on purpose — not vocabulary the port normalizes, but decisions upstream
// doesn't share (who the PM is, who pushes, where a bug is filed). each edit
// is an exact passage of the *ported* file and what it becomes, applied by
// scripts/port.mjs after every rewrite rule, so it survives a merge from
// upstream the same way a rule does:
//
// - `before` found → replaced by `after`
// - `after` already present → applied on an earlier run; nothing to do
// - neither → upstream reworded the passage: the port fails and names the
//   edit, and the fix is a new `before` copied from the new upstream text
//
// exact strings, not regexes: a prose edit should break loudly on any upstream
// rewording rather than half-apply. group by ticket; `why` is the reason the
// passage differs from upstream, kept short. PORTING.md → Hand-owned.
//
// E(file, before, after, why) — `file` is the ported path (skills/kru-<name>/…)
const E = (file, before, after, why) => ({ file, before, after, why })

export const EDITS = []

// --- t1: the PM is the briefing bot; Justin owns and approves ----------------
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "You are the engineering lead. **The user is the PM** — the team exists to execute their ideas, not to prioritize for them. You run",
  "You are the engineering lead. **The PM is the Grok Bot PM that briefed this session** (Ivy, Kai, Juno, Nora or Rhea), and **Justin owns the product and approves** above it; Justin's word outranks a PM bot's. This sentence is the definition the rest of the team points at: below, *the user* and *the PM* both mean that PM bot, and Justin is named wherever only he acts. The team exists to execute the PM's brief, not to prioritize for it. You run",
  "t1: the PM is a bot that briefs the session; Justin owns and approves",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "You scope, route, delegate, integrate, verify, and report.\n\n**Capture, listing,",
  "You scope, route, delegate, integrate, verify, and report.\n\n**The PM bot decides; Justin hears only what is his.** A PM bot makes the calls it is handed by default, records why, and keeps going. It escalates to Justin only a call that is hard to reverse or reaches outside the team: money (billing, pricing, spend), legal or compliance (terms, privacy, licensing), a change customers, clients or users need a heads-up about, security or data exposure, anything public or live, a change of product direction or strategy, and any solution that needs a new outside account or service, free trials included — Justin decides that one, and the account setup itself goes through Otto (Ops). A call that fits none of these but would be costly to guess wrong goes to Justin too. Everything else the PM bot answers, including your grill.\n\n**Capture, listing,",
  "t1: the escalation rule (Justin's answers 1-2), one source the other files point at",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**Capture, listing, and the persisted brief are the user's own skills**",
  "**Capture, listing, and the persisted brief are the PM's own skills**",
  "t1: the PM runs them",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "roadmaps, prioritization, and what-to-build-next are the user's.",
  "roadmaps, prioritization, and what-to-build-next are the PM's, under Justin.",
  "t1",
))
EDITS.push(E(
  "TRACKER.md",
  "no priority scores — the **user is the PM** and brings the subject;",
  "no priority scores — the **PM** (the PM bot that briefs the session, with Justin as owner — `skills/kru-lead/SKILL.md`, first paragraph) brings the subject;",
  "t1",
))
EDITS.push(E(
  "TRACKER.md",
  "No priority score, no framework, no horizon, no success metrics — the user is the PM and already decided *whether*;",
  "No priority score, no framework, no horizon, no success metrics — the PM already decided *whether*;",
  "t1",
))
EDITS.push(E(
  "TRACKER.md",
  "`pitched` = user, `discovered` = team",
  "`pitched` = the PM bot or Justin (`skills/kru-lead/SKILL.md`, first paragraph), `discovered` = team",
  "t1: pitched is a PM bot or Justin",
))
EDITS.push(E(
  "TRACKER.md",
  "the next `brief` verb run reads the file back to the user during the grill, and the user (the PM) decides",
  "the next `brief` verb run reads the file back to the PM during the grill, and the PM decides",
  "t1",
))
EDITS.push(E(
  "TRACKER.md",
  "governs scoring: the user's own words win and are filed bare;",
  "governs scoring: the PM's own words win and are filed bare (Justin's over a PM bot's when they differ);",
  "t1: Justin's words outrank a PM bot's",
))
EDITS.push(E(
  "ROSTER.md",
  "**The user is the PM** — there is no product-management function, no roadmap, and no prioritization framework in the team; what-to-build-next is the user's call,",
  "**The PM is the PM bot that briefs the session, with Justin as owner and approver** (`skills/kru-lead/SKILL.md`, first paragraph) — there is no product-management function, no roadmap, and no prioritization framework in the team; what-to-build-next is the PM's call,",
  "t1",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "There is **no roadmap, no prioritization framework, and no PM pass** — the user is the PM and brings\nthe subject.",
  "There is **no roadmap, no prioritization framework, and no PM pass** — the PM (the PM bot that\nbriefed the session, under Justin: `skills/kru-lead/SKILL.md`, first paragraph) brings the subject.",
  "t1",
))

// --- t1: (cont.) the remaining 'user is the PM' lines ------------------------
EDITS.push(E(
  "SOURCES.md",
  "**The user is the PM**: no roadmap,",
  "**The PM brings the subject** (the briefing PM bot, under Justin): no roadmap,",
  "t1",
))
EDITS.push(E(
  "SOURCES.md",
  "no product-management function (the user is the PM)",
  "no product-management function (the PM is the briefing PM bot)",
  "t1",
))
EDITS.push(E(
  "ROSTER.md",
  "**no roadmap, no horizons, no priority framework** (the user is the PM)",
  "**no roadmap, no horizons, no priority framework** (the PM is the briefing PM bot)",
  "t1",
))
EDITS.push(E(
  "ROSTER.md",
  "**not** vendored — the user is the PM, so nothing",
  "**not** vendored — the PM is the briefing PM bot, so nothing",
  "t1",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "pre-decision by construction — the user is the PM, and thinking it through",
  "pre-decision by construction — the PM decides, and thinking it through",
  "t1",
))
