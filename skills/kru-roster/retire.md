# retire — remove a seat

The inverse of `hire`: strip the seat from **every** point of the wiring map in `SKILL.md`, and leave nothing pointing at it. Steps:

## 1. Check for inbound references first
`grep -rn "<name>"` across `agents/`, `skills/kru-lead/`, and the other agent files. Every hit that isn't the seat's own definition is an **inbound reference** — a sibling that delegates to it, a routing row, a "see `<name>`" boundary clause in another seat's description. A dangling reference is the drift retire exists to prevent. List them; each must be rewritten or removed in step 2.

## 2. Unwire (map #1–#5, reversed)
- Delete `agents/<name>.md`.
- Remove its `ROSTER.md` *Current specialists* row and *Model tiers* entry.
- Remove its `SOURCES.md` row.
- Remove its row from `${CURSOR_PLUGIN_ROOT}/references/routing.md`, or its review wiring (Step 4). A deployed repo still naming it in its sheet sheds the line on its next `/kru-setup`.
- Fix every inbound reference from step 1 — if another seat's boundary clause named this one, rewrite it.

## 3. Version (map #6–#8)
Version bump: **minor** normally; **major** if removing the seat changes the orchestration contract others depend on (a stack now has no route). `VERSION` · `.cursor-plugin/plugin.json` · `.cursor-plugin/marketplace.json` plugin entry · `ROSTER.md` header, all equal.

Completion: **`audit` passes** and `grep -rn "<name>"` returns nothing. Hand off per `skills/kru-lead/SKILL.md` → *Who acts at the door*.
