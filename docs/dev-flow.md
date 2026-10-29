# Building, testing and pushing on the Mac

Many sessions share one checkout and one Mac (10 cores, 24 GB). What each step costs,
how they share the machine, and the two push modes. Scripts in deploy/; their tests:
deploy/flow-test.sh.

## Costs (26 Oct, quiet Mac)

| step | time | cores |
|---|---|---|
| test-ui after a ui edit | 5 s | 2 |
| test after an edit (the backend's test binary is the long pole) | ~150 s | 1.1 |
| test -Dtest-filter=NAME | ~85 s: it skips running tests (~50 s), not compiling | 1.4 |
| backend build (dev server, qa) | ~90 s | 1 |
| ci after a test of the same tree | ~100 s | 3.8 |

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
