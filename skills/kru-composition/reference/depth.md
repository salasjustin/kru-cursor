# Depth

Values craft. Which level a surface takes is `design-system`'s elevation rule; this is how each level is drawn.

## Light comes from above

**Default it corrects:** a symmetric glow around every raised element, which reads as floating nowhere in particular.
**Rule:** the viewer looks slightly down at the screen, and light falls from the top. A **raised** element shows a slightly lighter top edge (a top border or an inset shadow with a small downward offset, colour hand-picked — a white overlay drains saturation) and casts a small, sharp, dark shadow offset downward. An **inset** element (a well, an input, a checkbox) shows a lighter bottom lip (a bottom border or an upward-offset inset shadow) and a small dark inset shadow at its top. Borrow the cue, stop well short of realism.

## A shadow's size is its height

**Default it corrects:** shadow sizes chosen per component by eye, so a card and a dropdown sit at the same apparent height.
**Rule:** decide where the element sits on the z-axis, then take that level's shadow. Small and tight for a button, medium for a dropdown or popover, large and soft for a modal — the closer something feels, the more it pulls focus. About five levels, defined smallest and largest first, the middle filled roughly linearly.
**Interaction:** a draggable item lifts to a higher level when grabbed; a pressed button drops to a smaller shadow or none.

## A shadow has two parts, and the tight one fades with height

**Default it corrects:** one shadow per level, either too diffuse to define the edge or too dark to stay subtle.
**Rule:** pair a large soft shadow with real offset (the cast shadow) with a small tight dark one close to the edge (where ambient light can't reach). The tight one is distinct at the lowest level and nearly gone at the highest, as a lifted object loses its contact shadow.

## Flat designs still have depth

**Default it corrects:** a no-shadow direction where nothing reads as above or below anything.
**Rule:** lighter than the background reads raised, darker reads inset. A short, zero-blur, vertically offset solid shadow lifts a card or button without breaking the flat look.

## Overlap makes layers

**Default it corrects:** every element sealed inside its parent's box, so the page reads as one plane.
**Rule:** let an element straddle a boundary — a card across the seam between two backgrounds, a panel taller than its band, carousel controls over the image edge. Overlapping images keep a ring in the background colour (`media.md`).
