---
title: 'McElfresh et al. 2023: When Do Neural Nets Outperform Boosted Trees on Tabular Data? (TabZilla)'
url: https://arxiv.org/abs/2305.02997
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1-2, 3 algorithm selection vs tuning, 4 metafeatures)
relevance: medium
grade: A/strong
description: NeurIPS 2023 datasets track study: 19 algorithms on 176 datasets (32 to 1M rows); the NN vs GBDT gap is usually negligible and light tuning matters as much as the family
---
# McElfresh et al. 2023: When Do Neural Nets Outperform Boosted Trees on Tabular Data?

Why: the largest NN vs GBDT comparison, with dataset size as a variable, to see which
family suits 10^5+ rows.

## Assessment

- Evidence: A. NeurIPS 2023 datasets track, 176 datasets, 19 algorithms, raw results
  public; broader sizes than Grinsztajn (32 to 1,025,009 rows).
- Reasoning: strong. Separates family choice from tuning; metafeature analysis with
  leave-one-out; cautions against general trends.
- Interests: none known.
- Weigh: trust "the family matters less than you think"; size trends are
  correlations across heterogeneous datasets, not controlled curves.

## Findings

- [method] The NN vs GBDT debate is overemphasised: often the gap is negligible, or
  light tuning of a GBDT matters more than the family. Abstract ^f1
  > for a surprisingly high number of datasets, either the performance difference between GBDTs and NNs is negligible, or light hyperparameter tuning on a GBDT is more important than choosing between NNs and GBDTs.
- [method] 30 iterations of random search on one good model beat picking the best
  family at defaults on about a third of datasets. Section 3 ^f2
  > Surprisingly, light hyperparameter tuning yields a greater performance improvement than GBDT-vs-NN selection for about one-third of all datasets.
- [method] GBDTs did relatively better on larger datasets (dataset size most
  negatively correlated with NN relative performance), contrary to Grinsztajn's
  appendix trend; TabNet is an exception that does well on large data. Section 4 ^f3
  > Throughout our metafeature analyses, we find that GBDTs perform comparatively better than NNs and baselines with larger datasets.
  > TabPFN performs particularly well on smaller datasets, and TabNet performs particularly well on larger datasets.
- [method] GBDTs favour irregular data: heavy-tailed, skewed or high-variance feature
  distributions. Abstract ^f4
  > GBDTs are much better than NNs at handling skewed or heavy-tailed feature distributions and other forms of dataset irregularities.
- [method] (inferred) Our inputs are clean one-hot categories with no skew, the
  irregularity where GBDTs shine; trees split one champion at a time, so pair effects
  need depth. Neither family is favoured a priori; a tuned baseline matters more. ^f5

## Read

- Abstract, 1, 2 related work (contrast with Grinsztajn), 3, 4 main findings

## Not read

- Appendix tables per algorithm, TabZilla suite details
