---
title: 'yandex-research/tabm: TabM reference package (README and tabm.py)'
url: https://github.com/yandex-research/tabm
kind: project
commit: 28e47ae301c92ec37787dde1ce923a0793f405b4
for: [nn-draft-models]
looked: 2026-10-13
depth: code (README hyperparameters and training sections, TabM.make defaults)
relevance: high
grade: A/fair
origin: tabm-2024
description: Official TabM package from the paper's authors: default model (3 blocks of 512, dropout 0.1, k = 32), default optimiser (AdamW lr 2e-3, wd 3e-4), training and inference rules
---
# yandex-research/tabm

Why: the paper ([[tabm-2024]]) gives tuning spaces only; the package gives the authors'
recommended defaults and the training rules that are easy to get wrong.

## Assessment

- Evidence: A. Official package; 1,124 stars, 97 forks, Apache-2.0, created Oct 2024,
  last push Nov 2025, release v0.0.3 (Aug 2025).
- Reasoning: fair. Defaults stated without benchmarks of their own; README explains
  the k rules from the paper's Figure 7.
- Interests: authors' own model.
- Weigh: trust the defaults as a starting point; they are for the paper's (mostly
  numerical) datasets.

## Findings

- [method] Default TabM: 3 blocks (2 with numerical embeddings) of width 512, dropout
  0.1, ReLU, k = 32. `tabm.py` TabM.make ^f1
  > 'n_blocks': 2 if has_num_embeddings else 3,
- [method] Default optimiser: AdamW, lr 0.002, weight decay 0.0003. README ^f2
  > the default optimizer is `torch.optim.AdamW(..., lr=0.002, weight_decay=0.0003)`.
- [method] Train the k heads independently (mean of losses, not loss of the mean);
  at inference average probabilities, not logits. README ^f3
  > the *mean loss* must be optimized, *not* the loss of the mean prediction.
  > on classification tasks, *probabilities* should usually be averaged, not logits.
- [method] k: smaller values (16-24) still competitive for exploration; larger k may
  need a wider or deeper backbone; avoid n_blocks = 1 at paper-like data sizes. README ^f4
  > For exploration purposes, one can use lower values of `k` (i.e. 24 or 16) and still get competitive results
  > `n_blocks=1` should usually be avoided unless you have high budget on hyperparameter tuning.
- [method] TabM-mini may train faster and is occasionally better when more
  regularisation helps. README ^f5
  > `'tabm-mini'` can occasionally provide slightly better performance if the higher degree of regularization turns out to be beneficial for a given task.
- [method] 30-50 TPE iterations give a reasonable configuration if peak performance is
  not critical. README ^f6
  > If achieving the highest possible performance is not critical, then 30-50 iterations should result in a somewhat reasonable configuration.
- [method] (inferred) Averaging probabilities over k heads is what gives the convexity
  gain in log loss; with a rating offset each head's logit is offset + head(x). ^f7

## Read

- README.md (Training, Inference, Hyperparameters), tabm.py TabM.make

## Not read

- example.ipynb training loop, tabm.py internals beyond make
