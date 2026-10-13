# Text

Relations, except *Choosing type*, which is values craft.

## Mixed sizes on one line share a baseline

**Default it corrects:** `align-items: center` on a row holding a large title and small actions or meta, so the baselines step.
**Check:** any row with two type sizes aligns on `baseline` (or `last baseline`).

## Prose keeps its measure inside a wider column

**Default it corrects:** a paragraph stretched to the width of the image, table or card beside it.
**Rule:** body text holds about 45–75 characters per line (roughly `20em`–`35em`) even where its container is wider; content of mixed width in one column is normal.
**Check:** no paragraph on the artboard runs past ~75ch.

## Text aligns to its reading direction

**Default it corrects:** a centred block of four lines, a centred row of feature blurbs where one runs long, justified text with rivers.
**Rule:** left-align (start-align) by default. Centre only headlines and short standalone blocks, two or three lines at most — where one of a centred set runs long, shorten the copy rather than switch alignment. Numbers compared down a column are right-aligned (`ui-patterns` → `reference/lists-and-rows.md` carries the digits). Justified text always ships with `hyphens: auto`.

## A metadata line reads in one glance

**Default it corrects:** a chain of facts on one line — `author · date · 4 min · category`, or the same run joined by commas.
**Rule:** the shape is the failure, not the separator: swapping `·` for commas reads the same. Facts share a line while they read as one phrase in one glance — a byline's `author · date · 4 min read`, an issue row's `#123 · opened 3d ago by x`; past that, or where a fact doesn't join the phrase, it gets its own element, line or pill.
**Check:** every meta line on the artboard reads as one phrase at a glance.

## Line-height tracks size and measure

**Default it corrects:** one `line-height: 1.5` everywhere — loose on a 48px headline, tight on a wide paragraph.
**Rule:** line-height is inverse to size — small text needs more, a large headline can sit near `1` — and proportional to measure: a narrow column can run ~1.5, a wide one needs up toward 2 so the eye finds the next line.
**Check:** the artboard's display type has a tighter line-height than its body text.

## Choosing type

- **A scale is hand-picked, not computed.** A modular ratio produces fractional sizes and too few steps for UI; pick integer sizes by hand, packed tight at the small end and wider apart at the top. Units are `design-system`'s typography rule.
- **A neutral sans is the safe UI face**, and the system stack is the safest. Past that, prefer families with five or more weights (a sign of care), a tall x-height for small text, and nothing condensed for body UI. Popularity and the faces of sites whose typography you admire are both fair filters; a headline-only face never becomes body text.
- **The two UI weights** land at 400 or 500 for regular, by face, and 600 or 700 for emphasis.
- **Tracking stays at the face's default**, with two exceptions: tighten a headline set in a face built for small sizes, and open up all-caps text, which loses the shape variety lowercase relies on.
