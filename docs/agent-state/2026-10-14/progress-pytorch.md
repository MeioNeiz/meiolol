# PyTorch cross-check (meiolol-58 [d55c95])

Brief: scratchpad/brief-pytorch.md. Write-up: docs/model.md "### PyTorch cross-check".

## Facts found
- gpu-box: uv 0.12.19, python 3.12; ~/ml/pyproject.toml + .venv (Jacob's mnist smoke,
  torch cu128). a0 builds the shared env + `lab-run --python`; don't ssh-run Python jobs
- SNAP/nn (nn-export) has champ, platform, patch, start, blue_win, split, flags, aux; no
  match_id. Order = rows.Data games order = netcheck's scored order (preds.tsv per block)
- netcheck sets (winnet.zig Spec): fit = visible(.dev) and start < before; scored =
  harness.scored(.dev) for dev, else visible and lo <= start < hi; val = newest 10% of
  fit by start; vocab: champion-roles with min_games (10 small, 30 big) fit games
- win-ratings is NOT the L2 optimum: Adam lr 3e-3, batch 2048, L2 on gradient (not on
  platform intercepts), l2 grid 3e-4..1e-2 picked on newest 10%, patience 5, max 60
  epochs, refit epochs*1.1 on all. Early stops at 1-17 epochs (block 4: 1 epoch = ~31
  steps). So sklearn optimum at same L2 can differ: a finding, not necessarily a bug
- Reference run: gpu-box ~/ml/runs/20261013T221629Z-nc-win-ratings (small, 1 seed, 1
  epoch; counts per block in log: dev fit 88706 inner 79835 val 8871 scored 8500; f1 fit
  44353 scored 8870; ...)

## Planned runs
| id | question | status |
| --- | --- | --- |
| r1 | reader reproduces netcheck sets (counts, y, order) | todo |
| r2 | ratings: torch same procedure vs Zig cand preds, per game | todo |
| r3 | ratings: sklearn L2 optimum vs Zig (converged?) | todo |
| r4 | small/resid/big: 10-seed ensembles torch vs Zig | todo |
| r5 | set net, playernet (need their inputs exported) | todo |
| r6 | experiments: optimisers, schedules, archs | todo |

## State (after first hour)
- Plan approved by meiolol-bd: dev and folds only, no test; a ratings win goes to bd and
  4b first (paired, clustered, fold count); even count checks run on the gpu-box via
  lab-run --python (a0 building it); 0a's sealed seeds 11-20 untouched
- Scripts (uncommitted, src/lab/py/): nnsets.py (reader + sets + check vs preds.tsv),
  xratings.py (zigproc / exact / sklearn), xnets.py (small, big, resid in torch),
  compare.py (agreement test vs seed spread)
- 4a: match_id.txt in nn-export (7f7c80e), re-exporting gpu-box snapshots
- Refs on gpu-box ~/ml/xcheck/ref/{m-small,x-resid,w-small,w-resid,m-big} (f1's 3-seed,
  Mac, code a219c21-c709ca4); big 10 seeds ~/ml/runs/20261013T221051Z-0a-big-def10/out;
  coming: *-0a-t23-10-win-ratings (lr 0.002159 wd 0.0002976 batch 256 patience 3)
- 0a's details: small R init ±0.1, big R init 0; big no clip, dropout hash per row;
  GPU big not deterministic (atomics), compare ensembles
- resid offsets in xnets: own hash partition of fifths (Zig uses Wyhash of start,
  platform): equivalent, not identical
- tests' notes: golden targets docs/golden.tsv (reproduce at d87d8d7, deploy/golden.sh):
  ratings dev-val 0.68969, folds 0.69090; win-comp 0.68999 / 0.69033. Golden per-game
  preds gpu-box ~/ml/runs/20261013T2222*-golden-*/. No sklearn in ~/ml env; `uv run
  --with scikit-learn` avoids touching it (only if a0's env lacks it)

## Results so far (snap-20261012T2055Z, dev + folds; scripts moved to py/xcheck/ per a0)
- r1 done: reader reproduces scored sets (counts, labels, order) every block; fit/inner/
  val/ids counts = netcheck log (dev 88706/79835/8871/697)
- r2/r3 done (20261013T223833Z-xratings): zigproc - zig folds +0.00002 ± 0.00010 (3/5);
  exact L2 val-picked +0.00013 ± 0.00018 (2/5); exact at zig's l2 (3e-4) +0.00042 ±
  0.00051. sklearn (intercepts x1000) doesn't converge in 10k iters (my construction)
- ratings seed spread (224459Z-xratings-spread, 10 seeds): folds pooled sd 0.00006,
  blocks 0.00009-0.00026, dev 0.00012; |dlogit| between seeds 0.020-0.033. Told bd, 4b
  (in model.md noise-floor 2f917be), 0a: keep seed 1 pinned
- big (224426Z-xbig vs 0a-big-def10, 10 v 10): agree, pooled single-seed +0.00027 ±0.00037
  tolerance; ens +0.00024 ± 0.00026; block 5 alone outside
- small (224407Z-xsmall vs f1 m-small 3 seeds): torch better, pooled single -0.00036 vs
  tol 0.00031; rerunning Zig with 10 seeds (225123Z-zsmall10)
- resid (224417Z-xresid vs x-resid): torch worse +0.00047 vs tol 0.00011, but torch's
  offsets are its own ratings; rerun 225305Z-xresid2 writes own offset as cand and
  compare.py now pairs each side with its own cand

## State 2026-10-14 ~00:35 (coordinator now meiolol-14; handover at 40%)
Scripts committed in py/xcheck (first commit; later edits uncommitted: xnets --ema --trace
--offsets-from --cross-part --offset-seed --offsets-only, xdump block names, nnsets ens
column, dupcheck.py new). Run via `deploy/lab-run.sh start gpu-box NAME --python
py/xcheck/X.py --res cpu|gpu|none -- ARGS`; compare jobs on --res none (cpu queue slow).
Resid on --res cpu (offsets are CPU work; on a gpu slot it took 55+ min).
Verdicts (snap-20261012T2055Z, dev + folds, compare.py: single-seed gain vs own cand,
tolerance 2*sqrt(sdA^2/kA + sdB^2/kB)):
- ratings: agree (+0.00002 ± 0.00010); exact optimum ties; baseline stays
- small: agree 10 v 10 (zsmall10 225123Z): pooled -0.00014 tol 0.00021, 6/6 blocks
- big: agree 10 v 10 (0a-big-def10): +0.00027 tol 0.00037; block 5 alone out
- set (35's dump 233516Z-set-dump-a, zset10 235839Z): ALL AGREE, ens +0.00002 ± 0.00005
- player (51's dump 234943Z-pn-dump-2055Z, zplayer10 235950Z): pooled agree -0.00007
  tol 0.00013; block 2 marginal; Zig seed 1 identical across builds
- resid: own offsets stride partition +0.00063 DISAGREE -> MY bug: fifths from row-index
  hash gave optimistic OOF offsets (12/12 inner/fit better than Zig); random partition
  matches Zig's offset losses. lab-constraints line added (uncommitted). With Zig's
  offsets (xresid-zoff 001607Z vs zresid10 001624Z): pooled +0.00019 tol 0.00015, only
  block 2 (30 seeds fixed a: +0.00031 tol 0.00027, torch trains ~0.6 epoch longer, sd 2x;
  clipping ruled out: grad norm ~0.03, never clipped). Own random offsets (xresid5
  002828Z): +0.00045, blocks 2-3; offset realisation noise suspected: xresid5-o2/o3
  (003435Z, 003454Z) running to measure spread over offset seeds
- EMA 0.99 small: single seeds -0.00024, 10-seed ensemble -0.00002 ± 0.00010: no
Next: offset-seed spread -> resid verdict; write docs/model.md "### PyTorch cross-check"
+ docs/nn-results/pytorch.tsv; commit by path; report to meiolol-14; then experiments
(optimisers, schedules) and rerun on re-cut snap-20261013T2253Z when coordinator asks.

## Handover state 2026-10-14 ~01:30 (all committed locally, not pushed; coordinator pushes)
Commits: py/xcheck first commit; "PyTorch cross-check: no bug..." (model.md section before
"### Model tests", nn-results/pytorch.tsv + README key, lab-constraints line, scripts);
"cross-fitted training offsets ... 0.81-0.91" (model.md bullet).
Final comparisons: gpu-box runs *-fin-{small,big,set,player,residzoff,residown}.
offcmp 20261014T004223Z: log's block 5 lines duplicate dev's (restart overwrote?): used
blocks dev-4 only.
Open for successor (ask meiolol-14 which first):
1. Experiments cheap in torch (brief item 3): optimisers (sgdm in xnets --opt), LR
   schedules (cosine, one-cycle: not built), wider/attention nets, SWA; measure mean of
   10 seeds on inner val, then folds vs Zig/torch baseline with compare.py; winners to
   owners (0a nets, 35's successor set net, 51 player net)
2. Offset averaging for residual nets: average the cross-fitted candidate over k seeds/
   partitions (xnets --offset-seed exists; add averaging) and test whether resid/set/
   player gain more; owners may do it in Zig
3. Rerun the cross-check on re-cut snap-20261013T2253Z if the coordinator wants
   (needs Zig refs there: netcheck small/big/resid/set 10 seeds, dumps from 35's
   successor and 51)
4. Resid block-2 residue: +0.00031 with 30 seeds a side on identical offsets (torch
   trains ~0.6 epoch longer, 2x seed sd); not explained, clipping ruled out

## Successor (session 3c0d9d2f, from 2026-10-14 ~02:30)
Asked meiolol-14 which item first; defaulting to item 2 (offset averaging).
xnets --offset-avg K (uncommitted): training offsets (fit, inner) = mean of K cross-fits,
partition + ratings seed = offset_seed..offset_seed+K-1; val/scored one fit at offset_seed
(cand identical to K=1). Snap 2253Z re-cut, --ref rb-ref-wr (002905Z, Zig resid 5 seeds).
| id | question | status |
| --- | --- | --- |
| oavg-k1-o1, k1-o11 | single-realisation baseline + its spread | started |
| oavg-k5-o1, k5-o11 | K=5 average, and its spread | started |
| oavg-k10-o1 | K=10 | started |
Compare: k5 vs k1 same offset seed (same cand), compare.py; noise via o1 vs o11
Done (f89bc8c, model.md bullet + 2 tsv rows): offset averaging no gain (K5 +0.00001/-0.00010,
K10 +0.00004 ens vs K1, folds pooled, 2253Z). Torch own-offset resid agrees with Zig
rb-ref-wr on 2253Z (ens -0.00003/+0.00004 ± 0.00010). Told 14 and 51.
Next: item 1 experiments (schedules, optimisers, SWA) on 2253Z, inner val first
