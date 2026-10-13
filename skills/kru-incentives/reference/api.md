# API — integrators depend on whatever they can observe

An integrator's payoff is shipping their feature and never thinking about yours again. They code against what they observe, not what you documented — with enough users, every observable behavior of a surface is depended on by somebody (Hyrum's Law). `api-design` carries the traps this produces; this file is the reason they recur.

- **Everything you emit is a contract.** Field order, an unsorted list's order, error message text, timing, an undocumented field, a status code nobody meant. Emit less: what you don't want depended on stays out of the response.
- **Make the safe path the least effort.** An integrator takes the shortest working call. An idempotency key that's optional gets skipped; an opaque cursor can't be turned into an offset; a typed error `code` gets switched on where only a message would get regex-parsed.
- **Change reaches integrators only through what they already read.** A changelog is read by the few with a reason to; an integrator hears about a change when their code breaks. Additive changes, a version on the wire, and a sunset header on the response reach them where they already look.
- **An open integration surface has an attacker among its integrators.** The rate limit, the key's scope and the webhook's signature are priced as in `security.md`.
