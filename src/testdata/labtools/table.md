Ranked by inner-validation log loss (fit games only). Gains vs the command's
reference (netcheck: ratings; playernet: its -Dcand candidate) in milli-nats
per game, positive = net better: folds pooled by games, mean over
seeds ± its paired 95% half-width; better in = folds whose mean over seeds
favours the net; seed sd = spread of the per-seed gain;
ens = the seeds' averaged predictions (netcheck's ens rows), folds pooled.
ref = SPACE's reference config: the bar, never ranked.

| # | trial | val log loss | fold gain | better in | seed sd | ens gain | dev gain | seeds x blocks | epochs | GPU s | config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ref | ref (partial) | 0.68911 | -0.38 ± 1.02 | 0 of 1 | 0.86 | -0.06 | - | 3 x 1 | 2.48 | 16 | --lr 0.001 --wd 0.01 --batch 512 --layers 2 --emb 32 |
| 1 | t09 (partial) | 0.68890 | -0.51 ± 0.99 | 0 of 1 | 0.39 | -0.15 | - | 3 x 1 | 2.73 | 12 | --lr 0.0004267 --wd 0.02505 --batch 256 --layers 2 --emb 79 |
| 2 | t02 (partial) | 0.68954 | -1.32 ± 1.03 | 0 of 1 | 0.48 | -1.05 | - | 3 x 1 | 2.73 | 16 | --lr 0.0001006 --wd 0.009379 --batch 2048 --layers 4 --emb 28 |
| 3 | t08 (partial) | 0.68954 | -1.32 ± 1.03 | 0 of 1 | 0.48 | -1.05 | - | 3 x 1 | 2.73 | 16 | --lr 0.002023 --wd 0.005838 --batch 2048 --layers 2 --emb 75 |
| 4 | t07 (partial) | 0.68959 | - ± - | 0 of 0 | - | - | -0.01 | 0 x 0 | 1.75 | 5 | --lr 0.001063 --wd 0.01143 --batch 2048 --layers 1 --emb 11 |
| 5 | t06 (partial) | 0.68973 | -1.21 ± 1.56 | 0 of 1 | 0.57 | -0.98 | - | 3 x 1 | 1.73 | 12 | --lr 0.0003182 --wd 0.04455 --batch 512 --layers 2 --emb 181 |
| 6 | t12 (partial) | 0.68973 | -1.18 ± 1.13 | 0 of 1 | 0.57 | -0.95 | - | 3 x 1 | 1.73 | 13 | --lr 0.0006829 --wd 0.02375 --batch 256 --layers 4 --emb 19 |
| 7 | t01 | 0.69038 | +0.33 ± 0.26 | 3 of 5 | 0.17 | +0.42 | -0.09 | 3 x 5 | 5.60 | 67 | --lr 0.0001152 --wd 0.02272 --batch 2048 --layers 2 --emb 56 |
| 8 | t04 | 0.69038 | +0.33 ± 0.26 | 3 of 5 | 0.17 | +0.42 | -0.09 | 3 x 5 | 5.60 | 67 | --lr 0.0001686 --wd 0.02923 --batch 256 --layers 4 --emb 13 |
| 9 | t10 | 0.69038 | +0.33 ± 0.26 | 3 of 5 | 0.17 | +0.42 | -0.09 | 3 x 5 | 5.60 | 67 | --lr 0.001091 --wd 0.03874 --batch 2048 --layers 2 --emb 241 |
| 10 | t03 | 0.69064 | +0.17 ± 0.18 | 4 of 5 | 0.10 | +0.24 | -0.05 | 3 x 5 | 0.97 | 40 | --lr 0.0003302 --wd 0.02867 --batch 256 --layers 1 --emb 216 |

11 of 13 trials scored; none yet: t05 t11
