# Queries — the plausible wrong answer, and the index nobody used

Read `SKILL.md` first; its NULL traps apply to every query here. What follows is semantics and shape; both planners rewrite the rest. Verify an index is used with the engine's plan (`EXPLAIN` / `EXPLAIN QUERY PLAN`) rather than asserting it.

## Optional filters
`where col = coalesce(:p, col)` — the catch-all "filter if supplied" — drops every row where `col` is NULL, and can't use an index. Build the `WHERE` from the filters actually supplied, still with bound parameters, and join only the tables those filters need (AoSQL ch8).

## Keep the column bare
A function around an indexed column — `date(ts) = ?`, `substr(code, 1, 4) = ?`, `lower(email) = ?` without a matching expression index — hides the index. Rewrite as a range on the bare column: a half-open day `ts >= :day and ts < :next_day`, a prefix `code >= 'GUIT' and code < 'GUIU'`. An expression index is for the query that can't change (AoSQL ch3, ch8).

## Composite index order
Equality columns first, then the one range column: `(item_id, recorded_at)` serves `item_id = ? and recorded_at between ? and ?`. A range on two different columns (`start >= :a and end <= :b`) uses an index no better than one of its conditions (AoSQL ch6, ch10).

## `DISTINCT` hides the bug
`select distinct` added to remove duplicates is covering a join that multiplies rows — a missing join condition — and it also merges distinct entities that share the selected values (two customers named Wayne). "Has a matching X" is `exists`, returning the key (AoSQL ch4).

## The guarded write
Checking, then acting — `select count(*)`, then `update` — is two round trips and a race: two withdrawals both pass the check. Put the guard in the write and branch on rows affected; diagnose why only when it's 0 (AoSQL ch2, ch6):
```sql
update account set balance = balance - :amt
where id = :id and balance >= :amt;   -- 0 rows → insufficient funds or no account
```
Expected conflicts resolve in the statement too — upsert, `except`, window numbering — rather than per-row exception handling in a loop (AoSQL ch2).

## One query, not N
A lookup function called from a `select` list runs a query per row the planner can't see into; an ORM loop that lazy-loads a relation is the same shape. Join (AoSQL ch2, ch8).

## Lists and transactions
- A variable-length `IN` list binds as one array or list parameter where the driver supports it; concatenated into the SQL, every list length is a new statement and an injection point (AoSQL ch8, ch11).
- A transaction holds only what must be atomic: no per-row round trips inside it, two updates of the same table merged into one `case` update, and error-message lookup after the rollback, not before (AoSQL ch2, ch9).

## Pagination: keyset, not OFFSET
*Reproduced*: after page 1, a row inserted ahead of it shifts the window and `OFFSET` returns a row already shown. Keyset pagination doesn't move:
```sql
select * from post
where (created_at, id) < (:last_created_at, :last_id)
order by created_at desc, id desc
limit 20;
```
The `id` tiebreaker is what makes the order total; without it rows sharing a timestamp repeat or vanish at page boundaries.

## Cascades are off the books
*Reproduced*: a parent `DELETE` reports its own rows only — Postgres `DELETE 1`, SQLite `changes() = 1` — while `ON DELETE CASCADE` removed the children too. A test that asserts on the reported count passes while child rows vanish; assert on the child table.
