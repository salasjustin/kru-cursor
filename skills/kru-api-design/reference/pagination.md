# Pagination and incremental sync

## Keyset cursors
Use keyset pagination on `(sort_key, id)` with a strict comparison on the pair. The mechanics — the tie-breaker, the row-value comparison, and why OFFSET pages repeat — are the `sql` skill's (*Queries*). Load it; this file covers only the API side.

- **The cursor is opaque**: base64url of the last row's `(sort_key, id)`. Once integrators can read and build cursors, the sort order is part of the contract.
- **`next_cursor: null` is the end.** Integrators who stop at "the page came back empty" pay an extra request. Integrators who stop at "the page was short" stop early whenever a filter thins a page.
- **A cursor carries its filters, or it's refused when they change.** A cursor from `?status=paid` reused with `?status=refunded` otherwise returns a page that belongs to neither query.
- **Default page size and max page size are both explicit, and an oversize request is capped, not refused.**

## Incremental sync — the question integrators actually ask
Integrators don't want "orders placed in March." They want "everything that changed since my last run."

- **A filter on business time (`since` on `placed_at`) never shows a change to an old record.** A refund issued today on a March order falls outside every `since=today` window, so the integrator's copy says the order is paid forever. Syncing needs a **change cursor**: `updated_since` over an `updated_at` that every write keeps current, indexed with `id`.
- **`updated_at > last_seen` skips rows whose transactions committed late.** A write stamps `updated_at` at T, but its transaction commits after a sync already read past T, so the row appears behind the cursor. Document an overlap: start the next sync a fixed window before the last `updated_at` seen, and dedupe on id. On a single-writer database like SQLite or D1, writes are serialized, so the window can be small, but it isn't zero when the timestamp comes from app code rather than inside the write.
- **Deletes are invisible to `updated_since`.** A deleted row matches no filter. Either soft-delete with `deleted_at` so it appears in the change feed, or expose an events list as the feed.
- **The webhook event log can be the change feed.** A `GET /events?after=<cursor>` over the same rows the outbox writes gives integrators a way to replay what their receiver missed, with no second source of truth.
