---
title: 'Szczecinski and Tihon 2021: Simplified Kalman filter for online rating, one-fits-all approach (JQAS 2023)'
url: https://arxiv.org/pdf/2104.14012
kind: paper
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (sections 1-2, 5, 6; Table I text)
relevance: medium
grade: B/strong
description: arXiv 2021, J. Quantitative Analysis in Sports 2023 (INRS Montreal); Kalman filter rating for any skills-outcome model, team games included, with Elo, Glicko and TrueSkill as special cases; on noisy sports outcomes the Bayesian tracker gains nothing over plain SGD (Elo)
---
# Szczecinski and Tihon 2021: Simplified Kalman filter for online rating, one-fits-all approach (JQAS 2023)

Why: does a Kalman filter (Glicko, TrueSkill style variance tracking) beat a simple
stochastic gradient rating when outcomes are as noisy as a draft's?

## Assessment

- Evidence: B. Peer-reviewed (JQAS), careful synthetic and empirical comparisons; one
  group's work, three leagues.
- Reasoning: strong. Unifies Elo, Glicko and TrueSkill, says when the extra machinery
  pays and when it does not, and gives the reason (observation noise).
- Interests: none beyond their method; the conclusion is partly against it.
- Weigh: trust the "noise erases the gain" conclusion; sizes are per league, not ours.

## Findings

- [method/dynamics] State-space rating: skills follow an autoregression, theta_t =
  beta * theta_(t-1) + noise of variance epsilon per unit time, beta below 1 meaning
  mean reversion; the online rating is an approximate Kalman filter on that model, for
  one-on-one and group games. Section II ^f1
  > The autoregression parameter 0 < βt ≤ 1 models the decrease of the skills in time (in absence of game outcomes).
- [method/dynamics] Glicko and TrueSkill are instances of the simplified Kalman filter
  with a diagonal covariance; Elo is its stochastic gradient (SG) simplification.
  Section VI ^f2
  > we demonstrate that, the Glicko and the TrueSkill algorithms may be seen as instances of our generic algorithms
- [method/dynamics] [stats] Keeping the full covariance (KF) gives the same results as
  the diagonal version (vSKF). Section VI ^f3
  > the differences between the KF rating (with a full representation of the covariance matrix) and the vSKF rating (only diagonal of the covariance is preserved) are negligible
- [method/dynamics] [stats] On real leagues (NHL, NFL, EPL) the Bayesian filter beats
  plain SG by little or nothing: small but notable in football, negligible in hockey,
  where outcomes are noisiest; NHL predictions are barely better than the outcome
  entropy. Sections V, VI ^f4
  > the differences between the vSKF and the SG results are, at best, small but notable (in football, where the data is relatively not noisy) and, at worst, negligible (in hockey, where the game outcomes are very noisy)
  > We observe in Table I that the predictions in the NHL are merely better than the entropy
- [method/dynamics] [stats] Where the filter helps is convergence: EPL ratings settle in
  about 50 days with vSKF against about 200 with SG, most for extreme teams; the final
  log score barely differs. Section V ^f5
  > the skills estimated using the vSKF converge very fast to the final values (after 50 days, approx.), to which the SG rating also converges but the time required is longer (200 days, approx.)
- [method/dynamics] Their recommendation: with noisy outcomes, simple Elo-type ratings
  are as useful as the Bayesian filter. Section VI ^f6
  > when dealing with the noisy observations, the simple algorithms, such as the Elo rating (which is a an instantiation of the SG rating) may be equally useful
- [method/dynamics] (inferred) Our draft outcome (log loss 0.6855 vs 0.6931) is noisier
  than the NHL's; a Kalman tracker's only likely payoff is faster settling after a patch
  jump, which matters only if strengths really jump. Test the jump first, the filter
  second. ^f7

## Read

- Abstract, sections I-II, V (empirical), VI (conclusions).

## Not read

- Section III-IV derivations, synthetic figures.
