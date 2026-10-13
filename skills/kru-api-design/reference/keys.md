# API keys — minting, storing, checking

## The format
`<prefix>_<id>_<secret>`. The id half is used for an indexed lookup. The secret half is compared in constant time. The prefix makes a leaked key recognisable.

- **The secret's alphabet must not contain the separator.** Base64url contains both `_` and `-`. Measured over 100,000 keys of 32 random bytes each: **48% contain `_` and 48% contain `-`**. So `key.split("_")` returns four or more parts for about half of all keys, and the check refuses a valid key or reads the wrong half. `-` also stops a double-click from selecting the whole key. Encode the secret in base62 or hex. Or give the id a fixed length and parse by position, never by splitting. GitHub picked `_` because it isn't a base64 character and because double-click selects the whole token. That holds for standard base64 only: base64url, the usual encoding for tokens, uses `_` itself. ([GitHub, token formats](https://github.blog/engineering/platform-security/behind-githubs-new-authentication-token-formats/))
- **The prefix is for scanners.** A distinct prefix, high-entropy randomness and a 32-bit checksum are what GitHub's secret-scanning program asks for. The checksum lets a scanner reject random matches offline, without a database. ([GitHub, partner program](https://docs.github.com/en/code-security/secret-scanning/secret-scanning-partnership-program/secret-scanning-partner-program)) The partner program needs one verification endpoint per vendor. A product that mints keys per deployment has no such endpoint, so there the prefix and checksum serve custom patterns and a plain grep.

## Storage and the check
- **Store SHA-256 of the secret half, not bcrypt or argon2.** NIST requires a password-hashing scheme only for random secrets shorter than 112 bits; above that, an approved hash is enough ([SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html), look-up secrets; an API key applies by analogy). A slow hash on every request only turns a burst of requests into a CPU denial of service against yourself.
- **Look up by the id half, then compare digests in constant time.** Looking a key up by its secret is a table scan plus a timing oracle. Compare the two digests, not the raw strings: digests are always the same length, and a constant-time compare can throw on inputs of different lengths (Node's does). Use the repo's constant-time compare where it has one, and the runtime's where it doesn't.
- **"Id found, secret wrong" returns exactly the same refusal as "no such key."** A different answer tells a caller which ids exist.
- **Put the rate limit in front of the lookup, keyed by client IP.** Every guess costs a database read, so an unauthenticated bucket is what caps the cost of guessing. A per-key quota comes after authentication and is a separate limit.
- **Record usage by the day, not the request.** Write `last_used_on` only when the stored date isn't today. Writing a timestamp on every request turns every read into a write.

## Scopes
- **Each route declares its scope as data the gate reads**, not as an `if` inside the handler. Add a spec that lists every route under the prefix and asserts each one declares a scope. A new route without one is either open to every key or closed to all of them, and nothing else will notice.
- **Scope names come from one registry constant**, and minting a key refuses any name not in it. A typo stored in a scope list grants nothing and gives no error.

## Revocation
- **A revoked key stops working on its next request.** Caching the key lookup (in KV or an in-memory map with a TTL) keeps a revoked key working until the TTL runs out, and that's the window in which a leaked key is being used. If the lookup has to be cached, revocation evicts the entry. The cache is never the source of truth.
