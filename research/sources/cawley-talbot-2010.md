---
title: On Over-fitting in Model Selection and Subsequent Selection Bias in Performance Evaluation (Cawley, Talbot, JMLR 2010)
url: https://www.jmlr.org/papers/volume11/cawley10a/cawley10a.pdf
kind: paper
commit: 
for: [llm-experiment-agent]
looked: 2026-10-12
depth: skimmed (abstract, section 1, 4 intro, 4.4, 6)
relevance: medium
grade: A/strong
description: JMLR paper showing that tuning against a finite validation criterion overfits it, by as much as the gaps between algorithms; remedies and nested evaluation
---
# On Over-fitting in Model Selection (Cawley, Talbot, JMLR 2010)

Why: practical evidence on what happens when many model variants are selected on one
noisy validation estimate, as an experiment agent would do.

## Assessment

- Evidence: A. JMLR, widely cited standard reference on model-selection overfitting;
  synthetic demo over 1000 realisations plus a benchmark suite.
- Reasoning: strong. Bias/variance analysis of the selection criterion, remedies drawn
  from known methods, says none of the methods are new.
- Interests: none known; authors cite their own regularisation work as one remedy.
- Weigh: kernel methods with continuous hyperparameters, not agent search over code
  variants, but the mechanism (optimising a noisy criterion) is identical.

## Findings

- [stats] [lab] Overfitting the model selection criterion can cost as much as the
  difference between learning algorithms, so it cannot be ignored when comparing. Abstract ^f1
  > we show that the effects of this form of over-fitting are often of comparable magnitude to differences in performance between learning algorithms, and thus cannot be ignored in empirical evaluation.
- [stats] [lab] Low variance in the selection criterion matters at least as much as
  unbiasedness: variance is what lets selection overfit. Abstract ^f2
  > While unbiasedness is often cited as a beneficial quality of a model selection criterion, we demonstrate that a low variance is at least as important
- [stats] [lab] Demo (1000 realisations, 64 samples, four-fold CV): the CV estimate keeps
  falling while true test error rises again after about 30-40 iterations of tuning,
  the classic overfitting curve one level up. Section 4 ^f3
  > after a relatively short time (approximately 30–40 iterations), the test error begins to climb slowly once more as the hyper-parameters are tuned in ways that exploit the meaningless statistical peculiarities of the sample.
- [stats] [lab] It is worst with small data and many tuned choices; remedies are the
  same as for training overfitting: regularisation, early stopping, averaging, fewer
  hyperparameters, or for very small data integrate them out (Bayesian). Section 4.4 ^f4
  > over-fitting in model selection is likely to be most severe when the sample of data is small and the number of hyper-parameters to be tuned is relatively large.
  > namely regularisation (Cawley and Talbot, 2007), early stopping (Qi et al., 2004) and model or hyper-parameter averaging
- [stats] [lab] Reported performance is optimistically biased unless model selection is
  redone inside each evaluation trial (nested cross-validation). Section 1, 6 ^f5
  > In order to avoid this bias, model selection must be treated as an integral part of the model fitting process and performed afresh every time a model is fitted to a new sample of data.
  > such a nested cross-validation or “double cross” (Stone, 1974).
- [stats] [lab] Rigorous evaluation uses multiple randomised partitionings with
  selection repeated in each, which is easy to automate and parallelise. Section 6 ^f6
  > Rigorous performance evaluation therefore requires a substantial investment of processor time in order to evaluate performance over a wide range of data sets, using multiple randomised partitionings of the available data, with model selection performed separately in each trial.
- [lab] (inferred) For meiolol: an agent's search procedure is itself the "model
  selection" to be evaluated; report the winner's score on data the search never
  touched, and cap or early-stop the search on a noisy criterion. ^f7

## Read

- Abstract, section 1, section 4 opening demo and 4.4, section 6 conclusions

## Not read

- Section 4.1-4.3 bias/variance figures, section 5 benchmark-suite bias numbers
