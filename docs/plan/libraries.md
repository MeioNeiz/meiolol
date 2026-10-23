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

## Next, by how exposed the code is

1. HTTP server limits: done 23 Oct (above)
2. Fuzz the backend's untrusted input: Riot match JSON (riot/match.zig), timeline
   decode (riot/timeline.zig, digest.zig), API request handling (api/root.zig), rawpack.
   Same pattern: a fuzz test from a good fixture (core/fuzz.zig mutate), searched in a
   step outside ci, e.g. before a crawler or API change, or nightly on the gpu-box
3. ThreadSanitizer over the parallel code (par.zig, store/ahead.zig, the crawler's
   threads): a step like desktop-check, run by hand after a threading change
4. One library-grade `net` module (like tpl/ and nn/: std only, own tests, a worked
   example in its header): the server limits, LCU TLS (lcu/https.zig), the rate limiter
   (riot/ratelimit.zig), signing (desktop/sign.zig). A Zig upgrade's std.http and
   std.Io changes then land in one place
5. Desktop release checks still to add: screenshot comparison (desktop-shot against
   approved PNGs) and a Windows smoke start on the gpu-box (`--self-test`: load the
   files, exit)

## Not planned

A UI toolkit, async HTTP/2, Windows API bindings (use dvui, zigwin32 when needed) and
autograd for nn/ (the Python lab cross-checks the nets).
