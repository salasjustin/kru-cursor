# Embedded — the connection, and one writer

Read `SKILL.md` first. This file is the half that holds only when the app opens the `.db` file itself: settings live per connection, and the writer is yours to serialize.

## The connection recipe
Run on every connection, at open, before anything else.

```js
// journal_mode persists in the db file header; the other three are per-connection and reset on every open
db.pragma('journal_mode = WAL');
db.pragma('busy_timeout = 5000');
db.pragma('foreign_keys = ON');
db.pragma('synchronous = NORMAL');
```

| Pragma | Default | Why |
|---|---|---|
| `journal_mode = WAL` | `delete` | concurrent readers alongside one writer, instead of readers and writers blocking each other. Set once — it's stored in the file |
| `busy_timeout = 5000` | `0` — a blocked write throws instantly | makes a contended write wait and retry rather than surface `SQLITE_BUSY` to the caller. 5–10s is the usual band |
| `foreign_keys = ON` | `OFF` | SQLite ships FK enforcement off for backwards compatibility. Per-connection — one connection that misses this silently skips **every** FK |
| `synchronous = NORMAL` | `FULL` | skips an fsync per commit. In WAL this cannot corrupt the database; the only exposure is losing the last committed transactions on **power loss** (not on an app crash) |

Then `PRAGMA optimize`, per sqlite.org's stated recipe: short-lived connection → run it just before closing; long-lived → `PRAGMA optimize = 0x10002` at open plus a plain `PRAGMA optimize` hourly or daily; **always** after a schema change or `CREATE INDEX`. Don't hand-set `analysis_limit` first — `optimize` now applies its own temporary limit.

## Cargo-cult pragmas — leave them out
Widely copied off blog posts, wrong or situational as a default:

| Seen everywhere | Why not |
|---|---|
| `mmap_size = 30000000000` | trades away SQLite's ability to detect I/O errors (a bad read becomes a segfault, not an error), caps out on 32-bit, and mostly duplicates the OS page cache. Situational tuning, never a baseline |
| `page_size = 32768` | only pays off for large-blob workloads, and it **can't be changed** once the db is in WAL mode without reverting to `delete` and vacuuming. Decide at creation or not at all |
| `synchronous = OFF` | the one setting here that can actually corrupt the database. `NORMAL` is the floor |
| `cache_size = -32000` | usually redundant with the OS page cache. Set it from a measurement, not on principle |
| `PRAGMA vacuum` | not a pragma. `VACUUM` is a statement — and see `ops.md` before running it on anything large |

## Concurrency — one writer, and the real fix for SQLITE_BUSY
- WAL buys **concurrent readers + exactly one writer**. It does not buy concurrent writers, and no pool size changes that. Shape the app as one writer connection and N readers.
- `busy_timeout` retries a blocked write — **except in the case that actually bites**: a `DEFERRED` transaction that has already read, then tries to upgrade to a write. SQLite returns `SQLITE_BUSY` immediately and does not invoke the busy handler at all, because two connections both waiting to promote would deadlock: *"SQLite returns SQLITE_BUSY for the first process, hoping that this will induce the first process to release its read lock and allow the second process to proceed."*
- So: **every transaction that will write starts `IMMEDIATE`** — `tx.immediate(args)` in better-sqlite3 and bun:sqlite, `BEGIN IMMEDIATE` by hand elsewhere. Deferred is for read-only work. This is the single most common cause of intermittent `SQLITE_BUSY` under load.
- A long-running **read** transaction stops the checkpointer at its end mark, so the `-wal` file grows unbounded until that reader finishes. Never hold a read transaction open across an await point or a whole request lifetime.
- Transaction wrappers are **sync-only** in better-sqlite3 and bun:sqlite — an `async` function inside one commits early. Don't interleave them with hand-written `BEGIN`/`COMMIT` either.
