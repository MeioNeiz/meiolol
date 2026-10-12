---
title: 'Gorishniy et al. 2021: Revisiting Deep Learning Models for Tabular Data (FT-Transformer)'
url: https://arxiv.org/abs/2106.11959
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1-3, 4.1-4.5 protocol and takeaways)
relevance: medium
grade: A/strong
description: NeurIPS 2021 Yandex benchmark of tabular DL (MLP, ResNet, FT-Transformer, TabNet, NODE...) vs GBDT on 11 datasets of 20k to 1.2M rows under one tuning protocol
---
# Gorishniy et al. 2021: Revisiting Deep Learning Models for Tabular Data

Why: at our scale (10^5 to 10^7 rows), which neural baseline is worth trying, how it
compares with GBDT, and what the tuning and ensembling protocol costs.

## Assessment

- Evidence: A. NeurIPS 2021, widely cited, code released, same protocol for every
  model, 15 seeds per configuration.
- Reasoning: strong. Admits the benchmark leans DL-friendly and that GBDT wins on
  some sets; reports training cost as a limitation.
- Interests: authors propose FT-Transformer.
- Weigh: datasets are larger than Grinsztajn's (20k to 1.2M rows) but mostly
  numerical; no high-cardinality sparse categorical set like ours.

## Findings

- [method] No universally superior solution between GBDT and deep models; a tuned
  ResNet-like MLP is a strong baseline and FT-Transformer wins most of their tasks.
  Abstract ^f1
  > We also compare the best DL models with Gradient Boosted Decision Trees and conclude that there is still no universally superior solution.
- [method] Tuning makes plain MLP and ResNet competitive; MLP stays a good sanity
  check. Section 4.4 ^f2
  > Tuning makes simple models such as MLP and ResNet competitive, so we recommend tuning baselines when possible.
- [method] Protocol: Optuna TPE (Bayesian) tuning on the validation set, 15 seeds per
  tuned config, ensembles of 5 averaged models; comparing ensembles because GBDT is
  itself an ensemble and DL benefits more from ensembling. Section 4.3, 4.5 ^f3
  > For each model, on each dataset, we obtain three ensembles by splitting the 15 single models into three disjoint groups of equal size and averaging predictions of single models within each group.
  > GBDT is essentially an ensembling technique and we expect that deep architectures will benefit more from ensembling
- [method] Cost: FT-Transformer needs more hardware and time than ResNet; attention is
  quadratic in the number of features. Section 3.3 ^f4
  > FT-Transformer requires more resources (both hardware and time) for training than simple models such as ResNet
- [method] DL beating GBDT on most of their tasks reflects a benchmark tilted to
  DL-friendly problems; tuned GBDT dominates on some. Section 4.5 ^f5
  > the fact that DL models outperform GBDT on most of the tasks does not mean that DL solutions are “better” in any sense. In fact, it only means that the constructed benchmark is slightly biased towards “DL-friendly” problems.
- [method] (inferred) With 10 categorical slots, FT-Transformer is a Set-Transformer-like
  model over pick tokens; tokens are few, so the cost concern is training time per
  epoch, not attention size. ^f6

## Read

- Abstract, 1, 3 (MLP, ResNet, FT-Transformer), 4.1-4.5

## Not read

- 4.6 FT-Transformer vs ResNet on synthetic data, 5 analysis, supplementary timings
