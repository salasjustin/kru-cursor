---
name: kru-incentives
description: "Incentives — everyone acts on their own payoff, so design for what they'll actually do, not the intended path. Load when a choice depends on someone taking the extra step, the honest route or the careful one: an ask in a flow, an abuse case, a public contract, a test's assertion."
---

Every seat already carries the principle as `## Design for what they'll actually do`; below is what it resolves to per domain.

## The four questions

1. **Who acts here?** Name every actor, the unintended ones included: the user, the attacker, the integrator, the operator — and the author. You are one: a builder is paid in *done*, a test author in *green*, a reviewer in *findings*.
2. **What does each gain, and what does it cost them?** In their currency — time, attention, money, risk — never the product's.
3. **So what will they actually do?** The intended path is one strategy among several, and each actor takes the one that pays. That choice is the equilibrium; design for it.
4. **Make the intended path the one they'd pick anyway** (incentive-compatible), **or make deviating cost more than it pays.** Where neither is available, the design runs on goodwill — name that in your return.

**Done when** each actor on the path has a named payoff and the path you ship is the one that payoff predicts.

## The index

| About to | Load |
|---|---|
| ask the user for a step, a field, a permission; choose a default | `reference/ux.md` |
| write a test, or judge whether one earns its place | `reference/testing.md` |
| weigh an abuse case or add a defense | `reference/security.md` |
| ship a surface other code depends on — an API, a webhook, an export, CLI output | `reference/api.md` |
| file or rank a review finding | `reference/review.md` |
| write a claim the reader has to believe | `reference/copy.md` |
| pick a number to optimize, gate on or report | `reference/measurement.md` |

## Across every domain

- **The intended path is a hope, not a forecast.** "Users will fill it in", "integrators will read the changelog", "the builder will run the suite" each predict someone else acting against their own payoff. Replace the hope with what the payoff predicts.
- **Your own gates are this principle applied to you.** The return pass exists because *done* is rewarded; a reviewer's reachability test exists because *findings* are. Read them as mechanisms against your own payoff, and they stop reading as ceremony.

## Owned elsewhere

- **Which paths get built at all** — Block F, `## Scope — build the real path, not every path`, in every code-writing seat: this principle's scope case. Traffic that exists is the set of actors who actually show up.
- **Rating a security finding** — `code-reviewer` → *What to hunt*, the incentive bullet (gain · incidence · precondition). `reference/security.md` is the build side of the same analysis.
- **A flow's usability defects** — `ux-principles`; the user-cost entry is `reference/choice-and-load.md` → *A required field with no payoff to the user gets fabricated answers*.
- **Card testing** — `## Money rules` on `stripe-specialist` and `paypal-specialist`, each on its provider's own guidance.
- **Proof attached to a marketing claim** — `conversion-copywriter`.
- **What an integrator's code breaks on** — `api-design`.

## Sources

Verified September 2026. Paraphrased, never quoted, except where a law is known by its wording.

- Anderson, R. (2001). *Why Information Security Is Hard — An Economic Perspective*. ACSAC 2001, 358–365 · https://doi.org/10.1109/ACSAC.2001.991552
- Anderson, R. & Moore, T. (2006). *The Economics of Information Security*. Science 314(5799), 610–613 · https://doi.org/10.1126/science.1130992
- Carroll, J. M. & Rosson, M. B. (1987). *Paradox of the Active User*. In *Interfacing Thought*, MIT Press, 80–111 · https://dl.acm.org/doi/10.5555/28446.28451
- Crawford, V. P. & Sobel, J. (1982). *Strategic Information Transmission*. Econometrica 50(6), 1431–1451 · https://doi.org/10.2307/1913390
- Goodhart, C. A. E. (1975). *Problems of Monetary Management: The U.K. Experience*. Papers in Monetary Economics I, Reserve Bank of Australia (printed 1976) · https://www.rba.gov.au/publications/rdp/1990/9013/conference-volumes.html
- Herley, C. (2009). *So Long, and No Thanks for the Externalities: The Rational Rejection of Security Advice by Users*. NSPW '09, 133–144 · https://doi.org/10.1145/1719030.1719050
- Herley, C. (2012). *Why Do Nigerian Scammers Say They Are From Nigeria?* WEIS 2012 · https://www.microsoft.com/en-us/research/publication/why-do-nigerian-scammers-say-they-are-from-nigeria/
- Holmström, B. (1982). *Moral Hazard in Teams*. Bell Journal of Economics 13(2), 324–340 · https://doi.org/10.2307/3003457
- Holmström, B. & Milgrom, P. (1991). *Multitask Principal–Agent Analyses: Incentive Contracts, Asset Ownership, and Job Design*. JLEO 7 (special issue), 24–52 · https://doi.org/10.1093/jleo/7.special_issue.24
- Hurwicz, L. (1972). *On Informationally Decentralized Systems*. In *Decision and Organization*, North-Holland, 297–336 — incentive compatibility, question 4 · https://www.semanticscholar.org/paper/87b2df19b69389c8df5f2de718c3ffa5a434fdda
- Hyrum's Law (Hyrum Wright) · https://www.hyrumslaw.com/
- Johnson, E. J. & Goldstein, D. (2003). *Do Defaults Save Lives?* Science 302(5649), 1338–1339 · https://doi.org/10.1126/science.1091721
- Kerr, S. (1975). *On the Folly of Rewarding A, While Hoping for B*. Academy of Management Journal 18(4), 769–783 · https://doi.org/10.2307/255378
- Myerson, R. B. (1979). *Incentive Compatibility and the Bargaining Problem*. Econometrica 47(1), 61–73 — the revelation principle, question 4 · https://doi.org/10.2307/1912346
- Schelling, T. C. (1960). *The Strategy of Conflict*. Harvard University Press — focal points · https://www.hup.harvard.edu/books/9780674840317
- Simon, H. A. (1956). *Rational Choice and the Structure of the Environment*. Psychological Review 63(2), 129–138 · https://doi.org/10.1037/h0042769
- Spence, M. (1973). *Job Market Signaling*. Quarterly Journal of Economics 87(3), 355–374 · https://doi.org/10.2307/1882010
- Thaler, R. H. & Sunstein, C. R. (2008). *Nudge*. Yale University Press · https://yalebooks.yale.edu/book/9780300122237/nudge/
- Twilio, *What is SMS Pumping Fraud?* · https://www.twilio.com/docs/glossary/what-is-sms-pumping-fraud
- Card testing: Stripe, *Protect yourself from card testing* · https://docs.stripe.com/disputes/prevention/card-testing — PayPal, *Stop carding attacks* · https://www.paypal.com/us/brc/article/prevent-carding-attacks-and-losses — OWASP OAT-001 Carding · https://github.com/OWASP/www-project-automated-threats-to-web-applications/blob/master/assets/oats/EN/OAT-001_Carding.md
