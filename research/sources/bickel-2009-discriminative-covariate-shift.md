---
title: Discriminative Learning Under Covariate Shift (Bickel, Brückner, Scheffer, JMLR 2009)
url: https://jmlr.org/papers/volume10/bickel09a/bickel09a.pdf
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (sections 1-3, 7, 9-11)
relevance: medium
grade: A/strong
description: JMLR 2009 paper deriving instance weights as the test-to-training density ratio from a classifier that tells training from test inputs, with a two-stage version usable with any learner; assumes p(y|x) never changes
---
# Discriminative Learning Under Covariate Shift (Bickel, Brückner, Scheffer, JMLR 2009)

Why: the reference for domain-classifier (discriminative density-ratio) weighting, to
see what it assumes and whether it can pick trustworthy old-patch games.

## Assessment

- Evidence: A. JMLR, a standard reference for classifier-based density ratios; three
  problems (spam over nine inboxes, Cora before and after 1996, 29 x 28 landmine
  field pairs) with standard errors and paired tests.
- Reasoning: strong. Derives the weight, states the support condition, discusses
  tuning without target labels, compares against kernel mean matching and KDE.
- Interests: their own method; baselines include the strongest of the day.
- Weigh: trust the mechanism and its assumption; the gains (AUC near 0.99) say nothing
  about a 0.55 AUC problem.

## Findings

- [method] The whole method rests on covariate shift: input distributions differ,
  the label given the input is the same in training and test. Section 1 ^f1
  > the conditional distribution of the class variable given the instance is constant over training and test set
- [method] The loss-correcting weight is p_test(x)/p_train(x) (Shimodaira), valid only
  where training covers the test support. Section 2 ^f2
  > covariate shift can only be compensated for as long as the training distribution covers the entire support of the test distribution
- [method] That ratio needs no density model: a classifier separating training from
  test inputs gives it (weight = p(s=1)/p(s=-1) times (1/p(s=1|x) - 1)). Section 3,
  Equation 12 ^f3
  > can be evaluated based on a model that discriminates training against test examples and outputs how much more likely an instance is to occur in the test data than it is to occur in the training data
- [method] Two-stage version: fit a logistic domain classifier, then train any learner
  on the weighted sample, at a marginal cost against the joint fit. Section 7, 11 ^f4
  > This comes at the cost of only a marginal loss of performance compared to the integrated model.
- [method/dynamics] Tuning has no labelled test data; when the shift is over time,
  they tune on the later part of the labelled data. Section 9 ^f5
  > In this setting the parameters can be tuned by splitting the labeled training data into two consecutive parts.
- [method] Gains: spam 1 - AUC risk cut by up to 30% (iid AUC 0.994), Cora time split
  15% (iid AUC 0.998); separate kernel density estimates did not beat iid. Section 10 ^f6
  > The kernel density estimation procedure is not able to beat the iid baseline.
- [method/dynamics] Checked, not there: no experiment or discussion of p(y|x) changing;
  the weights cannot express "this old instance's label is now wrong". ^f7
- [method/dynamics] (inferred) For patches: the draft inputs hardly change their
  distribution (picks move toward buffed champions), while p(win | draft) changes for
  the patched champions. A domain classifier old vs new patch would learn pick-rate
  shifts and up-weight old games with now-popular champions, which fixes the wrong
  thing; it can still serve as a diagnostic of which drafts are typical of the new
  patch. ^f8

## Read

- Sections 1-3 (setting, prior work, integrated model and Equation 12), 7 (two-stage),
  9 (tuning), 10 (results), 11 (conclusion).

## Not read

- Sections 4-6, 8 and appendix: Newton updates, convexity proof, kernel mean matching
  relation; not needed for whether weighting applies.
