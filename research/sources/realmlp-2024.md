---
title: 'Holzmüller, Grinsztajn, Steinwart 2024: Better by Default: Strong Pre-Tuned MLPs and Boosted Trees on Tabular Data (RealMLP)'
url: https://arxiv.org/abs/2407.04491
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: skimmed (abstract, 3 RealMLP recipe, 5 discussion, A.1 table, A notes, B.5 AUROC)
relevance: high
grade: A/strong
description: NeurIPS 2024 (Inria, Stuttgart): RealMLP, an MLP with meta-tuned defaults (3x256, dropout 0.15, wd 0.02, multi-cycle lr, 256 epochs, batch 256, best-epoch selection) tuned on 118 datasets, tested on 90 more
---
# Holzmüller et al.: RealMLP, Better by Default

Why: a tuned-default MLP recipe validated out of sample (meta-train vs meta-test
datasets), so a starting config without our own big search; and its caveats for log
loss.

## Assessment

- Evidence: A. NeurIPS 2024; defaults tuned on 118 datasets, tested on a disjoint 90
  and the Grinsztajn benchmark (1k-500k rows); open code (pytabkit).
- Reasoning: strong. Ablations in Appendix B, admits order dependence and that label
  smoothing is not a proper scoring rule.
- Interests: authors propose RealMLP.
- Weigh: defaults were tuned for classification error, not log loss; lr 0.04 is in
  neural tangent parametrisation (scaled by 1/sqrt(fan-in)), not a plain Adam lr.

## Findings

- [method] Tuned defaults make an MLP competitive with GBDTs on 1k-500k-row data; a
  RealMLP plus GBDT combination works well without tuning. Abstract ^f1
  > Our benchmark results on medium-to-large tabular datasets (1K–500K samples) show that RealMLP offers a favorable time-accuracy tradeoff compared to other neural baselines and is competitive with GBDTs in terms of benchmark scores.
- [method] Defaults: 3 hidden layers of 256; AdamW with beta2 0.95; 256 epochs, batch
  256; cross-entropy with label smoothing 0.1. Section 3 ^f2
  > three hidden layers containing 256 neurons each
  > RealMLP is optimized for 256 epochs with a batch size of 256.
  > we use softmax + cross-entropy with label smoothing [62] with parameter ε = 0.1.
- [method] Regularisation defaults: dropout 0.15 after each activation and weight decay
  0.02, both on a flat-then-cosine schedule. Figure 1 ^f3
  > Dropout p = 0.15
  > Weight decay wd = 0.02
- [method] No classical early stopping: a 4-cycle cosine-log lr schedule over all 256
  epochs, then revert to the best validation epoch (last of ties). Section 3 ^f4
  > we do not perform classical early stopping. Instead, we always train for the full 256 epochs and then revert the model to the epoch with the lowest validation error
- [method] Categoricals over 8 levels get embeddings of size 8; but they could not show
  embeddings beat one-hot (few high-cardinality features in their benchmark). App. A ^f5
  > we were not able to conclude whether categorical embeddings are helpful or harmful compared to one-hot encoding
  > we found that 4 already gave good results for numerical embeddings and decided to use 8 for categorical variables.
- [method] Pitfall: label smoothing is not a proper scoring rule and hurt AUC; select
  epochs on cross-entropy, not accuracy. App. A, B.5 ^f6
  > cross-entropy with label smoothing is not a proper scoring rule, that is, in the infinite-sample limit, it is not minimized by the true probabilities P (y|x)
  > Stopping for cross-entropy generally performs better than stopping for classification error.
  > Label smoothing harms RealMLP for AUC
- [method] Larger patience and cyclic lr schedules help if affordable; the large weight
  decay makes the recipe sensitive to other settings such as beta2. Section 5 ^f7
  > the large weight decay value makes RealMLP-TD sensitive to changes in some other hyperparameters like β2 .
  > If affordable, larger stopping patiences and the use of (cyclic) learning rate schedules can be useful
- [method] Learning rate base value 0.04 under neural tangent parametrisation (layer
  output scaled by fan-in^-1/2), so not comparable to a standard Adam lr. A.1, Section 3 ^f8
  > Our linear layers use the neural tangent parametrization (NTP)
- [method] (inferred) For a log-loss target with ~0.004 nats of signal, drop label
  smoothing (it biases probabilities toward 0.5, i.e. directly against our metric) and
  select the epoch on validation log loss. ^f9

## Read

- Abstract, 1, 3 (preprocessing, architecture, training, best-epoch), 5, App. A notes,
  Table A.1, B.5

## Not read

- B.1-B.4 ablations in detail, 4 GBDT defaults
