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

// --- t1: the PM briefs the session; the owner approves ----------------
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "You are the engineering lead. **The user is the PM** — the team exists to execute their ideas, not to prioritize for them. You run",
  "You are the engineering lead. **The PM is the bot or person that briefed this session**, and **the owner approves** hard-to-reverse calls above it; the owner's word outranks a PM's. The PM bot's own operating rules govern escalation and approval, and the plugin's generic default applies only when the PM has none (the next paragraph). This sentence is the definition the rest of the team points at: below, *the user* and *the PM* both mean that PM, and the owner is named wherever only the owner acts. The team exists to execute the PM's brief, not to prioritize for it. You run",
  "t1: the PM is the bot or person that briefs the session; the owner approves",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "You scope, route, delegate, integrate, verify, and report.\n\n**Capture, listing,",
  "You scope, route, delegate, integrate, verify, and report.\n\n**The PM decides; the owner hears only a hard-to-reverse call.** The PM is the bot or person that briefed this session. A PM makes the calls it is handed by default, records why, and keeps going. The PM bot's own operating rules govern escalation and approval. The plugin's generic default applies only when the PM has none: escalate to the owner only a call that is hard to reverse or reaches outside the team — money (billing, pricing, spend), legal or compliance (terms, privacy, licensing), user impact (a change customers, clients or users need a heads-up about), security or data exposure, anything public or live, product direction (a change of direction or strategy), and any new outside account or service, free trials included. The owner decides that last one, and the account setup itself goes through ops. A call that fits none of these but would be costly to guess wrong goes to the owner too. Everything else the PM answers, including your grill. **Not an escalation:** a bug or want on the work tracker is internal tracking — GitHub issues on the product repo, or Linear when `KRU_TRACKER=linear` (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`) — public repo or not. The lead files it itself at Step 4.5, the PM bot through `/kru-issue` and `/kru-todo` (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*). A security finding goes to Linear when the tracker is Linear, internal to the team. bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand. It never goes to a public GitHub issue; on GitHub it stays in the store's `issues/` or a GitHub private security advisory.\n\n**Capture, listing,",
  "t1: the escalation default, one source the other files point at",
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
  "roadmaps, prioritization, and what-to-build-next are the PM's, under the owner.",
  "t1",
))
EDITS.push(E(
  "TRACKER.md",
  "no priority scores — the **user is the PM** and brings the subject;",
  "no priority scores — the **PM** (the PM bot that briefs the session, with the owner approving hard-to-reverse calls — `skills/kru-lead/SKILL.md`, first paragraph) brings the subject;",
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
  "`pitched` = the PM or the owner (`skills/kru-lead/SKILL.md`, first paragraph), `discovered` = team",
  "t1: pitched is the PM or the owner",
))
EDITS.push(E(
  "TRACKER.md",
  "the next `brief` verb run reads the file back to the user during the grill, and the user (the PM) decides",
  "the next `brief` verb run reads the file and the open wants back to the PM during the grill (Linear MCP `list_issues` when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind want`), and the PM decides",
  "t1: the brief reads the file and open enhancement issues back",
))
EDITS.push(E(
  "TRACKER.md",
  "governs scoring: the user's own words win and are filed bare;",
  "governs scoring: the PM's own words win and are filed bare (the owner's over a PM's when they differ);",
  "t1: the owner's words outrank a PM's",
))
EDITS.push(E(
  "ROSTER.md",
  "**The user is the PM** — there is no product-management function, no roadmap, and no prioritization framework in the team; what-to-build-next is the user's call,",
  "**The PM is the PM bot that briefs the session, with the owner approving hard-to-reverse calls** (`skills/kru-lead/SKILL.md`, first paragraph) — there is no product-management function, no roadmap, and no prioritization framework in the team; what-to-build-next is the PM's call,",
  "t1",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "There is **no roadmap, no prioritization framework, and no PM pass** — the user is the PM and brings\nthe subject.",
  "There is **no roadmap, no prioritization framework, and no PM pass** — the PM (the PM bot that\nbriefed the session, under the owner: `skills/kru-lead/SKILL.md`, first paragraph) brings the subject.",
  "t1",
))

// --- t1: (cont.) the remaining 'user is the PM' lines ------------------------
EDITS.push(E(
  "SOURCES.md",
  "**The user is the PM**: no roadmap,",
  "**The PM brings the subject** (the PM that briefed the session, under the owner): no roadmap,",
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
  "**Two things reach the PM.** A **product call** — what the thing does, who it's for, what it says, what\nit costs someone using it — is the PM's, because nothing in the codebase implies the answer. A\n**one-way door** — deploying, publishing, a migration, a deletion, anything outward-facing or\nexpensive to undo — is the PM's too, because a wrong guess can't be walked back; the PM takes it\non to the owner when the PM's own operating rules say so, or under the plugin's generic default when the PM has none, and a merge, deploy or publish always waits\nfor the owner, or the plugin maintainer for this plugin (*Who acts at the door*, below).",
  "t2: product calls and one-way doors go to the PM, which escalates to the owner",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**A push is a one-way door, and most of the user's repos are public.** Read the repo's visibility\n(`gh repo view --json visibility`) before any push. A security fix stays local\nuntil the user OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` the session starts through the GitHub API, the workflow creating the tag\non its job token — the release is the session's to run end to end.",
  "**Who acts at the door.** You commit locally and return proof; the push is not yours. The PM bot\nreviews the proof, pushes the branch and opens the pull request. Merging, tagging, releasing,\ndeploying, publishing and any message outside the team wait for the owner — except this plugin's own releases,\nwhich the plugin maintainer merges and tags. A bug or want on the work tracker (GitHub issues, or Linear when the repo has opted in) is internal\ntracking, not a message outside the team (first section). Pull requests stay on GitHub either way: the body\ncarries the line `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` prints. Most product repos are public, so the PM bot reads the\nrepo's visibility (`gh repo view --json visibility`) before a push. A security fix stays local\nuntil the owner OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR and off Linear. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` started through the GitHub API, the workflow creating the tag on its\njob token — started by whoever owns that release: the owner, or the plugin maintainer for this plugin.",
  "t2: the lead commits, the PM pushes and opens the PR, the owner merges (the plugin maintainer for this plugin)",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "description: How this engineering team works — load before building, reviewing or dispatching any seat. Also the entry for a project from scratch and for planning work past one context.",
  "description: How this engineering team works — load before building, reviewing or dispatching any seat. Also the entry for a project from scratch and for planning work past one context. Opening or owning a pull request runs the PR babysit loop.",
  "pr-babysit: the always-loaded description fires when a cloud agent opens or owns a PR",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "job token — started by whoever owns that release: the owner, or the plugin maintainer for this plugin.",
  "job token — started by whoever owns that release: the owner, or the plugin maintainer for this plugin.\n\n**PR babysit loop.** A cloud agent that opens a pull request, or already owns one, subscribes to its\nreviews, comments, and CI, then ends the turn. The next pass starts when one of those wakes you: fix a\nvalid finding, reply on each thread — say why when the finding stands — and push. Clean means CI green\nand every review thread from whatever reviewers the repo has answered. Where Greptile reviews the repo\n(today only AngelProtocolFinance/better-giving), clean also means no Greptile P0 or P1 still open.\nNever wait for a Greptile score in a repo Greptile does not review. Then tell the PM that requested\nthe work that it is ready to merge. That is the loop's only outward message; the owner merges.",
  "pr-babysit: one loop, in the lead contract cloud-skills.sh installs",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "   - *An ask to act* — running a command, logging in, approving a push — only when it can't be yours;\n     the exact thing to type and why, in one clause.",
  "   - *An ask to act* — running a command, logging in, a push or pull request (the PM bot's) — only when\n     it can't be yours; the exact thing to type and why, in one clause. A merge, deploy or release is\n     the owner's (the plugin maintainer's for this plugin), and the PM carries it there.",
  "t2: no line asks a human to approve a push",
))
EDITS.push(E(
  "skills/kru-roster/SKILL.md",
  "| 9 | git | `commit` + `tag vX.Y.Z` — **only when the user asks** (team git rule) |",
  "| 9 | git | `commit` locally when the PM asks; the PM bot pushes and opens the pull request; merging and `tag vX.Y.Z` are the plugin maintainer's — the plugin maintainer owns this plugin's releases (`skills/kru-lead/SKILL.md` → *Who acts at the door*) |",
  "t2: this plugin's releases are the plugin maintainer's",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "clause (\"plus 6 cleanups to the project notes\"); the diff is there if asked.",
  "clause (\"plus 6 cleanups to the project notes\"); the diff is there if asked. Setup commits at most\nlocally: the PM bot reviews the diff, pushes it and opens the pull request, and the owner merges it\n(`skills/kru-lead/SKILL.md` → *Who acts at the door*).",
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
  "- Design work: **the gate is the PM bot's eye, and there is no substitute for it** — it judges the screenshots and paths in your Proof block, and takes the call to the owner only when it can't judge it",
  "t4: design conformance goes to the PM, the owner only if the PM can't judge",
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
  "The owner (the plugin maintainer, for this plugin) just merged the PR, and the PM runs this.",
  "t4: the PM runs /kru-landed after the owner merges",
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
  "## Talk to a PM, not to an engineer\nYour reader is the PM. You report to the PM, never to the owner directly, and the PM forwards to the owner only\nwhat that PM's own operating rules say to escalate. The plugin's generic default applies only when the PM has none —\nthe escalation list in this skill's first section. So every message is written to be\nforwarded as is: outcome first, plain words. The PM and the owner own the product, not the implementation.",
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
  "1. **The owner or the PM, explicitly** — `/kru-remember <what they liked>`, sourced `owner` or `pm`. **Two channels, one each:** how a PM bot itself operates stays in that PM bot's own operating rules, never here; the engineering practice the seats should carry comes here. Only the PM-to-lead loop counts as input. The PM bot's own operating rules govern escalation and approval; the plugin's generic default applies only when the PM has none (`skills/kru-lead/SKILL.md`, first section): a `pm` line is a proposal, and the owner's words outrank it. Never inferred from approval; the team does not guess.",
  "t6: two preference channels, one each; PM-bot lines are proposals",
))
EDITS.push(E(
  "PREFERENCES.md",
  "- [design] prefers bento-grid hero over centered-stack — _user · acme-site · 2026-07-21_\n- [code] approved Result<T,E> returns over throwing at call boundaries — _agent:sveltekit-builder · acme-site · 2026-07-21_\n- [workflow] wants the plan grilled before any build, always — _user · acme-site · 2026-07-21_\n- [design] liked this pricing table → patterns/pricing-3col.md — _user · acme-site · 2026-07-21_",
  "- [design] prefers bento-grid hero over centered-stack — _owner · acme-site · 2026-07-21_\n- [code] approved Result<T,E> returns over throwing at call boundaries — _agent:sveltekit-builder · acme-site · 2026-07-21_\n- [workflow] wants the plan grilled before any build, always — _pm · acme-site · 2026-07-21_\n- [design] liked this pricing table → patterns/pricing-3col.md — _owner · acme-site · 2026-07-21_",
  "t6: the source tags",
))
EDITS.push(E(
  "PREFERENCES.md",
  "- **source** `user`, `agent:<seat-slug>`, or `setup` — who captured it",
  "- **source** `owner`, `pm`, `agent:<seat-slug>`, or `setup` — who captured it (a bare `user` from before the split reads as `owner`)",
  "t6",
))
EDITS.push(E(
  "PREFERENCES.md",
  "Nothing is committed, so the uncommitted diff is the user's review.",
  "Nothing is committed: the plugin maintainer reviews the uncommitted diff from a checkout of this plugin, then commits, pushes, opens the pull request, merges and tags (the plugin maintainer owns this plugin's releases).",
  "t6: learn's review and release are the plugin maintainer's",
))
EDITS.push(E(
  "PREFERENCES.md",
  "(run from the plugin source repo; decides, user reviews the diff)",
  "(run from the plugin maintainer's checkout of this plugin; the plugin maintainer decides and reviews the diff)",
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
  "Source is `owner` for the owner's words and `pm` for a PM's — a PM's line is a proposal, and the owner's words outrank it at the sweep. Agents append their own lines directly, per the lead's handoff.",
  "t6: the source tag accepts pm:<bot>",
))
EDITS.push(E(
  "skills/kru-remember/SKILL.md",
  "- Don't promote it now — capture is lossless and untriaged; the sweep is the gated step that edits the team.",
  "- Don't promote it now — capture is lossless and untriaged; the sweep is the gated step that edits the team.\n- How a PM bot itself operates is not a team preference: it stays in that PM bot's own operating rules, never here. This inbox takes what the seats should carry.",
  "t6: two channels",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "The review is the uncommitted diff — commit stays the user's, so an edit they disagree with is reverted before it ships.\n\nRun this **from the plugin source repo** (it commits the plugin), not a product repo.",
  "The review is the uncommitted diff — the plugin maintainer's, so an edit they disagree with is reverted before it ships.\n\nRun this **from the plugin maintainer's checkout of this plugin** (it changes the plugin), not a product repo. The plugin maintainer reviews the diff, commits, pushes, opens the pull request, merges and tags — the plugin maintainer owns this plugin's releases. The owner's words (`owner`) outrank a PM's (`pm`) in every verdict below.",
  "t6: learn runs from the plugin maintainer's checkout; the owner outranks",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "- **Put it to the user** when a `user`-sourced line contradicts a rule the plugin states — the conflict is resolved at its source, not won by the standing text. It becomes a numbered question in the report (keep the rule, or change it to the line) and stays in the inbox, deferred, until the user answers.",
  "- **Put it to the source** when an `owner`-sourced line contradicts a rule the plugin states — the conflict is resolved at its source, not won by the standing text. It becomes a numbered question in the report for the plugin maintainer to carry to the owner (keep the rule, or change it to the line) and stays in the inbox, deferred, until the owner answers. A `pm` line contradicting a stated rule or an `owner` line is a proposal that lost: drop it with the reason.",
  "t6: the owner's lines outrank a PM's",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "Leave `commit`+`tag` to the user (git rule).",
  "`commit`, push, pull request, merge and `tag` are the plugin maintainer's (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "t6",
))
EDITS.push(E(
  "hooks/check-handoff.sh",
  "(the user rejected X twice and chose Y)",
  "(the PM or the owner rejected X twice and chose Y)",
  "t6",
))
EDITS.push(E(
  "references/store.md",
  "the half that is supposed to follow the user rather",
  "the half that is supposed to follow the owner and the PM rather",
  "t6",
))

// --- t6: (cont.) learn's report ----------------------------------------------
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "questions (each user line against the rule it contradicts), deferred — as a list numbered 1, 2, 3 the user can answer by item.",
  "questions (each `owner` line against the rule it contradicts), deferred — as a list numbered 1, 2, 3 the plugin maintainer can answer, or carry to the owner, by item.",
  "t6",
))

// --- t7: tracking split: security private, bugs/wants on GitHub, scratch in the store ---
EDITS.push(E(
  "TRACKER.md",
  "— **not** committed to the working repo, and **not** on GitHub Issues. This file **is** the \"tracker doc\" the vendored planning skills ask for — **do NOT run `/setup-matt-pocock-skills`**. When a vendored skill says \"the issue tracker should have been provided to you,\" or offers a GitHub/Linear path, use the file layout here — it is the skills' own **local-markdown path**, made canonical for this team.",
  "— **not** committed to the working repo. Bugs and product wants are tracked on the work tracker (`scripts/kru-tracker.sh`) instead — GitHub issues unless the repo sets `KRU_TRACKER=linear` — and security findings stay private (*Where each thing is tracked*, below). This file **is** the \"tracker doc\" the vendored planning skills ask for — **do NOT run `/setup-matt-pocock-skills`**. When a vendored skill says \"the issue tracker should have been provided to you,\" or offers a GitHub/Linear path for a plan, a spec or tickets, use the file layout here — it is the skills' own **local-markdown path**, made canonical for this team. `KRU_TRACKER` does not move a spec, a map or a plan ticket onto Linear.",
  "t7: bugs and wants move to GitHub issues; plans stay in the store",
))
EDITS.push(E(
  "TRACKER.md",
  "Why user-level files, not in-repo and not Issues: the working repo stays clean — **no management files in it, ever**: no `management/` dir, no `issues/`, no plan docs, briefs, or todo lists, and **no pointer in its `AGENTS.md`**.",
  "## Where each thing is tracked\n\n| what | where it goes | how |\n|---|---|---|\n| a **security or vulnerability** finding — anything an attacker could use: an auth bypass, data exposure, an injection, a leaked secret | the store's `issues/` (one file per finding), or, on the GitHub tracker, a GitHub **private security advisory** on the product repo (and that advisory's private fork) — **never a public issue**. On the Linear tracker, a Linear issue (`*Security on Linear*`, below): label `security`, on `KRU_LINEAR_SECURITY_TEAM` when set, otherwise the main team. What is written follows *Tracker text* | `/kru-issue`, the lead's defect capture (Step 4.5) |\n| a **normal bug** or a **product want** | the **work tracker** (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`). Unset, empty, or `KRU_TRACKER=github`: a GitHub issue on the product repo, labelled `bug` or `enhancement`. `KRU_TRACKER=linear`: a Linear issue on team key `KRU_LINEAR_TEAM` in the project named `KRU_LINEAR_PROJECT`, labelled the same way. Prefer the connected Linear MCP tools (`TRACKER.md` → *Linear MCP*); `LINEAR_API_KEY` is optional. The pull request stays on GitHub either way | `/kru-issue`, `/kru-todo`, the lead's captures (Step 4.5) |\n| the team's **scratch todo** — a want the team turned up mid-task that nobody has asked for yet | the store's `TODOS.md` | the lead's todo capture (Step 4.5), `/kru-setup` |\n| the **in-session board** — the lead's running worklist | the agent's todo list (always on in Cursor) | the lead skill. Not the work tracker |\n| an effort's **spec, map and execution tickets** | `plan/<effort>/` in the store | `planner`, `/kru-to-spec`, `/kru-to-tickets`, `/kru-wayfinder`. Not the work tracker, even when `KRU_TRACKER=linear` |\n\n**The work tracker.** GitHub (`KRU_TRACKER` unset, empty, or `github`) files, lists, updates, comments and closes through `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`. Linear (`KRU_TRACKER=linear`) prefers the connected Linear MCP tools when this session has them. The script's API is the fallback, and `LINEAR_API_KEY` is optional — never commit one, and never read one from a plugin option. `backend` prints `github` or `linear`. `link --id` always goes through the script: it prints `Fixes #<n>` or `Linear: <id>` and needs no key. On the GitHub tracker, `--kind security` is refused (exit 3). On Linear it is filed (*Security on Linear*).\n\n**Tracker text.** bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand\n\nA comment or an update on a security issue stays pointer-only, including when `--kind security` is given. In a security title, body, comment, or update the script refuses these anywhere, not only as headings: reproduc, steps to, repro, root cause, exploit, poc, proof of concept, payload, or an HTTP method followed by a path.\n\n**Linear settings are a team key and a project name.** For example `KRU_LINEAR_TEAM=BG` and `KRU_LINEAR_PROJECT=Connector`. Those values belong to the repo; this plugin hard-codes none. An id is only for a name that is not unique. `KRU_LINEAR_SECURITY_TEAM` (for example `SEC`) is optional and files security findings on that team.\n\n**Linear MCP, when those tools are connected.** Use them. Do not call the script for file, list, search, comment, update, close, list-effort or show, and do not require `LINEAR_API_KEY`. A missing key is not a reason to fall back to the store. Pass `team` the team key and `project` the project name. Label `bug` for a bug and `enhancement` for a want. A security finding follows *Security on Linear*, not those labels. What you send follows *Tracker text*. Skip completed and canceled issues, except a `/kru-brief` re-run, which keeps both: include completed and canceled issues whose description contains `plan/<effort>/brief.md`. A canceled issue is never treated as done. Keep the identifier (a shape like `ABC-123`).\n- **file** — `save_issue` with `team`, `project`, `title`, `description`, and `labels`.\n- **search** — `list_issues` with `team`, `project`, `label`, and `query`.\n- **list** — `list_issues` with `team`, `project`, and `label`.\n- **comment** — `save_comment` with `issueId` (the identifier) and `body`. A comment on a security issue stays pointer-only.\n- **update** — `save_issue` with `id` and `description`. An update on a security issue stays pointer-only.\n- **close** — `save_issue` with `id` and `state` `Done`.\nThe pull request still gets the line `link --id` prints. Merge does not close a Linear issue, so the landing slice closes it: MCP `state` `Done`, or the script's `close --id` when MCP is absent.\n\n**Security on Linear.** This applies only when `backend` is `linear`. The GitHub tracker is unchanged: the finding stays in the store's `issues/` or a GitHub private security advisory, and `--kind security` is refused. On Linear, file it with the label `security`. Team is `KRU_LINEAR_SECURITY_TEAM` when set, and then there is no product project. Unset, the team is `KRU_LINEAR_TEAM` and the project is `KRU_LINEAR_PROJECT`. MCP: `save_issue` with `team`, `title`, `description`, and `labels: [\"security\"]`, plus `project` only on that fallback. The script: `file --kind security`. What you send follows *Tracker text*. A comment or an update on that issue stays pointer-only too.\n\n**The script, when MCP is not connected.** `ready` exits 0 when this process can file: GitHub, or Linear with `LINEAR_API_KEY` plus a team key and a project name the API can resolve. Exit 4 means fall back — a bug to `issues/`, a want to `TODOS.md` — and the capture repeats the reason. `file` prints the id and the url separated by a tab. `list` and `search` print a JSON array of `{id, title, body, url}`. `comment`, `update` and `close` take `--id` and print the id. A missing key is exit 4 only on this path. `list-effort --brief plan/<effort>/brief.md` prints `{id, title, body, url, state}` for every issue whose body contains that path, following the cursor until it ends — GitHub search ignores `/` and `.`, so the page size applies before the exact path check — completed and canceled included (`state` is `open`, `done`, or `canceled`). A GitHub issue closed as not_planned is `canceled`; any other closed issue is `done`. `show --id` strips a leading `#` and uppercases a Linear identifier, then prints one issue in that shape. Exit 1 and the text `no such issue` means the id does not exist. Exit 5 is auth, network, or a tool error: stop and report it, and do not treat the id as missing. `list-effort` runs the path through the outbound guard before `gh` or the API.\n\nA repo whose tracker is not ready — no GitHub remote, issues turned off, no `gh` sign-in, or Linear with no MCP tools and no API key, or a team key or project name that cannot resolve — sends a bug to `issues/` and a want to `TODOS.md`, and the capture says so. Unsure whether a bug is security-shaped → treat it as one. On GitHub that is a private file, which can be published later; a public issue can't be taken back. On Linear it is a security issue, and what you send follows *Tracker text*, because that text can't be taken back either.\n\n**Filing a bug or want is internal tracking, not an escalation.** It goes up on the work tracker without the owner's go-ahead: the lead files it at Step 4.5, the PM bot through `/kru-issue` and `/kru-todo` (`skills/kru-lead/SKILL.md`, first section). Only the security row stays private. No seat files one. No hook files one — `hooks/store-sync.sh` only syncs the scratch `TODOS.md`.\n\nWhy user-level files for the rest, not in-repo: the working repo stays clean — **no management files in it, ever**: no `management/` dir, no `issues/`, no plan docs, briefs, or todo lists, and **no pointer in its `AGENTS.md`**.",
  "t7: the three destinations in one table; the old not-Issues rationale goes",
))
EDITS.push(E(
  "TRACKER.md",
  "  TODOS.md                 # durable, cross-cutting — captured one-liners, untriaged",
  "  TODOS.md                 # the team's scratch todos (and wants the work tracker can't take) — one-liners, untriaged",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "  issues/                  # known defects — one file per bug, deleted when fixed",
  "  issues/                  # security findings (and bugs the work tracker can't take) — one file each, deleted when fixed",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "- **Todo capture** → a pitched or discovered want, out of scope for the current slice, appends **one line** to `TODOS.md`.",
  "- **Todo capture** → a pitched want (the PM's) out of scope for the current slice goes to the work tracker (Linear MCP when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" file --kind want`); a discovered one (the team's scratch) appends **one line** to `TODOS.md` (*Where each thing is tracked*).",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "- **Defect capture** → a bug that isn't being fixed in this slice gets **its own file** under `issues/` (below), not a line in `TODOS.md`. Fixed it in the slice instead? **Delete** its file in the same change.",
  "- **Defect capture** → a bug that isn't being fixed in this slice goes to the work tracker (`file --kind bug`); a security finding gets **its own file** under `issues/` (below). On the GitHub tracker that file is the record — never a public issue. On Linear the record is also a Linear issue, internal to the team (*Security on Linear*). What you send follows *Tracker text*. Fixed it in the slice instead? The pull request carries the line `link --id` prints, and a Linear issue is closed with `close --id`; a store file is **deleted** in the same change.",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "- **Todo closeout** → a slice that satisfies a parked want **deletes its line** from `TODOS.md`, same as a fix deletes its `issues/` file.",
  "- **Todo closeout** → a slice that satisfies a parked want **deletes its line** from `TODOS.md`, or closes its work-tracker item the same way a fix closes a bug (`link --id` on the pull request, and `close --id` when the tracker is Linear).",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "**Three writers, one format.** Mid-task capture is the Step 4.5 sweep above (`pitched` when the user tossed it out, `discovered` when the team turned it up inside the effort in flight).",
  "**Three writers, one format.** Mid-task capture is the Step 4.5 sweep above (`discovered` when the team turned it up inside the effort in flight; a want the PM tossed out goes to the work tracker, and lands here as `pitched` only when `ready` exits 4).",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "The **`/kru-todo` skill** (`skills/kru-todo/`) is the user's direct front door for when there's no task running to sweep from: always `pitched`,",
  "The **`/kru-todo` skill** (`skills/kru-todo/`) is the PM's direct front door for when there's no task running to sweep from: it files on the work tracker, and writes here only when `ready` exits 4 — always `pitched`,",
  "t7",
))
EDITS.push(E(
  "TRACKER.md",
  "**`issues/` — known defects, one file per bug.** A defect is something *wrong*: an incorrect result, false information shown to a user, or a failure of a condition the code claims to handle. Something merely *wanted* — a feature, a refactor, a cleanup, duplication, misfiled config — is a `TODOS.md` line, not an issue. The three-way split is the whole rule: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`.**",
  "**`issues/` — security findings, one file per finding.** A defect is something *wrong*: an incorrect result, false information shown to a user, or a failure of a condition the code claims to handle. A normal one goes to the work tracker; this dir holds the evidence. On the GitHub tracker the security finding never goes public. On Linear it goes to Linear, internal to the team (*Security on Linear*). What you send follows *Tracker text*. The dir also holds any bug whose tracker is not ready. Something merely *wanted* — a feature, a refactor, a cleanup, duplication, misfiled config — is a want, not a defect. The split is the whole rule: **wrong → the work tracker (security: `issues/` on GitHub, and on Linear a security issue internal to the team whose text follows *Tracker text*), wanted → the work tracker (the team's own scratch: `TODOS.md`), unformed → `notes/`.**",
  "t7: issues/ is for security findings",
))
EDITS.push(E(
  "references/store.md",
  "- **Project** — one project's plan of record: `TODOS.md`, `issues/`, `notes/`, `plan/`\n  (`TRACKER.md` owns its layout).",
  "- **Project** — one project's plan of record: `TODOS.md`, `issues/`, `notes/`, `plan/`\n  (`TRACKER.md` owns its layout).\n\nThe project root is the private half of tracking: security findings and the team's scratch todos live here, while normal bugs and product wants go to the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`, GitHub unless `KRU_TRACKER=linear`). Which goes where is `TRACKER.md` → *Where each thing is tracked*. On Linear, prefer the connected MCP tools; an API key is optional (*Linear MCP*). A security finding stays in this store on the GitHub tracker. On Linear the tracker issue points at the store file and does not carry the evidence (*Security on Linear*).",
  "t7: the private half of tracking, pointing at TRACKER.md's table rather than copying it",
))
EDITS.push(E(
  "references/store.md",
  "session bookkeeping (`audit/`, `lead-gate/`). It follows the **user**, across every engagement.",
  "session bookkeeping (`audit/`, `lead-gate/`). It follows **the owner and the PM**, across every engagement.",
  "t6 (the line the ticket named): the store follows the owner and the PM",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "Write the defect file from what the user just told you and get out.",
  "Record the defect from what the PM just told you and get out — on the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`), or, for a security finding, as a store file. On Linear it also goes to Linear, internal to the team. What you write follows *Tracker text* (`${CURSOR_PLUGIN_ROOT}/TRACKER.md`).",
  "t7: kru-issue files normal bugs on GitHub, security ones in the store",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "2. **Glance at `issues/`** (`ls`, nothing more). Same defect already has a file → append the user's new detail to it and stop. One directory listing isn't investigation; two files for one bug is drift.\n3. **Write the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path issues/<kebab-slug>` names.** **No precondition**: create the dir if it isn't there.",
  "2. **Pick the destination from what you were told.** Security-shaped — anything an attacker could use: an auth bypass, data exposure, an injection, a leaked secret — or unsure → a security finding. On the GitHub tracker that is the store file (step 3 on) and never the work tracker. On the Linear tracker it goes to Linear, internal to the team, and the evidence stays in the store file (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Security on Linear*). What you write follows *Tracker text* (`${CURSOR_PLUGIN_ROOT}/TRACKER.md`). When Linear MCP tools are connected, file with `save_issue` (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*) and do not call the script: a missing `LINEAR_API_KEY` is not exit 4 and not a reason to skip Linear. When they are not connected, run `file --kind security` only if `ready` exits 0; on exit 4 the store file is the only record and the confirm line says why (`ready` writes it). Still write the store file either way. On the tracker that security issue is a short title and a link to the file, not the template's Repro, Root cause, or Exploit sections. A comment or an update on that issue stays pointer-only too. Otherwise a normal bug → the work tracker. When `backend` is `linear` and Linear MCP tools are connected, use them (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*) and do not treat a missing `LINEAR_API_KEY` as a reason to use the store. Otherwise, when `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" ready` exits 0, use the script; else the store file, and the confirm line says why (`ready` writes it).\n   - **Tracker, for a normal bug:** On Linear with MCP tools connected, do this glance, comment and file through those tools (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*). Otherwise glance for the same bug (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" search --kind bug --query \"<two words from the symptom>\"`, nothing more). One hit → add the new detail (`comment --id <id> --body \"<the new detail>\"`) and stop. None, or more than one → `file --kind bug --title \"<the symptom, one line>\" --body \"<the template below, minus the frontmatter, with severity and urgency as its first line>\"`. It prints the id and the url separated by a tab. On GitHub it drops a label `gh` refuses and says so. Then step 5. bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand\n3. **Glance at `issues/`** (`ls`, nothing more). Same defect already has a file → append the new detail to it and stop. One directory listing isn't investigation; two files for one bug is drift. Else **write the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path issues/<kebab-slug>` names.** **No precondition**: create the dir if it isn't there.",
  "t7: normal bug -> the work tracker; security -> the store",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "5. **Confirm in one line** — \"logged as <severity>, needed <urgency in words>; not looked into yet.\" No path.",
  "5. **Confirm in one line** — \"logged as <severity>, needed <urgency in words>; not looked into yet\", with the tracker id when it went to the work tracker, and no path when it went to the store.",
  "t7",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "The store's three-way split holds: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`**. Say in one line which you did.",
  "The split holds: **wrong → the work tracker (security: `issues/` on GitHub; on Linear, internal to the team, text that follows *Tracker text*), wanted → `/kru-todo`, unformed → `notes/`**. Say in one line which you did.\n- **Tracker text.** bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand. Name the defect and point at the store file.",
  "t7",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "Filling the file in is a normal `/kru-lead <task>`; fixing it deletes the file in that same change, along with the repro test that replaces it (`lead` Step 4.5).",
  "Filling it in is a normal `/kru-lead <task>`; fixing it puts the line `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` prints on the pull request (and closes a Linear issue through MCP `save_issue` with `state` `Done` when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*), otherwise `close --id <id>`) or deletes the file in that same change, along with the repro test that replaces it (`lead` Step 4.5).",
  "t7",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "Write the user's deferred want into the project's `TODOS.md` and get out.",
  "File the PM's deferred want and get out: on the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`), or as a `TODOS.md` line when `ready` exits 4 (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*).",
  "t7: product wants go to GitHub issues",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "2. **Append** to the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path todos` names. **No precondition**: create the dir and the file if they don't exist.",
  "2. **File it.** When `backend` is `linear` and Linear MCP tools are connected, file there (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*); a missing `LINEAR_API_KEY` is not a reason to append to `TODOS.md`. Otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" ready` exits 0 → `file --kind want --title \"<the thing, one line>\" --body \"<the line's three scores and any sub-bullets, as written below>\"`. It prints the id and the url separated by a tab. On GitHub it drops a label `gh` refuses and says so. Otherwise **append** to the file `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-store.sh\" path todos` names, and the confirm line says why (`ready` writes it). **No precondition**: create the dir and the file if they don't exist.",
  "t7",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "4. **Confirm in one line** — echo the headline, how much it matters and how soon, in words (\"logged: <headline> — matters 3 of 5, needed within weeks\"). No path, no effort, no notation.",
  "4. **Confirm in one line** — echo the headline, how much it matters and how soon, in words (\"logged: <headline> — matters 3 of 5, needed within weeks\"), with the tracker id when it went to the work tracker. No path, no effort, no notation.",
  "t7",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "The store's three-way split holds: **wrong → `issues/`, wanted → `TODOS.md`, unformed → `notes/`**.",
  "The split holds: **wrong → `/kru-issue`, wanted → the work tracker (or `TODOS.md` when it isn't ready), unformed → `notes/`**.",
  "t7",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "- **Todo capture** — any want the **user pitches** mid-task, or one the **team discovers inside the effort in flight** (filed with that `plan: <slug>`), that's out of scope for the current slice: append a one-line entry to `TODOS.md` at the store root and **keep going** — never derail the task to build it.",
  "- **Todo capture** — any want the **PM pitches** mid-task goes to the work tracker (Linear MCP when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" file --kind want`), which you file yourself (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*); one the **team discovers inside the effort in flight** (filed with that `plan: <slug>`), out of scope for the current slice, is a one-line entry in `TODOS.md` at the store root. Either way **keep going** — never derail the task to build it.",
  "t7: capture picks the destination by the table",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "gets **its own file** at `issues/<kebab-slug>.md` in the store root — the team's defect list; a GitHub issue is filed with `gh` only when the user asks for one: `severity` frontmatter, then call sites as `file:line`, observed behavior, root cause, repro, blast radius, fix options.",
  "goes to the **work tracker** (Linear MCP when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" file --kind bug`, written up as below), which you file yourself — internal tracking, not an escalation (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md`, first section) — unless it is security-shaped, which gets **its own file** at `issues/<kebab-slug>.md` in the store root and never a public GitHub issue. On Linear it goes to Linear, internal to the team (*Security on Linear* in `TRACKER.md`). bug and want issues MAY carry a plain repro, symptoms and call sites, but never secrets, keys, credentials or customer emails/phones; SECURITY issues are pointer-only (short title + link to the store file, no repro, no root cause, no exploit detail); MCP-path sessions apply the same rule by hand (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Tracker text*). The store-file write-up: `severity` frontmatter, then call sites as `file:line`, observed behavior, root cause, repro, blast radius, fix options. A bug on the tracker may carry the plain repro, symptoms and call sites from it; a security issue on the tracker is the short pointer only.",
  "t7: normal bugs to GitHub, security to the store",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "   Take `severity` from the user when they state it, else `medium` — and name which in the confirm line so they can correct it in one word. Never infer severity from how alarmed the message sounds. `urgency` (`TRACKER.md` anchors) is bare when they said how soon (\"before launch\", \"whenever\"), else `~3`.",
  "   Take `severity` from the user when they state it, else `medium` — and name which in the confirm line so they can correct it in one word. Never infer severity from how alarmed the message sounds. `urgency` (`TRACKER.md` anchors) is bare when they said how soon (\"before launch\", \"whenever\"), else `~3`. The template above is the store file. A bug or want on the tracker may carry its plain repro, symptoms and call sites. A security issue on the tracker does not use the template.",
  "t7: the store template stays; a security tracker issue does not copy its repro",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "**a slice that fixes a bug closes its file.** `ls issues/` and read the listing against what you just landed — every file whose defect this slice fixed is **deleted in that same change**",
  "**a slice that fixes a bug closes its record.** The pull request stays on GitHub and its description carries the line `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` prints (`Fixes #<n>`, or `Linear: <id>`). A Linear issue also needs a close — Linear MCP `save_issue` with `state` `Done` when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*), otherwise `close --id <id>`. Merge does not close it. For the store, `ls issues/` and read the listing against what you just landed — every file whose defect this slice fixed is **deleted in that same change**",
  "t7",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "**Walk `issues/` too — this is the dir's only reader.**",
  "**Walk the open bugs too: the work tracker's open bugs (Linear MCP `list_issues` when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind bug`) and the store's `issues/`, the security ones — the brief is their only reader.** Each tracker bug is read against the current code the same way; one the code has since fixed is named in the brief for the PM bot to close, not closed by you.",
  "t7: brief walks the repo's open issues as well as the store's security files",
))

// --- t7: (cont.) the listing verbs read GitHub issues ------------------------
EDITS.push(E(
  "skills/kru-issues/SKILL.md",
  "Membership is the status: a file exists until the change that fixes its bug deletes it, so an empty dir is a true *no known defects*.",
  "Membership is the status: a file exists until the change that fixes its bug deletes it, so an empty dir is a true *no known defects*.\n\nNormal bugs live on the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind bug`; `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*), so `issues/` holds the security findings and any bug whose tracker is not ready. When Linear MCP tools are connected, list and close there (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*) even with no API key. Otherwise when `ready` exits 0, the open bugs run through the same steps beside the files: reconciled, scored and proposed alike, a verified-fixed one named for the PM bot to close rather than closed by you. A fix puts the line `link --id <id>` prints on the pull request, and closes a Linear issue through MCP `save_issue` with `state` `Done` when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*), otherwise `close --id <id>`.",
  "t7: the defect verb reads GitHub issues too",
))
EDITS.push(E(
  "skills/kru-todos/SKILL.md",
  "This is the one verb where a filed want meets the codebase:",
  "Product wants live on the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind want`; `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Where each thing is tracked*); when Linear MCP tools are connected, list and close there (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*) even with no API key; otherwise when `ready` exits 0, those open wants run through the same steps beside the file's lines — a landed one closed by the line `link --id <id>` prints on the pull request (and by `close --id <id>` when the tracker is Linear), a verified-done one named for the PM bot to close. This is the one verb where a filed want meets the codebase:",
  "t7: the want verb reads GitHub issues too",
))

// --- t10: seat prompts say PM where they mean the requester ------------------
EDITS.push(E(
  "agents/ui-designer.md",
  "The canvas decides the look inside the frame you draft; the user decides whether it's any good.",
  "The canvas decides the look inside the frame you draft; the PM decides whether it's any good.",
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
  "- **You have no user channel.** The `kru-design` skill asks one design question",
  "- **You have no channel to the PM.** The `kru-design` skill asks one design question",
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
  "- **The look is the canvas's and the verdict is the user's.**",
  "- **The look is the canvas's and the verdict is the PM's.**",
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
  "(`/kru-design`, publishing with `/canvas`, or the `.dc.html` artboards when `/canvas` isn't available)",
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
  "- **Consider** — the only verdict that goes to the plugin maintainer first; the action verdicts run through `/kru-roster` without a question. Real value at a cost someone has to decide — the plugin maintainer does, and takes it on to the owner when the PM's own operating rules say so, or under the plugin's generic default when the PM has none (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md`, first section):",
  "t11: Consider goes to the plugin maintainer first",
))
EDITS.push(E(
  "TRACKER.md",
  "It's the one artifact with no capture rule: the user writes it, and the lead only when asked to keep something they thought out loud.",
  "It's the one artifact with no capture rule: the PM and the owner write it, and the lead only when asked to keep something one of them thought out loud.",
  "t11: notes/ writers are the PM and the owner",
))
EDITS.push(E(
  "TRACKER.md",
  "Who writes it: the **user**, mostly, and the lead when the user thinks out loud and asks for it to be kept.",
  "Who writes it: the **PM and the owner**, mostly, and the lead when either thinks out loud and asks for it to be kept.",
  "t11: notes/ writers are the PM and the owner",
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
  "The store's existing `plan/<effort>/brief.md` (if you're re-grilling an effort), `TODOS.md` (the captured, untriaged one-liners), the work tracker's open wants (Linear MCP `list_issues` when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind want`), and the store's `notes/` (freeform brainstorming — **input, never authority**: cite it as *\"there's a note that says…\"*, never as a decision, and never let it override the brief, the repo's docs, or the user).\n\nBring them back to the user during the grill: an old brief's open threads get re-decided, and a `TODOS.md` line or an open want is either pulled into this change's scope or left where it is. Order them **`value × urgency ÷ effort`** the way `/kru-todos` ranks them — what matters, soon, for little work first, a work-tracker want on the three scores in its body, a `~n` ranked as filed, legacy lines with no digits after — and note the ones filed 90+ days ago or against a `plan/<slug>/` that's since been archived (\"may be out of date\"), since those are the lines most likely to be asking for a codebase that no longer exists. To the user, each surfaces as the want in plain words — what someone using the product would get — in that order, with no digits, tildes, ages or scoring notation. That ordering is arithmetic over filed numbers, not a triage: you don't triage `TODOS.md` or the open wants on your own — you surface them and the user calls it. One the code has since grown is named for the PM bot to close, not closed by you.",
  "review: a brief reads open enhancement issues back with the parking lot",
))
EDITS.push(E(
  "skills/kru-todos-loop/SKILL.md",
  "- **Queue**: `todos` §1 and §2 over the whole file, its §4 bookkeeping, ranked by its §3 order.\n- **Eligible**: open, `value` `3`–`5`, `effort` `1`–`3`, and `pitched`. A `discovered` line is the team's own capture and waits for the user to pull it, per `todos` → *Guardrails*; count it with the unreached. A `~` value is the team's guess at what the user wants, so it qualifies only at `4`–`5`.",
  "- **Queue**: `todos` §1 and §2 over the whole file and the work tracker's open wants (Linear MCP `list_issues` when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind want`), its §4 bookkeeping, ranked by its §3 order.\n- **Eligible**: open, `value` `3`–`5`, `effort` `1`–`3`, and `pitched`. A work-tracker want is one the PM filed, so it counts as `pitched`, and its `value`, `urgency` and `effort` are the digits in its body. A `discovered` line is the team's own capture and waits for the user to pull it, per `todos` → *Guardrails*; count it with the unreached. A `~` value is the team's guess at what the user wants, so it qualifies only at `4`–`5`.",
  "review: the want loop queues GitHub enhancement issues and counts each as pitched",
))
EDITS.push(E(
  "skills/kru-issues-loop/SKILL.md",
  "- **Queue**: `issues` §1 and §2 over the whole dir, its §4 bookkeeping, ranked by its §3 order.",
  "- **Queue**: `issues` §1 and §2 over the whole dir and the work tracker's open bugs (Linear MCP `list_issues` when those tools are connected, `${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*; otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list --kind bug`), its §4 bookkeeping, ranked by its §3 order.",
  "review: the defect loop queues GitHub bug issues with the store dir",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "a `~` number is a proposal awaiting their read — if the user confirms or corrects it, rewrite that line in place with the bare digit and stop.",
  "a `~` number is a proposal awaiting their read — if the user confirms or corrects it, write the bare digit back and stop: Linear MCP `save_issue` with `id` and `description` when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*), otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" update --id <id> --body` when the want is on the work tracker, or rewrite that line in place when it is a `TODOS.md` line.",
  "review: a confirmed score on a tracker want is kru-tracker update, not a line rewrite",
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

EDITS.push(E(
  "skills/kru-update/reviewed.md",
  "# Reviewed — the marks and the standing verdicts\n\n## Claude Code",
  "# Reviewed — the marks and the standing verdicts\n\n## Cursor\n\n### Swept through\n\n**unset** — no Cursor changelog day has been swept yet. The next `/kru-update claude` reads [Cursor's changelog](https://cursor.com/changelog) (`claude.md`). The Claude Code ledger below is closed.\n\n## Claude Code",
  "cursor sweep mark starts unset; the Claude Code ledger stays closed",
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

// adopt a ready-made skill before authoring one. the completion line stays
// role + boundary + source.
EDITS.push(E(
  "skills/kru-roster/hire.md",
  "A seat with a fuzzy boundary is worse than no seat (`ROSTER.md` → *Scope*: adding a seat is fine, adding a blurred lane is not).\n\nCompletion: role + boundary-vs-nearest-peer + named source, all one line, no overlap.",
  "A seat with a fuzzy boundary is worse than no seat (`ROSTER.md` → *Scope*: adding a seat is fine, adding a blurred lane is not).\n\nBefore authoring a new skill or inventing a seat-owned recipe, adopt an authoritative ready-made skill first: an official plugin, a publisher or standards-body skill repo, or a skill the team already has. Author one only where none of those exists.\n\nCompletion: role + boundary-vs-nearest-peer + named source, all one line, no overlap.",
  "adopt-first: author a skill only where no authoritative ready-made skill exists",
))

// KRU_CLOUD=0 forces the local store layout. the cloud row is the port's
// rewrite of upstream's remote-session row; this names the off switch.
EDITS.push(E(
  "references/store.md",
  "| cloud agent (`CURSOR_AGENT_SOCKET` set, or `KRU_CLOUD=1`) | `~/.kru` — session-lived | **`<repo>/.kru`**, and it ships in the branch |\n| `KRU_STORE_REPO` set, any surface |",
  "| cloud agent (`CURSOR_AGENT_SOCKET` set, or `KRU_CLOUD=1`) | `~/.kru` — session-lived | **`<repo>/.kru`**, and it ships in the branch |\n| `KRU_CLOUD=0` | the default row, on every surface | the default row — `CURSOR_AGENT_SOCKET` and `/run/cursor/api.sock` do not count |\n| `KRU_STORE_REPO` set, any surface |",
  "review: KRU_CLOUD=0 forces the local store layout",
))
EDITS.push(E(
  "references/store.md",
  "**`<project-slug>` is the repo's dir name**, and a linked worktree resolves to the **main** repo — a\n",
  "**`KRU_CLOUD=0` forces the local rows** even when `CURSOR_AGENT_SOCKET` is set or `/run/cursor/api.sock` exists: the project root stays `<cross-project root>/management/<project-slug>` and does not move into `<repo>/.kru`. Set it on a machine that has the agent socket but is not a cloud vm, and in tests, so a host socket cannot flip the layout. `KRU_CLOUD=1` forces the cloud row. Unset, the socket decides.\n\n**`<project-slug>` is the repo's dir name**, and a linked worktree resolves to the **main** repo — a\n",
  "review: when to set KRU_CLOUD=0",
))

// --- tracker: KRU_TRACKER=github|linear; security goes to Linear only then ---
EDITS.push(E(
  "TRACKER.md",
  "skipping one already filed.",
  "skipping one already filed — scratch, so it stays in this file even when the tracker is Linear.",
  "tracker: setup's discovered upgrades stay scratch, even on Linear",
))
EDITS.push(E(
  "skills/kru-issue/SKILL.md",
  "description: Open a defect file in the project's plan store from what the user just said, un-investigated. The user's front door to issues/, for when no task is running to sweep from.",
  "description: Record a defect from what the PM just said, un-investigated. A normal bug goes to the work tracker. A security finding stays in the store on GitHub; on Linear it goes to Linear, internal to the team, and what is filed follows *Tracker text* in TRACKER.md. The PM's front door for when no task is running to sweep from.",
  "tracker: the issue command names the work tracker",
))
EDITS.push(E(
  "skills/kru-todo/SKILL.md",
  "description: Log something you want but don't want done now, into the project's plan store. Expands it from context already in the session; logs it as-is when there's none.",
  "description: Log something the PM wants but doesn't want done now, on the work tracker. The plan store only when that tracker isn't ready. Expands it from context already in the session; logs it as-is when there's none.",
  "tracker: the todo command names the work tracker",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "- **Brief** — in `plan/<effort>/brief.md`: tick the `Landing plan` **commit** this slice just landed (and its parent PR box when that PR merges), tick the `Done when` boxes the slice satisfied, and correct `Blast radius` if the change reached further than the grill predicted. The PR's description is written from its `Change` + `Why now` + that PR's commit list.",
  "- **Brief** — in `plan/<effort>/brief.md`: tick the `Landing plan` **commit** this slice just landed (and its parent PR box when that PR merges), tick the `Done when` boxes the slice satisfied, and correct `Blast radius` if the change reached further than the grill predicted. The PR's description is written from its `Change` + `Why now` + that PR's commit list, plus the line `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` prints for each bug or want this slice closes. Pull requests stay on GitHub.",
  "tracker: the pull request links the work-tracker id",
))
EDITS.push(E(
  "skills/kru-lead/references/reconcile.md",
  "- **Todo closeout** — the other half, and it fires on the slices a `/kru-todos` run lands: **a slice that satisfies a parked want deletes its line** from `TODOS.md`, in that same reconciliation. `TODOS.md` is the open parking lot, never an archive — the commit is where the want is written down now. Outside a `todos` run you delete only a line the slice you just landed actually satisfies; the rest of the file is the user's.",
  "- **Todo closeout** — the other half, and it fires on the slices a `/kru-todos` run lands: **a slice that satisfies a parked want deletes its line** from `TODOS.md`, or closes its work-tracker item (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` on the pull request, and, when the tracker is Linear, close it through MCP `save_issue` with `state` `Done` when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*), otherwise `close --id <id>`), in that same reconciliation. `TODOS.md` is the open parking lot, never an archive — the commit is where the want is written down now. Outside a `todos` run you delete only a line the slice you just landed actually satisfies; the rest of the file is the user's.",
  "tracker: the pull request links the work-tracker id",
))
EDITS.push(E(
  "references/routing.md",
  "| something the user wants but doesn't want done now — \"not yet,\" \"remember this for later\" | **`/kru-todo`** — user-invoked, so name it in one line; mid-task it's your Step 4.5 `TODOS.md` capture |",
  "| something the user wants but doesn't want done now — \"not yet,\" \"remember this for later\" | **`/kru-todo`** — user-invoked, so name it in one line; mid-task it's your Step 4.5 capture on the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`; scratch still lands in `TODOS.md`; Linear MCP when those tools are connected, `TRACKER.md` → *Linear MCP*) |",
  "tracker: routing sends bugs and wants through the work tracker",
))
EDITS.push(E(
  "references/routing.md",
  "| something *wrong* the user wants recorded before it evaporates — a bug they just hit, not being fixed now | **`/kru-issue`** — user-invoked, same deal; mid-task it's your Step 4.5 `issues/` capture |",
  "| something *wrong* the user wants recorded before it evaporates — a bug they just hit, not being fixed now | **`/kru-issue`** — user-invoked, same deal; mid-task it's your Step 4.5 capture on the work tracker (security stays in `issues/` on GitHub; on Linear it is *Security on Linear* in `TRACKER.md`, and what is filed follows *Tracker text*) |",
  "tracker: routing sends bugs and wants through the work tracker",
))
EDITS.push(E(
  "references/routing.md",
  "| the user wants to work what's parked or what's broken — the `TODOS.md` lines, the open defect files | **`/kru-todos`** / **`/kru-issues`** — user-invoked; each reconciles the store against the code, scores, proposes a batch and waits for the pick before building. Name the one they want; only the user can fire them. Mid-task you already read the store directly when a step needs it |",
  "| the user wants to work what's parked or what's broken — the `TODOS.md` lines, the open defect files, the work tracker's open bugs and wants | **`/kru-todos`** / **`/kru-issues`** — user-invoked; each reconciles the store and the work tracker against the code, scores, proposes a batch and waits for the pick before building. Name the one they want; only the user can fire them. Mid-task you already read the store directly when a step needs it |",
  "tracker: routing sends bugs and wants through the work tracker",
))
EDITS.push(E(
  "skills/kru-to-spec/SKILL.md",
  "description: \"Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed.\"",
  "description: \"Turn the current conversation into a spec and publish it to the plan store: no interview, just synthesis of what you've already discussed. Not the work tracker.\"",
  "tracker: a spec stays in the plan store",
))
EDITS.push(E(
  "skills/kru-to-spec/SKILL.md",
  "The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.",
  "The tracker for a spec is the store's `plan/<effort>/spec.md` (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"` is the work tracker for bugs and wants, not for a spec — `${CURSOR_PLUGIN_ROOT}/TRACKER.md`). Do not run `/setup-matt-pocock-skills`, and do not file the spec on GitHub or Linear.",
  "tracker: a spec stays in the plan store",
))
EDITS.push(E(
  "skills/kru-to-spec/SKILL.md",
  "3. Write the spec using the template below, then publish it to the project issue tracker. Apply the `ready-for-agent` triage label - no need for additional triage.",
  "3. Write the spec using the template below, then publish it as `plan/<effort>/spec.md` in the store (`${CURSOR_PLUGIN_ROOT}/TRACKER.md`). Do not file it on the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`). `KRU_TRACKER` is for bugs and product wants, not for a spec. Apply no triage label.",
  "tracker: a spec stays in the plan store",
))
EDITS.push(E(
  "skills/kru-to-tickets/SKILL.md",
  "- **A real issue tracker (GitHub, Linear, …)** → publish one issue per ticket in dependency order (blockers first) so each ticket's blocking edges can reference real identifiers. Use the platform's native blocking / sub-issue relationship where it has one; otherwise set each ticket's \"Blocked by\" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise; the tickets are agent-grabbable by construction.",
  "- **A real issue tracker (GitHub, Linear, …)** → not this team's path for these tickets. Plan tickets stay files under the store (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Layout*). A bug or a product want is the work tracker (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`), and `KRU_TRACKER=linear` does not move a plan ticket onto Linear. The upstream branch, kept so a re-sync is visible, was: publish one issue per ticket in dependency order (blockers first) so each ticket's blocking edges can reference real identifiers. Use the platform's native blocking / sub-issue relationship where it has one; otherwise set each ticket's \"Blocked by\" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise; the tickets are agent-grabbable by construction.",
  "tracker: plan tickets stay in the store; KRU_TRACKER does not move them",
))
EDITS.push(E(
  "skills/kru-wayfinder/SKILL.md",
  "description: Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets on your issue tracker, and resolve them one at a time until the way to the destination is clear.",
  "description: Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets in the plan store, and resolve them one at a time until the way to the destination is clear. `KRU_TRACKER` does not move the map.",
  "tracker: the wayfinder map stays in the plan store",
))
EDITS.push(E(
  "skills/kru-wayfinder/SKILL.md",
  "charts the way as a **shared map** on the repo's issue tracker",
  "charts the way as a **shared map** in the plan store",
  "tracker: the wayfinder map stays in the plan store",
))
EDITS.push(E(
  "skills/kru-wayfinder/SKILL.md",
  "The map is a single issue on this repo's issue tracker, labelled `wayfinder:map`, the canonical artifact. Its tickets are child issues of the map.",
  "The map is `plan/<effort>/map.md` in the store, the canonical artifact (`${CURSOR_PLUGIN_ROOT}/TRACKER.md`). Its tickets are files under `plan/<effort>/tickets/`, not child issues on GitHub or Linear.",
  "tracker: the wayfinder map stays in the plan store",
))
EDITS.push(E(
  "skills/kru-wayfinder/SKILL.md",
  "**Where the map, its child tickets, blocking, and frontier queries physically live is tracker-specific.** The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`. Consult the tracker doc's \"Wayfinding operations\" section for how _this_ repo expresses them. If no tracker has been provided, default to the local-markdown tracker.",
  "**Where the map, its child tickets, blocking, and frontier queries physically live is the store**, not the work tracker. `plan/<effort>/map.md` and `tickets/` (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *wayfinder*). Do not run `/setup-matt-pocock-skills`, and do not file the map or its tickets on GitHub or Linear. `KRU_TRACKER` files bugs and product wants only (`bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\"`).",
  "tracker: the wayfinder map stays in the plan store",
))

// --- brief drift: re-run reconciles tracker issues ----------------
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "Re-run on an effort to reconcile its brief against what actually shipped.",
  "Re-run on an effort to reconcile its brief against what actually shipped and against that effort's tracker issues.",
  "brief drift: a re-run reconciles tracker issues too",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "**Re-grilling is reconciling, not re-reading.** Before you trust or tick anything in an old brief, check it against git — `git rev-list --count origin/main..main` plus the actual shas, and `gh pr list` for any PR the `Landing plan` claims landed. A brief claiming one unpushed commit when five are, or ticking a PR nobody opened, is the normal failure, not the odd one.",
  "**Re-grilling is reconciling, not re-reading.** Before you trust or tick anything in an old brief, check it against git — `git rev-list --count origin/main..main` plus the actual shas, and `gh pr list` for any PR the `Landing plan` claims landed. A brief claiming one unpushed commit when five are, or ticking a PR nobody opened, is the normal failure, not the odd one.\n\n**Re-grilling reconciles the tracker too.** The brief stores issue ids in `## Tracker` and never a status. Each issue links back with the line `Brief: plan/<effort>/brief.md` in its body. Open, done, or canceled is read from the tracker. A canceled issue is kept: one that links here and is not listed is drift (b), and a canceled issue is never (c). On a re-run, list that effort's issues and run the drift check before you trust an id. Normalize a listed id before the lookup: strip a leading `#`, and uppercase a Linear identifier (`bg-41` is `BG-41`). Linear MCP, when those tools are connected (`${CURSOR_PLUGIN_ROOT}/TRACKER.md` → *Linear MCP*): `list_issues` with `team`, `project`, and `query` set to `plan/<effort>/brief.md`, `limit` 250, and `fields` including `title`, `description`, `url`, `status`, and `statusType`. Follow `cursor` until a page returns none: the query matches more than the exact path, and the limit applies before that check. Keep an issue only when its description contains `plan/<effort>/brief.md`. Include completed and canceled — call again with `state` `completed`, then with `state` `canceled`, and the same query, each time from the first page and following `cursor` the same way, when the first call left them out. `get_issue` for each normalized id the brief lists that the list did not return. A lookup that says the issue does not exist is an id to omit, and drift says (a) missing. Any other failure — auth, network, or a tool error — stops the re-run: report it, and do not run the drift check on a partial list or call the id missing. Otherwise `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list-effort --brief plan/<effort>/brief.md`, then `show --id` for each listed id the list did not return (`show` strips a leading `#`, uppercases a Linear identifier, and prints one object). Exit 1 and the text `no such issue` means the id does not exist. Exit 5, or any other failure, stops the re-run: report it, do not treat the id as missing, and do not run drift on a partial list. A `list-effort` failure stops the re-run the same way. Write one JSON array of `{id, title, body, url, state}` — `body` is the issue description, `state` is `open`, `done`, or `canceled`. A completed issue is `done`. A closed GitHub issue whose state reason is not_planned is `canceled`; any other closed GitHub issue is `done`. A Linear canceled issue stays `canceled` — and run `node \"${CURSOR_PLUGIN_ROOT}/scripts/brief-drift.mjs\" --path plan/<effort>/brief.md --brief <the brief file> --issues <that json>`. Print the report as the script wrote it: (a) an id in `## Tracker` that does not exist or whose body does not contain the brief path, (b) an issue that contains the path and is not listed, (c) a `done` issue that links here and was never listed, never a canceled one, (d) a `## Tracker` bullet with no id. A clean run says `no drift`. The report is the output of this pass: do not file, comment, or edit a tracker issue to clear it, and do not copy a status into the brief. A later file or update goes through `kru-tracker.sh`, whose outbound guard refuses secrets and customer emails or phones, or on the MCP path through `node \"${CURSOR_PLUGIN_ROOT}/scripts/guard-text.mjs\"` (exit 1 means do not send) before `save_issue`. What you would send is the line `Brief: plan/<effort>/brief.md` and nothing from the brief's prose.",
  "brief drift: re-run lists the effort's issues and prints the drift report",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "Per `${CURSOR_PLUGIN_ROOT}/TRACKER.md` — `Change` (one line, what's different for users) · `Why now` · `Blast radius` (files/subsystems touched + risk) · **`Landing plan`** (the cadence — see below) · `Decisions resolved` (the grill record, Q → A) · `Non-goals` · `Done when` (checkboxes) · `Open questions` — only when the user cut the round short with the frontier not empty: each still-open question, numbered, with your recommended answer.",
  "Per `${CURSOR_PLUGIN_ROOT}/TRACKER.md` — `Change` (one line, what's different for users) · `Why now` · `Blast radius` (files/subsystems touched + risk) · **`Landing plan`** (the cadence — see below) · `Decisions resolved` (the grill record, Q → A) · `Non-goals` · **`Tracker`** (one bullet per planned tracker item; an issue id at the end when one exists — `#12` or `BG-41` — and no status) · `Open questions` — only when the user cut the round short with the frontier not empty: each still-open question, numbered, with your recommended answer · `Done when` (checkboxes).",
  "brief drift: the brief stores issue ids and no status",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "**Rewrite in place, don't append**: a re-grill reads the old brief as input and replaces it, so the file is always the *current* account of the change, never an archaeology of every discussion. Strip the brief's self-archaeology in the same pass — `(Correction, …)`, `(Amendment, …)`, `(Rewritten <date> — this read…)` — and grepping for those markers is the done-check. The brief states the current shape; the story of how it got there is exactly what `decisions.md` is for.",
  "**Rewrite in place, don't append**: a re-grill reads the old brief as input and replaces it, so the file is always the *current* account of the change, never an archaeology of every discussion. Strip the brief's self-archaeology in the same pass — `(Correction, …)`, `(Amendment, …)`, `(Rewritten <date> — this read…)` — and grepping for those markers is the done-check. The brief states the current shape; the story of how it got there is exactly what `decisions.md` is for.\n\n`## Tracker` survives the rewrite with its ids, and the rewrite does not record a status. An issue links to this brief with the line `Brief: plan/<effort>/brief.md`. Filing or updating that line goes through `kru-tracker.sh` (the outbound guard) or, when Linear MCP tools are connected, through `node \"${CURSOR_PLUGIN_ROOT}/scripts/guard-text.mjs\"` before `save_issue` — exit 1 means do not send. The line is the path, not the brief's prose, a repro, a secret, or a customer email or phone.",
  "brief drift: a tracker write is the brief path, through the outbound guard",
))
EDITS.push(E(
  "skills/kru-brief/SKILL.md",
  "One line in the shape \"Plan saved: <what's different for users>. Next I build it.\" — or, when it won't fit one session, \"…Next I break it into steps, then build it.\" When `Open questions` was written, the line names the count (\"3 questions still open\"). No path, no seat or step references. Which it is follows `lead` Step 2.6 (**`/kru-lead`** builds it, or **`planner`** slices it first).",
  "On a re-run, print the drift report first, as `brief-drift.mjs` wrote it. One line in the shape \"Plan saved: <what's different for users>. Next I build it.\" — or, when it won't fit one session, \"…Next I break it into steps, then build it.\" When `Open questions` was written, the line names the count (\"3 questions still open\"). No path, no seat or step references. Which it is follows `lead` Step 2.6 (**`/kru-lead`** builds it, or **`planner`** slices it first).",
  "brief drift: the re-run prints the drift report, then the plan line",
))
EDITS.push(E(
  "TRACKER.md",
  "Prose, not typed: no frontmatter, no id, no status — its existence in the effort dir is the signal.",
  "Prose, not typed: no frontmatter and no status. `## Tracker` stores the effort's issue ids; open or done lives only on the work tracker. Its existence in the effort dir is the signal.",
  "brief drift: the brief stores issue ids; status stays on the tracker",
))
EDITS.push(E(
  "TRACKER.md",
  "and the brief keeps `Change`/`Why now`/`Blast radius`/`Landing plan`/`Non-goals`/`Done when` whole.",
  "and the brief keeps `Change`/`Why now`/`Blast radius`/`Landing plan`/`Non-goals`/`Tracker`/`Done when` whole.",
  "brief drift: a split keeps the Tracker section",
))
EDITS.push(E(
  "TRACKER.md",
  "## Non-goals\n- explicitly out of scope, so a builder doesn't drift into it\n\n## Open questions\n- only when the user cut the grill short: the product calls still unanswered\n\n## Done when\n- [ ] the end-to-end behaviour that must work\n```",
  "## Non-goals\n- explicitly out of scope, so a builder doesn't drift into it\n\n## Tracker\n- <planned item> — <#12 or TEAM-123 when filed>\n- <planned item with no issue yet>\n\n## Open questions\n- only when the user cut the grill short: the product calls still unanswered\n\n## Done when\n- [ ] the end-to-end behaviour that must work\n```\n\n**Issue ids live in the brief; status lives on the tracker.** `## Tracker` is one bullet per planned item, the id at the end (`#12`, or a Linear identifier such as `BG-41`) when an issue exists, and no status. The issue links back: its body contains `Brief: plan/<effort>/brief.md`. A re-run of `/kru-brief` lists that effort's issues — `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" list-effort --brief plan/<effort>/brief.md`, or Linear MCP `list_issues` with that path as `query`, `limit` 250, following `cursor` until the pages end, completed and canceled included — then `node \"${CURSOR_PLUGIN_ROOT}/scripts/brief-drift.mjs\"` flags drift: an id that does not exist or does not link back, an issue that links here and is not listed, including a canceled one, a done issue the brief never planned (a canceled issue is never that), a planned bullet with no id. `show` exit 1 with the text `no such issue` is an id that does not exist; exit 5 or any other failure stops the re-run instead of calling the id missing. The report stays local. A later file or update still follows *Tracker text*.",
  "brief drift: the brief template stores ids and the contract",
))
EDITS.push(E(
  "TRACKER.md",
  "- A **brief** (`plan/<effort>/brief.md`) is prose, not typed — no frontmatter, no id, no status. Its presence in an effort dir **is** the handoff signal to `planner`, which reads it as the already-scoped brief for to-spec. See *The brief* below.",
  "- A **brief** (`plan/<effort>/brief.md`) is prose, not typed — no frontmatter and no status. Issue ids live in `## Tracker`, not in frontmatter. Its presence in an effort dir **is** the handoff signal to `planner`, which reads it as the already-scoped brief for to-spec. See *The brief* below.",
  "brief drift: a brief has no frontmatter id; issue ids live in Tracker",
))
