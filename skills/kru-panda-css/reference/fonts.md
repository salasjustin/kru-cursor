# Fonts and tokens

## `@fontsource-variable/*` registers a different family name than the package slug

`@fontsource-variable/inter` exposes the CSS family **`Inter Variable`**, not `Inter`. A Panda (or plain CSS) token that names `Inter` alone never resolves — the page falls back to the system font with **no build warning**.

**Fix:** set the `fontFamily` / `--font-*` token's value to the exact `font-family` string the `@font-face` rule publishes (check the package's `index.css` or the browser's computed style), not the npm package name.
