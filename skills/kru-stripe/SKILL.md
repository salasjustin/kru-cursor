---
name: kru-stripe
description: Stripe platform recipes — API version pinning (a webhook endpoint freezes its own), the raw-body signature trap, retry/idempotency/out-of-order webhook handling, the Checkout+Billing object graph, sandboxes vs test mode, restricted keys. Stops where app payment UI begins.
---

Claims checked against `docs.stripe.com` (its `.md` twin per page) on 2026-10-26; a rule with no citation is a recipe, and the reason stands beside it. **Never pin a version or a limit from memory** — `docs.stripe.com/llms.txt` opens with that instruction to agents specifically, and this file goes stale the same way training data does.

**Every failure mode below reports success at a glance.** A webhook with a bad signature still returns an HTTP response; an out-of-order event still parses; a `status: active` subscription still reads as paid. The traps are in what the response doesn't tell you.

## Three places a version is pinned, and they drift apart
"What API version am I on" has three independent answers, and nothing keeps them in sync:
1. **The account default**, set in Workbench. Any request that doesn't specify a version uses it.
2. **The SDK's own pin.** Recent major SDKs (stripe-node v12+, stripe-python v6+, stripe-ruby v9+, stripe-php v11+) pin to whatever version was current when *that SDK version* was released, regardless of the account default — upgrading the package can silently change your effective API version. Older SDK majors fall back to the account default instead. The strongly-typed SDKs (Java, Go, .NET) can't override it at all; changing version means changing the SDK version.
3. **Each webhook endpoint's own `api_version`**, frozen at the endpoint's creation time. If unset there, it falls back to the account default **at the time each event is created**, not at delivery time — so raising the account default tomorrow reshapes every event this endpoint receives tomorrow, but never touches events already queued. ([`docs.stripe.com/events/how-events-work`](https://docs.stripe.com/events/how-events-work))

A team can genuinely be running three different effective versions at once without anyone having changed anything in months. **Thin events sidestep this**: their notification payload is unversioned and never reshapes, which is why Stripe now recommends them for new integrations over snapshot (fat) events.

**Upgrading a webhook endpoint's version is a cutover, not an edit** — `snapshot_api_version` can only be set at creation, never mutated. Stripe's documented procedure ([`docs.stripe.com/upgrades`](https://docs.stripe.com/upgrades)): create a new endpoint pinned to the target version, disabled; enable it so old and new endpoints both receive every event in parallel — **the handler must already be idempotent, because both destinations fire for the same event**; flip which one actually processes (return `400` on the other, which forces an automatic retry, so you can revert by flipping back); disable the old endpoint only once the new one's output checks out.

## The webhook route is the integration
**Verify the signature against the raw bytes, not the parsed body.** ([`docs.stripe.com/webhooks`](https://docs.stripe.com/webhooks)) Any framework step that re-serializes, re-orders keys, or re-encodes the body before your handler sees it breaks verification — this is a framework-wiring bug, not a Stripe one:
- Express: mount the webhook route **before** `app.use(express.json())` — middleware runs in registration order, and a global JSON parser registered first has already consumed and reshaped the body.
- Next.js Pages Router: disable the route's `bodyParser` and read the raw stream yourself.
- API Gateway + Lambda: the default integration strips the raw body — a Body Mapping Template (VTL) is required to preserve it.

**The header carries more than one signature during a secret rotation.** Format: `t=<unix ts>,v1=<hmac>,v0=<fake>`. `v0=` exists only on Stripe's own test events sent from the dashboard — ignore every scheme that isn't `v1`, or a downgrade attack verifies against the weaker one. During a signing-secret rotation both the old and new secret stay valid for up to 24h (configurable), and Stripe sends **one `v1=` per active secret** — code that assumes exactly one `v1=` value breaks mid-rotation. Default replay tolerance is 5 minutes between the header's `t=` and now; **never set tolerance to `0`** — that disables the recency check entirely rather than tightening it.

**Retries run for up to three days in live mode, with no published interval schedule** — "exponential back off" is the only shape Stripe commits to in writing; don't invent or assume a cadence (a 5-minute-then-hourly schedule some write-ups quote isn't in the docs). Sandbox retries are a fixed, much shorter window: three attempts over a few hours. A manually-triggered resend (dashboard, up to 15 days; `stripe events resend`, up to 30 days) **does not cancel the automatic retry already in flight** — the two can both succeed, so a handler has to be idempotent regardless of which path delivers the duplicate.

**No ordering guarantee, ever.** ([`docs.stripe.com/events/how-events-work`](https://docs.stripe.com/events/how-events-work)) Creating one subscription can emit `customer.subscription.created`, `invoice.created`, `invoice.paid`, `charge.created` in any order, and `created` is second-granularity — two genuinely distinct events can share a timestamp. Dedupe on `event.id`, and when a handler needs an object that might not have arrived yet (the subscription behind an early `invoice.paid`), fetch it rather than reconstruct it from event sequence.

**Return 2xx before doing the work**, then fulfill — a slow handler is a timeout, and a timeout is a retry. Subscribe only to events you handle, and log-and-ignore the rest explicitly so a silent new event type doesn't get treated as "nothing happened."

## Idempotency keys cover POST, and that's the whole surface
An `Idempotency-Key` header (SDKs: `idempotencyKey`/`idempotency_key` request option) makes a retried mutating call safe. ([`docs.stripe.com/idempotency`](https://docs.stripe.com/idempotency)) It matters only on `POST` — Stripe states `GET`/`DELETE` are idempotent by definition and a key on them has no effect. Stripe retains a key for **at least 24 hours**; no upper bound is published, so don't code a cleanup job against an assumed TTL. Reusing a key with *different* parameters is a hard error, not a silent pass-through — the layer compares params and refuses the mismatch.

**API v1 and v2 disagree about what a retry does.** v1 (the one most `stripe-node` calls use today) replays the saved first response verbatim — including a saved `500`. v2 instead retries the failed work to completion and returns an updated result. Code a retry loop for v1's behavior, and re-check this if touching a v2 integration.

## Checkout and Billing: one API call grows a five-object chain
A Checkout Session's `mode` picks the shape: `payment` (one-time), `subscription` (recurring — creates the Subscription for you), `setup` (save a payment method, charge nothing now). ([`docs.stripe.com/checkout/quickstart`](https://docs.stripe.com/checkout/quickstart)) A session is **immutable once created** — changing the order means a new session, not an update.

For recurring revenue, Stripe's own recommendation is Checkout Sessions in `subscription` mode over hand-built Billing calls: "Stripe then creates the customer, activates the subscription, and handles the payment process." ([`docs.stripe.com/billing/billing-apis`](https://docs.stripe.com/billing/billing-apis)) That one call grows a chain worth knowing the shape of: `Product` (what you sell) → `Price` (how much, how often) → `Subscription` (the customer's recurring purchase, with a `latest_invoice`) → `Invoice` (generated every billing cycle, tracks draft → paid) → `PaymentIntent` (auto-created per invoice to actually collect) → `Entitlement` (auto-granted per feature once the subscription is `active`, so access-gating doesn't need to re-walk the chain).

Two status traps: **the first-payment window is 23 hours, not 24** — a subscription left `incomplete` past it moves to `incomplete_expired` and a new subscription is required, not a retry of the old one. And **`active` doesn't prove every invoice is paid** — by default status tracks only the *most recent* invoice, so a customer with an unresolved earlier invoice can still show `active`. ([`docs.stripe.com/billing/subscriptions/overview`](https://docs.stripe.com/billing/subscriptions/overview))

## Sandboxes, not just test mode
Every account's familiar `sk_test_…` world is now formally "the test mode sandbox" — the one sandbox that always existed and can't be deleted. **General sandboxes** are a separate, newer feature: up to 5 additional, fully-isolated environments, copied from live mode at creation — the test mode sandbox doesn't count toward that limit of five. ([`docs.stripe.com/testing-use-cases`](https://docs.stripe.com/testing-use-cases)) Stripe's own instruction to agents: "use general sandboxes instead of your test mode sandbox" for a new integration, and separate sandboxes for local dev vs CI so automated runs don't disturb shared settings. ([`docs.stripe.com/sandboxes`](https://docs.stripe.com/sandboxes))

**The trap the docs put a warning banner on**: the test mode sandbox's *settings* are shared with live mode — changing a Dashboard setting while in test mode can change it in live mode too, unless a test-data banner says otherwise. General sandboxes don't have this problem; they're independently configurable from creation. This is the one place "it's just test mode" is actively wrong, not just imprecise.

## Restricted keys, and the one built for agents
Three key shapes: `pk_…` (publishable, safe to expose), `rk_…` (restricted — scoped to the permissions you grant it), `sk_…` (secret — unrestricted; Stripe now recommends migrating off it even for existing integrations). ([`docs.stripe.com/keys`](https://docs.stripe.com/keys)) Default to a restricted key per integration surface rather than one `sk_…` shared everywhere — a compromised RAK is bounded by what it was ever allowed to call.

**Agent-tagged restricted keys exist specifically for this team's shape of work**: a RAK created with the agent tag is automatically subject to approval rules, which by default gate high-risk actions (payouts, refunds, account-config changes) behind a human reviewer before they take effect. That is Stripe's stated recommended way to hand an autonomous agent Stripe access — not a bare `sk_…`, and not an untagged `rk_…` either. ([`docs.stripe.com/keys-best-practices`](https://docs.stripe.com/keys-best-practices))

Key rotation keeps the old and new key both live for up to 7 days by default (configurable down to immediate). **Access policies have replaced IP address restrictions** — the docs say to use the newer policy mechanism, not the old restriction field. A webhook signing secret (`whsec_…`) is never an API key and never rotates alongside one — it lives per-endpoint on the Webhooks tab.

## Not this skill's job
Frontend payment UI and its copy are the UI/copy seats'. Which API object to reach for on the frontend (Payment Element vs Checkout, SetupIntent vs Sources, Connect's Accounts v2) is Stripe's own per-product directive to follow, not a platform trap — it's the agent's `## Product choices` block, sourced the same way (`docs.stripe.com/llms.txt`). Usage-based billing on a new integration is Metronome's lane by Stripe's own current guidance, not Stripe's native usage meters. Server-side money math (integer minor units, zero-decimal currencies, fee/net currency denomination) and card-testing defenses are the seat's `## Money rules`, not a platform-wide trap.
