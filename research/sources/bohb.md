---
title: 'Falkner et al. 2018: BOHB, Robust and Efficient Hyperparameter Optimization at Scale'
url: https://arxiv.org/pdf/1807.01774
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, sections 1-4.1, 5.1-5.2.2, 6, appendix H)
relevance: high
grade: A/fair
description: ICML 2018 method combining Hyperband's successive halving over budgets with a TPE model that picks which configurations to start; budgets can be data subset sizes
---
# Falkner et al. 2018: BOHB, Robust and Efficient Hyperparameter Optimization at Scale

Why: how to split a run budget between many cheap low-fidelity runs and few full ones,
and when a model should pick candidates instead of random sampling.

## Assessment

- Evidence: A. ICML 2018 (Freiburg AutoML group, Hutter); widely used open-source
  implementation (HpBandSter), later the default in several HPO libraries; benchmarks
  on toy functions, SVM, neural nets, Bayesian NNs, RL, CNNs, 50 independent runs on
  several.
- Reasoning: fair. States desiderata, keeps a random fraction for worst-case
  guarantees, reports where it loses (64 dimensions, noisy low budgets).
- Interests: authors' own method vs their own baseline runs.
- Weigh: trust the anytime vs final-performance pattern; numeric hyperparameter spaces
  only, nothing about choosing code or model structure.

## Findings

- [lab] [method] Pattern: Hyperband is fast early but near random search at large
  budgets; BO starts slow but wins given time; BOHB aims to get both. Figure 1 ^f1
  > Hyperband has strong anytime performance, but for larger budgets does not perform much better than random search. In contrast, Bayesian optimization starts slowly (like random search), but given enough time outperforms Hyperband.
- [lab] Practical budgets are often only a handful of full trainings, so methods must
  give good answers before many full runs. Section 1 ^f2
  > The overall budget that most researchers and practitioners can afford during development is often not much larger than that of fully training a handful of models
- [lab] Successive halving: run configurations on a small budget, keep the best third,
  give them η times more budget, repeat to the full budget. Section 3.2 ^f3
  > SH internally evaluates configurations on a given budget, ranks them by their performance, and continues the top η −1 (usually the best-performing third) on a budget η times larger.
- [lab] Hyperband hedges by running several brackets, from very aggressive (many
  configs, smallest budget) to conservative (straight to full budget). Section 3.2 ^f4
  > It balances very agressive evaluations with many configurations on the smallest budget, and very conservative runs that are directly evaluated on bmax .
- [lab] BOHB: a model picks which configurations start each bracket; the model is
  fitted on the largest budget with enough results, so wrong low-budget conclusions get
  overruled by high-fidelity results. Section 4.1 ^f5
  > BOHB always uses the model for the largest budget for which enough observations are available (line 2). This enables it to overcome wrong conclusions drawn on smaller budgets by eventually relying on results with the highest fidelity only.
- [lab] A constant fraction of configurations is still sampled at random, which bounds
  the worst case when low fidelities mislead. Section 4.1 ^f6
  > This means, that in the worst case (when the lower fidelities are misleading), BOHB is at most this factor times slower than RS, but it is still guaranteed to converge eventually.
- [lab] Data subset size works as the budget: SVM benchmark from 1/512 of the training
  data to all of it. Section 5.2.1 ^f7
  > The budget is given by the number of training datapoints, where the minimum budget is 1/512 of the training data and the maximum budget is the full training data.
- [lab] [stats] Where low budgets are too noisy to predict the full budget, cheap
  evaluations just add overhead and plain BO wins (64-dimension case). Section 5.1,
  appendix H ^f8
  > with as many as 64 dimensions, TPE and SMAC started to perform better than BOHB since the noise grows and evaluating configurations on a smaller budget does not help to build better models for the full budget.
  > given a large enough budget, BOHB's evaluations on small budgets lead to a constant overhead over only using the more reliable evaluations on larger budgets.
- [lab] Budgets are set by the user and misspecification is a known weakness the
  authors want to automate away. Section 6 ^f9
  > we will consider an automatic adaptation of the budgets used to alleviate the problem of misspecification by the user
- [lab] (inferred) For meiolol: data subsets are a valid cheap fidelity only if small
  subsets rank candidates the same way as full data; with effects near the noise
  level, small subsets may not, so check rank agreement before trusting them. ^f10

## Read

- Abstract, sections 1-4.1, 5.1, 5.2.1-5.2.2, 6; appendix H point 2

## Not read

- Section 4.2 parallelisation, 5.3-5.6 (Bayesian NN, RL, CNN), appendix KDE details
