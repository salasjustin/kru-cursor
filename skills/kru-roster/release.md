# Releasing kru-cursor

Hand-owned by this fork (`PORTING.md` → *Hand-owned*); upstream's own release steps don't apply
here. Bringing upstream in is `fork-sync.md`; this file starts once `main` holds what should ship.

## Who acts

| step | who |
|---|---|
| the version bump commit, local, with `bash scripts/verify.sh` green | Claude Code (the lead), on the PM's ask |
| push, pull request, merge, tag | Kai, kru's PM bot — Kai owns kru releases and may merge and tag |
| resubmitting to Cursor's marketplace, or making the repo public for it | Justin: anything public or live goes to him (publishing is a one-way door, which goes to the user: `skills/kru-lead/SKILL.md` → *Talk to a PM, not to an engineer*) |
| a Teams marketplace, the Cursor GitHub App, any new outside account | Justin decides (money, outside services); Otto sets the account up |

## The version

`VERSION` is `0.N.0+kruX.Y.Z`:

- `0.N.0` is the fork's own release counter. Each release bumps `N` by one (`0.1.0` → `0.2.0`);
  patch stays `0` unless a release only fixes the previous one (`0.2.1`).
- `X.Y.Z` is the upstream kru version merged in. `scripts/port.mjs` keeps it equal to upstream's
  `VERSION` on every sync, so it is never edited by hand.

The port writes the same string into `.cursor-plugin/plugin.json`, `.cursor-plugin/marketplace.json`,
the `# Roster — v…` header and `rules/kru-lead.mdc`; `scripts/verify-tree.mjs` fails when any of them
disagree.

## Steps

1. **Bump.** On a branch off `main`, change the fork half of `VERSION` (`0.<N>.0` → `0.<N+1>.0`,
   the `+kru…` half untouched), then `node scripts/port.mjs && bash scripts/verify.sh`. The port rewrites the
   manifests from `VERSION`, and the fresh-port check reads the fork half back from
   `.cursor-plugin/plugin.json`. Commit `release: v<VERSION>` with a short list of what changed
   for someone using the plugin since the last tag (`git log v<last>..HEAD --oneline`).
2. **Merge.** Kai pushes, opens the pull request, checks CI (`verify`), and merges.
3. **Tag** the merge commit on `main` with `v` + `VERSION`
   (`git tag -a "v$(cat VERSION)" -m "kru-cursor $(cat VERSION)"`) and push the tag. Upstream's own tags (`v0.150.0`) live in the same repo; the `+kru` suffix keeps
   the fork's apart.
4. **Ship it to Cursor** — one of the two channels below. Pushing to `main` alone changes nothing
   for anyone who installed from a marketplace.
5. **Check it landed.** On a cloud agent with the plugin installed:
   `cat ~/.cursor/plugins/cache/.cloud-plugin-manifest.json` — the kru-cursor entry's
   `resolvedCommitSha` is the tag's commit (`git rev-list -n1 "v$(cat VERSION)"`).

## How Cursor pins a plugin

Cloud agents don't track a branch. The marketplace records each plugin as a reviewed git source,
and the agent VM writes what it installed to `~/.cursor/plugins/cache/.cloud-plugin-manifest.json`:
`gitUrl`, `gitPath`, `gitRef` and `resolvedCommitSha` per plugin (or `releaseRepo`, `releaseAsset`,
`releaseTag` for a release-asset source). Read off `cursor-agent` 2026.10.01's bundle (the loader
reads that file from `~/.cursor/plugins/cache/`; the source resolver returns the
`resolvedCommitSha`); Cursor's docs don't describe the file.

### Channel 1: the public Cursor Marketplace

- Cursor's docs: plugins are "submitted through the Cursor team. Every plugin is manually reviewed
  before it's listed" (`cursor.com/docs/plugins`), from a **public** git repository
  (`cursor.com/docs/reference/plugins` → *Submitting a plugin*, `cursor.com/marketplace/publish`).
- Every update is re-reviewed by hand as well, so the listing moves to a new commit only after
  Cursor reviews it. **Each release is therefore a tag plus a resubmission** (or a note to the
  Cursor marketplace contact naming the tag and its commit SHA), and the release is live only
  once Cursor approves it.
- `salasjustin/kru-cursor` is private today, so this channel needs the repo made public first:
  Justin's call.

### Channel 2: a Teams team marketplace

- On a Teams or Enterprise plan, an admin imports the repo under **Dashboard → Plugins & MCPs →
  Team Marketplaces** (the repo root carries `.cursor-plugin/marketplace.json` for exactly this).
  With **Enable Auto Refresh** on, Cursor re-indexes when the tracked branch is pushed (at most every
  10 minutes; it needs the Cursor GitHub App on the repo), and **Serve marketplace from Cursor**
  lets members install without GitHub access to a private repo (`cursor.com/docs/plugins` → *Team
  marketplaces*). No public repo and no Cursor review.
- **Unverified:** whether a cloud agent installing from a team marketplace follows the refreshed
  commit or keeps the SHA it pinned. Check with step 5 after the first refresh before relying on it.
- Tracking `main` makes every merge a release. To keep tags meaningful, point the marketplace at a
  `release` branch and fast-forward it to each tag.
- A Teams plan and the GitHub App are a paid plan and an outside service: Justin decides, Otto sets
  them up.
