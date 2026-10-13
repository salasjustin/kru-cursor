# Syncing kru-cursor with upstream kru

Hand-owned by this fork (`PORTING.md` → *Hand-owned*). Upstream is the public
[ap-justin/kru](https://github.com/ap-justin/kru); this fork's tree is a function of it — upstream's
newest commit with the fork-owned files laid over it, ported once by `scripts/port.mjs` — and
`scripts/verify.sh` checks exactly that on every run. Shipping what a sync brings in is `release.md`.

## What runs on its own

`.github/workflows/sync-upstream.yml`, every Monday (06:23 UTC) and on **Run workflow**:

1. Reads upstream `main`. A branch `sync/upstream-<sha>` already on the fork means that commit was
   handled; the run stops there.
2. Runs `scripts/sync-upstream.sh` on that branch. It records upstream as a merge parent
   (`git merge -s ours`) and replaces the tree with the fresh port, so a text conflict can't happen —
   even where a port rule rewrote a line upstream also edited.
3. Runs `bash scripts/verify.sh`, then one of:

| outcome | what you get |
|---|---|
| upstream already merged | nothing; the log says `no changes` |
| synced, checks green | a pull request `sync: upstream kru X.Y.Z` with the upstream commits, the files the port changed, the files to read by hand, and the verify summary |
| synced, checks red | the same pull request as a draft, with the failing summary |
| the port failed on the new upstream | no pull request; an issue `upstream sync blocked: …` (or a comment on the open one) with the port's problem list |

The job runs on the default `GITHUB_TOKEN` (`contents`, `pull-requests`, `issues: write`); no secret.

### Repo settings it needs (once)

- **Settings → Actions → General → Workflow permissions:** allow GitHub Actions to create and
  approve pull requests. Without it `gh pr create` fails with a 403.
- Scheduled workflows run from the default branch only, and GitHub turns a schedule off after 60
  days without repository activity; re-enable it from the Actions tab.

## Reviewing a sync pull request (Kai)

- **CI.** A pull request opened with the workflow token starts no other workflow, so the `verify`
  check doesn't appear by itself; the summary in the body is the sync run's own `verify.sh`. Push any
  commit to the branch to get a CI run.
- **Read by hand.** The body lists upstream files this fork replaces with its own copy
  (`hooks/require-lead.sh`, `hooks/brainstorm-guard.sh`, `README.md`, …). Upstream changed them;
  decide whether the change applies to Cursor and mirror it in the fork's copy on the same branch.
- **Known gaps.** A new upstream feature that names a Claude Code surface Cursor lacks shows in the
  port's *surfaces cursor lacks* count; record it in `PORTING.md` → *Known gaps*.
- Merge, then cut a release when it should reach users (`release.md`).

## When the port fails (the issue)

Upstream reworded a line a required rule needs, or brought a Claude Code construct no rule covers.

```
git switch -c sync-fix main
bash scripts/sync-upstream.sh --dry-run     # reproduces the problem list
# fix the rule in scripts/port.mjs (or a hand-owned block under scripts/cursor/)
bash scripts/sync-upstream.sh               # one merge commit, the tree regenerated
bash scripts/verify.sh
```

Open that as the sync pull request and close the issue. The workflow skips an upstream commit whose
branch exists, so delete `sync/upstream-<sha>` before re-running the workflow instead.

## Running it by hand

`bash scripts/sync-upstream.sh --dry-run` on a clean checkout says whether upstream has anything new
and what the port would change; without `--dry-run` it commits the merge on the current branch.
`KRU_UPSTREAM_URL` / `KRU_UPSTREAM_REF` point it elsewhere (`scripts/sync-upstream.test.sh` runs it
against a fake upstream). The plain `git merge upstream/main && node scripts/port.mjs` in
`PORTING.md` still works; it can conflict where this can't.
