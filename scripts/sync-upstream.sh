#!/bin/bash
# brings upstream kru (github.com/ap-justin/kru) into this fork without a text
# merge. the tree is a function of upstream — upstream's newest commit, the
# fork-owned files laid over it, ported once (scripts/verify.sh → the fresh-port
# check) — so instead of merging line by line, which conflicts wherever a port
# rule rewrote a line upstream also touched, this records upstream as a merge
# parent and makes the tree exactly that function's output. a conflict is
# impossible; what can fail is the port itself (upstream reworded a line a
# required rule exists for), and then nothing is committed and the port's own
# problem list is the report.
#
# run on a clean checkout of the branch to update (CI: .github/workflows/sync-upstream.yml):
#   bash scripts/sync-upstream.sh             merge + regenerate, one commit (never on the default branch)
#   bash scripts/sync-upstream.sh --dry-run   say what would change, touch nothing
# env: KRU_UPSTREAM_URL (default the public repo), KRU_UPSTREAM_REF (default main),
# KRU_SYNC_REPORT (default $TMPDIR/kru-sync-report.md) — markdown for a PR or issue.
#
# exit: 0 up to date or synced (or, dry run, changes found) · 2 the port failed
# on the new upstream (report written) · 1 anything else (dirty tree, no fetch)
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
dry=false
[ "${1:-}" = "--dry-run" ] && dry=true
url=${KRU_UPSTREAM_URL:-https://github.com/ap-justin/kru.git}
ref=${KRU_UPSTREAM_REF:-main}
report=${KRU_SYNC_REPORT:-${TMPDIR:-/tmp}/kru-sync-report.md}

# key=value pairs for the workflow's later steps; a no-op off CI
out() { [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; return 0; }

git fetch --quiet --no-tags "$url" "$ref" || { echo "sync: could not fetch $url $ref" >&2; exit 1; }
up=$(git rev-parse FETCH_HEAD)
up_version=$(git show "$up:VERSION" 2>/dev/null | tr -d '[:space:]')
# upstream's VERSION reaches the workflow's outputs, a commit message and a pull
# request title, so anything but a version string is refused rather than quoted
if [ -n "$up_version" ] && ! [[ $up_version =~ ^[0-9A-Za-z.+-]{1,64}$ ]]; then
  echo "sync: upstream ${up:0:8} has a VERSION that isn't a version string; refusing it: $(printf '%q' "${up_version:0:60}")" >&2
  exit 1
fi
out upstream_sha "$up"
out upstream_version "$up_version"

if git merge-base --is-ancestor "$up" HEAD; then
  echo "no changes: upstream $ref ${up:0:8} (kru $up_version) is already merged"
  out status up-to-date
  exit 0
fi
[ -z "$(git status --porcelain)" ] || { echo "sync: the working tree has changes; commit or stash them first" >&2; exit 1; }
# the merge commit lands on the branch checked out: never the default branch,
# where it would skip the pull request and verify (KRU_SYNC_ALLOW_DEFAULT=1 overrides)
if ! $dry && [ -z "${KRU_SYNC_ALLOW_DEFAULT:-}" ]; then
  current=$(git symbolic-ref --short -q HEAD || true)
  default=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
  case "$current" in ""|"${default:-main}"|main|master)
    echo "sync: on ${current:-a detached HEAD}; switch to a branch first (git switch -c sync/upstream)" >&2; exit 1 ;;
  esac
fi

# the newest upstream commit already merged: the first one in history without
# the port script (the same base verify.sh's fresh-port check reads)
base=""
for c in $(git rev-list HEAD); do git cat-file -e "$c:scripts/port.mjs" 2>/dev/null || { base=$c; break; }; done
base_version=$(git show "$base:VERSION" 2>/dev/null | tr -d '[:space:]')

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/tree" && git archive "$up" | tar -x -C "$tmp/tree"
# the fork owns .github/ outright (its copy is laid over below): upstream's
# workflows don't run here, and the workflow token can't push a new one
upstream_workflows=$(cd "$tmp/tree" && find .github -type f 2>/dev/null | sed 's#^\./##' | sort || true)
rm -rf "$tmp/tree/.github"
while IFS= read -r f; do
  mkdir -p "$tmp/tree/$(dirname "$f")" && cp -p "$f" "$tmp/tree/$f"
done < <(node scripts/port.mjs --list-fork-owned)

# upstream files this fork replaces or mirrors by hand (PORTING.md → Hand-owned):
# a change to one is a human read even when the port is clean
overridden=$(comm -12 <(git diff --name-only "$base" "$up" | sort) <(node scripts/port.mjs --list-fork-owned | sort) || true)
upstream_log=$(git log --oneline --no-merges -n 30 "$base..$up")

{
  printf '## Upstream kru %s → %s\n\n' "${base_version:-?}" "${up_version:-?}"
  printf 'Upstream `%s` (%s), previously `%s`.\n\n' "${up:0:8}" "$ref" "${base:0:8}"
  printf '### Upstream commits\n\n```\n%s\n```\n\n' "$upstream_log"
} > "$report"

if ! port_out=$(cd "$tmp/tree" && node scripts/port.mjs 2>&1); then
  {
    printf '### The port failed on the new upstream\n\n'
    printf 'Nothing was committed. Each problem below is an upstream rewording a port rule no longer matches, or a new Claude Code construct no rule covers: add or adjust the rule in `scripts/port.mjs` (or a hand-owned block), then run `bash scripts/sync-upstream.sh` again.\n\n'
    printf '```\n%s\n```\n' "$(printf '%s\n' "$port_out" | tail -n 40)"
  } >> "$report"
  echo "sync: the port failed on upstream ${up:0:8} — report: $report" >&2
  out status port-failed
  out report "$report"
  exit 2
fi

# every path that would be added, removed or rewritten
changed=$({
  comm -3 <(git ls-files | sort) <(cd "$tmp/tree" && find . -type f | sed 's#^\./##' | sort) | tr -d '\t'
  while IFS= read -r f; do if [ -f "$tmp/tree/$f" ] && ! cmp -s "$f" "$tmp/tree/$f"; then printf '%s\n' "$f"; fi; done < <(git ls-files)
} | sort -u)
{
  printf '### What the port changed\n\n%s file(s) added, removed or rewritten:\n\n```\n%s\n```\n\n' "$(printf '%s' "$changed" | grep -c . || true)" "$(printf '%s\n' "$changed" | head -n 60)"
  dropped=$(comm -23 <(printf '%s\n' "$upstream_workflows" | grep . || true) <(node scripts/port.mjs --list-fork-owned | sort) || true)
  if [ -n "$dropped" ]; then
    printf '### Not taken: upstream files under .github/\n\n'
    printf 'This fork owns `.github/`, so these upstream files were left out; port one by hand if Cursor needs it:\n\n'
    printf '%s\n' "$dropped" | sed 's/^/- `/; s/$/`/'
    printf '\n'
  fi
  if [ -n "$overridden" ]; then
    printf '### Read by hand: upstream changed files this fork replaces\n\n'
    printf 'The fork keeps its own copy of these (PORTING.md → Hand-owned); mirror what upstream changed if it applies to Cursor:\n\n'
    printf '%s\n' "$overridden" | sed 's/^/- `/; s/$/`/'
    printf '\n'
  fi
} >> "$report"
out report "$report"

if $dry; then
  echo "dry run: upstream ${up:0:8} (kru $up_version) would change $(printf '%s' "$changed" | grep -c . || true) file(s); report: $report"
  out status changes
  exit 0
fi

git merge --quiet --no-ff --no-commit -s ours "$up" >/dev/null
git ls-files -z | xargs -0 rm -f
cp -a "$tmp/tree/." "$repo/"
git add -A
git commit --quiet -m "sync: upstream kru ${up_version:-?} (${up:0:8})" -m "Merged by scripts/sync-upstream.sh: upstream recorded as a parent, the tree regenerated by scripts/port.mjs from upstream plus the fork-owned files."
echo "synced: upstream ${up:0:8} (kru $up_version) merged as $(git rev-parse --short HEAD)"
out status synced
