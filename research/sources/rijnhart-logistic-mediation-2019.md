---
title: 'Rijnhart et al. 2019: Comparison of logistic-regression based methods for simple mediation analysis with a dichotomous outcome (BMC Med Res Methodol)'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC6341620/
kind: paper
commit:
for: [draft-mediation]
looked: 2026-10-13
depth: docs (whole paper; tables not read cell by cell)
relevance: high
grade: B/fair
description: Simulation comparing difference (c - c'), product (ab), standardised and potential-outcomes estimates of the indirect effect and proportion mediated with a binary outcome at 10, 30 and 50% prevalence; explains why c - c' underestimates
---
# Rijnhart et al. 2019: Comparison of logistic-regression based methods for simple mediation analysis with a dichotomous outcome (BMC Med Res Methodol)

Why: the direct simulation comparison of product vs difference with a logistic outcome,
including 50% prevalence (our case), and the plain explanation of the change of scale.

## Assessment

- Evidence: B. Peer-reviewed methods paper, open access; simulation only (500 samples of
  1,000, one effect size 0.6 per path, no confounders) plus one 360-person example.
- Reasoning: fair. Clear on the mechanism (fixed logistic error variance 3.29), but
  "true" proportion mediated is defined on the log odds scale, so it judges methods
  against a scale-dependent target and does not test interaction or confounding.
- Interests: academic.
- Weigh: trust "c - c' underestimates and is non-zero even with no mediation"; treat its
  endorsement of ab/(ab + c') as log-odds-scale only, not a probability-scale share.

## Findings

- [method] [stats] Three ways to compute a proportion mediated (ab/(ab + c'), ab/c,
  1 - c'/c) agree for continuous outcomes but not with logistic regression.
  Background ^f1
  > However, previous simulation studies showed that the different estimates of the indirect effect and proportion mediated will no longer coincide when the outcome is dichotomous and logistic regression analysis is used
- [stats] Cause: logistic error variance is fixed (3.29), so adding a variable that
  explains the outcome inflates every coefficient's scale. Discussion ^f2
  > However, in a logistic regression model a standard logistic distribution is assumed, in which the unexplained variance is fixed at 3.29
- [stats] So c - c' systematically underestimates a positive indirect effect, more so the
  stronger the mediator-outcome link and the larger the sample. Discussion ^f3
  > Consequently, the c - c’ estimate will be a systematic underestimation of the true (positive) indirect effect.
  > the magnitude of this underestimation depends on both the strength of the relationship between the mediator and outcome, and on the sample size
- [stats] Even with no mediation at all, c - c' is likely non-zero. Discussion ^f4
  > even when the true mediated effect equals zero, the indirect effect based on c-c’ will likely be nonzero and thus a misleading estimate of the true indirect effect.
- [stats] In simulation (outcome prevalence 0.10, 0.30, 0.50), the potential outcomes
  estimates and crude ab and ab/(ab + c') had the lowest bias and highest efficiency;
  c - c', ab/c and 1 - c'/c did worse at every prevalence. Results, Discussion ^f5
  > For both models with a continuous or a dichotomous mediator and across all prevalence rates of the mediator and outcome, the crude indirect effect estimate c - c’ and the crude estimates of the proportion mediated ab / c and 1-( c’ / c ) performed worse than the crude ab and ab /( ab  +  c’ ) estimates.
- [stats] Standardising logistic coefficients (y-standardisation, full, standardised
  logistic solution) mostly did not help. Abstract ^f6
  > Standardization of the coefficients prior to estimating the indirect effect and the proportion mediated may not increase the performance of these estimates.
- [stats] With a binary mediator, potential outcomes and ab disagreed in real data: 7%
  vs 25% mediated for the same question. Results ^f7
  > This indirect effect explained 7% of the total effect of sum of four skinfolds on CD.
  > This indirect effect explained 25% of the total effect of sum of four skinfolds on CD.
- [stats] Odds ratios from the potential outcomes method do not approximate risk ratios
  at 10-50% prevalence. Discussion ^f8
  > it is important to note that the odds ratios from the potential outcomes framework won’t approximate risk ratios for high prevalence rates, i.e. 10% to 50%
- [method] Proposed escape from logistic scale problems: linear probability models,
  average marginal effects or log-linear models. Discussion ^f9
  > the use of alternative models has been proposed, such as linear probability models, average marginal effects models, and log-linear models
- [stats] Checked, not there: no confounders, no exposure-mediator interaction, a single
  effect size per path. Methods ^f10
  > For the sake of simplicity, we did not include confounders in the simulated models.
- [stats] (inferred) For us: a binary early-state mediator (first tower, first drake,
  "ahead at 14") is the case where the two families disagree most (7% vs 25%); use the
  continuous gold diff or the full state, and compute effects on the win probability
  scale by simulation rather than from coefficients. ^f11
- [stats] (inferred) For us: comparing the draft logit's coefficient with and without
  gold@14 in a logistic win model (c - c') will understate mediation, and with 230k games
  the bias is not swamped by noise. ^f12

## Read

- Whole text; tables 2-4 summarised from the prose.

## Not read

- Tables 2-4 cell values.
- Rijnhart et al. 2021 scoping review (lead) and the 2023 binary mediator follow-up.
