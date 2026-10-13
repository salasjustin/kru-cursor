# Go CLI traps

Reproduced on go1.26.1 (macOS, 2026-10-05) and cobra v1.10.2 (pflag v1.0.9). Go already dies quietly by SIGPIPE on a closed stdout (status 141) — no handler needed.

## `flag`: help on stderr, positionals end parsing
The default `flag.CommandLine` prints `-h` output to **stderr** (exit 0) and stops at the first non-flag argument, so `cmd file.txt -v` leaves `-v` in `flag.Args()`. A `FlagSet` with `ContinueOnError` gives you the streams:
```go
fs := flag.NewFlagSet("cmd", flag.ContinueOnError)
fs.SetOutput(io.Discard)
// … define flags …
if err := fs.Parse(os.Args[1:]); err != nil {
	if errors.Is(err, flag.ErrHelp) {
		fs.SetOutput(os.Stdout); fs.PrintDefaults(); os.Exit(0)
	}
	fmt.Fprintf(os.Stderr, "cmd: %v\nRun 'cmd -h' for usage.\n", err)
	os.Exit(2)
}
```
Reproduced: `-h` to stdout exit 0, `-x` one line + pointer exit 2. Flags-after-positionals has no fix in `flag`; a tool whose users will type `cmd file -v` uses cobra/pflag.

## cobra: usage dumps and exit codes
- **`SilenceUsage: true`** on the root. The default prints the full usage after any `RunE` error, so `connect: connection refused` is followed by a screen of flags.
- **Flag and argument errors exit what `main` says** — usually 1. Mark them and map to 2:
```go
type usageError struct{ error }
root.SilenceErrors = true
root.SetFlagErrorFunc(func(_ *cobra.Command, err error) error { return usageError{err} })
// Args validators don't pass through SetFlagErrorFunc — wrap them too:
root.Args = func(c *cobra.Command, a []string) error {
	if err := cobra.NoArgs(c, a); err != nil { return usageError{err} }
	return nil
}
if err := root.Execute(); err != nil {
	fmt.Fprintln(os.Stderr, "cmd:", err)
	var ue usageError
	if errors.As(err, &ue) { fmt.Fprintln(os.Stderr, "Run 'cmd --help' for usage."); os.Exit(2) }
	os.Exit(1)
}
```
Reproduced: unknown flag → exit 2; `RunE` error → exit 1, one line; an `Args` error left unwrapped exited 1.
- `--help` goes to stdout, exit 0.
