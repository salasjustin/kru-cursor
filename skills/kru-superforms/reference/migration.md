# Superforms 2 on SvelteKit 2 → Superforms 3 on SvelteKit 3

- **Bump Superforms before Kit.** 3.0.0 peers on `@sveltejs/kit ^2.12 || ^3` and `svelte >=5.56.4`; 2.x imports `$app/stores`, which Kit 3 removed. The API didn't move; only the client's `page` store is rebuilt over `$app/state`.
- **An enhanced submit's HTTP status is now the action's status.** Kit 2 answered every `fail(400)`, `message(…, { status: 409 })` and `setError` with HTTP 200 and the status inside the body; Kit 3 sends 400/409/422 on the wire. Superforms reads it the same, but an e2e test, service worker or error monitor watching the action request now sees a 4xx for every invalid submit.
- **`$lib` imports fail** with `module_removed_lib` — the shared schema file is usually the first hit. Import from `#lib`, or add `alias: { '$lib': 'src/lib' }` to the `sveltekit()` options.
- **A cross-origin form POST with no `Content-Type` gets 403** (`Cross-site POST form submissions are forbidden`), on top of the form content types Kit 2 already refused. A test that posts to an action from another origin needs a form content type and a same-origin `Origin`.
