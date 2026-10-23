---
title: Boosting for Transfer Learning (Dai, Yang, Xue, Yu, ICML 2007)
url: https://cse.hkust.edu.hk/~qyang/Docs/2007/tradaboost.pdf
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (sections 1-5)
relevance: high
grade: A/fair
description: ICML 2007 TrAdaBoost: a little labelled new data votes, round by round, on which old labelled instances still fit, by shrinking the weight of old instances the current model gets wrong
---
# Boosting for Transfer Learning (Dai, Yang, Xue, Yu, ICML 2007)

Why: the classic method for exactly "which outdated labelled instances are still
usable", with labels in the new domain, i.e. the p(y|x)-shift case density ratios
cannot handle.

## Assessment

- Evidence: A. ICML 2007, very widely cited and the base of a family of transfer
  boosting methods; experiments are nine binary text and mushroom splits, 10 random
  repeats, SVM base learner.
- Reasoning: fair. Convergence theorems are training-error results; they admit no
  improvement guarantee and show one case where the gain shrinks.
- Interests: own method; baselines are plain SVMs and one auxiliary-data method.
- Weigh: trust the mechanism and "helps when new data is under ~10% of old"; the
  per-instance signal assumes clean labels, which our outcomes are not.

## Findings

- [method/dynamics] Setting: old labelled data partly outdated, a small labelled sample
  from the new distribution votes on each old instance's usefulness. Section 1 ^f1
  > we employ a small amount of labeled new data, called same-distribution training data, to help vote on the usefulness of each of the old data instance
- [method/dynamics] Mechanism: each round, old instances the current model mispredicts
  get their weight multiplied by beta < 1; new instances follow AdaBoost (up-weighted
  when wrong). Section 3 ^f2
  > we add a mechanism to decrease the weights of these instances in order to weaken their impacts
- [method/dynamics] The gain is concentrated where new data is scarce: ratio of new to
  old under 0.1; above 0.2 it is a little worse than training on new data alone.
  Section 5.3, Figure 1 ^f3
  > when the ratio is larger than 0.2, the performance of TrAdaBoost(SVM) is a little worse than SVM
- [method/dynamics] No guarantee of beating the base learner; negative transfer
  possible, and the gain is smaller when the old data are less related (orgs vs places).
  Section 4, 5.3 ^f4
  > TrAdaBoost does not guarantee to improve the basic learner either
- [method] With little new data and many rounds the bound allows overfitting, though
  they saw less of it than theory suggests. Section 4 ^f5
  > However, as we will show in the experiments, TrAdaBoost does not overfit as easily as it is shown theoretically.
- [method] Checked, not there: no noisy-label or probabilistic-outcome experiments, no
  log loss, no time-ordered data (splits are by subcategory). ^f6
- [method/dynamics] (inferred) Per game, our outcome is near a coin flip, so "the model
  mispredicts this old game" is true for ~45% of games under any model; instance-level
  down-weighting would cut old games largely at random and fit noise. The usable form
  is per cell: down-weight old-patch games of a champion (or champion-item) by how
  badly its old-patch rate predicts its new-patch games. ^f7

## Read

- Sections 1-5 (setting, algorithm, theorems, experiments, figures 1-2).

## Not read

- Section 6 and the long version's proofs.
