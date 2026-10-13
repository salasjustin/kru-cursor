# Writes — making a retried POST safe

A client that times out on a POST can't tell whether it landed, and a resend without an idempotency key creates the order twice. The header, its `400`/`422`/`409` cases and the replay rule are in the IETF HTTPAPI draft, revision -07, which is not an RFC ([draft](https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/)), and Stripe's implementation is a good reference ([Stripe](https://docs.stripe.com/api/idempotent_requests)). Two ways the record goes wrong in practice:

- **Store the key, the fingerprint and the response in the same transaction as the effect.** If the effect commits and the record doesn't, the retry runs the effect again. If the record commits and the effect doesn't, the retry replays a success that never happened. A failure that rolled the effect back therefore stores nothing, and the retry can succeed.
- **The "in progress" row that produces the `409` needs an expiry.** Without one, a crash mid-request blocks that key forever.
