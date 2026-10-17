# Syncing kru-cursor with upstream kru

Hand-owned by this fork (`PORTING.md` → *Hand-owned*). Upstream is the public
[ap-justin/kru](https://github.com/ap-justin/kru); this fork's tree is a function of it — upstream's
newest commit with the fork-owned files laid over it, ported once by `scripts/port.mjs` — and
`scripts/verify.sh` checks exactly that on every run. Shipping what a sync brings in is `release.md`.

## What runs on its own

`.github/workflows/sync-upstream.yml`, every Monday (06:23 UTC) and on **Run workflow**:

1. Reads upstream `main`. A pull request from `sync/upstream-<sha>` (any state) or an issue naming
   that sha means the commit was handled; the run stops there. A run that pushed the branch but
   failed to open the pull request is retried next time, and the branch is replaced.
2. Runs `scripts/sync-upstream.sh` on that branch. It records upstream as a merge parent
   (`git merge -s ours`) and replaces the tree with the fresh port, so a text conflict can't happen —
   even where a port rule rewrote a line upstream also edited.
   Upstream's `.github/` is not taken: the fork owns that directory, and the workflow token can't
   push a workflow file. A file upstream added there is listed in the report under *Not taken*.
3. Runs `bash scripts/verify.sh` in its own job, then one of:

| outcome | what you get |
|---|---|
| upstream already merged | nothing; the log says `no changes` |
| synced, checks green | a pull request `sync: upstream kru X.Y.Z` with the upstream commits, the files the port changed, the files to read by hand, and the verify summary; an older sync pull request still open is closed as superseded |
| synced, checks red | the same pull request as a draft, with the failing summary |
| the port failed on the new upstream | no pull request; an issue `upstream port failed: …` (or a comment on the open one, retitled with the new commit) with the port's problem list |
| synced, but the push was refused | no pull request; an issue `upstream push refused: …` with git's refusal. Upstream's history touched `.github/workflows/`, which the workflow token may not push: run the sync by hand (below) and push with your own credentials |
| upstream's `VERSION` isn't a version string | the run fails red before anything is committed (`sync-upstream.sh` exits 1) |

Three jobs, on the default `GITHUB_TOKEN`; no secret. `verify.sh` runs upstream's code (its hook tests,
`audit.sh`) before anyone has read it, so that is the **verify** job and nothing else: `contents: read`
only, a checkout without stored credentials, no token in its environment, and no output but the ok flag.
The **sync** job (`contents: read`, plus read on pull requests and issues to see what was already
proposed) does not run that code. It runs the port — which starts no subprocess — and, before the
verify job starts, records the git bundle's sha256 and the artifact id of the upload as its own
outputs. The **propose** job (`contents`, `pull-requests`, `issues: write`) runs none of the repo's
code: it downloads that artifact by id, checks the sha256, re-checks the branch name, commit ids,
version and ok flag, fetches the bundle, and pushes and files with the token set on those steps only.
Values reach the scripts through `env:`, never `${{ }}` inside `run:`; `scripts/workflows.test.sh`
holds these rules and the actions' commit-SHA pins.

### Repo settings it needs (once)

- **Settings → Actions → General → Workflow permissions:** allow GitHub Actions to create and
  approve pull requests. Without it `gh pr create` fails with a 403.
- Scheduled workflows run from the default branch only, and GitHub turns a schedule off after 60
  days without repository activity; re-enable it from the Actions tab.

## Reviewing a sync pull request (the plugin maintainer)

The plugin maintainer reviews this pull request, and merges and tags this plugin's releases (`skills/kru-lead/SKILL.md`, first paragraph and *Who acts at the door*). The PM bot's own operating rules govern escalation and approval; the plugin's generic default applies only when the PM has none.

- **CI.** A pull request opened with the workflow token starts no other workflow, so the `verify`
  check doesn't appear by itself; the summary in the body is the sync run's own `verify.sh` — run on
  upstream's code, so it is that code's own report. Push any commit to the branch to get a CI run.
- **Read by hand.** The body lists upstream files this fork replaces with its own copy
  (`hooks/require-lead.sh`, `hooks/brainstorm-guard.sh`, `README.md`, …). Upstream changed them;
  decide whether the change applies to Cursor and mirror it in the fork's copy on the same branch.
- **Known gaps.** A new upstream feature that names a Claude Code surface Cursor lacks shows in the
  port's *surfaces cursor lacks* count; record it in `PORTING.md` → *Known gaps*.
- **Merge with a merge commit** (`gh pr merge --merge`), never squash or rebase. Squash drops
  upstream as a parent while `VERSION` still names the new kru release; `verify.sh` then fails
  (fresh port, sync tests, and the tree version check). The weekly sync script already records
  upstream with `git merge -s ours`; a hand port pull request needs the same shape — either run
  `bash scripts/sync-upstream.sh` on a branch, or finish with `git merge -s ours --no-ff
  <upstream-sha>` so history carries upstream's commit without changing the ported tree.
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

Open that as the sync pull request and close the issue. The workflow skips an upstream commit an
issue already names, so after fixing the rule on `main`, a newer upstream commit — or running the
script by hand as above — is what produces the pull request.

## Running it by hand

`bash scripts/sync-upstream.sh --dry-run` on a clean checkout says whether upstream has anything new
and what the port would change; without `--dry-run` it commits the merge on the current branch,
and refuses the default branch (the merge goes through a pull request and `verify.sh`;
`KRU_SYNC_ALLOW_DEFAULT=1` overrides).
`KRU_UPSTREAM_URL` / `KRU_UPSTREAM_REF` point it elsewhere (`scripts/sync-upstream.test.sh` runs it
against a fake upstream). The plain `git merge upstream/main && node scripts/port.mjs` in
`PORTING.md` still works; it can conflict where this can't.
