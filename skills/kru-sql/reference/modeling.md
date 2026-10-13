# Modeling — tables, keys, relationships

Read `SKILL.md` first. These are the tests that find where a design isn't normalized.

## Fill rows before writing DDL
Put 3–5 realistic rows under the proposed columns before any `CREATE TABLE`. The rows show what column names hide (MM ch7):
- **a comma inside a value** → a multivalued field, which is a child table.
- **a value with parsable parts** → a multipart field. A code whose segments mean something (`GUIT2201` = category + serial) is the quiet version: split it before anything filters on a segment, or renaming a category becomes parse-and-rewrite. A function index written to reach a segment is the same smell (RD ch2, AoSQL ch3). Case folding is the one legitimate expression index (`sqlite` → case-insensitive uniqueness).
- **a row copied once per item** → a repeating group.

## Flattened lists and subtypes
- **Numbered or role-prefixed columns** (`phone_1..3`, `billing_*`/`shipping_*`) are a list flattened into columns: a hard cap, an `OR` across N columns in every query. Move them to a child table, and take along any column paired 1:1 with each item — a date, a level — or the pairing is lost (MM ch7, AoSQL ch1).
- **Columns null for whole categories of rows**, or two columns never set together, are subtypes. Split them into subtype tables whose primary key is also the foreign key to the parent's. Near-identical sibling tables (`full_time_staff` / `part_time_staff`) are the reverse miss: the shared columns belong in one parent, or one person lives in two tables (MM ch7–8, AoSQL ch1).
- **An "if NULL, use that other column" convention** is a rule every program re-implements its own way — one bills headquarters, another bills the shipping address. State it as structure the database can hold: role-tagged address rows, a shipments table (AoSQL ch1).

## Facts, not flags
- **A boolean status loses its fact.** `is_completed` can't answer *when* or *by whom*, and the migration to add them comes anyway. Store `completed_at` (plus `completed_by`), or a status-history table (AoSQL ch1).
- **One typed table per kind of value.** A generic `(entity, attribute, value text)` table can hold no foreign key, no type and no `CHECK`: a letter O typed for a zero fails when read, not when written, and every read self-joins N times (AoSQL ch1, ch4).
- **Only foreign-key columns repeat across tables.** A parent column copied into a child "so the report has it" drifts the first time a writer forgets it; the report joins or reads a view (MM ch7).
- **Derived columns stay out of base tables.** When a measured query forces one after query and index fixes, the migration records which rule it breaks, which columns it touches and how to reverse it — otherwise a stale total outlives anyone who knows why it exists (MM ch7, ch15).
- **History keys on `(item_id, effective_from)`; the current row is the latest at or before now.** A far-future end date (`9999-12-31`) marking the current row makes every insert also an update and future-dated rows break "latest = current" (AoSQL ch1, ch6).

## Keys
- **Candidate-key test.** A column (or set) fails if any part can be null or optional, can change, exposes private data, or is multipart. Name + surname fails; so does a national ID number, which some rows won't have. Nothing passes → surrogate key, with a `UNIQUE` on whatever natural candidate does exist (MM ch8).
- **Dependency test.** Take one sample row and ask of each column: does the key alone determine this value? A column determined by another non-key column — an employee's phone on an invoice, via the employee — moves out, or a phone change rewrites every invoice (MM ch8).
- **Entities get a surrogate; junction and owned-detail tables that nothing references get a composite primary key, parent foreign key first.** That key doubles as the index the foreign key needs, and the leading column decides which lookup it serves — `(order_id, article_id)` serves "lines of this order" (AoSQL ch3, ch4, ch6).
- **Ids come from the engine** — identity, sequence, `INTEGER PRIMARY KEY` — returned by the same statement (`RETURNING`). `max(id)+1` duplicates under concurrency; a next-value table serializes every insert (AoSQL ch3, ch9).
- **A foreign key column keeps the referenced key's name and type** (`customer_id` → `customer_id`); only a self-reference takes a role name (`manager_id`). A mismatched type forces a cast into every join (MM ch10).

## Relationships
- **Neither engine indexes the referencing column of a foreign key.** Index it when parent rows are deleted, or their key updated, while other writes run — otherwise each parent delete scans the child. Skip it for a static lookup parent, or where the foreign key already leads a composite index; "index every FK" leaves redundant indexes (AoSQL ch3).
- **The delete rule is a per-relationship answer to "when the parent goes, what happens to the children?"** Default `RESTRICT`. `CASCADE` only rows the parent owns — never a self-reference like manager → reports. `SET NULL` needs a nullable foreign key. "Deactivate, never delete" is a soft-delete column, not an `ON DELETE` option (MM ch10).
- **A cap on children** ("at most 2 loans per member") can't be declared. It is enforced inside the write — a guarded insert whose `WHERE` counts (`queries.md` → *The guarded write*) or a trigger — and named in the return, because nothing in the schema shows it (MM ch10–11).
- **A value list starts as a `CHECK (col IN (…))` and becomes a lookup table + foreign key** once values grow, need a label, or must not be deleted while referenced. Before extracting, confirm each code maps to exactly one label in the existing data, or the extraction fails on a duplicate key (MM ch11, RD ch6–7).
- **A rule every writer must obey is a constraint.** In application code it holds only for the app that wrote it; the second app, the script, the console session skip it (AoSQL ch1, RD ch8).
