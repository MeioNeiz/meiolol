---
title: 'Vansteelandt and Daniel 2017: Interventional effects for mediation analysis with multiple mediators (Epidemiology)'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC5289540/
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: docs (whole paper; eAppendix not read)
relevance: high
grade: A/strong
description: Epidemiology 2017 paper refining VanderWeele, Vansteelandt and Robins 2014 interventional (in)direct effects so they sum to the total, and extending them to several correlated mediators with unknown causal order; Monte Carlo estimator, breast cancer registry example
---
# Vansteelandt and Daniel 2017: Interventional effects for mediation analysis with multiple mediators (Epidemiology)

Why: our early state is several correlated mediators (gold, towers, drakes, kills) whose
causal order is unknown, and earlier states confound later ones; this is the estimand
built for that. Also restates VanderWeele, Vansteelandt and Robins 2014 (read here
instead of the original).

## Assessment

- Evidence: A. Epidemiology, two leading mediation methodologists; the estimand is now
  standard (later interventional effect models, R packages build on it).
- Reasoning: strong. States what is lost (mechanism precision) and gained (weaker,
  testable-in-principle assumptions, policy meaning), works a real example with
  bootstrap intervals.
- Interests: academic.
- Weigh: trust. Effects are on the additive (risk difference) scale here, which suits a
  probability-of-win outcome.

## Findings

- [method] Natural effects fail when a mediator-outcome confounder is itself affected by
  the exposure, which blocks repeated or correlated mediators. Abstract ^f1
  > In particular, they are known to be violated when confounders of the mediator–outcome association are affected by the exposure. This complicates extensions of counterfactual-based mediation analysis to settings that involve repeatedly measured mediators, or multiple correlated mediators.
- [method] Natural effects rest on cross-world counterfactuals that no experiment can
  reveal. Introduction ^f2
  > These concerns all originate from the fact that natural (in)direct effects are defined in terms of so-called cross-world counterfactuals 11 that are unobservable, even from experimental data
- [method] Interventional direct effect: set each subject's mediator to a random draw
  from the mediator distribution under the reference exposure, given covariates (a
  stochastic intervention), rather than to their own counterfactual value. Definitions ^f3
  > It differs from the controlled direct effect in that the intermediate is set for each subject to a random draw from the conditional distribution of M a* , given the observed covariates C for that subject
- [method] Identification allows mediator-outcome confounders L affected by the
  exposure, as long as the mediator effect is unconfounded given A, C and L.
  Identification ^f4
  > (ii) the effect of mediator M on outcome Y is unconfounded conditional on A , C and possibly some additional covariate vector L that may be affected by A
- [method] The VanderWeele, Vansteelandt and Robins 2014 versions need not sum to the total
  effect when L is present; this paper's versions do. Identification, Abstract ^f5
  > These expressions reveal a major weakness that we will attempt to overcome: the sum of the effects ( 1 ) and ( 2 ), which is sometimes called the ‘overall effect’ 21 , may differ from the total effect.
- [method] With one mediator and no exposure-induced confounder, natural effect estimates
  can be read as interventional effects even if the cross-world assumption fails.
  Identification ^f6
  > It thus follows that in single mediator models without post-treatment confounding, natural (in)direct effects obtained under assumption (iv) can also be interpreted as interventional (in)direct effects (even when that assumption is violated).
- [method] Interventional effects are policy-relevant: the effect of shifting the
  mediator's distribution to what it would be under the other exposure. Interpretation ^f7
  > In contrast to natural (in)direct effects, interventional (in)direct effects are policy-relevant 18 : they are relevant about a policy that involves fixing the mediator distribution, or shifting it to the extent that it is affected by the exposure.
- [method] With correlated mediators sharing an unmeasured cause, the path through one
  of them is not identified as a natural effect, and adjusting for the other does not
  help. Multiple mediators ^f8
  > Regression adjustment for M 2 provides no remedy because M 2 is an exposure-induced confounder so that adjusting for it would violate assumption (iv).
- [method] Proposed decomposition: direct, via M1, via M2, and via the exposure's effect
  on the mediators' dependence, valid whatever the causal order of M1 and M2. Multiple
  mediators ^f9
  > It can be used even when the causal structure between the mediators is unknown or when various mediators share unmeasured common causes.
  > This captures the indirect effect resulting from the effect of exposure on the dependence between the counterfactuals M 1 a and M 2 a , given C .
- [method] Estimator: Monte Carlo draws of each mediator from its fitted model under a or
  a*, predict the outcome, average; bootstrap for inference. Estimation ^f10
  > Finally, one may predict the outcome as the expected outcome under a suitable model with exposure set to a , M 1 set to M 1 a , i , M 2 set to M 2 a *, i , and covariate C i .
  > In practice, we recommend the bootstrap for inference.
- [stats] Example (29,580 patients): of a 2.8 point survival gap, 1.4 points mediated
  jointly; under interventional effects with no causal-order assumption, 0.7 via the
  mediators' dependence term, which they expected small but which was not. Illustration ^f11
  > of the 2.8% (95% CI 2.3%–3.4%) total difference in survival probability, about a quarter of this (0.7%, 95%CI 0.5%–0.9%) is mediated by the dependence of treatment on stage and age at diagnosis
- [method] Most mediation analyses involve several mediators, because confounders are
  often mediators too. Discussion ^f12
  > Most mediation analyses involve multiple mediators, either because of scientific interest in multiple pathways, or because certain confounders are mediators at the same time.
- [method] (inferred) For us: the 14:00 state is a set of correlated mediators (gold, CS,
  towers, drakes, heralds, kills) with no known order; use interventional effects with
  joint mediator draws: "how much of the draft's win effect is carried by the
  distribution of 14:00 states the draft produces". Split by mediator group only with
  the dependence term reported. ^f13
- [method] (inferred) For us: a per-game draw from P(state at 14 | draft d', covariates)
  needs a generative model of the 14:00 state; a cheap version is matching or
  reweighting real games (draw a 14:00 state from games with similar covariates and
  draft score d') instead of a parametric state model. ^f14
- [method] (inferred) For us: earlier states (minute 5, 10) are exposure-induced
  confounders of state at 14 and win; interventional effects allow them as L, so
  reporting mediation by minute (5, 10, 14, 20) is coherent, each one its own analysis,
  not a sum. ^f15

## Read

- Whole text including the illustration and discussion.

## Not read

- eAppendix (multiplicative scale versions, more than two mediators, Stata code).
- VanderWeele, Vansteelandt and Robins 2014 itself (summarised here).
