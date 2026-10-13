---
title: 'VanderWeele and Vansteelandt 2010: Odds ratios for mediation analysis for a dichotomous outcome (AJE)'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC2998205/
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: docs (whole paper and appendix; tables 1-2 skimmed)
relevance: high
grade: A/strong
description: AJE 2010 paper defining natural direct and indirect effects on the odds ratio scale for a binary outcome, with closed forms from a logistic outcome and linear mediator model, valid only for a rare outcome; simulations on prevalence and ignored interaction
---
# VanderWeele and Vansteelandt 2010: Odds ratios for mediation analysis for a dichotomous outcome (AJE)

Why: the source of the logistic-plus-linear mediation formulas and the statement of when
product-of-coefficients and difference methods agree for a binary outcome.

## Assessment

- Evidence: A. AJE with two invited commentaries; the formulas are what the SAS, SPSS
  and Stata mediation macros implement; widely cited.
- Reasoning: strong. Derives the rare-outcome approximation, simulates its failure and the
  cost of ignoring interaction, names its own limits (rare outcome, normal mediator).
- Interests: academic.
- Weigh: trust the warnings; do not use its closed forms for win (50% prevalence).

## Findings

- [method] [stats] On the odds ratio scale the total effect is the product of the natural
  direct and indirect effect odds ratios, so log ORs add; NIE log OR over TE log OR is a
  proportion mediated on the log odds scale. Direct and indirect effects odds ratios ^f1
  > On the odds ratio scale, the odds ratio for the total effect decomposes into a product of odds ratios for the natural direct and indirect effect
- [stats] Mediator-outcome confounding is often neglected because studies collect only
  exposure-outcome confounders. Direct and indirect effects odds ratios ^f2
  > Effort is often made to collect data on some set of covariates C that suffice to control for confounding of the exposure-outcome relation so that assumption 1 is satisfied, but this will not ensure that assumption 2 is satisfied.
- [method] The no-exposure-induced-confounder assumption may hold if the mediator comes
  shortly after the exposure. Direct and indirect effects odds ratios ^f3
  > In some settings, assumption 4 may be plausible if the mediator M occurs shortly after the exposure A
- [stats] Product and difference methods coincide only under a rare outcome, a normal
  homoscedastic mediator error, A1-A4, and no interaction. Appendix ^f4
  > If, however, the outcome is not rare or if the error term in regression model 6 is heteroscedastic or not normally distributed, then the 2 quantities β 1 θ 2 and ϕ 1 −θ 1 need not be approximately equal.
  > Furthermore, in that case, neither β 1 θ 2 nor ϕ 1 −θ 1 may warrant an interpretation as an indirect effect.
- [stats] Ignoring an exposure-mediator interaction can make the exposure coefficient
  average to near zero and look fully mediated. Regression analysis ^f5
  > This might result in a researcher's concluding that the effect of A on Y is largely mediated by M, when in fact all that is the case is that there is an interaction between the effects of A and M on Y .
- [method] Test the A x M product term first; if non-zero, do not use the
  include-the-mediator approach. Regression analysis ^f6
  > If there is evidence that θ 3 ≠ 0, then this standard approach of merely including the mediator in a regression for the outcome Y to obtain direct and indirect effects should not be used.
- [stats] The controlled direct effect odds ratio from a logistic model with interaction
  needs no rare outcome assumption; the natural indirect effect formula does. Regression
  analysis ^f7
  > The formula for the controlled direct effect odds ratio requires that assumptions 1 and 2 hold and that model 7 is correctly specified; no rare outcome assumption is required.
- [stats] Simulations: with small indirect effects the formulas held up even at common
  prevalence, but with indirect effects 5 times larger the rare outcome failure biased
  them (NIE coverage 79.1% at prevalence 0.5 in Table 1); ignoring a present interaction
  also biased them. Illustration and simulations ^f8
  > In the final 4 experiments β 1 and σ were increased 5 times (Ψ = 5 in Table 1 ) to give indirect effects of a larger magnitude; here, violations of the rare-outcome assumption do lead to bias.
  > As theoretically expected, ignoring exposure-mediator interactions when they are present can generate a substantial bias in the indirect effect estimates.
- [method] [stats] The two most common pitfalls: ignoring mediator-outcome confounding and
  ignoring exposure-mediator interaction; both can severely bias results. Discussion ^f9
  > The 2 most common pitfalls with mediation analysis in the epidemiologic literature are 1) ignoring possible mediator-outcome confounding and 2) ignoring possible interactions between the effects of exposure and mediator on the outcome.
- [stats] The identifying no-confounding assumptions cannot be checked in data; use
  subject knowledge and sensitivity analysis. Discussion ^f10
  > the no-unmeasured-confounding assumptions used for the identification of direct and indirect effects cannot be verified with data
- [method] [stats] (inferred) For us: the draft-gold interaction is likely real (a lead
  matters less to a scaling comp, more to a snowball comp), so fit draft x gold@14 (and
  draft x full state) terms in the outcome model and report the four-way or interaction-
  aware decomposition, not a single "% mediated". ^f11
- [stats] (inferred) For us: our indirect effect is large (draft moves gold@14 by hundreds,
  and gold@14 is a strong win predictor), the regime where these authors' own
  simulations show the rare-outcome formulas break; avoid the closed forms entirely. ^f12

## Read

- Whole text and appendix; Tables 1-2 read for the prevalence and interaction rows.

## Not read

- Web Appendix (pure natural direct effect formulas, NDE with interaction).
- Invited commentaries (Kaufman 2010 on collapsibility; Pushing the mediation envelope).
