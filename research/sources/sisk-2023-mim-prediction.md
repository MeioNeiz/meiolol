---
title: 'Sisk et al. 2023: Imputation and missing indicators for clinical prediction models'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC10515473/
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: skimmed (abstract, methods 2.2-2.6, results 3.1, discussion, Table 2)
relevance: high
grade: B/fair
description: Sisk, Sperrin, Peek, van Smeden, Martin (Stat Methods Med Res 2023); simulation plus MIMIC-III comparing regression vs multiple imputation, with or without the outcome, with or without missing indicators, by whether missingness is allowed at deployment
---
# Sisk et al. 2023: Imputation and missing indicators for clinical prediction models

Why: our mastery feature is missing for some seats in most games, both in training and at
prediction time; what does the prediction (not inference) literature recommend?

## Assessment

- Evidence: B. Manchester clinical prediction group (Sperrin, van Smeden, Martin), peer
  reviewed; simulation n=10,000 per set (500 to 10,000 varied) and a MIMIC-III example.
- Reasoning: fair. Clear on the deployment distinction; but one logistic model with 2
  predictors in the simulation, and the gains reported mostly from figures, few numbers in
  text.
- Interests: none known.
- Weigh: trust the direction (indicator helps under informative missingness when missing
  at deployment, harmless under MCAR/MAR); the size is "marginal" in their settings. They
  assume the missingness mechanism stays constant, which ours does not (mastery coverage
  rises over time and differs by region).

## Findings

- [method] [stats] In prediction, the question is whether missingness is allowed at
  deployment; that, not unbiased coefficients, decides the handling. Section 1 ^f1
  > in prediction research we must distinguish between handling missing data across the entire model pipeline; model development, model validation, and model deployment
- [method] Recommendation: with missingness at deployment and informative missingness
  (MNAR on X or on Y), add a missing indicator; it does not hurt under MCAR or MAR. Table 2 ^f2
  > Where data are assumed to be MNAR-X or MNAR-Y and missingness is allowed at deployment, the inclusion of a missing indicator can offer marginal improvements in model performance, and does not harm performance under MCAR or MAR mechanisms
- [method] Under MNAR with missingness at deployment the indicator lowered the Brier score
  and raised the C-statistic considerably (MNAR-Y). Section 3.1.3.1 ^f3
  > Under MNAR mechanisms and missingness allowed at deployment, the inclusion of a missing indicator in the outcome model provides reductions in the Brier Score, and considerable improvements in the C-statistic
- [method] Regression imputation must leave the outcome out of the imputation model; with
  it in, predictions collapse towards 0 and 1. Discussion ^f4
  > RI consistently showed extremely poor performance when the observed outcome was included in the imputation model
- [method] The imputation model must be the same at development and deployment; an
  unbiased-coefficient model is not the one that predicts best. Discussion ^f5
  > a model with unbiased model parameters is not necessarily the one that predicts best, especially when missing data will be imputed at deployment.
- [method] Regression imputation (deterministic) predicted about as well as multiple
  imputation when each used its preferred imputation model. Discussion ^f6
  > Estimates of predictive performance were practically indistinguishable between RI and MI when the preferred imputation model was applied in both simulated and real data settings.
- [stats] Assumption we break: missingness mechanism and proportion constant between
  development and deployment, which they call strong. Section 2.5 ^f7
  > we assume that the missingness mechanism, the missing data strategy, and the proportion of missing data remain constant between model development and validation, which is perhaps a strong assumption in practice.
- [method] On MIMIC-III, the indicator improved discrimination, calibration and overall
  accuracy under the preferred strategy. Discussion ^f8
  > In our real data example, the inclusion of a missing indicator offered improvements in model discrimination, calibration and overall accuracy under the preferred strategy
- [method] (inferred) For us: mastery is missing at prediction time too (the app can't
  always see it), so impute from observed covariates (rank, champion games) without the
  result, add a per-seat missing indicator, and keep the same imputer at train and serve. ^f9

## Read

- Abstract, sections 1-2 (design, strategies), 3.1 (simulation results text), discussion
  and Table 2.

## Not read

- Supplemental appendices (C-statistics, sample-size plots, predicted-risk histograms).
