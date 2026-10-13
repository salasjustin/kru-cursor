---
name: kru-postgres
description: Postgres engine recipes — migrations that keep a live table open (lock queue, NOT VALID then VALIDATE, CONCURRENTLY), enum values, default column types. Use when writing or reviewing a Postgres schema, migration, or query. Postgres-the-server only; the ORM layer is `drizzle`'s.
---

Reproduced on **PostgreSQL 18.3** (2026-09-13) unless a line says otherwise. A recipe gated on a major names it — check `select version()` on the target before reaching for one.

Load **`sql`** first: modeling, NULL semantics, pagination and the expand/contract order for a live schema change are engine-agnostic and live there. This file is what Postgres changes about them.

## A waiting migration blocks every read behind it
Most `ALTER TABLE` forms take `ACCESS EXCLUSIVE`. Behind one long-running read, the `ALTER` waits in the lock queue — and every plain `SELECT` that arrives after it queues behind the `ALTER`, so a table that was serving fine goes dark until that first read ends. Reproduced: the `SELECT` stayed blocked until its own `statement_timeout`.

So a migration touching a live table opens with `SET lock_timeout = '2s'` (seconds, never unset) and **retries** on `canceling statement due to lock timeout`, rather than waiting its way into an outage.

## Keeping DDL cheap on a table with rows
Each change below has a one-statement form that locks or rewrites the table, and an ordering that doesn't.

**A column with a default.** A non-volatile default (a constant, `now()`) is catalog-only. A **volatile** one — `clock_timestamp()`, `gen_random_uuid()` — rewrites the table and every index under `ACCESS EXCLUSIVE`. Add the column bare, `ALTER COLUMN … SET DEFAULT` (new rows only, no rewrite), backfill in batches, then tighten.

**A foreign key.** `ADD CONSTRAINT … FOREIGN KEY … NOT VALID` skips the scan but still takes `SHARE ROW EXCLUSIVE` on **both** tables — brief, but it blocks writes to the parent too. Then `VALIDATE CONSTRAINT` scans under `SHARE UPDATE EXCLUSIVE` on the child and `ROW SHARE` on the parent, with reads and writes flowing. Two statements, ideally two transactions.

**`NOT NULL`** (12+). `SET NOT NULL` alone scans the table under `ACCESS EXCLUSIVE`. A validated `CHECK (col IS NOT NULL)` lets Postgres skip that scan:
```sql
alter table t add constraint t_col_nn check (col is not null) not valid;
alter table t validate constraint t_col_nn;      -- scans, writes keep flowing
alter table t alter column col set not null;     -- proves from the check, no scan
alter table t drop constraint t_col_nn;
```

**An index.** `CREATE INDEX CONCURRENTLY` cannot run inside a transaction block, and most migrators wrap each file in one — it becomes a step outside the migrator (the `drizzle` skill's `reference/postgres.md` for Drizzle's). A failed concurrent build **leaves the index behind, marked invalid**: the retry fails on `already exists`, and the invalid index still costs every write. Find them with `select indexrelid::regclass from pg_index where not indisvalid`; drop it (or `REINDEX INDEX CONCURRENTLY`) before retrying.

## Enums only grow
`ALTER TYPE … ADD VALUE` runs inside a transaction, but the new value is unusable until that transaction commits — a migration that adds the value and backfills rows with it in one transaction fails with `unsafe use of new value`. Values cannot be dropped or reordered short of recreating the type. A set that may shrink, or that will grow attributes, is a lookup table.

## Types to default to
From the Postgres wiki's *Don't Do This*, each with its failure:
- **identity**, not `serial` — "for new applications, identity columns should be used instead."
- **`timestamptz`**, not `timestamp`. `timestamptz` stores a UTC instant and discards the zone it was written in; when the zone is data (a meeting's local time), it is its own column.
- **`text`** (or unbounded `varchar`), not `varchar(n)` by default — a length that is a business rule is a `CHECK`.
- **`numeric`** for money, not `money`.

## One null per key
A `UNIQUE` column admits any number of NULLs (`sql`). When the rule is at most one — one unassigned slot per group — it is `UNIQUE NULLS NOT DISTINCT` (15+), not a partial index or app code.

## Consult current docs (official sources first)
postgresql.org/docs/current is the authority for engine semantics; the `ALTER TABLE` page names the lock level of each subform — read it for any form not listed above. Driver and ORM APIs via Context7; Drizzle via the `drizzle` skill first.

## Not this skill's job
- **The ORM layer** — `drizzle` (transaction-mode poolers and prepared statements, the migrator's single transaction).
- **Embedded SQLite and D1** — `sqlite`.
