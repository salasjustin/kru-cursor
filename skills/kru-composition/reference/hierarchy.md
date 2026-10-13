# Hierarchy

## Hierarchy survives grayscale

**Default it corrects:** colour doing the ranking — the primary is the blue one, the warning is the red one — so the screen has no order once colour is removed, or for a reader who can't tell the hues apart.
**Rule:** rank with space, size, weight and contrast first; colour then reinforces an order that already exists.
**Check:** desaturate the artboard. The reading order from the pass's step 3 is still the order the eye takes.

## At most one primary action per view; the rest step down

**Default it corrects:** every button drawn at the same solid emphasis, or a destructive action given the loudest style on a page where it is not the main task.
**Rule:** primary — the solid, highest-emphasis treatment, on the one action the eye should find first; with no dominant action, nothing is primary. The count and its zero case are `ux-principles` → *One action wears the primary style per screen*. Secondary — clear but quieter (the system's outline or low-emphasis variant). Tertiary — link-weight, discoverable, unobtrusive. A destructive action off the main path takes a secondary or tertiary treatment; it becomes primary inside the confirm that asks about it.
**Check:** count distinct actions styled primary per view; the answer is at most one. One action repeated per item — *Add to cart* on every card, *Choose* per pricing tier — counts once.

## Text emphasis spends ink and weight before size

**Default it corrects:** hierarchy carried by font size alone — the heading huge, the metadata too small to read.
**Rule:** text takes one of two or three inks (primary · secondary · tertiary) and one of two weights (regular · emphasis). A bolder primary line can sit at a sensible size; a secondary line is quieter by ink, not shrunk. On a coloured surface the quieter ink comes from that surface's own ramp — the page's grey reads muddy there. Below-regular weights are for large display type only; to quiet small text, lower its ink.
**Check:** the artboard's emphasis comes from a small fixed set of inks and weights — the system's set where one exists, else at most three inks and two weights — and no line is smaller than the scale's small step to look secondary.

## Emphasis comes from quieting the competitors

**Default it corrects:** making the target louder — bigger, brighter, another colour — when it fails to stand out, until everything shouts.
**Rule:** when the important thing still doesn't lead, lower the ink or weight of what competes with it — inactive nav items, a sidebar's own background (let it sit on the page instead).
**Check:** squint at the artboard or blur the screenshot: the element named first in the pass's step 3 is the first thing that surfaces.

## Weight and contrast trade against each other

**Default it corrects:** a solid icon at full ink beside text (it covers more area than letters, so it reads louder than the words it labels); a hairline border that vanishes in a soft colour and turns harsh when darkened.
**Rule:** a heavy element takes a quieter ink; a faint element gains weight instead of contrast — the border goes a pixel wider rather than darker.

## A heading's size follows its job, not its tag

**Default it corrects:** an `h1` "Settings" or an `h2` "Billing" drawn at display size because of its level, when in an app screen it acts as a label and the content below is the point.
**Rule:** choose the tag for the outline and the size for the rank. Where the content names itself, the title can stay in the markup and leave the screen visually.
**Check:** a section title is never the loudest thing in its section unless reading it is the task.

## Displayed data is labelled only where format and context can't label it

**Default it corrects:** a `Label: value` grid for every field, giving the label and the value equal weight so nothing leads.
**Rule:** an email, a price, a date or a phone number labels itself; context labels the rest ("Customer Support" under a name is a department). Next, fold the label into the value ("12 left in stock", "3 bedrooms"). Where a label stays — a dashboard of like figures — it takes the quieter ink and the value leads. The inverse holds where readers scan for the label (a spec sheet): the label leads, the value one ink step behind.
**Check:** every visible label earns its place against those three steps. The ledger's grid mechanics are `ui-patterns` → `reference/lists-and-rows.md`.

## A link is as loud as its place on the path

**Default it corrects:** every link in a link-dense UI (nav, tables, cards) drawn in the accent colour, until the page is a field of blue.
**Rule:** a link inside running prose is marked as a link. Where nearly everything is clickable, a link takes weight or a darker ink instead of colour; an ancillary link off the main path can stay unmarked until hover.

## Colour never carries meaning alone

**Default it corrects:** a trend shown only as green up / red down, a status shown only as a dot's hue, chart series told apart only by hue.
**Rule:** pair the colour with an icon, a word or a shape; for series, vary lightness as well as hue so the difference holds without colour vision. Chart craft is `dataviz`'s.

## An empty state is a first screen, drawn as one

**Default it corrects:** the populated screen drawn with care and the empty one left as a bare list header over nothing — the screen a new user sees first.
**Rule:** the action that fills the screen is the view's primary; an illustration or image can carry the space. Tabs, filters, sort and bulk controls that do nothing with zero items are hidden until there are items. Which words it carries is `ui-patterns` → `reference/text-and-icons.md`.
**Check:** every list or collection in the inventory has an empty-state artboard, and its only primary is the action that ends the emptiness.
