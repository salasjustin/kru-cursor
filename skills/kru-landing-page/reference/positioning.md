# positioning — from competitive alternatives to the headline on the page

<!-- The five components, their nuances and the traps are adapted from `jgerton/brand-toolkit`
     (MIT), `references/frameworks/dunford-positioning.md`, which condenses April Dunford,
     *Obviously Awesome* (2019). Dropped: the cross-functional workshop format, which assumes a
     room of humans and hours this seat does not have, and its `brand-brief.md` pipeline, which
     this repo has no equivalent of. Added: *Cutting the headline* and the two tests, which the
     source does not carry. -->

Positioning is context-setting — the frame that makes a product's value obvious to the people who care most about it. Good positioning sets off assumptions that are true; bad positioning sets off assumptions that are false, and every claim further down the page is then spent undoing them.

## The order is the method

The five components are interdependent and the flow **must start with competitive alternatives**. Each one downstream is defined relative to them: unique attributes are unique *against the alternatives*, value is value *relative to what they'd otherwise get*, and the category is the frame in which that difference reads. Start anywhere else — from the product, from the category you want to be in — and you get a description of what you have rather than what you have *that matters*. It sounds right internally, because internally everyone already knows the product, and it fails with customers, who don't.

### 1. Competitive alternatives — what they'd do if this didn't exist

Not a list of every possible competitor: what customers **actually consider or currently do**.

- **"Do nothing" is an alternative, and usually the largest one** — the spreadsheet, the manual process, the intern, the status quo that is already working badly enough to live with. In enterprise software roughly a quarter of deals are lost to *no decision*, which means the status quo wins more often than any named vendor.
- **The phantom-competitor trap**: a company that theoretically competes and that you have never actually lost a deal to. Position against a phantom and the entire page answers an objection nobody holds, while the real alternative — the spreadsheet — goes unaddressed. The test is whether a deal was lost to it, not whether the two products overlap on a feature grid.
- By business type: software, a manual process, a spreadsheet, or hiring someone (SaaS) · DIY, a different kind of provider, or ignoring it (local service) · other creators, free content, books (content) · direct competitors, Amazon, homemade, going without (ecommerce).

### 2. Unique attributes — what you have that they do not

Exhaustive and unjudged: features, business model, pricing model, delivery method, supply chain, proprietary process, IP, partnerships, community, expertise. Value is assessed in the next step, so nothing is filtered here — an attribute that looks like a liability (complexity, narrowness, price) is differentiating in the right frame.

### 3. Value — so what?

For each attribute: what does it let the customer **do** that the alternatives don't? Value can come from a combination of attributes, not only from single ones.

**Every value claim traces back to a named attribute.** One that can't is generic — it is a claim any alternative could also make, and it will fail the swap test below.

### 4. Best-fit customers — who cares a lot

Many prospects care somewhat; the position is built for the ones who care **a lot** — they understand the value fast, buy faster, and don't ask for discounts. Specify beyond demographics: the situation, trigger, or pain that makes them care. *Small businesses* is not a best-fit customer; *a two-person finance team that just failed an audit* is.

### 5. Market category — the frame

The context that makes the value obvious. Declaring a category makes the customer assume a set of competitors, a feature baseline, and a price range — so the test is whether the category makes the differentiated value **obvious** or buries it.

Three styles: **head-to-head** (take the leader in an existing category; needs clear differentiators) · **niche** (own a subsegment — the default for a startup) · **new category** (invent the frame; the most expensive and the highest variance). The great majority of tech companies that reached an IPO positioned inside existing markets rather than inventing one, and a niche of an existing category beats a new category for almost everyone.

## The five are facts, not judgments

Each component is a claim about a market this seat cannot observe. Supplied — in the brief, a product-marketing file, research — use it. Derivable from the repo or the product itself (what it integrates with, who it authenticates, what it charges for) — use it and state the derivation. Otherwise it is a **named gap**, and the largest one is competitive alternatives: a page positioned against an invented alternative is worse than a page that admits it doesn't know what it is beating.

## Cutting the headline

The step the source stops short of. Each component has a place on the page:

| component | where it lands |
|---|---|
| **market category** | the frame — the noun the reader files the product under. In the headline, or carried by the subhead, or (level 4–5) replaced by mechanism or identification |
| **unique attribute** | the differentiating clause — the *without X* / *that Y* half |
| **value** | the outcome — the verb and object the headline promises |
| **best-fit customer** | the qualifier, *for <who>*, used when the category alone doesn't qualify the reader |
| **competitive alternative** | what the headline has to beat. Named explicitly in the subhead or a comparison section; rarely in the headline itself |

**The headline carries one component as its subject and at most one as a modifier. The subhead carries the rest.** Which one leads is set by the sophistication level from `selector.md`, not by taste:

- **level 1–2** → value leads. The outcome is the news.
- **level 3–4** → the unique attribute leads. The mechanism is what makes a worn-out claim credible again.
- **level 5** → the best-fit customer leads. Identification is the only thing still being read.

Only then pick a formula, from `${CURSOR_PLUGIN_ROOT}/skills/kru-copywriting/references/copy-frameworks.md` → *Headline Formulas* — the formula that fits the lead already settled, never a formula chosen first and filled in after.

## Two tests before the headline leaves

- **Swap test.** Put the strongest competitor's name in it. Still true → it carries no position, only category-generic value, and any of the alternatives could run it tomorrow.
- **Category test.** A reader who has never heard of this product: does the headline plus subhead tell them what *kind* of thing it is? If not, they have nothing to file it under, and every claim below lands on nothing.

Symptoms that the position, not the copy, is what's broken: *"so what exactly is this?"* → the category is wrong or missing · constant comparison to competitors you don't consider competitors → the category frame is wrong · they love the demo and don't buy → the value isn't connected to their specific pain · heavy discounting to close → the page is reaching people who don't value what it does.
