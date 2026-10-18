---
name: kru-design
description: Designer-bot skill only — draft .dc.html artboards and publish with Cursor's /canvas for the PM to compare directions. Not for engineering sessions; the lead never loads this skill.
disable-model-invocation: true
---

The artboard and publish mechanics for a **designer bot** session. Load this file (`skills/kru-design/SKILL.md`); engineering does not invoke it as a slash command. The look is decided on the canvas. The verdict is the PM's. Practice: `${CURSOR_PLUGIN_ROOT}/references/ui-practice.md` and `${CURSOR_PLUGIN_ROOT}/references/designer-handoff.md`.

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
- **One viewport per file, stated.** 1440 for desktop, 375 for mobile. A direction that only makes sense at both is two files.
- **Real content.** Copy from the build spec (or `conversion-copywriter`'s SECTION deck on marketing pages). Placeholder text hides the decision.
- **The states the screen has**, stacked under small labels, where the brief names them.
- **Web-safe faces, or a `<link>` to a font host.** Those are the file's outside loads. Everything else is local.
- **Label every artboard in the file** — the direction's name and its one-line thesis.
- **Match the repo first** and say in one line what you matched: the token file, the stylesheets, the closest screen, the icon set.
- **Directions differ.** 2–4 at bootstrap. Three palettes of the same layout is one direction. State each thesis in one line.
- **Re-draft from the files that are there.** The PM's pick is the base. Two rounds is normal. A third means the brief is what's wrong.

## Publish with `/canvas`

Publish the directions as one live canvas the PM compares beside the chat. Layout is the same on every host: **2–4 directions**, each named with its one-line thesis, each frame taken from the `.dc.html` you just wrote. Values stay literals.

The canvas is a React artifact ([skills](https://cursor.com/docs/skills)). It does not host the `.dc.html` file, and it has no design-system token layer. A builder still transcribes every value once into the repo's token file.

### Cloud agent

On a **Cursor cloud agent**, Cursor's built-in **`canvas` skill** is present (`~/.cursor/skills-cursor/canvas/SKILL.md`), with **`WriteCanvas`** and **`ReadCanvas`** tools. Call them directly — not via MCP.

1. **`WriteCanvas`** with the full `.canvas.tsx` `contents` and a `title`; omit `canvas_id` to create.
2. The tool returns a **`canvas_id`** and a **`url`** (`https://cursor.com/canvas/<store>/<id>`). Hand the PM that **url** as the canvas link. No toolbar **Publish** click is required on cloud agents.
3. The link opens for **signed-in team members** — do not call it a public link.
4. **Update an existing canvas:** `ReadCanvas` with `canvas_id` or the canvas `url`, then `WriteCanvas` again with the **same `canvas_id`** and the full new `contents` (per the canvas skill — there is no on-disk source path).

### Cursor IDE

When `/canvas` is available in the IDE, invoke it ([skills](https://cursor.com/docs/skills); [canvas](https://cursor.com/docs/agent/tools/canvas)). This file is the designer workflow around that built-in. The **canvas card** at the end of the response is the link ([canvas](https://cursor.com/docs/agent/tools/canvas) → *Opening a canvas*). The PM reshapes it by asking, by editing the source, or with Design Mode ([changelog](https://cursor.com/changelog/canvas-improvements)). **Publish** on the canvas toolbar is the read-only **team share** link on paid plans ([canvas](https://cursor.com/docs/agent/tools/canvas) → *Sharing canvases*; [shared canvases](https://cursor.com/changelog/shared-canvases)).

### Fallback

If neither cloud **`WriteCanvas`** nor IDE `/canvas` is available, or creating the canvas fails, do not invent a publish. Return the absolute `.dc.html` paths and say the canvas was not available.

## Canvas vs approved mockups

The canvas is for **comparing directions** before the PM picks one. **Approved mockups** are still **PNG exports at 1440 and 375** (and the build spec). They attach to the **Linear issue** and are what the layout gate and `visual-reviewer` compare against at build time.

Put the canvas **`url`** on the Linear issue as an **extra link** for direction review. It **never replaces** the PNG mockups.

## The handoff

You talk to the **PM**, not the engineering lead. The return carries what the PM needs to approve and attach to the engineering brief (`references/design-spec.md`):

- **canvas** — the `url` and `canvas_id` when one was created; on IDE sessions, the canvas card counts as the link
- **approved mockups** — absolute paths to the **1440** and **375** PNG exports per screen and state
- **artboards** — absolute paths to each `.dc.html` and the index, marked uncommitted
- each direction's name and one-line thesis
- the one line saying what you matched from the repo
- design questions for the PM (static mockups or working controls, and anything the brief left open)
- any screen or element from the inventory you could not cover, and what it would need

The look is settled on the canvas. The PM's approval is what ships to engineering.
