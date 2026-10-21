---
title: 'Caruana, Niculescu-Mizil, Crew, Ksikes 2004: Ensemble Selection from Libraries of Models'
url: https://www.cs.cornell.edu/~alexn/papers/shotgun.icml04.revised.rev2.pdf
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (1-2, 5)
relevance: high
grade: A/strong
description: ICML 2004 (Cornell): greedy forward selection with replacement from ~2000 models on a hillclimb set, with sorted initialisation and bagged selection against overfitting; beats stacking with LR, Bayesian model averaging and the best model
---
# Caruana et al. 2004: Ensemble selection

Why: the origin of greedy ensemble selection (GES), still the default post-hoc ensembler
in AutoGluon, TabArena and Kaggle "hill climbing"; its own overfitting fixes.

## Assessment

- Evidence: A. ICML 2004, the canonical reference, ~2000 models on 7 problems, 10
  metrics, 20k-case test sets; used for two decades (AutoGluon, auto-sklearn, TabArena).
- Reasoning: strong. Each overfitting fix motivated and measured; admits gains are modest.
- Interests: none.
- Weigh: small hillclimb sets (1000 points) make overfitting worse than in our 300k
  scored games, but our per-game signal is far weaker, so effective sample size is small
  too.

## Findings

- [method/ensemble] Forward selection on a hillclimb set sometimes overfits it; three
  fixes: selection with replacement, sorted initialisation, bagged selection. 2 ^f1
  > sometimes overfits to the hillclimbing set, reducing ensemble performance. We made three additions to this
- [method/ensemble] With replacement, adding a model again acts as weighting and flattens
  the curve past the peak, so the hillclimb set itself can decide when to stop. 2.1 ^f2
  > Selection with replacement flattens the curve so much that a test set is not needed to determine when to stop adding models to the ensemble.
- [method/ensemble] Sorted initialisation: start from the best N models (typically 5-25)
  so early greedy steps cannot pick overfitting models. 2.2 ^f3
  > This typically adds 5-25 of the best models to an ensemble before greedy stepwise selection begins.
- [method/ensemble] Bagged selection: select from random halves of the library 20 times
  and average the 20 ensembles; overfitting combinations rarely land in one bag. 2.3 ^f4
  > We use p = 0.5, and bag ensemble selection 20 times to insure that the best models
- [method/ensemble] Stacking with logistic regression did poorly: regression overfits with
  2000 correlated models and 1k validation points; an unweighted average cannot overfit
  but includes bad models. 5 ^f5
  > Stacking (Wolpert, 1992) with logistic regression performs poorly because regression overfits dramatically when there are 2000 highly correlated input models and only 1k points in the validation set.
- [method/ensemble] Ensemble selection beat the best of 2000 models in 64 of 70
  problem-metric pairs, cutting loss 8.76% on average; bagging the selection gave about a
  third of that. 5 ^f6
  > Ensemble selection wins 64 of 70 times (significant at p = 0.001). On average, ensemble selection reduces loss 8.76% over the best models for each problem and metric.
  > On average, bagged ensemble selection reduces loss an additional 2.5% at p = 0.5.
- [method/ensemble] Gains are modest next to bagging or boosting trees (20%), because the
  best models are already good. 5 ^f7
  > For comparison, bagging or boosting trees yields a 20% reduction in loss compared to raw trees, 2.5 times the benefit of ensemble selection.
- [method/ensemble] (inferred) For us: a library of our lab models' forward-fold
  predictions (win-draft, additive v2, set net seeds, big net seeds, comp terms) suits
  GES with replacement, sorted init and bagging, fitted on folds 2-5 and scored on dev-val
  or sealed seeds; meiolol-97's tuned stacker already showed the choice-of-subset optimism
  this guards against. ^f8

## Read

- Sections 1, 2, 5 and Figure 2 (raw/caruana-ensemble-selection-2004.txt)

## Not read

- Section 6 SLAC case study; appendix of model settings
