---
title: Frustratingly Easy Domain Adaptation (Daumé 2007)
url: https://arxiv.org/abs/0907.1815
kind: paper
commit: 
for: [patch-transfer]
looked: 2026-10-21
depth: docs (sections 1-4)
relevance: high
grade: A/strong
description: ACL 2007 paper: supervised domain adaptation by feature augmentation (shared plus per-domain copies), against the standard baselines
---
# Frustratingly Easy Domain Adaptation (Daumé 2007)

Why: how to train on a big old domain (previous patches) plus a little new one (newest patch).

## Assessment

- Evidence: A. ACL 2007, one of the most cited domain adaptation papers; nine tasks with significance marks.
- Reasoning: strong. States where its method loses and offers why.
- Interests: none known; author's own method vs baselines.
- Weigh: tasks are NLP taggers with averaged perceptron, not win prediction; the structure (shared plus domain copies) transfers, the margins don't.

## Findings

- [method/dynamics] Standard baselines with N source and M target examples: source only, target only, all pooled, pooled with source down-weighted, source prediction as a feature, and interpolating source and target models. Section 2 ^f1
  > These baselines are actually surprisingly difficult to beat.
- [method/dynamics] Pooling everything risks the large source washing out the small target, the reason for down-weighting source examples. Section 2 ^f2
  > may “wash out” any affect
- [method/dynamics] PRIOR (Chelba and Acero) regularises target weights toward the source model's weights instead of toward zero. Section 2 ^f3
  > the model trained on the target data “prefers” to have weights that are similar to the weights
- [method/dynamics] AUGMENT: each feature gets a shared copy plus one per domain, then one ordinary L2 fit; with L2 it acts like a penalty on the difference between source and target weights, fitted jointly not sequentially. Sections 3, 3.1 ^f4
  > This leads to a regularizer proportional to
- [method/dynamics] It handles any number of source domains, one copy each, so every past patch can be its own domain. Section 3.3 ^f5
  > Our formulation is agnostic to the number of
- [method/dynamics] AUGMENT won almost everywhere, PRIOR second; it lost where target-only did worse than source-only, i.e. where the target data was too small to tell the domains apart. Section 4 ^f6
  > the clear second-place contestant is the P RIOR model
  > Our hypothesis is that the common feature of these examples is that these are exactly the tasks for which
- [method/dynamics] (inferred) For us: champion rating = shared + per-patch copy, L2 on each, is exactly our "stationary strength plus shrunk per-patch offset" (frontier-dynamics C3); PRIOR is "warm start, regularised toward last patch". The paper's own loss case is our patch day: too few new games for the per-patch copy to beat the shared one. ^f7

## Read

- Sections 1-4 and the results table discussion.

## Not read

- Kernelised analysis and the appendix script.
