---
title: 'Richman 2026: Scaling Laws, Tabular Data and Actuarial Ratemaking Models'
url: https://arxiv.org/abs/2609.03106
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1-2, 7.1 overview, 7.9 seed ensembles, 8 conclusion)
relevance: high
grade: B/fair
description: Sept 2026 preprint: GLM vs MLP, Transformers and TabM on a 4.5M-row noisy motor-insurance frequency task; GLMs hard to beat near 10^5 rows, non-linear models gain only in the millions, by small margins
---
# Richman 2026: Scaling Laws, Tabular Data and Actuarial Ratemaking Models

Why: the closest analogue found to our setting: a noisy outcome, mostly categorical
rating factors, a strong regularised GLM baseline, and 10^5 to 10^6+ rows.

## Assessment

- Evidence: B. Preprint (not yet reviewed) by a known actuarial ML author; real
  4.5M-row insurer portfolio, nested fractions, multiple seeds, bootstrap intervals.
- Reasoning: fair. States that the floor and exponents are conditional on data,
  features and tuning; one dataset; heavy on architecture variants.
- Interests: author's consultancy works on deep actuarial models.
- Weigh: trust the regime story (GLM until ~10^5, small NN gains in the millions);
  the size of gains is specific to insurance frequency.

## Findings

- [method] [stats] Regime shift: near 10^5 rows GLMs and strongly regularised
  baselines are hard to beat; in the multi-million range non-linear tabular models
  keep improving. Section 8 ^f1
  > as training data grows from ∼ 105 rows into the multi-million range, the compute-optimal choice changes. In smaller data regimes, GLMs and other strongly regularized baselines remain difficult to beat
- [method] At small fractions the smallest MLPs were best; larger MLPs only became
  favourable as data grew. Section 7.1 ^f2
  > GLMs remain strong and stable throughout, but larger FFNs only become favorable as N increases: at small fractions the smallest FFNs are best, while at larger fractions the optimum shifts to the largest FFN
- [method] [stats] Gains at full data were small: best model improved on the GLM by
  0.00158 nats per policy of held-out log-likelihood. Section 8 ^f3
  > the best TabM-mini full-data extension improves by 0.00315 deviance (0.00158 per-policy log-likelihood).
- [method] Plain supervised Transformers scaled weakly with size; ensemble-style TabM
  scaled best. Abstract ^f4
  > TabM exhibits markedly stronger data scaling than purely supervised tabular Transformers and standard MLP baselines.
- [method] Seed variance is non-trivial even at 4M rows; averaging seeds is a cheap
  gain because log loss is convex in the prediction. Section 7.9 ^f5
  > Because the Poisson negative log-likelihood (and hence Poisson deviance) is convex in the predicted mean, averaging predictions across seeds can systematically reduce loss when predictions vary
- [method] [stats] Example fit: reducible loss falls by ~25% per doubling of rows
  (exponent 0.409) above a fitted floor. Section 2 ^f6
  > each doubling of data removes about 25% of the remaining gap to the fitted floor
- [method] (inferred) Read across to us at 90k games: a regularised logistic model is
  the right baseline now; non-linear models (FM, set nets, GBDT) become worth their
  cost around 10^6 games, and even then expect gains in the thousandths of a nat. ^f7

## Read

- Abstract, 1, 2 (credibility as a scaling law), 7.1, 7.9, 8

## Not read

- 3-6 data and architectures in detail, 7.2-7.8 per-family fits, compute allocation
