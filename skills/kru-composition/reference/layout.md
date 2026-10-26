# Layout

## The space around a group is larger than the space inside it

**Default it corrects:** one gap for everything — a `gap` or `space-y` on a parent whose children are themselves groups, so the label sits as close to the previous field as to its own box, and the list reads as a flat run of equals.
**Instances that recur:** a section heading equidistant from the section above and the content below (it belongs to what follows, so more space above than below); list items spaced at the text's own line-height, so a wrapped item reads as two; a meta row where the date sits as close to the next card's title as to its own; a button cluster the same distance from the field above as the buttons are from each other; card-internal padding equal to or larger than the gutter between cards. The compact form case is `ui-patterns` → `reference/forms-and-mutations.md`.
**Check:** for each node, measure the smallest gap to a sibling and the largest gap inside it. Sibling gap ≤ internal gap is the defect, horizontal and vertical alike.

## Separate with space first, then a background step, then a border

**Default it corrects:** a border on every card, a divider under every row and an outline on the panel holding them — separation drawn three times, so the lines out-shout the content. Or a background change *and* a border on the same edge, when either alone separates.
**Rule:** more space is the cheapest separator and adds no UI. Next, a background one step apart. Next, a shadow on a surface that already differs from the page. A border comes last.
**Check:** every border on the artboard does a job neither spacing nor a background step already does. Where two separators stack on one edge, cut one.

## A container matches the group it contains

**Default it corrects:** a card drawn around a layout slot rather than a unit of meaning — related items split across two cards, or unrelated ones sharing one because they happened to sit side by side.
**Check:** each surface on the artboard maps to one node of the pass's tree.

## An element takes the width its content needs

**Default it corrects:** a login card at six grid columns, a settings form stretched across a 1400px canvas, a sidebar sized as a percentage that grows on wide screens and cramps on narrow ones.
**Rule:** give a component a `max-width` and let it shrink only once the viewport is narrower than that; fixed-width sidebars sized to their contents, a fluid main area with its own inner layout. A narrow thing that looks lost in a wide layout is split into columns (the supporting text beside the form), never stretched. Each section sizes to its own content, whatever width the nav spans; where a section genuinely needs the room, it takes it.
**Check:** at the widest artboard, no form, card or text block is wider than its content needs, and no element sized in percentages gets *narrower* as the viewport widens past a breakpoint.

## The primary audience's frame is drawn first

**Default it corrects:** a wide layout drawn on a 1440 canvas and squeezed afterwards, so every narrow compromise is a patch.
**Rule:** draw the frame the primary audience uses first — the ~400px frame for a public or consumer surface, the wide one for a desktop-first internal tool or a dense ops dashboard — then move to the other end and change only what felt compromised, before the canvas publishes.

## Density is a decision, and roomy is the default

**Default it corrects:** space added only until nothing looks broken, which leaves every gap at the minimum.
**Rule:** start a step roomier than feels right and take space away — what looks generous on one element reads as enough in a full screen. Pack tight only where the job is seeing many things at once (a dashboard, a table), and say so in the artboard notes.
**Check:** a dense artboard names its reason; any other artboard has room to lose a step before it looks cramped.

## Narrow viewports compress large things faster than small ones

**Default it corrects:** a heading-to-body ratio carried unchanged from desktop, so the phone headline is enormous; or padding defined relative to font size, so a small button looks zoomed out rather than small.
**Rule:** sizes scale independently. Display type steps down further than body type does on a narrow frame; a large control gets disproportionately more padding and a small one disproportionately less.
**Check:** the narrow artboard's display sizes step down further than its body size does.

## A fixed length inside a height-capped container is checked at its shortest height

**Default it corrects:** a floor or band authored against a tall region and spent in a short one — a `min-height` on a flex child in a sheet capped at `80svh`, an edge fade whose depth is a fixed token.
**Rule:** state each fixed length against what it must not swallow, and say what happens when the room isn't there. A floor on a flex child beats `flex: 1`, so the column overflows its cap and the child paints outside the clip, under whatever follows it: gate the floor behind a `min-height` query, or let the child shrink. A fade sized as a constant can cover the whole first row past the fold in a short scrollport, so the row reads unreachable while one drag away: size it against the row, narrow it where a media query already admits the cap, and buy room back before dropping the fade — it's the only cue that more lies past the edge.
**Check:** phone landscape and 200% zoom, where the cap is shortest — 200% zoom makes this a reflow failure, not a landscape edge case.

## The side margins are one pair, and the nav sits on them

**Default it corrects:** a header on one inset and the page on another (40px against 20px), a section nudged to one side, a bleed that drags the margin with it.
**Rule:** the left and right margins match at every width, and the navigation shares them with the content. On 97 recent Awwwards Sites of the Day the two sides agree to a few pixels, and no strong page sits off-centre (taste-skill v2.1's study). A bleed is deliberate and starts from a margin: a row running off the right edge begins on the left one. Asymmetry lives inside the frame: an off-centre anchor line on symmetric margins.
**Check:** at every artboard width, the left and right content edges of the nav and of every section measure equal.

## Empty space is closed by something, or it is a hole

**Default it corrects:** the blank stretches readers name first when a page looks wrong — text in one half of a section and plain ground in the other, a gap between sections stretched to most of a screen, a footer or a lone heading padded to `100vh`, a row of pictures of different heights top-aligned over a hole, a screen of bare ground while a reveal waits to fire.
**Rule:** every large empty area names what closes it: a picture with the type docked at its edge, a picture at the far side of the band, type large enough to span it, a step in ground tone. If nothing does, move the section's picture into it, make the main element larger, or take the space out. When text takes one half, the other holds the section's picture, a second column, a list or a figure; in the same study about one text section in a hundred leaves half the width empty. A section is sized to its content, and full-screen height belongs only to one that fills the screen. Content is in place on the first paint; an entrance moves what is already there.
**Check:** no stretch taller than about half a screen holds nothing, no section leaves half its width to plain ground, and the first frame of every screen shows its words.
