# Lossless compaction of a management/plan store

Procedure for shrinking a plan store (or any summary-file + long-form-record pair) that has grown until reading it costs more than the work. Exercised on a production plan store 2026-08-04: 138KB brief → 51KB, 69KB ideas → 25KB, recurring read 52k → 19k tokens, zero loss.

The lead owns this (it edits the plan store — `TRACKER.md`) but never runs it inline: it's blocking, mechanical, and long. Dispatch it with the rules below as the hard brief, then audit the return per §5.

## 1. Measure the recurring read, not the total

Size ≠ cost. Split the store into **recurring** (opened on every run — the brief, the todos parking lot) and **pay-per-use** (opened only when a task needs it — the long-form decisions file, reference docs). A 306KB decisions file read via pointers costs nothing per run; a 138KB brief costs 35k tokens every single time.

Curate the recurring set. Leave the rest alone — and say so, rather than shrinking things that were never costing anything.

```bash
# recurring vs total
find . -type f -not -path './.git/*' -exec wc -c {} + | sort -rn | head -12
wc -c TODOS.md plan/<effort>/brief.md          # the every-run cost
```

## 2. Checkpoint first

Commit the store's own paths before touching anything, so every move is one `git checkout` from reversible. On a cloud vm the store is `<repo>/.kru` and ships in the branch (`store.md`), so the checkpoint stages that root alone — never the working repo's other edits.

```bash
git add -- <store root> && git commit -q -m "checkpoint before archiving pass" -- <store root>
```

## 3. The governing rule — the split is a verification, not a formatting move

**Never delete prose from the summary file until you have found its content in the long-form file.** Where it isn't there, append it to the long-form file *first*, then delete.

Dispatch this to the agent as a hard rule, and require the report to include:

> **A list of everything you removed that you could NOT resolve to a record** — i.e. what you had to append rather than point at.

That list is the audit. On the exercised run it was 50,046 B across steps that existed nowhere else — a naive "move the old sections to archive" pass would have silently dropped all of it. **If that list comes back empty, be suspicious, not pleased.**

## 4. A dead pointer is a finding, not a broken link

When the summary cites a record that doesn't exist: write the record from **what the pointer itself asserts**, carry the assertion verbatim, and say inside the record that it was reconstructed and why. Log anything further as a dated gap. Never backfill from memory — an invented rationale reads identical to a recorded one.

## 5. Audit with cheap greps, not the agent's narrative

Every one of these caught something or confirmed a claim the report made:

```bash
# every italic pointer in the summary resolves to a real heading
grep -o '→ _[^_]*_\(, _[^_]*_\)*' brief.md | grep -o '_[^_]*_' | tr -d '_' \
  | sed 's/^ *//;s/ *$//' | sort -u > /tmp/ptrs.txt
grep '^###\? ' decisions.md | sed 's/^#\+ //' > /tmp/heads.txt
while IFS= read -r p; do grep -qiF "$p" /tmp/heads.txt || echo "MISSING: $p"; done < /tmp/ptrs.txt

# checkbox state must survive exactly — never let a compaction tick anything
awk '/^## Landing plan/,/^## Decisions/' brief.md | grep -o '^\s*- \[[ x]\]' | sort | uniq -c

# entry accounting must balance: N in = stayed + moved
grep -c '^- ' TODOS.md; grep -c '^- ' archive/<dir>/todos-decided.md
```

Report counts back to the user, including where the agent's self-count disagreed (one claimed 21 records where `grep` found 20).

## 6. Name the archive honestly

`archive/<effort>-<date>/` implies the effort **closed**. If it's still live, use `archive/<effort>-records-<date>/` and open the README with the fact that it's a size cut, not a completion — otherwise the next reader takes an in-flight effort for a finished one.

Every archive dir gets a `README.md`: why archived · what would be lost without it · a what-lives-where table · an explicit **"these decisions are reversed / superseded — do not read as current"** section · where the work went next.

## 7. Curating is not triaging

Moving decided/reversed/landed entries out is bookkeeping. Deciding what's *worth building* is the user's call. Two correct refusals from the exercised run:

- an entry reading like a closed verdict stayed live, because another entry explicitly re-opened the question
- entries arguably describing defects were **not** reclassified into `issues/`, because reclassification is triage

Over-long entries carrying a real argument go to `notes/` with a one-line pointer left behind; merely wordy ones get tightened in place (moving those just relocates bytes).

## 8. Expect the total to grow

Nothing is deleted, only relocated, so headers and pointer lines add bytes. On the exercised run the store rose ~9.6K while the recurring read fell 131KB. Report both numbers — claiming a shrink that didn't happen is the easy lie here.

## 9. Check your own targets for arithmetic

If you name a byte target *and* name untouchable sections, add the untouchable sections up first. A 25K target was impossible against 24.5K of sections marked keep-in-full; the agent was right to land at 51K and say why rather than gut them to hit the number.
