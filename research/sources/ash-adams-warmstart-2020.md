---
title: 'Ash and Adams 2020: On Warm-Starting Neural Network Training'
url: https://arxiv.org/pdf/1910.08475
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: listed (sections 1-5)
relevance: high
grade: B/fair
description: Ash (MSR NYC) and Adams (Princeton), NeurIPS 2020; warm-starting a net from its fit on part of the data and retraining on all of it generalises worse than a fresh init at equal training loss; shrink and perturb (theta <- lambda theta + noise) closes the gap and keeps most of the speed-up
---
# Ash and Adams 2020: On Warm-Starting Neural Network Training

Why: each patch adds games; should the set net be refit on the pooled set from a
fresh init, warm-started from last patch's net, or something in between?

## Assessment

- Evidence: B. NeurIPS 2020, widely cited; ResNet-18, 3-layer MLP and logistic
  regression on CIFAR-10/100 and SVHN, 5 seeds; hyperparameter grids. Image data,
  trained to convergence with no augmentation or learning-rate schedule, so a regime
  that magnifies the effect.
- Reasoning: fair. Careful elimination of obvious fixes (lr, batch size, L2,
  confidence penalty) and a mechanism (gradient imbalance between seen and unseen
  data); no theory for why the warm start lands in a worse basin.
- Interests: none known.
- Weigh: trust the direction for non-convex nets trained to convergence; logistic
  ratings are safe to warm start. Our set net is small, trained with early stopping
  on noisy outcomes: the gap may be small there, so measure, don't assume.

## Findings

- [method/dynamics] Warm-starting on the full data from a model fit on half of it
  gives similar training loss but worse test accuracy than a fresh init. Abstract ^f1
  > in practice this warm-starting seems to yield poorer generalization performance than models that have fresh random initializations, even though the final training losses are similar
- [method/dynamics] Damaged for ResNets and MLPs, not for convex logistic regression
  (e.g. CIFAR-10 MLP with Adam 39.4% fresh vs 36.1% warm; LR 33.8 vs 33.3). The gap
  shrinks as the first round's share of the data shrinks. Section 2.1, Table 1 ^f2
  > Logistic regression, which enjoys a convex loss surface, is not significantly damaged by warm starting for any datasets.
  > the gap is inversely proportional to the fraction of data available in the first round of training
- [method/dynamics] Online version (1,000 new samples per round): the gap grows as
  data accumulate. Section 2.2 ^f3
  > As more data arrive, the gap in validation accuracy increases substantially.
- [method/dynamics] Hyperparameters that close the gap also remove the time saving;
  L2 and other regularisers help but don't close it. Sections 3.1, 3.3 ^f4
  > we do find warm-started models that perform as well as randomly-initialized models, but they are unable to do so while benefiting from their warm-started initialization
  > regularization does not resolve the generalization gap
- [method/dynamics] Mechanism offered: gradients from new data are much larger than
  from data already seen, so the model doesn't learn from new data as a fresh fit
  would. Section 4 ^f5
  > For warm-started models, gradients from new, unseen data tend to be much larger magnitude than those from data the model has seen before.
- [method/dynamics] Shrink and perturb: before each round set every parameter to
  lambda times its old value plus small noise (noise drawn as a scaled fresh init).
  lambda 0.6 matched fresh-init accuracy and trained much faster; smaller lambda
  sometimes beat fresh init. Section 4, Figure 7 ^f6
  > we propose initializing the network’s parameters by shrinking the weights found in the previous round of optimization towards zero, then adding a small amount of parameter noise
  > if we instead initialize parameters using the shrink and perturb trick, we are able to both close this generalization gap and significantly speed up training
- [method/dynamics] Shrinking only the last layer, or a confidence penalty, did not
  fix it; all parameters had to change. Section 4 ^f7
  > For sophisticated architectures especially, we find it is important to holistically modify parameters before training on new data.
- [method/dynamics] Transfer across datasets: warm start helps when the target set
  is small, but past a crossover fresh training wins; the crossover can't be
  predicted, and shrink-perturb matched the better of the two at every size. Section 4.2 ^f8
  > Often, when the second dataset is small, warm starting is helpful, but there is frequently a crossover point where better generalization would be achieved by training from scratch on that fraction of the target data.
  > shrink-perturbed models perform at least as well as warm-started models when pre-training is the most performant strategy and as well as randomly-initialized models when it is better to learn from scratch
- [method/dynamics] Checked, not there: no replay or weighting of old data, no
  partial (layer-wise) refit, and no shift that touches only a few inputs; the second
  round always trains on the union. ^f9
- [method/dynamics] (inferred) For us: ratings (convex) can always warm start; for
  the set net, a pooled refit warm-started from last patch's net may generalise
  worse than a fresh fit. Cheap test: fresh vs warm vs shrink-perturb (lambda
  0.3-0.6) on the same pooled data, scored on held-out newest-patch games. ^f10

## Read

- Abstract, sections 1-5

## Not read

- Appendix 8 (per-setting grids, Figure 13 other data and architectures)
