# What the `go` directive gates

The installed toolchain decides what *compiles*; the `go` line in `go.mod` decides how some of it *behaves*. A module pinned at `go 1.21` built by go1.26 keeps 1.21 semantics for everything in the gated column. A toolchain can drop a gate: go1.27 did for 1.23's timers. Read the directive before reaching for anything below; bump it (`go mod edit -go=1.N && go mod tidy`) as its own reviewed change, since the gated rows change runtime behavior without a diff in the code.

| `go` ≥ | Gated on the directive (behavior changes) | Available on the toolchain (new API) |
|---|---|---|
| 1.21 | — | `context.WithoutCancel` / `AfterFunc` / `WithTimeoutCause`; `log/slog`; `slices`, `maps`; `min`/`max`/`clear`; `sync.OnceFunc`/`OnceValue` |
| 1.22 | **per-iteration loop variables** — `for _, tc := range cases { t.Run(…, func(){ tc }) }` is safe only from here; below it every closure sees the last `tc` | `http.ServeMux` method+path patterns, `r.PathValue`; `math/rand/v2`; `sql.Null[T]`; `cmp.Or` |
| 1.23 | **timer channels unbuffered and timers GC-able without `Stop()`** — a `time.After` in a `select` loop stops leaking, and a `t.Reset` race on a drained channel behaves differently. Gated through go1.26 only (1.27 row) | range-over-func (`iter.Seq`/`Seq2`); `slices.Collect`, `maps.Keys`/`Values` return iterators; `unique` |
| 1.24 | — | `omitzero` JSON tag; `os.OpenRoot`/`os.Root`; `t.Context()`; `b.Loop()`; `strings.SplitSeq`/`Lines`; `go.mod` `tool` directive + `go get -tool` / `go tool X`; `runtime.AddCleanup`; `crypto/pbkdf2`, `crypto/hkdf`, `crypto/sha3` in stdlib; generic type aliases |
| 1.25 | container-aware `GOMAXPROCS` (drop `automaxprocs`) | `net/http.CrossOriginProtection`; `sync.WaitGroup.Go`; `testing/synctest` stable (`synctest.Test` — the 1.24 experimental `synctest.Run` is gone); `reflect.TypeAssert[T]`; `encoding/json/v2` behind `GOEXPERIMENT=jsonv2`; vet: `waitgroup` misuse, manual `host:port` (use `net.JoinHostPort`) |
| 1.26 | Green Tea GC default | `errors.AsType[T]`; `new(expr)`; `slog.NewMultiHandler`; `t.ArtifactDir()`; `httputil.ReverseProxy.Director` deprecated → `Rewrite`; `go fix` rewritten on `go/analysis` (modernize fixers: `rangeint`, `minmax`, `stringscut`, `omitzero`, …); `go tool doc` removed — `go doc` |
| 1.27 | **un-gates 1.23's timers** — the `asynctimerchan` GODEBUG is removed, so timer channels are unbuffered for every module on this toolchain whatever its directive; `asynctimerchan=1` fails the build from a `go.mod` `godebug` line and the start from the env | `encoding/json/v2` + `encoding/json/jsontext` GA; `encoding/json` runs on the v2 implementation (same behavior, error text may differ; `GOEXPERIMENT=nojsonv2` restores v1); `go fix`'s `waitgroup` modernizer renamed `waitgroupgo` (vet's `waitgroup` misuse check keeps its name) |

Deprecated and still compiling: `runtime.GOROOT()`, `reflect.PtrTo` (→ `PointerTo`), `cipher.NewCFB*`/`NewOFB`, `rsa.EncryptPKCS1v15` for new encryption, `runtime.SetFinalizer` (→ `AddCleanup`). `staticcheck` flags them; `vet` doesn't.

`math/rand` → `math/rand/v2` renames `Intn` → `IntN`, drops seeding (auto-seeded) and removes `Read` — still not cryptographic; `crypto/rand` for anything a client can't be allowed to predict.
