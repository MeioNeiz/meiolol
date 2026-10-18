---
title: 'Stern, Herbrich, Graepel 2009: Matchbox, large scale online Bayesian recommendations'
url: http://web.archive.org/web/2015id_/http://www2009.eprints.org/12/1/p111.pdf
kind: paper
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (abstract, 1, 2.1-2.3, 4.1, 5)
relevance: medium
grade: B/fair
description: WWW 2009 (Microsoft Research Cambridge, the TrueSkill group); user and item traits are sums of per-feature trait vectors over id one-hots and metadata, each with an independent Gaussian prior; one-pass ADF / EP message passing; MovieLens and Netflix
---
# Stern, Herbrich, Graepel 2009: Matchbox

Why: the other way to put attributes and ids in one model: not "id shrunk towards an
attribute regression" but "id and attribute columns summed, each with its own prior",
from the TrueSkill group, fitted online without MCMC.

## Assessment

- Evidence: B. WWW 2009 by Microsoft Research's TrueSkill authors; used in Microsoft
  products; MovieLens 1M and Netflix 100M. The metadata gain is shown only in a
  figure, with no numbers in the text.
- Reasoning: fair. Clear model and inference; the metadata result is described as
  "seem to improve".
- Interests: Microsoft's system.
- Weigh: trust the model form and the cold-start direction; not a measured size for
  metadata.

## Findings

- [method] Each user and item is a sparse feature vector including a one-hot for its
  id and its metadata; the trait vector is the sum of per-feature trait vectors.
  Section 1 ^f1
  > In order to take account of user-speciﬁc and itemspeciﬁc tastes we can include a binary feature for every user ID and item ID in the set of features
  > the linear combination of the trait vectors for a particular user or item, weighted by the feature values for that user or item, provides a total trait vector for the user or item.
- [method] [stats] Priors: independent Gaussians (mean and sd) on every component,
  chosen for memory and fast inference. Section 2.2 ^f2
  > We choose this factorizing prior because it reduces memory requirements to two parameters (a mean and standard deviation) for each component
- [method] Inference: EP and variational message passing; ADF gives a single online
  pass, more EP passes improve it. Abstract ^f3
  > By using Assumed-Density Filtering (ADF) for training, the model requires only a single pass through the training data.
- [stats] Intended behaviour: metadata carry new users, ids take over once their
  ratings suffice. Section 1 ^f4
  > once we have observed suﬃcient user ratings we want to be able to make fully personalized predictions for the user based on their speciﬁc ratings rather than their features.
- [stats] MovieLens cold-start test (test users seen at 5% or 75% of their ratings):
  metadata "seem to improve" MAE, most at larger K; the per-user rating-threshold
  model helped far more. Section 4.1 ^f5
  > The meta data features seem to improve performance, especially for higher values of K.
  > The thresholds appear to help enormously to improve performance.
- [stats] Checked, not there: a number for the metadata gain, per-feature-group prior
  variances learnt from data (the priors are set, not estimated by EB), any check
  that the id and metadata parts are identifiable. ^f6
- [method] (inferred) This is the additive alternative to a group-level predictor:
  slope_c = sum of a role column, kit-group columns and an id column, each with its
  own N(0, s^2) prior. With a wide prior on the group columns it equals the Gelman-
  Hill model ([[gelman-hill-2007-ch12-13#^f4]]); with equal priors the split between
  group and id is set by the prior ratio, not the data, so the per-batch variances
  must be estimated (as [[ghosh-2022-logistic-crossed-re#^f3]]) for the shares to mean
  anything. ^f7
- [stats] (inferred) ^f5 is one more case where the structural term that matches how
  the outcome is produced (user thresholds) beat descriptive metadata; for us, a
  trait that is mechanistically right (enemy auto-attack build for G1) should matter
  more than the label "kit group". ^f8

## Read

- Abstract, 1, 2.1-2.3, 4.1, 5.

## Not read

- 2.4 dynamics, 3 inference details, 4.2 Netflix, 4.3 ads.
