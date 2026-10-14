# cursor — what shipped to Cursor

Cursor ships on its own calendar, and a release can change the ground under a plugin. The docs are the authority: a changelog entry can be gated to a plan or a client this install doesn't have, so a candidate is confirmed against the page it claims and, where the install has the command, that command's `--help`, before it earns a verdict. This file keeps the name `claude.md` so `/kru-update`'s argument stays `claude`.

## Do

1. **Find the mark.** `reviewed.md` → *Cursor* → *Swept through*. `$ARGUMENTS` names a day (`2026-04-15`) → sweep back through that changelog day instead. The *Claude Code* section under it is a closed ledger. Do not extend it.
2. **Get the notes.**

   ```bash
   curl -sL https://cursor.com/changelog -o <scratchpad>/changelog.html
   ```

   Also read [the changelog](https://cursor.com/changelog) and, for the agent surface, [the docs release notes](https://cursor.com/docs/release-notes) when the changelog entry points at a doc. Save the page. Don't stream it into context.
3. **Cut to the unswept range** — everything newer than the mark. Nothing newer → report *swept through <day>, nothing new* and stop.
4. **Keep only what touches the team.** An entry earns a read when it names one of these surfaces:

   | Surface | Where it lands here |
   |---|---|
   | agent frontmatter (`model` · `readonly` · `permissionMode`) | `agents/*.md`, `scripts/port.mjs` → `SEAT_MODELS` (a sweep never changes a pin; `MODELS.md` does) |
   | skill / command frontmatter (`disable-model-invocation` · `description`) | `skills/kru-*/SKILL.md`, `commands/` |
   | plugin manifest, install, loading, `${CURSOR_PLUGIN_ROOT}` | `.cursor-plugin/plugin.json`, README → *Install* — [plugins](https://cursor.com/docs/plugins) |
   | subagent dispatch — context isolation, parallel work, resume | `lead` SKILL.md → Steps 3–4 — [subagents](https://cursor.com/docs/subagents) |
   | the built-ins the team delegates to — `Explore`, Plan mode, `/review`, `/canvas`, the Browser subagent | `lead` SKILL.md, `ROSTER.md`, `skills/kru-design/SKILL.md` — [skills](https://cursor.com/docs/skills), [canvas](https://cursor.com/docs/agent/tools/canvas), [browser](https://cursor.com/docs/agent/tools/browser) |
   | hook events and their payloads | `hooks/hooks.json`, `hooks/cursor-hook.sh` — [hooks](https://cursor.com/docs/hooks) |
   | MCP config | README → *Requirements*, `SOURCES.md` — [MCP](https://cursor.com/docs/mcp) |
   | model ids the seats may name | `MODELS.md` — record a new id there before any seat uses it |

   Read the kept entries. The rest of the range is done.
5. **Confirm each candidate is reachable**, before it earns a verdict. Read the doc the entry cites ([skills](https://cursor.com/docs/skills), [subagents](https://cursor.com/docs/subagents), [plugins](https://cursor.com/docs/plugins), [canvas](https://cursor.com/docs/agent/tools/canvas)). Where this install has a CLI command, its `--help` is the check. There is no `claude` binary and no zod grep of one.
6. **Give every kept entry one verdict** (`SKILL.md` → *The verdicts*). The action verdict here is **Adopt** — the change is small, reversible, and the team's existing doctrine already argues for it. Say which line moves. A model pin does not move in this sweep.
7. **Check the floor.** An adopted feature that needs a newer CLI moves README → *Requirements* → the **≥ version** line. Name the version and the feature that forced it.
8. **Record and report.** Rewrite `reviewed.md` → *Cursor*: the mark to the newest day read, and one line per verdict under its bucket. Leave *Claude Code* as it stands. Then wire every **Adopt** through `/kru-roster` in the same turn, one at a time, without asking. The maintainer hears only the **Consider** items, each in outcome terms, plus one counted clause for the rest.
