---
name: kru-oss-prose
description: README and CONTRIBUTING for an open-source repo, split by reader — README for people using the product, CONTRIBUTING for people changing it. Use when writing, restructuring or reviewing either file. Wording inside them is `doc-fix`'s.
---

Two readers, two files, and every section serves exactly one of them. The default this corrects: one README that opens on clone-and-install, mixes dev scripts with the API, buries the hosted URL, and walks the code's structure in prose — so the user wades through contributor setup, and the contributor hunts for setup between endpoint tables.

## README — someone using the product
The sections that apply, in this order:
1. **What it does** — one paragraph, for someone deciding whether it's for them.
2. **Where to use it** — the hosted URL first. Self-hosting comes after, as a pointer to CONTRIBUTING's setup.
3. **The surface** — each endpoint or command with one real request and its response; auth and rate limits; the errors a caller meets and what each means; where the data comes from and how fresh it is.

Done when a user can make a first successful call from the README alone.

## CONTRIBUTING — someone changing it
Setup, in the order they'll do it: prerequisites with versions, install, the checks the gate runs, running it locally, where local keys and test data come from, and deploy as a pointer to the workflow or deploy doc.

Done when a fresh clone gets to green checks and a running local copy from CONTRIBUTING alone.

## Placement
- **One reader per section.** Local setup found in the README moves to CONTRIBUTING; API reference found in CONTRIBUTING moves to the README.
- **Point at what the code already documents.** A config file, a schema, `--help`, a commented module: name the file. Architecture tours and design rationale live in the code's comments or an ADR (`domain-modeling`).
