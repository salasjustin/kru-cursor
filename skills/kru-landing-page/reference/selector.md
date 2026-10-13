# selector — placing the visitor, and what that settles

The two axes of `SKILL.md` → *1. Place the visitor*, in full. Both are Eugene Schwartz, *Breakthrough Advertising* (1966); the stage names and the five sophistication levels are his, the mapping onto this repo's templates is not.

Read only the row you placed.

## Awareness — where the page starts and how far it travels

| stage | what the reader already grants | the hero's job | still to travel | template |
|---|---|---|---|---|
| **unaware** | nothing — not even that the problem is a problem | name the situation as their own experience, in their words, before any product noun appears | the problem is real → it is costly → it is solvable → this category → this product → proof | **none of the five.** A landing page is the wrong surface: unaware traffic converts through an article or story lead that reaches the product past the fold |
| **problem-aware** | the pain; not that anything fixes it | the pain named more precisely than they could name it, and the assertion that it is solvable | a solution category exists → this one → this product → proof → risk | Enterprise/B2B Landing Page, or the Varied Engaging Page at full length |
| **solution-aware** | that solutions exist; they are comparing *kinds* | the mechanism — what this does differently from the other kinds — not the pain, which they have already felt | why this kind → why this one → proof → risk | Varied Engaging Page |
| **product-aware** | this product exists; unconvinced it is the one | the differentiator plus the objection that has them stalled | objections and risk only | Compact Landing Page, plus comparison and FAQ |
| **most-aware** | the product and the value; they want the terms | the offer — price, what is included, what happens after the click | nothing | Compact Landing Page stripped to hero · one proof · CTA. Product Launch Page when there is an announcement to carry |

The **Feature-Heavy Page** the source marks *Weak* maps to no stage. It is the shape a deck takes when no stage was placed.

## Sophistication — what the headline has to do

How many times this market has heard a claim like this one. It moves in one direction and never back.

| level | the market | the headline leads with | the failure at this level |
|---|---|---|---|
| **1** | first credible claim of its kind | the claim, stated plainly | over-writing — dressing a claim that needed no dressing |
| **2** | the claim has been made and believed | the same claim, outbid: bigger, faster, more specific | matching the incumbent's claim instead of beating it, which reads as a copy |
| **3** | the claim is worn out; it is disbelieved | the **mechanism** — how it works, which is what makes the claim credible again | repeating the claim louder into a market that has stopped hearing it |
| **4** | mechanisms are now competing | this mechanism's advantage over the other mechanisms | describing a mechanism as if it were new |
| **5** | everything is disbelieved, including mechanisms | **identification** — who this is for, who built it, and why they would know | any claim at all in the hero; it is read as noise before it is read as content |

Unsupplied and underivable: default **3** in an established category, **1** where the buyer has no noun for the category yet. Guessing a level low is the expensive direction — a plain claim into a level-4 market is invisible, while a mechanism-led headline in a level-2 market merely reads as thorough.

## The two axes are independent

Awareness sets the page's **start and length**. Sophistication sets the **hero's lead**. A most-aware visitor in a level-5 market still needs identification in the hero and still needs nothing below it. A problem-aware visitor in a level-1 market gets the long page with the plainest possible headline on top of it.

## The mixed-awareness page

A page reachable from site navigation — a homepage, a top-level product page — has no single stage, and it does not get the average of them. It **qualifies in the hero at the widest stage it serves**, then branches: a self-identification section (`Built for…`, use-case blocks) sends each visitor to the depth they need, and the deeper material sits behind those links rather than in the scroll.

The tell that a page was averaged: a hero that assumes the problem is felt *and* explains what the category is.

## When nothing places the visitor

Return the placement as a gap and keep the deck. The gap names the assumption and what would settle it:

```yaml
gaps:
  - field: placement.awareness
    assumed: solution-aware
    need: "the traffic source — ad copy, campaign, or the page that links here"
    effect: "a problem-aware audience would need two sections above the current hero"
```
