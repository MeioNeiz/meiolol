---
title: 'Imai, Keele and Tingley 2010: A general approach to causal mediation analysis (Psychological Methods)'
url: https://imai.fas.harvard.edu/research/files/BaronKenny.pdf
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: docs (sections to concluding remarks; appendices not read)
relevance: high
grade: A/strong
description: Psych Methods 2010 paper behind the R mediation package; sequential ignorability, model-free simulation estimator for average causal mediation effects with any mediator and outcome model, sensitivity analysis on the mediator-outcome error correlation rho or R-squared
---
# Imai, Keele and Tingley 2010: A general approach to causal mediation analysis (Psychological Methods)

Why: the general simulation (g-computation) estimator for mediation with a binary outcome
and any models, plus the rho / R-squared sensitivity analysis for unmeasured
mediator-outcome confounding.

## Assessment

- Evidence: A. Thousands of citations; the R package mediation (CRAN, JSS 2014) is the
  default tool in social science; worked example on a randomised trial (JOBS II, n
  1,801).
- Reasoning: strong. Separates identification (one assumption) from estimation (any
  model), shows where LSEM is a special case, gives a sensitivity analysis tied to
  explainable quantities.
- Interests: academic; promotes its own package.
- Weigh: trust the framework. The closed-form sensitivity analysis is for probit-type
  latent models with normal errors, no interaction for the binary outcome case; a
  nonparametric outcome model needs a different sensitivity route.

## Findings

- [method] Sequential ignorability: (a) treatment independent of potential mediators and
  outcomes given pretreatment covariates; (b) mediator independent of potential outcomes
  given treatment and pretreatment covariates. Introduction ^f1
  > (b) the observed mediator is independent of all potential outcomes given the observed treatment and pretreatment covariates.
- [method] Part (b) does not follow from randomising the treatment, and only pretreatment
  covariates may be conditioned on. Sequential ignorability assumption ^f2
  > Unlike the ignorability of treatment assignment, however, the ignorability of the mediator may not hold even in randomized experiments.
  > Moreover, the conditioning set of covariates must be pretreatment variables.
- [method] Under that assumption average causal mediation effects are identified
  without functional form assumptions, so any mediator and outcome model can be used.
  Nonparametric identification ^f3
  > Theorem 1 implies that only the sequential ignorability assumption is needed and neither the linearity nor the no-interaction assumption is required for the identification of causal mediation effects.
- [method] Estimator: draw the mediator from the mediator model under treatment t', then
  the outcome from the outcome model under treatment t and that mediator draw; average
  (quasi-Bayesian draws or nonparametric bootstrap for intervals). Estimation algorithms ^f4
  > To do this, we first sample Mi(t⬘) from the selected mediator model, f(Mi 兩 Ti ⫽ t⬘, Xi ⫽ x), and then given this draw of the mediator, sample Yi(t, Mi(t⬘))
- [method] [stats] Mediation and direct effects differ by treatment arm (delta(1) vs
  delta(0)) when there is interaction; they sum to the total only under no interaction
  or when averaged across arms. Defining causal mediation effects ^f5
  > yielding the simple decomposition of the total effect into direct and indirect effects
- [stats] A near-zero total effect does not imply small mediation: direct and indirect
  effects can offset. Defining causal mediation effects ^f6
  > It is possible that the average causal mediation and average direct effects have opposite signs and thus offset each other, yielding a small average total effect.
- [stats] With a probit or logit outcome, neither difference nor product of coefficients
  consistently estimates the average causal mediation effect; product bias can be
  substantial. Binary outcome ^f7
  > Indeed, the nonlinearity of those models implies that unlike in the case of the LSEM, neither of the two methods consistently estimates the average causal mediation effects given in Equations 15 and 16.
- [stats] Proportion mediated is the average mediation effect over the total effect; it
  only makes sense when both have the same sign. The traditional gamma beta2 / (gamma
  beta2 + beta3) is a latent (logit) scale share, not the probability scale share.
  Binary outcome ^f8
  > Clearly, this quantity makes sense only when the sign of the sum of the two average causal mediation effects (i.e., the numerator) is the same as the sign of the average total effect
  > is a valid measure of the proportion mediated on the latent variable scale (logit or probit)
- [stats] In the binary JOBS II outcome the proportion mediated was 6% with a 95%
  interval of about -10% to 30%: proportions are imprecise. Table 5 ^f9
  > As a result, the estimated proportion mediated is a mere 6%.
- [method] Continuous (nonbinary) treatment: define effects for chosen treatment levels
  against a baseline and plot them over treatment intensity; the same algorithms apply.
  Nonbinary treatment ^f10
  > the causal mediation effects can be defined for any two levels of the treatment
- [method] [stats] Sensitivity analysis: rho, the correlation between mediator and outcome
  model errors, is 0 under sequential ignorability; report the rho at which the effect,
  and its interval, cross zero. Sensitivity analysis ^f11
  > With this fact, the proposed sensitivity analysis asks the question of how large does ␳ have to be for the causal mediation effect to go away.
- [method] Rho can be restated as how much variance an omitted confounder explains in
  the mediator and outcome (R-squared, pseudo-R-squared for binary), with a sign
  assumption; e.g. "ability" would need 60% and 30%. Coefficients of determination ^f12
  > This means that the unobserved confounder, ability, would have to explain 60% of the original variance in the (latent) mastery variable and 30% of the original variance in the depression variable for the estimate to be zero.
- [stats] Example of fragility: JOBS II mediation vanished at rho -0.165, its interval
  at -0.06; another study needed rho 0.48. No absolute threshold exists. Empirical
  illustration ^f13
  > Unfortunately, there is no absolute threshold.
- [method] They call a mediation analysis incomplete without sensitivity analysis.
  Sensitivity analysis ^f14
  > we argue that a mediation analysis is not complete without a sensitivity analysis.
- [method] Checked, not there: multiple mediators, panel or time-varying mediators,
  multilevel data left for future work. Introduction, Concluding remarks ^f15
  > Future research should extend this general framework to more complex situations such as panel data, multilevel models, and multiple mediators.
- [method] (inferred) For us: treatment = draft score (continuous), so report mediation
  for a fixed contrast (e.g. draft win logit at its 25th vs 75th percentile, or a
  one-sd change) and a curve over treatment levels, not one number. ^f16
- [method] [stats] (inferred) For us: the natural plug-in is our own models. Mediator
  model = gold@14 (or the 14:00 state) given draft and pre-game covariates; outcome
  model = win given draft, state and covariates (meiolol-state's model at minute 14).
  Simulate: for each game, draw M under draft d', then P(win | d, M) under d; average
  the probability differences. ^f17
- [stats] (inferred) For us: the "ability bias" example is our case exactly: player
  skill on the champion raises gold@14 and win. Calibrate rho or R-squared against the
  observed covariates (how much player history explains of gold@14 and win), rather
  than guessing. ^f18

## Read

- Main text to Concluding remarks, Tables 1-5.

## Not read

- Appendices (simulation of product-method bias, Appendix E; latent-scale proportion vs
  probability-scale proportion, Appendix G).
