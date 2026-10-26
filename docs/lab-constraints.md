# Lab constraints: known traps and their rules

Read this before your first lab run (shared bug registry: research/questions/
agent-ml-practice.md C16, C17). Add an entry when you hit an error or silent wrong
result whose cause wasn't obvious, or fix the same thing twice: symptom, cause, rule
(commit). Edit an entry in place when it changes; drop it when the trap is gone (git
keeps it). Failed lab-runs are logged on the gpu-box (`deploy/lab-run.sh failures`:
run, exit, last error line, args; `wait` says when one failed).
Same error twice on one line of work: restore the last good state, don't try a third fix.

## Data

- Silent all-NaN inputs: a snapshot without seat_stats.tsv gives Row.stats all NaN and
  empty profiles, and win-comp then scores exactly like ratings. Candidates declare
  needs_stats (harness.fit fails with error.NoSeatStats); check inputs aren't all NaN
  before trusting a run (9b2d122)
- snapshot.sh opens the db plainly, not `?mode=ro` (a WAL without -shm fails to open
  and the patch loop runs empty, leaving Data Dragon values NaN); it dies when no
  patches are found (30450b4)
- Lab commands slow (rows from SQLite, 15-37 s) after copying a snapshot means the pack
  was ignored: a "from SQLite" note on load. Pack manifests stamp mtime in whole seconds
  because rsync drops nanoseconds (src/lab/pack.zig)
- rows.Data rows are in match_id order, games in start order: index a game's rows by
  counting sort on Row.game, never by position (effects.zig, 4ace29b)
- Per-row inputs built from outcomes are cross-fitted: from a fit without that row's
  fold (22adcde). Assign cross-fit folds by a hash of the game's identity
  (winnet.crossFold: start, platform) or a seeded random draw, never from row order:
  row-index hashes give optimistic out-of-fold offsets
- rank_start comes from rank_history, which starts on 12 Oct 2026: check its coverage
  on the snapshot's dev games before a rank model

## Harness and nets

- Name the reference model and its run in every comparison; both sides from the same
  build and snapshot (afb4a4e)
- Different seeds must give different predictions; check it (9ace58d)
- cand-built commands (netcheck etc.) need `--build-arg -Dcand=src/lab/cand/win-ratings`
  (or win-comp): build.zig's default candidate is src/lab/cand/base. The log's first
  line names the candidate ("vs win-ratings"); check it
- Variance components: half-samples (no duplicates, Var / 2), not the Poisson bootstrap,
  which duplicates games and makes thin pair cells look consistent (d582b76). Report a
  block only above a shuffled-outcome null (`effects --null N`, 4f3d007): on cells with
  1-3 games the estimate is biased up on pure noise
- Torch on the gpu-box: lab-run caps it at 0.95/gpu.slots of the card (3 slots: 3.16
  GiB) whatever runs beside it. Keep big tensors on the CPU and move batches. State jobs
  peak at 9.5-15.8 GB RAM: one at a time (`lab-sweep --live 1`), and watch a sweep's
  first job end before queuing the rest

## Runs, builds and the shared tree

- Long runs only through deploy/lab-run.sh (own process group, survives the session);
  plain background shells die with the pane
- Zig 0.17 is ~/.local/bin/zig; Homebrew's is 0.16. Put ~/.local/bin first on PATH for
  zig build and lab-run, in resumed sessions and in launchd scripts ("pinned to Zig
  0.17.x, found 0.16.0" means it wasn't)
- Remote commands: a plain ssh's PATH lacks ~/bin (zstd lives there): put it on PATH
  (4447cdb)
- lab-run ARGS are joined with spaces and split again by bash: one-word values, or
  --literal; write `$HOME/` (single-quoted locally) inside words, since `~` expands only
  at a word's start
- Binaries are keyed by every build input: any lab source commit between starts changes
  the key and `--no-build` refuses. Queue a batch with `--commit SHA` (or `--bin KEY`
  from the first run's meta): one build per candidate
- Keep a start's whole output (`> log 2>&1`); never grep it, or a build failure shows
  only "build failed: not started". A failed build uses no test look: retry once
- Commit by path takes the whole working file, whoever edited it, and `-Dtest-filter`
  only compiles what the tests reach. Run `git diff FILE` right before committing a
  shared file; if others' hunks are in it, commit a clean copy (yours on HEAD's version)
  and put theirs back. Test on `git archive HEAD` in your scratchpad plus your files
  (symlink zig-pkg) when others' uncommitted edits break the shared tree

## Zig 0.17

API renames and semantics: docs/zig-0.17.md; check APIs with LSP hover. Not there: float
format has no sign flag (`{d:+.5}` fails at comptime); print the sign yourself.

## gpu-box and CUDA (docs/compute.md)

- The watcher pauses every run while League is up: CPU work goes to the Mac (lab-run
  start with no HOST); queue only real GPU work on the gpu-box
- A WSL restart or reboot kills running jobs (back in under ~2 min): tell the sessions
  using it first; lab-watch reruns live runs at most twice
- CUDA only on the gpu-box (libcuda.so.1 is WSL's, /usr/lib/wsl/lib): `--res gpu` jobs
  there only; kernels are PTX for sm_86, JIT-compiled at load
- Kernels: use kernels.zig's exp (ex2.approx; nvptx has no libcall for @exp); take
  pointers and scalars only, shared layout structs live in device memory (extern)
- A Mac lab-run needs ~/ml/snaps/<snap> linked to data/<snap>; snapshot.sh push makes
  it, make it by hand for older snapshots

## Typical times (to judge whether a run is stuck)

- lab-exp run ~2 min: ~80 s build, ~16 s scoring (gpu-box). Rows load 0.14 s packed,
  15-17 s gpu-box / 31-37 s Mac from SQLite. eval of 26.6k games: 7 s gpu-box, 13 s Mac.
  Pack write 17-34 s
- Draft net epoch at 175k games: 0.52 s on the 3080, 2.02 s on 20 threads, 11.9 s one
  core. netcheck big trial ~2 s (fit 0.6 s), +250 MiB GPU memory. 40 trials x 20 epochs
  at 16x data ~40 min on the 3080
