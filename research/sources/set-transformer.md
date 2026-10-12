---
title: 'Lee et al. 2019: Set Transformer'
url: https://arxiv.org/abs/1810.00825
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3, 5 related work, 6.4-6.5 caveats, conclusion)
relevance: medium
grade: A/fair
description: ICML 2019 paper (Oxford, Teh) adding self-attention to set models so elements interact before pooling, with inducing points to cut cost from O(n^2) to O(nm)
---
# Lee et al. 2019: Set Transformer

Why: whether attention between the ten picks (ally synergy, enemy counters) is the
natural neural form of our pair terms, and when it beats simple pooling.

## Assessment

- Evidence: A. ICML 2019, widely cited, standard set baseline.
- Reasoning: fair. Ablations of encoder and pooling; admits it lost to simpler pooling
  on large sets; no noisy-label or small-signal tasks.
- Interests: authors' own method.
- Weigh: trust that attention captures pairwise and higher-order interactions; the
  benefit depends on interactions mattering, which for drafts is unproven at our
  sizes.

## Findings

- [method] Pooling each element independently necessarily discards information about
  interactions between elements. Section 1 ^f1
  > Since every element in a set is processed independently in a set pooling operation, some information regarding interactions between elements has to be necessarily discarded.
- [method] Self-attention blocks encode pairwise interactions and stacking them encodes
  higher-order ones. Section 3 ^f2
  > Since the output of SAB contains information about pairwise interactions among the elements in the input set X, we can stack multiple SABs to encode higher order interactions.
- [method] Cost: full self-attention is O(n^2) in set size; inducing points make it
  O(nm). For ten picks n^2 is trivial. Section 3 ^f3
  > A potential problem with using SABs for set-structured data is the quadratic time complexity O(n2 ), which may be too expensive for large sets
- [method] Interaction modelling lost to simple pooling when the elements already
  carried enough information: Set Transformers won on small sets, lost on large point
  clouds. Section 6.5 ^f4
  > We think Set Transformers were outperformed in the problems with large sets because such sets already had sufficient information for classification, diminishing the need to model complex interactions among points.
- [method] (inferred) For us: attention over the ten picks is the neural analogue of
  FM pair terms; f4 suggests it pays only once interaction signal exceeds what
  per-champion terms capture, which our pair terms say is not yet the case at 90k. ^f5

## Read

- Abstract, 1, 3 (MAB, SAB, ISAB, PMA), 5 related work, 6.4-6.5, conclusion

## Not read

- 4 theory, experiments on amortised clustering and anomaly detection in detail
