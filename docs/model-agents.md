# Model agents: how the modelling work is run

The coordinator session's handbook. Jacob decides; the coordinator keeps the model
sessions agreed, unduplicated and inside policy, collects questions for Jacob with a
recommendation, and records results. It does not model itself.

Where things live:
- Lab findings that change how runs are done: docs/lab-findings.md. Coordinator state at
  the 2026-10-14 stop: docs/coordinator-state.md
- Results and method: docs/model.md ("Shared protocol, 2026-10-12" first, then dated
  sections). Plain findings: docs/learned.md (wording rule in its header). Decisions and
  next steps: docs/plan.md "Draft model". Research: research/questions/
  draft-predictor-methods.md (honest draft-only ceiling, levers in order)
- Lab tooling: docs/lab-tooling.md (what sessions lost, fixes, backlog)
- Compute: docs/compute.md (gpu-box, lab-run, snapshots). Lab: docs/lab-agent.md,
  docs/lab-brief.md. Data fields and retention: docs/fields.md, docs/data-safety.md
- Admin Models tab and Draft tester: https://meio.lol/admin/#models/all and
  #models/draft (admin only)

## Goals (Jacob)

- App and site: learning-first lessons with intervals for ranked climbers; claims
  limited by docs/learned.md "Site:" lines and docs/production-key.md (champ select
  never uses other players' stats)
- Personal: the best League draft predictor (internal). Honest target: beat ~53-54%
  draft-only on a time split; with pre-game player features 55-57%. Report both our
  time split and a LoLDraftAI-style random split for comparison
- More training data is a standing goal (Jacob, 2026-10-14): more games is the only
  gain that has held. The coordinator tracks fit games per comparison against games
  crawled, and re-pins when the crawl has added half again (or weekly, whichever comes
  first), never waiting on a fixed date. Training always uses every game (Jacob,
  2026-10-14): only the test set is held out (one global time cut over all
  platforms, so test reflects the training sources; a region model (likely the global model
  fine-tuned on that region) gets a test from that region), shipped models fit on
  everything after the test look, and no split or filter may drop games a model can fit
  on (draft-only models need no timeline). meiolol-4a owns crawl volume and coverage and
  reports both with each snapshot

## Sessions and what they own (2026-10-13 ~01:10; names change on handover)

Coordinator: meiolol-bd (from meiolol-76, from meiolol-2c, from meiolol-78, 2026-10-13).

| Session | Owns |
| --- | --- |
| (none) | win / draft predictor rerun: closed (meiolol-db done 2026-10-13); new session when the coordinator pins a snapshot with ~a week of rank_history and pre-game mastery (model.md Next steps) |
| meiolol-ff (closed) | review fixes done: winchance smooth weights (live), playstyle clustered intervals, bootstrap bounds (31338cb) |
| meiolol-3f (closing) | playstyle clustering done (47fdfb2, 57d50d0): beyond the full 14:00 state style adds almost nothing; types and sequence net not detected |
| meiolol-12 (closing) | lab harness: rank_start done (9eb6982, after_game_rank dev-only gate); campaign plan in model.md Next steps; fresh lab session at the pin |
| meiolol-0d (closing) | admin Models tab, Draft tester: lane, blind and draft lists live with the 1% role floor; last check: Models tab renders struck lines |
| meiolol-fa | box, archive operation, snapshots (weekly Sun 04:00, first 19 Oct, with mastery_pre and coverage report; from 1e9a446 snapshot.sh also fetches Data Dragon per patch and runs seat-stats before pack, a Data Dragon outage fails the make: check the first run; 30450b4 fixed an empty patch list that left resists NaN; mid-week snap-20261013T1954Z taken by ea on 13 Oct, unpinned, learning curve only: prune it with the others once a new one is pinned), flex daily count, mastery catch-up, pushes (from meiolol-11 [1f36a8]); snapshot.sh push also links ~/ml/snaps/<snap> to data/<snap> on the Mac, so lab-run placement can use either host (1c, 2026-10-13) |
| meiolol-47 | overnight code review; shared src/analysis.zig refactor committed (3324cd3..c2b1a73), all analysis files free |
| meiolol-82 | Riot application text (drafted; waits on Jacob: ownership, privacy.md 24-month retention, meiolol-ef's deploy) |
| meiolol-bd (from meiolol-76, from meiolol-2c) | coordinator, neural net programme (Jacob's big goal, 2026-10-13; brief in docs/model.md "Neural draft models"), after the comp features campaign (api Row.stats 53323f9) |
| meiolol-73 (from meiolol-4a, from meiolol-ea) | NN data: pack mtime fix (second precision), gpu-box repack of 1954Z; multi-task targets (Row.y, Row.stats as auxiliary), tensor export for the GPU, extra games count (comp data done: 25737aa, 1e9a446) |
| meiolol-structured (pane 1010, from meiolol-35 [397394], was meiolol-c2) | structured nets on profiles (profile inputs, DeepSets/attention, residual on ratings); win-comp done (7a2de11, test: mix effect holds, prediction gain not detected) |
| meiolol-5b (closed, pane closed 13 Oct, from meiolol-97 [7beeb6]) | done (f5b5499, fe33e9b, 30e9f74): d8 prior borderline, not detected at the noise floor; rerun on 19 Oct snapshot (Next steps). Was: NN pretraining: champion-role embeddings from aux targets, used in f1's nets and as a ratings prior (src/lab/pretrain.zig) (research done: 9530584, fbc5df5) |
| meiolol-d8 (closed, from meiolol-ba) | NN tester done: LoLDraftAI 2x2 corrected per 4b (c3bbe11), random split flatters ratings at equal fit size, learned.md stands; net exporter on hold until a net beats ratings. Was: NN tester: draft-model.json net kind, Zig reference scorer and JS forward pass (comp tester done: 2be13f3, 7423f29) |
| meiolol-53 (from meiolol-33, from meiolol-4b, from meiolol-49) | comp test look reading (20261013T195844Z-final-compcheck, c26ffa8), then NN verifier: leakage audits, seed variance, paired checks |
| meiolol-37 (from meiolol-fd, from meiolol-1c) | GPU sweep runner for nets (random search on the 3080 via lab-run) (lab-run auto placement done: 371bec8, e050551) |
| meiolol-04 (from meiolol-0a [101155], from meiolol-f1) | lead NN modeller: big net seed ensembles and sweep with 1c, learning curve on the ~350k snapshot (f1 results: a189f10, no net beats ratings or win-comp) |
| meiolol-97 [5c523c] (closed) | stacking and calibration done (9522113, 2840bce): stacker at the noise floor vs win-exp, GBDT loses to it, temperature nothing; rerun on 0a's sweep ensemble and f7's 350k win-exp later (scratchpad progress file) |
| meiolol-74 (pane 1024, from meiolol-51, from meiolol-f7) | player-history nets, internal scope only: experience, mastery_pre, rank_start per slot (src/lab/playernet.zig) |
| meiolol-48 (closed) | patch and rank context done (3d11c31, e2ed6f4): per-patch offsets not detected; rank brackets wait for the 19 Oct snapshot (model.md Next steps) |
| meiolol-30 | scaling curves for ratings, win-comp and nets, a*N^-b + c, projection to production-key volumes |
| meiolol-64 (from meiolol-ab) | interactions on pretrained embeddings: low-rank cross and within-team terms (cand/win-embx) |
| meiolol-2a (closed) | admin Models tab dashboard of the NN programme results: done (16ecd0f) |
| meiolol-e3 (closed) | research: how AI agents run ML experiments well: done (86c8a5f, docs/lab-constraints.md 2680d29); ranked list adopted in briefs and 16's queue |
| meiolol-tooling (pane 1011, from meiolol-a0, from meiolol-16) | lab tooling from evidence: results store and checked comparisons, immutable run binaries, standard preds files, snapshot completeness checks |
| meiolol-1d (from meiolol-08) | effects and the CPU model: one shrunk additive model (champion-role, ally and enemy role-pair terms, comp), effects table in win points and gold, in-game event value (win chance added), distilled from GPU teachers (Jacob 2026-10-13: ship CPU-only models that pick out information) |
| meiolol-research (was meiolol-f1, new) | research: isolating event, synergy and counter values; pre-game player skill models; distilling GPU models into explainable CPU ones |
| meiolol-tests (pane 1004, from meiolol-tests [01815a]) | model tests: planted-effect recovery and minimum detectable effects per model, training-health tests, golden numbers on the pinned snapshot |
| meiolol-58 (new) | PyTorch cross-check of the Zig models (win-ratings, small, big, resid, set net, playernet: same rows, folds, seeds; agreement within a justified tolerance), takes over tests' Python item; runs via lab-run --python (meiolol-a0 adding it) |
| meiolol-state (new, pane 1000) | live state model and what matters: P(win | draft, full state at minute t) with per-role gold, deaths and respawns, towers by lane and tier, dragons and soul, buffs, items; linear, GBDT and GPU net vs winchance; grouped importance by minute in win points and gold equivalents; momentum and comeback checks |
| meiolol-draftpath (new, pane 1001) | how drafts win: draft vs state information by minute, what a draft decides (game shape from the draft), mediation of champion and comp effects through the early lead, draft-conditional comebacks |
| meiolol-94 (from meiolol-c1) | comp discovery: our own champion and team variables (comp_stats.tsv, src/lab/compstats.zig, comps.zig), cross-team matchups, archetypes, FDR screen with a sealed block; survivors to 08 and 35 |
| meiolol-61 (closed 14 Oct: carry done, test look confirmed role gold; types on 2253Z) | carry and impact: which champions and roles carry (leverage of a seat's lead, skill sensitivity, outcome spread), src/carry.zig |

Two sessions can share a name: message by the `from=` socket or the `[ref]` ListAgents
shows. Current clashes (14 Oct): meiolol-04 [79f90e] lead NN (pane 1002) vs
meiolol-04 [904e99] lab tooling (pane 1011, renaming to meiolol-tooling); meiolol-41
[701543] state (pane 1000) vs meiolol-41 [36c2ab] draftpath (pane 1001). When an agent hands over, get the successor's name and tell the others.

## Rules given to every model agent

- Shared protocol in docs/model.md: one hashed snapshot, eval's time split, test touched
  once per model; choose variants on dev; gains with paired intervals clustered by game
- Label train-time and use-time features; champ-select models use only champions,
  roles, the user's own rank and experience; `internal` scope (Jacob's predictor) may see
  all ten players' pre-game data and never feeds the site or app
- Snapshot: moving off snap-20261012T2055Z to a fresh pin (2026-10-14, 4a taking it; rebase
  checklist from meiolol-4b in the coordinator scratchpad, rebase-checklist-source.md).
  Was: - Snapshot: snap-20261012T2055Z stays pinned for all work in flight (gold14-a, db's
  models, ff's checks, 6f's bench), so results compare. A new weekly snapshot is a new
  game set: start new models on it only once the coordinator pins it in docs/model.md,
  and rescore any reference model on it before comparing. Re-packs (SNAP/pack/) never
  change rows; code changes can
- Both sides of a paired comparison from the same build; rerun the older side if a
  pair straddles a numeric change. The gpu-box x86_64_v3 switch (516fce3) is not one:
  byte-identical output (strict float mode), 2x faster
- An effect table from the train fit is not a test result, however clear: per-effect
  claims in learned.md need the effect to hold on held-out games (test refit with
  train-derived features, or a pre-declared test), with train vs test side by side
- Condition on game state for items, objectives, playstyle (teams ahead buy and take)
- Rank in participants is post-game (leaks); rank at game start comes from
  rank_history (from 12 Oct, so later snapshots)
- Don't declare exclusions or effects without a measurement (Jacob, via meiolol-47)
- learned.md lines in plain English first; commit by path only, new files with their
  first import; pre-push CI must pass (one failing commit blocks every push)
- Hand over past ~40% context with a focused brief; tell the coordinator the new name
- Lab runs: `deploy/lab-run.sh start NAME -- ARGS` (no HOST) picks host and resource by
  predicted finish and queues on ~/ml/locks; name a HOST only when it must run there.
  Model runs on the gpu-box only, never the Mac (Jacob, 2026-10-13); auto respects it.
  League pauses gpu-box runs (placement allows for it)
- Always through lab-run, never a binary run directly or a background shell (no meta,
  no lock, dies with its pane). Wait with `deploy/lab-run.sh wait RUN...`, not loops.
  Same inputs build once: repeat starts reuse `binary KEY` (--bin KEY pins it)
- Test looks are counted by the harness, not by hand: exp final, compcheck, fields
  and style --final and `meiolol carry --final` append to SNAP/test-looks.tsv on the gpu-box before scoring (a
  crashed look counts). `meiolol-lab looks SNAP` prints it; snap-20261012T2055Z
  back-filled to 7 looks from run meta (2026-10-13). Python or other scoring of nnexport's
  test rows (split 10) isn't recorded yet: add a line by hand (look, utc, run, command)

## Open, waiting

- Jacob: none pending at handover
- Collected: gold14-a final (rank on 3c-team holds on test at half dev size, learned.md
  e4f8335; recheck with rank at game start and on team2 in the next campaign)
- Collected: sub-15:00 exclusion makes no detectable difference (db, 289f63a; kept);
  champlevel shrinkage no gain on dev (12, 3b28e60): off-role lane cells are real
  farming, the Draft tester's 1% role floor is the fix
- Collected: draft predictor test finals (db, 1abb887): champions only 53.2%,
  everything pre-game 54.5%; skill slopes not detected; stored rank leaks
- Agreed: meiolol-12's rank-at-game-start campaign (model.md Next steps); harness work
  now, campaign on the pinned snapshot
- Collected: GPU vs CPU (6f, ccfbd95, docs/compute.md): deep draft net on the 3080
  (3.9x at 175k games, ~11x from 2.8M); fm and additive models on the CPU (sweeps tie)
- Collected: winchance smooth weights (ff, 6c7d50d; ties per-minute refit on test, jump
  from weights 19.2 -> 4.4 pp; ff installs the jomove API binary); playstyle clustered
  intervals (8c84735, about the same width)
- Collected: field ranking (48, d94c875): champ-select fields don't move win, do move
  early outcomes (association); early stats add <0.5% beyond 14:00 state; kit and
  lane opponent explain much of skillshot/CC/ward stats
- Jacob: keep the five champ-select fields in compact rows? (recommended: yes)
- Collected: bootstrap upper bounds (ff, 31338cb): comeback slope per champion under
  ~2-4.5 pp per 1000 gold (4-7 pp from 2k behind at 15:00), so "not detected", not
  ruled out; team counters and champion x item bounded in model.md
- Jacob: may a session check Your games live with a Riot ID (his own)? If yes, fresh
  session checks the win chance turning minute live
- Collected: playstyle (3f): b0's 8 style +0.00020 ± 0.00011 on test with objectives in
  the state (half the gold/XP-only gain); clusters, components, net not detected;
  train-fit leanings didn't hold on test, dropped
- Collected: mastery for all participants live (11, 170e409, 02:16Z): matches/day
  127,914 before, 130,215 after; catch-up ~2.5 days, then ~25k mastery calls/day
- Collected: flex sample live (11, 0a4a787, 02:41Z, --flex-calls-per-day 500): 27 EUW1
  games in 45 min, isolation tested, solo matches/day unchanged (~130k); mastery_pre
  (b424a24) in snapshots from 19 Oct
- Results to collect: flex games per full day (11, 14 Oct; lever is the cap), next snapshot pinned in docs/model.md
- Admin follow-ups for the next admin session (0d, not done: admin.js held by
  meiolol-9f's Your games proxy edits): All-view cards take a category's first two
  learned.md lines in file order, so replacement lines can hide newer ones; stable-sort
  by leading date newest first in learnedList's short mode before slice(0, 2), don't
  reorder learned.md. Run detail fetches metrics.tsv for every run (404s on runs
  without one); lab-push.sh lists it in runs.tsv, runDetail fetches only when listed
