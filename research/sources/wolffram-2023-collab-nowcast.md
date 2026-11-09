---
title: 'Wolffram et al. 2023: Collaborative nowcasting of COVID-19 hospitalization incidences in Germany'
url: https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011394
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, results 3.3-3.6)
relevance: medium
grade: A/strong
description: PLOS Comp Bio 2023 preregistered real-time comparison of eight nowcasting methods (incl. RKI, LMU, epinowcast, KIT) and two ensembles on German hospitalisations, scored by WIS and interval coverage per horizon
---
# Wolffram et al. 2023: Collaborative nowcasting of COVID-19 hospitalization incidences in Germany

Why: which nowcasting choices matter when the latest periods are incomplete, measured
head to head rather than by one method's authors?

## Assessment

- Evidence: A. Preregistered (OSF, 23 Nov 2021), eight independent teams, daily nowcasts
  for 159 days at national, 16 state and 7 age levels, public hub and data on Zenodo.
- Reasoning: strong. Reports where every model failed (overwhelmed hospitals, Easter,
  Omicron), reruns with changed settings, and a sensitivity to the "final" data date.
- Interests: the organisers also ran the KIT model; scores are pooled and public.
- Weigh: counts again, not rates; the lessons on maximum delay, past-error intervals
  and covariate regression carry over, the WIS numbers do not.

## Findings

- [stats] Eight methods removed most of the delay bias, but most underweighted very long
  delays (slight downward bias) and almost all intervals were too narrow. Abstract ^f1
  > Most participating teams underestimated the importance of very long delays, though, resulting in nowcasts with a slight downward bias. The accompanying prediction intervals were also too narrow for almost all methods.
- [stats/scoring] Pooled over horizons, most models cut the uncorrected series' error by
  about 80% (relative WIS 0.2); ILM, which regressed on case counts and allowed 80-day
  delays, by about 90% (0.1). Section 3.3 ^f2
  > most models were able to reduce the error of the uncorrected time series (FrozenBaseline) by roughly 80% (relative WIS of 0.2), while the ILM model achieved a reduction of about 90% (relative WIS 0.1)
- [stats/scoring] For the latest days the quantile mean of all models was best, closely
  followed by ILM. Section 3.3 ^f3
  > For this subset of nowcasting tasks, the MeanEnsemble outperformed the individual models in all three categories, closely followed by ILM.
- [stats] Late additions are harder than early ones: models did worse on the small
  number of late arrivals than on the bulk, likely because a 40-day cap ignored a
  non-negligible tail. Section 3.4 ^f4
  > most models seemed to have more difficulties predicting the small number of late additions than the bulk of early additions, leading to higher relative WIS
- [stats/scoring] Intervals built from the errors of past real-time nowcasts (close to
  conformal prediction) gave the best calibration; model-based intervals were
  overconfident. Section 3.4 ^f5
  > the ILM approach based uncertainty intervals directly on the errors of past real-time nowcasts, an approach close to the idea of conformal prediction
  > this approach may quantify nowcast uncertainty more realistically than standard model-based uncertainty intervals
- [stats] Models without weekday effects under-predicted on Mondays and over-predicted on
  Fridays or Saturdays. Section 3.3 ^f6
  > with a tendency for underprediction on Mondays and many cases of overprediction on Fridays or Saturdays
- [stats] Every model assumed one thing constant (the delay distribution, or ILM's
  hospitalisations per case); each broke when its assumption did (overwhelmed hospitals,
  Easter, Omicron's lower severity). Section 3.5 ^f7
  > The nowcasting models in our study assumed either that the probability of hospitalization given a positive test remains roughly constant (the ILM model) or that the delay distribution in hospitalizations does so (all other models).
- [stats] Rerunning KIT with an 80-day rather than 40-day maximum delay brought it close
  to ILM across age groups. Section 3.6 ^f8
  > In particular across age groups, the KIT model now came close to the performance the ILM model achieved in real time.
- [stats] (inferred) For meiolol: cap store lag at the true tail (days, not hours),
  score fresh-day estimates against the same days once filled, and set their ranges
  from past fresh-vs-filled errors (as our thin-cell spread per band does), not from a
  model's own sd. A regression on an early-complete signal (ILM's case counts) has an
  analogue in rank-at-start games since 13 Oct. ^f9

## Read

- Abstract, Sections 3.3 to 3.6.

## Not read

- Section 2.3 model table and S1 Appendix (each method's delay model; Günther's LMU).
- Section 4 Discussion, Section 3.7 (final-data definition).
