---
title: 'Brown 2008: In-season prediction of batting averages, a field test of empirical Bayes'
url: https://arxiv.org/pdf/0803.3697
kind: paper
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: docs (sections 1, 3-5, Table 2 discussion)
relevance: high
grade: A/strong
description: Annals of Applied Statistics paper testing James-Stein, method-of-moments and ML empirical Bayes on out-of-sample batting averages with unequal sample sizes
---
# Brown 2008: In-season prediction of batting averages, a field test of empirical Bayes

Why: which closed-form shrinkage estimator holds up out of sample when units have very
different sample sizes (our thin vs thick matchups), and how to estimate the prior
variance.

## Assessment

- Evidence: A. Annals of Applied Statistics 2008, by a leading decision theorist; real
  out-of-sample validation on 567 players, the canonical modern follow-up to
  Efron-Morris.
- Reasoning: strong. Compares six estimators, explains why some fail (non-normal
  prior, n correlated with the mean).
- Interests: none known.
- Weigh: binomial data (we have roughly normal gold diffs, so the variance-stabilising
  step is unnecessary for us), but the heteroscedastic normal-normal set-up is exactly
  ours: per-matchup mean with known sampling variance sd^2/n.

## Findings

- [stats] Using each unit's raw average as its prediction (the naive method) is worse
  than ignoring individual data and predicting the overall mean. ^f1
  > This is not an effective prediction method. In terms of overall accuracy, as described later, it
  > performs worse than simply ignoring individual performances and using
  > the overall mean of batting averages
- [stats] Shrinkage scales with sample size: units with fewer observations are pulled
  harder toward the group mean; the best estimator cut squared error by about 40%
  relative to the overall mean. ^f2
  > the averages of players with fewer first-half at-bats undergo more shrinkage than those with more first-half at-bats.
  > by about a 40% decrease in total squared estimation error.
- [stats] [method] Normal-normal model: true values drawn from N(mu, tau^2), Bayes
  estimate mu + tau^2/(tau^2 + sigma_i^2) * (X_i - mu); empirical Bayes plugs in
  estimates of mu and tau^2 from the data. Eq. 4.3-4.4 ^f3
  > The empirical Bayes concept is to use the {X1i } distributed as in (4.5) in
  > order to estimate µ, τ 2 , and then to substitute the estimators of µ, τ 2 into
  > Bayes formula, (4.4), in order to yield an estimate of {θi }.
- [stats] [method] Method of moments estimate of tau^2: unweighted spread of the
  observed means minus the average known sampling variance, floored at zero; mu is the
  precision-weighted mean; one iteration is usually enough. Eq. 4.6 ^f4
  > positive-part sign in the definition of τ̃ 2 is a commonsense improvement on
  > In practice, with data like that in our baseball examples, one iteration of this system yields almost the same accuracy as does convergence to a full solution.
- [stats] Out-of-sample ranking (relative squared error, naive = 1): nonparametric EB
  0.508, James-Stein 0.525, EB method of moments 0.593, group mean 0.852, harmonic
  prior 0.884, EB maximum likelihood 0.902. Table 2 ^f5
  > The best performing predictors in order are those corresponding to the
  > nonparametric empirical Bayes method, the James–Stein method, and the
  > parametric EB(MM) method. The performance of the parametric EB(ML)
  > method and the true (formal) Bayes harmonic prior method is mediocre.
- [stats] Why ML failed: sample size correlated with the true value (better hitters
  bat more), so the n-weighted ML estimate of tau^2 was too small and over-shrank; the
  unweighted method of moments estimate did better. ^f6
  > The EB(ML) estimator essentially computes a weighted estimate
  > of τ 2 with weights proportional to the values of Ni .
  > A smaller estimate for τ 2 results in an estimator which shrinks more.
- [stats] (inferred) Same risk for us: popular matchups (high n) are likely the
  balanced, meta ones, rare matchups (off-role picks) more extreme, so estimate tau^2
  with an unweighted or method-of-moments estimator, not n-weighted. ^f7
- [stats] Splitting into clearly different groups first (pitchers vs others) and
  shrinking within groups helps a lot; group means differ (0.255 vs 0.153). ^f8
  > It is clear from Table 1 that it is desirable to separate the two types of
- [stats] (inferred) For us the analogue of "group" is the additive champion baseline:
  shrink a matchup toward A's lead plus B's deficit, not toward the role mean. ^f9

## Read

- Abstract, section 1 (questions and answers in brief), section 4 parametric EB, section
  5 Table 2 and discussion

## Not read

- Nonparametric EB (Brown-Greenshtein) details, section 2 variance stabilisation tests,
  hot-hand analysis
