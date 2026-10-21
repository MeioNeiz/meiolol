---
title: Wild-Time: temporal distribution shift benchmark (Yao et al. 2022)
url: https://arxiv.org/abs/2211.14238
kind: paper
commit: 
for: [patch-transfer, frontier-dynamics]
looked: 2026-10-21
depth: docs (sections 1-5)
relevance: medium
grade: B/fair
description: NeurIPS 2022 datasets track: 5 datasets with temporal shift, 13 methods (invariant learning, continual learning, SSL, ensembles) against plain ERM on all past data
---
# Wild-Time: temporal distribution shift benchmark (Yao et al. 2022)

Why: does anything beat "train on all past data" when the future shifts? And how to evaluate over time.

## Assessment

- Evidence: B. Stanford (Finn, Koh), NeurIPS 2022 benchmark, 5 datasets, 13 methods, released code.
- Reasoning: fair. Clear protocols; shifts are gradual over years, not sudden known-date changes like a patch.
- Interests: benchmark authors; no method of their own to sell.
- Weigh: the "ERM on everything is hard to beat" result fits the drift literature; their shifts are total (images, text), ours are local.

## Findings

- [method/dynamics] Two protocols: Eval-Fix, one time split (train up to t, test after), and Eval-Stream, train at each time and test on the next K. Section 2.2 ^f1
  > Eval-Stream mimics standard machine learning development pipelines, where models are updated frequently and evaluated on timestamps in the near future.
- [method/dynamics] Moving to future data cost about 20% on average, and no method closed the gap. Abstract ^f2
  > we observe an average performance drop of 20% from in-distribution to out-of-distribution data
- [method/dynamics] Plain ERM on all past data stayed a strong baseline, even with fewer training examples. Section 5.3 ^f3
  > ERM has been shown to be a strong baseline in Wild-Time, even when we reduce the number of training examples
- [method/dynamics] Invariant learning methods mostly did not beat ERM. Section 5.3 ^f4
  > Most invariant learning approaches (CORAL-T, GroupDRO-T, IRM-T, LISA, mixup) did not show clear improvements over ERM.
- [method/dynamics] Fine-tuning and other incremental methods helped only where the shift is gradual, because they bias toward the latest times. Section 5.3 ^f5
  > incremental training tends to bias the trained model towards the last few timestamps
- [method/dynamics] (inferred) For us: pooled training on all patches is the bar every patch-aware arm must beat, and Eval-Stream (fit up to day d, score day d+1, roll) is the protocol that matches how the site refits. ^f6

## Read

- Sections 1-5.

## Not read

- Appendix D (Eval-Stream tables), E.4 (smaller training sets).
