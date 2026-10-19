---
name: kru-panda-css
description: "Panda CSS 2 recipes — the class that ships with no rule and no warning. Use when writing or reviewing styles in a repo with a `panda.config.*` / `styled-system/`, wiring Panda into a build or CI, or debugging a Panda style that renders with no CSS. Not Tailwind, vanilla-extract or StyleX."
---

**Panda folds what it can at build time and warns about most of what it can't; the failures left are the ones nothing reports.** The engine resolves a style value across imports down to a literal. A `css()` argument it can't fold prints `warning panda_call_unextractable … no static CSS was generated for this call` and emits nothing. The traps below are the paths that warning misses. In each, a class reaches the DOM with no rule behind it, or with a rule that does the wrong thing, and the build exits 0. Make the warnings fail the build first (the gate below), then check the silent paths by hand.

Reproduced on **`@pandacss/dev@2.1.0`** (npm `latest`, 2026-10-02) with `@pandacss/vite@2.1.0` on `vite@8.3.2`, TypeScript 7.0.2, Node 24.20.0, through the `panda` CLI and `vite build` only. Cascade claims, which need a browser, are source-verified and marked. Panda 2 is ESM-only and needs Node ≥ 22.

## The gate: warnings and stale artifacts exit 0 unless you ask
```sh
panda --max-warnings 0     # codegen + CSS; exits 1 on any panda_call_unextractable / unknown_condition warning
panda check                # exits 1 when styled-system/ is stale against the config ("missing 0, stale 3")
panda analyze              # "analyze: scanned N files" is the only file count the CLI prints
tsc --noEmit               # after `panda`: styled-system/ is gitignored, so typecheck needs it generated first
```
`panda doctor` validates setup, not extraction. It prints `doctor: ok (0 diagnostics)` while the build warns, and its `sources` / `sourceCount` is the number of `include` globs, not files (it reported 1 for a glob matching 10 files). Its `utilities` and `conditions` counts are still worth reading (the `presets` trap below). `panda` writes both outputs: `panda codegen` writes only `styled-system/` and `panda cssgen` only the CSS.

## What resolves, what warns, what drops in silence
| Becomes CSS | Warns, emits nothing | Emits nothing, no warning |
|---|---|---|
| literals and same-file consts | a function parameter (a union type doesn't help) | a value passed to **your own wrapper**: `const mine = (o) => css(o)` |
| an imported const, through a relative path, a `tsconfig` `paths` alias, a named or `export *` re-export, a file outside `include`, or a `node_modules` package | `map[k]` with a runtime key | a **JSX style prop** given a runtime value: `<Box color={c} />` |
| an imported object's member, or the whole object (`css(base)`) | a **default** import | a config-recipe variant chosen at runtime (next trap) |
| a literal index into an imported array (`tones[1]`) | a namespace member (`T.brand` after `import * as T`) | |
| a call to an imported function with literal arguments (`pick(true)`) | an imported `enum` member | |
| both branches of a ternary, and the fallback of `x ?? 'red.500'` | | |

The wrapper does warn, but **once, at the `css(o)` inside it**, never at its call sites. Every `mine({...})` in the codebase drops, and the one warning points at a line that looks correct. Call `css()` directly, or make the wrapper a `cva`.

A value that arrives as a prop has three homes: a recipe variant, a `staticCss` entry, or a CSS variable. For the variable, set `style={{ '--accent': token.var('colors.red.500') }}` and write `css({ color: 'var(--accent)' })`. `token.var()` returns `var(--colors-red-500)`. `token()` returns the raw value (`oklch(63.7% …)`) for a base token and a `var()` for a semantic one.

## A config recipe called with a runtime variant has no rule
```ts
// theme.extend.recipes.btn: tone primary | danger | ghost, size sm | lg
btn({ tone: 'primary', size: 'sm' })          // somewhere, literally
const Btn = ({ tone }) => btn({ tone })        // tone = 'danger' at runtime → "btn btn--tone_danger"
// styles.css: .btn--tone_primary .btn--size_sm — no .btn--tone_danger, no warning
```
A config recipe (`theme.recipes`, imported from `styled-system/recipes`) emits only the variants some file passes **literally**. A `cva()` declared in a source file emits every variant, so `chip({ look })` with a prop works. `transform: true` doesn't help: the runtime `btn({ tone })` stays a runtime call, and its class still has no rule. Choose by where the variant is decided. If the call site picks it, a config recipe gives smaller CSS. If a prop picks it, use `cva`, or keep the config recipe and safelist it:
```ts
staticCss: { recipes: { btn: ['*'] } }   // every variant of btn
```
A design-system component that passes a variant prop through to a recipe has the same problem and the same fix.

## Overrides lose to sheet order, not argument order
```ts
css({ mt: '4' }, { m: '0' })                                  // "mt_4 m_0" — margin-top stays 4
cx(css({ color: 'red.500' }), css({ color: 'green.500' }))    // "c_red.500 c_green.500" — red wins
cx(css({ color: 'green.500' }), css({ color: 'red.500' }))    // red wins again
```
`css(a, b)` merges by property: the same key in `b` replaces it (`css({color:'red.500'},{color:'green.500'})` → `c_green.500`). It does not reconcile a shorthand with its longhands. The sheet puts the broader property first (`.m_0` before `.mt_4`, `.bd-c_*` before `.bd-t-c_*`), so a longhand from the base beats the shorthand in the override. `cx` only joins strings, so two rules for one property both apply, and the later rule in the sheet wins. In this reproduction that order was sorted by class name, stable across extraction order, and argument order never decided anything. Write an override with the same longhand it overrides, and merge style objects in one `css()`. Keep `cx` for classes that don't compete, like `cx(btn({ tone: 'ghost' }), active && css({ fontWeight: 'bold' }))`.

## `include` is the whole contract, under the Vite plugin too
`panda init` writes `include: ['./src/**/*.{js,jsx,ts,tsx}', './pages/**/*.{js,jsx,ts,tsx}']`. A file outside that list gets no rules for its calls and no warning: an App Router `app/page.tsx`, a root `components/`, and every `.svelte` / `.vue` / `.astro` file (the compiler reads them once a glob includes them). `@pandacss/vite` extracts from the same globs, not from the module graph. A file the entry imports but `include` misses builds with its class string and no rule. Only call sites need to be in `include`: a value *imported* from outside still resolves.

`--include` takes one glob per flag. `--include "src/**/*.tsx,app/**/*.tsx"` is a single glob containing a comma, and it scans 0 files. Repeat the flag. After changing globs, confirm with `panda analyze`'s `scanned N files`.

## The Vite plugin injects CSS into one file: the one with the `@layer` line
```css
/* src/index.css, imported by the entry */
@layer reset, base, tokens, recipes, utilities;
```
`@pandacss/vite` appends the generated CSS only to a `.css` module that declares Panda's layers. A Vitest config kept separate from `vite.config.ts` inherits none of its plugins or `css.postcss`: re-add Panda's (`@pandacss/vite`, or `css.postcss.plugins: [pandacss()]` under the PostCSS integration), or Browser Mode renders raw UA styles and nothing errors. Leave the line out and `vite build` ships the file without any Panda CSS, and prints nothing. With `transform: true`, static `css()`, pattern, recipe and `styled` calls compile to class strings (`el.title = "m_0 mt_4"`), and two `panda_call_unextractable` warnings point at `styled-system/css/cva.js` and `sva.js` themselves. Those two are expected. A warning that points at your own file is a real drop.

## `optimize.removeUnusedTokens` deletes variables that plain CSS reads
```ts
optimize: { removeUnusedTokens: true }
```
```css
@layer reset, base, tokens, recipes, utilities;
.legacy { color: var(--colors-indigo-300); }   /* --colors-indigo-300: not in the built sheet */
```
The optimizer keeps a token only when a Panda call, `token()`/`token.var()` call, recipe, `staticCss` or `globalCss` uses it. A `var(--colors-*)` in a `.css` file (the layer entry itself included), or in a style object Panda doesn't read (`{ color: 'var(--colors-cyan-300)' }`), resolves to nothing, and nothing warns. Keep such a token with `staticCss: { css: [{ properties: { color: ['indigo.300'] } }] }`, or reference it through `css()`. `smartCompoundVariants` has the same blind spot for compound variants chosen at runtime (source-verified, `/docs/styling/optimization`).

## A config without `presets` emits garbage
```ts
defineConfig({ include: ['./src/**/*.tsx'], theme: { extend: { tokens: { colors: { brand: { value: '#4f46e5' } } } } } })
css({ color: 'brand', bg: 'red.500', px: '4', _hover: { color: 'brand' } })
// .color_brand { color: brand }  .bg_red\.500 { bg: red.500 }  .px_4 { px: 4px }
// warns only: unknown condition `_hover`
```
No preset is added implicitly. Without `@pandacss/preset-base` there are no shorthands, no token-aware utilities and no conditions, so a token name becomes a literal value and a shorthand becomes a property name. The only warnings are the conditions. `panda doctor` says `ok` with `utilities: 1, conditions: 1` (506 and 275 with the presets). `panda init` writes `presets: ['@pandacss/preset-base', '@pandacss/preset-panda']`. A hand-written or merged config must list them too.

## A semantic token's value references other tokens with `{}`
```ts
semanticTokens: { colors: { surface: { value: { base: 'white', _dark: 'gray.900' } } } }
// .dark { --colors-surface: gray.900 }            — an invalid color, no warning
_dark: '{colors.gray.900}'
// .dark { --colors-surface: var(--colors-gray-900) }
```
In `css()`, `'gray.900'` is a token path. In a token's `value`, it is a literal string. Use `{category.path}` there.

## Dark mode matches `.dark`, not `[data-theme]`
`preset-base` defines `dark: '.dark &'`. Every `_dark` value, in semantic tokens and in `css()`, compiles under `.dark`, and an app that toggles `data-theme="dark"` gets no flip and no warning. Extend the condition to cover both:
```ts
conditions: { extend: { dark: '[data-theme=dark] &, .dark &' } }
// tokens: :where([data-theme=dark], .dark) { --colors-surface: … }
// css():  [data-theme=dark] .dark\:c_white, .dark .dark\:c_white { … }
```

## An unknown token is not an error, and `strictTokens` only guards types
`css({ color: 'nosuchtoken', padding: '13px' })` emits `.c_nosuchtoken { color: nosuchtoken }` and `.p_13px { padding: 13px }`, with no warning even under `--max-warnings 0`. The browser drops the first declaration, so a mistyped token leaves one component unthemed. `strictTokens: true` changes only the generated types: `panda` still emits both rules, and `tsc` is what fails (`Type '"nosuchtoken"' is not assignable to type 'ConditionalValue<ColorsValue>'`, and the same for `'13px'` against `SpacingValue`). It does nothing unless typecheck runs in CI. A deliberate raw value takes brackets: `padding: '[13px]'` → `.p_\[13px\] { padding: 13px }`.

## Unlayered CSS beats every Panda rule (source-verified)
Output lives in `@layer reset, base, tokens, recipes, utilities`. Under the cascade-layers spec, an unlayered declaration beats any layered one regardless of specificity, so a third-party plain stylesheet overrides your utilities (panda-css.com/blog/panda-css-v2, *Caveats*). Import it into a layer you order (`@import "lib.css" layer(vendor);`) instead of raising specificity. A library that ships Panda styles can rename its layers (`layers: { recipes: 'ds.recipes', utilities: 'ds.utilities' }`) so the consuming app's unlayered CSS wins predictably.

A repo resolving `@pandacss/dev` below 2: `reference/migration.md`. A font token that silently falls back to the system font, or any `@fontsource-variable/*` import: `reference/fonts.md`.

## Consult current docs (official sources first)
1. **Panda MCP**: `npx -y @pandacss/mcp`. It answers against this repo's resolved config, which no docs page can. `get_usage_report` audits used, unused and misused tokens, recipes, utilities, patterns and keyframes. Run it before inventing a token that already exists.
2. **`https://panda-css.com/llms.txt`**: a per-section index (`llms-full.txt` holds everything). Pages: `/docs/styling/source-transforms`, `/docs/styling/optimization`, `/docs/get-started/upgrading-to-v2`.
3. Installed types: `@pandacss/types/dist/config.d.ts` lists every config key with its doc comment, and `@pandacss/vite/dist/index.d.ts` lists the plugin options (`cwd`, `configPath`, `outdir`, `transform`). `panda <command> --help` covers flags.

## Not this skill's job
- **Introducing Panda into a repo that already has a styling system.** Brownfield matches what's there; flag the mismatch to the lead.
- **Which tokens exist.** Palette, type scale and spacing belong to the design and live in the repo's token file.
- **Native CSS feature safety**: the `modern-css` skill. Panda emits whatever you write.
- **Accessible interactive primitives**: the `ark-ui` skill. Panda styles them through their `data-*` state attributes.
- **Generic config/recipe typing and module augmentation**: the `typescript` skill.
- **Publishing a design system** (`panda lib`, `designSystem`, `treeshakeDesignSystem`), webpack/Rollup/Bun plugins, Turbopack, and the ESLint/oxlint plugin were not reproduced here. Read the docs above.
