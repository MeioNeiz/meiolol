# progress: context (meiolol-48)

Brief: brief-context.md. Candidate src/lab/cand/win-context (3d11c31).

| id | question | status | found |
| --- | --- | --- | --- |
| 20261013T211837Z-ctx-patch-folds5b (Mac, before the gpu-box-only order) | per-patch offsets vs ratings, 5 forward folds | done | -0.00014 ± 0.00020 (44,353 games); per fold -0.00027, -0.00064, +0.00023, 0 (no offsets: inner val chose none), 0; ratings 0.69090 matches f1/0d |
| 20261013T205545Z-ctx-folds5 + 20261013T205856Z-ctx-wr-ref (Mac) | dev-val pair | done | +0.00043 ± 0.00054 (8,500 EUW games, all patch 16.20) |
| 20261013T214649Z-ctx-patch-ctl (gpu-box, --head 3d11c31) | the same plus shuffled-patch control row | done | +patch -0.00014 ± 0.00020 (same as Mac); control -0.00008 ± 0.00012: no better than random labels |
| rank brackets | coverage | blocked | rank_start: 0 of 887,060 rows on snap-20261012T2055Z; rank_history days 12 and 13 Oct only, so only games from 13 Oct have rank_start, and those are in test on every snapshot so far. First dev coverage: weekly snapshot 19 Oct (13-17 Oct visible) |
| (3) embeddings in a net | | skipped | nothing in (1) or (2) to embed |

Snapshots: only patches 16.19 (54,750 games) and 16.20 in both snap-20261012T2055Z and snap-20261013T1954Z: one patch boundary; the bigger snapshot adds only 16.20 games. Patch offsets get a real test with 16.21 in dev.

Closed 2026-10-13: write-up e2ed6f4 (model.md "Patch and rank context", Next steps line, docs/nn-results/context.tsv); sent to 4b for audit. Brackets: rank_start null below Platinum IV, so Platinum, Emerald, Diamond, Master+.
