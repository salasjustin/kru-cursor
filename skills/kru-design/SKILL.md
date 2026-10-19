---
name: kru-design
description: Designer-bot skill only — draft .dc.html artboards and publish with Cursor's /canvas for the PM to compare directions. Not for engineering sessions; the lead never loads this skill.
disable-model-invocation: true
---

The artboard and publish mechanics for a **designer bot** session. Load this file (`skills/kru-design/SKILL.md`); engineering does not invoke it as a slash command. The look is decided on the canvas. The verdict is the PM's. Practice: `${CURSOR_PLUGIN_ROOT}/references/ui-practice.md` and `${CURSOR_PLUGIN_ROOT}/references/designer-handoff.md`.

## Draft the files first

Always draft self-contained `.dc.html` artboards. They are the re-seed and the transcription spec, and they are the whole return when `/canvas` is not available. The file format is `${CURSOR_PLUGIN_ROOT}/skills/kru-design/artboards.md` — follow it for every local artboard and the index.

## Directions and re-drafts

**Match before you invent.** Read the repo first and say in one line what you matched: the token file, the stylesheets, the closest screen, the icon set. At bootstrap there is nothing to match but the conventions corpus and whatever the brief names; that is the one turn where the look is yours to propose.

At bootstrap, draft **2–4 directions**. A reader should be able to say what each one *is* in a phrase. Vary what carries the look: **density**, **type scale and face pairing**, **how much chrome** a surface gets, whether **depth** comes from shadow or from line, **how colour is spent** (one accent or a family), and **shape language**. Three palettes of the same layout is one direction. State each direction's thesis in one line in your return. A direction you cannot name in a phrase is the one to cut.

**Re-draft from the files that are there.** The PM's pick is the base; what they wanted different is the next brief. Keep rejected directions until the pick is transcribed into the token file. Two rounds is normal. On a **third** re-draft round, say the **brief** is the problem and hand the question back to the PM.

**Ask the PM before building working controls.** Static mockups are the default.

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

If neither cloud **`WriteCanvas`** nor IDE `/canvas` is available, or creating the canvas fails, return the absolute `.dc.html` paths and say the canvas was not available.

## Canvas vs approved mockups

The canvas is for **comparing directions** before the PM picks one. **Approved mockups** are still **PNG exports at 1440 and 375** (and the build spec). They attach to the **Linear issue** and are what the layout gate and PM screen acceptance compare against at build time. **`kru-visual-reviewer` runs only when the PM names that pass** (`skills/kru-visual-review/SKILL.md`).

Put the canvas **`url`** on the Linear issue as an **extra link** for direction review. Keep the PNG mockups on the issue; the canvas link is for comparing directions only.

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
