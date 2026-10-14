# Lab findings that change how runs are done

Saved 2026-10-14 from the coordinator's shared brief (nn-common.md, scratchpad). Read
before planning runs; newest at the bottom.

  a 90% resample (netcheck --resample)
- Pin builds: `--commit SHA` (or --bin KEY) for a batch of starts; --head rebuilds
  whenever HEAD moves (d8: 10 starts, 1 build, 7 min)
- gpu slots x --pack share the CPU: 16 processes made 73 s jobs take 3-6 min; prefer
  --pack 1-2 until a0's tuning says otherwise
- Big net: single seeds always worse than ratings; seed ensembles only level (first 10
  seeds -0.39 shrank to -0.12 sealed, -0.10 resample: not detected, 4b audited 9ed8df9);
  tuning on inner val no help (0a). Compare new nets against win-comp, not ratings
- Set net gain comes from profile content (permuted ~0), within-team only; cross-team
  terms add nothing (35). win-comp's gain sits on lopsided-damage teams (4b gains)
- GBDT on dense features loses to a linear stacker; temperature scaling gains nothing (97)
- Random split flatters ratings by 2.7 ± 1.6 on the same games (4b): always time splits
- Player history is the biggest lever (-2.5 to -3.8); its net adds little beyond the hand
  terms so far (f7)
- Starting a run without -Dcand scores against base rates (35); check meta before reading
- Sweeps at our size barely rank on inner val (top 12 of 32 within 0.0002) and val
  favours fast configs worse on folds: a sweep pick is a candidate for a 10-seed check,
  not a winner; never put --evals in a space (biases val low) (0a)
- Residual nets: let early stopping score step 0 (the candidate alone); report the
  fixed-offset (weight 1) result beside the learnt one, as the learnt weight can be half
  a small gain (35)
- Inputs built from outcomes or end-of-game stats: leave-one-out values for training
  games, plus a permuted-input control within role (setnet --control permute) (35)
- Packs: rows.zig edits no longer stale packs (df1050c); rowsql, pack, protocol, stats,
  seatstats edits do. "pack is stale" in a run log = slow SQLite load: tell meiolol-4a
- SNAP/events.tsv (meiolol-lab events, 703e2f8): towers, inhibitors, epic monsters,
  kills with the state just before; use it rather than parsing timelines again (4a)
- Python: `lab-run --python SCRIPT` (1d9a334): slot, League pause, run dir; shared uv env
  (torch cu128, numpy, scipy, pandas, sklearn, lightgbm); scripts live in py/, never src/
  (src changes every Zig binary key). gpu-box binaries now build on the gpu-box (df6d5c6)
- nn-export has match_id.txt for per-game joins (7f7c80e)
- Crawl outage 20:56-22:35Z 13 Oct (wrong-app key): rows from that window may carry
  undecryptable PUUIDs until 4a rekeys; player-history features near it: ask 4a
- PyTorch agrees with Zig ratings (+0.00002 ± 0.00010) and the exact L2 optimum is no
  better: Zig ratings are early-stopping regularised and the baseline stands (58). The
  reference fit's shuffle order alone moves its logits ~0.02: its seed spread is being
  measured (58), so treat a single-seed reference as noisy
- A shrinkage spread estimate > 0 is not evidence: null plants gave 1-3 pp spreads in
  some role-minutes; judge per-champion effects by held-out gain (61). Per-champion
  leverage of own gold is under ~2 pp/1000 gold vs role slopes 3-8 (61)
- Shared state export: `meiolol-lab state-export` (meiolol-state, src/lab/stateexport.zig),
  game x minute, aligned to nn-export; read it rather than build another
- NEW PIN COMING (Jacob, 14 Oct ~00:10): we move off snap-20261012T2055Z (~90k fit
  games) to a fresh snapshot (4a taking it now, roughly double). Finish runs in flight;
  start no new long campaign on 2055Z; build code snapshot-agnostic. Draft-only models
  should not need a timeline (4a checking the 15:00-timeline filter). Coordinator pins it
  in model.md with 4b's rebase checklist; references are rescored first
- Checks to run (tests): `deploy/golden.sh [--commit SHA]` rechecks docs/golden.tsv's 6
  reference numbers after any tooling or numeric change (~2 min, gpu-box);
  `meiolol-lab health` (~20 s) runs 36 training-health checks per net; planted data via
  SNAP=plant:SPEC:$HOME/ml/snaps/X and `meiolol-lab plant-score` (only win relabelled)
- A label-shuffle control on a residual net is uninformative (it learns to drop the
  offset): permute the inputs instead (f7, 4b's rule). Calibration by history bucket is a
  cheap way to find missing player terms (calib.sh, data/runs/playernet-20261013) (f7)
- An effect can be real yet "not detected" as a gain: win-comp recovers a planted 1 pp/sd
  damage-mix effect in 9/9 runs, but its log-loss gain (~0.0001) is under the folds'
  noise (±0.0003). Report the effect estimate with its interval beside the gain (tests).
  Ratings absorb ~43% of a planted ally pair and ~29% of a lane matchup via strengths
- New pin: snap-20261013T2253Z (4a). Mac with pack ~23:40Z; gpu-box ~/ml/snaps/
  snap-20261013T2253Z with mastery-pre, then nn-export, events and pack ~00:10Z (UTC).
  Pinned in model.md once 4b's checklist items 1-5 pass; references rescored first (04, 35)
- Test looks are ledgered (a0, 95d9e96): every --final appends to SNAP/test-looks.tsv
  before scoring; `meiolol-lab looks SNAP` lists them. A test score made any other way
  (Python on split 10, a custom command) must be added by hand. Same seed at 5 vs 20
  cores is byte-identical (2f5dd85)
- CLEARED (a0, 14 Oct): every key built 22:48-23:05Z 13 Oct matched its clean rebuild
  (state-export-2055Z was rebuilt and gave identical output); those runs are citable
- gpu-box slots now: 5 cores reserved for gpu slots and --res none (pinned), 3 cpu slots
  x 5 cores, FIFO queue with a fast lane for runs predicted <= 60 s (8bf0e69, 94068f0)
- BUG CLASS (08, 4ace29b): rows.Data rows are in match_id order (rowsql ORDER BY
  match_id, slot), games in start order: "a game's rows are adjacent and in game order"
  is FALSE. Check any code that walks rows assuming game order
- Variance components: a Poisson bootstrap inflates thin pair blocks; block spreads need
  a shuffled-outcome null (effects --null N); count only blocks above the null's 95th (08)
- Draft-predicted early gold carries no win (-0.02 ± 0.05 logit/1000 vs in-game gold's
  0.405): early-gold drafts give it back later (08)
- Lab gates (a0): GATE FAIL lines for NaN/inf/constant prediction columns (83918fa);
  `lab-run.sh failures [N]` lists failed runs (90cc294); `--control shuffle` across the
  harness (a3432bd). Build keys eff-d and ev-a verified clean
- gpu-box OVERSUBSCRIBED (14 Oct ~00:20): load 41-58 on 20 threads, jobs 5-10x slow.
  Never bypass the queue with --res none for anything heavy; cancel your own queued runs
  that are stale (old snapshots, superseded variants); a0 is capping threads per slot
- Effects block sds (tests on planted data): lane blocks "X vs their X" are half-scale
  (theta(a,b) - theta(b,a)), so x2 for a matchup's spread (top vs top 1.23 = ~2.5 pp);
  ally block sds biased low by ~25-40% with intervals that miss planted values. Read
  "ally bottom-support 1.21" as ~1.6-2 pp; upper bounds understate
- New pin snap-20261013T2253Z is final (4a): 298,944 lab games (294,739 15:00+), EUW
  test 17,486; rank_start 1%, mastery_pre 0.85% so far
- Seed ensembles need diverse fast fits (fd, big1c): averaging 3 seeds gains 1.06 mnats
  for big's default, 0.72-0.81 for fast trials, 0.56 for slow ones; every slow (low-lr)
  config is worse than ratings. Don't tune nets towards slow, stable training
- 2253Z GATE NOT PASSED YET (33): seat_stats covered only 77.5% of games, unevenly
  (dev_old 38%, test 99.99%). 73 is filling it from 2055Z's seat_stats and repacking;
  nn-export redone (aux). DISCARD UNSEEN and rerun after the repack: anything using seat
  stats (win-comp cand, effects/additive, bigres-on-wc, set net, pretrain, embx, comps,
  nn aux). Ratings-only and pure draft nets are unaffected (33 verifies by preds).
  Every 2253Z test look also reports the fresh subset (new test minus old test games)
- PROTOCOL CHANGE (Jacob, 14 Oct ~01:30): test = one global time cut over ALL platforms
  (newest 15% of played games), EUW1 a pre-declared slice, the all-platform number decides;
  folds/selection/dev-val are windows below it over all platforms; every game before the
  cut trains in finals; shipped exports fit on everything after the look. 73 re-cuts 2253Z
  in the seat_stats repack: EVERY 2253Z run so far is discarded. Report accuracy beside
  log loss
- REVISED (Jacob, final): test matches the training sources (all platforms); a
  region-specific model (e.g. EUW) would get its own matching train and test. Splits by
  time over all platforms: test = newest 15%, dev-val = next 10% (no separate selection
  window), then 5 forward folds; finals train on all before test, exports on all games
- A by-path commit takes the WHOLE file, other sessions' uncommitted hunks too (51's
  7456304 swept in 73's half-done split edit and broke the build). Before committing a
  shared file: `git diff -- FILE`; if it holds hunks not yours, wait for their owner's
  commit (73's re-cut touches winnet, playernet, pretrain, harness now)
- Mac toolchain: /opt/homebrew/bin/zig is 0.16; building an export outside the repo needs
  ~/.local/zig/zig-aarch64-macos-0.17.0/zig (74)
