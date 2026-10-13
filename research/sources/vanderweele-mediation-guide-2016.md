---
title: 'VanderWeele 2016: Mediation analysis, a practitioner''s guide (Annu Rev Public Health)'
url: https://annualreviews.org/doi/pdf/10.1146/annurev-publhealth-032315-021402
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: docs (whole review, 16 pages)
relevance: high
grade: A/strong
description: VanderWeele's review of causal mediation (difference vs product method, assumptions A1-A4, interaction, logistic non-collapsibility, sensitivity analysis, measurement error, multiple mediators); a guide to his 2015 book
---
# VanderWeele 2016: Mediation analysis, a practitioner's guide (Annu Rev Public Health)

Why: the standard short reference for doing mediation with regressions: which assumptions,
which estimator, what goes wrong with a binary outcome. Read in place of the 2015 book
(Explanation in Causal Inference), which it summarises section by section.

## Assessment

- Evidence: A. Annual Reviews; the author wrote the field's main book and many of the
  methods cited (refs 8, 19, 46, 51-55 are his).
- Reasoning: strong. States assumptions, shows a worked failure (antidepressant example),
  gives direction of biases, admits what is not identified.
- Interests: academic; promotes his own SAS/SPSS macros and book, harmless.
- Weigh: trust the assumptions and bias directions. Its closed forms assume a rare
  outcome; ours (win, 50%) is common, so use its log-binomial or simulation routes.

## Findings

- [method] [stats] Difference method: total-effect coefficient minus the exposure
  coefficient once the mediator is added; product method: exposure-to-mediator
  coefficient times mediator-to-outcome coefficient. Traditional approaches ^f1
  > The difference between these two coefficients is sometimes interpreted as a mediated or indirect effect (IE): IE = φ1 − θ1 .
  > The indirect effect, however, is taken as the product of β 1 and θ 2
- [method] [stats] With linear models fitted by OLS the two always agree; with logistic
  regression they do not. Traditional approaches ^f2
  > With logistic regression with a binary outcome, the product and difference methods do not give numerically identical results.
- [method] [stats] Four assumptions for a causal reading: no unmeasured exposure-outcome
  (A1), mediator-outcome (A2) or exposure-mediator (A3) confounding, and no
  mediator-outcome confounder that the exposure itself affects (A4). Confounding
  assumptions ^f3
  > Finally, for standard estimates, as above, to be interpreted as direct and indirect effects, there should be no mediator-outcome confounder that is itself affected by the exposure (Assumption A4).
- [method] [stats] Mediator-outcome confounding must be controlled even when the exposure
  is randomised, because the mediator is not. Confounding assumptions ^f4
  > It is needed even in the randomized trial context because, in a trial, although the exposure has been randomized, the mediator typically has not been.
- [stats] Ignoring it can flip signs: in a randomised therapy trial the naive analysis
  made antidepressants look harmful and the direct effect larger than the total.
  Confounding assumptions ^f5
  > In short, we get nonsense from the traditional approach if we ignore mediatoroutcome confounding.
- [method] A4 gets less plausible the longer the gap between exposure and mediator.
  Confounding assumptions ^f6
  > This assumption likely becomes increasingly less plausible the more time that elapses between the exposure and the mediator.
- [method] [stats] With exposure-mediator interaction (theta3), direct and indirect effects
  are closed-form combinations of both models' coefficients; without it they reduce to
  theta1 and beta1 theta2. Allowing for exposure-mediator interaction ^f7
  > Note that when there is no exposure-mediator interaction (i.e., when θ 3 = 0), these expressions simply reduce to θ 1 for the direct effect and β 1 θ 2 for the indirect effect
- [stats] Logistic closed forms need a rare outcome; if it is common (over about 10%),
  neither product nor difference method is valid. Binary outcomes ^f8
  > However, if the outcome is not rare (10% is often used as a cutoff ), then the product method and the difference method can and do diverge, and, in fact, neither of these approaches nor the expressions given above are valid for the direct and indirect effects.
- [stats] Cause: odds ratios are non-collapsible; adding any covariate to a logistic model
  tends to grow coefficients, so adding the mediator can hide mediation. Binary outcomes ^f9
  > The problem arises because as we add covariates to the logistic regression model (even if these are not confounders), the coefficients tend to increase in magnitude
- [stats] With logistic regression the difference method is conservative: it tends to
  underestimate the indirect effect. Binary outcomes ^f10
  > the difference method will generally underestimate the indirect effect when used with logistic regression
- [method] Fix for a common outcome: a log-linear (log-binomial) outcome model, on the risk
  ratio scale, where product and difference agree. Binary outcomes ^f11
  > When the outcome is common, we can circumvent these issues by fitting a log-linear model rather than a logistic model.
- [method] [stats] Sensitivity analysis for unmeasured mediator-outcome confounding (Ding
  and VanderWeele): two parameters, gamma (confounder-outcome risk ratio) and lambda
  (confounder-exposure ratio within mediator levels), give a bias factor that divides
  the direct effect and multiplies the indirect one. Sensitivity analysis ^f12
  > divide the direct effect estimate and both limits of its confidence interval by the bias factor B and then multiply the indirect effect estimate and both limits of its confidence interval by the bias factor B
- [method] Report a table of corrected estimates over a grid of the two parameters, and at
  least how much confounding would bring the estimate, and its interval, to the null.
  Sensitivity analysis ^f13
  > At the very least, however, it is good practice to report how much unmeasured confounding would be required to reduce the direct effect estimate to the null
- [stats] Nondifferential error in the mediator biases the indirect effect toward the null
  and the direct effect away from it (always for a binary mediator, or continuous
  mediator and outcome without interaction; often otherwise). Measurement error ^f14
  > then one can show (28, 51) that the indirect effect will be biased toward the null and the direct effect will be biased away from the null.
- [method] [stats] Summing proportions mediated one mediator at a time fails if mediators
  affect one another or interact; a joint analysis of the whole mediator set works even
  when their order is unknown. Multiple mediators ^f15
  > Sometimes an informal approach is used for multiple mediators by assessing mediation one mediator at a time and then summing the proportion mediated across mediators. If the mediators affect one another, then this approach fails.
- [method] [stats] The effect through one mediator is generally not identified when an
  earlier mediator affects it, short of strong linear, no-interaction assumptions as in
  SEM. Multiple mediators ^f16
  > In this context, direct and indirect effects are generally not identified, even if one has data on all the variables (4, 47), unless one makes further strong modeling assumptions
- [method] Definitions (Robins and Greenland, Pearl): controlled direct effect fixes the
  mediator at m; natural direct effect sets it to what it would have been without
  exposure; natural indirect effect changes only the mediator's counterfactual value.
  Precise counterfactual interpretation ^f17
  > natural direct effects fix the intermediate variable for each individual to the level which it naturally would have been under—for example, the absence of exposure.
- [method] Controlled direct effects need only A1 and A2 and survive exposure-induced
  confounders (with MSMs or g-methods), but give no indirect effect. Precise
  counterfactual interpretation ^f18
  > Controlled direct effects cannot in general be used for effect decomposition or to assess the relevance of a particular pathway
- [method] Imai et al.'s simulation approach allows flexible mediator and outcome models
  under the same A1-A4. More flexible models ^f19
  > a simulation-based approach has been developed by Imai et al. (15), which allows investigators to specify much more flexible models for the outcome and the mediator
- [method] A four-way decomposition separates mediation from interaction: mediation only,
  interaction only, both, neither. Conclusion ^f20
  > A total effect can, in fact, be decomposed into not just two but four distinct components
- [method] [stats] (inferred) For us: win is a common outcome (50%), so the logistic
  product-of-coefficients and difference shortcuts (the "draft logit drops when gold@14
  is added" reading) are both invalid; estimate natural effects by simulation or
  g-computation on the probability (risk difference) scale instead. ^f21
- [method] (inferred) For us: player skill drives both gold@14 (mediator) and win
  (outcome) and also champion choice; matchmaking balances team MMR but not
  champion-specific skill. A2 is the weak point: adjust for player-history features
  where we have them, and report the Ding and VanderWeele table for the rest. ^f22
- [method] (inferred) For us: 14 minutes is long; events before 14 (first blood, early
  drakes, lane state at 5 or 10) are themselves exposure-induced mediator-outcome
  confounders (A4 violated) if gold@14 alone is the mediator. Treat the whole 14:00
  state as one joint mediator rather than gold alone. ^f23
- [stats] (inferred) For us: gold@14 is a noisy proxy for "early advantage" (scaling comps
  trade gold for later power), so its indirect effect is a lower bound on how much the
  draft works through being ahead early, and the direct effect is an upper bound. ^f24

## Read

- Whole review, including the reference list.

## Not read

- VanderWeele 2015 book (chapters 2-3, 5, 7.3): fuller proofs and the antidepressant
  reanalysis.
- Ding and VanderWeele 2016 (ref 8): the sharp bounds paper itself.
