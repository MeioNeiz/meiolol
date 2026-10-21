---
title: 'Enouen, Liu 2022: Sparse interaction additive networks via feature interaction detection and sparse selection (SIAN)'
url: https://arxiv.org/pdf/2209.09326
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-5.1)
relevance: high
grade: B/fair
description: NeurIPS 2022 (USC); train a full net, detect interactions with an Archipelago variant, keep tuples whose subsets pass a heredity test, fit a neural additive model with those 1- to 5-way shape functions; the best order differs by dataset (1 on Appliances, 2 on Bike, more on others; >5 for Higgs and Year)
---
# Enouen, Liu 2022: SIAN

Why: the standard pipeline for "black box first, then a readable additive model with
only the interactions it needs, including 3-way", and evidence on when order 3+ helps.

## Assessment

- Evidence: B. NeurIPS 2022, code public; 7 real tabular sets (MIMIC-III, Appliances,
  Bike, California housing, Wine, Song year, Higgs); no planted ground truth for the
  selection step, no FDR.
- Reasoning: fair. Reports where its higher orders hurt (Appliances), compares many
  baselines; selection thresholds are tuned.
- Interests: authors' method (same lab as NID and Archipelago).
- Weigh: the order-by-dataset result is the useful part; the selection has no error
  control, so on noisy data it would need held-out checks.

## Findings

- [method/interpret] Pipeline: detect interactions in a trained net, select a sparse set
  of tuples with a heredity rule, then fit an additive network of shape functions on
  exactly those tuples. Abstract, Section 3 ^f1
  > we develop a tractable selection algorithm to efficiently identify the necessary feature combinations by leveraging techniques in feature interaction detection.
- [method/interpret] Detection uses an Archipelago adaptation, chosen because it works on
  black boxes; integrated Hessians needs smooth nets, and SHAP interactions had fast
  implementations only for trees. Section 3 ^f2
  > we primarily use an adaptation of Archipelago for higher-order interactions because of its compatibility with blackbox models.
- [method/interpret] Heredity, computational version: a tuple is a candidate only if a
  share tau of its subsets are above the detection threshold. Section 3 ^f3
  > our algorithm will instead focus on a computational version of heredity which asks that τ percent of subsets are above threshold θ in order for a pair (triple, tuple, etc.) to be considered as a possible interaction.
- [method/interpret] On Appliances Energy the 1-way model was best and test error grew
  with each added order; the full net was worst. Section 5 ^f4
  > As we increase the dimension of the SIAN, the test error slowly increases as the generalization gap grows; the full-complexity DNN has even worse error than all SIAN models.
- [method/interpret] On Bike sharing 2- and 3-way GAMs were best (one bivariate trend
  over 50% of variance); on Song year and Higgs full nets beat every SIAN up to order 5.
  Section 5 ^f5
  > the most important bivariate trend accounts for more than 50% of the variance in the dataset
  > These two are the only datasets where SIANs of order five or less are not sufficient to outperform vanilla deep neural networks
- [method/interpret] Few works fit 3-way shape functions in practice; the best order
  differs by dataset (also found by SALSA). Section 2 ^f6
  > Their work also corroborates our finding that optimal performance is achieved by different orders for different datasets.
- [method/interpret] Speed: 2-8x faster than NAM and NODE-GAM for mains, 10-80x for
  pairs, on a GTX 1080. Section 5.1 ^f7
  > with 2-8x faster training on GAM-1 models and 10-80x faster training on GAM-2 models.
- [method/interpret] Checked, not there: categorical high-cardinality inputs, a noisy
  binary outcome near chance, error control on selected tuples. ^f8
- [method/interpret] (inferred) For us the analogue is: fit the set net, rank seat pairs
  and triples by a four-corner swap score, then fit shrunk logistic terms for the top
  pairs (and triples whose three pairs all pass) on top of the shipped model, and keep
  an order only if paired held-out log loss improves; ^f4 is the warning that each
  added order can lose on held-out data when trends are mostly lower order. ^f9

## Read

- Abstract, 1-3 (method), 5 and 5.1 (results text).

## Not read

- Appendix C (detector comparison), result tables in full, MIMIC detail.
