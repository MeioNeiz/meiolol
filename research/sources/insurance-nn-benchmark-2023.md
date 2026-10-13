---
title: 'Holvoet, Antonio, Henckaerts 2023/2025: Neural networks for insurance pricing with frequency and severity data'
url: https://arxiv.org/abs/2310.12671
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: skimmed (abstract, 3.1 CANN, 3.3 tuning, 4.3 grid, 4.4, 4.5 deviances)
relevance: medium
grade: B/fair
description: KU Leuven benchmark (arXiv v4 2025) of GLM, GBM, FFNN and CANN (GLM or GBM offset plus net, fixed or trainable output weights) on four insurance sets of 68k to 669k rows
---
# Holvoet et al.: Neural networks for insurance pricing

Why: an empirical test of CANN (net on top of a GLM or GBM prediction) against a plain
net and the GLM, on noisy targets at our row count.

## Assessment

- Evidence: B. Peer-reviewed actuarial venue, 4 public datasets (68k to 669k rows),
  6-fold CV, 3 seeds per model, Diebold-Mariano tests.
- Reasoning: fair. Reports where models tie; small tuning grids (40 random points).
- Interests: none known.
- Weigh: Poisson frequency, not binary win; numerical plus categorical features. The
  ranking (CANN >= GLM > plain FFNN) is the transferable part.

## Findings

- [method] CANN implementation: the base model's log prediction joins the net's output
  node via a skip connection, not the hidden layers; output weights either fixed at 1
  (fixed CANN) or trainable (flexible CANN). 3.1 ^f1
  > ŷ IN directly connects to the output node of the FFNN via a so-called skip connection.
  > In our case study, we also run experiments with trainable weights in the output layer and refer to this model as the flexible CANN.
- [method] [stats] CANN on a GBM base was lowest deviance for frequency on all four
  sets; the plain FFNN was the one model slightly worse on the low-feature set. 4.5 ^f2
  > Among the four data sets analyzed, the combination of a neural network and a gradient boosting model (CANN GBM flex) consistently yields the lowest deviance when modeling claim frequency.
  > similar performance observed across all models except for the feed-forward neural network, which exhibits slightly higher deviance.
- [method] Trainable output weights (flexible CANN) beat fixed weights in most cases.
  4.5 ^f3
  > Notably, the CANN models with a flexible output layer structure outperform those with a fixed output layer in most cases, for both frequency and severity modeling.
- [method] Small nets suffice: tuning ranges were 1-4 hidden layers of 10-50 nodes,
  dropout 0-0.1, batch 10k-50k for frequency. Table 3 ^f4
  > Table 3: Collection of tuning parameters and their respective ranges for the random grid search tuning strategy.
  > Nodes per hidden layer
- [method] Seed variance: every model trained 3 times and out-of-sample loss averaged,
  with 20% of training data held out for early stopping. 4.3 ^f5
  > Because optimization in a neural network is dependent on the random initialization of the weights, we train each model three times and use the average out-of-sample loss over the three training runs.
- [method] Learned categorical embeddings (autoencoder) helped the plain FFNN but made
  negligible difference to the CANN for frequency. 4.4 ^f6
  > However, the impact on CANN models appears to be negligible.
- [method] (inferred) A residual net on a good base inherits its main effects, so the
  input encoding and net size matter less; gains over the base are small and need
  paired tests (Diebold-Mariano) at our noise level. ^f7

## Read

- Abstract, 3.1, 3.3, 4.3 tuning grid, 4.4, 4.5 deviance comparison

## Not read

- Appendix B deviance tables (exact gains), surrogate GLM sections, severity results
