# Sending webhooks

## Use the Standard Webhooks wire format, not your own
Headers are `webhook-id`, `webhook-timestamp` (unix seconds) and `webhook-signature`. The signed content is `{id}.{timestamp}.{body}`, HMAC-SHA256, sent as `v1,<base64>`. The secret is `whsec_` followed by base64 of 24–64 random bytes. The body is `{ "type": "order.paid", "timestamp": "<ISO 8601>", "data": {…} }`, with dot-separated type names. ([spec](https://github.com/standard-webhooks/standard-webhooks/blob/main/spec/standard-webhooks.md))

**Why this format:** receivers can verify with an existing library in their own language. A custom `x-app-signature: t=…,v1=…` forces every integrator to write their own verifier. That's where the known mistakes happen: comparing with `==`, or re-serializing the parsed JSON before hashing it.

- **The HMAC key is the decoded bytes, not the string.** Strip `whsec_`, base64-decode, and key the HMAC with the resulting bytes. Tested against `standardwebhooks` 1.1.1: bytes → verified; the literal `whsec_…` string as the key → `No matching signature found`, on every delivery. **Add a spec that signs with your code and verifies with the reference library** (`standardwebhooks` on npm). That one test proves compatibility with every receiver.
- **Sign exactly the bytes you send.** Serialize once, sign that string, and send that same string as the body. Re-serializing the same JSON with different whitespace was rejected in the same test. Passing an object to a helper that stringifies it again after you signed breaks the same way.
- **`webhook-id` is per event, not per attempt.** It stays the same across retries, per the spec. Receivers use it to skip duplicates. The attempt number is a separate header of your own.
- **One signing secret per endpoint.** The spec says reusing keys across customers "can lead to security issues": a secret shared between endpoints lets one receiver forge deliveries to another.
- **Rotation signs with both secrets during an overlap window.** The header is a space-separated list. Tested: a receiver still holding only the old secret verified `"<new> <old>"`. A rotation that swaps the secret immediately fails every delivery until the receiver redeploys.
- **Include a timestamp tolerance in the verification docs.** The reference library rejects timestamps more than 5 minutes off in either direction. State that window so receivers reject replays.
- **Always send `v1` (HMAC). Add `v1a` (ed25519) only alongside it.** The spec prefers asymmetric signing, but `standardwebhooks` 1.1.1 verifies only `v1` and skips any other version. A sender that sends only `v1a` fails every delivery to a receiver using the reference library. And because `v1` is always sent, the HMAC secret stays stored in a form the app can read back: signing needs it.
- **Keep payloads under 20 KB**, as the spec recommends.

## The outbox — enqueue with the change, send after the commit
- **Write the delivery row in the same transaction or batch as the state change it's about.** An enqueue after the commit can be lost in a crash. An enqueue before it can announce a change that later rolled back.
- **Never send inside the request that made the change.** A slow receiver becomes your latency, and a receiver's failure can't be rolled back. A background loop sends what's pending.
- **One row per (event, endpoint).** Each endpoint has its own attempts, backoff and status. One broken endpoint must not hold up the others.

## Ordering and what the payload carries
- **There's no ordering guarantee, and retries make it worse.** `order.refunded` can arrive before a retried `order.paid`. Pick one of two shapes and say which in the docs:
  - **A snapshot**: the object as it was when the event happened, plus a version number or `updated_at` that only goes up, so the receiver can drop anything older than what it has. It describes the past, never the current state.
  - **A thin event**: type and id only, and the receiver fetches current state from the API. This removes the ordering problem, but only if there's a read API to fetch from.
- **Adding an event type must not break receivers.** The docs promise from v1 that unknown types are ignored and acknowledged with a 2xx.

## Classifying a response
| Response | Action |
|---|---|
| `2xx` | sent |
| `410 Gone` | disable the endpoint — the spec's signal |
| `3xx` | a failure, never followed. HTTP clients follow redirects by default (`fetch`: `redirect: "follow"`; Go's `http.Client`: until 10 requests), so a redirect would reach a URL nobody validated, and that URL's `200` would count as delivered. Turn redirects off: `redirect: "manual"`, or a `CheckRedirect` that returns `http.ErrUseLastResponse`. The spec counts 3xx as a failure, and OWASP says to disable redirects for this reason. |
| `429`, `502`, `503`, `504` | retry, honouring `Retry-After` when it's longer than the next backoff step |
| any other non-2xx, timeout, network error | retry on the schedule |

**Retry other 4xx responses; don't treat them as final.** The spec counts only 2xx as success, lists `404` among the failures a producer retries, and names only `410` as a reason to stop. A broken receiver often returns 401, 403 or 404 for a few minutes, during a deploy or after losing an env var, and treating those as final drops the events from exactly that window.

- **Always set a timeout.** Neither `fetch` nor Go's zero-value `http.Client` has one by default. The spec recommends 15–30 s.
- **Store only the first few KB of the response body.** It's a stranger's text, of any size, possibly with their users' data in it.

## Retries, exhaustion, auto-disable
- **Retry with exponential backoff and jitter, over days, not minutes.** The spec's example runs 10 attempts over about 75 hours (immediately, 5 s, 5 m, 30 m, 2 h, 5 h, 10 h, 14 h, 20 h, 24 h). Jitter stops a receiver that comes back from getting everything it missed in the same second.
- **Once attempts run out, mark the delivery failed and keep it.** Whoever registered the endpoint can redeliver it later. Redelivery moves one row from failed back to pending, and a single module owns that transition.
- **Disable an endpoint after sustained failure, and tell a person.** Consecutive failures across the endpoint past a threshold, or a `410`, set `enabled = false`. Notify the endpoint's owner once. Deliveries enqueued while it's disabled are dropped or held, and the docs say which.
- **A test event goes through the real signing and delivery path** and is recorded as a delivery. A separate test sender proves only itself.

## SSRF — a user types the URL, your server fetches it
- **HTTPS only. Refuse `localhost` and any address the IANA special-purpose registries mark not globally reachable** ([IPv4](https://www.iana.org/assignments/iana-ipv4-special-registry/), [IPv6](https://www.iana.org/assignments/iana-ipv6-special-registry/)). A hand-written list of private ranges usually misses two: `0.0.0.0/8`, and `::ffff:0:0/96` (IPv4-mapped IPv6), which wraps any IPv4 address in IPv6 notation.
- **Check the parsed hostname, not the string the user typed.** A regex sees `https://2130706433/`, `https://0x7f.1/` and `https://017700000001/` as three hostnames; a WHATWG `URL` parser returns `127.0.0.1` for all three (tested in Node). An IPv4-mapped address stays IPv6 after parsing (`[::ffff:7f00:1]`), so unwrap it before the range check. OWASP names these hex, octal and dword encodings as the usual bypass ([OWASP SSRF](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)).
- **Check again at send time, not only at registration.** DNS can change after the endpoint is saved, and a hostname that passed can later resolve to an internal address.
- **What an attacker can reach depends on the host.** A VM or container can reach its private network and the cloud metadata endpoint at `169.254.169.254`. There, a hostname check can't see the address `fetch` finally connects to, and the spec's answer is an egress proxy that filters internal IPs (it names Stripe's `smokescreen`), with the senders on a subnet that can't reach internal services. An edge or serverless runtime may have no private network at all, but a platform's undocumented egress filtering is not a contract. Keep your own check either way.

## The delivery loop
A background sender is bounded by the host, and the limits that bind it aren't the obvious one. Read them from the platform's own limits page, not from here.
- **Time spent waiting on a receiver is wall-clock time, not CPU time.** A sender spends almost all of its time waiting on `fetch`, so a CPU ceiling rarely binds it. What binds is the run's wall-clock limit and the number of connections it can hold open at once. Size a run as sends × timeout ÷ concurrency and make sure that fits inside the run's deadline.
- **Each attempt is one outbound request**, and some hosts cap outbound requests per invocation.
- **A scheduled run overlaps the previous one whenever a run takes longer than its interval.** Claim rows with a lease: a conditional `UPDATE … WHERE status = 'pending' AND (leased_until IS NULL OR leased_until < now) … RETURNING`, and send only the rows that statement returned.
