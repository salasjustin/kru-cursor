# Test credentials

Loaded when a test run needs secrets or a database — the lead before a scoped run, a `kru-test-writer` dispatch, or a Browser check that needs them, and any seat writing or running those tests.

1. **Source.** Secrets come only from **Cursor Runtime Secrets** on the product repo's cloud-agent environment, read through the env var names the app already uses. Never from prompts, repo files, chat, or pasted output.

2. **Stripe.** Before any run that hits Stripe, turn tracing off in the **current shell** so no command expands a secret while xtrace is on — tracing stays off for the rest of the run. Start every guard with `{ set +x; } 2>/dev/null`. Never `echo`, `cut`, `printf`, or `head` any part of a secret value — only fixed status lines like the ABORT examples below. Run each check in the calling script (no `( … )` subshell): `exit` must stop the script. For each required Stripe **secret** key variable (e.g. `STRIPE_SECRET_KEY`), only `sk_test_` is allowed; anything else aborts (including `sk_live_`, `rk_test_`, `rk_live_`, or any other prefix):

   ```
   { set +x; } 2>/dev/null
   case "${STRIPE_SECRET_KEY-}" in
     sk_test_*) ;;
     '') echo 'ABORT: STRIPE_SECRET_KEY is not set'; exit 1 ;;
     *) echo 'ABORT: STRIPE_SECRET_KEY is not a test secret key'; exit 1 ;;
   esac
   ```

   For each required **publishable** key variable (e.g. `STRIPE_PUBLISHABLE_KEY` or `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`), only `pk_test_` is allowed:

   ```
   { set +x; } 2>/dev/null
   case "${STRIPE_PUBLISHABLE_KEY-}" in
     pk_test_*) ;;
     '') echo 'ABORT: STRIPE_PUBLISHABLE_KEY is not set'; exit 1 ;;
     *) echo 'ABORT: STRIPE_PUBLISHABLE_KEY is not a test publishable key'; exit 1 ;;
   esac
   ```

3. **No echo.** Never echo, log, commit, or screenshot a secret value. For presence only, use the same `{ set +x; } 2>/dev/null` first, then `[ -n "${VAR:+x}" ]` (or a `case` with an empty branch that names the variable) — no command may expand a secret while xtrace is on.

4. **Database.** Use only the `DATABASE_URL` (or the app's equivalent) that the cloud-agent environment provides through Runtime Secrets. Never derive, swap, or hand-type a database URL — whoever sets the secret is responsible for pointing it at a schema-only `test-e2e-*` branch. The URL itself does not prove which branch it is (a Neon host is an endpoint id). When the environment also provides a branch marker (e.g. `TEST_DB_BRANCH`), require it to match `test-e2e-*` and abort otherwise. Seed the data the test needs yourself.

5. **Missing.** A required secret that is unset gets named in the return and the test slice **stops** — no placeholder, no silent skip of the dependent case.
