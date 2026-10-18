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
  "in the main thread — you are the orchestrator, not a subagent (subagents can't spawn subagents).",
  "in the main thread — you are the orchestrator, not a subagent (since Cursor 2.5 a direct subagent can launch children; only deeper nesting can't, [subagents](https://cursor.com/docs/subagents)).",
  "harness: a direct subagent can launch children; only deeper nesting can't",
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
  "**Who acts at the door.** **Ordinary work** — review fixes, hire, author, retire, requester ships, ports: the lead `commit`s on the branch and returns proof; the lead never pushes and never waits for a PM ask (headless runs do not wait). The PM bot reviews the proof, pushes the branch and opens the pull request. On a cloud agent, outbound team connector MCP (send/post/share/delete and the rest) is forbidden by the always-on rule in `rules/kru-lead.mdc` — hand the exact tool and arguments back to the PM bot; the repo hook enforces the same denylist only when Cursor runs hooks on MCP calls (not on cloud agents today; see `PORTING.md`). **`/kru-roster learn` only:** the sweep leaves the diff uncommitted; the plugin maintainer reviews it; then the lead `commit`s when the PM asks; then the PM bot pushes and opens the pull request — \"when the PM asks\" appears only in learn contexts. **Merge:** in this plugin repo, the plugin maintainer merges after CI (`verify`) passes; in product repos, the owner merges. **Tag:** only when the PM asked for a release, per `skills/kru-roster/release.md`. The maintainer creates and pushes the tag from a checkout that has push rights (`git tag` + `git push origin <tag>`, or `gh release create`). A cloud session that cannot push a tag (403) stops and hands the tag step back to the PM bot with the exact commands. Deploying, publishing and any message outside the team wait for the owner. A bug or want on the work tracker (GitHub issues, or Linear when the repo has opted in) is internal tracking, not a message outside the team (first section). Pull requests stay on GitHub either way: the body carries the line `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` prints. Most product repos are public, so the PM bot reads the repo's visibility (`gh repo view --json visibility`) before a push. A security fix stays local until the owner OKs it, then ships through a GitHub security advisory's temporary private fork, published on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays in `issues/`, off the PR and off Linear.",
  "t2: the lead commits, the PM pushes and opens the PR, the owner merges (the plugin maintainer for this plugin)",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "description: How this engineering team works — load before building, reviewing or dispatching any seat. Also the entry for a project from scratch and for planning work past one context.",
  "description: How this engineering team works — load before building, reviewing or dispatching any seat. Also the entry for a project from scratch and for planning work past one context. Opening or owning a pull request follows the PR babysit loop in `rules/kru-lead.mdc`.",
  "pr-babysit: the always-loaded description fires when a cloud agent opens or owns a PR",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "in `issues/`, off the PR and off Linear.",
  "in `issues/`, off the PR and off Linear.\n\n**PR babysit loop.** The loop is the always-on rule in `rules/kru-lead.mdc`.",
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
  "| 9 | git | the lead `commit`s on the branch; the PM bot pushes and opens the pull request; merge and `tag` per `skills/kru-lead/SKILL.md` → *Who acts at the door* and `release.md` |",
  "t2: git row matches release.md and kru-lead Who acts at the door",
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
  "You run in the **main thread** (like `lead`) — minting a seat edits the orchestration contract (the `lead` routing table) and bumps + tags a version, which a subagent can't own. This skill operationalizes `ROSTER.md` → *Growing the team* so every seat is wired **identically** and nothing drifts.",
  "You run in the **main thread** (like `lead`) — minting a seat edits the orchestration contract (the `lead` routing table) and bumps the version, which a subagent can't own. Hand off per `skills/kru-lead/SKILL.md` → *Who acts at the door*. This skill operationalizes `ROSTER.md` → *Growing the team* so every seat is wired **identically** and nothing drifts.",
  "t2: roster main thread bumps version; full door split in opener",
))
EDITS.push(E(
  "skills/kru-roster/SKILL.md",
  "You run in the **main thread** (like `lead`) — minting a seat edits the orchestration contract (the `lead` routing table) and bumps the version, which a subagent can't own; the lead `commit`s locally, and the plugin maintainer `tag`s on release (`release.md`). This skill operationalizes `ROSTER.md` → *Growing the team* so every seat is wired **identically** and nothing drifts.",
  "You run in the **main thread** (like `lead`) — minting a seat edits the orchestration contract (the `lead` routing table) and bumps the version, which a subagent can't own. Hand off per `skills/kru-lead/SKILL.md` → *Who acts at the door*. This skill operationalizes `ROSTER.md` → *Growing the team* so every seat is wired **identically** and nothing drifts.",
  "review PR21: roster opener full door split",
))
EDITS.push(E(
  "skills/kru-roster/SKILL.md",
  "It's the only verb that reads the cross-project store (`${CURSOR_PLUGIN_ROOT}/references/store.md`) and the one verb that decides on its own what to land — the user reviews the uncommitted diff.",
  "It's the only verb that reads the cross-project store (`${CURSOR_PLUGIN_ROOT}/references/store.md`) and the one verb that decides on its own what to land — the plugin maintainer reviews the uncommitted diff before it ships (`learn.md`).",
  "t2: learn diff reviewed by plugin maintainer",
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
  "their findings merge into the same fix list as `kru-code-reviewer`'s, and the PM bot's eye above remains the gate.",
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
  "Nothing is committed until the lead commits when the PM asks: the plugin maintainer reviews the uncommitted diff before it ships (`skills/kru-roster/learn.md`, `skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "t6: learn review + lead commit when PM asks",
))
EDITS.push(E(
  "PREFERENCES.md",
  "Nothing is committed: the plugin maintainer reviews the uncommitted diff from a checkout of this plugin, then commits, pushes, opens the pull request, merges and tags (the plugin maintainer owns this plugin's releases).",
  "Nothing is committed until the lead commits when the PM asks: the plugin maintainer reviews the uncommitted diff before it ships (`skills/kru-roster/learn.md`, `skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "review PR21: PREFERENCES tier-2 step 3 door roles",
))
EDITS.push(E(
  "PREFERENCES.md",
  "(run from the plugin source repo; decides, user reviews the diff)",
  "(run from the plugin maintainer's checkout of this plugin; decides the promotion — the plugin maintainer reviews the uncommitted diff, and the lead commits when the PM asks)",
  "t6: learn diagram door roles",
))
EDITS.push(E(
  "PREFERENCES.md",
  "(run from the plugin maintainer's checkout of this plugin; the plugin maintainer decides and reviews the diff)",
  "(run from the plugin maintainer's checkout of this plugin; decides the promotion — the plugin maintainer reviews the uncommitted diff, and the lead commits when the PM asks)",
  "review PR21: PREFERENCES diagram learn caption",
))
EDITS.push(E(
  "PREFERENCES.md",
  "                                → commit + tag  (minor bump)",
  "                                → lead commit (PM asks) · PM push/PR · maintainer merge+tag after verify",
  "t6: preference loop diagram release path",
))
EDITS.push(E(
  "PREFERENCES.md",
  "5. Version-bumps (minor for new prefs/capability, patch for a tiny tweak), runs `audit`, hands off. Commit/tag left to the user (git rule).",
  "5. Version-bumps (minor for new prefs/capability, patch for a tiny tweak), runs `audit`, hands off per `skills/kru-roster/learn.md` → §5 and `skills/kru-lead/SKILL.md` → *Who acts at the door*.",
  "t6: learn tier-2 step 5 door roles",
))
EDITS.push(E(
  "PREFERENCES.md",
  "then a **curated sweep** that edits the team and leaves the commit to the user (mirroring the `TODOS.md` → `/kru-brief` promotion the team already runs)",
  "then a **curated sweep** that edits the team and hands off per steps 3 and 5 below (mirroring the `TODOS.md` → `/kru-brief` promotion the team already runs)",
  "review PR21: PREFERENCES loop prose matches learn hand-off",
))
EDITS.push(E(
  "PREFERENCES.md",
  "Run it **from the plugin source repo** periodically (not from a product repo — it commits the plugin). It:",
  "Run it **from the plugin maintainer's checkout of this plugin** periodically (not from a product repo — it changes the plugin). It:",
  "review PR21: PREFERENCES tier-2 intro matches learn.md",
))
EDITS.push(E(
  "agents/dispatch-auditor.md",
  "/kru-roster learn` sweeps, dedupes, and decides the promotion; the user reviews its diff before any commit.",
  "/kru-roster learn` sweeps, dedupes, and decides the promotion; the plugin maintainer reviews the uncommitted diff, and the lead `commit`s when the PM asks.",
  "review PR21: dispatch-auditor learn hand-off",
))
EDITS.push(E(
  "ROSTER.md",
  "/kru-roster learn` decides the promotion and the user reviews its diff before any commit.",
  "/kru-roster learn` decides the promotion; the plugin maintainer reviews the uncommitted diff, and the lead `commit`s when the PM asks.",
  "review PR21: ROSTER dispatch-auditor learn hand-off",
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
const LEARN_INTRO_AFTER =
  "The review is the uncommitted diff — the plugin maintainer reviews it before it ships, so an edit they disagree with is reverted first.\n\nRun this **from the plugin maintainer's checkout of this plugin** (it changes the plugin), not a product repo. The sweep leaves the diff uncommitted through review; hand off per `${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Who acts at the door* (`/kru-roster learn`). The owner's words (`owner`) outrank a PM's (`pm`) in every verdict below. The inbox is user-global, so it's the same source wherever you run it."
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "The review is the uncommitted diff — commit stays the user's, so an edit they disagree with is reverted before it ships.\n\nRun this **from the plugin source repo** (it commits the plugin), not a product repo. The inbox is user-global, so it's the same source wherever you run it.",
  LEARN_INTRO_AFTER,
  "t6: learn runs from the plugin maintainer's checkout; the owner outranks",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "The review is the uncommitted diff — the plugin maintainer's, so an edit they disagree with is reverted before it ships.\n\nRun this **from the plugin maintainer's checkout of this plugin** (it changes the plugin), not a product repo. The plugin maintainer reviews the diff, commits, pushes, opens the pull request, merges and tags — the plugin maintainer owns this plugin's releases. The owner's words (`owner`) outrank a PM's (`pm`) in every verdict below.",
  LEARN_INTRO_AFTER,
  "review PR21: learn intro matches kru-lead Who acts at the door",
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
  "The lead `commit`s locally on the branch when the PM asks; the PM bot pushes and opens the pull request; merge and `tag` per `${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Who acts at the door*.",
  "t6",
))
EDITS.push(E(
  "skills/kru-roster/learn.md",
  "`commit`, push, pull request, merge and `tag` are the plugin maintainer's (`${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Who acts at the door*).",
  "The lead `commit`s locally on the branch when the PM asks; the PM bot pushes and opens the pull request; merge and `tag` per `${CURSOR_PLUGIN_ROOT}/skills/kru-lead/SKILL.md` → *Who acts at the door*.",
  "review PR21: learn §5 hand-off matches kru-lead Who acts at the door",
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

// --- dispatch: Task subagent_type is kru-<seat> ------------------------
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "## Delegate on stack, not size\nA specialist's value is its official-source discipline \u2014 Svelte MCP and its autofixer, Better Auth's\nCLI schema, Next's cache semantics, parameterized SQL \u2014 not lines of code. A change routes to its\nstack's seat whenever getting it right needs that seat's source chain \u2014 its MCP, autofixer, CLI \u2014\nhowever small it is; a change fully specified and checkable inline (a reviewer's exact replacement\nafter the loop closed, a version pin) runs inline, on the seat's skills (below). A stack's own config file is that stack (`turbo.json`,\n`wrangler.jsonc`, `fly.toml` go to their seats), and a red or flaky suite no build is running is\n`test-writer`'s, however small the fix looks. A question with no code to write routes too when a\nseat owns the answer: where a seam goes is `architecture-reviewer`'s, even answered in prose.\nImplement inline for the genuinely stack-agnostic: a typo, a rename, a string the user dictates, a\ncomment, docs. Rewording a screen people find confusing is judgment, not a string fix, so it is\n`ux-designer`'s. When in doubt, route.\n\nInline work runs on the seat's sources: before the edit, load every skill the definition of the seat\nthat would have taken the job names (`agents/<seat>.md` lists them), so inline work runs on the\nsources the seat would have. Inline work spawns no reviewer, so you are both halves of the gate.\n\n",
  "## Delegate on stack, not size\nA specialist's value is its official-source discipline \u2014 Svelte MCP and its autofixer, Better Auth's\nCLI schema, Next's cache semantics, parameterized SQL \u2014 not lines of code. A change routes to its\nstack's seat whenever getting it right needs that seat's source chain \u2014 its MCP, autofixer, CLI \u2014\nhowever small it is. A stack's own config file is that stack (`turbo.json`,\n`wrangler.jsonc`, `fly.toml` go to their seats), and a red or flaky suite no build is running is\n`test-writer`'s, however small the fix looks. A question with no code to write routes too when a\nseat owns the answer: where a seam goes is `architecture-reviewer`'s, even answered in prose.\nRewording a screen people find confusing is judgment, not a string fix, so it is\n`ux-designer`'s. When in doubt, route.\n\n**Dispatch is a Task tool call with `subagent_type` `kru-<seat>`.** That string is the seat's `name:` in `agents/<seat>.md` (`kru-code-reviewer`, `kru-react-ui-builder`). Prose may say the bare seat; the Task call uses `kru-<seat>`. Never do that seat's work in the main thread. Try the call. If the Task tool rejects `kru-<seat>` or does not offer it, report the types it offered and stop. Do not do the seat's work inline, and do not decide that from a directory listing.\n\n**Inline is a closed list, and the list does not depend on file type.** Only these edits run in the main thread: a typo, a rename, a string the user dictates, a comment, docs, a version pin, a reviewer's exact replacement after the loop closed. A typo or a comment in a CSS, component, route, or test file is still on this list. A behavior, CSS, component, route, or test change that is not on this list is dispatched. A detailed brief is not fully specified. Before that edit, load every skill the definition of the seat that would have taken the job names (`agents/<seat>.md` lists them), so the closed list still runs on the sources the seat would have. Inline work spawns no reviewer, so you are both halves of the gate.\n\n**Lead-owned work is not that list, and it is not a seat's job done inline.** It stays in the main thread because no seat owns it:\n- a user-named pass with no seat — `/kru-seo-review`, `/kru-copywriting`, `/kru-copy-editing`, `/kru-cro`, `/kru-review-animations`, `/kru-improve-animations` — and only when the user names one (`references/screen-passes.md`)\n- the comment pass: read the diff's added comments against `skills/kru-roster/shared-blocks.md` → Block I (`references/gates.md`). `/review` itself is a background subagent, not this pass\n- a scoped test-count check: run the slice's tests and read the count (`references/gates.md`); before any scoped run, `kru-test-writer` dispatch, or Browser check that needs secrets or a database, follow `references/test-credentials.md` and stop the slice on a failed guard. A red or flaky suite, a coverage sweep, and a long run are `kru-test-writer`\n\n**No covering seat: report and stop.** Hiring is the PM's. Until a seat exists, that slice stays parked. Do not implement it.\n\n",
  "dispatch: inline is a closed list; seat work is a Task call",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "each independent unit of work is a **fresh `Task` call** with its own scoped context.",
  "each independent unit of work is a **fresh `Task` call** with `subagent_type` `kru-<seat>` and its own scoped context. Never do that seat's work in the main thread.",
  "dispatch: a fresh unit of work names the Task subagent_type",
))
EDITS.push(E(
  "ROSTER.md",
  "Every specialist follows **official sources first** (`SOURCES.md`).",
  "Every specialist follows **official sources first** (`SOURCES.md`). Each specialist's Task `subagent_type` is `kru-<seat>`, the `name:` in `agents/<seat>.md`. The bare name in the table is the file stem.",
  "dispatch: the roster names the Task subagent_type beside the file stem",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "(e.g. `code-reviewer` + `architecture-reviewer`)",
  "(e.g. `kru-code-reviewer` + `kru-architecture-reviewer`)",
  "dispatch: the batch example uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "The three seats Block O exempts (`test-writer`, `brand-designer`, `ui-designer`)",
  "The three seats Block O exempts (`kru-test-writer`, `kru-brand-designer`, `kru-ui-designer`)",
  "dispatch: Block O names the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "spawn `architecture-reviewer`",
  "spawn `kru-architecture-reviewer`",
  "dispatch: spawn uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "spawn `code-reviewer`",
  "spawn `kru-code-reviewer`",
  "dispatch: spawn uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "\u2014 `accessibility-reviewer`",
  "\u2014 `kru-accessibility-reviewer`",
  "dispatch: the screen pass uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  ") and `visual-reviewer`",
  ") and `kru-visual-reviewer`",
  "dispatch: the screen pass uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "as `code-reviewer`'s",
  "as `kru-code-reviewer`'s",
  "dispatch: the screen pass uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "or `test-writer`)",
  "or `kru-test-writer`)",
  "dispatch: the covering run uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "Spawn `test-writer`",
  "Spawn `kru-test-writer`",
  "dispatch: spawn uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "spawn `ux-auditor`",
  "spawn `kru-ux-auditor`",
  "dispatch: spawn uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "and `ux-auditor` is the only one",
  "and `kru-ux-auditor` is the only one",
  "dispatch: the journey seat uses the Task name",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "every review seat — `code-reviewer`, `architecture-reviewer`, `accessibility-reviewer`, `visual-reviewer`, `ux-auditor` —",
  "every review seat — `kru-code-reviewer`, `kru-architecture-reviewer`, `kru-accessibility-reviewer`, `kru-visual-reviewer`, `kru-ux-auditor` —",
  "dispatch: the review-seat list uses the Task name",
))

EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "Ambient binds you too on the edits you make inline (a rename, a copy fix, a config tweak): the same comment bar applies, canonical text at `skills/kru-roster/shared-blocks.md` → Block I.",
  "Ambient binds you too on the closed inline list in *Delegate on stack, not size* (a typo, a rename, a string the user dictates, a comment, docs, a version pin, a reviewer's exact replacement): the same comment bar applies, canonical text at `skills/kru-roster/shared-blocks.md` → Block I.",
  "dispatch: ambient names the closed inline list",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**The two screen passes have seats you dispatch, and a set of passes that stay the user's.** `visual-reviewer` and `accessibility-reviewer` are review-only seats you spawn at Step 4; `/kru-seo-review`, `/kru-copywriting`, `/kru-copy-editing`, `/kru-cro` and the two animation passes run inline only when the user names one, because each edits work that already exists and each carries taste rather than a rule.",
  "**The two screen passes have seats you dispatch, and a set of passes that are lead-owned.** `visual-reviewer` and `accessibility-reviewer` are review-only seats you spawn at Step 4; `/kru-seo-review`, `/kru-copywriting`, `/kru-copy-editing`, `/kru-cro` and the two animation passes are lead-owned, the list in *Delegate on stack, not size*, and they run in the main thread only when the user names one, because each edits work that already exists and each carries taste rather than a rule. They are not an opening of the closed inline list.",
  "dispatch: user-named passes are lead-owned",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "Ask it in outcomes — a specialist hired for the phone app, or the team builds it without one this time — and on the answer: mint it (`/kru-roster hire <name>` for a seat, `/kru-roster author <name>` for a skill; roster does the wiring, then route to it), or the general path (Explore conventions + implement, backed by Context7) for this slice, on their say-so.",
  "Ask it in outcomes — a specialist hired for the phone app — and on the answer mint it (`/kru-roster hire <name>` for a seat, `/kru-roster author <name>` for a skill; roster does the wiring, then route to it). Until that seat exists, report and stop on the slice. Do not implement it, on the PM's say-so or otherwise. That is the same stop as *Delegate on stack, not size*.",
  "dispatch: no covering seat reports and stops",
))
EDITS.push(E(
  "skills/kru-lead/references/screen-passes.md",
  "These have no seat and you never dispatch them — they run inline in the main thread when the user names one, on the target they name:",
  "These have no seat and you never dispatch them. They are lead-owned, the list in `SKILL.md` → *Delegate on stack, not size*: they run in the main thread when the user names one, on the target they name, and that does not open the closed inline list:",
  "dispatch: user-named passes are lead-owned",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "so **that fork keeps the comment pass yours**: read the diff's added comments against `skills/kru-roster/shared-blocks.md` → Block I before you call the slice reviewed.",
  "so **the comment pass stays lead-owned**, the list in `SKILL.md` → *Delegate on stack, not size*: read the diff's added comments against `skills/kru-roster/shared-blocks.md` → Block I before you call the slice reviewed. `/review` itself is a background subagent, not this pass.",
  "dispatch: the comment pass is lead-owned",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "Either way, see the counts yourself, from a run scoped to the slice's changes — a builder's \"tests pass\" is a narrative until you have; a full suite runs only when the user asks, and a long run is dispatched, not run inline.",
  "Either way, a scoped test-count check is lead-owned, the list in `SKILL.md` → *Delegate on stack, not size*: see the counts yourself, from a run scoped to the slice's changes — a builder's \"tests pass\" is a narrative until you have. A full suite runs only when the user asks. A red or flaky suite, a coverage sweep, and a long run are `kru-test-writer`, not this check.",
  "dispatch: the scoped test-count check is lead-owned",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "A red or flaky suite, a coverage sweep, and a long run are `kru-test-writer`, not this check.",
  "A red or flaky suite, a coverage sweep, and a long run are `kru-test-writer`, not this check. **Test credentials:** before any scoped run, `kru-test-writer` dispatch, or Browser check that needs secrets or a database, follow `references/test-credentials.md` and stop the slice on a failed guard.",
  "test credentials: lead runs the same guards before scoped tests",
))
EDITS.push(E(
  "skills/kru-roster/shared-blocks.md",
  "**Not a substitute for `test-writer`.** This block covers first coverage of behavior the seat is building right now. What needs its own context stays `test-writer`'s (`lead` SKILL.md Step 4): coverage sweeps and fan-out across many files, repairing a red/flaky suite when no builder is in flight, and **capturing** an unfamiliar repo's conventions into a project testing doc. The seat and this block run the same `testing` skill — the split is context, not craft.\n\n## Block F — `## Scope — build the real path, not every path`",
  "**Not a substitute for `test-writer`.** This block covers first coverage of behavior the seat is building right now. What needs its own context stays `test-writer`'s (`lead` SKILL.md Step 4): coverage sweeps and fan-out across many files, repairing a red/flaky suite when no builder is in flight, and **capturing** an unfamiliar repo's conventions into a project testing doc. The seat and this block run the same `testing` skill — the split is context, not craft.\n\n## Block S — `## Test credentials`\n\nRequired on the same seats as Block D (21 behavior seats) plus `test-writer` — anyone who runs or writes tests that may touch secrets or a database. Sits **immediately after** Block D in each behavior seat, or **immediately after** `## The craft (shared skill)` in `test-writer` — matching `scripts/port.mjs` injection.\n\n```\n## Test credentials\nBefore the first test run in a slice that needs secrets or a database, read `${CURSOR_PLUGIN_ROOT}/skills/kru-lead/references/test-credentials.md` and follow it — the lead runs the same guards before a scoped test-count check, a `kru-test-writer` dispatch, or a Browser check that needs secrets or a database.\n```\n\n**No tailored slot** — on Block O's precedent.\n\n**Invariant clauses:**\n- `` `${CURSOR_PLUGIN_ROOT}/skills/kru-lead/references/test-credentials.md` `` — the canonical guard; do not restate its rules in a brief or in this block.\n- `the lead runs the same guards` — one guard for lead, builders, and `test-writer`; a seat that skips it because the brief didn't repeat it is drift.\n\n## Block F — `## Scope — build the real path, not every path`",
  "test credentials: Block S on behavior seats and test-writer",
))
EDITS.push(E(
  "skills/kru-roster/hire.md",
  "`## Test-first (shared skill)` verbatim from there, filling only the marked `{…}` slots. Peer-copying these is what caused the one real drift on record:",
  "`## Test-first (shared skill)` and `## Test credentials` (Block S) verbatim from there, filling only the marked `{…}` slots. Block S has no slots — copy it verbatim, on Block O's precedent. `test-writer` carries Block S without Block D. Peer-copying these is what caused the one real drift on record:",
  "test credentials: hire copies Block S",
))
EDITS.push(E(
  "references/routing.md",
  "| **no specialist matches** | the **user**, naming the seat it would need (*Handling gaps*); the general path only on their say-so |",
  "| **no specialist matches** | the **PM**, naming the seat it would need (*Handling gaps*); report and stop until that seat exists. Do not implement it |",
  "dispatch: an uncovered slice reports and stops",
))
EDITS.push(E(
  "SOURCES.md",
  "Until a dedicated `astro-builder` exists, use the general path + Context7.",
  "Until a dedicated `astro-builder` exists, report and stop (`skills/kru-lead/SKILL.md` → *Handling gaps*). Context7 is the source that seat would use once hired.",
  "dispatch: Astro does not take the general path",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "and the full user-owned list:",
  "and the full lead-owned list:",
  "dispatch: the screen-pass list is lead-owned",
))
EDITS.push(E(
  "skills/kru-lead/references/screen-passes.md",
  "## The user's passes",
  "## The lead-owned passes",
  "dispatch: the screen-pass heading is lead-owned",
))
EDITS.push(E(
  "skills/kru-lead/references/screen-passes.md",
  "which is exactly why they stayed the user's when the two screen passes didn't:",
  "which is exactly why they are lead-owned, and named by the user, when the two screen passes are not:",
  "dispatch: taste passes stay lead-owned",
))
EDITS.push(E(
  "TRACKER.md",
  "- A **brief** (`plan/<effort>/brief.md`) is prose, not typed — no frontmatter, no id, no status. Its presence in an effort dir **is** the handoff signal to `planner`, which reads it as the already-scoped brief for to-spec. See *The brief* below.",
  "- A **brief** (`plan/<effort>/brief.md`) is prose, not typed — no frontmatter and no status. Issue ids live in `## Tracker`, not in frontmatter. Its presence in an effort dir **is** the handoff signal to `planner`, which reads it as the already-scoped brief for to-spec. See *The brief* below.",
  "brief drift: a brief has no frontmatter id; issue ids live in Tracker",
))

// --- cursor: skill prose names Cursor cloud agents, not Claude Code ------
EDITS.push(E(
  "skills/kru-writing-for-agents/CALIBRATION.md",
  "<!-- repo-owned, not vendored: the model-generation branch of `writing-for-agents`, sourced from Anthropic's \"The New Rules of Context Engineering for Claude 5 Generation Models\" (claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/). Survives a re-sync of SKILL.md unchanged; SKILL.md's pointer to it is deviation (4) in that file's vendoring note. -->\n\n# Calibrating for the Claude 5 generation\n\nThe model-generation branch of [`writing-for-agents`](SKILL.md): what changes when the reader is a Claude 5 generation model. Anthropic cut over 80% of Claude Code's own system prompt for these models with no measurable eval loss — most of what came out was guardrails written for an older model's worst case. Everything else about writing is the universal reference in `SKILL.md`; this file says where its levers now point.\n\n## Judgment over rules\n\nA rule written against the worst case binds the good case too. _Default to writing no comments_ stopped the noise an older model produced, and also stopped the comment a genuinely tricky block needed. The replacement states the target the rule was serving and lets the model judge each case against it: _write code that reads like the surrounding code — match its comment density, naming, and idiom._\n\nSo the first draft of any rule is its **goal**, and the rule survives only where a wrong judgment can't be walked back — security, money, data loss, a public push, the `⚠` invariants drift has actually dropped. Everywhere else, the goal plus the reason is the instruction. This is **overconstraint**, and it is the failure mode the no-op test under *Pruning* misses: a no-op changes nothing, an overconstraint changes behaviour for the worse in exactly the cases the author didn't picture.\n\n## One voice per topic, across layers\n\nA seat runs under a stack — the harness system prompt, the user's `~/.claude/CLAUDE.md`, the repo's `AGENTS.md`, this plugin's seat prompt and shared blocks, the skills it loads, the brief. Each layer can be right alone and contradict the next: _leave documentation as appropriate_ in one, _do not add comments_ in another. The model spends its judgment reconciling the authors instead of the task.\n\nBefore a rule lands, read what the layers above already say on its topic. Agreement makes the new line a duplicate (*Pruning*); disagreement is a conflict to resolve at its source, never one to win by louder wording or a `⚠`.\n\n## Interfaces over examples\n\nExamples narrow — the model copies their shape and stops exploring past it. A well-typed interface teaches the usage instead: Claude Code's todo tool went from ~9,100 characters of examples and guidelines to a short description, a `pending | in_progress | completed` enum, and one constraint (one task `in_progress` at a time).\n\nHere the interface is a return contract, a frontmatter field, a ticket schema, a hook's checked line. Where a document reaches for a worked example to show a format, give the format a closed set of values and one stated constraint first; keep the example only if the shape still misreads without it.\n\n## Rich references over prose specs\n\nA spec in prose is a lossy description of something that usually exists in a richer form. Point at the richer form: the test suite that pins the behaviour, the function in another codebase to match, an artifact mockup, a **rubric** a verifier agent can grade against. Code is the highest-fidelity spec a model reads — it is written in a language the model knows better than any description of it.\n",
  "<!-- repo-owned, not vendored: the calibration branch of `writing-for-agents` for a Cursor cloud agent, model-agnostic (best model per task). The levers were first written up in Anthropic's context-engineering note (claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/) and are restated here for this harness. Survives a re-sync of SKILL.md unchanged; SKILL.md's pointer to it is deviation (4) in that file's vendoring note. -->\n\n# Calibrating for Cursor cloud agents\n\nThe calibration branch of [`writing-for-agents`](SKILL.md): what changes when the reader is a Cursor cloud agent. The model is whichever is best for the task; these levers do not change with that pick. The evidence they rest on is a published cut of a coding harness's system prompt — over 80%, no measurable eval loss — most of which was guardrails written for an older model's worst case. Everything else about writing is the universal reference in `SKILL.md`; this file says where its levers now point.\n\n## Judgment over rules\n\nA rule written against the worst case binds the good case too. _Default to writing no comments_ stopped the noise an older model produced, and also stopped the comment a genuinely tricky block needed. The replacement states the target the rule was serving and lets the model judge each case against it: _write code that reads like the surrounding code — match its comment density, naming, and idiom._\n\nSo the first draft of any rule is its **goal**, and the rule survives only where a wrong judgment can't be walked back — security, money, data loss, a public push, the `⚠` invariants drift has actually dropped. Everywhere else, the goal plus the reason is the instruction. This is **overconstraint**, and it is the failure mode the no-op test under *Pruning* misses: a no-op changes nothing, an overconstraint changes behaviour for the worse in exactly the cases the author didn't picture.\n\n## One voice per topic, across layers\n\nA seat runs under a stack — the harness system prompt, User Rules, Team Rules, root `AGENTS.md`, and a `.cursor/rules` file with `alwaysApply: true`, this plugin's seat prompt and shared blocks, the skills it loads, the brief. Each layer can be right alone and contradict the next: _leave documentation as appropriate_ in one, _do not add comments_ in another. The model spends its judgment reconciling the authors instead of the task.\n\nBefore a rule lands, read what the layers above already say on its topic. Agreement makes the new line a duplicate (*Pruning*); disagreement is a conflict to resolve at its source, never one to win by louder wording or a `⚠`.\n\n## Interfaces over examples\n\nExamples narrow — the model copies their shape and stops exploring past it. A well-typed interface teaches the usage instead: a Cursor cloud agent's todo list is a short description and a `pending | in_progress | completed | cancelled` status. `merge: true` patches todos by id; `merge: false` replaces the list.\n\nHere the interface is a return contract, a frontmatter field, a ticket schema, a hook's checked line. Where a document reaches for a worked example to show a format, give the format a closed set of values and one stated constraint first; keep the example only if the shape still misreads without it.\n\n## Rich references over prose specs\n\nA spec in prose is a lossy description of something that usually exists in a richer form. Point at the richer form: the test suite that pins the behaviour, the function in another codebase to match, an artifact mockup, a **rubric** a verifier agent can grade against. Code is the highest-fidelity spec a model reads — it is written in a language the model knows better than any description of it.\n",
  "cursor: calibrate for a cloud agent, model-agnostic",
))
EDITS.push(E(
  "skills/kru-writing-for-agents/SKILL.md",
  "When you're adding a rule, a worked example, or a prose spec, read [`CALIBRATION.md`](CALIBRATION.md) — where the Claude 5 generation wants judgment, an interface, or a reference instead.",
  "When you're adding a rule, a worked example, or a prose spec, read [`CALIBRATION.md`](CALIBRATION.md) — where a Cursor cloud agent wants judgment, an interface, or a reference instead. The model is whichever fits the task.",
  "cursor: the calibration pointer is model-agnostic",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "(the user's `~/.claude/CLAUDE.md`)",
  "(root `AGENTS.md`, or a `.cursor/rules` file with `alwaysApply: true`)",
  "cursor: machine budget lives in rules or AGENTS.md",
))
EDITS.push(E(
  "skills/kru-lead/references/gates.md",
  "(the user's `~/.claude/CLAUDE.md`)",
  "(root `AGENTS.md`, or a `.cursor/rules` file with `alwaysApply: true`)",
  "cursor: machine budget lives in rules or AGENTS.md",
))
EDITS.push(E(
  "skills/kru-update/SKILL.md",
  "a machine constraint the user's `~/.claude/CLAUDE.md` sets",
  "a machine constraint root `AGENTS.md` or an `alwaysApply: true` rule sets",
  "cursor: machine budget lives in rules or AGENTS.md",
))
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "every rule an always-loaded AGENTS.md carries — the working repo's, or the user's own `~/.claude/CLAUDE.md`: its machine budget, its comment standard, its dependency policy, whatever it states). Point at it or say nothing — and an AGENTS.md section, repo or user, loads into every seat on its own, so there saying nothing is the whole move",
  "every rule root `AGENTS.md` or a `.cursor/rules` file with `alwaysApply: true` carries: its machine budget, its comment standard, its dependency policy, whatever it states). Point at it or say nothing — those load into every seat on their own ([rules](https://cursor.com/docs/rules)), so there saying nothing is the whole move. Any other rule does not, and the brief carries the constraint",
  "cursor: ambient rules are .cursor/rules and AGENTS.md",
))
EDITS.push(E(
  "skills/kru-copy-editing/SKILL.md",
  "(or `.claude/product-marketing.md`, or the legacy `product-marketing-context.md` filename, in older setups)",
  "(or the legacy `product-marketing-context.md` filename, in older setups)",
  "cursor: drop the .claude product-marketing fallback",
))
EDITS.push(E(
  "skills/kru-copywriting/SKILL.md",
  "(or `.claude/product-marketing.md`, or the legacy `product-marketing-context.md` filename, in older setups)",
  "(or the legacy `product-marketing-context.md` filename, in older setups)",
  "cursor: drop the .claude product-marketing fallback",
))
EDITS.push(E(
  "skills/kru-cro/SKILL.md",
  "(or `.claude/product-marketing.md`, or the legacy `product-marketing-context.md` filename, in older setups)",
  "(or the legacy `product-marketing-context.md` filename, in older setups)",
  "cursor: drop the .claude product-marketing fallback",
))
EDITS.push(E(
  "skills/kru-cro/references/form.md",
  "If `.agents/product-marketing.md` exists (or `.claude/product-marketing.md` in older setups), read it before asking questions.",
  "If `.agents/product-marketing.md` exists, read it before asking questions.",
  "cursor: drop the .claude product-marketing fallback",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "- **A language server is not its compiler.** `typescript-lsp@claude-plugins-official` declares\n  `lspServers` and ships no binary, so it stays inert until `typescript-language-server` is on PATH.",
  "- **A language server is not its compiler.** A plugin that declares\n  `lspServers` and ships no binary stays inert until `typescript-language-server` is on PATH.",
  "cursor: the language-server check does not name a Claude marketplace plugin",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "Open the repo's `AGENTS.md`, `.cursor/rules/*.mdc`, `AGENTS.md`, and any nested\nmember `AGENTS.md`. That is the whole always-loaded surface, and reading it in one pass is the vantage\nstep 3 works from.",
  "Open root `AGENTS.md`, nested `AGENTS.md`, and `.cursor/rules/**/*.mdc`. Root `AGENTS.md` and a rule with `alwaysApply: true` load every session; a rule with globs or a description loads only when it matches ([rules](https://cursor.com/docs/rules)). User Rules and Team Rules are not files in the repo — Customize, and the team dashboard. That is the whole always-loaded surface, and reading it in one pass is the vantage\nstep 3 works from.",
  "cursor: the always-loaded surface is root AGENTS.md, alwaysApply rules, and User and Team Rules",
))
EDITS.push(E(
  "skills/kru-eval-review/SKILL.md",
  "description: Audit a `claude plugin eval` suite for checks that pass or fail for the wrong reason, and fix the eval files in place.",
  "description: Audit an upstream plugin-eval suite already in the tree for checks that pass or fail for the wrong reason, and fix the eval files in place. Cursor has no eval runner; do not install one.",
  "cursor: eval-review does not send the reader to install a runner",
))
EDITS.push(E(
  "skills/kru-eval-review/SKILL.md",
  "The format is `code.claude.com/docs/en/plugin-evals.md` (fetch it; grader types, `target` values and the two-arm exclusions change with the CLI). The model-agnostic checklist, the one for any eval, is `shared/evals/eval-audit.md` inside the `/claude-api` skill. Run both; this file carries only what those two don't: the traps specific to grading an agent plugin from its trace. Every trap below was reproduced on Claude Code 2.1.284, 2026-09-29.",
  "Cursor has no plugin-eval runner, and this repo ships no eval suite. Do not install a runner. When a suite is already in the tree, the argument names its directory; grade it in place. The traps below are the whole checklist. Every trap below was reproduced against harness traces from 2.1.284 on 2026-09-29.",
  "cursor: eval-review grades an existing suite and does not start Claude Code",
))
EDITS.push(E(
  "skills/kru-eval-review/SKILL.md",
  "argument-hint: \"[<eval dir> — omit for evals/]\"",
  "argument-hint: \"[<eval dir>]\"",
  "cursor: eval-review has no default evals/ directory",
))
EDITS.push(E(
  "skills/kru-eval-review/SKILL.md",
  "1. **Resolve the target**: the argument, else `evals/`, else the manifest's `experimental.evals`. Read every case's `prompt.md`, `case.yaml` and `graders/*.md`, and the suite's README if it has one.",
  "1. **Resolve the target**: the argument, a directory already in the tree. This repo has no `evals/` directory. Read every case's `prompt.md`, `case.yaml` and `graders/*.md`, and the suite's README if it has one.",
  "cursor: eval-review has no default evals/ directory",
))
EDITS.push(E(
  "ROSTER.md",
  "It carries only the agent-plugin traps; the format is `code.claude.com/docs/en/plugin-evals.md` and the model-agnostic checklist is `/claude-api`'s `shared/evals/eval-audit.md`, both run beside it. Worked example: this repo's `evals/`.",
  "This repo ships no eval suite, so the argument names a suite already in the tree.",
  "cursor: the roster does not point at a checklist or an evals/ directory this repo does not ship",
))
EDITS.push(E(
  "SOURCES.md",
  "Its **`CALIBRATION.md`** is repo-owned too, sourced from Anthropic's *New Rules of Context Engineering for Claude 5 Generation Models* — judgment over rules, one voice per topic across layers, interfaces over examples, rich references over prose specs.",
  "Its **`CALIBRATION.md`** is repo-owned too: calibration for a Cursor cloud agent, model-agnostic (best model per task) — judgment over rules, one voice per topic across layers, interfaces over examples, rich references over prose specs. The levers were first written up for a newer model generation; the file restates them for this harness.",
  "cursor: the source map describes calibration for a cloud agent",
))
EDITS.push(E(
  "SOURCES.md",
  "and a second pointing at **`CALIBRATION.md`**, the repo-owned model-generation reference (sourced from Anthropic's Claude 5 context-engineering post)",
  "and a second pointing at **`CALIBRATION.md`**, the repo-owned calibration for a Cursor cloud agent (model-agnostic; the levers were first written up in Anthropic's context-engineering post)",
  "cursor: the vendored-resources note matches the reframed calibration file",
))

EDITS.push(E(
  "hooks/check-handoff.sh",
  "# whose brief asserts a file:line coordinate, a verbatim run of an always-loaded\n# rule, a paraphrase of the user CLAUDE.md\n# machine budget or the comment standard, a request for the return-pass line,\n",
  "# whose brief asserts a file:line coordinate, a verbatim run of an always-loaded\n# rule, a paraphrase of the machine budget (root AGENTS.md, an alwaysApply\n# rule, or ~/.claude/CLAUDE.md as fallback) or the comment standard, a request for the return-pass line,\n",
  "cursor: the handoff header names root AGENTS.md and alwaysApply rules",
))

EDITS.push(E(
  "hooks/check-handoff.sh",
  "# the two texts briefs re-type as paraphrase, which no shingle sees — lead scan 2\n# names these greps.\nUSER_CANON=\"$HOME/.claude/CLAUDE.md\"\nif [ -f \"$USER_CANON\" ]; then\n  # a brief naming some other limit — an R2 object cap, a container's memory\n  # request, a machine that isn't this one — states a fact about the slice, so\n  # the figure has to be one this file spends before it reads as re-typed, and\n  # its sentence can't be about a deployed resource (\"resize the Machine to 8 GB\").\n  DEPLOYED='\\b(resize|scale|deploy(ed|s)?|provision(ed)?|instances?|vms?|containers?|pods?|fly|vercel|tier|region)\\b'\n  nfig() { tr '[:upper:]' '[:lower:]' | tr -d ' ' | sed 's/cores$/core/'; }\n  figs=$(grep -oiE '\\b[0-9]+ ?(gb|cores?)\\b' \"$USER_CANON\" | nfig | sort -u)\n  budget=\"\"\n  # the reason quotes the brief's own spelling — the lead greps for the\n  # sentence it names.\n  if [ -n \"$figs\" ]; then\n    while IFS= read -r raw; do\n      [ -z \"$raw\" ] && continue\n      printf '%s\\n' \"$figs\" | grep -Fxq \"$(printf '%s' \"$raw\" | nfig)\" || continue\n      budget=\"$raw\"; break\n    done < <(printf '%s' \"$prompt\" | tr '\\n' ' ' | tr '.' '\\n' | grep -viE \"$DEPLOYED\" | grep -oiE '\\b[0-9]+ ?(gb|cores?)\\b')\n  fi\n  # \"one X at a time\" is ordinary English — pacing tickets, rows, migrations,\n  # a single writer. it's the machine budget only where a machine word sits in\n  # the same sentence. the quote is the pacing clause, not the machine word —\n  # that word is often the test command the slice legitimately names.\n  [ -z \"$budget\" ] && budget=$(printf '%s' \"$prompt\" |\n    grep -oiE '[^.]*\\b(one|a single)( [a-z-]+){1,3} at a time\\b[^.]*' |\n    grep -iE '\\b(ram|memory|swap|cores?|cpu|machine|budget|background shells?|long-running|headless|chromium|vitest|playwright|tsc)\\b' |\n    grep -oiE '\\b(one|a single)( [a-z-]+){1,3} at a time\\b' | head -1)\n  [ -n \"$budget\" ] && reasons=\"${reasons}paraphrases the user CLAUDE.md machine budget: \\\"${budget}\\\" — that file loads into every seat on its own; cut that clause, keep any command the slice runs (scan 2). \"\nfi\n",
  "# the two texts briefs re-type as paraphrase, which no shingle sees — lead scan 2\n# names these greps. the machine budget is what loads into every seat: root\n# AGENTS.md and a .cursor/rules file with alwaysApply: true (nested included).\n# ~/.claude/CLAUDE.md is the fallback only when the repo has neither.\nUSER_CANON=\"$HOME/.claude/CLAUDE.md\"\nrule_always() {\n  awk 'BEGIN { fm = 0 }\n    /^---[[:space:]]*$/ { fm++; if (fm >= 2) exit; next }\n    fm == 1 && /^[[:space:]]*alwaysApply:[[:space:]]*true[[:space:]]*$/ { found = 1; exit }\n    END { exit found ? 0 : 1 }' \"$1\"\n}\n# one source set for the budget paraphrase and the verbatim shingle. walks to\n# the git root: root AGENTS.md, then every .cursor/rules file with\n# alwaysApply: true, nested included. a top-level .cursor/rules/*.mdc glob is\n# not this set — it skips nested rules and ignores alwaysApply.\n# ~/.claude/CLAUDE.md is the only entry when that set is empty — a stale 8 GB\n# must not refuse a brief the repo's own file already contradicts.\nalways_loaded() { # start dir → NUL-delimited paths\n  local start=$1 root d f any=false\n  root=$start\n  d=$start\n  while [ -n \"$d\" ] && [ \"$d\" != \"/\" ] && [ \"$d\" != \".\" ]; do\n    [ -e \"$d/.git\" ] && { root=$d; break; }\n    d=$(dirname \"$d\")\n  done\n  if [ -n \"$root\" ] && [ -f \"$root/AGENTS.md\" ]; then\n    printf '%s\\0' \"$root/AGENTS.md\"\n    any=true\n  fi\n  if [ -n \"$root\" ] && [ -d \"$root/.cursor/rules\" ]; then\n    while IFS= read -r -d '' f; do\n      if [ -n \"$f\" ] && rule_always \"$f\"; then\n        printf '%s\\0' \"$f\"\n        any=true\n      fi\n    done < <(find \"$root/.cursor/rules\" -type f -name '*.mdc' -print0)\n  fi\n  if ! $any && [ -f \"$USER_CANON\" ]; then\n    printf '%s\\0' \"$USER_CANON\"\n  fi\n}\nalways_files=()\nwhile IFS= read -r -d '' f; do\n  [ -n \"$f\" ] && always_files+=(\"$f\")\ndone < <(always_loaded \"$cwd\")\nif [ \"${#always_files[@]}\" -gt 0 ]; then\n  # a brief naming some other limit — an R2 object cap, a container's memory\n  # request, a machine that isn't this one — states a fact about the slice, so\n  # the figure has to be one these files spend before it reads as re-typed, and\n  # its sentence can't be about a deployed resource (\"resize the Machine to 8 GB\").\n  DEPLOYED='\\b(resize|scale|deploy(ed|s)?|provision(ed)?|instances?|vms?|containers?|pods?|fly|vercel|tier|region)\\b'\n  nfig() { tr '[:upper:]' '[:lower:]' | tr -d ' ' | sed 's/cores$/core/'; }\n  figs=$(for f in \"${always_files[@]}\"; do [ -f \"$f\" ] && grep -oiE '\\b[0-9]+ ?(gb|cores?)\\b' \"$f\"; done | nfig | sort -u)\n  budget=\"\"\n  # the reason quotes the brief's own spelling — the lead greps for the\n  # sentence it names.\n  if [ -n \"$figs\" ]; then\n    while IFS= read -r raw; do\n      [ -z \"$raw\" ] && continue\n      printf '%s\\n' \"$figs\" | grep -Fxq \"$(printf '%s' \"$raw\" | nfig)\" || continue\n      budget=\"$raw\"; break\n    done < <(printf '%s' \"$prompt\" | tr '\\n' ' ' | tr '.' '\\n' | grep -viE \"$DEPLOYED\" | grep -oiE '\\b[0-9]+ ?(gb|cores?)\\b')\n  fi\n  # \"one X at a time\" is ordinary English — pacing tickets, rows, migrations,\n  # a single writer. it's the machine budget only where a machine word sits in\n  # the same sentence. the quote is the pacing clause, not the machine word —\n  # that word is often the test command the slice legitimately names.\n  [ -z \"$budget\" ] && budget=$(printf '%s' \"$prompt\" |\n    grep -oiE '[^.]*\\b(one|a single)( [a-z-]+){1,3} at a time\\b[^.]*' |\n    grep -iE '\\b(ram|memory|swap|cores?|cpu|machine|budget|background shells?|long-running|headless|chromium|vitest|playwright|tsc)\\b' |\n    grep -oiE '\\b(one|a single)( [a-z-]+){1,3} at a time\\b' | head -1)\n  [ -n \"$budget\" ] && reasons=\"${reasons}paraphrases the machine budget: \\\"${budget}\\\" — root AGENTS.md and an alwaysApply rule load into every seat; ~/.claude/CLAUDE.md is only the fallback. Cut that clause, keep any command the slice runs (scan 2). \"\nfi\n",
  "cursor: machine budget is root AGENTS.md and alwaysApply rules; the home file is the fallback",
))

EDITS.push(E(
  "hooks/check-handoff.sh",
  "# an always-loaded rule restated in the brief is a second source that drifts —\n# scan 2 says point at the file instead. the mechanizable half is the verbatim\n# one: a run of SHINGLE words from the brief found unchanged in a canonical\n# text. paraphrase stays a reading check; a shorter run would misfire on\n# ordinary phrasing, so the length is the fail-open margin. rule files are\n# terse, so the run shortens with them: six words from the repo's own\n# CLAUDE.md or rules, five from the user's, where the machine budget is the\n# text briefs re-type most.\nSHINGLE=8\nSHINGLE_REPO=6\nSHINGLE_USER=5\ncanon=\"\"\nrepo_canon=\"\"\nfor f in \"$cwd/CLAUDE.md\" \"$cwd/AGENTS.md\" \"$cwd\"/.cursor/rules/*.mdc; do\n  [ -f \"$f\" ] && canon=\"$canon $f\" && repo_canon=\"$repo_canon $f\"\ndone\nfor f in \"$USER_CANON\" \"$plugin_root/skills/kru-roster/shared-blocks.md\"; do\n  [ -f \"$f\" ] && canon=\"$canon $f\"\ndone\n# the plan store's contract is the file a planner brief re-types (lead step 2.6)\n[ \"$seat\" = \"planner\" ] && [ -f \"$plugin_root/TRACKER.md\" ] && canon=\"$canon $plugin_root/TRACKER.md\"\n# a path and a backticked identifier are the pointer scan 2 asks for in place\n# of the text, and stripping punctuation turns one of them into a six-word run\n# any repo's own path map already spends — the gate refusing its own remedy.\n# barrier each with a word no canon holds, so a pointer neither matches on its\n# own nor joins the prose on either side of it.\nBARRIER=' zzpointerzz '\npoint() { sed -E -e \"s/\\`[^\\`]*\\`/${BARRIER}/g\" \\\n  -e \"s#[A-Za-z0-9_@~.-]*/[A-Za-z0-9_@~./-]*#${BARRIER}#g\" \\\n  -e \"s/[A-Za-z0-9_-]+\\.(tsx?|jsx?|mjs|cjs|svelte|vue|astro|md|go|py|rs|css|scss|json|sql|html|ya?ml|toml|sh)/${BARRIER}/g\"; }\nnorm() { tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]\\n' ' ' | tr -s ' \\n' ' '; }\nshingle() { # files → \"file<TAB>run\" of the first verbatim hit\n  printf '%s' \"$prompt\" | point | norm | awk -v n=\"$SHINGLE\" -v nr=\"$SHINGLE_REPO\" -v ns=\"$SHINGLE_USER\" -v short=\"$USER_CANON\" -v repo=\" $repo_canon \" -v files=\"$1\" '\n    BEGIN {\n      split(files, fs, \" \")\n      for (i in fs) { f = fs[i]; if (f == \"\") continue\n        text = \"\"\n        while ((getline line < f) > 0) text = text \" \" tolower(line)\n        close(f)\n        gsub(/[^[:alnum:]]+/, \" \", text)\n        corpus[f] = text }\n    }\n    { for (f in corpus) { m = (f == short) ? ns : (index(repo, \" \" f \" \") ? nr : n)\n        for (i = 1; i + m - 1 <= NF; i++) {\n          s = $i; for (j = 1; j < m; j++) s = s \" \" $(i + j)\n          if (index(corpus[f], \" \" s \" \")) { print f \"\\t\" s; exit } } } }'\n}\nif [ -n \"$canon\" ]; then\n  hit=$(shingle \"$canon\")\n  [ -n \"$hit\" ] && reasons=\"${reasons}restates a file verbatim: \\\"${hit#*	}\\\" is in ${hit%%	*} — point at the file instead (scan 2). \"\nfi\n\n# planner reads a written brief.md (lead step 2.6)\nif [ \"$seat\" = \"planner\" ] && ! printf '%s' \"$prompt\" | grep -q 'brief\\.md'; then\n  reasons=\"${reasons}planner brief names no brief.md: run /kru-brief first and point the seat at the written file (step 2.6). \"\nfi\n\n# shadow scans — logged, never refused.\nshadow=\"\"\n",
  "# an always-loaded rule restated in the brief is a second source that drifts —\n# scan 2 says point at the file instead. the mechanizable half is the verbatim\n# one: a run of SHINGLE words from the brief found unchanged in a canonical\n# text. paraphrase stays a reading check; a shorter run would misfire on\n# ordinary phrasing, so the length is the fail-open margin. rule files are\n# terse, so the run shortens with them: six words from root AGENTS.md or an\n# alwaysApply rule, five from ~/.claude/CLAUDE.md when it is the fallback,\n# where the machine budget is the text briefs re-type most.\nSHINGLE=8\nSHINGLE_REPO=6\nSHINGLE_USER=5\n# always_files is the budget's source set (always_loaded, above). a home file\n# in it is the fallback, so it keeps the shorter run; repo files keep six.\ncanon_files=()\nrepo_files=()\nif [ \"${#always_files[@]}\" -gt 0 ]; then\n  for f in \"${always_files[@]}\"; do\n    canon_files+=(\"$f\")\n    [ \"$f\" = \"$USER_CANON\" ] || repo_files+=(\"$f\")\n  done\nfi\nsb=\"$plugin_root/skills/kru-roster/shared-blocks.md\"\n[ -f \"$sb\" ] && canon_files+=(\"$sb\")\n# the plan store's contract is the file a planner brief re-types (lead step 2.6)\n[ \"$seat\" = \"planner\" ] && [ -f \"$plugin_root/TRACKER.md\" ] && canon_files+=(\"$plugin_root/TRACKER.md\")\n# a path and a backticked identifier are the pointer scan 2 asks for in place\n# of the text, and stripping punctuation turns one of them into a six-word run\n# any repo's own path map already spends — the gate refusing its own remedy.\n# barrier each with a word no canon holds, so a pointer neither matches on its\n# own nor joins the prose on either side of it.\nBARRIER=' zzpointerzz '\npoint() { sed -E -e \"s/\\`[^\\`]*\\`/${BARRIER}/g\" \\\n  -e \"s#[A-Za-z0-9_@~.-]*/[A-Za-z0-9_@~./-]*#${BARRIER}#g\" \\\n  -e \"s/[A-Za-z0-9_-]+\\.(tsx?|jsx?|mjs|cjs|svelte|vue|astro|md|go|py|rs|css|scss|json|sql|html|ya?ml|toml|sh)/${BARRIER}/g\"; }\nnorm() { tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]\\n' ' ' | tr -s ' \\n' ' '; }\nshingle() { # paths… → \"file<TAB>run\" of the first verbatim hit\n  local files_us repo_us\n  files_us=$(printf '%s\\036' \"$@\")\n  repo_us=\"\"\n  [ \"${#repo_files[@]}\" -gt 0 ] && repo_us=$(printf '%s\\036' \"${repo_files[@]}\")\n  printf '%s' \"$prompt\" | point | norm | awk -v n=\"$SHINGLE\" -v nr=\"$SHINGLE_REPO\" -v ns=\"$SHINGLE_USER\" -v short=\"$USER_CANON\" -v repo=\"$repo_us\" -v files=\"$files_us\" '\n    BEGIN {\n      nf = split(files, fs, \"\\036\")\n      nrp = split(repo, rs, \"\\036\")\n      for (i = 1; i <= nrp; i++) if (rs[i] != \"\") isrepo[rs[i]] = 1\n      for (i = 1; i <= nf; i++) { f = fs[i]; if (f == \"\") continue\n        text = \"\"\n        while ((getline line < f) > 0) text = text \" \" tolower(line)\n        close(f)\n        gsub(/[^[:alnum:]]+/, \" \", text)\n        corpus[f] = text }\n    }\n    { for (f in corpus) { m = (f == short) ? ns : (f in isrepo ? nr : n)\n        for (i = 1; i + m - 1 <= NF; i++) {\n          s = $i; for (j = 1; j < m; j++) s = s \" \" $(i + j)\n          if (index(corpus[f], \" \" s \" \")) { print f \"\\t\" s; exit } } } }'\n}\nif [ \"${#canon_files[@]}\" -gt 0 ]; then\n  hit=$(shingle \"${canon_files[@]}\")\n  [ -n \"$hit\" ] && reasons=\"${reasons}restates a file verbatim: \\\"${hit#*	}\\\" is in ${hit%%	*} — point at the file instead (scan 2). \"\nfi\n\n# planner reads a written brief.md (lead step 2.6)\nif [ \"$seat\" = \"planner\" ] && ! printf '%s' \"$prompt\" | grep -q 'brief\\.md'; then\n  reasons=\"${reasons}planner brief names no brief.md: run /kru-brief first and point the seat at the written file (step 2.6). \"\nfi\n\n# shadow scans — logged, never refused.\nshadow=\"\"\n",
  "cursor: the verbatim shingle reads the same always-loaded set as the budget",
))

EDITS.push(E(
  "hooks/check-handoff.test.sh",
  "check allow kru-fly-platform-engineer \"Resize the Machine to 8 GB in fly.toml.\"\n\n",
  "check allow kru-fly-platform-engineer \"Resize the Machine to 8 GB in fly.toml.\"\n\n# root AGENTS.md and an alwaysApply rule are budget canon; a rule without it is not.\n# the legacy home file stays the fallback (the cases above). cwd is the repo, not /x.\nbudget_repo=$sandbox/budget\nmkdir -p \"$budget_repo/.cursor/rules/nested\" \"$budget_repo/pkg\"\ngit -C \"$budget_repo\" init -q\nprintf '%s\\n' 'The dev box has 16 GB.' > \"$budget_repo/AGENTS.md\"\nprintf '%s\\n' '---' 'alwaysApply: true' '---' 'One suite: 32 GB is the cap.' > \"$budget_repo/.cursor/rules/nested/budget.mdc\"\nprintf '%s\\n' '---' 'alwaysApply: false' '---' 'The laptop has 64 GB.' > \"$budget_repo/.cursor/rules/optional.mdc\"\nbudget_check() {\n  local expect=$1 seat=$2 prompt=$3 needle=${4:-} cwd=${5:-$budget_repo}\n  local input out code\n  input=$(jq -nc --arg s \"$seat\" --arg p \"$prompt inbox.md\" --arg c \"$cwd\" \\\n    '{session_id:\"test\", cwd:$c, tool_input:{subagent_type:$s, prompt:$p, description:\"t\"}}')\n  out=$(cd \"$sandbox/cwd\" && printf '%s' \"$input\" | env -u KRU_HOME -u KRU_PROJECT_STORE -u KRU_STORE_URL -u KRU_NO_GATE -u CURSOR_PLUGIN_ROOT HOME=\"$sandbox/home\" bash \"$hook\" \"$root\" 2>&1)\n  code=$?\n  local ok=true\n  if [ \"$expect\" = refuse ]; then\n    [ \"$code\" -eq 2 ] || ok=false\n    [ -n \"$needle\" ] && ! printf '%s' \"$out\" | grep -qF \"$needle\" && ok=false\n  else\n    [ \"$code\" -eq 0 ] || ok=false\n  fi\n  if $ok; then pass=$((pass + 1)); else\n    fail=$((fail + 1))\n    printf 'FAIL (%s, exit %s): %s\\n  %s\\n' \"$expect\" \"$code\" \"$prompt\" \"$out\"\n  fi\n}\nbudget_check refuse $ui \"The box has 16 GB so be careful.\" \"machine budget\" \"$budget_repo/pkg\"\nbudget_check refuse $ui \"Stay under 32 GB.\" \"machine budget\"\nbudget_check allow $ui \"The laptop has 64 GB.\"\n# the home file is a fallback, not a second canon: its 8 GB must not refuse a\n# brief once the repo has an AGENTS.md or an alwaysApply rule.\nbudget_check allow $ui \"The box has 8 GB so be careful.\"\nrules_only=$sandbox/rules-only\nmkdir -p \"$rules_only/.cursor/rules\"\ngit -C \"$rules_only\" init -q\nprintf '%s\\n' '---' 'alwaysApply: true' '---' 'One suite: 32 GB is the cap.' > \"$rules_only/.cursor/rules/budget.mdc\"\nbudget_check allow $ui \"The box has 8 GB so be careful.\" \"\" \"$rules_only\"\nbudget_check refuse $ui \"Stay under 32 GB.\" \"machine budget\" \"$rules_only\"\nbare=$sandbox/bare\nmkdir -p \"$bare\"\ngit -C \"$bare\" init -q\nbudget_check refuse $ui \"The box has 8 GB so be careful.\" \"machine budget\" \"$bare\"\n# a space in the repo path, and in a rule's filename, still reaches the figure\nspace_repo=\"$sandbox/budget box\"\nmkdir -p \"$space_repo/.cursor/rules\"\ngit -C \"$space_repo\" init -q\nprintf '%s\\n' 'The workstation has 24 GB.' > \"$space_repo/AGENTS.md\"\nprintf '%s\\n' '---' 'alwaysApply: true' '---' 'Cap the suite at 48 GB.' > \"$space_repo/.cursor/rules/my budget.mdc\"\nbudget_check refuse $ui \"The workstation has 24 GB.\" \"machine budget\" \"$space_repo\"\nbudget_check refuse $ui \"Cap the suite at 48 GB.\" \"machine budget\" \"$space_repo\"\nbudget_check allow $ui \"The box has 8 GB so be careful.\" \"\" \"$space_repo\"\n\n# verbatim shingle uses the same always-loaded set as the budget: a rule\n# without alwaysApply is not canon, a nested alwaysApply rule is, and\n# ~/.claude/CLAUDE.md is scanned only when the repo has neither.\nprintf '%s\\n' 'Purple kettles never boil on tuesdays in the annex.' >> \"$sandbox/home/.claude/CLAUDE.md\"\nshingle_repo=$sandbox/shingle\nmkdir -p \"$shingle_repo/.cursor/rules/nested\" \"$shingle_repo/pkg\"\ngit -C \"$shingle_repo\" init -q\nprintf '%s\\n' 'Root agents prose stays the shingle canon for this repo.' > \"$shingle_repo/AGENTS.md\"\nprintf '%s\\n' '---' 'alwaysApply: true' '---' 'Nested amber rule text loads with every session.' > \"$shingle_repo/.cursor/rules/nested/amber.mdc\"\nprintf '%s\\n' '---' 'alwaysApply: false' '---' 'Optional crimson rule text stays out of the brief scan.' > \"$shingle_repo/.cursor/rules/optional.mdc\"\nprintf '%s\\n' 'Root claude file text must not count as shingle canon.' > \"$shingle_repo/CLAUDE.md\"\nbudget_check refuse $ui \"Root agents prose stays the shingle canon for this repo.\" \"AGENTS.md\" \"$shingle_repo/pkg\"\nbudget_check refuse $ui \"Nested amber rule text loads with every session.\" \"nested/amber.mdc\" \"$shingle_repo\"\nbudget_check allow $ui \"Optional crimson rule text stays out of the brief scan.\" \"\" \"$shingle_repo\"\nbudget_check allow $ui \"Root claude file text must not count as shingle canon.\" \"\" \"$shingle_repo\"\nbudget_check allow $ui \"Purple kettles never boil on tuesdays in the annex.\" \"\" \"$shingle_repo\"\n# a non-alwaysApply rule is not primary, so the home file is the fallback\nshingle_optional=$sandbox/shingle-optional\nmkdir -p \"$shingle_optional/.cursor/rules\"\ngit -C \"$shingle_optional\" init -q\nprintf '%s\\n' '---' 'alwaysApply: false' '---' 'Optional crimson rule text stays out of the brief scan.' > \"$shingle_optional/.cursor/rules/optional.mdc\"\nbudget_check allow $ui \"Optional crimson rule text stays out of the brief scan.\" \"\" \"$shingle_optional\"\nbudget_check refuse $ui \"Purple kettles never boil on tuesdays in the annex.\" \".claude/CLAUDE.md\" \"$shingle_optional\"\nshingle_bare=$sandbox/shingle-bare\nmkdir -p \"$shingle_bare\"\ngit -C \"$shingle_bare\" init -q\nbudget_check refuse $ui \"Purple kettles never boil on tuesdays in the annex.\" \".claude/CLAUDE.md\" \"$shingle_bare\"\n\n",
  "cursor: the handoff gate reads root AGENTS.md and alwaysApply rules",
))

// --- cursor: no claude-code-delegation skill (cloud agents use roster request.md) -
EDITS.push(E(
  "ROSTER.md",
  "`claude-code-delegation` and `skills/kru-roster/request.md` both point here for the brief.",
  "`skills/kru-roster/request.md` points here for the brief.",
  "cursor: delegation skill dropped; request.md is the path",
))
EDITS.push(E(
  "ROSTER.md",
  "- **`claude-code-delegation`** (`skills/kru-claude-code-delegation/`) — model-invoked. A build, fix, refactor or review handed to Cursor runs in the cloud or local headless, then meets an independent review before a merge.\n",
  "",
  "cursor: claude-code-delegation skill is not ported",
))
EDITS.push(E(
  "ROSTER.md",
  "`reliable-work`, `claude-code-delegation`, `/kru-roster`",
  "`reliable-work`, `/kru-roster`",
  "cursor: skills list drops claude-code-delegation",
))
EDITS.push(E(
  "ROSTER.md",
  "5. `bash scripts/verify.sh` passes (`PORTING.md` — the verify gate at the top), then `git add -A && git commit && git tag vX.Y.Z`.",
  "5. `bash scripts/verify.sh` passes (`PORTING.md` — the verify gate at the top), then `git add -A && git commit` on the branch (the lead); the PM bot pushes and opens the pull request; merge and `tag vX.Y.Z` per `skills/kru-lead/SKILL.md` → *Who acts at the door* and `skills/kru-roster/release.md`.",
  "review PR21: git row matches release.md and kru-lead Who acts at the door",
))
EDITS.push(E(
  "skills/kru-setup/SKILL.md",
  "The Svelte seats name\n  `*` (`svelte` MCP) the same way",
  "The Svelte seats name `list-sections`, `get-documentation`, and `svelte-autofixer` (`svelte` MCP) the same way",
  "review PR21: Svelte seats name real MCP tools, not a wildcard",
))
EDITS.push(E(
  "skills/kru-roster/hire.md",
  "Report the new seat + its boundary. Leave `commit`+`tag` to the user unless they asked (git rule). Then route work to the seat.",
  "Report the new seat + its boundary. Hand off per `skills/kru-lead/SKILL.md` → *Who acts at the door*. Then route work to the seat.",
  "review PR21: hire hand-off matches kru-lead Who acts at the door",
))
EDITS.push(E(
  "skills/kru-roster/author.md",
  "Leave commit/tag to the user (git rule).",
  "Hand off per `skills/kru-lead/SKILL.md` → *Who acts at the door*.",
  "review PR21: author hand-off matches kru-lead Who acts at the door",
))
EDITS.push(E(
  "skills/kru-roster/retire.md",
  "Leave commit/tag to the user (git rule).",
  "Hand off per `skills/kru-lead/SKILL.md` → *Who acts at the door*.",
  "review PR21: retire hand-off matches kru-lead Who acts at the door",
))

// --- review PR21: canonical door spec (skills/kru-lead/SKILL.md → Who acts at the door) ---
EDITS.push(E(
  "skills/kru-lead/SKILL.md",
  "**Who acts at the door.** You commit locally and return proof; the push is not yours. The PM bot\nreviews the proof, pushes the branch and opens the pull request. Merging, tagging, releasing,\ndeploying, publishing and any message outside the team wait for the owner — except this plugin's own releases,\nwhich the plugin maintainer merges and tags. A bug or want on the work tracker (GitHub issues, or Linear when the repo has opted in) is internal\ntracking, not a message outside the team (first section). Pull requests stay on GitHub either way: the body\ncarries the line `bash \"${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh\" link --id <id>` prints. Most product repos are public, so the PM bot reads the\nrepo's visibility (`gh repo view --json visibility`) before a push. A security fix stays local\nuntil the owner OKs it, then ships through a GitHub security advisory's temporary private fork,\npublished on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays\nin `issues/`, off the PR and off Linear. A cloud session pushes branches but gets a 403 on a tag push, so a release\nruns as a `workflow_dispatch` started through the GitHub API, the workflow creating the tag on its\njob token — started by whoever owns that release: the owner, or the plugin maintainer for this plugin.",
  '**Who acts at the door.** **Ordinary work** — review fixes, hire, author, retire, requester ships, ports: the lead `commit`s on the branch and returns proof; the lead never pushes and never waits for a PM ask (headless runs do not wait). The PM bot reviews the proof, pushes the branch and opens the pull request. On a cloud agent, outbound team connector MCP (send/post/share/delete and the rest) is forbidden by the always-on rule in `rules/kru-lead.mdc` — hand the exact tool and arguments back to the PM bot; the repo hook enforces the same denylist only when Cursor runs hooks on MCP calls (not on cloud agents today; see `PORTING.md`). **`/kru-roster learn` only:** the sweep leaves the diff uncommitted; the plugin maintainer reviews it; then the lead `commit`s when the PM asks; then the PM bot pushes and opens the pull request — "when the PM asks" appears only in learn contexts. **Merge:** in this plugin repo, the plugin maintainer merges after CI (`verify`) passes; in product repos, the owner merges. **Tag:** only when the PM asked for a release, per `skills/kru-roster/release.md`. The maintainer creates and pushes the tag from a checkout that has push rights (`git tag` + `git push origin <tag>`, or `gh release create`). A cloud session that cannot push a tag (403) stops and hands the tag step back to the PM bot with the exact commands. Deploying, publishing and any message outside the team wait for the owner. A bug or want on the work tracker (GitHub issues, or Linear when the repo has opted in) is internal tracking, not a message outside the team (first section). Pull requests stay on GitHub either way: the body carries the line `bash "${CURSOR_PLUGIN_ROOT}/scripts/kru-tracker.sh" link --id <id>` prints. Most product repos are public, so the PM bot reads the repo\'s visibility (`gh repo view --json visibility`) before a push. A security fix stays local until the owner OKs it, then ships through a GitHub security advisory\'s temporary private fork, published on merge. Its PR body summarizes the fix without exploit detail; the defect write-up stays in `issues/`, off the PR and off Linear.',
  "review PR21: canonical Who acts at the door (migration)",
))
