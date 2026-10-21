---
title: 'Erickson et al. 2025: TabArena: A Living Benchmark for Machine Learning on Tabular Data'
url: https://arxiv.org/pdf/2506.16791v4
kind: paper
commit: 
for: [frontier-tabular-ensembles]
looked: 2026-10-21
depth: skimmed (abstract, 1-2, 4, A.6, C.3-C.5)
relevance: high
grade: A/strong
description: NeurIPS 2025 D&B (AWS, Freiburg, Inria, Prior Labs): living tabular benchmark, 51 curated IID datasets of 500-250k rows, 16 models tuned with 200 configs and 8-fold CV ensembles; GES post-hoc ensembles, validation overfitting by model
---
# Erickson et al. 2025: TabArena

Why: the current reference benchmark for which tabular learners win, how ensembles are
built (greedy ensemble selection over tuned configs) and where they overfit validation.

## Assessment

- Evidence: A. NeurIPS 2025, maintained leaderboard, authors from AutoGluon, TabPFN,
  RealMLP and TabICL groups; 51 datasets, 16 models, 200 configs each, 8-fold inner CV.
- Reasoning: strong. Studies its own design choices (holdout vs CV, overtuning) and
  states what it excludes.
- Interests: authors build AutoGluon, RealMLP, TabPFN and TabICL, which all do well.
- Weigh: IID only, at most 250k rows, ROC AUC metric for binary: none of our regime (time
  split, 1.4M rows, log loss near coin flip). Trust the ensembling and overfitting
  findings more than the model ranking.

## Findings

- [method/tabular] Out of scope by design: non-IID data (temporal, shift) and data over
  250k training rows. Section 1 ^f1
  > We explicitly leave for future work use cases such as non-IID data (e.g., temporal dependencies, subject groups, or distribution shifts)
  > large data (e.g., more than 250 000 training samples)
- [method/tabular] [method/ensemble] Results: best single-model performance comes from
  post-hoc ensembling tuned configs; tuned and ensembled deep learning matches or beats
  GBDTs; foundation models win on small data; cross-model ensembles are state of the
  art. Section 1 ^f2
  > The best performance for individual tabular machine learning models is generally achieved by post-hoc ensembling tuned hyperparameter configurations
  > Ensemble pipelines leveraging various models are the state-of-the-art for tabular data, but the best individual models do not contribute equally to the ensemble pipeline.
- [method/ensemble] Greedy ensemble selection (Caruana) runs N = 40 iterations over the
  200 configs' out-of-fold predictions, giving a sparse weighted mean. C.4 ^f3
  > The vector W is learned via a greedy algorithm that runs for a fixed number of iterations N (N = 40
- [method/ensemble] Cross-validation ensembles: the 8 fold models are averaged instead of
  refitting on all data, like bagging. C.3 ^f4
  > We then ensemble the 8 fold models by averaging their predictions, mirroring a bagging ensemble.
- [method/ensemble] Holdout instead of CV for selection underestimates every model and
  favours models that already ensemble internally. Section 4 ^f5
  > when using holdout validation instead of cross-validation for model selection, all models are greatly underestimated, and performance is biased in favor of models that already use ensembling
- [method/ensemble] The cross-model ensemble over-selects models that overfit the
  validation data (ModernNCA, RealMLP) and under-selects TabM, yet still beats every
  model and AutoGluon. A.6 ^f6
  > the models that are most overfit on the validation data will naturally be over-selected by the ensembling algorithm
  > Similarly, models that perform very well on test data while avoiding overfitting (such as TabM) are
- [method/tabular] Neural nets overtune far more than trees; TabM is the exception,
  plausibly from internal ensembling and joint early stopping. A.6 ^f7
  > neural network models overfit much more than other methods, even with far fewer configurations.
  > TabM stands out as the sole exception, demonstrating remarkable resilience to overfitting
- [method/tabular] Foundation models were run only where they fit: TabPFNv2 up to 10k
  rows, TabICL up to 100k; TabDPT has no size limit. C ^f8
  > In particular, TabPFNv2 is restricted to datasets with up to 10, 000 training samples, 500
- [method/tabular] Most models saturate by about 200 random configs; ModernNCA peaks at 25
  and then degrades from overtuning. A.6 ^f9
  > ModernNCA’s performance peaks at 25 configurations and then progressively degrades with further tuning
- [method/ensemble] (inferred) For us: GES over many configs is the standard way to build
  an ensemble, but its weights follow validation overfit; with our A/A floor near 0.5
  milli-nats, weights should be fitted on forward folds and judged on a sealed block. ^f10

## Read

- Abstract, sections 1, 2.1-2.2, 4, A.6, C.3-C.5 (raw/tabarena-2025.txt)

## Not read

- Per-dataset tables and the Elo method (D.1); the leaderboard's later versions
