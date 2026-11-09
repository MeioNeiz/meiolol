---
title: 'Keogh and Bartlett 2019: Measurement error as a missing data problem'
url: https://arxiv.org/pdf/1910.06443
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: docs (sections 1-3, 6-8)
relevance: high
grade: B/strong
description: LSHTM and Bath review casting covariate measurement error as missing data; regression calibration as mean imputation, ML, Bayes and multiple imputation with validation, replicate and calibration substudies, NHANES III example
---
# Keogh and Bartlett 2019: Measurement error as a missing data problem

Why: our stored rank is a proxy for rank at game start that depends on the outcome
(differential error), and we have both ranks for games since 13 Oct. Which correction
fits a proxy that knows the result, using that overlap as a validation set?

## Assessment

- Evidence: B. Two established measurement-error statisticians (Keogh co-leads the
  STRATOS measurement error group); a review, so its comparisons cite others' work
  (Freedman et al.) rather than new simulations; one worked example.
- Reasoning: strong. States each method's assumption, cost and software gap.
- Interests: none known; the authors also wrote the Bayes and SMC-FCS methods they
  recommend.
- Weigh: trust the assumption map (which method survives differential error); the
  NHANES numbers only show methods agree when error is non-differential.

## Findings

- [stats] [method/causal] Framing: a covariate measured with error is a true variable
  missing for some or all units; the error-prone value X* is an auxiliary variable seen
  for everyone. Abstract, Section 6 ^f1
  > Studies with variables measured with error can be considered as studies in which the true variable is missing, for either some or all study participants.
  > all individuals have the error prone value X ∗ observed. This takes the role of an auxiliary variable in the missing data context.
- [stats] Non-differential error means the error and the outcome are independent given
  the true value; our stored rank breaks this (it moved with the result). Section 2.3 ^f2
  > An assumption often made is that measurement errors are non-differential, meaning that the errors and outcome Y are conditionally independent given X and Z.
- [stats] Regression calibration (replace X by E(X | X*, Z) fitted on the validation
  subset) is the most used correction but needs non-differential error. Section 3 ^f3
  > Regression calibration therefore relies on the assumption of non-differential error.
- [stats] With a validation subset, multiple imputation draws X from p(X | X*, Z, Y):
  conditioning on the outcome is what lets it handle differential error. Sections 6.1-6.2 ^f4
  > The aim is to draw values of the true exposure X from its distribution conditional on the error prone measure X ∗ , the outcome Y , and any covariates Z.
  > MI using standard software in the validation setting can be used to impute X using a model for p(X|X ∗, Z, Y ), which allows for the measurement error to be differential.
- [stats] Reported comparison (Freedman et al.): under differential error, regression
  calibration was biased and differential MI about unbiased; under non-differential
  error they had similar efficiency. Section 7 ^f5
  > Under differential error, regression calibration gave biased estimates while their differential MI implementation delivered approximately unbiased estimates.
- [stats] Fitting only on the validation subset is unbiased but wasteful; methods using
  all units are preferred. Section 2.3 ^f6
  > unbiased estimates of the parameters in model 1 could be obtained by fitting the model within the subset of individuals with X observed (R = 1). However, this would be highly inefficient
- [stats] The ease rests on the validation subset being chosen completely at random; a
  non-random subset needs its selection modelled. Section 2.2 ^f7
  > When, as is usually the case, the selection is completely at random, the missingness process can be ignored for the purposes of inference.
  > If the subset Ri = 1 arises in a non-random fashion, attention should be paid to the missing data mechanism.
- [stats] Imputation model must be compatible with the analysis model; a conditional
  normal (or logistic) imputation is compatible with a logistic outcome model, but
  non-linear terms and interactions in X break that. Section 6.1 ^f8
  > the imputation model should be compatible with the substantive model that is used for the analysis
- [stats] NHANES III: correcting blood pressure moved its log hazard ratio from 0.085
  (naive) to 0.114 (RC), 0.114 (Bayes), 0.120 (MI), intervals wider; other covariates
  barely moved. Table 2 ^f9
  > The results from RC, the direct Bayesian analysis, and MI in which the missing data in SBP and smoking status is ignored are very similar.
- [stats] (inferred) For meiolol: games since 13 Oct are the validation set (true start
  rank X and stored rank X*); fit p(start rank | stored rank, store lag, win, seat
  features) there and impute start rank for older games, several draws. The catch is
  ^f7: the overlap is the latest weeks, not a random subset, so the leak model must
  hold across patches (check by splitting the overlap by date). ^f10

## Read

- Abstract, Sections 1-3 (setup, error types, regression calibration), 6-8 (MI,
  comparison, NHANES example).

## Not read

- Sections 4-5 (likelihood and Bayes derivations); references 24-26 (Cole, Freedman,
  Keogh-White) for simulation numbers.
