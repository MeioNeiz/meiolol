---
title: 'statmod glm.scoretest: score test for adding a covariate to a GLM (Smyth, CRAN 1.5.2)'
url: https://cran.r-project.org/src/contrib/statmod_1.5.2.tar.gz
kind: project
commit: cran-1.5.2
for: [smart-experiment-search]
looked: 2026-10-12
depth: code (man/glmscoretest.Rd, R/glmscoretest.R)
relevance: high
grade: A/strong
description: Gordon Smyth's R function (statmod, since 2009) giving Rao score z-statistics for adding a covariate to a fitted GLM, from the null fit's working residuals alone
---
# statmod glm.scoretest (Smyth)

Why: can a candidate feature be screened against the current model's residuals
without refitting, and what exactly is the statistic?

## Assessment

- Evidence: A. Long-lived CRAN package by Gordon Smyth (limma author); function dates
  from 2009, version 1.5.2 published 2026-05-17; the help page cites Dunn and Smyth
  (2018) and Pregibon (1982) for the theory. A CRAN vignette (lsreg-score-screening)
  reproduces its statistics independently.
- Reasoning: strong. The help page explains Wald versus LRT versus score, which fits
  each needs, and the limits (one numeric covariate at a time, no factors).
- Interests: none known.
- Weigh: trust the statistic. It is for GLMs fitted by maximum likelihood; our shrunk
  additive groups are penalised, so the projection step would need the penalised fit's
  weights and design (an approximation; inferred).

## Findings

- [stats] [method] Score tests need only the null model fitted; Wald needs the
  alternative, LRT needs both. `man/glmscoretest.Rd` ^f1
  > Wald tests require maximum likelihood estimates (MLEs) to be computed only under the alternative hypothesis, LRT tests require both the null and alternative models to be fitted, while score tests require only the null hypothesis to be fitted.
- [stats] [lab] That makes them cheap for testing many candidate covariates against a
  simple null model. `man/glmscoretest.Rd` ^f2
  > score tests can be a very computationally efficient choice when one wants to test for many potential additional covariates being added to a relatively simple null model.
- [stats] The three tests are asymptotically equivalent in ideal conditions. `man/glmscoretest.Rd` ^f3
  > All three types of tests (Wald, score and LRT) are asymptotically equivalent under ideal circumstances
- [stats] [method] The code computes it as a residual correlation: project the
  candidate off the current design (weighted QR residual), dot it with the weighted
  working residuals, divide by the projected candidate's norm (and dispersion, 1 for
  binomial). Result is a z-statistic, standard normal under the null. `R/glmscoretest.R` ^f4
  > x2.1w <- qr.resid(fit$qr,ws*x2)
  > colSums(as.matrix(x2.1w*zw))/sqrt(colSums(as.matrix(x2.1w * x2.1w)))/sqrt(dispersion)
- [stats] Limits: one numeric covariate per statistic; factors and multi-column terms
  need anova.glm's score option, which refits. `man/glmscoretest.Rd` ^f5
  > On the other hand, \code{anova.glm} can compute score tests for factors and multiple covariates, which \code{glm.scoretest} does not currently do.
- [stats] Checked, not there: no estimate of the effect size or of the predictive gain
  (log-loss) the covariate would bring; only a test statistic. ^f6
- [stats] [lab] (inferred) For meiolol: a candidate per-game feature (say a matchup
  term) can be screened as z = sum(x_resid * r) / norm(x_resid) on the current
  model's per-game residuals, in milliseconds, before any harness run; the z for a
  screen is not evidence of held-out gain and many screens need a multiplicity
  correction. ^f7

## Read

- `man/glmscoretest.Rd`, `R/glmscoretest.R` in full.

## Not read

- Dunn and Smyth (2018) section 7.2.6 (computational formula), Pregibon (1982).
