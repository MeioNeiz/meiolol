# Structured nets (meiolol-35 [397394], from meiolol-0d / c2)

Code: src/lab/setnet.zig (`netcheck --net set`), hook in winnet.zig (0696aad), controls
d8f1ebf. DeepSets per team on win-comp's 12 LOO profiles, residual on the candidate's
cross-fitted offset, antisymmetric. Defaults: phi 16, rho 16, cross 1, dropout 0.2 (rho
hidden), AdamW lr 1e-3 wd 0.1, batch 512, evals 4, patience 5; early stopping also scores
the start (0 epochs = candidate alone).

Runs: gpu-box, --res cpu, --head, ALWAYS -Dcand (default is base rates: set-a wasted).
Snapshot ~/ml/snaps/snap-20261012T2055Z, seeds 1,2,3, dev + folds 1-5.

| run | question | status | folds vs cand | dev-val | notes |
| --- | --- | --- | --- | --- | --- |
| 20261013T212805Z-set-a | (no -Dcand: vs base rates) | void | | | wrong reference |
| 20261013T214152Z-set-wr | set net vs ratings | done | -0.00042 ± 0.00023 | -0.00006 ± 0.00074 | better 3/5 folds, tie 1 (0 epochs), worse 1; offset weight 0.65-0.8 |
| 20261013T222221Z-set-wr-nocross | within-team only | done | -0.00049 ± 0.00023 | -0.00003 | 4/5 folds |
| 20261013T215541Z-set-wr-ids | + champion-role emb 8 | done | -0.00031 ± 0.00016 | | no better than without ids |
| 20261013T220534Z-set-wc | set net on win-comp's offset | done | -0.00020 ± 0.00017 vs win-comp | -0.00003 | 4/5, 1 tie |
| 20261013T221157Z-set-wr-fix | offset weight fixed 1 | done | -0.00024 ± 0.00015 | +0.00004 | 4/5: mostly not temperature |
| 20261013T221814Z-set-wr-permute | control: profiles permuted | done | -0.00003 ± 0.00005 | +0.00001 | passes: gain is profile content |
| 20261013T220241Z-set-wr-shuffle | control: results shuffled, offset 1 | done | +0.00016 ± 0.00023 | +0.00149 | passes: no fake gain |

4b audit of set-wr (8ea54ff): no leak; lopsided -1.20 ± 0.56 mn, balanced -0.23 ± 0.25; vs win-comp +0.15 ± 0.33 (lopsided +0.91 ± 1.10): not better than win-comp. A/A floor ~0.25 mn sd across 90% resamples: needs sealed seeds + resample before write-up.
First starts of fix/permute/nocross/wc failed at build (HEAD broken by 42ed9d6 for a while), restarted.
healthFit for meiolol-lab health (da1183c), asked by the tests session (sock 78474, also named meiolol-0a).

SEALED confirmation (declared to 4b before running): A = --cross 0 on win-ratings, B = default on win-comp; seeds 4,5,6; full + --resample 1, 2. Pass (amended with 4b before any result): full pooled folds seed mean + 1.6 x paired 95% half-width < 0 AND both resamples < 0; else "not confirmed". Runs conf-a, conf-b, conf-a-r1/r2, conf-b-r1/r2 (gpu-box).

Next: 4b gets run dirs + games-*.tsv for lopsided/balanced split and audit; rows to
docs/nn-results/structured.tsv (main answer first); model.md subsection under "Neural draft
models". Report to coordinator meiolol-76.

## Sealed verdict (2026-10-13 ~23:00Z)
- A within-team on ratings: full -0.37 ± 0.21 (4/5), widened -0.71..-0.03, r1 -0.13, r2 -0.16: CONFIRMED (barely)
- B set on win-comp: full -0.25 ± 0.17 (4/5), widened -0.52..+0.02, r1 -0.20, r2 -0.17: NOT confirmed
- Runs 20261013T223405Z-conf-a, 223644Z-conf-b, 224930Z-conf-a-r1, 225421Z-conf-a-r2, 225244Z-conf-b-r1, 225808Z-conf-b-r2
- Write-up 70abd0c (model.md "Set net: DeepSets on champion profiles", nn-results/structured.tsv); sent to 4b for audit; no learned.md yet

## Next (coordinator meiolol-bd)
- No new long campaigns on 2055Z. New pin snap-20261013T2253Z (pack ~00:10Z on gpu-box)
- Rescore win-comp there with seed spread, same games as meiolol-04's ratings (asked 04 for its command/commit); follow 4b's rebase checklist
- set-net sealed A/B rerun on the new pin is item e of 4b's rerun list

## Closed on 2055Z (2b70884)
- 33 audited: A confirmed barely (honest size ~0.15-0.4 mn), B not confirmed beyond win-comp; a0: all 4 resample binaries clean
- learned.md Win line 2026-10-14 (early); model.md, structured.tsv (learned column) updated

## Waiting
- meiolol-04's SHA (HEAD when 4a confirms the 2253Z pack). Then on that SHA, gpu-box --res cpu:
  1. win-comp refit spread: -Dcand=src/lab/cand/win-comp, netcheck --net small --blocks 1,2,3,4,5 --seeds 1 --resample N --out rN, N=1..12 chained in one job; pair games-win-comp.tsv with 04's rb-aa-small/rN/games-win-ratings.tsv
  2. compcheck ~/ml/snaps/snap-20261013T2253Z --folds 5, -Dcand=src/lab/cand/win-ratings

## Session meiolol-structured (pane 1010, ref [3ec461]), from 2026-10-14 00:40Z
- Waiting on 04's SHA. Prepared wc-rs args: scratchpad 6ca805e9.../wc-rs-args.txt (bash loop r1..r12 in one job)
- Lead after item 1 (from c1 via 35): extra set-net inputs from SNAP/comp_stats.tsv (src/lab/compstats.zig: vision, objective dmg, takedowns, catch/dive/save, item flags); model.md "### Comp discovery" (0a6a424). c1: only damage mix holds of 252 traits; cross-team not detected (agrees with set net)
- 00:00Z: started on 21412d3 then HELD by bd (2253Z seat_stats 77.5% coverage; meiolol-73 fills from 2055Z + repacks). 20261013T235531Z-wc-rs stopped; 20261013T235446Z-wc-compcheck finished but DISCARDED UNSEEN (not read). Rerun both after the repack, on 04's (new?) commit
- 14d8117: setnet init-loss gate (asked by new coordinator meiolol-14, took over from bd)
- 73: 2253Z re-cut (one time cut all platforms, test newest 15%, dev-val 10%), repacked; build >= 85fd62a; all 21412d3 runs void. Asked 04 for its rerun SHA
- started on 0c3e486: 20261014T003527Z-wc-rs, 20261014T002938Z-wc-compcheck
- 04 runs at 0c3e486: pair with 20261014T003438Z-rb-aa-small (rN/games-win-ratings.tsv); refs 20261014T002905Z-rb-ref-wr, 20261014T003341Z-rb-ref-wc
- 53: wc-rs r1 blocks match split.u8. KEEP RESULTS UNREAD until meiolol-14 says win-comp gate (item 5) passed; only exit codes/row counts/GATE FAIL checked
- both exit 0, 12x134375 games, no GATE FAIL; told 14; holding unread for gate item 5
- Lead (94, 52b49b5, model.md Comp discovery > Rerun on 2253Z): cross-team terms hold small on 2253Z sealed: AD share x enemy armour lean -0.63 pp/sd, AP mirror +0.56, tankiness x their pen items +0.62; beside mix -1.06; combined beyond mix -0.34 ± 0.25 mn (under floor). Set-net inputs that would carry them: armour_end - mr_end lean, pen-item rates (armour_pen, magic_pen, lethality), tank share (comp_stats/seat_stats). Relevant to set-net --cross 1 on 2253Z (item e)
