---
title: 'Zhu, Liu, Yi, Cai, Zhu, Zhang, He 2021: Open Benchmarking for Click-Through Rate Prediction (BARS-CTR, FuxiCTR)'
url: https://arxiv.org/pdf/2009.05794v6
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (1, 2.1, 3, Table 3, 4)
relevance: high
grade: A/strong
description: CIKM 2021 (Huawei Noah's Ark): 24 CTR models (LR, FM, HOFM, FFM, FwFM, DeepFM, DCN, xDeepFM...) retuned under one protocol on Criteo (46M rows) and Avazu (40M), 7000+ runs; logloss table and the finding that tuned deep models are indistinguishable
---
# BARS-CTR open benchmark (Zhu et al. 2021)

Why: the one benchmark that retunes FM, FFM, HOFM, FwFM and deep CTR models under one
protocol at tens of millions of rows; gives the size of each step over LR in log loss.

## Assessment

- Evidence: A. CIKM 2021, open code (FuxiCTR, used widely in CTR papers), 7000+
  experiments, numbers reproducible from configs.
- Reasoning: strong. Explains why reported results disagree (splits, preprocessing,
  tuning) and what it does about it.
- Interests: none beyond their library.
- Weigh: random 8:1:1 splits, 39 and 24 fields with millions of feature values and click
  rates ~20%, so interactions are far stronger than in drafts. Read the ordering and the
  "tuned models tie" finding, not the absolute gains.

## Findings

- [method/tabular] Industry treats 0.001 absolute in log loss or AUC as a practically
  significant gain. 1 ^f1
  > reveal that an absolute improvement of 1‰ in logloss (or AUC) is
- [method/tabular] Datasets: Criteo 46M and Avazu 40M rows, split randomly 8:1:1. 3.2 ^f2
  > them to randomly split both Criteo and Avazu into 8:1:1 as the
- [method/tabular] Criteo, dim 16, log loss x100: LR 45.68, FM 44.31, HOFM 44.11, FFM
  44.07, DNN 43.80, DeepFM 43.76, DCN 43.76. FM takes ~14 milli-nats from LR; HOFM, FFM
  and FwFM add ~2 more; deep models ~5 more. Table 3 ^f3
  > 2007      LR    44.74   78.58      45.68    79.34        0.9M     6    45.66      79.36      5.5M      12    7m × 12
  > 2010     FM     44.64   79.33      44.31    80.86       15.5M     9    44.45      80.78     227.5M     20    18m × 5
  > 2016     FFM    45.25   80.01      44.07    81.13      139.3M     18   44.09      81.11     638.2M     20    3h59m × 5
  > 2017 DeepFM     44.45   80.85      43.76(2) 81.43(3) 20.1M        30   43.78(2)   81.41(3) 229.1M     128    18m × 9
- [method/tabular] Avazu, dim 16: LR 38.15, FM 37.54, HOFM 37.54, FFM 37.20, FwFM 37.44,
  DeepFM 37.19: higher-order FM adds nothing over FM; field-aware FM about as much as a
  deep net. Table 3 ^f4
  > 2016   HOFM     37.56   77.01      37.54    78.91     123.8M    10     37.33      79.14    385.2M     31     1h47m × 1
  > 2018   FwFM     39.88   74.06      37.44    79.07      60.0M    15     37.24      79.25    334.9M     15     11m × 1
- [method/tabular] After exhaustive retuning, DeepFM, DCN, xDeepFM, IPNN and ONN tie; 544
  DCN runs on Criteo were indistinguishable from DeepFM; some newer models are worse. 3.4 ^f5
  > after exhaustive retuning, we found that the differences among the state-of-the-art models become small.
  > we run DCN for 544 and 496 experiments on
- [method/tabular] Reusing the original papers' hyperparameters on a new split costs up to
  5 per mille; retuning per split is needed. 3.4 ^f6
  > After model retuning, we achieve quite large improvements (up to 5‰) over the original hyper-parameters
- [method/tabular] (inferred) For us: the factorised step (LR to FM or FFM) is where most of
  the CTR gain sits, and DCN/DeepFM-style crosses add a further third; with draft pairs
  far weaker than ad-click crosses, expect at most a fraction of a milli-nat from a deep
  CTR model over a tuned field-aware FM on top of the shipped model. ^f7

## Read

- Sections 1, 2.1, 3 (setup, results), Table 3, 4 discussion (raw/bars-ctr-2021.txt;
  Table 3 appended from a layout extraction)

## Not read

- Later BARS versions with DCN-v2, FinalMLP results; the matching (retrieval) benchmark
