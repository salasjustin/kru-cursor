#!/bin/bash
# static checks over .github/workflows/*.yml: the workflows parse, and the
# rules that keep a token away from code nobody has reviewed yet hold —
# sync-upstream.yml runs upstream's tests (verify.sh) on upstream's code before
# the PM reads the pull request. verify.sh has its own job, which outputs
# only the ok flag; the sync job records the bundle sha256 and artifact id
# first, and the propose job checks them. run: bash scripts/workflows.test.sh
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
    if f == "sync-upstream.yml":
        jobs = wf.get("jobs") or {}
        sync, verify, propose = jobs.get("sync") or {}, jobs.get("verify") or {}, jobs.get("propose") or {}
        sync_runs = "\n".join(s.get("run") or "" for s in (sync.get("steps") or []))
        propose_runs = "\n".join(s.get("run") or "" for s in (propose.get("steps") or []))
        vsteps, psteps = verify.get("steps") or [], propose.get("steps") or []
        def idx(steps, pred):
            return next((i for i, s in enumerate(steps) if pred(s)), -1)
        check(f"{f}: verify is its own job", "verify" in jobs and verify is not sync)
        check(f"{f} sync: does not run verify.sh", "verify.sh" not in sync_runs)
        check(f"{f} verify: needs sync", verify.get("needs") == "sync")
        check(f"{f} verify: contents read only", verify.get("permissions") == {"contents": "read"})
        check(f"{f} verify: outputs only the ok flag", list(verify.get("outputs") or {}) == ["ok"])
        outs = sync.get("outputs") or {}
        check(f"{f} sync: records the bundle sha256", any("sha256" in str(v) for v in outs.values()))
        check(f"{f} sync: records the artifact id", any("artifact-id" in str(v) for v in outs.values()))
        check(f"{f} sync: does not output the verify flag", "verify_ok" not in outs and "ok" not in outs)
        sha_i = idx(vsteps, lambda s: "sync.bundle" in (s.get("run") or "") and "sha256sum" in (s.get("run") or ""))
        ver_i = idx(vsteps, lambda s: "scripts/verify.sh" in (s.get("run") or ""))
        check(f"{f} verify: sha256 is checked before verify.sh", sha_i != -1 and ver_i != -1 and sha_i < ver_i)
        by_id = [s for s in psteps if "download-artifact" in (s.get("uses") or "") and "artifact-ids" in (s.get("with") or {})]
        check(f"{f} propose: downloads the sync artifact by id", len(by_id) == 1 and "name" not in (by_id[0].get("with") or {}))
        check(f"{f} propose: needs sync and verify", propose.get("needs") == ["sync", "verify"])
        check(f"{f} propose: sha256 is checked before fetch", any(
            "sha256sum" in (s.get("run") or "") and "git fetch" in (s.get("run") or "") and (s.get("run") or "").find("sha256sum") < (s.get("run") or "").find("git fetch")
            for s in psteps))
        check(f"{f}: push-refused and port-failed issues have distinct titles",
              "upstream push refused:" in propose_runs and "upstream port failed:" in propose_runs and "upstream sync blocked" not in propose_runs)
        check(f"{f}: summary.txt is indented before the pull request body", "sed 's/^/    /'" in propose_runs)
print(f"{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
