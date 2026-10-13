# Color

Values craft. The ramp *shape* (how many steps, what each is for) is `design-system`'s.

## Author in a space the eye reads

**Default it corrects:** picking and adjusting colours in hex or RGB, where two near-identical colours share no visible digits and a "lighter" version is a guess.
**Rule:** work in hue, chroma and lightness. Prefer `oklch()` over `hsl()`: HSL's lightness isn't perceptual — a yellow and a blue at the same HSL lightness read wildly different — so an HSL ramp needs the hue and saturation corrections below by eye, while OKLCH's `L` already tracks what the eye sees. Safety and fallbacks are `modern-css`'s.

## The palette is larger than five swatches

**Default it corrects:** a generator's five harmonious colours, with nothing to build greys, tints, text colours or states from.
**Rule:** three families. **Greys** — most of the UI; 8–10 steps from a very dark near-black (true black looks unnatural) to an off-white. **Primary** — one or two hues, 5–10 steps each: the palest tints an alert background, the darkest carries text. **Accents** — a highlight for something new, plus one hue per state the copy distinguishes (destructive, warning, positive), each with a few steps; more where colour categorises (calendar events, tags). A complex UI can reach ten hues.

## Shades are defined up front, from the edges in

**Default it corrects:** `lighten()`, `darken()` or a one-off `color-mix()` at the point of use, until there are 35 near-identical blues.
**Rule:** pick the base first — for a hue, the shade that works as a button fill. Then the edges: the darkest (for text) and lightest (for tinted backgrounds), both judged inside a real alert. Then fill the midpoints between them, then the midpoints between those. Adjust by eye once the ramp is in use, and add a shade rarely.

## Chroma rises toward the ends of a ramp

**Default it corrects:** one saturation across the ramp, so the lightest tints and darkest shades look washed out or muddy.
**Rule:** raise saturation as a step moves away from the middle lightness. In HSL this is a manual correction on every end step; in OKLCH, hold chroma up toward the gamut edge at the extremes.

## Hue shifts are a brightness lever

**Default it corrects:** darkening yellow by lightness alone, until it turns brown.
**Rule:** hues differ in inherent brightness — yellow, cyan and magenta read light; red, green and blue read dark. To lighten a step, rotate slightly toward the nearest bright hue; to darken, toward the nearest dark one. Stay within ~20–30° or it reads as a different colour. A yellow ramp shifted toward orange as it darkens stays warm and rich.

## Greys carry a temperature

**Default it corrects:** zero-saturation greys that sit oddly against a warm or cool brand.
**Rule:** tint greys slightly — blue for cool, yellow or orange for warm — and raise the tint at the ramp's ends, as with any hue, so the temperature holds across it.

## Colour stays legible without shouting

**Default it corrects:** white text on a colour darkened until it is legible, which then out-shouts the page; secondary text on a dark coloured panel pushed toward white until it matches the primary text.
**Rule:** flip it — dark text of the hue on a pale tint of it keeps the colour and quiets the element. For secondary text on a coloured surface, take a colour from that surface's own ramp, and gain brightness by rotating toward a bright hue rather than toward white.
