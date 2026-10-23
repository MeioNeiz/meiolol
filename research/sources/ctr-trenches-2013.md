---
title: 'Ad Click Prediction: a View from the Trenches'
url: https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/41159.pdf
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: docs (sections 3, 4.1, 5)
relevance: high
grade: A/strong
description: McMahan et al. (Google, KDD 2013); lessons from Google's online-trained sparse logistic CTR model (FTRL-Proximal), including per-coordinate learning rates, probabilistic admission of new features, and progressive validation (score each event before training on it) as the main evaluation
---
# Ad Click Prediction: a View from the Trenches

Why: the canonical production description of prequential evaluation ("progressive
validation") for a model trained on a stream, and of per-id learning rates for ids
seen often vs rarely.

## Assessment

- Evidence: A. Google's deployed ads model, billions of predictions a day; the paper is
  a standard reference (FTRL-Proximal, progressive validation, feature admission).
- Reasoning: strong. Explains why each choice, reports what failed, gives the
  statistical reason for its evaluation choice.
- Interests: none beyond describing own system.
- Weigh: the model is a sparse logistic regression, not a deep net; the evaluation and
  learning-rate lessons transfer, the memory tricks don't matter to us.

## Findings

- [method/dynamics] Evaluation is progressive validation (online loss), not
  cross-validation or a held-out set. 5.1 ^f1
  > We generally use progressive validation (sometimes called online loss) [5] rather than cross-validation or evaluation on a held out dataset.
- [method/dynamics] Why: it scores only the newest data before training on it, as in
  serving, and it uses all data for both training and testing, giving much tighter
  statistics than a held-out set. 5.1 ^f2
  > it measures the performance only on the most recent data before we train on it
  > The online loss also has considerably better statistics than a held-out validation set, because we can use 100% of our data for both training and testing.
- [method/dynamics] Metrics are read as relative change against a baseline model on
  exactly the same data; absolute losses from different time ranges are not compared.
  5.1 ^f3
  > We therefore always look at relative changes, usually expressed as a percent change in the metric relative to a baseline model.
  > loss metrics computed on a model over one time range are not comparable to the same loss metrics computed on another model over a different time range.
- [method/dynamics] Metrics are also broken down by slices (country, query topic,
  layout), because a small aggregate win can hide mixed effects per slice. 5.1, 5.2 ^f4
  > a small aggregate accuracy win on one metric may in fact be caused by a mix of positive and negative changes in distinct countries, or for particular query topics.
- [method/dynamics] Per-coordinate learning rates: each feature's rate shrinks with its
  own accumulated gradients, so rarely seen ids keep reacting fast; this cut AucLoss
  11.2% vs a global rate (1% counts as large). 3.1 ^f5
  > the learning rate will stay high for coin j, since we have less confidence in our current estimate, and so need to react more quickly to new data.
  > The results showed that using a per-coordinate learning rates reduced AucLoss by 11.2% compared to the global-learning-rate baseline.
- [method/dynamics] Learning-rate hyperparameters are themselves tuned under
  progressive validation. 3.1 ^f6
  > we use a learning rate where α and β are chosen to yield good performance under progressive validation
- [method/dynamics] New features are admitted online only after they recur (Bloom
  filter, n occurrences, or Poisson with probability p); RAM saved 40-66% at
  0.003-0.02% AucLoss. 4.1, Table 2 ^f7
  > Once a feature has occurred more than n times (according to the filter), we add it to the model and use it for training in subsequent observations as above.
- [method/dynamics] Checked, not there: no mechanism to re-open a frequent id's learning
  rate when its behaviour changes; the per-coordinate rate only decays with data, so a
  long-lived id reacts slowly to a sudden shift. ^f8
- [method/dynamics] (inferred) For us: score every new day's games with the model as
  it stood before training on them, accumulate that loss on newest-patch games only,
  and compare variants as differences on the same games (paired), sliced by changed vs
  unchanged champions. A patch should reset (raise) the per-champion learning rate or
  prior variance of patched champions, which accumulated-gradient schedules like
  AdaGrad never do by themselves. ^f9

## Read

- Sections 1, 3 (FTRL, per-coordinate rates), 4.1 (feature inclusion), 5 (evaluation)

## Not read

- 4.2-4.5 memory tricks, 6 confidence, 7 calibration, 8 feature management, 9 failures
  (9.1 hashing may matter if embeddings are ever hashed)
