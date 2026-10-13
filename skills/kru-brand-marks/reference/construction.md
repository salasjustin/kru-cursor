# The construction board

One board per kit that shows how the master is built. It explains the finished mark as drawn. A wordmark-only kit skips the board, and the handoff says why in one line.

## Measure, don't recall
Read the geometry from the master's path, not from what you meant to draw: use a scratch script that parses the `d` attribute.
- Bounding box, centre, and any mirror or rotational symmetry, with how far off it is.
- Circles: sample each curved segment, fit a circle by least squares, and record the centre, the radius, the residual and any tangency to the box or an edge.
- Edge angles, repeated radii or module sizes, and equal ratios between parts.
- The anchors that matter: arc ends, tangent points, centres.

When a relation fits only approximately, or holds only because of a correction made by eye, draw the real shape and name it in the handoff.

## Draw
- **Pick the strongest relationships**, mixing the kinds the mark actually has: circles and arcs, axes, extended edges, the module. About 25–35 guides. Drop anything decorative or redundant, and any guide that nearly coincides with an edge or another guide, because a near-miss reads as a mistake.
- **No text of any kind**: no labels, numbers, dimensions, ticks or captions.
- **Near-white field, neutral grays only**, with no colour or effects.
- **Three tiers that read at a glance**: primary solid and dark, secondary dashed and mid-dark, auxiliary thin solid or dotted in mid gray. If a tier is barely visible on the render, darken or thicken it.
- **Small hollow nodes** at key anchors, a centre marker, and small squares at the bounding-box corners.
- **The logo stays the hero**: a copy of the master path with a flat fill of about 10% black and a dark outline. The master file stays as it is.
- **Breathing room**: 16:9, the mark about 40–45% of the board's height and centred, guides running only a short, even distance past the mark.
- **SVG layers**, as `<g id>` from bottom to top: `auxiliary`, `secondary`, `primary`, `logo`, `anchors`.

## Prove it
Render the board to PNG and read it. Check that nothing runs off the board, that arcs sit on the logo's edges, that the tiers are distinct, and that the logo still leads. Fix what you find and render once more. The board lands beside the master as `brand/construction.svg` + `.png`.
