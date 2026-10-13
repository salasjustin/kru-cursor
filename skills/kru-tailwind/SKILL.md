---
name: kru-tailwind
description: Tailwind CSS v4 recipes. Use when writing or reviewing markup styled with Tailwind utilities, wiring Tailwind into a build, or debugging a class that paints nothing. v4 only; not v3, not Panda, not CSS modules.
---

**Tailwind v4 scans your source as plain text, then emits one sorted stylesheet whose config is CSS.** Three consequences drive everything below: a class name that isn't a **complete literal** in a scanned file does not exist · a conflict between two utilities is decided by **the sheet's order**, never the attribute's · and the configuration is the CSS file, so a `tailwind.config.js` sitting in the repo is inert.

Each of those fails **silent**: the build exits 0, the attribute keeps the class it was handed, and the element renders with no rule behind it — so the page reads as a styling mistake rather than the build one it is.

All claims below reproduced on `tailwindcss@4.3.3` + `@tailwindcss/cli@4.3.3` unless cited otherwise. Read `package.json` before applying any of them: v4 is a different product rather than a version bump, and the `v3-lts` tag keeps v3 a live choice with a JS config, a `content` array and `@tailwind` directives.

## The scan is text — an unwritten class name has no rule
It matches **candidate strings**, per file, without resolving imports, types or expressions. Verified:

| Reaches CSS | Never reaches CSS |
|---|---|
| a literal anywhere in a scanned file — `class="text-red-500"`, `{ ok: "text-emerald-500" }` | an interpolated name — `` `text-${color}-500` `` emits nothing, whatever `color` holds |
| a literal inside a **comment** (over-inclusion is the safe direction) | anything under a path your `.gitignore` covers — reproduced with an `ignored/` entry |
| a theme variable named in source — `style="color: var(--color-slate-200)"` keeps the variable | anything in `node_modules`, always |

So the rule at every call site: **the class list is a complete literal, or the variable holds whole class strings** — `const tone = on ? "text-teal-500" : "text-red-500"`, never a stitched-together name.

Three escape hatches, **all resolved relative to the stylesheet that declares them, not the project root**:

```css
@source "../node_modules/@acme/ui/dist";   /* a package's classes, otherwise zero */
@source inline("bg-amber-500");            /* safelist a name the app builds at runtime */
@source not "./legacy.html";               /* exclude */
```

**A `@source` path that matches nothing is silent too** — no warning, no file count, exit 0. Reproduced both ways: `@source not "./src/index.html"` written *from* `src/input.css` excluded nothing (it resolved to `src/src/`), and `"./index.html"` excluded correctly. When a rule is missing, check the path's base before anything else.

The scan root is the **repo**, not the stylesheet's directory: from `apps/web/src/app.css`, a sibling `packages/ui/src/Button.tsx` is scanned with no configuration. The boundary that actually bites is `node_modules` — a design-system package consumed as a dependency contributes nothing until `@source` names its `dist`.

## Conflicts resolve by sheet order, never by attribute order
`class="p-4 px-2"` and `class="px-2 p-4"` emit the identical sheet — `.p-4` first, `.px-2` after — so `px-2` wins **both times**. Two single-class utility rules in one layer tie on specificity, and the cascade's tiebreak is position in the generated file, which is Tailwind's sort rather than your concatenation.

This is what breaks the override prop. `<Button className="p-8">` over a base `p-4` works or doesn't depending on which the sorter happened to place later — the same component, the same call, opposite padding as the base changes. **Merge before render** with `tailwind-merge`'s `twMerge(base, props.className)`, which resolves by utility group in argument order, or keep two utilities of the same group from reaching the attribute at all. Match its major to Tailwind's: `tailwind-merge` **3.x** is the v4 line — "this release drops support for Tailwind CSS v3 and in turn adds support for Tailwind CSS v4" (v3.0.0 release notes), so a repo left on 2.x is merging against v3's group table.

**`twMerge` only merges what it recognizes as one group.** A project type role (`text-note`, registered under `--text-*` or as a custom utility) passed into a vendored shadcn component doesn't replace its stock `text-sm`: `tailwind-merge` reads the unknown `text-*` as a colour and keeps both, and Tailwind emits custom roles *before* stock sizes, so the stock size wins. Put the role on an ancestor the vendored component leaves classless, or teach `extendTailwindMerge` the role's group — and check the compiled sheet order rather than trusting the later class in `cn()`.

## `@theme` publishes a variable; `@theme inline` spends its value
Both register a utility. What differs is what lands in the sheet — reproduced side by side:

```css
@theme        { --color-brand: oklch(0.6 0.2 250); }  /* :root gets --color-brand; .bg-brand reads var(--color-brand) */
@theme inline { --color-ink: var(--paper-ink); }      /* no --color-ink anywhere; .text-ink reads var(--paper-ink) */
```

So the choice is about **runtime theming**. A theme variable whose value is another variable that changes under `.dark` must be `inline`, or the indirection resolves once at `:root` and the flip never reaches the utility. This is why a shadcn theme block is `@theme inline` over the `--background`/`--foreground` custom properties — the utilities point straight at the properties `.dark` re-declares. Use plain `@theme` for a value that is the value.

## The closed set that ships: `--color-*: initial`
```css
@theme { --color-*: initial; --color-brand: #123456; }
```
Reproduced: `bg-gray-500` then matches **no rule at all**, while `bg-brand` compiles. This is the one place to *want* the silence: an off-system value stops being a review finding and becomes an element with no styling, enforcement that ships with the app and can't be skipped.

## `@apply` outside the entry sheet needs `@reference`
A CSS module, a Vue/Svelte `<style>` block or any separately-compiled file knows no utilities. This is the exception that fails **loudly** — `Error: Cannot apply unknown utility class 'bg-blue-500'. Are you using CSS modules or similar and missing '@reference'?` — so the trap isn't the error, it's the cost of the fix:

```css
@reference "./input.css";   /* or "tailwindcss" for stock theme only — parses that sheet per consuming file, emits none of it */
.btn { @apply bg-blue-500 px-4; }
```

Reach for a custom property instead where you can (`color: var(--color-blue-500)`) — one declaration, no re-parse, and it survives the file being compiled anywhere.

## A `tailwind.config.js` is read only when `@config` names it
Reproduced: with a v4 install and a config file exporting `theme.extend.colors.legacy`, `bg-legacy` emits nothing, silently. `@config "../tailwind.config.js"` restores it. A repo carrying both a v4 stylesheet and an un-referenced JS config has a file that looks authoritative and decides nothing — read the CSS to learn what the theme is.

## Dark mode is the media query until you say otherwise
`dark:text-white` compiles to `@media (prefers-color-scheme: dark)`. A class-toggled theme needs the variant redefined, which then compiles to the selector:

```css
@custom-variant dark (&:where(.dark, .dark *));   /* → .dark\:text-white:where(.dark, .dark *) */
```

Match whatever the app already toggles — a `data-theme` attribute takes `[data-theme=dark]` in the same position.

## Layers, and where a custom class can take variants
The sheet opens with `@layer theme, base, components, utilities`. Per the cascade, **any unlayered stylesheet outranks every one of them** regardless of specificity, so a third-party plain CSS file silently beats your utilities — import it into a layer you control (`@import "lib.css" layer(vendor);`) rather than escalating.

For a class of your own, the two homes are not equivalent: `@utility card { … }` composes with variants (`hover:card` emits), while `.panel` declared inside `@layer components` does not (`hover:panel` emits nothing). Custom utilities go in `@utility`.

## `hover:` does not apply where there is no hover
Hover variants compile inside `@media (hover: hover)` — reproduced. A control whose only affordance is its hover state has **no** affordance on touch; the resting state has to carry the signal on its own.

## `outline-none` beside a `focus-visible:` ring paints no ring
`outline-none` and `outline-hidden` both set `--tw-outline-style: none`, and a width utility like `focus-visible:outline-2` reads `outline-style: var(--tw-outline-style)` without setting it — so `outline-none focus-visible:outline-2` keeps the style at `none` and the ring never draws. Suppress the resting outline with `outline-0` (width only), or scope the suppression with `not-focus-visible:outline-none`; variants sort after `focus-visible:`, so a variant-gated `outline-none` wins over the ring.

## Consult current docs (official sources first)
Never answer config or utility specifics from memory — the v3→v4 rename table especially (`outline-none` → `outline-hidden`, `ring` → `ring-3`, `shadow-sm` → `shadow-xs`, default border color now `currentColor`) is a lookup, not a recipe.
1. **tailwindcss.com** — `/docs/upgrade-guide` for the v3→v4 diff, `/docs/theme`, `/docs/detecting-classes-in-source-files`, `/docs/functions-and-directives`.
2. **Context7** — the framework has no first-party entry; the docs site is `/tailwindlabs/tailwindcss.com`.

State which source you used.

## Not this skill's job
- **Which values the system has** — palette, type scale, spacing, motion live in the repo's token file and are read from there, never invented here.
- **Tailwind v3** — almost nothing above transfers to a `v3-lts` repo; the markers are in the opening.
- **shadcn repos** — the `shadcn` skill owns the CLI, the registry and `components/ui/*`; this skill is the CSS engine underneath.
- **Native CSS feature safety** (container queries, `:has()`, `@starting-style`) — the `modern-css` skill. Tailwind emits what you write.
- **Accessible interactive primitives** — the `ark-ui` skill; Tailwind styles them through their `data-*` state attributes.
- **Other styling systems** — Panda (`panda-css`), CSS modules, vanilla-extract. Brownfield matches what the repo has.
