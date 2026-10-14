---
name: kru-design
description: Draft .dc.html artboards and publish them with Cursor's /canvas so the PM can settle a look. Use when a look is unsettled — 2-4 directions at bootstrap, screen mockups after, or a re-draft after the PM's verdict. The local files are the surface when /canvas is not available.
---

The artboard and publish mechanics `ui-designer` draws on. The look is decided on the canvas. The verdict is the PM's. Practice: `${CURSOR_PLUGIN_ROOT}/references/ui-practice.md` → *The canvas*.

## Draft the files first

Always draft self-contained `.dc.html` artboards. They are the re-seed and the transcription spec, and they are the whole return when `/canvas` is not available. The file format follows kru-opencode's kru-artboards skill for the local files only.

```
.design-work/
  index.html            a plain list of links, one per artboard, with its one-line label
  direction-a.dc.html   one direction, the whole screen, at one viewport
  direction-b.dc.html
```

- **Gitignored.** Build inputs, not the system. Put them under `.design-work/` unless the repo already has a design-work path, and say **uncommitted** in the return.
- **`.dc.html` for an artboard**, plain `.html` for the index.
- **Absolute paths in the return.**
- **Inline everything.** A `<style>` block, values as literals. Every value is a literal. The token file is a builder's to write, once.
- **One viewport per file, stated.** 1280 for desktop, 375 for mobile. A direction that only makes sense at both is two files.
- **Real content.** The copy `ux-designer` wrote. Placeholder text hides the decision.
- **The states the screen has**, stacked under small labels, where the brief names them.
- **Web-safe faces, or a `<link>` to a font host.** Those are the file's outside loads. Everything else is local.
- **Label every artboard in the file** — the direction's name and its one-line thesis.
- **Match the repo first** and say in one line what you matched: the token file, the stylesheets, the closest screen, the icon set.
- **Directions differ.** 2–4 at bootstrap. Three palettes of the same layout is one direction. State each thesis in one line.
- **Re-draft from the files that are there.** The PM's pick is the base. Two rounds is normal. A third means the brief is what's wrong.

## Publish with `/canvas`

When `/canvas` is available, publish the directions as one live canvas the PM compares beside the chat. Invoke Cursor's built-in `/canvas` ([skills](https://cursor.com/docs/skills): "Creates interactive React artifacts that render alongside the conversation"; [canvas](https://cursor.com/docs/agent/tools/canvas)). A plugin packages that workflow as a skill — this file is that skill. There is no separate publish API.

Layout: 2–4 directions the PM can compare, each named with its one-line thesis, each frame taken from the `.dc.html` you just wrote. Values stay literals. The card at the end of the response is the link ([canvas](https://cursor.com/docs/agent/tools/canvas) → *Opening a canvas*). The PM reshapes it by asking, by editing the source, or with Design Mode in the canvas ([changelog](https://cursor.com/changelog/canvas-improvements)). **Publish** on the toolbar is a read-only team link on paid plans ([canvas](https://cursor.com/docs/agent/tools/canvas) → *Sharing canvases*; [shared canvases](https://cursor.com/changelog/shared-canvases)). It is not a save that republishes a design project.

The canvas is a React artifact ([skills](https://cursor.com/docs/skills)). It does not host the `.dc.html` file, and it has no design-system token layer. A builder still transcribes every value once into the repo's token file.

Canvases are the interactive artifacts introduced for the Agents Window ([changelog, 2026-04-15](https://cursor.com/changelog/04-15-26); [announcement](https://cursor.com/blog/canvas)).

If `/canvas` is not offered, or creating the canvas fails, do not invent a publish. Return the absolute `.dc.html` paths and say the canvas was not available.

## The handoff

You have no channel to the PM. The return carries what the lead needs in order to ask, and never the markup:

- the canvas card, when one was created; otherwise the absolute path of each artboard and the index, marked uncommitted
- each direction's name and one-line thesis
- the one line saying what you matched from the repo
- the design question for the PM (static mockups or working controls, and anything the brief left open)
- any screen or element from the inventory you could not cover, and what it would need

The look is settled on the canvas. The verdict is the PM's.
