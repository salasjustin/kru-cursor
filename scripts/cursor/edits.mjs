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

// --- t2: gates match the PM bots' policy ----------------------------------
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**Two things reach them.** A **product call** — what the thing does, who it's for, what it says, what\nit costs someone using it — is theirs, because nothing in the codebase implies the answer. A\n**one-way door** — deploying, publishing, a migration, a deletion, anything outward-facing or\nexpensive to undo — is theirs, because a wrong guess can't be walked back.",
  "**Two things reach the PM.** A **product call** — what the thing does, who it's for, what it says, what\nit costs someone using it — is the PM's, because nothing in the codebase implies the answer. A\n**one-way door** — deploying, publishing, a migration, a deletion, anything outward-facing or\nexpensive to undo — is the PM's too, because a wrong guess can't be walked back; the PM bot takes it\non to Justin when the escalation rule above says so, and a merge, deploy or publish always waits\nfor him (*Who acts at the door*, below).",
  "t2: product calls and one-way doors go to the PM bot, which escalates to Justin",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**A push is a one-way door, and most of the user's repos are public.** Read the repo's visibility\n(`gh repo view --json visibility`) before any push. A security fix stays local\nuntil the user OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` the session starts through the GitHub API, the workflow creating the tag\non its job token — the release is the session's to run end to end.",
  "**Who acts at the door.** You commit locally and return proof; the push is not yours. The PM bot\nreviews the proof, pushes the branch and opens the pull request. Merging, tagging, releasing,\ndeploying, publishing and any message outside the team wait for Justin — except kru's own releases,\nwhich Kai (kru's PM bot) merges and tags. Most product repos are public, so the PM bot reads the\nrepo's visibility (`gh repo view --json visibility`) before a push. A security fix stays local\nuntil Justin OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` started through the GitHub API, the workflow creating the tag on its\njob token — started by whoever owns that release: Justin, or Kai for kru.",
  "t2: Claude Code commits, the PM bot pushes and opens the PR, Justin merges/tags/deploys (Kai for kru)",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "   - *An ask to act* — running a command, logging in, approving a push — only when it can't be yours;\n     the exact thing to type and why, in one clause.",
  "   - *An ask to act* — running a command, logging in, a push or pull request (the PM bot's) — only when\n     it can't be yours; the exact thing to type and why, in one clause. A merge, deploy or release is\n     Justin's, and the PM bot carries it to him.",
  "t2: no line asks a human to approve a push",
))
EDITS.push(E(
  "skills/kru-roster/SKILL.md",
  "| 9 | git | `commit` + `tag vX.Y.Z` — **only when the user asks** (team git rule) |",
  "| 9 | git | `commit` locally when the PM asks; the PM bot pushes and opens the pull request; merging and `tag vX.Y.Z` are Kai's — kru's PM bot owns kru releases (`skills/kru-lead/SKILL.md` → *Who acts at the door*) |",
  "t2: kru releases are Kai's",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "clause (\"plus 6 cleanups to the project notes\"); the diff is there if asked.",
  "clause (\"plus 6 cleanups to the project notes\"); the diff is there if asked. Setup commits at most\nlocally: the PM bot reviews the diff, pushes it and opens the pull request, and Justin merges it\n(`skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "t2: setup's report names who pushes and merges",
))

// --- t2: (cont.) propagate's push --------------------------------------------
EDITS.push(E(
  "skills/kru-propagate/SKILL.md",
  "commit in the repo's own message style (read its `git log`); push to the working branch.",
  "commit in the repo's own message style (read its `git log`); the push to the working branch is the PM bot's (`skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "t2: Claude Code commits, the PM bot pushes",
))

// --- t3: headless runs never wait on a question ------------------------------
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "Asking for approval of your own recommendation on a two-way door is the\nsame wait, disguised as courtesy.\n",
  "Asking for approval of your own recommendation on a two-way door is the\nsame wait, disguised as courtesy.\n\n**A headless run never waits.** Under `cursor-agent -p`, a cloud agent, or any run the PM bot\nstarted and left, nobody answers mid-run, and one waiting question ends the run without proof. The\nPM bot answers the grill up front: the brief's *Decisions resolved* are its answers. Every two-way\ndoor still open you decide, record in one line, and build on. A product call or one-way door left\nopen parks only the slice it touches; the rest builds, and the call goes under **Questions for the\nPM** in your final return, each with your recommendation. An explicit `go` line in the brief lifts\na `/kru-brainstorm` lock. `/kru-setup`, `/kru-brief` and `/kru-remember` are the PM bot's to run\nitself, so a headless run never stops to hand one over.\n",
  "t3: the headless rule, one source the other files point at",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "name `/kru-setup` for the user to re-run — it is theirs to type, and the current sheet still carries the work meanwhile.",
  "name `/kru-setup` for the PM to re-run — the PM bot runs it itself, and the current sheet still carries the work meanwhile.",
  "t3: the PM bot runs /kru-setup",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**Persisting it is `/kru-brief`'s**, and the user types it. Only when the work will span sessions — or `planner` will slice it — ask in outcome terms (\"keep this plan past today?\"), and on a yes give them `/kru-brief` to type.",
  "**Persisting it is `/kru-brief`'s**, and the PM bot runs it. Only when the work will span sessions — or `planner` will slice it — ask in outcome terms (\"keep this plan past today?\"), and on a yes name `/kru-brief` for the PM bot to run; headless, say it under *Questions for the PM* and keep building.",
  "t3: the PM bot runs /kru-brief; headless never waits",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "Only the product calls still open wait on the user.",
  "Only the product calls still open wait on the PM — and headless, not even those (*A headless run never waits*).",
  "t3",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "A slice reaching a stack no seat covers is a question for the user — hiring is their call on their team — and it parks only that slice:",
  "A slice reaching a stack no seat covers is a question for the PM — hiring is the PM bot's call on the team — and it parks only that slice (headless, it goes under *Questions for the PM*):",
  "t3: the unseated-stack question goes to the PM bot and never blocks",
))
EDITS.push(E(
  "skills/kru-grilling/SKILL.md",
  "The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.",
  "The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.\n\nThe user here is the PM bot that briefed the session, and it answers up front: its brief's *Decisions resolved* settle the frontier they cover. In a headless run nobody answers mid-run, so no round is asked and nothing waits: an open two-way door gets your recommended answer, recorded as a decision; an open product call or one-way door parks only the work it touches and is returned under *Questions for the PM* (`skills/kru-lead/SKILL.md` → *A headless run never waits*).",
  "t3: the grill is answered by the PM bot; headless never waits",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "Persisting the brief widens what's **written down**, never what's **asked**: a two-way door you settled goes into `Decisions resolved` as your call, with its reasoning — not into the round as a question.\n",
  "Persisting the brief widens what's **written down**, never what's **asked**: a two-way door you settled goes into `Decisions resolved` as your call, with its reasoning — not into the round as a question.\n\n**The PM bot answers the round** — best up front, in the subject it hands you. In a headless run nobody answers mid-run: ask no round, write the open product calls and one-way doors into the brief as open questions, and return them under *Questions for the PM* (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*).\n",
  "t3: headless brief runs never wait",
))
EDITS.push(E(
  "skills/kru-brainstorm/SKILL.md",
  "The user's go (\"go\", \"brief it\") is the only thing that writes.",
  "The PM's go (\"go\", \"brief it\") is the only thing that writes. A headless brainstorm carries it in the prompt as a line of its own reading `go`, which lifts the lock from the start (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*).",
  "t3: an explicit go in the brief lifts the brainstorm lock",
))
EDITS.push(E(
  "skills/kru-remember/SKILL.md",
  "If empty, ask one line (\"What should I bank — and is it design, code, or workflow?\") and stop.",
  "If empty, ask one line (\"What should I bank — and is it design, code, or workflow?\") and stop — or, headless, bank nothing and say so in the return.",
  "t3: headless never waits",
))
EDITS.push(E(
  "skills/kru-roster/SKILL.md",
  "No verb given → run `audit` and report, then ask which of the others they want.",
  "No verb given → run `audit` and report, then ask which of the others they want (headless: report the audit and stop).",
  "t3: headless never waits",
))
EDITS.push(E(
  "skills/kru-todos-loop/SKILL.md",
  "listed under *Need your call* for the user to confirm, so the guess becomes their number.",
  "listed under *Questions for the PM* for the PM bot to confirm, so the guess becomes its number.",
  "t3: one name for the held list",
))
EDITS.push(E(
  "references/backlog-loop.md",
  "Held entries get the numbered list, each with a recommendation;",
  "Held entries go under *Questions for the PM*, numbered, each with a recommendation;",
  "t3: one name for the held list",
))
EDITS.push(E(
  "references/backlog-loop.md",
  "Nothing is pushed — the branch is the user's to review and open.",
  "Nothing is pushed — the PM bot reviews the branch, pushes it and opens the pull request.",
  "t2/t3: the PM bot pushes",
))
EDITS.push(E(
  "hooks/setup-nudge.sh",
  "there is no sheet in .claude/CLAUDE.md. Name /kru-setup to the user once this session (it is theirs to type), then carry on:",
  "there is no sheet in AGENTS.md. Name /kru-setup to the PM once this session (the PM bot runs it itself; a headless run says it in its return), then carry on:",
  "t3: the PM bot runs /kru-setup; the sheet is AGENTS.md here",
))

// --- t4: the oracle is the PM bot's done-check, with proof returned ----------
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "pair every behavior on the list you handed down (your grill, or `brief.md`'s `Done when`) with its proof — a test name, a command's output, a count, from the return or from your own scoped run.",
  "pair every behavior on the list you handed down (your grill, or `brief.md`'s `Done when` — the PM bot's done-check, and the oracle for the whole change) with its proof — a test name, a command's output, a count, a screenshot path, from the return or from your own scoped run. Those pairs are the **Proof** block of your report (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Report when work lands*), which is what the PM bot reviews.",
  "t4: the oracle is the PM bot's done-check, and the proof goes back to it",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "- Design work: **the gate is the user's eye, and there is no substitute for it**",
  "- Design work: **the gate is the PM bot's eye, and there is no substitute for it** — it judges the screenshots and paths in your Proof block, and takes the call to Justin only when it can't judge it",
  "t4: design conformance goes to the PM bot, Justin only if it can't judge",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "A **named gap** in the builder's return is the one output you act on before the user looks: it goes to the **user** as the visible choice (\"what colour for warnings?\"), not to a seat — the token name it would need stays in the record and the builder's brief. The user reports back through you",
  "A **named gap** in the builder's return is the one output you act on before the PM looks: it goes to the **PM** as the visible choice (\"what colour for warnings?\"), not to a seat — the token name it would need stays in the record and the builder's brief. The PM reports back through you",
  "t4",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "their findings merge into the same fix list as `code-reviewer`'s, and the user's eye above remains the gate.",
  "their findings merge into the same fix list as `code-reviewer`'s, and the PM bot's eye above remains the gate.",
  "t4",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "   - *Report when work lands* — what's different for users, then what's next. A handful of lines,\n     closing on the `/kru-reflect` line filled in — its target the commit or range that landed — ready\n     to run as typed.",
  "   - *Report when work lands* — what's different for users, then what's next. A handful of lines,\n     then a **Proof** block: each `Done when` item beside the command you ran and its result, or the\n     screenshot or file path that shows it (`references/gates.md` → *Done is judged on evidence*), and\n     *Questions for the PM* when any stayed open. Close on the `/kru-reflect` line filled in — its\n     target the commit or range that landed — ready to run as typed.",
  "t4: every return carries a proof block",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "A builder has no user channel, so `tdd`'s \"confirm the seams under test with the user\" resolves to *your grill*",
  "A builder has no user channel, so `tdd`'s \"confirm the seams under test with the user\" resolves to *your grill*, which the PM bot answered",
  "t4",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "Its bound is in its own wording: the user has to actually *be* the oracle.",
  "Its bound is in its own wording: the PM bot has to actually *be* the oracle, judging the screen from the Proof block's screenshots.",
  "t4: the PM bot is the screen oracle",
))
EDITS.push(E(
  "skills/kru-landed/SKILL.md",
  "The user just watched their PR merge.",
  "Justin just merged the PR, and the PM bot runs this.",
  "t4: the PM bot runs /kru-landed after Justin merges",
))
EDITS.push(E(
  "skills/kru-landed/SKILL.md",
  "List the paths and stop; commit or stash is the user's call, not yours.",
  "List the paths and stop; commit or stash is the PM bot's call, not yours — report it there.",
  "t4: landed's stops report to the PM bot",
))
EDITS.push(E(
  "skills/kru-landed/SKILL.md",
  "Name the path and let the user leave it first.",
  "Name the path and let the PM bot leave it first.",
  "t4",
))

// --- t4: (cont.) landed's stops ----------------------------------------------
EDITS.push(E(
  "skills/kru-landed/SKILL.md",
  "**Local sync only.** Landing already happened on the remote. Nothing here merges, rebases, pushes, or force-anythings.",
  "**Local sync only.** Landing already happened on the remote. Nothing here merges, rebases, pushes, or force-anythings.\n\n**Every stop below is a report to the PM bot**: what stopped, the paths or commits involved, and the one command that would resolve it. The PM bot decides the next step.",
  "t4: landed's stops report to the PM bot",
))

// --- t5: reports go to the PM bot --------------------------------------------
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "## Talk to a PM, not to an engineer\nThe user owns the product, not the implementation.",
  "## Talk to a PM, not to an engineer\nYour reader is the PM bot. You report to it, never to Justin directly, and it forwards to Justin only\nwhat is blocked, ready for his approval, or done with proof — the escalation rules are the PM bots'\n`policies.md`, and the list in this skill's first section. So every message is written to be\nforwarded as is: outcome first, plain words. The PM and Justin own the product, not the implementation.",
  "t5: the lead's audience is the PM bot; it forwards to Justin only blocked / ready / done",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "A *You should know* card the user sends to the main session is the same case: the press is theirs,",
  "A *You should know* card the PM sends to the main session is the same case: the press is the PM's,",
  "t5",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "- **Queued** — anything the user says while a builder is out.",
  "- **Queued** — anything the PM says while a builder is out.",
  "t5",
))

// --- t6: two preference channels, one each -----------------------------------
EDITS.push(E(
  "PREFERENCES.md",
  "1. **The user, explicitly** — `/kru-remember <what they liked>`. Never inferred from approval; the team does not guess.",
  "1. **Justin or the PM bot, explicitly** — `/kru-remember <what they liked>`, sourced `user:justin` or `pm:<bot>` (`pm:kai`). **Two channels, one each:** how the PM bots themselves operate goes to the PM bots' own `remember` skill, which Vera files into their policies, never here; the engineering practice the seats should carry comes here. Only the PM-to-lead loop counts as input, kept within the escalation rule (`skills/kru-lead/SKILL.md`, first section): a `pm:<bot>` line is a proposal, and Justin's words outrank it. Never inferred from approval; the team does not guess.",
  "t6: two preference channels, one each; PM-bot lines are proposals",
))
EDITS.push(E(
  "PREFERENCES.md",
  "- [design] prefers bento-grid hero over centered-stack — _user · acme-site · 2026-07-21_\n- [code] approved Result<T,E> returns over throwing at call boundaries — _agent:sveltekit-builder · acme-site · 2026-07-21_\n- [workflow] wants the plan grilled before any build, always — _user · acme-site · 2026-07-21_\n- [design] liked this pricing table → patterns/pricing-3col.md — _user · acme-site · 2026-07-21_",
  "- [design] prefers bento-grid hero over centered-stack — _user:justin · acme-site · 2026-07-21_\n- [code] approved Result<T,E> returns over throwing at call boundaries — _agent:sveltekit-builder · acme-site · 2026-07-21_\n- [workflow] wants the plan grilled before any build, always — _pm:kai · acme-site · 2026-07-21_\n- [design] liked this pricing table → patterns/pricing-3col.md — _user:justin · acme-site · 2026-07-21_",
  "t6: the source tags",
))
EDITS.push(E(
  "PREFERENCES.md",
  "- **source** `user`, `agent:<seat-slug>`, or `setup` — who captured it",
  "- **source** `user:justin`, `pm:<bot>`, `agent:<seat-slug>`, or `setup` — who captured it (a bare `user` from before the split reads as `user:justin`)",
  "t6",
))
EDITS.push(E(
  "PREFERENCES.md",
  "Nothing is committed, so the uncommitted diff is the user's review.",
  "Nothing is committed: Kai reviews the uncommitted diff from its kru checkout, then commits, pushes, opens the pull request, merges and tags (Kai owns kru releases).",
  "t6: learn's review and release are Kai's",
))
EDITS.push(E(
  "PREFERENCES.md",
  "(run from the plugin source repo; decides, user reviews the diff)",
  "(run from Kai's kru checkout; decides, Kai reviews the diff)",
  "t6",
))
EDITS.push(E(
  "skills/kru-remember/SKILL.md",
  "   - [<lane>] <the preference, tightly worded> — _user · <project-slug> · <YYYY-MM-DD>_",
  "   - [<lane>] <the preference, tightly worded> — _<source> · <project-slug> · <YYYY-MM-DD>_",
  "t6: the source tag accepts pm:<bot>",
))
EDITS.push(E(
  "skills/kru-remember/SKILL.md",
  "Source is always `user` for this command (agents append their own lines directly, per the lead's handoff).",
  "Source is `user:justin` for Justin's words and `pm:<bot>` (`pm:kai`) for a PM bot's — a PM bot's line is a proposal, and Justin's words outrank it at the sweep. Agents append their own lines directly, per the lead's handoff.",
  "t6: the source tag accepts pm:<bot>",
))
EDITS.push(E(
  "skills/kru-remember/SKILL.md",
  "- Don't promote it now — capture is lossless and untriaged; the sweep is the gated step that edits the team.",
  "- Don't promote it now — capture is lossless and untriaged; the sweep is the gated step that edits the team.\n- How the PM bots themselves operate is not a team preference: it goes to the PM bots' own `remember` skill (`${CURSOR_PLUGIN_ROOT}/PREFERENCES.md` → Tier 1, writer 1). This inbox takes what the seats should carry.",
  "t6: two channels",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "The review is the uncommitted diff — commit stays the user's, so an edit they disagree with is reverted before it ships.\n\nRun this **from the plugin source repo** (it commits the plugin), not a product repo.",
  "The review is the uncommitted diff — Kai's, so an edit it disagrees with is reverted before it ships.\n\nRun this **from Kai's kru checkout** (it changes the plugin), not a product repo. Kai reviews the diff, commits, pushes, opens the pull request, merges and tags — Kai owns kru releases. Justin's words (`user:justin`) outrank a PM bot's (`pm:<bot>`) in every verdict below.",
  "t6: learn runs from Kai's checkout; Kai reviews and releases; Justin outranks",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "- **Put it to the user** when a `user`-sourced line contradicts a rule the plugin states — the conflict is resolved at its source, not won by the standing text. It becomes a numbered question in the report (keep the rule, or change it to the line) and stays in the inbox, deferred, until the user answers.",
  "- **Put it to the source** when a `user:justin`-sourced line contradicts a rule the plugin states — the conflict is resolved at its source, not won by the standing text. It becomes a numbered question in the report for Kai to carry to Justin (keep the rule, or change it to the line) and stays in the inbox, deferred, until Justin answers. A `pm:<bot>` line contradicting a stated rule or a `user:justin` line is a proposal that lost: drop it with the reason.",
  "t6: Justin's lines outrank PM-bot lines",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "Leave `commit`+`tag` to the user (git rule).",
  "`commit`, push, pull request, merge and `tag` are Kai's (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "t6",
))
EDITS.push(E(
  "hooks/check-handoff.sh",
  "(the user rejected X twice and chose Y)",
  "(the PM or Justin rejected X twice and chose Y)",
  "t6",
))
EDITS.push(E(
  "references/store.md",
  "the half that is supposed to follow the user rather",
  "the half that is supposed to follow Justin and the PM bots rather",
  "t6",
))

// --- t6: (cont.) learn's report ----------------------------------------------
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "questions (each user line against the rule it contradicts), deferred — as a list numbered 1, 2, 3 the user can answer by item.",
  "questions (each `user:justin` line against the rule it contradicts), deferred — as a list numbered 1, 2, 3 Kai can answer, or carry to Justin, by item.",
  "t6",
))
