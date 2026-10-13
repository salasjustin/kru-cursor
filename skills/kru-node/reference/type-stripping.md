# Running `.ts` with `node`

`node file.ts` erases type annotations and runs what's left — no flag on Node 24, no warning printed, no type check, and no `tsconfig.json` read (so no `paths`, no `target`). Anything that needs *code generated* rather than erased is a `SyntaxError` at load. Reproduced on **Node v24.20.0** and **tsc 6.0.3** (`darwin/arm64`, 2026-10-05). Docs: `typescript.html#type-stripping`.

## Rejected at load
| Source | Error |
|---|---|
| `enum Color { Red }` | `ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX` — enum |
| `namespace N { export const a = 1 }` | same — namespace (a `declare namespace` is erased and runs) |
| `constructor(private x: number)` | same — parameter property |
| `c.tsx` | `SyntaxError: Unexpected token '<'` — no JSX |
| a `.ts` file under `node_modules` | `ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING` — a workspace package consumed as raw `.ts` needs a build step |

`--experimental-transform-types` accepts enums and the rest, with an `ExperimentalWarning`; replacing the enum with an `as const` object keeps the file strip-only.

## Rejected at link
- **A type imported without `type` is a missing export.** `import { User, make } from './types.ts'` where `User` is an interface: `SyntaxError: The requested module './types.ts' does not provide an export named 'User'`. `import { type User, make }` runs.
- **The specifier carries `.ts`.** `import './types'` is `ERR_MODULE_NOT_FOUND`; `import './types.ts'` loads.

## Move all of it to `tsc`
`erasableSyntaxOnly` + `verbatimModuleSyntax` + `allowImportingTsExtensions` (needs `noEmit`) under `module: "nodenext"` make the typecheck gate report the strip-only rows before `node` does — verified, each file got its error: `TS1294` for enum, namespace and parameter property, `TS1484` for the untyped import. Where they sit among the rest of the tsconfig is the `typescript` skill's.
