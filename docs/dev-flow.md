# Building, testing and pushing on the Mac

Many sessions share one checkout and one Mac (10 cores, 24 GB). What each step costs,
how they share the machine, and the two push modes. Scripts in deploy/; their tests:
deploy/flow-test.sh.

## Costs (29 Oct, Mac at load 10-25)

| step | time |
|---|---|
| test-ui after a ui edit | 28 s (gpu-box 4 s) |
| test after a backend edit | ~100 s: backend test compile 42 s, its run 50-60 s (slow tests: docs/plan/build-speed.md BS4) |
| test after a ui edit | ~175 s at load 25: the backend test compile and run; the tests get stub islands, ci and the dev server build the real 41 (~50 s CPU) |
| test with nothing changed | ~10 s (compile-error checks rerun: Zig caches no failed compile) |
| backend build (dev server, qa) | ~80 s |
| deploy build (ReleaseSafe, box target) | ~185 s (gpu-box 230 s) |
| -Dtest-filter=NAME | skips running tests, not compiling them |

A zig compile runs on one core, so builds run side by side, not one at a time.

## Build slots

deploy/slots.sh hands out 6 slots across sessions (MEIOLOL_SLOTS); a run takes about the
cores it keeps busy: ci 3, anything else 1. A holder's `zig build` runs at most
2 x weight compiles at once (-j via MEIOLOL_ZIG_JOBS and the ~/.local/bin/zig shim); the
dev server's watch 2. First come first served, with a smaller run
starting beside a waiting bigger one when it leaves that one's slots free. Holders and
waiters: `deploy/slots.sh status`. A zig build outside zb.sh: `deploy/slots.sh 1 zig
build ...`.

Builds on the gpu-box instead (faster, off the Mac's cores), and one view of both
hosts' load: docs/compute.md "Builds on the gpu-box".

deploy/zb.sh runs builds and tests in slots and answers a check (test, test-ui, ci) from
a run that started after the request, finished or still going: that run saw the
request's saved files.

## Commits and pushes

- deploy/commit.sh writes site-files.txt from the commit's own tree, in build tree
  "hashes" (one slot), so a commit never waits for a push's ci
- The pre-push hook runs ci on a clean checkout of the pushed commit (build tree "ci",
  3 slots); a push that changes nothing in src, deploy or build files skips it
- deploy/push.sh holds its own lock, so builds go on during a push

Two modes, for every session (`deploy/push.sh --mode fast|bulk [MIN]`, `--status`):

- fast (default): `deploy/push.sh REV` pushes now, grouped with the other waiting
  pushes (one ci for the group; a group whose ci fails is retried smaller, down to REV
  alone). Then `deploy/box.sh wait-deployed`
- bulk: `deploy/push.sh REV` queues REV and returns. Every MIN minutes (default 30) a
  timer pushes the queue as one: one ci, one deploy, one live check. A commit whose ci
  fails is left out with those after it, the older ones go, and a notice says so;
  `--status` lists it. `--flush` pushes the queue now; `--mode fast` flushes it and
  stops the timer. Sessions don't wait-deployed: pages are checked on the dev server

Why bulk exists: each deploy is ~3.5 min on the Mac, then a site round on the box
(160-400 s) and a 25 min cache warm (deploy/cache-warm.sh); 48 deploys in the night of
25-26 Oct kept both busy and the site round slowed 2.5 times.

## Seeing pages

`deploy/dev.sh` serves the shared tree's pages at http://localhost:8080 from data/snap,
rebuilding the backend on each edit (`zig build backend --watch`; log
.zig-cache/dev-watch.log). One server for all sessions: started again, it prints where
it runs. A build that fails keeps the last good binary, so one session's half-done edit
holds the others' changes back until it compiles. Live checks (meio.lol) are for what
only the box shows: real data volume, render swap, nginx.

data/snap (15 GB) takes ~22 min to load on the gpu-box (30 Oct: people tallies 982 s
Debug, 1228 s ReleaseSafe, reading the database), 3.4-4.8 GB peak. For page checks and
screenshots, `deploy/dev.sh --small` serves data/snap-small (deploy/snap-small.sh, built
on first use in ~80 s and again once data/snap changes, beside it and swapped in, so small
servers already running stay on the old copy): 1 in 20 games with their rows, so every
page renders with the same shapes at 1/20 the counts; curves and builds are data/snap's,
linked. Loads in ~100 s, ~1.3 GB private (640 MB of it the builds files, whatever the
games) plus ~1 GB of mapped curves and database. `--no-watch` builds once, into
zig-out/dev-PORT, and serves, so edits meanwhile don't restart the load. Full servers are
capped at 2 on the machine (MEIOLOL_DEV_MAX), small ones at 3 apart
(MEIOLOL_DEV_MAX_SMALL).

## ui.wasm sizes

Each page family's ui.wasm has a gzip budget (40 KB, the login families 64 KB; stack.md),
measured as served: the .gz the site writer makes for nginx (std flate at its default
level, src/store/raw.zig), the same bytes on any host. That runs 60-390 B over GNU gzip
-9 on our files.
`zig build ci` and `zig build ui-sizes` print each family against its budget and the
last pushed main's size, marked at 90%. On growth over 200 B or a failure they list what
grew: functions in raw bytes with their files, our callers of grown std code, and what
grew in most families at once (a shared component). src/tools/wasmsize.zig; baselines in
.git/meiolol-wasm-sizes/<sha>, recorded by any clean tree's full run (pre-push ci's).
`zig build ui-sizes -- --base REV` compares with another recorded commit. Symbols come
from a second build of each family with names (strip = false), built beside it; on
that file `wasmsize --list` prints every function, `--numbers` std's number formatting
and which of our functions keep each piece.

Number formatting in wasm: src/tools/fmtlint.zig (in ci) flags format strings with numeric
placeholders and direct calls of std's number formatters (printIntAny, printFloat, ...) in
src/site/ui, src/tpl and the src/core files they import. Each call site is code in every
family it reaches, and each int type std prints adds ~170 B gz. Numbers go through
phrase.num or fmt.write; old ones are counted per file in src/tools/fmtlint-allow.txt (the
follow-up list; one more copy in that file fails), a line that never reaches wasm says
`// fmt-ok: <why>`.
