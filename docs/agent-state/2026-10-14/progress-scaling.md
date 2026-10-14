# progress: scaling curves (meiolol-30)

Question: at what fit-game count, if any, would a net pass ratings? Fit log loss =
a*N^-b + c[block] per model, project to production-key volumes (~130k games/day).

Tool: `meiolol-lab curve` (src/lab/curve.zig, a145c19): MODEL:COL:LABEL:DIR sources from
netcheck dirs, bootstrap over scored games, crossings, --tsv rows for
docs/nn-results/scaling.tsv. Run it on the gpu-box (no binaries on the Mac).
Queue script: scratchpad (this session's) qcurve.sh.

## Runs (gpu-box unless noted)
- reuse f1 (Mac, data/netcheck/f1): c-{big,small,resid}{25,50}, m-big, m-small, x-resid
  (100%), vs win-ratings, 3 seeds
- done: 20261013T210641Z-curve-small-ratings-f1 (Mac, before the gpu-box-only rule):
  reproduces f1 small +0.00066 ± 0.00029
- done: 20261013T212646Z-curve-big-ratings-f0.1: big 10% -0.00075 ± 0.00039 vs ratings
  (ratings weak at 10%)
- queued: curve-ratings-pinned (small, resid 10%), curve-comp-pinned (win-comp cand,
  10-100%, small seed 1 only as a by-product), curve350-ratings (small, resid 10-100%),
  curve350-comp, curve350-big (10-100%)
- pending: big1 config from 1c's sweep (0a sends it)

## 2026-10-14 ~00:00Z
- All curve runs done (gpu-box): 20261013T214021Z-curve-ratings-pinned, ...220126Z-curve-comp-pinned,
  ...221051Z-curve350-ratings, ...221710Z-curve350-comp, ...222220Z-curve350-big
- First fit 20261013T224457Z-curve-fit: pooled table good; separate power laws useless (b at
  grid floor). Added paired gap fit (979b14a). Final fit 20261013T230808Z-curve-fit queued
- Draft write-up: this session's scratchpad scaling-section.md (placeholders GAP_TABLE,
  READING_SLOPES, BIGCFG, PROJECTION); goes in model.md before "### Effects and the CPU model"
- Findings: win-comp better at every size 5/5 folds; big ahead at 6k, behind at 106k (1/5
  folds); resid -0.00012 at 106k; small level on 1954Z, worse on 2055Z
- Queued: curve350-bigcfg (big at 1954Z 100%, evals 4 patience 10, and lr 3e-4)
- Next (coordinator meiolol-bd): rerun everything on new pin ~/ml/snaps/snap-20261013T2253Z
  (ready ~00:10Z); then a plan for curvefit.zig ownership (plan.md "Curves next")
- Scripts: scratchpad qcurve.sh (runs), qfit.sh (fit; f1 dirs via --with)

## 2026-10-14 ~00:20Z
- curve now has accuracy + per-doubling trends (91795bc), --min-fit (15351f5)
- Fit 20261014T001310Z-curve-fit-all: ratings per doubling -0.00090 ± 0.00015 nats, +0.58 ±
  0.08 pp accuracy; gap slopes: big +0.00024/doubling (falls behind), resid -0.00014, small
  +0.00003, win-comp -0.00004. Interim sent to bd
- bigcfg (1954Z 100%): evals4+patience10 +0.00029, lr3e-4 +0.00028 vs default +0.00053:
  config explains ~0.0002, big still behind
- Queued (bfyhd9vib): curvepin-ratings, curvepin-big on 2253Z (win-comp waits for 73's
  repack), then curve-fit-min15k. Pin results: add 2253Z sources to qfit.sh
- Write-up draft in this session's scratchpad scaling-section.md still to finalise + commit
  with docs/nn-results/scaling.tsv rows (from scaling-rows.tsv in the fit run dir)

## 2026-10-14 ~00:50Z
- Coordinator now meiolol-14. Verifier meiolol-33 (audit request sent with run dirs)
- 2253Z curve runs (curvepin-*, curve-fit-pool/-2253/-lower/-upper) WITHDRAWN: pre-re-cut
  split (85fd62a). Don't cite them. Rerun on 73's ping after the repack: scratchpad
  qcurve-pin.sh (add a curvepin-comp line for win-comp), then qfit.sh with SETS. Count the
  withdrawn runs' scored games in the new test by match id vs new split.tsv; send to 14 + 33;
  the count goes beside the pin in model.md
- Write-up committed 0c3e486 (model.md "Scaling curves", docs/nn-results/scaling.tsv),
  2055Z + 1954Z only: ratings +0.58 ± 0.08 pp / -0.90 ± 0.15 mnats a doubling; flattening
  not established; no net passes ratings
- curvefit.zig plan sent to 14 (n_eff by player, patch decay, tau^2 smoothing, embedding
  blend for thin pairs); proposed handing it over with the 2253Z rerun

## 2026-10-14 ~01:00Z (handover)
- Audit (33) applied d2564c8; 2253Z re-cut results in model.md (941e833, c80df37) and
  scaling.tsv. Reported to 14: big's gap doesn't grow on fixed folds (+0.06 ± 0.21/doubling),
  small's does (-0.21 ± 0.07, ahead from ~90k); dev-val alone has big pulling ahead
- Open: win-comp 2253Z curve: gpu-box run *-curvercut-comp (check it finished; if not,
  queue `q cpu curvercut-comp ...` from qcurve-pin.sh). Read it only after 33's successor
  clears the win-comp reference (14 says); then COMP2253=1 SETS=2253 TAG=-rcut-comp bash
  qfit.sh and add the win-comp column/rows
- Scripts copied to the shared scratchpad's scaling-scripts/; win-comp run 20261014T004124Z-curvercut-comp
- 01:19Z: curvercut-comp finished (exit 0); ready to fit once 33's successor clears the win-comp reference
