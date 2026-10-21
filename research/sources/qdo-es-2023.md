---
title: 'Purucker et al. 2023: Q(D)O-ES: Population-based Quality (Diversity) Optimisation for Post Hoc Ensemble Selection in AutoML'
url: https://arxiv.org/pdf/2307.08364
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (abstract, 1, 4.1, 6)
relevance: medium
grade: B/strong
description: AutoML Conf 2023 (Freiburg): population-based alternatives to greedy ensemble selection on 71 AMLB datasets; they beat GES significantly only on validation data, and ensembles fall below the single best model on some datasets: validation overfitting
---
# Q(D)O-ES (Purucker et al. 2023)

Why: does a smarter or diversity-seeking search over ensemble weights beat Caruana's
greedy selection out of sample, and how does diversity relate to overfitting?

## Assessment

- Evidence: B. AutoML Conference 2023, 71 AutoML Benchmark datasets, 10-fold CV, two
  metrics, leave-one-dataset-out choice of each method's configuration; ~3.9 CPU-years.
- Reasoning: strong. Separates validation from test significance and says what failed.
- Interests: authors propose Q(D)O-ES; they report its test gain as not significant.
- Weigh: IID CV; ROC AUC and balanced accuracy, not log loss.

## Findings

- [method/ensemble] The new searches outrank greedy ensemble selection, but significantly
  only on validation data; diversity helps but raises the risk of overfitting. Abstract ^f1
  > demonstrating that QO-ES and QDO-ES often outrank GES, albeit only statistically significant on validation data.
  > diversity can be beneficial for post hoc ensembling but also increases the risk of overfitting.
- [method/ensemble] Every post-hoc ensembler beat the single best model on average across
  datasets. 6 ^f2
  > post hoc ensemble selection is statistically significantly better than the single best model – we can always boost the performance on average.
- [method/ensemble] Yet on some datasets every method fell below the single best model on
  test, although each only proposes an ensemble that beats it on validation: direct
  overfitting. 6 ^f3
  > Because all methods have access to the validation score of the single best and only propose an ensemble if it outperforms the single best, this phenomenon is directly linked to overfitting.
- [method/ensemble] (inferred) For us: more search over ensemble weights buys validation
  gain, not test gain; prefer GES or a plain average with few, structurally different
  members, and report the gain on blocks the weights never saw. ^f4

## Read

- Abstract, 1, 4.1, 6 results (raw/qdo-es-2023.txt)

## Not read

- Appendix per-dataset results; the companion CMA-ES paper (arXiv 2307.00286)
