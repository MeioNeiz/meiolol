---
title: 'Gelman and Hill 2007: Data analysis using regression and multilevel/hierarchical models, sections 12.6-12.9 and 13.1-13.5'
url: https://www.stat.cmu.edu/~brian/valerie/617-2022/0%20-%20books/0521867061%20-%20Andrew%20Gelman%20-%20Data%20Analysis%20Using%20Regression%20and%20Multilevel~Hierarchical%20Models%20%5b2006%5d.PDF
kind: book
commit: 
for: [hierarchical-comp-terms]
looked: 2026-10-18
depth: docs (sections 12.6, 12.9, 13.1, 13.5 start)
relevance: high
grade: A/strong
description: The standard applied multilevel textbook (Cambridge 2007); group-level predictors in the shrinkage target, varying slopes with a group-level predictor as a cross-level interaction, how many groups and observations are needed, non-nested (crossed) groupings
---
# Gelman and Hill 2007: chapters 12-13 (group-level predictors, varying slopes)

Why: the canonical text for "slope varies by unit, and its mean depends on the unit's
attributes": our champion-role slope on an enemy trait with kit-group membership as
the unit-level predictor.

## Assessment

- Evidence: A. The standard applied multilevel textbook, by Gelman and Hill; worked
  radon example (919 houses, 85 counties) with lmer output.
- Reasoning: strong. Shows each model several ways (as a hierarchy, as one
  regression with interactions), explains what the variance components mean and
  when multilevel adds little.
- Interests: none.
- Weigh: trust the structure and interpretation; the example is small and linear.

## Findings

- [stats] [method] Group-level predictor: county intercepts ~ N(gamma0 + gamma1 u_j,
  sigma_alpha^2); with lmer the group predictor is copied to each row
  (u.full, the county value per house). Section 12.6 ^f1
  > The lmer() function only accepts predictors at the individual level, so we have converted uj to
- [stats] The group predictor cut the unexplained between-county sd from 0.33 to 0.16
  and left within-county sd at 0.76; the group-level model is then worth about 23
  observations per county. Section 12.6 ^f2
  > These residual standard deviations were 0.76 and 0.33 without the uranium predictor.
  > so that the county-level model is as good as 1/0.044 = 23 observations within any county.
- [stats] It also narrowed the standard errors of every county's coefficient.
  Section 12.6 ^f3
  > The group-level predictor has increased the precision of our estimates of the county intercepts
- [stats] [method] Varying slopes with a group-level predictor: (alpha_j, beta_j)
  bivariate normal with means gamma0 + gamma1 u_j each; fitted as y ~ x + u + x:u +
  (1 + x | county). The cross-level interaction x:u is the group predictor's effect
  on the slope. Section 13.1 ^f4
  > the interaction corresponds to allowing uranium to be a predictor in the regression for the slopes.
- [stats] In the example the county slope sd went from 0.34 (no group predictor) to
  0.31 with uranium in the slope model; the x:u coefficient was -0.42 ± 0.23. A group
  predictor that barely reduces the slope spread adds little for the slopes. Section
  13.1 ^f5
  > the estimated standard deviation of the county slopes is σ̂β = 0.34
- [method] The same model is equally a regression with 4 + 2J predictors (constant,
  v, x, v x, group indicators and their x interactions) and three error terms; which
  view to show depends on whether the unit's values or the coefficients matter.
  Section 13.1 ^f6
  > A regression model with 4 + 2J predictors: the constant term, vi , xi , vi xi , indicators for the J groups, and interactions between x and the J group indicators.
- [stats] Partial pooling includes both extremes: zero group variance is complete
  pooling, large is no pooling; with few groups the group variance is hard to
  estimate and tends to be overestimated, so estimates end near no pooling. Section
  12.9 ^f7
  > when σα cannot be estimated well, it tends to be overestimated, and so the partially pooled estimates are close to no pooling
- [stats] Two observations per group is enough to fit; small groups still inform the
  group-level coefficients and variances. Section 12.9 ^f8
  > Even two observations per group is enough to ﬁt a multilevel model.
- [stats] Non-nested (crossed) groupings get one variance component each; the
  components show which grouping varies (airports 0.32, treatments 0.04 in their
  example). Group means fold into the intercept, so each batch is centred at 0.
  Section 13.5 ^f9
  > Their distributions are centered at zero (rather than given mean levels μγ , μδ ) because the regression model for y already has an intercept
- [stats] Checked, not there in these sections: multiple membership, scale beyond
  lmer, logistic varying slopes at millions of rows (chapter 14 covers logistic
  multilevel, not read). ^f10
- [method] (inferred) Our model in their terms: row = seat, x = enemy trait (z), j =
  champion-role, u_j = kit memberships (0/1, one column per group on that trait) and
  role. Fit = trait + role:trait + group:trait (the cross-level interactions, ^f4) +
  (trait | champion-role) random slopes. The group:trait coefficient is the kit
  group's reason, the champion-role random slope is "beyond its group", and sigma_beta
  with and without the groups (^f5) says how much of the champion spread the groups
  explain. ^f11
- [stats] (inferred) ^f2 gives the expected size of the help: shrinkage towards the
  group line is worth sigma_y^2 / sigma_beta^2 "observations". Our champcomp spread is
  near 0 in most roles (only Q-test roles keep spread), so the champion level is
  already almost complete pooling; a group term then mainly moves cells from the role
  mean to the group mean, and its held-out value is the group slope times the share
  of seats with a member, which is small for 4-9 champions per group. ^f12

## Read

- 12.6 (group-level predictors), 12.9 (how many groups), 13.1 (varying intercepts and
  slopes, group-level predictors, slopes as interactions), 13.5 opening (non-nested).

## Not read

- 12.7-12.8, 13.2-13.4 (inverse-Wishart, correlations), 13.6-13.7, ch. 14 (logistic
  multilevel), ch. 17 (Bayes fits of the same).
