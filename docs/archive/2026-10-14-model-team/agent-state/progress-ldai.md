# progress: LoLDraftAI evaluation beside ours (meiolol-d8, was meiolol-ba)

Question: does LoLDraftAI's random 90/10 split + 15-min filters inflate our numbers, and does
a small net beat the candidate there? Write-up docs/model.md "LoLDraftAI's evaluation
beside ours"; rows docs/nn-results/ldai.tsv. Audit: meiolol-4b. Report: meiolol-76.
Table script: /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/462953a6-6c12-41f3-8d60-7eb54494347f/scratchpad/ldai_table.py data/runs

Runs (gpu-box, snap-20261012T2055Z, netcheck --net small --seeds 1,2,3):
- *-ldai-{ratings,comp}-dev-{none,ldai}: time split dev-val (EUW1). done, pulled
- *-ldai-{ratings,comp}-r{1,2,3}-{none,ldai}: random split, EUW1-only scoring (old). done,
  pulled; superseded, kept as check (must equal new runs' EUW1 rows).
  20261013T205336Z-ldai-comp-r1-none duplicate, ignored
- *-ldaiall-{ratings,comp}-r{1,2,3}-{none,ldai}: random split, every platform scored
  (a75878b, 76's decision 13 Oct). done, pulled, verified (cand, commit f09e507)
- 20261013T200834Z-ldai-filter: filter drops 0.25%; no_timeline 29% (36% off EUW1, 11% EUW1)

Done 13 Oct 23:25: results 0060a53 (ldai.tsv, model.md). Audit sent to meiolol-4b; report to 76.
Findings: random split, every platform, ratings 53.07% AUC 0.543; EUW1 random 0.69174 vs time
0.68969 (no inflation, but populations differ; conflicts with 1abb887, open: paired check).
Small net ties ratings, worse than win-comp. win-comp -0.00055 ± 0.00037 on random. Filters
cost +0.00064 ± 0.00041 (fit -30%, no_timeline).
Open: 4b audit; 76 to decide on the paired inflation check; net exporter on hold.

## Paired inflation check (76's go, 13 Oct 23:30); reading fixed before looking
Model: win-ratings (preds.tsv `cand`, deterministic). Scored: games in random tenth k (k=1..3)
that a time-split block also scores. Random fit: ldaiall-ratings-rk-none (all dev-era games
outside tenth k, ~110k). Time fit: 20261013T214152Z-set-wr cand (dev-val fit before the dev
cut, 88,706; folds f1-f5 fit on games before each block); first check its dev-val cand equals
ldai-ratings-dev-none's exactly, else stop.
- Primary: dev-val (EUW1) games in the tenths, d = ll(random fit) - ll(time fit) per game,
  pooled over k, 95% clustered by game. Upper bound < 0: the random split flatters ratings by
  |d|; interval covering 0: not detected; lower bound > 0: random worse. Nothing else
  changes this reading.
- Secondary (descriptive): folds pooled (every platform), per block, EUW1 only; paired
  accuracy. Size control: random fit cut to the time fit's size (--fraction 0.807 ~ 88.7k),
  same dev-val games: d split into "more fit games" and "newer / same-period games".
Result (13 Oct 23:40): primary -0.00269 ± 0.00155 (2,276 games): random split flatters, = 4b's
paired check. Size control (*-ldaiall-ratings-r*-size, 88.7k fit) -0.00261 ± 0.00165: newer
games, not more. Folds' games: tie -0.00049 ± 0.00095. Script: d8 scratchpad inflation.py.
Committed c3bbe11 (model.md corrected per 4b, ldai.tsv paired rows first, Next steps: net
exporter on hold). learned.md unchanged (76: the line stands).
CLOSED. Nothing open from this line of work.
