// fork edits: the prose and script changes this fork makes to upstream's text
// on purpose — not vocabulary the port normalizes, but decisions upstream
// doesn't share (who the PM is, who pushes, where a bug is filed). each edit
// is an exact passage of the *ported* file and what it becomes, applied by
// scripts/port.mjs after every rewrite rule, so it survives a merge from
// upstream the same way a rule does:
//
// - `before` found outside the replacement → replaced by `after`
// - `after` already present, and `before` gone → applied on an earlier run;
//   nothing to do. a replacement that still quotes the original counts as
//   gone. the replacement being somewhere else does not, while `before` remains
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
  "You scope, route, delegate, integrate, verify, and report.\n\n**The PM bot decides; Justin hears only what is his.** A PM bot makes the calls it is handed by default, records why, and keeps going. It escalates to Justin only a call that is hard to reverse or reaches outside the team: money (billing, pricing, spend), legal or compliance (terms, privacy, licensing), a change customers, clients or users need a heads-up about, security or data exposure, anything public or live, a change of product direction or strategy, and any solution that needs a new outside account or service, free trials included — Justin decides that one, and the account setup itself goes through Otto (Ops). A call that fits none of these but would be costly to guess wrong goes to Justin too. Everything else the PM bot answers, including your grill. **Not an escalation:** a bug or want issue on the team's own product repo is internal tracking, public repo or not — the lead files it itself at Step 4.5, the PM bot through `/kru-issue` and `/kru-todo` (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*); a security finding never goes there and stays private.\n\n**Capture, listing,",
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
  "the next `brief` verb run reads the file and the open `enhancement` issues back to the PM during the grill (`gh issue list --label enhancement --state open`), and the PM decides",
  "t1: the brief reads the file and open enhancement issues back",
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
  "**Two things reach the PM.** A **product call** — what the thing does, who it's for, what it says, what\nit costs someone using it — is the PM's, because nothing in the codebase implies the answer. A\n**one-way door** — deploying, publishing, a migration, a deletion, anything outward-facing or\nexpensive to undo — is the PM's too, because a wrong guess can't be walked back; the PM bot takes it\non to Justin when the escalation rule above says so, and a merge, deploy or publish always waits\nfor Justin, or Kai for kru (*Who acts at the door*, below).",
  "t2: product calls and one-way doors go to the PM bot, which escalates to Justin",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**A push is a one-way door, and most of the user's repos are public.** Read the repo's visibility\n(`gh repo view --json visibility`) before any push. A security fix stays local\nuntil the user OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` the session starts through the GitHub API, the workflow creating the tag\non its job token — the release is the session's to run end to end.",
  "**Who acts at the door.** You commit locally and return proof; the push is not yours. The PM bot\nreviews the proof, pushes the branch and opens the pull request. Merging, tagging, releasing,\ndeploying, publishing and any message outside the team wait for Justin — except kru's own releases,\nwhich Kai (kru's PM bot) merges and tags. A bug or want issue on the product repo is internal\ntracking, not a message outside the team (first section). Most product repos are public, so the PM bot reads the\nrepo's visibility (`gh repo view --json visibility`) before a push. A security fix stays local\nuntil Justin OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` started through the GitHub API, the workflow creating the tag on its\njob token — started by whoever owns that release: Justin, or Kai for kru.",
  "t2: Claude Code commits, the PM bot pushes and opens the PR, Justin merges/tags/deploys (Kai for kru)",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "   - *An ask to act* — running a command, logging in, approving a push — only when it can't be yours;\n     the exact thing to type and why, in one clause.",
  "   - *An ask to act* — running a command, logging in, a push or pull request (the PM bot's) — only when\n     it can't be yours; the exact thing to type and why, in one clause. A merge, deploy or release is\n     Justin's (Kai's for kru), and the PM bot carries it there.",
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
  "Justin (Kai for kru) just merged the PR, and the PM bot runs this.",
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
  "## Talk to a PM, not to an engineer\nYour reader is the PM bot. You report to it, never to Justin directly, and it forwards to Justin only\nwhat is blocked, ready for his approval, or done with proof — the escalation list in this skill's\nfirst section is the one source, and the PM bots' `policies.md` points at it. So every message is written to be\nforwarded as is: outcome first, plain words. The PM and Justin own the product, not the implementation.",
  "t5: the PM bot is the reader; the escalation list in the first section is the one source",
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

// --- t7: tracking split: security private, bugs/wants on GitHub, scratch in the store ---
EDITS.push(E(
  "TRACKER.md",
  "— **not** committed to the working repo, and **not** on GitHub Issues. This file **is** the \"tracker doc\" the vendored planning skills ask for — **do NOT run `/setup-matt-pocock-skills`**. When a vendored skill says \"the issue tracker should have been provided to you,\" or offers a GitHub/Linear path, use the file layout here — it is the skills' own **local-markdown path**, made canonical for this team.",
  "— **not** committed to the working repo. Bugs and product wants are tracked on the product repo's GitHub issues instead, and security findings stay private (*Where each thing is tracked*, below). This file **is** the \"tracker doc\" the vendored planning skills ask for — **do NOT run `/setup-matt-pocock-skills`**. When a vendored skill says \"the issue tracker should have been provided to you,\" or offers a GitHub/Linear path for a plan, a spec or tickets, use the file layout here — it is the skills' own **local-markdown path**, made canonical for this team.",
  "t7: bugs and wants move to GitHub issues; plans stay in the store",
))
EDITS.push(E(
  "TRACKER.md",
  "Why user-level files, not in-repo and not Issues: the working repo stays clean — **no management files in it, ever**: no `management/` dir, no `issues/`, no plan docs, briefs, or todo lists, and **no pointer in its `AGENTS.md`**.",
  "## Where each thing is tracked\n\n| what | where it goes | how |\n|---|---|---|\n| a **security or vulnerability** finding — anything an attacker could use: an auth bypass, data exposure, an injection, a leaked secret | the store's `issues/` (one file per finding), or a GitHub **private security advisory** on the product repo — **never a public issue** | `/kru-issue`, the lead's defect capture (Step 4.5) |\n| a **normal bug** or a **product want** | a **GitHub issue on the product repo** (`gh issue create`, labelled `bug` or `enhancement`), on the Agent Board (salasjustin's GitHub project #1), and closed by the pull request that fixes it (`Fixes #n`) | `/kru-issue`, `/kru-todo`, the lead's captures (Step 4.5) |\n| the team's **scratch todo** — a want the team turned up mid-task that nobody has asked for yet | the store's `TODOS.md` | the lead's todo capture (Step 4.5), `/kru-setup` |\n\nA repo with no GitHub remote, issues turned off, or no `gh` sign-in sends a bug to `issues/` and a want to `TODOS.md`, and the capture says so. Unsure whether a bug is security-shaped → treat it as one: a private file can be published later, a public issue can't be taken back.\n\n**Filing a bug or want issue is internal tracking, not an escalation.** It goes up on the team's own product repo without Justin's go-ahead, public repo or not: the lead files it at Step 4.5, the PM bot through `/kru-issue` and `/kru-todo` (`skills/kru-lead/SKILL.md`, first section). Only the security row stays private.\n\nWhy user-level files for the rest, not in-repo: the working repo stays clean — **no management files in it, ever**: no `management/` dir, no `issues/`, no plan docs, briefs, or todo lists, and **no pointer in its `AGENTS.md`**.",
  "t7: the three destinations in one table; the old not-Issues rationale goes",
))
EDITS.push(E(
  "TRACKER.md",
  "  TODOS.md                 # durable, cross-cutting — captured one-liners, untriaged",
  "  TODOS.md                 # the team's scratch todos (and wants with no GitHub repo) — one-liners, untriaged",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "  issues/                  # known defects — one file per bug, deleted when fixed",
  "  issues/                  # security findings (and bugs with no GitHub repo) — one file each, deleted when fixed",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "- **Todo capture** → a pitched or discovered want, out of scope for the current slice, appends **one line** to `TODOS.md`.",
  "- **Todo capture** → a pitched want (the PM's) out of scope for the current slice becomes a GitHub issue on the product repo; a discovered one (the team's scratch) appends **one line** to `TODOS.md` (*Where each thing is tracked*).",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "- **Defect capture** → a bug that isn't being fixed in this slice gets **its own file** under `issues/` (below), not a line in `TODOS.md`. Fixed it in the slice instead? **Delete** its file in the same change.",
  "- **Defect capture** → a bug that isn't being fixed in this slice becomes a GitHub issue on the product repo; a security finding gets **its own file** under `issues/` (below) — never a public issue. Fixed it in the slice instead? The pull request closes the issue (`Fixes #n`), or the same change **deletes** its file.",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "- **Todo closeout** → a slice that satisfies a parked want **deletes its line** from `TODOS.md`, same as a fix deletes its `issues/` file.",
  "- **Todo closeout** → a slice that satisfies a parked want **deletes its line** from `TODOS.md` (or closes its GitHub issue with `Fixes #n`), same as a fix deletes its `issues/` file.",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "**Three writers, one format.** Mid-task capture is the Step 4.5 sweep above (`pitched` when the user tossed it out, `discovered` when the team turned it up inside the effort in flight).",
  "**Three writers, one format.** Mid-task capture is the Step 4.5 sweep above (`discovered` when the team turned it up inside the effort in flight; a want the PM tossed out goes to a GitHub issue, and lands here as `pitched` only when the repo has none to file in).",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "The **`/kru-todo` skill** (`skills/kru-todo/`) is the user's direct front door for when there's no task running to sweep from: always `pitched`,",
  "The **`/kru-todo` skill** (`skills/kru-todo/`) is the PM's direct front door for when there's no task running to sweep from: it files a GitHub issue, and writes here only when the repo has no GitHub issues — always `pitched`,",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "**`issues/` — known defects, one file per bug.** A defect is something *wrong*: an incorrect result, false information shown to a user, or a failure of a condition the code claims to handle. Something merely *wanted* — a feature, a refactor, a cleanup, duplication, misfiled config — is a `TODOS.md` line, not an issue. The three-way split is the whole rule: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`.**",
  "**`issues/` — security findings, one file per finding.** A defect is something *wrong*: an incorrect result, false information shown to a user, or a failure of a condition the code claims to handle. A normal one goes to a GitHub issue on the product repo; this dir holds the security-shaped ones, which never go public, plus any bug from a repo with no GitHub issues to file in. Something merely *wanted* — a feature, a refactor, a cleanup, duplication, misfiled config — is a want, not a defect. The split is the whole rule: **wrong → a GitHub issue (security: `issues/`), wanted → a GitHub issue (the team's own scratch: `TODOS.md`), unformed → `notes/`.**",
  "t7: issues/ is for security findings",
))
EDITS.push(E(
  "references/store.md",
  "- **Project** — one project's plan of record: `TODOS.md`, `issues/`, `notes/`, `plan/`\n  (`TRACKER.md` owns its layout).",
  "- **Project** — one project's plan of record: `TODOS.md`, `issues/`, `notes/`, `plan/`\n  (`TRACKER.md` owns its layout).\n\nThe project root is the private half of tracking: security findings and the team's scratch todos live here, while normal bugs and product wants go to the product repo's GitHub issues. Which goes where is `TRACKER.md` → *Where each thing is tracked*.",
  "t7: the private half of tracking, pointing at TRACKER.md's table rather than copying it",
))
EDITS.push(E(
  "references/store.md",
  "session bookkeeping (`audit/`, `lead-gate/`). It follows the **user**, across every engagement.",
  "session bookkeeping (`audit/`, `lead-gate/`). It follows **Justin and the PM bots**, across every engagement.",
  "t6 (the line the ticket named): the store follows Justin and the PM bots",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "Write the defect file from what the user just told you and get out.",
  "Record the defect from what the PM just told you and get out — as a GitHub issue on the product repo, or, for a security finding, as a file in the store (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*).",
  "t7: kru-issue files normal bugs on GitHub, security ones in the store",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "2. **Glance at `issues/`** (`ls`, nothing more). Same defect already has a file → append the user's new detail to it and stop. One directory listing isn't investigation; two files for one bug is drift.\n3. **Write the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path issues/<kebab-slug>` names.** **No precondition**: create the dir if it isn't there.",
  "2. **Pick the destination from what you were told.** Security-shaped — anything an attacker could use: an auth bypass, data exposure, an injection, a leaked secret — or unsure → the store file (step 3 on). Otherwise a normal bug → a GitHub issue, when the product repo has one to file in (`gh repo view --json hasIssuesEnabled` answers true); else the store file, and the confirm line says why.\n   - **GitHub:** glance for the same bug (`gh issue list --state open --search \"<two words from the symptom>\"`, nothing more) — found → add the new detail as a comment (`gh issue comment <n>`) and stop. Else `gh issue create --label bug --title \"<the symptom, one line>\" --body \"<the template below, minus the frontmatter, with severity and urgency as its first line>\"`, adding `--project \"Agent Board\"` when the repo is on salasjustin's board (drop either flag if `gh` refuses it, and say so). Then step 5.\n3. **Glance at `issues/`** (`ls`, nothing more). Same defect already has a file → append the new detail to it and stop. One directory listing isn't investigation; two files for one bug is drift. Else **write the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path issues/<kebab-slug>` names.** **No precondition**: create the dir if it isn't there.",
  "t7: normal bug -> gh issue create; security -> the store",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "5. **Confirm in one line** — \"logged as <severity>, needed <urgency in words>; not looked into yet.\" No path.",
  "5. **Confirm in one line** — \"logged as <severity>, needed <urgency in words>; not looked into yet\", with the issue number when it went to GitHub, and no path when it went to the store.",
  "t7",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "The store's three-way split holds: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`**. Say in one line which you did.",
  "The split holds: **wrong → a GitHub issue (security: `issues/`), wanted → `/kru-todo`, unformed → `notes/`**. Say in one line which you did.",
  "t7",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "Filling the file in is a normal `/kru-lead <task>`; fixing it deletes the file in that same change, along with the repro test that replaces it (`lead` Step 4.5).",
  "Filling it in is a normal `/kru-lead <task>`; fixing it closes the issue (`Fixes #n` in the pull request) or deletes the file in that same change, along with the repro test that replaces it (`lead` Step 4.5).",
  "t7",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "Write the user's deferred want into the project's `TODOS.md` and get out.",
  "File the PM's deferred want and get out: as a GitHub issue on the product repo, or as a `TODOS.md` line when the repo has no GitHub issues to file in (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*).",
  "t7: product wants go to GitHub issues",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "2. **Append** to the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path todos` names. **No precondition**: create the dir and the file if they don't exist.",
  "2. **File it.** The product repo has GitHub issues (`gh repo view --json hasIssuesEnabled` answers true) → `gh issue create --label enhancement --title \"<the thing, one line>\" --body \"<the line's three scores and any sub-bullets, as written below>\"`, adding `--project \"Agent Board\"` when the repo is on salasjustin's board (drop either flag if `gh` refuses it, and say so). Otherwise **append** to the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path todos` names. **No precondition**: create the dir and the file if they don't exist.",
  "t7",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "4. **Confirm in one line** — echo the headline, how much it matters and how soon, in words (\"logged: <headline> — matters 3 of 5, needed within weeks\"). No path, no effort, no notation.",
  "4. **Confirm in one line** — echo the headline, how much it matters and how soon, in words (\"logged: <headline> — matters 3 of 5, needed within weeks\"), with the issue number when it went to GitHub. No path, no effort, no notation.",
  "t7",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "The store's three-way split holds: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`**.",
  "The split holds: **wrong → `/kru-issue`, wanted → a GitHub issue (or `TODOS.md` with none to file in), unformed → `notes/`**.",
  "t7",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "- **Todo capture** — any want the **user pitches** mid-task, or one the **team discovers inside the effort in flight** (filed with that `plan: <slug>`), that's out of scope for the current slice: append a one-line entry to `TODOS.md` at the store root and **keep going** — never derail the task to build it.",
  "- **Todo capture** — any want the **PM pitches** mid-task goes to a GitHub issue on the product repo, which you file yourself (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*); one the **team discovers inside the effort in flight** (filed with that `plan: <slug>`), out of scope for the current slice, is a one-line entry in `TODOS.md` at the store root. Either way **keep going** — never derail the task to build it.",
  "t7: capture picks the destination by the table",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "gets **its own file** at `issues/<kebab-slug>.md` in the store root — the team's defect list; a GitHub issue is filed with `gh` only when the user asks for one: `severity` frontmatter,",
  "goes to a **GitHub issue on the product repo** (`gh issue create --label bug`, written up as below), which you file yourself — internal tracking, not an escalation (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md`, first section) — unless it is security-shaped, which gets **its own file** at `issues/<kebab-slug>.md` in the store root and never a public issue (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*). The write-up: `severity` frontmatter,",
  "t7: normal bugs to GitHub, security to the store",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "**a slice that fixes a bug closes its file.** `ls issues/` and read the listing against what you just landed — every file whose defect this slice fixed is **deleted in that same change**",
  "**a slice that fixes a bug closes its record.** A GitHub issue closes through the pull request (`Fixes #n` in its description). For the store, `ls issues/` and read the listing against what you just landed — every file whose defect this slice fixed is **deleted in that same change**",
  "t7",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "**Walk `issues/` too — this is the dir's only reader.**",
  "**Walk the open bugs too: the repo's GitHub issues labelled `bug` (`gh issue list --label bug --state open`) and the store's `issues/`, the security ones — the brief is their only reader.** Each GitHub issue is read against the current code the same way; one the code has since fixed is named in the brief for the PM bot to close, not closed by you.",
  "t7: brief walks the repo's open issues as well as the store's security files",
))

// --- t7: (cont.) the listing verbs read GitHub issues ------------------------
EDITS.push(E(
  "skills/kru-issues/SKILL.md",
  "Membership is the status: a file exists until the change that fixes its bug deletes it, so an empty dir is a true *no known defects*.",
  "Membership is the status: a file exists until the change that fixes its bug deletes it, so an empty dir is a true *no known defects*.\n\nNormal bugs live on the product repo's GitHub issues (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*), so `issues/` holds the security findings and any bug from a repo with no GitHub issues. When the repo has them, the open ones labelled `bug` (`gh issue list --label bug --state open --json number,title,body`) run through the same steps beside the files: reconciled, scored and proposed alike, a verified-fixed one named for the PM bot to close rather than closed by you, and a fix carrying `Fixes #n` in its commit so the merge closes it.",
  "t7: the defect verb reads GitHub issues too",
))
EDITS.push(E(
  "skills/kru-todos/SKILL.md",
  "This is the one verb where a filed want meets the codebase:",
  "Product wants live on the product repo's GitHub issues (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*); when the repo has them, the open ones labelled `enhancement` (`gh issue list --label enhancement --state open --json number,title,body`) run through the same steps beside the file's lines — a landed one closed by `Fixes #n` in its commit, a verified-done one named for the PM bot to close. This is the one verb where a filed want meets the codebase:",
  "t7: the want verb reads GitHub issues too",
))

// --- t10: seat prompts say PM where they mean the requester ------------------
EDITS.push(E(
  "agents/ui-designer.md",
  "Claude Design decides the look inside the frame you draft; the user decides whether it's any good.",
  "Claude Design decides the look inside the frame you draft; the PM decides whether it's any good.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "and the user judging a canvas drawn in its happy state.",
  "and the PM judging a canvas drawn in its happy state.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "You are one of them: paid in the direction the user picks,",
  "You are one of them: paid in the direction the PM picks,",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "**2–4 genuinely different directions** for the user to pick one they can see",
  "**2–4 genuinely different directions** for the PM to pick one it can see",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "- **You have no user channel.** The `design` skill asks one design question",
  "- **You have no channel to the PM.** The `design` skill asks one design question",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "and hand the question up in your return for the lead to put to the user.",
  "and hand the question up in your return for the lead to put to the PM.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "The look is settled and it's the user's —",
  "The look is settled and it's the PM's —",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "- **The look is Claude Design's and the verdict is the user's.**",
  "- **The look is Claude Design's and the verdict is the PM's.**",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ui-designer.md",
  "the design question for the user;",
  "the design question for the PM;",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ux-designer.md",
  "(`/design`, or the user's own claude.ai/design session)",
  "(`/design`, or the PM's own claude.ai/design session)",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ux-designer.md",
  "you have no Bash, no Write and no user channel, and the look was never yours.",
  "you have no Bash, no Write and no channel to the PM, and the look was never yours.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ux-designer.md",
  "Whether it looks good is the user's call",
  "Whether it looks good is the PM's call",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/ux-designer.md",
  "- You run as a subagent and have no user channel.",
  "- You run as a subagent and have no channel to the PM.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/web-components-builder.md",
  "the lead carries it to the user.",
  "the lead carries it to the PM.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/web-components-builder.md",
  "not from asking the user — you have no user channel, so the **`tdd`** skill's",
  "not from asking the PM — you have no channel to it, so the **`tdd`** skill's",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/web-components-builder.md",
  "the rendered design gate is the user's look,",
  "the rendered design gate is the PM's look,",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/visual-reviewer.md",
  "that's the **user's** `/kru-visual-review` front door,",
  "that's the **PM's** `/kru-visual-review` front door,",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/visual-reviewer.md",
  "- **You have no user channel, so report-only is absolute.**",
  "- **You have no channel to the PM, so report-only is absolute.**",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "agents/visual-reviewer.md",
  "so the lead can ask the user to start it.",
  "so the lead can ask the PM to start it.",
  "t10: the requester is the PM; end-user lines untouched",
))

// --- t11: small ownership fixes ----------------------------------------------
EDITS.push(E(
  "skills/kru-update/SKILL.md",
  "- **Consider** — the only verdict the user is asked about; the action verdicts run through `/kru-roster` without a question. Real value at a cost the user decides:",
  "- **Consider** — the only verdict that goes to Kai (kru's PM bot) first; the action verdicts run through `/kru-roster` without a question. Real value at a cost someone has to decide — Kai does, and takes it on to Justin when it is on the escalation list (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md`, first section):",
  "t11: Consider goes to Kai first",
))
EDITS.push(E(
  "TRACKER.md",
  "It's the one artifact with no capture rule: the user writes it, and the lead only when asked to keep something they thought out loud.",
  "It's the one artifact with no capture rule: the PM bot and Justin write it, and the lead only when asked to keep something one of them thought out loud.",
  "t11: notes/ writers are the PM bot and Justin",
))
EDITS.push(E(
  "TRACKER.md",
  "Who writes it: the **user**, mostly, and the lead when the user thinks out loud and asks for it to be kept.",
  "Who writes it: the **PM bot and Justin**, mostly, and the lead when either thinks out loud and asks for it to be kept.",
  "t11: notes/ writers are the PM bot and Justin",
))

// --- review fixes (PR 4) ------------------------------------------------------
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "something merely *wanted* stays a `TODOS.md` capture.",
  "something merely *wanted* is a want, captured by the todo bullet above (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*).",
  "t7: a want follows the routing table, not always TODOS.md",
))
EDITS.push(E(
  "agents/ux-designer.md",
  "the lead takes it to the user.",
  "the lead takes it to the PM.",
  "t10: the requester is the PM; end-user lines untouched",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "Nothing on disk answers step 1, so the user does, and the sheet is written from the **decision**. Load\n**`grilling`**; its rounds are these three:",
  "Nothing on disk answers step 1, so the user does, and the sheet is written from the **decision**. Headless\n(`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), the brief's answers\nare the rounds: take the subject and the lanes it settles, deploy on those, and put each lane it left\nopen under **Questions for the PM** with your recommendation instead of a round. Otherwise load\n**`grilling`**; its rounds are these three:",
  "t3: a headless blank-repo setup never waits on the grill",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "words, with what dropping it would cost. Everything the answer can't touch is written already.",
  "words, with what dropping it would cost. Everything the answer can't touch is written already.\nHeadless (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), keep the\nrule and return the question under **Questions for the PM**.",
  "t3: a headless setup keeps a hand-written rule rather than waiting to ask",
))

// --- review fixes (PR 4, round 2) ------------------------------------------
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "The store's existing `plan/<effort>/brief.md` (if you're re-grilling an effort), `TODOS.md` (the captured, untriaged one-liners), and the store's `notes/` (freeform brainstorming — **input, never authority**: cite it as *\"there's a note that says…\"*, never as a decision, and never let it override the brief, the repo's docs, or the user).\n\nBring them back to the user during the grill: an old brief's open threads get re-decided, and a `TODOS.md` line is either pulled into this change's scope or left where it is. Order them **`value × urgency ÷ effort`** the way `/kru-todos` ranks them — what matters, soon, for little work first, a `~n` ranked as filed, legacy lines with no digits after — and note the ones filed 90+ days ago or against a `plan/<slug>/` that's since been archived (\"may be out of date\"), since those are the lines most likely to be asking for a codebase that no longer exists. To the user, each surfaces as the want in plain words — what someone using the product would get — in that order, with no digits, tildes, ages or scoring notation. That ordering is arithmetic over filed numbers, not a triage: you don't triage `TODOS.md` on your own — you surface it and the user calls it.",
  "The store's existing `plan/<effort>/brief.md` (if you're re-grilling an effort), `TODOS.md` (the captured, untriaged one-liners), the product repo's open GitHub issues labelled `enhancement` (`gh issue list --label enhancement --state open`), and the store's `notes/` (freeform brainstorming — **input, never authority**: cite it as *\"there's a note that says…\"*, never as a decision, and never let it override the brief, the repo's docs, or the user).\n\nBring them back to the user during the grill: an old brief's open threads get re-decided, and a `TODOS.md` line or an open `enhancement` issue is either pulled into this change's scope or left where it is. Order them **`value × urgency ÷ effort`** the way `/kru-todos` ranks them — what matters, soon, for little work first, an `enhancement` issue on the three scores in its body, a `~n` ranked as filed, legacy lines with no digits after — and note the ones filed 90+ days ago or against a `plan/<slug>/` that's since been archived (\"may be out of date\"), since those are the lines most likely to be asking for a codebase that no longer exists. To the user, each surfaces as the want in plain words — what someone using the product would get — in that order, with no digits, tildes, ages or scoring notation. That ordering is arithmetic over filed numbers, not a triage: you don't triage `TODOS.md` or the open `enhancement` issues on your own — you surface them and the user calls it. One the code has since grown is named for the PM bot to close, not closed by you.",
  "review: a brief reads open enhancement issues back with the parking lot",
))
EDITS.push(E(
  "skills/kru-todos-loop/SKILL.md",
  "- **Queue**: `todos` §1 and §2 over the whole file, its §4 bookkeeping, ranked by its §3 order.\n- **Eligible**: open, `value` `3`–`5`, `effort` `1`–`3`, and `pitched`. A `discovered` line is the team's own capture and waits for the user to pull it, per `todos` → *Guardrails*; count it with the unreached. A `~` value is the team's guess at what the user wants, so it qualifies only at `4`–`5`.",
  "- **Queue**: `todos` §1 and §2 over the whole file and the product repo's open GitHub issues labelled `enhancement` (`gh issue list --label enhancement --state open`), its §4 bookkeeping, ranked by its §3 order.\n- **Eligible**: open, `value` `3`–`5`, `effort` `1`–`3`, and `pitched`. A GitHub `enhancement` issue is a want the PM filed, so it counts as `pitched`, and its `value`, `urgency` and `effort` are the digits in its body. A `discovered` line is the team's own capture and waits for the user to pull it, per `todos` → *Guardrails*; count it with the unreached. A `~` value is the team's guess at what the user wants, so it qualifies only at `4`–`5`.",
  "review: the want loop queues GitHub enhancement issues and counts each as pitched",
))
EDITS.push(E(
  "skills/kru-issues-loop/SKILL.md",
  "- **Queue**: `issues` §1 and §2 over the whole dir, its §4 bookkeeping, ranked by its §3 order.",
  "- **Queue**: `issues` §1 and §2 over the whole dir and the product repo's open GitHub issues labelled `bug` (`gh issue list --label bug --state open`), its §4 bookkeeping, ranked by its §3 order.",
  "review: the defect loop queues GitHub bug issues with the store dir",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "a `~` number is a proposal awaiting their read — if the user confirms or corrects it, rewrite that line in place with the bare digit and stop.",
  "a `~` number is a proposal awaiting their read — if the user confirms or corrects it, write the bare digit back and stop: `gh issue edit <n> --body` when the want is a GitHub issue, or rewrite that line in place when it is a `TODOS.md` line.",
  "review: a confirmed score on a GitHub want is gh issue edit, not a line rewrite",
))
EDITS.push(E(
  "skills/kru-todos/SKILL.md",
  "No answer → say so in one line and return to whatever was in flight.\n\n## 5. Land what they picked",
  "No answer → say so in one line and return to whatever was in flight.\n\nHeadless (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), return the batch under *Questions for the PM*; `/kru-todos-loop` pays this gate in advance.\n\n## 5. Land what they picked",
  "review: headless returns the batch; the loop pays the gate in advance",
))
EDITS.push(E(
  "skills/kru-issues/SKILL.md",
  "No answer → say so in one line and return to whatever was in flight.\n\n## 5. Fix what they picked",
  "No answer → say so in one line and return to whatever was in flight.\n\nHeadless (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), return the batch under *Questions for the PM*; `/kru-issues-loop` pays this gate in advance.\n\n## 5. Fix what they picked",
  "review: headless returns the batch; the loop pays the gate in advance",
))
EDITS.push(E(
  "skills/kru-briefs/SKILL.md",
  "No answer → say so in one line and return to whatever was in flight.\n\n## 3. Apply what they picked",
  "No answer → say so in one line and return to whatever was in flight.\n\nHeadless (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *A headless run never waits*), return the batch under *Questions for the PM*. `/kru-todos-loop` and `/kru-issues-loop` pay their own gates in advance; this pick stays in that return.\n\n## 3. Apply what they picked",
  "review: headless returns the batch; a brief has no loop that pays the gate",
))

// the port's cloud probe also treats /run/cursor/api.sock as a cloud vm, which
// the test cannot hide. KRU_CLOUD=0 is an explicit off, and the default under
// test, so a host socket does not flip the non-cloud cases; KRU_CLOUD=1 still
// overrides it.
EDITS.push(E(
  "scripts/kru-store.test.sh",
  "parent shell can't make a case pass for the wrong reason.",
  "parent shell can't make a case pass for the wrong reason.\n# KRU_CLOUD=0 is the default so a host /run/cursor/api.sock does not flip these\n# cases; a case that passes KRU_CLOUD=1 overrides it.",
  "review: the store test states why KRU_CLOUD=0 is the default",
))
EDITS.push(E(
  "scripts/kru-store.test.sh",
  "    HOME=\"$home\" ${envs[@]+\"${envs[@]}\"} bash \"$store\" \"${args[@]}\" 2>&1)",
  "    HOME=\"$home\" KRU_CLOUD=0 ${envs[@]+\"${envs[@]}\"} bash \"$store\" \"${args[@]}\" 2>&1)",
  "review: store tests default to not-cloud so the host agent socket cannot flip them",
))
