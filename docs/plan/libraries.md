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

## Next, by how exposed the code is

1. HTTP server limits (what hyper and axum give): request header and body caps,
   read and idle timeouts, a connection cap in src/httpd.zig, shared by the Your games
   API, the crawler's proxy and serve.zig. nginx in front already rejects malformed
   HTTP, so limits and timeouts are the gap
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
