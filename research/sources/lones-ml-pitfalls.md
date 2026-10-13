---
title: How to avoid machine learning pitfalls: a guide for academic researchers (Lones)
url: https://arxiv.org/abs/2108.02497
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: skimmed (contents, 2.3, 2.4, 3.1, 3.6, 3.8, 4.3, 4.4, 4.8, 5.2-5.4, 6.1, 6.5, 6.6)
relevance: high
grade: A/fair
description: Heriot-Watt guide of ML dos and don'ts (v5, 2024; published in Patterns), updated yearly: data, leakage, sequential overfitting, multiple evaluations, baselines, statistical tests, reporting
---
# How to avoid machine learning pitfalls (Lones, arXiv v5 2024)

Why: a practitioner checklist of habits, to see which an agent-run lab lacks.

## Assessment

- Evidence: A as a consensus reference: widely cited, revised yearly since 2021 from
  reader feedback, published in Patterns 2024. No new measurements; cites others.
- Reasoning: fair. Each item says why it matters; little on how much each pitfall
  costs or how often it happens.
- Interests: none known; recommends REFORMS, which the author co-wrote.
- Weigh: aimed at newcomers and publication; items overlap Kapoor and Cawley-Talbot.
  Useful as the list of habits, not as evidence of size.

## Findings

- [lab] Do not look closely at test data during exploration: untestable assumptions
  from it leak into the model. 2.3 ^f1
  > you should avoid looking closely at any test data in the initial exploratory analysis stage.
- [lab] Find and remove duplicates before building models; they corrupt evaluation. 2.4 ^f2
  > One common problem to look out for is data duplication, i.e. the unintentional inclusion of multiple copies of a data point.
- [lab] Scaling and imputation statistics (means, ranges) must come from training data
  only; leakage routes include feature selection before the split, reusing one test
  set across models, augmentation before the split. 3.1 ^f3
  > using information about the means and ranges of variables within the whole data set to carry out variable scaling or imputation — in order to prevent information leakage, these statistics should be calculated using only the training data.
- [lab] Partition the test set at the start and use it once, on a single final model. 3.1 ^f4
  > partition off a subset of your data right at the start of your project, and only use this independent test set once to measure the generality of a single model at the end of the project
- [lab] Feature selection and dimensionality reduction are part of training: fit them
  on training folds only, and redo them inside each CV fold. 3.6 ^f5
  > it’s important to carry out feature selection or dimensionality reduction independently within each iteration, each time using just the training folds
- [lab] Check what a model responds to: spurious correlations look good on metrics but
  fail in practice. 3.8 ^f6
  > it is always worth looking at your trained model to see whether it’s responding to appropriate features within your data
- [lab] "Sequential overfitting": tuning successive models on one test set leaks it into
  training, and it is rarely documented because informal; overfitting grows with
  each use. 4.3 ^f7
  > Often this is done as an informal process, trying out different models and different hyperparameters until you get good performance on the test set. As such, it is rarely documented, which is one reason why it’s so pernicious.
  > the more times you use the test set, the more the overfitting that occurs.
- [lab] [stats] Evaluate stochastic models several times: different seeds at least,
  better also varied data (CV); keep a subject's rows in one fold; report spread
  (SD or 95% CI). 4.4 ^f8
  > For stochastic models, the simplest is to train the same model multiple times using different random seeds and then look at the average performance. A more robust approach is to also vary the
  > in medical datasets, it is commonplace to have multiple data points for a single subject; to avoid data leakage, these should be kept together within the same fold.
- [lab] Time series: look-ahead bias when training data postdate test data, including
  through data-dependent preprocessing before the split. 4.8 ^f9
  > Look ahead bias can also result from carrying out datadependent preprocessing operations before splitting off the test data
- [lab] Baselines: the model being extended, simpler models, and naive "dummy"
  baselines (majority class, last value) to show the model is not doing something
  trivial; a transformer lost to a last-value baseline. 5.2 ^f10
  > The simplest baselines are known as naı̈ve baselines and are used to show that your model is not doing something trivial.
- [lab] [stats] Comparing two model instances by per-sample outputs (McNemar) needs
  the per-sample predictions recorded. 5.3 ^f11
  > works by comparing the classifiers’ output labels for each sample in the test set (so do remember to record these).
- [stats] Many pairwise tests multiply false positives (20 tests at 95%: one likely
  wrong); correct, e.g. Bonferroni. 5.4 ^f12
  > if you do 20 pairwise tests with a confidence level of 95%, one of them is likely to give you the wrong answer.
- [lab] Share the experiment scripts; experiment tracking (MLflow) records the
  workflow; use a checklist such as REFORMS, most useful at planning time. 6.1, 6.6 ^f13
  > if you used a script to implement all your experiments, then share the script when you
  > checklists are arguably most useful at the start of a study when it comes to planning an ML pipeline.
- [lab] Ablations (remove parts, see what matters) for models too complex to inspect. 6.5 ^f14
  > This involves successively removing parts of the model to see what is important
- [lab] Checked, not there: no concrete per-run sanity checks (init loss, label
  shuffle), no number of seeds to run. ^f15
- [lab] (inferred) Our time split, ladder and paired intervals cover 3.1, 4.3, 4.8 and
  5.3. Gaps: duplicate-game check across split boundaries, train-only fit of every
  normalisation or prior (champion priors, smoothing), same-player games across the
  split (Kapoor L3.2), and a naive baseline row on every result. ^f16

## Read

- Contents and changes; sections listed in depth

## Not read

- 2.5-2.8, 3.2-3.5, 3.7 (hyperparameters), 4.1, 4.2, 4.5-4.7, 5.1, 5.5, 5.6, 6.2-6.4
