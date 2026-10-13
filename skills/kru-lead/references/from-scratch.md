# Scoping a project from scratch

Loaded by `lead` when the branch is live.

1. The subject, audience, the one job and the stack are the sheet's — `/kru-setup` grilled them on the blank repo (its step 1b). Read them there. A UI that needs a design system built for it defaults to React when the user states no preference, because the sync lane is React-only; a stated stack wins, and gets the canvas, the token file and its gate (*UI from scratch*, below).
2. Consider grilling (Step 2.5) before architecting.
3. Then spawn **Plan mode** (built-in) for the architecture, scaffold, and route implementation (Step 3).

### UI from scratch — the design is made in Claude Design, the system is owned by the repo
A UI with no system yet is **not built and then designed**. `ux-designer`'s flow + the **conventions corpus** — plus `conversion-copywriter`'s deck where the first surface is a marketing page, so the canvas is drawn around real strings at real length rather than around placeholder text that sizes to a different page → **the look is settled on a canvas in front of the user** (the design gate, and the build's only human-in-the-loop stop): run **`/design`** in this session, briefed with the screen inventory and the corpus, or hand the two over for the user's own claude.ai/design session where they'd rather → the builder's **Phase 0** builds the real token file *and the conformance gate that closes it* → the first components, and the conventions file turns over to its shipped-system header. From there screens are designed out of the real parts. **Claude Design decides the look; every other seat works on the material and the gates.**

**The design is authoritative.** What comes back ships as authored — contrast included. The team's job is to transcribe it once, into the token file, and hold every build inside it. Holding it there includes using a pair the way the system authored it: a fill token spent as a text colour is a conformance finding, not a design decision anyone took (`${CURSOR_PLUGIN_ROOT}/references/ui-practice.md` → *Contrast*).

**Bootstrap, steady state, system change, ownership, and what a build is held to: `${CURSOR_PLUGIN_ROOT}/references/ui-practice.md`.** Read it when any UI build starts — and before running `/design`, whose limits are *The canvas* there — from scratch at *Bootstrap*, an existing system at *Steady state*, a change that moves the token file at *System change*. It also carries the from-scratch team defaults (`pnpm`, React when no stack is stated). A repo with a `.design-sync/` runs the **sync lane** on top of that loop — its entry bar, its two extra steps and the bundle's maintenance are `${CURSOR_PLUGIN_ROOT}/references/design-sync.md`.

### UI on an existing system — there is no design hop
An existing repo already has a system, so the build follows it and the design work already happened. Two shapes:
- **A change inside the existing language** (a new feature, a new screen, a restyle of one): route **`ux-designer` for the flow pass** — flows, IA, the screens and their states, the copy — and hand that straight to the builder, which reads the repo's `## Design system` pointer and builds to the existing tokens. A feature that already has a system to follow doesn't need art direction, and inserting one is how a repo ends up with two design languages.
- **A gap in the system** — the builder returns a **named gap**: the token file genuinely has no value for what the slice needs. **No seat fills it.** Carry it to the user as the choice they'd see ("what colour for warnings?"); the token name it would need stays in the builder's brief. A value the system should have is a **product call**, and product calls are made in Claude Design or by the user, never by a builder and never by you.

**The repo is upstream of every design project, in every direction** — a landed system change is followed by a re-run of the canvas from the tree, or by a rebuild and resync where the repo runs the sync lane. The loop, and what a build on an existing system is held to: **`${CURSOR_PLUGIN_ROOT}/references/ui-practice.md` → *Steady state*.**

