# Review 29 Oct: 2bfe25a3 d740ad4d 0bc9786b ef4d4e13 480cf5fd a62252ed 80bbc328

Correctness review against main. Line numbers are main's. Most severe first.

## 1. high | 2bfe25a3 | src/adminmodels.zig:380, deploy/lab-push.sh:147,218

lab-push uploads every 30 s as soon as training.bin builds.
- Failure: `training()` writes `made = now` (wall clock) into training.bin. push() uploads
  only when `diff -rq "$next" "$STATE/sent"` differs. training.bin (and its .gz) now
  differ on every call, so every 30 s launchd tick uploads the whole view. Today that
  is 3.6 MB gz (11 MB staged; lane-model.json alone is 4.3 MB). The server then extracts
  it, rm -rf's the old copy and curls meio.lol/p/, every 30 s: about 10 GB a day off
  the Mac. hosts.tsv is rounded to 10 min (line 149 comment) precisely to avoid this.
- Not firing yet only because of finding 2 (no training.bin is built). It starts with
  the first `zig build` that refreshes zig-out/bin/meiolol.
- Fix: keep the clock out of the bytes. Either drop `made` and read the time from
  pushed.txt, or have lab-push pass `--now` rounded to 10 min like hosts.tsv.

## 2. medium | 2bfe25a3 | deploy/lab-push.sh:147-148

The Models tab's lab view is missing in production.
- Failure: stage() runs `$ROOT/zig-out/bin/meiolol admin --training`. Nothing rebuilds
  that binary: `deploy/zb.sh test` and ci don't install it. On this Mac it is from
  28 Oct 16:41 and has no `--training` (strings count 0), so it exits with a usage
  error. The `|| echo` sends that to launchd's stderr, so the failure is silent.
- Checked on C01: /var/www/meiolol-training/current/ has no training.bin. The island
  shows "training/training.bin didn't load" on every view but Draft.
- Fix: build the binary lab-push needs before calling it (e.g. `deploy/slots.sh 1 zig
  build` when it is older than HEAD), or fail loudly into a file the admin page shows.
  Fix finding 1 first, or the rebuild turns on the 30 s uploads.

## 3. medium | d740ad4d | src/site/ui/adminmodels.zig:491

The "top-10% picks" chart never shows on the live data.
- Line: `for (vs) |v| if (v != null) break else return null;`
- The `else` binds to the `if`, not the `for`. Checked with a scratch `zig test`:
  `f(&.{ null, 0.5 })` returns null. So the chart is dropped whenever the first day's
  value is null.
- On the box, eval-history.tsv's first rows (2026-10-11) have no pick_top10_win (the
  column came later; the last rows have 0.5326 to 0.5347). `vs[0]` is null, so
  picksChart always returns null.
- The demo data has picks on every row and no test checks for this chart, so tests pass.
- Fix: `for (vs) |v| { if (v != null) break; } else return null;` (as runByRun does at
  line 464).

## 4. low | 2bfe25a3 | deploy/lab-push.sh:147 vs 151; src/adminmodels.zig:375

training.bin's `gpu_seen` is always null.
- Failure: view() reads `hosts.tsv` from the staged dir. stage() writes hosts.tsv four
  lines after it runs `meiolol admin --training`, into a fresh `mktemp -d`. So the file
  never exists when it is read.
- The test "training.bin from a staged lab view" puts hosts.tsv in its fixture, so it
  passes while the real order never sets the field.
- Latent: no view reads gpu_seen yet (A6c will).
- Fix: write hosts.tsv before the `meiolol admin --training` call.

## 5. low | d740ad4d | src/site/ui/adminmodels.zig:314

The All view's Early headline indexes `te.total` without a bounds check.
- Failure: `te.total[o]`. teamEffects() leaves `total = &.{}` when model.md's table has
  no row starting with "total". teamBlock guards the same index (`oi < te.total.len`,
  line 635); the headline doesn't.
- In the ReleaseSmall wasm that is an unchecked out-of-bounds read: garbage text, or a
  trap that kills the island. Today's model.md has the total row, so it doesn't fire.
- Fix: `if (o >= te.total.len) return .none;` before indexing.

## 6. low | d740ad4d | src/site/ui/adminmodels.zig:423-424

Win's learning-curve sentence can convert a negative float to an unsigned integer.
- Failure: `need = (c.last - ll_published) / pd`. Once champion base only's log loss at
  the largest size drops below 0.687, need < 0 and target < n.
  `@intFromFloat(@min((target - n) / r, 1e12))` then converts a negative float to
  u64: undefined in ReleaseSmall, a panic in tests and -Dwasm-dev. The sentence would
  also read "about -2 more doublings".
- Today c.last = 0.6881, so it doesn't fire.
- Fix: only add the sentence when `need > 0`; otherwise say published accuracy is
  reached.

## 7. low | d740ad4d | src/site/ui/wasm/adminmodels.zig:4,42-43; src/site/ui/adminmodels.zig:140

Refresh never fetches models.bin or training.bin again.
- Failure: `asked` is set once and never reset. Refresh lives in ui-admin.wasm and
  re-fetches only admin.bin, live.bin, me.bin and accounts.bin. After a failed fetch the
  tab keeps saying "didn't load: Refresh to try again" until a full page reload. The
  file's doc comment ("so Refresh fetches them again") is wrong too.
- Fix: reset `asked` on failure and when the tab is shown again, or change the message
  to "reload the page".

## 8. low | ef4d4e13 | src/site/html.zig:226

A header search submit can be swallowed for good.
- Failure: before `window.meioSearch` is set, a submit that isn't a Riot ID is
  preventDefault'ed and parked in `meioSearchGo`. If ui-sitesearch.js or its wasm fails
  to load, or `answered` gets no bytes (wasm/sitesearch.zig:80-82), nothing ever follows
  it, and each later Enter is swallowed the same way (`go()` is a no-op once `on`).
- Fix: on script `error`, or after a timeout, let the form submit (or drop the
  preventDefault).

## Checked, no findings

- 0bc9786b: compView's unknown-champion skip is safe: Ctx.champ returns null without
  stats before `c.stats.?`, and nameOf gives "?" for unknown ids. Comp was cleanly
  removed from ChampSelect and its test.
- 480cf5fd: the ticks steps match the test and the fixed puzzles. Tile order in
  counterBasic ("o beats x") matches who wins. Tips are per chapter. Setup.facts is
  added at the end of the union.
- a62252ed: every location with its own add_header includes the snippet; the rest
  inherit the server's. @notes passes the inner request's headers through. vm-web.sh
  installs the snippet before `nginx -t` and reload. Nothing frames the site, uses
  `<base>` or depends on window.opener, so XFO DENY, frame-ancestors, base-uri and COOP
  break nothing. The renderer serves .js and .wasm with correct types under nosniff.
- 80bbc328: the comp fingerprint is compared with the old page's, so reload goes out
  only when the comp comes, goes or changes. The comp is rendered into the arena while
  the poller lock is held. The Mac shim goes through bridge.js too, so `reload` works on
  both shells. The comp HTML is written after the app island.
