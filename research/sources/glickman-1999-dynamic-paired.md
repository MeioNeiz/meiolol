---
title: 'Glickman 1999: Parameter estimation in large dynamic paired comparison experiments (Glicko)'
url: http://www.glicko.net/research/glicko.pdf
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: skimmed (summary, 2 model, 3 algorithm text, 4 parameter fitting, tennis, 6)
relevance: medium
grade: A/fair
description: Applied Statistics 48(3) 1999; the Glicko paper: dynamic Bradley-Terry state space where a rating's variance grows by a fixed amount per unit time, fitted by minimising one-step-ahead log loss; chess and tennis examples
---
# Glickman 1999: Parameter estimation in large dynamic paired comparison experiments

Why: the canonical rating system that raises uncertainty between observations; does it
raise it at known events, and how are the variance knobs fitted?

## Assessment

- Evidence: A. Basis of Glicko, used by many online game and chess ratings; peer reviewed.
- Reasoning: fair. Clear model and fitting criterion; admits what the approximation drops
  (correlations between players).
- Interests: none.
- Weigh: variance grows with elapsed time only; known events are named as possible but
  not used. Its fitting method (minimise forward log loss over the variance knobs) is the
  part we can copy.

## Findings

- [method/dynamics] Strength follows a random walk whose variance grows by a constant per
  unit time, so a player's strength gets more uncertain while not observed. Section 2 ^f1
  > This model asserts that, as time passes while a player is not competing, the description of a competitor's strength becomes more uncertain.
- [method/dynamics] Known events between observations could set the variance step, but
  the paper assumes no such information. Section 2 ^f2
  > Knowledge of a player's activities (e.g. preparation) between events could be incorporated in model (2), but we assume that such information is not generally available.
- [method/dynamics] Elapsed time t adds c^2 t to the variance, keeping variance additive in
  time; c^2 is fitted. Section 3 ^f3
  > an elapse of t units in time corresponds to an increase in  2 t in the variance.
- [method/dynamics] The effective K factor grows with prior variance, so an uncertain
  rating moves a lot on new results; Elo is the special case with fixed variance.
  Section 3.3 ^f4
  > When one's prior strength is uncertain, the outcomes of games have a potentially substantial eect on one's strength distribution update
- [stats/scoring] The initial and per-period variances are chosen by minimising the
  predictive discrepancy: the binomial log loss of each game given only earlier periods.
  Section 4 ^f5
  > the predictive discrepancy dij in equation (15) is the binomial log-likelihood for a game eval
- [method/dynamics] Fitted variance growth differs by domain: much smaller per year for
  chess than tennis (fitness and injuries). Section 5 ^f6
  > The variance increase per year was much smaller for the chess player data than for the tennis data, suggesting more stability in chess playing strength than in tennis.
- [method/dynamics] (inferred) For us: a patch is an "activity between events" known in
  advance; Glicko's form becomes variance step = base + k * change exposure at the
  boundary, with base and k fitted by forward log loss exactly as Glickman fits c^2. ^f7

## Read

- Summary, Sections 2-4 text, tennis results, conclusion.

## Not read

- Simulation study, chess all-time rankings, Appendix A derivations.
