# Lab tooling: what the modelling sessions lost, and the fixes

From the transcripts of ~25 model sessions, 12-13 Oct 2026 (comp features and the neural
net programme; meiolol-16). Each line: what happened, cost, fix (done: commit; else
backlog, in priority order at the end). Research behind the ranking: meiolol-e3,
research/questions/agent-ml-practice.md.

## Builds and binaries

- --head builds 5-13 min on the Mac for runs of seconds (ba: 16 netcheck starts ~45
  min; 1c's smoke 13 min build, 2 s run). Cause: zig 0.17 keeps fetched packages
  (~560 MB) in the build root's zig-pkg, so every fresh temp tree unpacked them again
  and deleted them; 9-15 identical ReleaseFast builds at once, both targets each; Mac
  load 27-38. Done cddffa0: content-keyed store, one build lock, fixed mirror tree,
  target host only; builds on the gpu-box itself (lab-run, late 2026-10-13)
- --no-build ran another session's rebuild of a shared prefix (49's compcheck folds
  exit 2; 3f repeated a dev look exactly; 0d hand-audited binary hashes of every pair).
  A failed build hidden by `| tail` ran the old binary (3f, a dev look spent). Done
  cddffa0: binaries never replaced, --bin KEY, `src`/`harness` in meta
- Shared tree mid-edit broke builds for everyone (crawl.zig, tpl.zig, setnet.zig);
  each session built its own clean copy (~10 min, 7+ times); `git archive` clones to
  pin a test look to a commit. Done cddffa0: --head/--commit build from the commit
- Broken commits on main blocked every push 30+ min (33a87ba, 0783747; lab_main.zig
  importing an uncommitted file, deecc3f): lab_main.zig is every command's dispatch,
  hunks get swept into other sessions' commits (7579f6f). Backlog: pre-commit refuses
  an @import of a path missing from the staged tree; commands register per file
- Homebrew zig 0.16 first on PATH: lab-run, deploy (21:15) and 4 sessions failed. Done
  cddffa0: ~/.local/bin pinned in lab-run, build-tree, on-push, pre-commit
- Scripts rewritten while running: lab-exp.sh exit 2 on the one test look (a3bd822),
  misdiagnosed; lab-run edit broke a sweep start. Done cddffa0 for lab-run (main
  wrap); backlog: lab-exp.sh, lab-sweep.sh, snapshot.sh

## Data and snapshots

- Mac snapshot lacked seat_stats.tsv: win-comp silently became plain ratings (f1
  caught it by eye); draft --export without Row.stats; snapshot.sh's Data Dragon open
  failed so every value was NaN (30450b4); stale packs silently load from SQLite
  (15-37 s a run, 3 manual repacks). Guard 9b2d122 (needs_stats); done cddffa0: snap
  hash in meta (input files' sizes, equal across hosts). Backlog: NaN share per
  declared input in fit rows (fail at 100%), stale pack an error or auto-repack
- Population and counts differ by tool: duration >= 900 only in the harness (88's
  8,608-game vs db's 8,500-game dev reported side by side); 3c vs 2a timeline-15 sets
  (10,604 vs 10,618); four different "games" counts for one snapshot; winchance has its
  own dev split. Backlog: one population function, row-set hash in every result
- Leaks: participants.tier (post-game rank) used as a feature; a gold14 "own rank"
  gain reported as usable in champ select; resid trained on in-sample offsets. Fixed
  9eb6982 (rank_start), f1's cross-fit; backlog: availability tag per rows field

## Comparisons and results

- Sign conventions: at least four live at once (folds.tsv + is net better, netcheck
  stdout and nn-results - is better, style + better, gains A - B). Several retractions
- Wrong reference: gold14-a's "rank gain" was the whole model vs base rates (6
  learned.md commits in 70 min); a false confound from a candidate built on 3c-team
  not team2; runs compared across different game sets (ldai 8,500 vs 7,992)
- ~15 hand-written comparison scripts (pair.py, summ.py, pairs.py, paired.sh, t15.py,
  final.py, ldai_table.py, perfold.py); numbers then hand-copied into model.md,
  learned.md and nn-results/*.tsv (wrong commit hashes twice). Backlog, next:
  `meiolol-lab compare A B` (src/lab/compare.zig, written): recomputes log loss, AUC,
  accuracy from per-game preds, B - A with the sign in words, paired per game,
  refuses different labels, game sets, harness builds or snapshots, --emit writes the
  nn-results row
- exp final had no per-row output (a test look rerun, ~45 min). Fixed c26ffa8
- Train-fit effect tables reported as test results (3f, pushed then dropped); dev-val
  "not detected" overturned by the folds minutes later (b9c69fa, 2e52957)
- Test looks outside the ledger: fields --final, scaling variants scored on test,
  style looks counted by hand, scratch --lab dirs. Done: SNAP/test-looks.tsv, appended
  by exp final and compcheck/fields/style --final before scoring; `meiolol-lab looks
  SNAP` (lab/looks.zig)
- Fold code written six times (win-comp foldAblation, compcheck, winnet, playernet,
  pretrain, win-embx, which reads files with std.c.fopen around the candidate rule).
  Backlog: one block runner with cross-fit offsets (f7 listed playernet's copies)
- Seed 3 equalled seed 1 when threads < seeds (9ace58d); invalid pretrain comparison.
  Backlog: run gate, different seeds give different preds

## Compute and waiting

- League paused the gpu-box for hours; the Mac was never placed (no ~/ml/snaps).
  Fixed c7f4687, then Mac runs stopped (65eb54b, 4f60ffd: gpu-box only)
- One cpu and one gpu job at a time: benches held the cpu lock ~1 h, finals queued
  behind; GPU at 0% with 769 MiB of 10 GiB. Done cddffa0: 4 slots per resource, cpu
  slots pinned to their cores. Backlog: measure 1/2/4/6/8 concurrent jobs and tune
  slots and sweep --pack; weighted slots; mean GPU % and CPU % per run
- ~13 hand-written `until ssh gpu-box test -f exit` loops, one missed its run, kq
  poll crashed, until-loops exit 144. Done cddffa0: `lab-run wait RUN...`
- Runs outside lab-run (nohup on the Mac, binaries copied to scratchpads) died with a
  pane or left no meta; preds.tsv lost in scratchpads (`find /` timed out, 97 reran
  netcheck). Done: model-agents rule; backlog: `lab-run find --cmd --cand --snap`
- Variants by sed on a candidate's cfg (one overwrote the original), one ReleaseFast
  build each (~25 min); harness constants patched in archived copies. Backlog: cfg and
  harness flags at run time
- `zig build test -Dtest-filter=X` matching nothing reports success (edc83d5b broke a
  test on purpose to check); candidates aren't built by ci. Backlog

## Backlog, in order (coordinator's priorities, 2026-10-13)

1. Done: compare registered (42ed9d6). Same seed, 5 cores (cpu slot, taskset) vs 20
   (--res none): netcheck small seeds 1-3, preds.tsv byte-identical, compare B - A
   0.00000 ± 0.00000; folds.tsv differs only in `seconds` (2026-10-13, meiolol-a0).
   Thread count needn't be in meta
2. Throughput: concurrent mixes on the gpu-box, nvidia-smi
   (/usr/lib/wsl/lib/nvidia-smi) and load; slot counts and default --pack from models
   per hour; weighted slots. Done 2026-10-14: per-run `usage` (CPU cores, runnable
   threads per core, card %, peak memory), labpy caps process pools to the slot (load
   80 on 20 cores was pools x OMP threads), layout r 4 / cpu 4x4 / gpu 3 with a memory
   gate (compute.md). Left: models per hour per mix, --pack default
3. Cheap run gates: done for preds (deploy/lab-gates.sh after every run: NaN/inf or
   constant prediction columns, 83918fa) and seat stats (a needs_stats fit fails on any
   all-NaN stat, e30cec4) and a fresh net's loss vs the base rate's (src/lab/gates.zig,
   hooked in draftnet's fits: netcheck, winnet big; real 2055Z: 0.69308 vs 0.69301).
   Left: playernet, setnet, stylenet, winnet small, pretrain call gates.initLoss
   (their owners); heavy checks are meiolol-tests'
4. Done: failed runs logged on the gpu-box, `lab-run.sh failures`, wait points at
   docs/lab-constraints.md (90cc294; not appended to the tracked file: it would sit
   dirty for other sessions' commits to sweep)
5. --control shuffle harness-wide, generalising playernet's --shuffle-labels (8ea54ff),
   same flag name (76: --control shuffle|permute, --shuffle-labels an alias)
6. Done: run key (meta `runkey`: binary, CPU target, snapshots, args, pyenv, --with
   files); a start prints "same as RUN (exit N)" and still starts
7. Done: pre-commit import check (7449671), looks ledger (95d9e96). Left: per-file
   command registration; one block runner (meiolol-f7's list of winnet/playernet
   duplicates)

Also done (meiolol-a0, 2026-10-13/14): gpu-box binaries built on the gpu-box (df6d5c6),
2 build slots and per-key locks (98cadb6; its lock never locked, fixed 59d0d27, locks
now checked held), `lab-run --python` (1d9a334, py/)
