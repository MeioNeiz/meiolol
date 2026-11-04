---
title: 'Berry and West 2018/2020: Bayesian forecasting of many count-valued time series (DCMM)'
url: https://arxiv.org/pdf/1805.05232
kind: paper
commit:
for: [share-drift-ranges]
looked: 2026-11-04
depth: skimmed (abstract, sections 2, 3.2-3.4 coverage, appendix A)
relevance: high
grade: A/strong
description: Duke (Mike West) paper, JBES 2020, on dynamic generalised linear models (Bernoulli logistic and Poisson DGLMs with discount factors, linear Bayes plus conjugate updating), a random-effect discount for overdispersion, and simulated multi-step forecasts checked by coverage and randomised PIT
---
# Berry and West 2018/2020: Bayesian forecasting of many count-valued time series (DCMM)

Why: a dynamic binomial/logistic model for a drifting share, with forecast ranges h days
ahead and overdispersion, in the West and Harrison DGLM tradition, written up openly.

## Assessment

- Evidence: A. Mike West co-wrote the DGLM framework (West, Harrison, Migon 1985;
  West and Harrison 1997); published in JBES 2020; applied to a supermarket chain's
  daily item sales with a year of rolling 1-14 day forecasts.
- Reasoning: strong. Gives the full update equations, the meaning of each discount
  factor, and reports where the baseline under-covers before fixing it.
- Interests: industry-funded (84.51, Kroger's data arm), no product to sell.
- Weigh: method is canonical; the Bernoulli DGLM is the binary case, our daily (n, k)
  binomial is the same conjugate step with k successes in n trials (our inference).

## Findings

- [method/dynamics] [stats/shares] A logistic DGLM puts the time-varying state on the
  logit of the probability and updates it each step with linear Bayes, avoiding MCMC.
  Section 2.1, appendix A.1 ^f1
  > The traditional logistic DGLM has λt = logit(πt ).
  > enables model analysis without resort to MCMC or other intensive computational approximations.
- [method/dynamics] [stats/shares] Each step: evolve state moments (a, R = G C G' + W),
  match a Beta prior to the logit's mean f and variance q via digamma and trigamma,
  update with the outcome, map back and update the state (a Kalman-like gain). Appendix
  A.1 ^f2
  > The conjugate prior in part 4 above is Beta, πt ∼ Be(αt , βt ), with the hyper-parameters defining
  > ft = ψ(αt ) − ψ(βt ) and qt = ψ 0 (αt ) + ψ 0 (βt )
  > mt = at + Rt Ft (gt − ft )/qt
- [method/dynamics] Evolution noise is set by a discount factor delta: the prior
  variance after evolution is the posterior variance divided by delta, i.e. each step
  adds 100(1 - delta)/delta percent uncertainty; typical delta 0.97-0.99, robust in
  that range, tuned on forecast metrics over training data. Appendix A.2.1 ^f3
  > part of the evolution increases uncertainties about state vector elements in each subvector j by
  > typical applications use values in the range 0.97−0.99 with, generally, robustness in terms of forecasting performance with respect to values in the range.
- [method/dynamics] The case study used fixed discounts 0.999 (Bernoulli) and 0.99
  (Poisson), chosen from earlier analyses of daily sales. Section 3.2 ^f4
  > Fixed discount factors of 0.999 (Bernoulli) and 0.99
- [method/dynamics] Multi-step forecasts: evolve the state k steps with no data, then
  use the conjugate predictive; for paths, forward-simulate one step at a time treating
  synthetic outcomes as data. Appendix A.3 ^f5
  > Forecasting k−steps ahead from time t, the forward evolution of DGLM
  > Treating this synthetic outcome as “data”, perform the time t + 1 update step to revise the
- [stats/shares] Overdispersion beyond the conjugate model is handled by a time-specific
  random effect on the linear predictor whose variance is the baseline variance times
  (1 - rho)/rho; rho = 1 is no random effect. Section 2.3 ^f6
  > a random effects discount factor ρ ∈ (0, 1] defines the conditional variance of ζt by vt ≡ V[ζt |Dt−1 , It−1 ] =
  > If ρ is set to one, then this model is simply the Poisson DGLM without the random
- [stats/shares] Baseline forecasts under-covered for one item at all horizons; adding
  the random effect (rho = 0.2, picked on a year of data) brought coverage and the
  randomised PIT close to ideal. Sections 3.3, 4 ^f7
  > item B we see evidence of under-coverage at all horizons, related mainly to the apparent inability
  > Coverage has increased and substantially
  > improved to conform with the 45−degree line
- [stats/scoring] Forecasts were judged per horizon (1, 7, 14 days) by empirical
  coverage of nominal intervals and by randomised PIT for discrete outcomes. Section
  3.3 ^f8
  > Figure 2 displays coverage of forecast distributions for each of 1, 7, and 14−days ahead.
- [method/dynamics] Checked, not there: no binomial (n trials per step) or multinomial
  DGLM worked out, and no learnt (as opposed to tuned) evolution variance. ^f9
- [method/dynamics] [stats/shares] (inferred) For us: a per-cell logistic local-level
  DGLM on daily (n_d, k_d / phi) is a few lines per day (Beta match via digamma and
  trigamma, conjugate update, linear-Bayes back to the logit). Its h-day range comes
  from evolving h times: with a discount delta, logit variance grows by a factor 1/delta
  per day, so a range made on day 3 for day 8+ widens by about 1/delta^5 or more,
  instead of a fixed tau2. Its one knob (delta, per slot kind) is tuned on the truth
  test, as they tune delta and rho. ^f10
- [stats/shares] (inferred) Their rho random effect is the dynamic analogue of our phi:
  a per-step inflation of the predictive variance on the link scale; in a share model
  the player-clustering phi (count side) and the discount (state side) are separate
  knobs and both are needed. ^f11

## Read

- Abstract, 1, 2 (DGLM, DCMM, random effects), 3.2-3.3 (setup, coverage), 4
  (random effects example), appendix A

## Not read

- Section 5 point metrics, multi-scale / decouple-recouple models (sections 6-7):
  relevant if we pool drift across champions (shared patch-wide adoption factor)
