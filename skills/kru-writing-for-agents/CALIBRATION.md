<!-- repo-owned, not vendored: the calibration branch of `writing-for-agents` for a Cursor cloud agent, model-agnostic (best model per task). The levers were first written up in Anthropic's context-engineering note (claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/) and are restated here for this harness. Survives a re-sync of SKILL.md unchanged; SKILL.md's pointer to it is deviation (4) in that file's vendoring note. -->

# Calibrating for Cursor cloud agents

The calibration branch of [`writing-for-agents`](SKILL.md): what changes when the reader is a Cursor cloud agent. The model is whichever is best for the task; these levers do not change with that pick. The evidence they rest on is a published cut of a coding harness's system prompt — over 80%, no measurable eval loss — most of which was guardrails written for an older model's worst case. Everything else about writing is the universal reference in `SKILL.md`; this file says where its levers now point.

## Judgment over rules

A rule written against the worst case binds the good case too. _Default to writing no comments_ stopped the noise an older model produced, and also stopped the comment a genuinely tricky block needed. The replacement states the target the rule was serving and lets the model judge each case against it: _write code that reads like the surrounding code — match its comment density, naming, and idiom._

So the first draft of any rule is its **goal**, and the rule survives only where a wrong judgment can't be walked back — security, money, data loss, a public push, the `⚠` invariants drift has actually dropped. Everywhere else, the goal plus the reason is the instruction. This is **overconstraint**, and it is the failure mode the no-op test under *Pruning* misses: a no-op changes nothing, an overconstraint changes behaviour for the worse in exactly the cases the author didn't picture.

## One voice per topic, across layers

A seat runs under a stack — the harness system prompt, User Rules, Team Rules, root `AGENTS.md`, and a `.cursor/rules` file with `alwaysApply: true`, this plugin's seat prompt and shared blocks, the skills it loads, the brief. Each layer can be right alone and contradict the next: _leave documentation as appropriate_ in one, _do not add comments_ in another. The model spends its judgment reconciling the authors instead of the task.

Before a rule lands, read what the layers above already say on its topic. Agreement makes the new line a duplicate (*Pruning*); disagreement is a conflict to resolve at its source, never one to win by louder wording or a `⚠`.

## Interfaces over examples

Examples narrow — the model copies their shape and stops exploring past it. A well-typed interface teaches the usage instead: a Cursor cloud agent's todo list is a short description and a `pending | in_progress | completed | cancelled` status. `merge: true` patches todos by id; `merge: false` replaces the list.

Here the interface is a return contract, a frontmatter field, a ticket schema, a hook's checked line. Where a document reaches for a worked example to show a format, give the format a closed set of values and one stated constraint first; keep the example only if the shape still misreads without it.

## Rich references over prose specs

A spec in prose is a lossy description of something that usually exists in a richer form. Point at the richer form: the test suite that pins the behaviour, the function in another codebase to match, an artifact mockup, a **rubric** a verifier agent can grade against. Code is the highest-fidelity spec a model reads — it is written in a language the model knows better than any description of it.
