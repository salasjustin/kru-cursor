# The sync lane — designing out of the repo's real components

**Cursor has no claude.ai/design project, so do not run this lane.** The in-session surface is `/canvas` ([canvas](https://cursor.com/docs/agent/tools/canvas)) through `/kru-design`, with `.dc.html` artboards when `/canvas` isn't available. The procedure below stays so a repo that already has a `.design-sync/` can still be read. Standing a new one up is a gap (`PORTING.md`).

Behind `ui-practice.md` → *The sync lane*. Do not stand one up. Design in this session with `/canvas` ([canvas](https://cursor.com/docs/agent/tools/canvas)) through `/kru-design`. Read the procedure below only to understand a `.design-sync/` that is already in the tree.

`/design-sync` publishes a bundle of the repo's **real** components to a claude.ai/design project, where screens get designed out of the actual parts. It is the only surface that does, and everything it buys is paid for in maintenance.

## The entry bar

Do not stand up a bundle. Upstream's entry bar was a recurring turn where **someone who doesn't write code designs against the system** — a marketing team shipping pages, a designer working screens between engineering slices. That turn has no Cursor host. Point it at `/canvas` ([canvas](https://cursor.com/docs/agent/tools/canvas)) through `/kru-design`, with `.dc.html` artboards when `/canvas` isn't available.

Two conditions gate it:

- **React.** The converter takes React components (a Storybook or a bare package). Another stack gets the canvas, the token file and its gate, and settles a look there.
- **A maintained build.** A bundle is a workspace package with a preview harness, an export surface, a stylesheet build and a notes file — its own piece of work, on its own maintenance schedule (*The bundle*, below).

Where every design turn is an engineer's own, `/kru-design` with `/canvas` is the whole practice: it reads the tree fresh each time, so there is nothing to push and nothing to go stale.

## The loop

Two steps wrap `ui-practice.md` → *Steady state*, around its design → pull → land:

- **Push, first.** The bundle is built from the tree and synced. Its stylesheet is the repo's own compiled CSS and its component list is the repo's own components; the only prose a person authors is the conventions file, in its **header** era.
- **Rebuild and resync, last.** The design project then holds what the repo holds. **Rebuild means the app's stylesheet, not just the bundle** (*The bundle*, below).

The repo is upstream in both senses: a component deleted from the tree comes off the remote on the next resync, so a sync that produces deletes is the practice working.

## The bundle — what the design agent actually gets

Four facts decide whether a design comes back composable, and none of them is visible from inside a design session.

- **The stylesheet is the app's prebuilt CSS, not the token file.** The bundle ships whatever `cfg.cssEntry` points at — a compiled artifact. Under a JIT engine (Tailwind v4 and kin) that sheet contains **only the utilities the app already writes**: the gaps are not symmetric between axes, arbitrary values exist only where some call site wrote that exact string, and **a missing utility fails silently** — no error, just a rule that doesn't exist and a layout that ignores the design. That constraint is the single most decision-relevant fact for a design session, and the header is the only place it can be stated.
- **That artifact is content-hashed and goes stale.** A new app build changes the filename; a `cfg.cssEntry` still pointing at the old one is skipped, and every preview renders unstyled. Refreshing it is a repo-specific procedure — invoke the framework's builder directly rather than the `build` script, whose lifecycle hooks may do things a sync has no business triggering.
- **Prop contracts are generated, and degrade to nothing by default.** The converter's extractor reads `.d.ts`. A repo whose components live in an app rather than a built package ships none, so every published contract collapses to `[key: string]: unknown` unless something regenerates it from source types. A component published with no props is a component the design agent guesses at.
- **The export surface is hand-maintained and easy to break.** A star-export over a source tree collides (two files exporting `Content`) and drags in assets no loader handles, so the entry file is explicit, one named export per published component, pointing at implementation files and never at directory barrels. It and the config's component map are **one artifact in two files** — regenerate them together.

## The notes file

Every sync accumulates repo-specific truth that is nowhere else: converter bugs worked around and why the obvious fix is wrong, warnings triaged as expected, components with no intrinsic size, overlays that need opening synthetically, a fixed clock in the capture harness. It lives beside the config (`.design-sync/NOTES.md`), it is the UI builder's, and it is written **as each thing is discovered**. Skip it and the next sync re-derives all of it from scratch — at full cost, in a fresh context, usually wrong the first time.
