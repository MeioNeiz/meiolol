---
title: 'Large-Scale Poisson Regression with lsReg (CRAN vignette)'
url: https://cran.r-project.org/web/packages/lsReg/vignettes/poisson-regression.html
kind: docs
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: listed
relevance: low
grade: C/fair
description: CRAN vignette of the lsReg package showing score-test screening of ten candidate covariates from one base GLM fit, checked against statmod
---
# Large-Scale Poisson Regression with lsReg (CRAN vignette)

Why: a worked example of screening many candidates from one base fit.

## Assessment

- Evidence: C. A small package's vignette on simulated data; its value is the
  agreement with statmod's statistics.
- Reasoning: fair. States the trade-off (no estimate, only a statistic).
- Interests: package authors.
- Weigh: confirms the screening pattern works as described; no evidence about power.

## Findings

- [stats] [method] The score test is computed from the base fit only, for screening
  many candidate covariates; no parameter estimate is produced. `Overview` ^f1
  > The score test is computed entirely from the base model fit and does not require fitting the full model for each candidate covariate, making it especially efficient for large-scale screening. Because the full model is never fit, no parameter estimate is produced — only the test statistic.
- [stats] On simulated data the two true covariates of ten candidates had the largest
  score statistics, and values matched statmod's to numerical precision. `Results` ^f2
  > The variables `z5` and `z9` have the largest score statistics and the smallest p-values, consistent with the data-generating model.
  > The score statistics from `lsReg` match those from `statmod::glm.scoretest()` to numerical precision.

## Read

- Whole vignette.
