---
title: 'Tibshirani, Barber, Candes, Ramdas 2019: Conformal Prediction Under Covariate Shift (weighted conformal)'
url: https://arxiv.org/pdf/1904.06019
kind: paper
commit:
for: [share-drift-ranges]
looked: 2026-11-04
depth: listed (abstract, 2 weighted conformal, Corollary 1, 2.x experiments, discussion)
relevance: medium
grade: A/strong
description: NeurIPS 2019 paper extending split and full conformal prediction to covariate shift by weighting calibration scores with the test/train likelihood ratio, plus the general weighted-exchangeability result
---
# Tibshirani, Barber, Candes, Ramdas 2019: Conformal Prediction Under Covariate Shift

Why: can conformal calibration of share ranges be reweighted so that calibration cells
from earlier patches or earlier days stand in for the later days we forecast?

## Assessment

- Evidence: A. NeurIPS 2019, four leading conformal authors; the canonical weighted
  conformal reference.
- Reasoning: strong. Exact finite-sample guarantee, states the assumption (only the
  covariate distribution moves), shows the cost (effective sample size) and the
  estimated-weight case.
- Interests: none.
- Weigh: the guarantee needs P(Y | X) fixed; share drift within a patch breaks that
  unless the drift is captured by a covariate.

## Findings

- [stats/shares] Weighted conformal gives distribution-free intervals when test and
  training covariate distributions differ by a known (or well estimated) likelihood
  ratio. Abstract ^f1
  > a weighted version of conformal prediction can be used to compute distribution-free prediction intervals for problems in
  > which the test and training covariate distributions differ, but the likelihood ratio between these two distributions is
- [stats/shares] Each calibration score is weighted in proportion to w(X_i) =
  dP_test / dP_train at its covariates, and the band uses the weighted quantile; the
  normalising constant of w is not needed. Section 2, Remark 3 ^f2
  > by a probability proportional to the likelihood ratio w(Xi ) = dPeX (Xi )/dPX (Xi ).
  > with an unknown normalization constant,
- [stats/shares] The assumption is covariate shift: the conditional distribution of Y
  given X stays the same. Discussion ^f3
  > conditional distribution PY |X remains unchanged). In this case, known as covariate shift, the new weighted conformal
- [stats/shares] The cost is a smaller effective sample size, (sum w)^2 / sum w^2 (the
  Kish formula); coverage spread with oracle weights matched unweighted conformal at
  that smaller n. Section 2 experiments ^f4
  > we are relying on a reduced “effective sample
  > latter is fully explained by the reduced effective sample size.
- [stats/shares] Unknown weights can be estimated with any probabilistic classifier
  telling test covariates from training ones (logistic regression, random forests);
  coverage held on a low-dimensional example. Section 2, Discussion ^f5
  > by applying logistic regression or random forests (more generally, any classifier that outputs estimated
  > which we showed
  > empirically, on a low-dimensional example, can still yield correct coverage.
- [stats/shares] With no actual shift, estimated weights cost little (logistic about
  equal to unweighted; random forest slightly more dispersed). Section 2 ^f6
  > The unweighted and logistic regression approaches are very similar.
- [stats/shares] (inferred) For us: within-patch drift is a change in P(share |
  champion, slot), not in covariates, so weighted conformal does not apply directly to
  "calibrate on days 1-3, cover day 8+". It applies if horizon is a covariate: calibrate
  on earlier patches' truth tests with X = (days since patch at estimate, lead days, n
  bucket, slot kind) and weight to this patch's mix of X; valid as far as earlier
  patches drift like this one. ^f7
- [stats/shares] (inferred) Simpler equivalent when X is a few buckets: plain split
  conformal per bucket (lead days x slot kind) on past patches; weighting only matters
  if buckets are too thin. ^f8

## Read

- Abstract, 1 intro, 2 (weighted conformal, Corollary 1, airfoil experiments),
  discussion

## Not read

- Theorem 2 proof (weighted exchangeability), latent variable and missing data
  applications in detail
