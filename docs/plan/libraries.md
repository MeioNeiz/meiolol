# Plan: our Zig libraries toward Rust-crate quality

Where Rust would be better here it is mostly the ecosystem (hyper and axum, rustls,
reqwest, governor, egui, Velopack), plus compile-time memory and race safety. Instead of
a rewrite, bring our own pieces up to what those crates give, and match the safety with
checks: ReleaseSafe builds, fuzz tests, ThreadSanitizer. Slow checks stay out of `zig
build ci` and run where a release happens (Jacob: no tests that slow everyday
development).

## Status

- Desktop releases: deploy/desktop-release.sh is the only way an exe ships. ReleaseSafe;
  Ed25519-signed exe and manifest with an offline release key and a rollback guard
  (sign.zig); `zig build desktop-check` (ThreadSanitizer), `desktop-fuzz`,
  deploy/desktop-shots.sh (`zig build desktop-shot --compare`: every state from pinned
  inputs, pixel for pixel against an approved set, NAME.diff.png for a change) and
  deploy/desktop-smoke.sh (`meiolol-desktop --self-test` on the gpu-box's Windows, ~6 s)
  all run in the release script (arch-app.md "Desktop window", accounts.md AC5)
- HTTP server limits (what hyper and axum give): httpd.Limits per server (Your games
  API, the crawler's proxy, serve.zig, the mocks): connection cap (503), 64 KB heads
  (431), Content-Length body cap (413; chunked 411), malformed heads 400; idle, head
  and handler timeouts from one watchdog task per server. Each sits behind nginx's own
  limits; the values per server are in the code
- ThreadSanitizer over the backend: `zig build backend-check` (par.zig, store/ahead.zig,
  httpd's watchdog and slot table, the proxy, ratelimit, the API's keep-alive test, the
  site pipeline's parallel load and filters) and a 90 s fake crawl of the TSan build
  (`zig build backend-tsan`; architecture.md "Crawler"). TSan works on macOS with 0.17
- Backend fuzzing: `zig build backend-fuzz` over Riot match and timeline JSON, ladder
  pages, match id lists and mastery replies (through the writer; mastery's blob must
  read back), compact timelines, digests and gzip blobs, packs, raw HTTP through
  std.http.Server, httpd.admit and the API, the Your games report, and a Your games
  lookup against riot/fake.zig with damaged account, region, league and match id replies
  (Fake.damage). Run deploy/backend-fuzz.sh [REV] (a clean checkout) before a crawler,
  storage or API change; ~300K inputs per test, 2 to 45 min each on the Mac. Each fault
  found has a regression test
- Nightly on the gpu-box: deploy/fuzz-nightly.sh (timer meiolol-fuzz, 02:30, gpu-box.sh
  install) runs backend-fuzz.sh over origin main from its own clone (~/ml/fuzz/meiolol,
  the corpus kept between nights) as a run in ~/ml/runs, so League pauses it and the
  admin Training tab lists it; crash inputs kept in the run dir. Its outcome rides the
  archive pull's disk report into health.sh (docs/health.md)
- Fuzzing gotchas: `zig build --fuzz` exits 0 on a crash and on a test that doesn't
  build, so the scripts fail on the log ("terminated with signal"); given several fuzz
  tests in one run zig searches only one, so the scripts run each on its own
  (desktop-fuzz takes -Dtest-filter); sqlite builds with -fno-sanitize-coverage (no
  comparison hooks for C); the fuzzer checks every input for leaks, so harness state
  lives per input; on x86_64 Linux the fuzz tests build with LLVM (use_llvm): Zig's own
  x86_64 Debug backend emits no coverage, and the fuzzer searched blind (the report's
  "pcs_len was zero", which the scripts fail on)
- `net` module (src/net/, std only, imported by backend, app, mock and desktop; its
  tests run in backend-check, desktop-check and desktop-fuzz): ratelimit.zig (governor:
  global and per-key windows set from the server's limit and count headers, priority,
  pacing, save/load), sign.zig (Ed25519 in text bound to a context), server.zig
  (httpd), pinned.zig (HTTPS GET trusting one root), deadline.zig (within(io, limit,
  func, args): a call beside a timer on Io.Select, cancelled past the limit, ~200 ms to
  return) and client.zig (get/send on std.http.Client without fetch(), which panics on
  a failed body read; no redirects, a body cap, ShortBody on a cut body). Limits:
  device.signIn 20 s, update.zig manifest 30 s and each file 2 min plus 64 KB/s,
  ddragon 60 s, Riot 30 s per try (retried), 5 min through the proxy (not retried),
  the League client 10 s a request (pinned.zig; a hung client is a client error and the
  next poll tries again)

## Next, by how exposed the code is

1. `net`: a stall limit (bytes per interval) instead of the whole-request one for big
   downloads (update.zig sets each file's limit from its size)

## Not planned

A UI toolkit, async HTTP/2, Windows API bindings (use dvui, zigwin32 when needed) and
autograd for nn/ (the Python lab cross-checks the nets).
