# `.dc.html` artboard file format

## Layout on disk

```
.design-work/
  index.html
  direction-a-1440.dc.html     bootstrap direction at one viewport
  direction-a-375.dc.html
  checkout-empty-1440.dc.html  settled mockup set
```

**Naming**

- Bootstrap directions: `direction-<slug>-<viewport>.dc.html` (for example `direction-a-1440.dc.html`, `direction-a-375.dc.html`).
- Settled mockup set: `<screen>-<state>-<viewport>.dc.html` (for example `checkout-empty-1440.dc.html`, `checkout-error-375.dc.html`).

Put files under `.design-work/` unless the repo already has a design-work path. Add `.design-work/` to `.gitignore` if it is not ignored already, and mark paths **uncommitted** in the return. Use `.dc.html` for an artboard and plain `.html` for the index. Return **absolute paths** to the PM.

## Document skeleton (every `.dc.html`)

Each artboard is one valid HTML5 document.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=1440">
  <title>Direction name — one-line thesis</title>
  <!-- optional: <link rel="stylesheet" href="https://fonts.googleapis.com/..."> -->
  <style>
    .dc-artboard[data-viewport="1440"] { width: 1440px; }
    /* every other rule: literal values only */
  </style>
</head>
<body>
  <p class="dc-label">Direction name — one-line thesis</p>
  <div class="dc-artboard" data-viewport="1440">
    <!-- the screen at this viewport -->
  </div>
</body>
</html>
```

- Set `data-viewport` on `.dc-artboard` to `1440` for desktop or `375` for mobile. One viewport per file; a direction that needs both is two files.
- Set `<meta name="viewport" content="width=<N>">` to the same `N` as `data-viewport`.
- Give `.dc-artboard` an explicit `width` in CSS that matches `data-viewport`.
- Put the direction or screen name and one-line thesis in `.dc-label` and in `<title>`.

## Styling and loads

Values in the file are literals.

- Write every value as a literal in the one `<style>` block in `<head>`.
- Use web-safe faces, or add a single font `<link>` in `<head>`.
- Reference repo images with relative paths from the artboard file.
- After the PM approves a direction, a builder transcribes literals into the repo token file once.

## Content in each artboard

- Use copy from the build spec (or `kru-conversion-copywriter`'s SECTION deck on marketing pages). Include a plausible long string in the field that will overflow.
- Where the brief names screen states, stack them under small labels in the file (separate `.dc-artboard` blocks or clearly labelled sections): **empty**, **one row**, **many**, **error**, **loading**, **disabled**.
- Keep interaction **static** by default. Show **hover** and **focus** as a labelled second copy of the element beside the default state.
- Each file renders at its one width. Breakpoint behaviour is the builder's job.

## PNG exports

Capture each `.dc-artboard` at its `data-viewport` width as a full-height PNG named after its `.dc.html` file (for example `direction-a-1440.png` beside `direction-a-1440.dc.html`). These are the **1440** and **375** approved-mockup exports that *Canvas vs approved mockups* in `skills/kru-design/SKILL.md` requires.

## `index.html`

A plain HTML page with one link per `.dc.html`. Link text is the direction or screen name plus its one-line label. Navigation only.
