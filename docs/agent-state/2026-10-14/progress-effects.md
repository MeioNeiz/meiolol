# progress: effects and the CPU model (meiolol-1d, from meiolol-08 at 23:07Z 13 Oct)

Brief: scratchpad/brief-effects.md. Coordinator now meiolol-bd (was 76). Verifier meiolol-33.
New pin coming (bd): no new long campaigns on 2055Z; rescore the additive model on the new pin
beside ratings and win-comp once eff-d's build is cleared by a0 and eff-shuf2 shows mix gain ~0.

## Code (all committed)
- src/lab/additive.zig: solver (random-effect blocks, MacKay variance, planted tests)
- src/lab/effects.zig: `effects SNAP` (variants, drop-one, half-sample sd, --null N shuffled
  outcomes, --shuffle SEED control, --soft distillation: student-logit, student-mix)
- src/lab/eventvalue.zig: `eventvalue SNAP` (needs SNAP/events.tsv, meiolol-4a's)
- src/lab/winnet.zig --fit-preds 1 (c2ec378): teacher preds on fit games, cross-fitted
- src/lab/draft.zig + admin-draft.js (842dbbc): temperature 0.80 in draft-model.json v3;
  live file still v2 until a draft --export (bd to decide: new pin)

## Runs (gpu-box ~/ml/runs)
| run | what | status / result |
| --- | --- | --- |
| 20261013T222220Z-eff-b | first full | mix ~0 (row-order bug), bootstrap broken: superseded |
| 20261013T223330Z-eff-c | drop-one, 9ee9c51..d582b76 | drop-one results valid except mix |
| 20261013T223344Z-eff-shuf | shuffled control, pre-fix | gains ~0; pair block sd 0.1-0.9 pp under null |
| 20261013T225421Z-eff-d | 4ace29b (mix fixed) | full vs ratings -0.00129 ± 0.00054 (4/5); a0 must clear its build key |
| 20261013T225443Z-ev-a | eventvalue 706b2c4 | event table + cause check; a0 to clear key; redo on state+draft model |
| eff-e (queued) | 4f3d007 table with --null 20 | pending |
| eff-shuf2 (queued) | 4f3d007 --shuffle 11 | mix gain must be ~0 |

## Findings
- Additive full vs mains (pairs) -0.00033 ± 0.00019 5/5; mix -0.00091 ± 0.00037 5/5 (eff-d)
- Drop-one held-out: mains all roles, ally bottom-support, top vs top, (mid vs mid) matter
- Gold@14 route fails: draft gold edge win slope ~0 (±0.05/1000) vs in-game 0.405; R^2 5-8%
- Calibration on folds: ratings T 0.80 ± 0.11, additive 0.94 ± 0.10; f1's own builds
  (data/netcheck/f1/m-*/games-win-ratings.tsv) give ratings T 0.804 folds, 0.94 dev: the
  shipped 0.80 doesn't rest on eff-d's key
- Events: see ev-a log; steals not coin flips (stealing team wins less after); behind teams
  beat the state model after objectives (missing draft terms, bd's C2)
- Distillation parked (bd, C5 gate): no champ-select teacher beats the additive model

## Next
- model.md "### Effects and the CPU model" + docs/nn-results/effects.tsv (in progress)
- On the new pin: effects (all blocks, drop 1, null 20), shuffle control, send to meiolol-33
- eventvalue on meiolol-state's P(win | draft, state) when it lands (pane 1000)

## 1d status (23:20Z)
- eff-e / eff-shuf2 starts (old session's shells, pids 62325 / 65215) waiting for gpu-box
  build slots (pt-d12-s456, carry-final building). Tell a0 if not started by 23:30Z
- Asked a0 for key verdicts 854c47eb (eff-d), af272479 (ev-a)
- 04: sends SHA + fold args at rebase launch (waits 4a's pack); netcheck defaults, blocks
  dev,1..5, cand win-ratings seed 1; ratings fold preds at ~/ml/runs/<ts>Z-rb-ref-wr/small/
  games-win-ratings.tsv -> temperature refit -> draft --export -> lab-push -> tell bd
- Asked meiolol-41 [701543] (state) for P(win | draft, state) ETA/format for eventvalue
- GATE 1 PASSED (a0, ~23:20Z): keys 854c47eb (eff-d, fd47860) and af272479 (ev-a, 706b2c4)
  byte-identical stripped to clean rebuilds. model.md "being re-checked by a0" lines to drop
- eff-e = 20261013T231222Z-eff-e, eff-shuf2 = 20261013T231223Z-eff-shuf2 (queued cpu 23:13Z)
- 2d9a8b4 eventvalue --preds FILE --col p_wcd --block cf (41's SNAP/state/preds-wcd.tsv:
  match_id, minute, block [cf | dev,1-5], p_wc, p_wcd, p_rich; ETA 2055Z ~00:20Z, 2253Z
  after pin). ev-b (default mode) == ev-a byte for byte. Under winchance no-event slope
  15.7 7.8 5.6 4.8 4.5 4.5 pp/1000 by band (includes XP; ~1.3x gold weight at 10-14)
- eff-e done -> 4ac4867 model.md table (null-corrected): win detected = 5 champion roles,
  ally bot-sup 1.2, top-top 1.2; gold detected = champs, top-top 127, mid-mid 96, bot-sup
  83, bot-bot 54. Remaining gate: eff-shuf2 (queued cpu 23:30Z), then send both to 33
- GATE 2 PASSED: eff-shuf2 mix +0.00002 ± 0.00003, full +0.00010 ± 0.00011 (5134fc6).
  Sent to verifier meiolol-33 [70ba19] (pane 1005; another 33 [3ec461] exists) 23:45Z;
  offered a 90% resample run (effects has no --resample yet). bd told.
- Waiting: 04's SHA for 2253Z rescore; 41's preds-wcd.tsv
- AUDIT 33: reproduces; clear = beats ratings mostly via mix; NOT established = vs win-comp
  (-0.72 ± 0.44, bound -0.02), pairs over mix (-0.32 ± 0.19). model.md marked (21412d3).
  Pre-declared 2253Z rule sent to 33 (await OK): A0-2 cand ratings resample none/1/2, B0-2
  cand win-comp, C shuffle 11, T table; H1 full-wc, H2 full-mains_mix; pass = mean+1.6 half
  < 0 and both resample means < 0; C must be ~0; cand preds = 04's/35's to 1e-6
- effects --resample N (uncommitted, smoke eff-rs-smoke running on 2055Z block 1)
- RULE OK'd by 33 (~00:00Z) with amendments: (1) void only if C shows a GAIN (mean + half
  < 0 for full vs mains or mix vs mains); (2) full and mains-mix preds equal between A0/B0,
  A1/B1, A2/B2, else stop. Start only after bd pins 2253Z; send 33 SHA + run dirs; 33
  recomputes H0-H2. No 2253Z scores before these runs. (c1: only comp term confirmed is the
  damage mix; 251 traits bounded ~1 pp/team sd; teams.tsv at comps-export-teams run)
- d8 (meiolol-tests) plants: lane blocks half-scale -> effects now prints matchup rows (sd
  r-vs-q + q-vs-r; same-role x2) (uncommitted, eff-f smoke on 2055Z running); ally sds
  0.6-0.75x truth, intervals miss -> label lower bounds; estimator fix (MacKay diag
  posterior) only AFTER the 2253Z test. Asked tests for plants pair_sd 1, crossed ctr 2
- bd: start 2253Z runs on 04's SHA without formal pin. 33: OK but BLIND: don't read
  folds.tsv / games-*.tsv / gain lines until 33 says gate passed; pred equality checks ok
- Launch script: 1d scratchpad eff-2253.sh COMMIT [--dry-run] (A0-2, B0-2, C, T)
- 04's 2253Z SHA: 21412d3; rb-ref-wr = ~/ml/runs/20261013T234946Z-rb-ref-wr (small/games-
  win-ratings.tsv for temperature). My runs at my effects commit (after eff-f smoke)
- bd: export must fit on ALL played games incl. ~64.5k non-EUW test-period games
  (eval.split drops them; draft already fits train+tests). Needs rowsql opt-in = pack
  stale; asked meiolol-73 (4a's successor, data) how to sequence. Then --all-games flag +
  model.md "Draft model file" note
- Export fit set SETTLED (bd's b, 73): no rowsql edit on 2253Z; next pin's global cut makes
  dropped games test rows, draft already fits all rows.Data. 2253Z export note: misses
  ~64.5k non-EUW test-period games until next pin
- HOLD 2253Z runs (bd ~00:10Z): seat_stats covers 77.5% (dev_old 38%); 73 filling + repack.
  Start A/B/C/T only after the repack (nothing had started)
- 2253Z ratings T (rb-ref-wr folds 78,036): 0.891 ± 0.038 (folds .71 .87 1.30 .77 .99;
  dev 1.02). Asked bd: export now (T 0.89, --commit 21412d3) or after 2253Z test looks
- bd: export WAITS for 73's repack (re-cuts 2253Z with one global cut, adds the 64.5k);
  then export at the new commit on every played game incl. test, T refit on NEW folds
  (needs ratings fold preds on the re-cut: ask 04). T 0.89 finding in model.md (8c7553d)
- PROTOCOL CHANGE (33/bd/Jacob): 2253Z re-cut globally: test newest 15% all platforms,
  selection 10%, dev-val 5%, folds 5 equal-count blocks below; EUW1 a slice. All 2253Z runs
  so far void. Rule stands; dev-val now all-platform. effects.zig duplicates netcheck's fold
  edges -> must follow the new shared definition (asked 73). T 0.89 was on the OLD cut
- d1d22f1 effects --resample + matchup rows (smoke: 39,923/44,353 = 90%; eff-f block rows ==
  eff-e). a0fbfa7 model.md table: matchups (top-top 2.5 pp / 253 gold), lower-bound caveats
- Next: 73's repack + global re-cut -> effects fold edges must follow (asked 73) -> run
  eff-2253.sh at new commit (blind) ; ratings T refit on new folds -> draft --export -> bd
- FINAL protocol (33): test newest 15% all played; dev-val next 10%; no selection, no EUW
  slice; folds 5 forward blocks below dev-val. effects must use 73's shared split fn; 33
  checks blocks by match id
- RE-CUT DONE (73, 85fd62a; effects switched to c.fold/c.dev/c.test_). Launched eff-2253.sh
  85fd62a (~01:25 BST): e53-A0..2, B0..2, C, T. BLIND until 33's gate. Validity checks
  allowed blind: A vs B full/mains-mix preds equal; cand preds vs 04's/35's new refs
- 04 re-cut refs at 0c3e486 (= 85fd62a + winnet gate only): rb-ref-wr ~/ml/runs/
  20261014T002905Z-rb-ref-wr. T refit + cand-equality check from it only after 33 reads refs
- e53 runs (gpu-box ~/ml/runs): 20261014T002919Z-e53-A0, 002938Z-A1, 002957Z-A2, 003704Z-B0,
  003729Z-B1, 003751Z-B2, 003812Z-C, 003833Z-T. Sent to 33
- 33 released ratings ref. Blind check A0 cand == 04's rb-ref-wr: 170,209 rows, max diff
  1e-6 (print precision): PASS. Results still unread until win-comp ref released (14/33)
- Re-cut T (rb-ref-wr folds 134,375): 0.965 ± 0.029 (folds .93 1.08 .86 1.11 .88; dev
  1.07 ± 0.06); top tenth 59.8 -> 59.4 vs won 59.3. Export started: draft-export-2253Z,
  --commit 0c3e486, --temperature 0.965. Then model.md note + tell bd (use draft = human)
- All 8 e53 exit 0. Blind checks PASS: A/B full + mains-mix identical (max diff 0); A1/A2
  differ from A0 (resample on). Pending: B0 cand vs 35's win-comp ref (after release)
- GATE PASSED (53, 33's successor). RESULTS 2253Z (folds 134,375): C clean (0.00000 ±
  0.00005). H1 full-wc B0 -0.00115 ± 0.00022 5/5, bound -0.00080, r1 -0.00126 r2 -0.00116:
  PASS (dev -0.00169 ± 0.00048). H2 full-mains_mix A0 -0.00082 ± 0.00017 5/5, bound
  -0.00055, r1 -0.00075 r2 -0.00076: PASS (dev -0.00132 ± 0.00037). H0 full-ratings
  -0.00163 ± 0.00028 (dev -0.00219 ± 0.00057). Sent to 53. Next: write-up (audit pending),
  T table from e53-T, tell bd (ship additive? its decision)
- a7c8ccf write-up 2253Z (audit pending 53). Asked bd: ship additive (export format, Scorer,
  admin JS: ~2-3 h) now or after estimator fix (my pref: fix first, own pre-declared check)
- 94's comp terms (magic 60%+ flag, AD x armour lean, tank x pen; teams.tsv at
  20261014T005458Z-comps-export-teams-2253Z): to test later, pre-declared
- 53 AUDIT: H1, H2 CONFIRMED. learned.md Win line d753f88; model.md audited wording.
- Export DONE: 20261014T004029Z-draft-export-2253Z (0c3e486, T 0.965, 363,472 games);
  model.md fb2b493. Told coordinator meiolol-14 (bd handed over): `lab-push use` = human
- NEXT (bd/14 order): (a) variance estimator fix (MacKay diag posterior) + own pre-declared
  2253Z check; (b) ship additive (draft-model.json, Scorer, admin JS, ~2-3 h); (c)
  eventvalue on 41's preds (re-cut). Later: 94's comp terms, pre-declared
- 53's learned-line fixes in 63fc05e (top-mid added; cross-role as ranges sum vs rss until
  tests' lanes=2 plant). CAUSE of low pair sds = logistic Laplace bias with thin cells
  (unit probe: gaussian 0.97-1.04x; logistic 0.96/0.67/0.23x at 178/25/6 games/cell), NOT
  diag posterior. Plan for the fix: simulation-calibrated block sds (plant all blocks at
  sigma, refit, iterate ratio) for reporting; for prediction, test a refit with sigmas fixed
  at calibrated values (Config.estimate=false) vs current, pre-declared with 53
- 178e955 additive.calibrate (sim calibration; unit: raw .63x -> .91x). effects --calibrate
  SIMS (uncommitted): calibrated table section + full-cal variant (refit, sigmas fixed).
  Smoke eff-cal-smoke on 2055Z block 1 (may fail: old-protocol pack vs TestWindowMismatch;
  then use plant:SPEC on 2253Z or --blocks none). Then pre-declare full-cal vs full with 53
- 94: USE teams.tsv at ~/ml/runs/20261014T011109Z-comps-export-teams-2253Z-b (e6f582e): +3
  cols phys_share, armour_lean, pen; per-block cross-fitted. magic60 = magic_share>=0.6;
  cross = (own - block mean)(enemy - block mean), blue minus red. ~0.6 pp/team sd expected
- eff-cal-smoke (2055Z, 4x4): undamped joint calibration ran champ bot/sup up 4-5x, allies
  2.5-4x noisy; full-cal vs full fold 1 -0.00030 ± 0.00047. Fix (uncommitted): pairs only,
  damped sqrt step, 8 rounds, misfit printed. eff-cal-smoke2 (8 sims) running
- eff-cal-smoke2 (damped, 8x8, 16.5 min): mains stay 1.00; pairs misfit 0.56-1.65; full-cal
  vs full fold 1 -0.00025 ± 0.00037. BUT gold factors ~1.35 for top-top (= sqrt 2): v1's
  same-role blocks have 2 cells per matchup (only difference identified) and cross blocks
  r-vs-q / q-vs-r are redundant -> calibration targets non-identified sds.
- v2 parametrisation (uncommitted): 15 identified matchup blocks (same-role one signed cell
  per unordered pair; cross r<q only), Variant.matchup / matchupGroups; effects --param
  v1|v2 (default v2). Unit test passes. eff-v2-smoke on 2055Z running. Then pre-declare with
  53: v2 (and v2-cal) vs e53-A0 v1 full, paired per game, same 2253Z folds
- meiolol-state preds on re-cut: ~/ml/snaps/snap-20261013T2253Z/state/preds-wcd.tsv (cf
  236,227 games; LL wc .53458 wcd .52883 rich .52116). Started ev53-p_wcd / p_rich / p_wc
  (eventvalue --preds --block cf, HEAD commit). Asked for p_richc (champion x minute) column
- ev53 (wc/wcd/rich on re-cut, f16367e): draft changes event values <=0.15 pp; behind-team
  excess not the draft (rich removes it); steals -3 to -10 pp. model.md 60035ac; audit
  asked of 53; 14 updated. p_richc pending from meiolol-state -> rerun --col p_richc
- 53 CLEARED events as description; wording applied + learned.md Objectives line (8f0645c)
- cf4762d v2 (identified matchups, default) + damped calibrate + --calibrate. NOTE: effects
  default is now v2; reproduce e53 with --param v1. v2 smoke 2055Z: top-top 2.35 (v1 sum
  2.47 -> sum rule holds); full-cal vs full -0.00024 ± 0.00033 (1 fold); gold cal factors
  1.07-1.5 (MacKay non-convergence? sim calibration corrects either way)
- Pre-declared to 53 (await OK): V0-2 (--param v2 --calibrate 8, resample none/1/2) + T2;
  H4 v2 full - v1 full (e53-A*) non-inferior < +0.0002; H5 full-cal - full < 0 + resamples
- DECLARED + ACCEPTED by 53 (~05:30 BST 14 Oct), before any 2253Z v2 run:
  runs V0/V1/V2: effects 2253Z --param v2 --calibrate 8 --boot 0 --null 0 --drop 0, blocks
  dev,1..5, cand win-ratings, resample none/1/2; T2: --blocks none --boot 30 --null 20
  --calibrate 8. H4: V full - e53-A full (same resample index), pass = mean+1.6 half <
  +0.0002 and both resample means < +0.0002 (else v1 stays; H5 still reported on v2). H5:
  V full-cal - V full, pass = mean+1.6 half < 0 and both resample means < 0. Validity: cand
  = e53-A0's; V0 full/mains-mix differ from e53-A0's. Calibration on each block's fit games
  only, fixed seeds. T2 descriptive; if it replaces learned sizes cite 178e955 plant (0.63x
  raw -> 0.91x cal) and keep "lower bound" only where plant < 1. Read when ended (no gate)
- v2 RESULTS (2253Z, pre-declared): H4 v2-v1 -0.00009 ± 0.00005 5/5, resamples -0.00008
  -0.00009: PASS -> v2 ships. H5 full-cal-full +0.00001 ± 0.00010: FAIL -> no calibrated
  variances (reporting only). v2 vs win-comp -0.00124 ± 0.00026. model.md 3a12e02 (audit
  pending); learned.md line backed out c5eef8e (draft: 1d scratchpad learned-v2-draft.md),
  goes in after 53's audit. NEXT: ship switch (export additive v2: draft-model.json,
  Scorer, admin JS, tests), ask 14 to confirm order

## HANDOVER from meiolol-1d (~06:00 BST 14 Oct, context 46%)
State: all committed, none pushed (coordinator meiolol-14 pushes). Verifier meiolol-53.
Waiting on others:
- DONE: 53 audited v2 (H4 pass, H5 fail); learned.md v2 line in (f2b82ff), effects.tsv
  linked; model.md v2 section audited
- meiolol-state: p_richc column in SNAP/state/preds-wcd.tsv -> rerun eventvalue --col
  p_richc --block cf on re-cut 2253Z (like ev53-*), add to model.md events section
- meiolol-tests: crossed-only plant (lanes=2) + pair_sd 1 on 2253Z; with v2 the sum-rule
  question is settled (v2 top-top 2.35 vs v1 sum 2.47), so it's a check only
- human: `deploy/lab-push.sh use draft 20261014T004029Z-draft-export-2253Z` (ratings
  export, T 0.965) - told 14
NEXT (agreed with bd/14): SHIP SWITCH to additive v2 (2-4 h):
- draft.zig exports via cand.exportModel (ratings u,v,s + comp). Additive lives in
  effects.zig (Mix = win-comp's damage-mix profiles) + additive.zig. Plan: factor Mix out
  of effects.zig into a shared module; draft --export --model additive fits v2 (mains-mix
  + all ally + matchups, cont mix) on all played games; draft-model.json version 4 adds
  model.additive {platform intercepts, mix weight + per champion-role profiles, cells
  [{group, a, b, theta, games}] above a games floor (rest 0 = prior mean), group names};
  Scorer (Zig) + admin-draft.js: blue logit = intercept + strengths + ally + matchup cells
  (v2 signs: same-role one signed cell min/max) + mix; has_pairs true -> ranking evaluates
  each candidate with the full team; reasons: top matchup/synergy contributions
- temperature: refit on V0's games-full.tsv fold preds (additive was ~0.94 on 2055Z)
- export check: scorer reproduces additive.predict on 500 games (as ratings: 5e-8)
- pre-declare nothing (no new model); 53 checks the export like the ratings one
Later: 94's comp terms (magic 60%+ flag, AD x armour lean, tank x pen; teams.tsv at
20261014T011109Z-comps-export-teams-2253Z-b), pre-declared; distillation still parked.
- Successor: meiolol-d1 (pane 1023). 53's non-blocking nit for the v2 learned line if
  touched again: "pre-declared tests (v1 passed at 1.15; v2 not worse) ... v2 1.24" (v2's
  1.24 vs win-comp is reported, not itself declared)
- UNDELIVERED to coordinator meiolol-14 (its inbox queue was full; 3 msgs dropped): send it
  ONE combined message once: "v2 audited (identified matchups ship, -0.09 ± 0.05 vs v1;
  calibrated variances don't, H5 failed); v2 vs win-comp -1.24 ± 0.26 mnats/game 5/5;
  learned.md v2 line f2b82ff; 1d handed over to meiolol-d1 (pane 1023); d1 is starting the
  ship switch to additive v2 (draft-model.json v4, Zig Scorer, admin JS, export check),
  ~2-4 h; ratings export 20261014T004029Z-draft-export-2253Z still waits for a human
  lab-push use"

## meiolol-d1 (from 1d, ~07:00 BST 14 Oct)
- Sent 14 the combined UNDELIVERED message (once)
- T for additive v2 on V0 games-full.tsv folds: 1.01 ± 0.026 (folds .96-1.10, dev 1.14 ±
  .05); top tenth said 61.1 won 61.2: no calibration needed; default_temperature_additive
- Ship switch code (uncommitted at first): src/lab/addinputs.zig (Mix, Inputs, gameIn,
  fullVariant moved out of effects); draft --model additive [--pair-floor N] (default 20):
  fit on all played games, Params kind additive (strength terms, mix as comp team term,
  pairs v4), Scorer.pairLogit, checkAdditive (vs additive.predict with floor+rounding),
  devAdditive; draft-model.json v4; admin-draft.js v4 (pairPart, pairReasons, check);
  test "scorer: additive pair cells ... reproduce additive.predict"
- Export test run: gpu-box 20261014T060951Z-draft-export-add-2253Z (working tree)
- STOPPED (bd: Jacob out of usage) ~07:15 BST. Committed 951e916 (not pushed): draft
  --model additive, v4, JS, docs/model.md Draft model file. zig build test passes.
- First export 20261014T060951Z: scorer vs additive.predict 8.7e-9; floor 20 keeps 78,404
  of 274,962 pair cells, logit moves 0.0021 mean (max 0.062); dev-val 0.68539 vs strength
  alone 0.68768, acc 54.9%, AUC 0.569; 2.0 MB. JS check FAILED on comp part with empty
  slots: average[] lacked raw -> fixed in 951e916 (pairs matched exactly)
- RUN STILL GOING (short, ~30 s): gpu-box 20261014T061428Z-draft-export-add-2253Z (working
  tree = 951e916). NEXT: scp its draft-*.json to scratchpad and run
  node /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/2109efbc-6042-4f9c-862f-d6052401147a/scratchpad/jscheck.js src/site/static/admin-draft.js MODEL REF (must say ok:true);
  /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/2109efbc-6042-4f9c-862f-d6052401147a/scratchpad/jsdrafts.js prints per-item gaps. Then rerun export at --commit 951e916 for the record,
  ask 53 to check the export, tell 14 it's ready for a human lab-push use
- d1's combined message to 14 was ALSO dropped (inbox full): still UNDELIVERED. On resume,
  send 14 ONE message: the 1d UNDELIVERED text above plus d1's ship-switch status (951e916)
