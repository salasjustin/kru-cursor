# Shutting down a service

A long-running Node process stops cleanly only if it drains in-flight work, then lets the event loop empty. Reproduced on **Node v24.20.0** (`darwin/arm64`, 2026-10-05). Docs: `process.html#signal-events`, `http.html#serverclosecallback`, `http.html#servercloseallconnections`.

## The pattern

```js
function dieBy(signal) {          // the shell reads 128+n and stops its loop
  process.removeAllListeners(signal);
  process.kill(process.pid, signal);
}
function shutdown(signal) {
  process.once('SIGINT', () => dieBy('SIGINT'));                  // second Ctrl-C: out now
  setTimeout(() => server.closeAllConnections(), 10_000).unref(); // deadline for streams
  server.close(() => {
    // close the db pool, queue consumer, intervals here
    dieBy(signal);
  });
}
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
```

Run against a server holding an open streaming response: `SIGTERM` with the deadline at 500 ms closed the stream at the deadline and the process died by `SIGTERM` (shell status `143`); a second `SIGINT` mid-shutdown died by `SIGINT` at once (`130`).

- **Die by the signal.** The calling shell stops its loop only for a child the signal killed — the `cli` skill, *The exit status is the verdict*.
- **`once`, not `on`.** With `on`, the second signal re-enters `shutdown` and its `server.close()` calls back with `ERR_SERVER_NOT_RUNNING`.
- **`.unref()` on the deadline timer**, or it holds the process for its full duration after everything else has closed — measured: a 1.5 s timer delayed exit by 1.5 s.

## What holds `close()` open
- **Idle keep-alive sockets don't.** `server.close()` closes idle connections itself: with one idle keep-alive client, the callback fired in 0 ms.
- **An active response does, indefinitely.** One open `text/event-stream` response kept `close()` pending until `closeAllConnections()` ran at the 3 s mark. SSE and long-polling responses never end on their own; every one needs the deadline.
- **`close()` stops the listener, not the process.** The process exits when nothing else is referenced: a database pool, a Redis client, a `setInterval`, a queue consumer each keeps it alive after the server is gone. Close them in the `server.close` callback; a process that won't exit after it fires has one of these still open.
