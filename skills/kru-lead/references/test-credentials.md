# Test credentials

Loaded when a test run needs secrets or a live database — the lead before a scoped run or a `kru-test-writer` dispatch, and any seat writing or running those tests.

1. **Source.** Secrets come only from **Cursor Runtime Secrets** on the product repo's cloud-agent environment, read through the env var names the app already uses. Never from prompts, repo files, chat, or pasted output.

2. **Stripe.** Before any run that hits Stripe, check prefixes in the shell **without printing values**: secret keys must start `sk_test_`, publishable keys `pk_test_`. Stop the slice if any set key starts `sk_live_`, `pk_live_`, or `rk_live_`.

3. **No echo.** Never echo, log, commit, or screenshot a secret value — only presence (`[ -n "$VAR" ]`) or prefix checks.

4. **Database.** `DATABASE_URL` (or the app's equivalent) must point at a **schema-only test branch** named `test-e2e-*`. Stop if it targets production or a prod-copied branch. Seed the data the test needs yourself.

5. **Missing.** A required secret that is unset gets named in the return and the test slice **stops** — no placeholder, no silent skip of the dependent case.
