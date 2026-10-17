# progress: meiolol-state (live state model and what matters)

Brief: scratchpad/brief-state.md. Coordinator meiolol-bd approved plan (scratchpad msgs).
New pin coming (4a, ~2x games): build/test on 2055Z, real model runs on new pin.

## Done
- 659e017 src/lab/stateexport.zig `meiolol-lab state-export SNAP --every N --max M`
  -> SNAP/state/ (minute.f32 [M][n][C] minute-major, game.f32, meta.json). Shared with
  meiolol-41 (draftpath [36c2ab]), which reads it.

## Runs (gpu-box, lab-run --python ... --with py/xcheck/nnsets.py)
- 20261013T225405Z-state-export-2055Z: done. 185,334 games, 130,238 with timeline, 0
  mismatches vs stateBefore; 218 cols; minute.f32 6.6 GB. Told 41.
- 20261013T225705Z-state-smoke (fold 1, coverage): rich -0.0126 ± 0.0028 vs wc per
  game-minute, gbdt -0.0078, wcd -0.0042. Coverage table in its out/coverage.md
- 20261013T230024Z-state-models-2055Z: all 6 blocks, wc,wcd,rich,gbdt,gbdt_r (queued)
- 20261013T230230Z-state-imp-smoke: stateimp.py bucket 10 (queued)
- 20261013T230400Z-state-net-smoke: statenet.py fold 1, 1 seed (gpu)

## Next
- tell 41 when on gpu-box; coverage per column
- py/state/: baseline winchance-style smooth logistic, rich logistic, LightGBM, GPU net
- importance: research decided (msgs): 8 fixed groups, exact Shapley over 256 subsets
  with logistic per bucket, unique + alone, LightGBM unique/alone check, per-game
  contributions for CI; zero tests on forward folds. stateimp.py does this
- research live-win notes: report ECE per band (equal-mass bins), AUC; draft fade
  a(t) from wcd weights; headline mean LL minutes 5-20 + gain over gold-only LR;
  momentum = change in diffs over last 3 min; GRU only as challenger
- research mediation (draftpath's): keep minute-14 model taking draft logit as input

## 2026-10-14 ~01:05 BST
- 2055Z smoke (fold 1): imp at 10:00 Shapley economy 31%, xp 22%, fights 22%,
  structures 11%, dragons 7%, neutral 3%, draft 3%, vision 1%; draft unique 4.5 >
  alone 2.7 mnats. checks fold 1: momentum -0.00045 ± 0.00034, lead x draft ~0, late
  comp -0.0008 ± 0.0005. Net: netd val 0.009 better than nets but scored ~0.001: val
  may flatter netd (draft logit on fit rows is 80%-fit cross-fit, scored full-fit?)
- 2253Z export 20261013T235532Z (237,244 games w/ timeline, 10.7 GB)
- 2253Z runs (fit rows every other minute, fe1035d):
  20261014T000231Z-state-models-2253Z, 20261014T000244Z-state-imp-2253Z,
  20261014T000300Z-state-checks-2253Z, 20261014T000321Z-state-preds-2253Z (for 1d:
  SNAP/state/preds-wcd.tsv; message 1d when done)
- fd sweeps statenet (st1, 16 trials + ref, netd 5 seeds, then val pick with nets);
  don't edit statenet.py/nnsets.py until fd says queued
- 61 (carry): only type x own gold lead helps; 94 (comps): damage mix only survivor,
  no logloss gain; per-scored-team file only (can't feed fit rows) - not used
- bd: headline = per-minute importance table 5/10/15/20/25 with intervals
- Seat stats incomplete on 2253Z: my features don't use them (timeline + champ ids)
- 01:15 VOID: coordinator now meiolol-14 (from bd). 2253Z re-cut (one global time cut:
  test newest 15% of all played, dev-val next 10%, 5 forward folds below; 73 repacks with
  seat stats). All 4 of my 2253Z runs stopped unread; fd's st1 void. After 73's ping:
  rerun state-export on repacked 2253Z, check nn split.u8 code meanings vs nnsets.py,
  tell fd (re-queue st1), draftpath [36c2ab], 1d (preds), then rerun models/imp/checks/preds.
- Session renamed meiolol-state. Draftpath is now meiolol-30 [cc1fb5] (pane 1017; use
  the ref, another meiolol-30 exists): ping it with the new export run id. Its loader
  asserts state match_id.txt == nn's. 14: if 73's ping lacks split codes, ask 73 first.
- 02:10 re-cut 2253Z export 20261014T004121Z-state-export-2253Z-recut (363,472 games,
  290,825 timeline, match ids == nn; peak 12.7 GB RAM). Told draftpath, meiolol-37 (st1
  owner now, not fd). Started 20261014T011054Z-state-models-2253Zr and
  20261014T011111Z-state-imp-2253Zr. Next when models done: checks + preds (memory:
  don't run all 4 at once). Then tell 1d preds.
- 03:00 RESULT models-2253Zr (folds, per game-minute vs wc): wcd -0.00504 ± 0.00058,
  rich -0.01277 ± 0.00076 (5/5), gbdt -0.01067, gbdt_r -0.01276 (best round 1: trees add
  nothing beyond rich). dev-val rich -0.01366 ± 0.00148. Draft weight a(t) in wcd:
  1.07 at 1, 1.55 at 10, 1.71 at 20, 1.41 at 30, 0.95 at 40 (grows, no fade until 30+).
  AUC rich 0.773/0.838/0.871/0.896 at 10/15/20/25; ECE <= 0.005 to 30 min.
- imp-2253Zr: ~45 min a bucket; 5 and 10 done (10: economy 31%, xp 22%, fights 21%,
  structures 11%, dragons 7%, draft 5%, neutral 2%, vision 1%; full 124.7 mnats)
- started checks 20261014T020103Z, preds 20261014T020129Z, coverage 20261014T020205Z
- 04:00 NETS 2253Zr (20261014T022722Z-state-net-2253Zr, 0b10b1b, 3 seeds): netd vs rich
  ens gain (+ = net better, per game-minute): dev +0.0116, folds +0.0054/+0.0090/+0.0109/
  +0.0090/+0.0123; nets vs rich ~ -0.0002..-0.0005 (nets ~ rich). netd-nets ~ -0.01.
  CONTROL 20261014T022742Z-state-net-perm-2253Zr (whole drafts permuted in fit): netd vs
  rich -0.0004..-0.0031 all blocks -> gain needs real champions. No duplicate games
  (unique ids, no repeated draft). By minute (folds): netd-rich +0.0023 at 1, -0.004 at 5,
  -0.010 at 10, -0.0124 at 15, -0.0135 at 20, -0.0125 at 25, -0.0107 at 30.
  Conflicts: 61's type x own gold ~0.00005; b0 champion beyond state ~0.002. Localising:
  20261014T025645Z-state-neta-2253Zr (additive champions x minute), 
  20261014T025706Z-state-net-2055Z (netd,nets,neta on 2055Z: data-size check).
  st1 (37) go at 14a1d89, --live 1. Checks/preds/imp/coverage still in CPU queue.
- 04:05 DONE: imp-2253Zr (20261014T011111Z; out/imp.md, headline sent to 14), checks-2253Zr
  (20261014T020103Z: momentum -0.00038±0.00008 5/5, leadxdraft 0, late comp
  -0.00111±0.00016 5/5). imp gold equivalents muddled (collinear obj_ + detail cols) ->
  stategold.py (20261014T025902Z-state-gold-2253Zr). st1 queued by 37 (hash 10b72c0e, ~9h).
  Still queued: preds 20261014T020129Z, coverage 20261014T020205Z, neta, net-2055Z.
- 04:20 LOCALISED: neta (additive champions-by-minute, no champion x state) 2253Zr
  (20261014T025645Z) = netd's gain: vs rich dev +0.0117, folds +0.0049/+0.0086/+0.0108/
  +0.0092/+0.0122. So it's champion value beyond the state by minute (scaling), not
  interaction. 2055Z (20261014T025706Z, fit 35-65k games): netd vs rich dev +0.0031,
  folds -0.0006..+0.0044; neta dev +0.0043, folds +0.0008..+0.0056 (grows with data);
  nets ~ -0.0005 (nets ~ rich). Explainable test: richc (rich + ridge champion-role x
  minute hat effects) 20261014T032052Z-state-richc-2253Zr.
- 05:30 gold: 20261014T040551Z-state-gold-2253Zr2 (draft col unit bug: /100; rare cells
  wild) -> fixed c674ad3, rerun 20261014T0xxxxx-state-gold-2253Zr3. Preds for 1d landed
  (20261014T020129Z); 1d wants p_richc column once richc holds. coverage done.
  Draft write-up: scratchpad (4d4361c5 session dir) state-section.md. statecompare.py
  (efb98cf) to join nets/richc/control vs rich. Draftpath Q1 replicates: draft given
  state -0.020/game at 15-20 vs min-0 logit -0.005 -> cite, don't duplicate.

## STOP 2026-10-14 ~05:20 BST (Jacob out of usage, via bd). Nothing new started after this.
Runs on the gpu-box that may still finish (read them on resume):
- 20261014T032052Z-state-richc-2253Zr (statemodels --models wc,rich,richc; ~25 min/block)
- 20261014T041727Z-state-gold-2253Zr3 (stategold fixed c674ad3: final gold table)
- meiolol-37's st1 sweep (netd, 17 jobs, ~9 h, hash 10b72c0e): 37 sends the table
Finished results to use: models 20261014T011054Z-state-models-2253Zr (report.md),
imp 20261014T011111Z-state-imp-2253Zr (imp.md: headline), checks 20261014T020103Z,
coverage 20261014T020205Z, preds for 1d 20261014T020129Z (SNAP/state/preds-wcd.tsv),
nets 20261014T022722Z (netd+nets), control 20261014T022742Z (permute), neta
20261014T025645Z, 2055Z nets 20261014T025706Z, gold v2 20261014T040551Z (draft row /100).
Resume steps:
1. richc vs rich on folds (statecompare.py --ref RICHC_RUN:preds.npz:rich RICHC_RUN:
   preds.npz:richc NETS_RUN:preds-net.npz:netd NETS_RUN:preds-net.npz:nets NETA_RUN:
   preds-net.npz:neta PERM_RUN:preds-net.npz:netd=control); if richc gets most of neta's
   gain: add p_richc to statepreds.py and rerun for 1d (1d asked for it)
2. Fill state-section.md (this dir) -> docs/model.md before "### Draft model file";
   docs/nn-results/state.tsv (vs winchance; headline rich vs wc folds -0.01277 ±
   0.00076); cite draftpath Q1 (same champion-beyond-state finding, linear)
3. Ask 4b (or 14's auditor) to audit from run dirs before any learned.md line
4. Propose (don't ship) Your games' weights: rich or richc over winchance
