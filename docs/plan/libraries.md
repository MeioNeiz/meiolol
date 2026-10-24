# Plan: our Zig libraries toward Rust-crate quality

Jacob 21 Oct: where Rust would be better here it is mostly the ecosystem (hyper and
axum, rustls, reqwest, governor, egui, Velopack), plus compile-time memory and race
safety. Instead of a rewrite, bring our own pieces up to what those crates give, and
match the safety with checks: ReleaseSafe builds, fuzz tests, ThreadSanitizer. Slow
checks stay out of `zig build ci` and run where a release happens (Jacob: no tests
that slow everyday development).

## Done

- Desktop releases (21 Oct): deploy/desktop-release.sh is the only way an exe ships;
  ReleaseSafe (was ReleaseSmall: no bounds or overflow checks); Ed25519-signed exe
  and manifest with an offline release key and a rollback guard (sign.zig, what
  Velopack or self_update give); `zig build desktop-check` (ThreadSanitizer) and
  `desktop-fuzz` (architecture.md "Desktop window"). Fuzzing found two crashes on
  damaged curves files: View.lane's sums underflowed and a flipped minute negated
  -32768 in i16 (both saturate now). `zig build --fuzz` exits 0 when a fuzz test
  crashes: the first release went out past one (withdrawn before any web round
  published it); the script now fails on the log's "terminated with signal"
- HTTP server limits (23 Oct, what hyper and axum give): httpd.Limits per server, shared
  by the Your games API, the crawler's proxy, serve.zig and the mocks. A connection cap
  (503 past it), 64 KB heads (431), a Content-Length body cap (413; chunked bodies 411,
  as nginx and our clients state a length), malformed heads 400; idle, head and handler
  timeouts from one watchdog task per server that shuts a stalled socket down. Each sits
  behind nginx's own (/api/ 1 KB bodies, /auth/ 4 KB, 30 s; render 15 s, /admin/api/
  120 s): API 128 connections, 16 KB, idle 60 s, head 30 s, handler 60 s; serve 256,
  handler 180 s; proxy 64, no body, no idle or handler timeout (the API keeps pooled
  connections there; a request waits for a Riot slot)
- ThreadSanitizer over the backend (24 Oct): `zig build backend-check` (par.zig,
  store/ahead.zig, httpd's watchdog and slot table, the proxy, ratelimit, the API's
  keep-alive test and the site pipeline's parallel load and filters) and a 90 s fake
  crawl of the TSan build with the proxy serving (`zig build backend-tsan`; how to run:
  architecture.md "Crawler"). No races found. TSan works on macOS with 0.17 (a planted
  race is reported)
- Backend fuzzing (24 Oct): `zig build backend-fuzz` (outside ci) searches fuzz tests
  from good fixtures (core/fuzz.zig mutate) over Riot match JSON parsed and stored
  (riot/match.zig), timeline JSON to the compact form and back, a damaged compact
  timeline (timeline.zig), a damaged digest or stored gzip blob (digest.zig), a damaged
  pack (rawpack.zig), raw HTTP bytes through std.http.Server, httpd.admit and the API's
  handle (api/root.zig, /api/ and /auth/), and the Your games report from a damaged
  match and stored timeline (api/game.zig). deploy/backend-fuzz.sh [REV] runs it on a
  clean checkout and fails on the log (`zig build --fuzz` exits 0 on a crash and on a
  test that doesn't build); before a crawler, storage or API change. ~300K inputs per
  test, 2 to 45 min each on the Mac, found: a POST body cut short and left unread
  crashed any of our servers in std's respond() (httpd.admit closes after a body
  now); a red player's lane diff of -32768 overflowed on negation in the report
  (saturates); timeline timestamp deltas past i64 overflowed in encode and decode
  (BadTimeline, by reading the code, the fuzzer did not get there); bans repeating a
  pick turn failed the bans key, losing the match in the crawler and stopping
  `rebuild` (the first ban stays). Each has a regression test. Setup: -ffuzz
  instruments sqlite3.c, which Zig's fuzzer has no comparison hooks for, so sqlite
  builds with -fno-sanitize-coverage; the fuzzer checks every input for leaks, so
  harness state lives per input

- One `net` module, steps 1-4 (24 Oct): src/net/ (build module "net", std only, a
  module doc with an example, imported by backend, app, mock and desktop; backend-check,
  desktop-check and desktop-fuzz run its tests). ratelimit.zig (governor: global and
  per-key windows corrected from the server's limit and count headers, priority,
  pacing, save/load; riot/ratelimit.zig keeps routes and the personal key's spec),
  sign.zig (Ed25519 in text bound to a context; desktop/sign.zig keeps keys and
  contexts, signatures byte for byte as before), server.zig (httpd.zig moved, as is),
  pinned.zig (HTTPS GET trusting one root and no host name, from lcu/https.zig). Found
  on the way: a chunked answer after a first chunk whose size overflowed body + size
  panicked (the desktop app is ReleaseSafe), saturating now, regression test

## Next, by how exposed the code is

1. HTTP server limits: done 23 Oct (above)
2. Backend fuzzing: done 24 Oct (above). Could still add: a nightly run on the
   gpu-box, the crawler's other Riot replies (league, mastery, account ids)
3. ThreadSanitizer: done 24 Oct (above)
4. `net` module: steps 1-4 done (above). Step 5, client timeouts and a safe fetch:
   std.http.Client has no timeout (ConnectTcpOptions.timeout is never read), so a
   stalled server blocks a crawl thread or the desktop's "Signing in..." for good.
   Cancelling the call returns in ~200 ms on macOS and Windows (Io.Threaded), so plan
   net.deadline.within(io, limit, func, args) on Io.Select. Blocker found: std's
   fetch() panics (bodyErr().? null) when a Content-Length body read fails, on cancel
   AND on a plain connection reset mid-body: desktop update.zig and device.zig and
   ddragon.zig all call fetch. So step 5 also needs net's own GET (request,
   receiveHead, bounded body read, connection closing on error, as riot/client.zig
   does) and those three moved to it. Repros and handover: net-notes.md of the
   2026-10-23-progress run
5. Desktop release checks: done 24 Oct. deploy/desktop-shots.sh (`zig build desktop-shot
   --compare`: every state from pinned inputs, pixel for pixel against an approved set,
   NAME.diff.png for a change; renders are deterministic, a one-word change shows as 289
   red pixels) and deploy/desktop-smoke.sh (`meiolol-desktop --self-test` on the
   gpu-box's Windows: the files load, a lane card per role, ~6 s). The release script
   runs both (accounts.md AC5)

## Not planned

A UI toolkit, async HTTP/2, Windows API bindings (use dvui, zigwin32 when needed) and
autograd for nn/ (the Python lab cross-checks the nets).
