# progress-tests (meiolol-tests; brief: scratchpad brief-tests.md)

Coordinator now meiolol-bd (took over from meiolol-76). Only the coordinator pushes.
Session: meiolol-tests (was meiolol-d8, pane 1004) since 14 Oct ~00:00 BST; my scratchpad
/private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/ed77de91-a80b-405f-a7ed-2ac0471c2df9/scratchpad
(golden2.log, eff-runs.txt, model-tests.md = draft model.md section). Old scratchpad (0a)
.../8b5601a5-3afd-40ff-a8c3-726b3c3404f6/scratchpad (plant-sweep.sh, score-all.sh, scores/)
Split agreed with meiolol-16: 16 owns run-time gates (<1% run time) + compare.zig; tests
owns test cases, src/lab/synth.zig, plant: hook, health, golden. Python cross-check moved
to meiolol-58 (notes sent). Name clash: the lead NN modeller is meiolol-0a [101155]; always
use refs for it.

## Done (all committed by path, not pushed)
- 507c88d, 3278338 src/lab/synth.zig + rows.load hook: any command's SNAP may be
  `plant:SPEC:PATH`; winners re-drawn from a known logit. SPEC keys (win pp at 50%, logit =
  pp/25): seed, champ (strength sd, default 2.5), side, synergy, counter, pair (k-th most
  common pair/matchup), pair_sd (all ally pairs), counter_sd (lanes + bot/sup crossed),
  mix (per sd of win-comp's (f-0.5)^2), skill (per player per log1p champ games). gold14
  etc. stay REAL (only win relabelled). Experience wins stay real (noise)
- 0265310 `meiolol-lab plant-score plant:SPEC:PATH PREDS.tsv [REF]` (dispatch in lab_main via
  08's 9ee9c51): per dev/folds, each column's loss vs REF, truth and truth-without-plants,
  captured = slope of model logit on each planted truth part (HC0 95%)
- d87d8d7, 51ea741, c3347bb `meiolol-lab health` (src/lab/health.zig): big (draftnet),
  small + resid (winnet.healthFit f29a170), set (setnet.healthFit da1183c), player
  (playernet.healthFit c1e68d2/9cee34a). Checks: init loss vs base rate/offset, antisymmetry
  (swap sides: logit sum constant), held-out loss falls, overfits tiny random-label set,
  same seed identical params, seed 2 differs, finite. Run 20261013T223621Z-tst-health2
  (51ea741): 36/36 ok, ~20 s. tst-health3 (c3347bb, + player): 0 of 45 failed; key 62fdc17e built during a0's
  lock bug (98cadb6, fixed 59d0d27): a0 rebuilding clean to check, verdict pending
- 74cf241 deploy/golden.sh + docs/golden.tsv: 6 cases, all ok at d87d8d7 (ratings
  dev 0.68969, folds 0.69090, test 0.69064; win-comp 0.68999/0.69033/0.69065; test reruns use
  a scratch --lab, no new look)

## Planted sweep 1 (pinned commit d87d8d7, snapshot 2055Z, netcheck --net small --seeds 1
--max-epochs 1; script scratchpad plant-sweep.sh CAND TAG SPEC [NET]; run list runs1.txt)
All 17 finished (~15 s each). Scores: scratchpad score-all.sh runs1.txt -> scores/TAG.md
(running in background at handover; if empty, rerun it). Folds log loss (net / cand):
none s1-3: ratings 0.6842/0.6865/0.6866; win-comp same within 0.00002 (no mix: comp = ratings)
wc-mix1: cand 0.68413/0.68643/0.68621; mix2: 0.68370/0.68590/0.68580; mix4: 0.68176/
0.68388/0.68402; wr-mix4-s1 ratings 0.68265 (comp gains 0.0009 over ratings at mix -4).
Read captured mix slope per run from scores/*.md: detection = CI excludes 0.
Calibration: default champ 2.5 pp makes ratings 0.684 on folds vs 0.6909 real; use
champ=1.7 in later sweeps (strength spread realistic).

### Sweep 1 read (scores/*.md, folds 44,353 games; captured = slope of cand logit on the
planted mix part, ± 95%; oracle = what the planted term is worth to the truth, nats/game)
| planted mix (pp/sd) | win-comp captured, seeds 1/2/3 | oracle value |
| --- | --- | --- |
| -1 | 0.74 / 0.61 / 1.01 (± 0.03) | -0.00018, +0.00003, -0.00022 (± 0.0002) |
| -2 | 0.91 / 0.60 / 0.99 (± 0.02) | -0.00077, -0.00036, -0.00077 (± 0.0004) |
| -4 | 0.92 / 0.83 / 0.94 (± 0.01) | -0.00293, -0.00221, -0.00302 (± 0.0007) |
- win-comp picks up the planted mix in all 9 runs, down to 1 pp per sd (its effect at
  ~90k fit games has se ~0.17 pp, so 1 pp is ~6 se); the seed spread of captured share
  (0.6-1.0) is estimation noise
- But the prediction gain from 1 pp is ~0.0001 nats/game, under the folds' paired noise
  (± ~0.0003): a real 1 pp/sd mix effect would show as an effect yet "not detected" as a
  gain. Real data: train-fit mix -1.5 ± 0.33 pp/sd, folds gain -0.00057 ± 0.00028: in line
  with a true effect of ~1.5-2 pp/sd
- win-ratings alone carries 39% of a planted mix (mix -4, seed 1) through champion strengths;
  wc vs wr paired at mix -4 s1: comp 0.68176 vs ratings 0.68265 (-0.0009) while the oracle
  says -0.0029: ratings absorbs part, estimation noise eats the rest
- win-ratings (misc s1: synergy 4, counter 4, skill 1): carries 43% ± 4 of the top ally pair
  (#804 bottom + #117 utility, 4,749 team-games), 29% ± 5 of the top lane matchup (#51 over
  #202 bottom, 3,789 games) through the two champions' strengths, 3% ± 2 of skill (it has
  no experience input): the controls behave
- Still needed for an MDE as "gain detected": paired wr vs wc runs for every seed and size
  (only mix -4 s1 has a wr run), and more seeds at 1-2 pp

## Done by d8 (14 Oct)
- f98213f golden.tsv snapshot column, golden.sh per-row snapshot, *-test opt-in (--test or
  by name: 95d9e96's test-looks ledger counts each rerun). 4/4 non-test ok at a7961de
- a0 cleared tst-health3's binary (62fdc17e byte-identical to a clean rebuild)
- effects planted (a7961de, 2055Z, champ=1.7): runs 20261013T230632Z-tst-eff-none, 230656Z
  -pair2, 230723Z-pair4, 230751Z-ctr2, 230817Z-ctr4, 230841Z-mix2; scores tst-score-eff-*.
  No false effects; lane blocks half-scale (theta(a,b)-theta(b,a)); ally sd ~1/3 low,
  intervals miss (1/10 at 2 pp); champion blocks collapse at pair_sd 4; mix -1.69 ± 0.33
  for -2. Sent to 1d (effects owner, pane 1006) and bd
- 122a089 model.md "### Model tests" (before "## Next steps"): golden, health, sweep 1,
  effects planted, MDE rules of thumb
- Sweep 2 ready for 2253Z (my scratchpad sweep2.sh + plant-run.sh; SNAP= COMMIT= LIST=):
  wr/wc mix 0/1/2/4 x plant seeds 1-3 (24), small/resid/set at pair_sd=counter_sd=x,
  mix=-x, x 0/1/4, --seeds 1,2,3 (9), playernet skill 0/0.5/1 (3), effects none/pair2/
  ctr2 (3) + (1d asked) eff pair1 and cross2 (counter_sd=2,lanes=2; f6e6366 adds lanes=1|2).
  Run on 1d's commit (effects matchup rows = cell sd(r vs q) + sd(q vs r), uncommitted until
  eff-f) that includes f6e6366: d1d22f1 has both (eff-f on 2055Z: top vs top matchup 2.47 pp
  [1.98, 2.95], our x2). BUT every 2253Z run so far is void (bd/33): wait for meiolol-73's
  repack and global re-cut; effects.zig may need the new fold definition (1d will say), so the
  commit may be later than d1d22f1. Golden 2253Z rows also only after the re-cut. Waiting: bd says start only after meiolol-04 [79f90e]'s 2253Z reference chain finishes (bd pings with the commit, or ask 04). Score with plant-score per run
  (netcheck preds.tsv REF cand; effects need merged.tsv of games-*.tsv, see effects runs)

## Next
1. Read scores/*.md: per planted size, win-comp's captured mix share and gain vs ratings
   (paired runs: same seed, wr vs wc), detection rate over 3 seeds -> MDE for mix
2. 08's additive model: `effects plant:SPEC:PATH --blocks 1,2,3,4,5 --boot 50 --drop 0
   --out DIR` with -Dcand=src/lab/cand/win-ratings; compare components.tsv "ally X-Y" sd_pp
   with pair_sd, "X vs their X" with counter_sd; ignore gold rows; plant-score its
   games-<model>.tsv. Specs: nothing; pair_sd=2; pair_sd=4; counter_sd=2/4 (champ=1.7)
3. Nets planted at 0/1/4 pp, 100% only (coordinator: lean): small/resid/set (netcheck
   --net X, -Dcand win-ratings, --seeds 1,2,3), big via 1c/fd queue (--res gpu). Terms nets
   could learn: synergy, counter, pair_sd, counter_sd, mix (set net sees profiles)
4. playernet planted skill: f7 ready; `playernet plant:skill=X:PATH ...` (check its usage)
5. Write-up: docs/model.md "### Model tests" (golden table, health table, planted
   results + MDE per model and size; analytic: binary term in m games: se = 50/sqrt(m) pp,
   MDE(80%, 5%) = 140/sqrt(m) pp; per-sd term on n games: se = 50/sqrt(n) pp, matches
   win-comp's published train-fit -1.50 ± 0.33 at 89k). MDEs beside "not detected" lines
   in learned.md only via meiolol-4b's audit
6. New pin (coordinator meiolol-bd, 14 Oct: 4a is taking a fresh snapshot): once the
   references are rescored on it and published in model.md, add golden cases for it (give
   golden.tsv a snapshot column, golden.sh's SNAP is hard-coded to 2055Z now; keep the 2055Z
   rows, never edit an expected value to match), and rerun the planted sweep on the new
   snapshot so the MDEs are for its size
- Mac: only `zig build test -Dtest-filter=MINE`; test on a clean HEAD export in
  scratchpad/tree (working tree often has others' broken files). Pin --commit on lab-run
