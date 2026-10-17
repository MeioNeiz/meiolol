# Progress: pretraining track (meiolol-5b since 23:10, succeeded meiolol-97 [7beeb6] / meiolol-52)

Design: scratchpad pretrain-design.md (meiolol-ad). Code: src/lab/pretrain.zig (a88db2d,
74e059d). Write-up: docs/model.md "#### Pretrained champion-role embeddings" (95653e7).
Selection rule written there: inner-val statistic, not folds.

Data: Mac data/snap-20261012T2055Z-ss (symlinked DBs + gpu-box seat_stats.tsv + own pack).
Zig: put ~/.local/zig/zig-aarch64-macos-0.17.0 first on PATH (a resumed shell found
Homebrew 0.16 and lab-run builds failed).
Scripts (my scratchpad 271d063b.../scratchpad): select.py (inner-val statistic per run
dir), rows.py (nn-results rows from preds.tsv), games.py, pairs.py.

| id | question | status | found |
| --- | --- | --- | --- |
| d12 (full1) | E prior vs ratings, d12 | done, data/pretrain/d12, audited by 4b (no leak) | folds -0.00036 ± 0.00027 (ens), dev +0.00016 ± 0.00045; rare folds -0.00079 ± 0.00056; inner val -0.00017 |
| nowin | d12 without won term | done ~/ml/runs/20261013T211052Z-pt-nowin | folds -0.00033 ± 0.00030, dev +0.00005; inner val -0.00019 |
| d8 | variant | done gpu-box ~/ml/runs/20261013T213925Z-pt-d8 (26276f3) | folds emb -0.00024 ± 0.00027 (summary SE), rare -0.00076 ± 0.00057; run select.py/rows.py after pull |
| d16, noout | variants | gpu-box lab-run pt-d16, pt-noout (26276f3; Mac banned by Jacob); waiter task bo578wqmp | |
| winner rerun | on 74e059d | after selection | |
| shuffled-label control | --shuffle 1 on d12, gain must be ~0 | gpu-box pt-shuf (26276f3) | |
| nets with E | 0a: small net scratch vs init vs frozen, d12, vs win-ratings | done (Mac 20261013T205649Z-0a-pscr, 20261013T212239Z-0a-pinit; gpu-box 20261013T213554Z-0a-pfrz) | scratch folds +0.00022 ± 0.00025, dev +0.00020 ± 0.00062; init folds -0.00004 ± 0.00054, dev -0.00031 ± 0.00106; frozen folds +0.00049 ± 0.00068 (AUC 0.5326 vs 0.5397). init minus scratch folds -0.00026 ± 0.00057: no form helps; 0a stops unless d8/d16 clearly better on inner val |
| nn-results | docs/nn-results/pretrain.tsv | after selection | |
| CANN-style missing interactions | if room | not started | |

Next steps: when pt-* finish (deploy/lab-run.sh status gpu-box; pull with lab-run pull),
run select.py on all 5 run dirs (d12 = data/pretrain/d12, nowin = ~/ml/runs/...-pt-nowin/out,
others pulled to data/runs/RUN/out); winner by the model.md rule; rerun winner on
>= 74e059d if it was a pre-fix run (d12, nowin); fill model.md table (all 5 variants,
fold sign k/5, rare split, shuffled control, 0a's net rows) and docs/nn-results/pretrain.tsv
(rows.py; main answer first); send 4b the run dirs; report to coordinator meiolol-76.
Rules: Mac runs banned; nothing in learned.md before 4b's audit.

Other open asks:
- meiolol-ab (embx candidates read emb files via src/lab/embfiles.zig): keep header and
  fit_games semantics; for a test look, add a `final` block (fit on splits 0..9, write
  emb-final-s<seed>.tsv only, no scoring) on 76's go. Told ab so.
- meiolol-4b (verifier): send run dirs + games-*.tsv (pretrain writes them from 74e059d);
  rerun the winner on >= 74e059d before any test look.
- nn-results file: docs/nn-results/pretrain.tsv, spec docs/nn-results/README.md; first
  row = main answer vs ratings on folds; optional learned column.
- meiolol-ab confirmed: a test look needs only the final block (splits 0..9, emb-final-s<seed>.tsv), no selection block; ab adds "final" to embfiles.zig on 76's go.
- 22:5x: pt-d16 (20261013T215019Z) and pt-noout (20261013T215956Z) finished exit 0 on the gpu-box; pt-shuf not yet listed in status at that point. Pull with deploy/lab-run.sh pull gpu-box RUN.
- pt-shuf started as 20261013T220812Z-pt-shuf on the gpu-box.
- 23:2x (meiolol-5b): all runs pulled to data/runs/. Selection: inner val d8 -0.0001972,
  nowin -0.0001854 (tie band), d12 -0.0001679, d16 -0.0001474, noout -0.0001465 -> d8.
  d8 is post-fix (head a75878b, pretrain.zig = 26276f3), so no rerun. Folds 5/5 better
  for every variant; shuf +0.00028 ± 0.00014 (0/5). model.md results + nn-results
  pretrain.tsv committed f5b5499 (not pushed). Scripts: 5b scratchpad 56724cd8.../
  build.py, folds.py. Sent: 4b audit request, 0a pick (both 0a refs), 76 report asking
  test look (final block) vs stop. Waiting on 4b audit and 76's call.
- 76 chose (b): borderline, no test look. Next steps line in model.md (d8 rerun on 19 Oct
  snapshot; d8 offered to meiolol-08, sent). 0a's frozen dev-val row added. fe33e9b.
  Remaining: 4b audit sign-off, then close and tell 76.
- 4b audit d8: no leakage, rule followed; noise floor ±0.00048 -> not detected. Recorded in
  model.md, learned.md line (early), pretrain.tsv learned link. CLOSED by meiolol-5b.
  Open for later: d8 rerun on 19 Oct snapshot (model.md Next steps); 08 may ask for d8.
