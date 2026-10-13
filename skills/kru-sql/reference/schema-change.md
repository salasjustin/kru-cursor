# Schema change on a database that has data

Read `SKILL.md` first. What an engine locks or rewrites along the way is its skill's — `postgres` → *Keeping DDL cheap*, `sqlite` → the rebuild and `d1.md`. This file is the order of operations and the data, which hold on both.

## Expand → sync → move → contract
A rename, move or split reaches a database that some running code still reads the old way. The order that never breaks it (RD ch2–4, ch6):
1. **Expand** — add the new column or table alongside the old.
2. **Sync** — keep both shapes current for every writer (below).
3. **Backfill** — copy existing rows into the new shape.
4. **Move readers**, then **move writers**, to the new shape.
5. **Contract** — drop the sync and the old shape, on one date stamped on both.

Sync precedes backfill: a write landing between a backfill and the sync installed after it is lost.

The migration that expands ships **before** the code that needs it — code first errors on a missing column; the contract ships **after** the last reader is gone. Back out by a forward fix: restoring a backup discards every write since it (RD ch4).

When exactly one deployable reads the database and it migrates on deploy, the whole sequence can land in one release. Anything else — a second app, a worker on its own deploy, a desktop build in users' hands — gets the transition window.

## Keeping two shapes in sync
- **Who writes decides the mechanism.** A database trigger when you can't guarantee every writer dual-writes; app dual-write only when one codebase owns every write. A periodic batch sync can't tell which of two concurrent edits wins (RD ch5).
- **A sync trigger compares NULL-safely.** `not (new.a = old.a)` is NULL when either side is NULL, so a NULL → value edit never propagates and the columns quietly diverge. Use `is distinct from` (Postgres) or `is not` (SQLite), and decide which side wins on an insert that supplies both (RD ch6).
- **Moving a column across a 1:N changes what it means.** `customer.balance` copied into every `account` row sums to the balance times the account count. Decide how the value distributes before copying, and make the aggregate the migration's test (RD ch6).

## Tightening: pre-check, then constrain
- **Every new constraint is preceded by a query that can find its violators**: `count(*) … where col is null` for `NOT NULL`, `group by … having count(*) > 1` for `UNIQUE`, an anti-join for foreign-key orphans. Otherwise the `ALTER` fails mid-deploy.
- **Violators get real values or a decision.** A placeholder value or dummy parent backfilled to push a `NOT NULL` or foreign key through passes the constraint and poisons every filter and aggregate after. No real value exists → the column stays nullable, or the product call goes up (RD ch7–8).

## Defaults and backfills
- **A column readers will filter on arrives with its value.** Adding the column in one step and its default in another leaves existing rows NULL — a default applies to future inserts, never to existing NULLs — and `where is_deleted = false` hides every row that predates it. Add it with the default in the same statement where the engine makes that cheap, or backfill before any reader filters on it (RD ch7–8).
- **A large backfill chooses, and says which:** one statement (consistent, holds its locks for the duration) or batches (stays available, readers see a mix of old and new). Collect the target keys once and reuse them for both copy and delete, rather than re-running the selecting predicate (RD ch7, AoSQL ch10).

## A shared database has other writers
A new constraint or default changes behavior for every program that writes the table: another app may encode a different rule, may treat NULL as meaningful, may `insert` without a column list or `select *` positionally and break when a column appears. Inventory the writers and ship their handling before the constraint lands (RD ch2, ch7–8).
