---
name: kru-msw
description: "MSW 3 recipes — the green test whose request never met a handler. Use when writing or reviewing a test, setup file or handler in a repo with `msw` in `package.json`. Node `setupServer` under Vitest; not the browser worker, not the Vite plugin."
---

**Every request MSW doesn't answer goes somewhere, and the test can't tell where.** A mocked request proves only what its handler checked; everything the handlers don't claim — an unmatched URL, a resolver that returns nothing, a request sent after a second server's `close()` — leaves for the real network or fails inside app code that catches it, and the test stays green. Each trap below is one of those exits. Make every exit fail the test (the setup file below), then read a failure as a report on which handler didn't answer.

Reproduced on **`msw@3.0.1`** (npm `latest`, 2026-10-02) with `vitest@5.0.3` (`environment: 'jsdom'`), `jsdom@30.1.1`, `axios@1.20.0`, TypeScript 7.0.2, Node 24.20.0. MSW 3 is ESM-only, needs Node ≥ 22.12 and TypeScript ≥ 5.9. `graphql` exists only at `msw/graphql`, needs the `graphql` package installed, and hangs its handlers off `graphql.link(url)`.

## The setup file: make every unanswered request a failure
```ts
// vitest setupFiles entry
import { afterAll, afterEach, beforeAll, expect } from 'vitest'
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
export const leaks: string[] = []
server.events.on('request:unhandled', ({ request }) => { leaks.push(`unhandled ${request.method} ${request.url}`) })
server.events.on('response:bypass', ({ request }) => { leaks.push(`real network ${request.method} ${request.url}`) })
server.events.on('unhandledException', ({ request, error }) => { leaks.push(`handler threw on ${request.method} ${request.url}: ${error}`) })

beforeAll(() => server.listen({ onUnhandledFrame: 'error' }))
afterEach(() => { server.resetHandlers(); expect(leaks.splice(0), 'requests no handler answered').toEqual([]) })
afterAll(() => server.close())
```
Each event closes one exit the sections below reproduce: `request:unhandled` the URL no handler matched, `response:bypass` the request that reached the network (a no-return resolver, `passthrough()`, or an unmatched request under `'warn'`/`'bypass'`), `unhandledException` the resolver that threw. Export `leaks` so a test that means to pass a request through can drop its entry. One server, one setup file — see the last trap.

## `onUnhandledRequest` is not an option
```ts
server.listen({ onUnhandledRequest: 'error' })   // tsc: TS2353 — 'onUnhandledRequest' does not exist
// at runtime the key is ignored: default 'warn', request reaches the real server, test green
server.listen({ onUnhandledFrame: 'error' })     // the option
```
The key is `onUnhandledFrame` (requests and WebSocket connections share it), and nothing reads `onUnhandledRequest`. Vitest strips types without checking them, so the TS2353 shows only under `tsc`. The `[MSW] Warning: intercepted a request without a matching request handler` that `'warn'` prints is gone under the agent-detected `minimal` reporter on a passing test (`vitest` skill, the reporter swap). In the callback form, `onUnhandledFrame({ frame, defaults })`, **`defaults.error()` only prints** — the request still goes to the real network (reproduced: `getaddrinfo ENOTFOUND` after the `[MSW] Error`; the source notes it as backward compatibility). Throw from the callback to stop it, and the request answers 500:
```ts
server.listen({ onUnhandledFrame({ frame, defaults }) {
  const { request } = frame.data as { request?: Request }   // `data` is typed `unknown`; checking `protocol` doesn't narrow it
  if (frame.protocol === 'http' && request && new URL(request.url).hostname === 'cdn.test') return   // allowed through
  defaults.error()
  throw new Error('unhandled request')
} })
```
The 2→3 migration guide's callback (`frame.data.request.url` after a `protocol` check) is TS18046 under `strict`.

## `'error'` fails the fetch, not the test
```ts
server.listen({ onUnhandledFrame: 'error' })
async function loadOrders() {
  try { return await (await fetch('https://api.test/orders')).json() } catch { return { fallback: true } }
}
expect(await loadOrders()).toEqual({ fallback: true })   // ✓ — fetch rejected, the app caught it
// TypeError: fetch failed — cause: [MSW] Cannot bypass a request when using the "error" strategy …
```
`'error'` prints `[MSW] Error: intercepted a request without a matching request handler` and rejects the request with a network error. App code that handles network errors — every data layer with an error state — turns that into a rendered fallback, and a test asserting the error state passes on a URL typo. The `afterEach` guard above is what turns it into a failure.

## A resolver that returns nothing sends the request to the real network
```ts
let calls = 0
server.use(http.get('https://api.test/user', () => { calls++ }))   // the "spy" handler
await fetch('https://api.test/user')   // calls === 1, then the request goes out — even under 'error', with no message
```
A matched handler that returns `undefined` hands the request to the next matching handler, and past the last one to the network; MSW counts it as handled, so `onUnhandledFrame` never fires. `passthrough()` does the same on purpose. To prove what the app sent, record inside a resolver that also answers:
```ts
const sent: unknown[] = []
server.use(http.post('https://api.test/orders', async ({ request }) => {
  sent.push(await request.json())
  return HttpResponse.json({ id: 1 }, { status: 201 })
}))
// … drive the UI …
expect(sent).toEqual([{ qty: 2 }])
```
A UI assertion proves the response rendered; a handler that answers any body the same way can't tell a correct POST from a wrong one. A `server.events` listener reading the body must `request.clone()` — reading the original consumes it, and the handler that runs next fails with `TypeError: unusable`, served as a 500.

## Overrides outlive the test
```ts
test('A', () => { server.use(http.get(url, () => new HttpResponse(null, { status: 500 }))) })
test('B', async () => { await fetch(url) })   // 500 — A's override is still first in line
```
`server.use` prepends; the first matching handler wins (inside one `use(a, b)`, `a`); nothing removes it but `resetHandlers()`, which restores the `setupServer(...)` list. `{ once: true }` answers one request, then falls back to the next match. Under `describe.concurrent` / `test.concurrent`, `resetHandlers` can't help — a sibling's override is visible mid-test (reproduced: the second test saw the first's 500). Wrap each concurrent test in `server.boundary(async () => { … })`, which scopes its `server.use` to that call.

## A response object answers once
```ts
const user = HttpResponse.json({ name: 'Ada' })            // hoisted, maybe in handlers.ts
server.use(http.get('https://api.test/user', () => user))
await fetch('https://api.test/user')   // 200
await fetch('https://api.test/user')   // never settles — "Test timed out in 5000ms", no MSW message
```
A `Response` body is a one-read stream; the second request gets the spent one and hangs. In a shared `handlers.ts` the first test that hits the route passes and a later one times out, far from the cause. Build the response inside the resolver. Native `Response.json(…)` works as a return value and hangs the same way when hoisted, adding an unhandled `TypeError: Response body object should not be disturbed or locked` after the timeout.

## A resolver that throws is a 500, not a failure
A resolver exception — `await request.json()` on an empty body, a fixture typo — becomes a `500` whose body is the serialized error (`{"name":"SyntaxError","message":"Unexpected end of JSON input",…}`) plus a stderr line, and the test asserting the error state goes green. `HttpResponse.error()` is the deliberate network failure (`TypeError: fetch failed`); a 4xx/5xx is `new HttpResponse(null, { status })`. The guard's `unhandledException` listener catches the accidental one.

## Query strings don't match
```ts
server.use(
  http.get('https://api.test/users?page=1', () => HttpResponse.json({ page: 1 })),
  http.get('https://api.test/users?page=2', () => HttpResponse.json({ page: 2 })),
)
await fetch('https://api.test/users?page=2')   // { page: 1 } — plus "[MSW] Found a redundant usage of query parameters"
```
The handler URL matches on path only; the query is dropped with a warning and the first handler answers every page. Branch inside one resolver on `new URL(request.url).searchParams`. A trailing slash matches its bare path.

## The handler URL is resolved, and so is the app's
Under jsdom, a relative handler (`'/api/user'`) resolves against `location` — `http://localhost:3000/` — and while the server listens, the app's relative `fetch('/api/user')` resolves the same way and matches (without MSW listening, Node's `fetch` fails on a relative URL; the `vitest` skill). It does not match the absolute base the app builds from `import.meta.env.VITE_API_URL`; write handlers against the URL the app actually requests, or `'*/api/user'` to match any origin. Under `environment: 'node'` there is no `location`: a relative `fetch` throws `TypeError: Failed to parse URL` before any handler.

## XMLHttpRequest under jsdom enforces CORS on the mock
```ts
server.use(http.get('https://api.test/user', () => HttpResponse.json({ name: 'Ada' })))
await axios.get('https://api.test/user')                         // AxiosError ERR_NETWORK "Network Error", response undefined
await axios.get('https://api.test/user', { adapter: 'fetch' })   // { name: 'Ada' }
```
jsdom's `XMLHttpRequest` — axios's adapter whenever `XMLHttpRequest` exists — applies CORS to the mocked response: cross-origin from `http://localhost:3000` with no `Access-Control-Allow-Origin`, it fires `onerror` with status `0`, and MSW logs nothing because the handler did answer. Node's `fetch` applies no CORS. Fix in the handler: `headers: { 'access-control-allow-origin': '*' }` on cross-origin mocks, or have the app call a same-origin (relative) base under test.

## Fake timers hold every `delay()`
```ts
http.get(url, async () => { await delay(1000); return HttpResponse.json(x) })
vi.useFakeTimers()
await fetch(url)                                    // never settles — "Test timed out"
const p = fetch(url); await vi.advanceTimersByTimeAsync(1000); await p   // ✓
```
`delay()` is a plain `setTimeout`. The bare `delay()` (5 ms in Node) hangs the same way. Advance with the `Async` variants, or fake only what the test needs (`vi.useFakeTimers({ toFake: ['Date'] })` leaves `setTimeout` real). Fake-timer mechanics are the `vitest` skill's.

## Cookies don't round-trip in Node
`document.cookie = 'session=abc'` never reaches the handler — `cookies` is `{}` and `request.headers.get('cookie')` is `null`, `credentials: 'include'` or not — and a mock's `Set-Cookie` never lands in `document.cookie`. MSW 3 leaves cookies to the environment, and Node's `fetch` keeps no jar. An explicit `cookie` header in the request does arrive, in both `cookies` and the header. A handler that branches on the session cookie takes its logged-out branch in every jsdom test; model auth per test with `server.use` instead.

## A second server shadows the first, and its `close()` turns both off
```ts
// setup file: global `server` listening with its handlers
const local = setupServer(http.get('https://api.test/user', () => HttpResponse.json({ from: 'local' })))
local.listen()
await fetch('https://api.test/user')   // { from: 'local' } — the global handlers are out of reach
local.close()
await fetch('https://api.test/user')   // real network: getaddrinfo ENOTFOUND api.test — no MSW message
```
Interception is process-wide and the last `listen()` owns it; `close()` releases it for every server, so the rest of the file runs unmocked and the guard's listeners — registered on the global server — stay silent. One `setupServer` per test process, in the setup file; a file that needs other handlers calls `server.use` on that one.

## Consult current docs (official sources first)
`https://mswjs.io/docs/` (Node: `/api/setup-server`, `/api/setup-server/boundary`; matching: `/http/intercepting-requests`; events: `/api/life-cycle-events`; `/api/delay`, `/api/passthrough`, `/api/bypass`; 2→3: `/migrations/2.x-to-3.x`). Release notes: `github.com/mswjs/msw/releases`. Context7: `/mswjs/mswjs.io`. The installed `msw/lib/node/index.d.ts` is the shape of `setupServer`; `SharedOptions` in `msw/lib/_chunks/shared-options.d.ts` is every `listen` option.

## Not this skill's job
- **What a test should assert, and how this repo tests** — the **`testing`** skill.
- **The runner** — `setupFiles`, `globals`, the reporter that drops output, fake timers in depth, jsdom's missing APIs: the **`vitest`** skill.
- **Querying what the response rendered** — the **`testing-library`** skill.
- **The browser** — `setupWorker`, `mockServiceWorker.js`, the `msw/vite` plugin and Vitest Browser Mode were not reproduced here; read the docs above.
