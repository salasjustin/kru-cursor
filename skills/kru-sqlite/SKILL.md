---
name: kru-sqlite
description: "SQLite recipes for an embedded `.db` file in node/bun and for Cloudflare D1 — STRICT tables, the 12-step rebuild, pragmas, SQLITE_BUSY, migrations, backups, driver choice; D1 batch(). Use when writing or reviewing SQLite schema, migrations, or queries on either host. Not libSQL/Turso."
---

**SQLite is not a small Postgres.** Three differences burn a Postgres-shaped instinct wherever SQLite runs: one writer at a time regardless of pool size · types are advisory unless the table is `STRICT` · `ALTER TABLE` cannot touch a constraint.

Load **`sql`** first — modeling, NULL semantics, pagination and the expand/contract order are engine-agnostic and live there. Then this file, then **the branch for the host**, before the first line of schema:
- **An embedded `.db` file** the app opens itself → `reference/embedded.md`, then the *Embedded recipes* below as the task needs.
- **Cloudflare D1** → `reference/d1.md` alone: the platform owns what the embedded files set.

## Types — declare STRICT
Without it, a column's declared type is an *affinity*, not a constraint: `age INTEGER` happily stores `'banana'`. The goal is column types the engine enforces: add `STRICT` to every `CREATE TABLE` you write (SQLite 3.37+). Under an ORM whose generator can't emit it — Drizzle — a hand edit to generated SQL is overwritten by the next `generate`; `drizzle` → `reference/sqlite.md` carries the three ways through. Note what STRICT does not give you: still no native boolean (store `0`/`1` with a `CHECK`), no date/time type (store ISO-8601 `TEXT` or an integer epoch, and be consistent — comparisons are lexical), and `INTEGER PRIMARY KEY` remains the one true rowid alias.

## Schema changes — `ALTER` can't, so rebuild
`ALTER TABLE` does four things only: add a column, rename a column, rename a table, drop a column. Every other change — a type, a `CHECK`, a `NOT NULL`, a foreign key, column order — is the official 12-step table rebuild, reproduced verbatim in `reference/migrations.md`. Two steps that get skipped and cost data: `PRAGMA foreign_keys=OFF` goes **outside** the transaction (it is a no-op inside one), and `PRAGMA foreign_key_check` runs **before** the commit, not after. D1 can't run step 1 at all — `reference/d1.md` carries its version.

## Case-insensitive uniqueness lives on the index
A user-visible name that must be unique regardless of case keeps its typed capitals in the row; the index carries the collation — `create unique index t_name on t(name collate nocase)`. Lower-casing the column rewrites what the user typed, and a second lower-cased column stores twice for a rule the index states in two words. `nocase` folds ASCII only; a Unicode fold is an application-side normalised column.

## Consult current docs (official sources first)
sqlite.org is the authority for engine semantics — pragma behavior, WAL, transaction locking, `ALTER TABLE`, `VACUUM INTO` — and it is precise where community posts are approximate. Fetch it rather than answering from memory. On D1, Cloudflare's D1 docs outrank sqlite.org for anything the platform intercepts: pragmas, transactions, foreign-key enforcement. For the driver or ORM API (`better-sqlite3`, `node:sqlite`, `bun:sqlite`, Drizzle, Kysely), resolve via Context7; for Drizzle prefer its official `llms.txt` index (`https://orm.drizzle.team/llms.txt`) for schema/migration docs and Context7 for exact call signatures.

## Embedded recipes
Pull the file that matches the task.
- `reference/drivers.md` — choosing between better-sqlite3 / `node:sqlite` / bun:sqlite, their transaction APIs, and the gotchas each one has (integer truncation, FK defaults, macOS sidecar files).
- `reference/migrations.md` — the 12-step rebuild verbatim, the `user_version` stepper, Drizzle Kit for the sqlite dialect, and migrating a database file that's already in users' hands.
- `reference/ops.md` — `VACUUM INTO` vs. the backup API, WAL checkpointing and growth, integrity checks, and shipping a seed database inside a package.

## Not this skill's job
- **The Worker around D1** — the binding, `wrangler` config, local state and deploy are `cloudflare-builder`'s, from the vendored `cloudflare` and `wrangler` skills.
- **libSQL / Turso** — a remote or replica server changes the concurrency and pragma story enough that these recipes mislead.
- **Postgres** — the `postgres` skill.
- **Typing the query surface** (generics, inference, `.d.ts`) — the `typescript` skill, in whichever seat owns the code.
