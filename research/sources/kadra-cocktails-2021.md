---
title: 'Kadra, Lindauer, Hutter, Grabocka 2021: Well-tuned Simple Nets Excel on Tabular Datasets (regularisation cocktails)'
url: https://arxiv.org/abs/2106.11189
kind: paper
commit: 
for: [nn-draft-models]
looked: 2026-10-13
depth: skimmed (abstract, 1, 5.1-5.2 setup, B.1 Table 4, C.2-C.3, 6 conclusion)
relevance: medium
grade: B/fair
description: NeurIPS 2021 (Freiburg): a fixed 9x512 MLP plus a per-dataset BOHB search over 13 regularisers (dropout, weight decay, SWA, snapshot ensembles, mixup...) beat XGBoost and tabular architectures on 40 datasets of 452-416k rows
---
# Kadra et al.: Well-tuned Simple Nets Excel on Tabular Datasets

Why: which regularisers matter for a plain MLP on tabular data, and whether one fixed
recipe transfers across datasets.

## Assessment

- Evidence: B. NeurIPS 2021, 40 OpenML datasets, but one train-val-test split per
  dataset and up to 4 days of BOHB per dataset; tuned for balanced accuracy, not log loss.
- Reasoning: fair. Clear ablations; the win over XGBoost rests on a very large per-dataset
  search, a cost later work (RealMLP, TabM) avoids.
- Interests: authors' AutoML group (Auto-PyTorch).
- Weigh: trust "regularisation matters more than architecture" and "no single
  regulariser always wins"; discount the GBDT verdict (single split, heavy search).

## Findings

- [method] A plain MLP with a per-dataset combination of 13 regularisers beat recent
  tabular architectures and XGBoost on 40 datasets. Abstract ^f1
  > (i) well-regularized plain MLPs significantly outperform recent state-of-the-art specialized neural network architectures, and (ii) they even outperform strong traditional ML methods, such as XGBoost.
- [method] The 13 candidates: batch norm, SWA, lookahead, weight decay, dropout,
  snapshot ensembles, skip connections, multi-branch, shake-drop, shake-shake, mixup,
  cutmix, cutout, FGSM adversarial training. Table 1 ^f2
  > SD: Shake-Drop, SS: Shake-Shake, MU: Mix-Up, CM: Cut-Mix, CO: Cut-Out, and AT: FGSM Adversarial Learning
- [method] Fixed backbone: 9-layer MLP of 512 units, AdamW at lr 1e-3, batch 128,
  cosine annealing with restarts (15 epochs, multiplier 2), 105 epochs. 5.1-5.2, Table 4 ^f3
  > We use a 9-layer feed-forward neural network with 512 units for each layer
  > we set a low learning rate of 10−3 after performing a grid search for finding the best value across datasets.
  > each configuration was run for 105 epochs, in accordance with the cosine learning rate annealing with restarts
- [method] No regulariser or combination was chosen on every dataset; the dataset-
  specific cocktail beat both the 5 most chosen and the 5 best single regularisers. C.2 ^f4
  > there is no regularization method or combination that is always chosen for every dataset.
  > the cocktail outperforms both top-5 variants, indicating the need for dataset-specific regularization cocktails.
- [method] Tuning the learning rate per dataset on top did not help significantly
  (21 wins, 18 losses, p = 0.7). C.3 ^f5
  > the results are not statistically significant with a p-value of 0.7 and do not indicate a clear region where the dynamic learning rate helps.
- [method] Cost: BOHB up to 4 days or 40 x D configurations per dataset, one split.
  5.1 ^f6
  > we ran BOHB for at most 4 days, or at most 40 × D hyperparameter configurations, whichever came first.
- [method] (inferred) The transferable lesson for a low-signal target is "regularise
  hard and tune the regularisers, not the architecture"; a 9x512 net is far more capacity
  than our ~0.004 nats of signal needs, so start small (cf. [[actuarial-scaling-2026#^f2]]). ^f7

## Read

- Abstract, 1, 5.1-5.2, B.1 Table 4, C.2-C.3, 6

## Not read

- 3 regulariser review, per-dataset tables, per-regulariser ablations (C.1)
