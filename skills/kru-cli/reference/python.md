# Python CLI traps

Reproduced on Python 3.14.3 (macOS, 2026-10-05), typer 0.27.2 (which vendors click as `typer._click`) and platformdirs 4.12.3.

## The broken-pipe recipe
`cmd | head -1` gives a `BrokenPipeError` traceback and exit **120** (the traceback's exit 1, then the failed flush at shutdown). The Python docs' recipe (`signal` module, *Note on SIGPIPE*), around the whole `main`:
```python
try:
    main()
    sys.stdout.flush()
except BrokenPipeError:
    os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())  # the shutdown flush goes nowhere
    sys.exit(0)
```
Reproduced: empty stderr, exit 0, and `set -o pipefail` stays green. The docs' version exits 1; 0 is the `SKILL.md` contract. `signal.signal(SIGPIPE, SIG_DFL)` also silences it, and kills the process on a socket's broken pipe too.

## argparse
- **3.14 colors usage errors by stdout's TTY.** `ArgumentParser(color=True)` is the default and its check reads `sys.stdout`; usage errors go to stderr, so `cmd --bad 2>err.log` from a terminal writes escapes into the log. `ArgumentParser(..., color=sys.stderr.isatty())` — reproduced clean; help still colors only when stdout is a TTY too.

## Prompts
- For `input()`, write the prompt to stderr yourself (`print(q, end="", file=sys.stderr, flush=True); input()`) after checking `sys.stdin.isatty()`.
- typer/click `confirm`/`prompt` take `err=True` to put the prompt on stderr. With `abort=True` and no TTY, `confirm` exits 1 with `Aborted.` on stderr.
- typer's `pretty_exceptions_show_locals` is `False` by default; leave it there — locals in a traceback are tokens in a CI log.

## Exit
- `sys.exit("message")` prints the message to stderr and exits 1; `sys.exit(None)` exits 0.
