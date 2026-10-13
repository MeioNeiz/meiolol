---
title: 'Lee, Apostolopulos, Markov 2023: Practical Knowledge Distillation, using DNNs to beat DNNs'
url: https://arxiv.org/pdf/2302.12360
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: docs (abstract, 1-3, Tables 2 and 7)
relevance: medium
grade: B/fair
description: USC and Meta 2023 arXiv paper; self-distillation over generations, ensembles of generations, label denoising and distilling ensembles into one XGBoost, on Meta tabular binary tasks at 10K and 100K rows
---
# Lee, Apostolopulos, Markov 2023: Practical Knowledge Distillation, using DNNs to beat DNNs

Why: does distillation (self or from a bigger ensemble) help a tabular binary
classifier at 10^4-10^5 rows, and is the gain from the distillation itself or from the
ensemble?

## Assessment

- Evidence: B. Meta production datasets (unnamed, anonymised), several tables, but one
  run per cell, no seeds or error bars, ROC AUC only, random samples.
- Reasoning: fair. Separates single students from ensembles of generations, which is
  the key point; explanations (DNN diversity) are post hoc.
- Interests: authors' own pipeline; XGBoost and TabNet out of the box.
- Weigh: trust that single distilled students do not reliably improve and that the
  gain comes from ensembling generations; do not trust the size of the 10K gains.

## Findings

- [method] Distillation does not reliably improve an individual student; ensembles of
  the generations improve consistently. Section 3.1 ^f1
  > We observe that distillation does not necessarily improve individual student models, but their ensembles demonstrate consistent improvement.
- [method] [data] Dataset B, 100K sampled rows, ROC AUC: single TabNet students went
  0.610, 0.619, then fell to 0.578-0.584 by generations 2-5; the TabNet ensemble of
  generations rose to 0.625; XGBoost went 0.677 to 0.724 and stayed ahead. Table 2 (cells
  split across lines, quote is the caption) ^f2
  > Table 2. XGBoost and TabNet ensembles on Dataset B (100K sampled rows)
- [method] At 10K rows the DNN beat XGBoost and gained far more from ensembling
  generations (TabNet ensemble 0.718 to 0.792 vs single 0.680 to 0.737; XGBoost single
  about 0.67-0.68). Section 3.3, Table 7 ^f3
  > We found that TabNet significantly outperforms XGBoost when we train the models on smaller sample sizes. Moreover, TabNet gains a much greater boost from ensembling, as seen in Table 7 for 10K random samples from Dataset B.
- [method] Why: DNN generations are diverse (consecutive generation correlation under
  0.36) while XGBoost generations are near copies (over 0.78). Section 3.3 ^f4
  > For TabNet, the correlations are <0.36 even for consecutive generations, while for XGBoost, the correlations are all >0.78.
- [method] Self-distillation from the previous generation vs from the full ensemble
  of prior generations: no serious difference on average. Section 3.4 ^f5
  > Our experiments in Tables 15 and 16 compare these two options, but show no serious differences on average.
- [method] Denoising: drop rows whose teacher prediction is far from the label
  (|f(x) - y| >= 0.99) during distillation; reported to help consistently. Section 3.2 ^f6
  > Per Table 3, threshold 0.99 leads to good performance and consistently improves results.
- [method] (inferred) For a noisy win label, dropping rows the teacher is confident
  are "wrong" means dropping upsets, which are real; at our 53-54% ceiling that is
  likely harmful, so the denoising part should not be copied. ^f7
- [method] (inferred) A between-generation correlation under 0.36 at 100K rows is a
  warning about single-net variance on noisy tabular labels: seed ensembles, not
  distillation, are the likely source of any gain for us. ^f8

## Read

- Abstract, 1, 2 (related work), 3.1-3.4, Tables 2 and 7

## Not read

- Section 4 (input-data distillation, ensemble weight optimisation), production
  results (Table 13), appendix tables
