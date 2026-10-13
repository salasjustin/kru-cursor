# Node CLI traps

Reproduced on Node v24.20.0 (macOS, 2026-10-05) and commander 15.0.0.

## Exit and broken pipes
`process.exit()` truncating piped stdout and the stdout `EPIPE` handler are runtime behavior, carried with their measurements by the **`node`** skill (*Streams and stdout*, *Exit and signals*). Install that handler before the first write.

## `parseArgs` throws, and the throw is a usage error
`node:util` `parseArgs` throws a `TypeError` with a `code` starting `ERR_PARSE_ARGS_` on an unknown option, a missing value, a value starting with `-` (`--n -5` is *ambiguous*; `--n=-5` parses), or a positional when `allowPositionals` is off. Uncaught, that is a stack trace and exit 1:
```js
let args;
try { args = parseArgs({ options, allowPositionals: true }); }
catch (e) {
  if (!e.code?.startsWith('ERR_PARSE_ARGS_')) throw e;
  process.stderr.write(`cmd: ${e.message}\nRun 'cmd --help' for usage.\n`);
  process.exit(2);
}
```
It has no `--help`/`--version` handling; declare both as booleans and check them first. `default` values fill `values`, so an option with a `default` can't be told apart from one the user passed — leave it off where env or config can supply the value (`SKILL.md` → *Configuration*).

## commander exits 1 on a usage error
Every parse failure (`commander.unknownOption`, `.missingArgument`, `.optionMissingArgument`, `.invalidArgument`, `.excessArguments`, `.unknownCommand`, …) exits 1. `exitOverride()` turns each into a thrown `CommanderError` you map:
```js
import { Command, CommanderError } from 'commander';
program.exitOverride();
try { await program.parseAsync(); }
catch (e) {
  if (!(e instanceof CommanderError)) throw e;         // the action's own failure
  if (e.exitCode === 0) process.exit(0);               // --help, help, --version
  process.exitCode = e.code === 'commander.executeSubCommandAsync' ? e.exitCode : 2;
}
```
## readline
Create the interface with `output: process.stderr` so the prompt stays off stdout, and gate it on `process.stdin.isTTY` — `question()` at EOF never resolves (`SKILL.md` → *Prompts*).
