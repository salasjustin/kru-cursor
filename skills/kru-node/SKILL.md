---
name: kru-node
description: "Node runtime recipes. Use when writing or reviewing code `node` runs — a CLI, a script, or a long-running service, as `.js`/`.mjs` or `node file.ts`: exit, signals, `fetch`, `--env-file`, streams, rejections, shutdown. Node 24 LTS; tsconfig and ESM/CJS config are `typescript`'s."
---

**Node's dangerous failure is the one the process never reports.** Output lost after the last line ran, a socket held after the code moved on, a crash quietly turned into exit 0. Three consequences drive the file: a listener *replaces* a default (signals, `unhandledRejection`, stream `'error'`) · exit is not synchronized with I/O (stdout, sockets and child buffers drain after your last statement) · a resource you didn't finish (a body, a stream, a connection) is held, not freed.

Reproduced on **Node v24.20.0** (`darwin/arm64`, 2026-10-05). Each behavior is documented under nodejs.org/api; the page is named per section.

## Environment — `--env-file` (`cli.html#--env-filefile`)
- **The shell wins.** A variable already in the environment beats the file, for `--env-file` and `process.loadEnvFile()` alike — `FOO=shell node --env-file=.env` reads `shell`. A stale `export` in the terminal makes an edit to `.env` look like it did nothing; `env | grep` before debugging the file. Among several `--env-file` flags, the later file wins.
- **The flag goes before the script.** `node app.js --env-file=.env` loads nothing and hands `--env-file=.env` to the script as `argv` — no error. A missing file exits `9`; `--env-file-if-exists` for an optional one.
- **No expansion.** `B=${A}-x` reads as the literal `${A}-x`, and so does `$A`; a `.env` written for `dotenv-expand` breaks silently. Unquoted values drop a trailing `# comment`; double-quoted values may span lines.

## `fetch` (undici) — `globals.html#fetch`
- **An unread body pins its connection.** Twenty requests that check `res.ok` and never read the body held twenty sockets; reading each (`await res.text()`) reused two. Every response is read or `await res.body?.cancel()`'d — the error path too, where `if (!res.ok) throw …` is the leak. `cancel()` frees the socket by closing it, so a body you'll reuse the connection after is cheaper read.
- **The only default timeout is undici's 300 s on headers** — measured: `UND_ERR_HEADERS_TIMEOUT` at 301 s. Pass `signal: AbortSignal.timeout(ms)`; it covers the body read too, and it rejects with a `DOMException` named **`TimeoutError`** — a `catch` testing `err.name === 'AbortError'` (what a manual `controller.abort()` gives) misses every timeout.
- **A network failure is `TypeError: fetch failed`** with the reason only in `err.cause` (`ECONNREFUSED`, `UND_ERR_CONNECT_TIMEOUT`). Log `err.cause`, or every outage reads the same.

## Streams and stdout — `stream.html`
- **`.pipe()` doesn't propagate errors or cleanup.** A source that errors leaves the destination open (`destroyed: false` after 200 ms), and with no `'error'` listener on the source the process crashes. `await pipeline(src, …transforms, dest)` from `node:stream/promises` destroys every stage and rejects once.
- **`write()` without honoring its return buffers everything.** A `for await` loop calling `w.write(row)` into a slow sink peaked at 22.3 MB buffered; the same rows through `pipeline(rows, async function* (src) { … yield … }, w)` peaked at 16 KB. Put the transform in the pipeline rather than awaiting `'drain'` by hand.
- **`process.stdout.write` crashes on EPIPE when the reader leaves** — `node script.js | head -1` prints an unhandled `'error'` stack to stderr and exits `1`. `console.log` swallows the same error and runs the loop to the end. A CLI that writes output installs `process.stdout.on('error', (e) => { if (e.code === 'EPIPE') process.exit(0); throw e; })`.

## Exit and signals — `process.html`
- **`process.exit()` truncates piped stdout.** 2 MB written then `process.exit(1)`, piped to a slow reader: 65,500 bytes arrived, `console.log` the same. Pipes are asynchronous on macOS (`process.html#a-note-on-process-io` lists the platforms), so the CLI that passes in a terminal loses output in CI and under `| jq`. Set `process.exitCode = 1` and return; the process exits when the loop drains, with all 2 MB.
- **A `SIGINT`/`SIGTERM` listener removes the default exit** (`process.html#signal-events`). The handler runs again on every signal — three Ctrl-Cs started three concurrent cleanups and none exited. Register with `process.once`, re-arm the second signal to exit at once, and after cleanup die by the signal — remove the listener and `process.kill(process.pid, signal)` — rather than `exit(130)`, so the calling shell stops its loop too (the `cli` skill carries why). The verified service pattern is in `reference/shutdown.md`.

## Promises — `cli.html#--unhandled-rejectionsmode`
- **A promise that rejects before you `await` it crashes the process.** `const a = slow(); const b = failing(); try { await a; await b } catch {}` exits `1` on `b`'s rejection; the `catch` never runs. Concurrent work goes through `Promise.all` / `allSettled`, which attaches every handler at once.
- **Any `unhandledRejection` listener turns the crash off.** The default `throw` mode only throws when no listener exists; a logging listener leaves the process running in an unknown state and exiting `0`. A listener that logs and then rethrows keeps the crash (exit `1`).

## Child processes — `child_process.html#maxbuffer-and-unicode`
- **`exec`, `execSync` and `spawnSync` cap output at 1 MiB.** 2 MB from the child: `exec` fails `ERR_CHILD_PROCESS_STDIO_MAXBUFFER` with output cut at 1,048,576 bytes and the child killed; the sync forms fail `ENOBUFS`. Raise `maxBuffer` for a known size; stream from `spawn` for an unknown one.

## Modules at runtime — `esm.html`, `modules.html`
The config axis (`type`, `module`, `verbatimModuleSyntax`) is `typescript`'s; these are what the loader does with it.
- **ESM has no `__dirname`, `__filename`, `require` or `module`** — `typeof` gives `undefined`, any use throws. `import.meta.dirname` / `.filename`; `import.meta.main` replaces `require.main === module` (stability 1.0, early development); `createRequire(import.meta.url)` for a CJS-only path.
- **`require()` of an ES module returns its namespace.** The default export is `.default`; only an export named `"module.exports"` changes that. A module whose graph has top-level `await` throws `ERR_REQUIRE_ASYNC_MODULE`.
- **ESM specifiers resolve exactly.** `import './lib'` is `ERR_MODULE_NOT_FOUND` — the extension is required; JSON needs `with { type: 'json' }` (`ERR_IMPORT_ATTRIBUTE_MISSING` without it).

## Disclosed
- `reference/shutdown.md` — a service's shutdown: the verified signal + `server.close` + deadline pattern, the streaming or long-polling response that holds `close()` open forever, and the other handles that keep the process alive after the server stops.
- `reference/type-stripping.md` — running `.ts` with `node` directly: what strip-only mode rejects (enums, namespaces, parameter properties, `.tsx`, `.ts` under `node_modules`), the type import that fails at runtime, the `.ts` specifier, and the tsconfig flags that move those errors to `tsc`.
