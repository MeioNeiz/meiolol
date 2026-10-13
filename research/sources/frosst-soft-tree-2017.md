---
title: 'Frosst, Hinton 2017: Distilling a neural network into a soft decision tree'
url: https://arxiv.org/pdf/1711.09784
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: skimmed (abstract, 4-5)
relevance: low
grade: C/fair
description: Google Brain workshop paper; a soft (sigmoid-gated) decision tree trained on a net's soft targets generalises better than one trained on labels; MNIST, Connect4, Letter
---
# Frosst, Hinton 2017: Distilling a neural network into a soft decision tree

Why: a tree-shaped explainable student; how much of the teacher it keeps.

## Assessment

- Evidence: C. Workshop paper, single runs, three datasets, no error bars.
- Reasoning: fair. Honest that the tree keeps only part of the gap.
- Interests: none.
- Weigh: useful only as a data point that low-capacity students keep a fraction of the
  gap; the soft tree's learned filters are not a fit for categorical drafts.

## Findings

- [method] [stats] MNIST: depth-8 soft tree 94.45% on labels, 96.76% on soft targets
  (mixed with true labels), teacher net 99.21%: about half the gap. Section 4 ^f1
  > The soft decision tree trained in this way achieved a test accuracy of 96.76% which is about halfway between the neural net and the soft decision tree trained directly on the data.
- [method] [stats] Connect4 (game outcome from board): 78.63% on labels, 80.60% distilled. ^f2
  > with a tree of depth 8 we were able to achieve a test accuracy of 80.60% on the Connect4 dataset
- [method] [stats] Letter: 78.0% on labels, 81.0% distilled from an ensemble at 95.9%:
  under a fifth of the gap. ^f3
  > We were able to achieve a test accuracy of 78.0% with a tree of depth 9 trained on the raw training data, and a test accuracy of 81.0% when we distilled from an ensemble of neural nets that had a 95.9% test accuracy.
- [method] (inferred) A restricted student keeps only the share of the teacher that fits
  its form; for an additive draft student that share is the additive plus chosen-pair
  part. Expect a gap and measure it rather than assume the 80-97% figures from flexible
  students. ^f4

## Read

- Abstract, sections 4-5.

## Not read

- Section 2-3 tree formulation and regularisers.
