---
title: 'Strobl, Boulesteix, Kneib, Augustin, Zeileis 2008: Conditional variable importance for random forests'
url: https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-9-307
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (abstract, 2.1, 2.4-5)
relevance: medium
grade: A/fair
description: BMC Bioinformatics 2008; the original conditional permutation importance for random forests (permute within a grid of each tree's cut points on correlated covariates), with the null-hypothesis view of why marginal permutation favours correlated predictors; R party::varimp(conditional = TRUE)
---
# Strobl, Boulesteix, Kneib, Augustin, Zeileis 2008: Conditional variable importance for random forests

Why: the origin of conditional permutation importance and its framing as a test of
X_j independent of Y given the rest.

## Assessment

- Evidence: A. Canonical, heavily cited; one simulation (12 Gaussian features, a block of
  4 at correlation 0.9, 500 repeats, linear response) and one small real dataset
  (n=310).
- Reasoning: fair. The null-hypothesis argument is clear and still the best short
  explanation; the method is random-forest specific and the simulation is small.
- Interests: authors' own method and R package.
- Weigh: trust the framing; the estimator itself was later found to underestimate at
  larger n ([[molnar-2023-conditional-subgroup#^f5]]) and is RF-only, so it is not a
  tool for us.

## Findings

- [method] Marginal permutation tests the null that X_j is independent of both Y and
  the other features, so a correlated but useless predictor scores as important.
  Section 2.4 ^f1
  > a positive value of the importance corresponds to a deviation from this null hypothesis – that can be caused by a violation of either part: the independence of X j and Y, or the independence of X j and Z
- [method] Conditional permutation (permute X_j within groups of Z = z) tests
  conditional independence of X_j and Y given Z instead. Section 2.4 ^f2
  > we suggest a conditional permutation scheme, where X j is permuted only within groups of observations with Z = z, to preserve the correlation structure between X j and the other predictor variables
- [method] Grid: the cut points of each tree on the conditioning variables; Z chosen as
  variables correlated with X_j above a threshold (r >= 0.2 in their simulation).
  Sections 2.5, 3 ^f3
  > Our suggestion is to define the grid within which the values of X j are permuted for each tree by means of the partition of the feature space induced by that tree.
- [method] [stats] Simulation: marginal importance strongly overestimated correlated
  predictors; conditional importance reduced but did not remove the preference, and had
  lower variability. Sections 3, 5 ^f4
  > With this scheme the importance scores of the correlated predictor variables are highly overestimated.
  > Even though the conditional permutation cannot entirely eliminate the preference for correlated predictor variables
- [method] (inferred) The null-hypothesis framing is the one-line test for us: a
  marginal permutation score for gold lead mixes "gold predicts winning" with "gold
  correlates with XP and kills"; only the first is what the dashboard wants to say. ^f5

## Read

- Abstract, simulation design, sections 2.4-2.5, results and conclusion.

## Not read

- Section 2.2 (selection bias in tree building), peptide example detail; Debeer and
  Strobl 2020 "Conditional permutation importance revisited" (lead).
