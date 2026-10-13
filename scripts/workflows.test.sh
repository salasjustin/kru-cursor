#!/bin/bash
# static checks over .github/workflows/*.yml: the workflows parse, and the
# rules that keep a token away from code nobody has reviewed yet hold —
# sync-upstream.yml runs upstream's tests (verify.sh) on upstream's code before
# the PM reads the pull request. run: bash scripts/workflows.test.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
py=(python3)
python3 -c 'import yaml' 2>/dev/null || py=(uv run -q --no-project --with pyyaml python3)
"${py[@]}" - "$repo"/.github/workflows/*.yml <<'PY'
import re, sys, yaml
passed = failed = 0
# a command that runs one of the repo's own scripts (prose naming one in a
# heredoc doesn't start a line)
RUNS_REPO_CODE = re.compile(r"(^|[;&|(]\s*)(bash|sh|node|python3?)\s+\S*(scripts|hooks)/", re.M)
def check(name, ok):
    global passed, failed
    if ok: passed += 1
    else: failed += 1; print(f"FAIL: {name}")
def writes(perms):
    if perms in ("write-all",): return True
    return isinstance(perms, dict) and any(v == "write" for v in perms.values())
for path in sys.argv[1:]:
    f = path.rsplit("/", 1)[-1]
    try:
        wf = yaml.safe_load(open(path))
    except yaml.YAMLError as e:
        check(f"{f}: parses ({e})", False); continue
    check(f"{f}: parses", isinstance(wf, dict))
    check(f"{f}: no write permission at the workflow level (per job instead)", "permissions" in wf and not writes(wf["permissions"]))
    check(f"{f}: no token in the workflow-level env", "GH_TOKEN" not in (wf.get("env") or {}))
    for jn, job in (wf.get("jobs") or {}).items():
        steps = job.get("steps") or []
        runs = [s.get("run", "") for s in steps]
        check(f"{f} {jn}: permissions set on the job", "permissions" in job or not writes(wf.get("permissions")))
        check(f"{f} {jn}: no token in the job-level env", "GH_TOKEN" not in (job.get("env") or {}))
        # a job that runs the repo's scripts runs whatever the checkout holds —
        # upstream's code, on a sync branch — so it holds no write token
        if any(RUNS_REPO_CODE.search(r) for r in runs):
            check(f"{f} {jn}: runs repo scripts, so no write permission", not writes(job.get("permissions", wf.get("permissions"))))
        for i, s in enumerate(steps):
            label = s.get("name") or s.get("uses") or s.get("run", "").split("\n")[0][:40]
            if "run" in s:
                # an expression in a script is pasted in before the shell parses it
                check(f"{f} {jn} [{label}]: no ${{{{ }}}} expression inside run:", "${{" not in s["run"])
                if RUNS_REPO_CODE.search(s["run"]):
                    check(f"{f} {jn} [{label}]: no token beside repo scripts", not any(k in (s.get("env") or {}) for k in ("GH_TOKEN", "GITHUB_TOKEN")))
            if "uses" in s:
                check(f"{f} {jn} [{label}]: action pinned to a commit sha", re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", s["uses"]) is not None)
                if s["uses"].startswith("actions/checkout@"):
                    check(f"{f} {jn} [{label}]: checkout keeps no credentials in .git/config", (s.get("with") or {}).get("persist-credentials") is False)
print(f"{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
