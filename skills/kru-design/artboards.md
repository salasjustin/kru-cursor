# `.dc.html` artboard file format

Canonical spec for local design artboards. Every rule here is what a builder transcribes from; values stay literals in the file.

## Layout on disk

```
.design-work/
  index.html            plain list of links, one per artboard, with its one-line label
  direction-a.dc.html   one direction, the whole screen, at one viewport
  direction-b.dc.html
```

- Put files under `.design-work/` unless the repo already has a design-work path.
- **`.dc.html` for an artboard**, plain `.html` for the index.
- **Gitignored** — build inputs, not the system. Mark paths **uncommitted** in the return.
- **Absolute paths** in the return to the PM.

## Document skeleton (every `.dc.html`)

Each artboard is one valid HTML5 document, self-contained except for optional font hosts.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=1440">
  <title>Direction name — one-line thesis</title>
  <!-- optional: <link rel="stylesheet" href="https://fonts.googleapis.com/..."> -->
  <style>
    /* every rule here; literal values only — no var(), no @import */
  </style>
</head>
<body>
  <p class="dc-label">Direction name — one-line thesis</p>
  <div class="dc-artboard" data-viewport="1440">
    <!-- the screen at this viewport -->
  </div>
  <!-- optional: more .dc-artboard blocks for named states, each preceded by a small state label -->
</body>
</html>
```

- **`data-viewport`** on `.dc-artboard` matches the stated width: `1440` for desktop, `375` for mobile. One viewport per file; a direction that needs both is two files.
- **`<meta name="viewport">`** uses `width=<N>` for that same number (not `device-width`).
- **`.dc-label`** is visible in the file: the direction name and its one-line thesis (same text as the `<title>`).
- **No scripts.** No build step, no framework runtime, no external CSS except a font `<link>`.

## Styling rules

- **Inline everything** in a single `<style>` block (or minimal extra blocks in the same file). Every color, spacing, type size, and radius is a literal.
- **No design-system token file** in the artboard — the token file is the builder's job after approval.
- **Web-safe faces, or one `<link>` to a font host** — those are the only outside loads. Icons are inline SVG or a data URL unless the repo's approved spec names a hosted set.
- **Match the repo first** — token file, stylesheets, closest screen, icon set — and say in one line what you matched in the handoff.

## Content rules

- **Real content** from the build spec (or `kru-conversion-copywriter`'s SECTION deck on marketing pages). Placeholder lorem hides the decision.
- **The states the screen has**, stacked under small labels, where the brief names them (each state can be its own `.dc-artboard` block in the same file).
- **Directions differ.** 2–4 at bootstrap. Three palettes of the same layout is one direction. State each thesis in one line.
- **Re-draft from the files that are there.** The PM's pick is the base. Two rounds is normal. A third means the brief is what's wrong.

## `index.html`

A plain HTML page listing every `.dc.html` in the folder: one link per artboard, link text = direction name + one-line label. No canvas, no publish step — navigation only.
