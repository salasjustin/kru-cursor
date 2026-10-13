---
name: kru-sql
description: "Engine-agnostic SQL under `postgres`/`sqlite` — NULL traps, then modeling (keys, subtypes, delete rules), queries (filters, indexes, pagination, guarded writes), live schema change (expand/contract, backfills). Use when designing a schema, writing a query, or changing a live schema."
---

The layer under the engine skills: what holds on Postgres and SQLite alike. Load it first, then the engine's — **`postgres`** or **`sqlite`** — which carries what that engine changes.

Claims marked *reproduced* ran on PostgreSQL 18.3 and SQLite 3.43.2 (2026-09-13). Book cites: **MM** *Database Design for Mere Mortals* (Hernandez) · **AoSQL** *The Art of SQL* (Faroult & Robson) · **RD** *Refactoring Databases* (Ambler & Sadalage).

## NULL answers wrong, not loudly
Every branch runs into these. Each is *reproduced* on both engines.
- **`x NOT IN (subquery)` returns zero rows once the subquery yields a single NULL.** Write `NOT EXISTS`. (AoSQL ch1, ch6)
- **`col <> 'x'` drops the rows where `col` is NULL** — they are neither equal nor unequal. A filter meant to keep them says `col IS DISTINCT FROM 'x'` (Postgres) or `col IS NOT 'x'` (SQLite).
- **`count(col)` skips NULLs; `count(*)` doesn't.** A pre-check for NULLs counts `count(*) … where col is null`; `count(col)` there is always 0.
- **A `UNIQUE` column admits any number of NULLs.** "Unique when present" is the default; "at most one missing" needs the engine's own form (`postgres` → *One null per key*).

## Branches
Pull the file for the task, not all three.
- **Designing tables, keys, relationships** → `reference/modeling.md`.
- **Writing or reviewing a query** → `reference/queries.md`.
- **Changing a schema that has data** → `reference/schema-change.md`.

## Not this skill's job
- **What an engine changes** — lock levels, `CREATE INDEX CONCURRENTLY`, enums, types: `postgres`. STRICT, the 12-step rebuild, pragmas, D1: `sqlite`.
- **The ORM layer** — `drizzle`.
- **The domain's vocabulary and decision records** — `domain-modeling`. This skill turns a settled domain into tables; that one settles the domain.
