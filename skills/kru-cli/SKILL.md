---
name: kru-cli
description: CLI contract recipes. Use when writing or reviewing a command-line tool's flags and arguments, stdout vs stderr, exit status, `--json`, stdin, prompts, env/config precedence or `--dry-run`, in Node/TS, Python or Go. A full-screen terminal app is `tui-design`'s.
---

**A CLI's caller is a program at least as often as a person** — a shell script, a CI step, an agent's Bash tool. That caller reads three things: stdout as data, the exit status as the verdict, and nothing else. Every trap below is the tool telling that caller the wrong thing while a human watching a terminal sees nothing amiss — so test the contract with the terminal taken away: `cmd </dev/null 2>/dev/null | cat; echo $?`.

Reproduced on macOS 15 (`darwin/arm64`, 2026-10-05): Node v24.20.0 · Python 3.14.3 · go1.26.1 · commander 15.0.0 · typer 0.27.2 (vendors click) · cobra v1.10.2 · platformdirs 4.12.3 · env-paths 4.0.0. Convention claims cite POSIX Utility Syntax Guidelines (XBD ch. 12), GNU Coding Standards §4.8, the Bash manual's *Exit Status*, no-color.org, the XDG Base Directory spec, and clig.dev.

## stdout is data, stderr is everything else
- **Anything that isn't the result goes to stderr** — progress, warnings, "wrote 3 files", prompts, deprecation notices. One stray line on stdout and `cmd --json | jq` fails on a parse error that names the wrong problem. When stdout is a protocol (an MCP stdio server, an LSP, a `git` credential helper) one line ends the session. The defaults that put it there anyway: Node's `console.info`/`console.debug` (stdout, same as `console.log`); Python's `input(prompt)` and typer/click's `confirm` (prompt written to stdout); `npm run` (prints its `> pkg@1.0.0 script` banner to stdout — `npm run -s`). Python `logging` and `warnings`, Go's `log`, and Node's `console.warn`/`console.error` already go to stderr.
- **A reader that stops early is normal, not an error.** `cmd | head -1` closes the pipe; the next write fails. Go dies quietly by SIGPIPE (status 141, like coreutils). Node throws an unhandled `EPIPE` stack trace (exit 1); Python prints a `BrokenPipeError` traceback and exits 120. Catch the broken pipe **on stdout only** and exit **0** with nothing on stderr, so `set -o pipefail` doesn't fail a pipeline that stopped reading on purpose — Python's in `reference/python.md`, Node's in the **`node`** skill. Go's 141 is the runtime's own and stays.
- **Write the output before you exit, and let it drain.** Node's stdout on a pipe is asynchronous on POSIX: `process.exit()` after a large write cut a 3.1 MB JSON document to 65,536 bytes — the **`node`** skill carries the fix. Go's `os.Exit` skips the deferred `Flush` of a `bufio.Writer`.

## The exit status is the verdict
- **0 success · 1 failure · 2 usage error** (bad flag, missing argument, conflicting options — bash builtins, argparse, typer/click and Go `flag` all use 2). A caller retries a 1 and fixes its invocation on a 2, so a usage error that exits 1 sends an agent into a retry loop. commander, `node:util` `parseArgs` (uncaught throw) and cobra (whatever `main` passes to `os.Exit`) all exit 1 on a usage error by default.
- **Every failure path reaches a non-zero exit.** `main().catch(console.error)` in Node and `except Exception as e: print(e)` in Python both exit **0** after the failure — CI goes green on a failed upload. The top-level handler prints one line to stderr and sets the code; it never returns normally. A run that finished with per-item failures exits 1 too.
- **Statuses are one byte.** `exit(256)` is 0 in Node, Python and Go — "exit with the error count" reports success at 256 errors. Cap it, or exit 1 and print the count.
- **On SIGINT, clean up and then die by the signal.** A handler that cleans up and calls `exit(130)` looks right and isn't: the calling shell sees a normal exit, so `for f in *; do cmd "$f"; done` runs on to the next file after Ctrl-C (reproduced: three iterations ran; re-raising stopped the loop after the first). After cleanup, restore the default handler and send the signal to yourself — `process.kill(process.pid, 'SIGINT')` / `signal.signal(SIGINT, SIG_DFL); os.kill(os.getpid(), SIGINT)` / `signal.Reset(os.Interrupt)` then `syscall.Kill(os.Getpid(), syscall.SIGINT)`. The shell then reports 128+2 = 130 by itself. (Source: Bash manual *Exit Status*; cons.org/cracauer/sigint.html.)

## Arguments
- **`--help` and `--version` print to stdout and exit 0** (GNU §4.8), so `cmd --help | less` and `cmd --version | grep` work. Go's `flag` prints help to **stderr** (`cmd -h | less` shows nothing) — `reference/go.md`.
- **A usage error is one line plus a pointer**, on stderr, exit 2: `cmd: unknown option '--bogus'` / `Run 'cmd --help' for usage.` The full usage text belongs to `--help`; cobra prints it after *every* `RunE` error by default, so a refused connection scrolls the actual message away (`SilenceUsage: true`).
- **`--opt=value` is the only form every parser reads the same.** A value starting with `-` (`--msg -x`, `--n -5`): argparse rejects `--msg -x` and accepts `--n -5`; `parseArgs` rejects both as ambiguous; commander takes both as values. Docs, examples and any code that builds a command line for this tool use `=`.
- **`--` ends options and `-` is stdin** (POSIX guidelines 10 and 13). argparse, `parseArgs`, commander and Go `flag` all handle both; the trap is the tool's own code opening a file named `-`. A tool that reads files treats `-` as stdin and, given no file, reads stdin only when stdin is not a TTY.
- **A prefix abbreviation is a contract you didn't mean to sign.** argparse's `allow_abbrev=True` default accepts `--verb` for `--verbose`; add `--verbatim` and every script using `--verb` fails with `ambiguous option` (exit 2). `ArgumentParser(allow_abbrev=False)` from the first release.
- **Go's `flag` stops at the first positional**: `cmd file.txt -v` leaves `-v` as a second filename, silently. argparse, commander and `parseArgs` parse options after positionals.

## `--json` is an API
Its consumers are code you don't own, so its shape follows `api-design` (an object at the top so it can grow a field, `[]` never `null`, additive changes only). What is the CLI's own:
- **One document, written whole, or nothing.** Build it, serialize it, write it once at the end. A tool that streams `[` then items then fails leaves a truncated array the consumer reports as a JSON parse error, hiding the real one.
- **A stream is NDJSON** — one complete, single-line object per line, flushed per line — so a failure mid-run leaves N parseable records and a non-zero exit. Pretty-printed objects one after another are not NDJSON.
- **Errors in machine mode**: stdout stays empty (or holds only complete records), stderr carries `{"error":{"code":"…","message":"…"}}`, and the exit status is the same non-zero one plain mode gives. `--json` never changes an exit code.
- **No color, no marking, no progress on stdout** in machine mode, whatever the TTY says.

## Is anyone there? Ask each stream
- **Decide per stream, from that stream's TTY check.** `TERM` and a parent's TTY prove nothing: this skill's own harness ran with `TERM=xterm-ghostty` and every stream a pipe. Node's `util.styleText` checks **stdout** by default — text written to stderr was colored into a log file while stdout was a terminal; pass `{ stream: process.stderr }`. Python 3.14's argparse does the same for its usage errors (`reference/python.md`). In Node `isTTY` is `undefined`, not `false`, on a non-TTY.
- **Color: `--color=always|never|auto` beats the environment; then `NO_COLOR` — only when set *and non-empty* (no-color.org; `NO_COLOR=` means nothing); then `FORCE_COLOR`; then `TERM=dumb` → none; then the stream's TTY.** Node's own detection lets `FORCE_COLOR` win over `NO_COLOR` with a runtime warning — honor a flag before reaching either.
- **No input and stdin is a TTY → usage error, never a silent wait.** `cmd` with no file, run by hand, otherwise sits on a blank line until Ctrl-D. And an open pipe nobody writes to blocks a read forever (reproduced: a child given an unwritten `stdin=PIPE` was still blocked after 2 s; with `/dev/null` it exited at once) — a tool that never needs stdin never reads it.

## Prompts
- **Prompt only when stdin *and* stderr are TTYs; otherwise refuse.** With stdin not a TTY, a destructive action that needs confirmation exits 2 with `refusing to delete 40 rows without --yes`. The defaults that go wrong: Python's `input()` raises `EOFError` on `</dev/null`, and the common `except EOFError` / empty-answer → `[Y/n]` default **deployed to prod** on an empty pipe; Node's `readline` `question()` never resolves at EOF, so the process exits **0** (CommonJS) or **13** (ESM top-level await) having done nothing. typer's `confirm` aborts with exit 1, which is the safe shape.
- **A TTY does not mean a person.** Buildkite's agent runs jobs in a PTY by default, and `docker run -t` allocates one. `CI` set non-empty means no prompts and no spinners whatever the TTY says.
- **`--yes` (`-y`) answers every confirmation; `--no-input` fails any prompt that would have appeared.** Prompts go to stderr so the answer never lands in stdout.

## Configuration
- **Precedence: flag > env > project config > user config > built-in default**, resolved in one function. The trap is the parser: argparse `default=8080` makes `args.port` always set, so `args.port or os.environ["T_PORT"]` never reads the env (reproduced: `T_PORT=9000` → 8080). Parser defaults stay `None`/`undefined`; the built-in default is applied last, in the resolver.
- **An env var is a string.** `if (process.env.DEBUG)` is on for `DEBUG=0` and `DEBUG=false`; parse booleans explicitly and reject what you don't recognize.
- **User config lives at `$XDG_CONFIG_HOME/<tool>`, else `~/.config/<tool>` — on macOS too**, where `gh` and `git` look and where the user's dotfiles put it. An empty or relative `XDG_CONFIG_HOME` is ignored (XDG spec). The library helpers disagree on macOS: Go's `os.UserConfigDir` returns `~/Library/Application Support` even with `XDG_CONFIG_HOME` set; Node's `env-paths` returns `~/Library/Preferences/<tool>-nodejs`; platformdirs honors `XDG_CONFIG_HOME` and falls back to `~/Library/Application Support`. Resolve the path yourself and print it in `--help` or a `config path` subcommand.

## Re-runs
- **`--dry-run` runs the same planner as the real run** and stops before the first write, printing the plan and exiting with the status the real run would. A dry-run built as a separate branch diverges from the real path and approves changes the real run doesn't make.
- **A second run converges, it doesn't fail.** Create-if-absent and report `already exists` as success; after a partial failure, re-running finishes the rest. A caller's retry, an agent's included, is the common path.

## Owned elsewhere
- **What the output says to a person watching** — which spans are marked as retypeable, the progress tree — `ui-patterns` → `reference/terminal-output.md`.
- **A full-screen, interactive terminal app** — `tui-design`.
- **The shape of a public JSON contract** — `api-design`.
- **The language layer** — `typescript`, `python`, `go`, in whichever seat owns the code.

## Disclosed — one per language, loaded when the tool is written in it
- `reference/node.md` — `parseArgs`'s throw mapped to exit 2, commander's `exitOverride` codes, the `readline` prompt.
- `reference/python.md` — the `BrokenPipeError` recipe, argparse 3.14 coloring stderr by stdout's TTY, prompts on stderr for `input()` and typer/click.
- `reference/go.md` — `flag` help on stderr and the `ContinueOnError` wrapper, cobra's `SilenceUsage` and flag/arg errors to exit 2.
