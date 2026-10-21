---
title: Kearns: bound on cross validation error, training-test split
url: https://www.cis.upenn.edu/~mkearns/papers/cv.pdf
kind: paper
commit: 
for: [patch-transfer]
looked: 2026-10-21
depth: docs (whole paper)
relevance: medium
grade: A/fair
description: COLT 1995 / Neural Computation 1997: how the fraction of data held out for testing trades off when the holdout picks model complexity
---
# Kearns: bound on cross validation error, training-test split

Why: how many scarce newest-patch games to hold out when they pick a setting (the shrinkage strength) rather than only report a score.

## Assessment

- Evidence: A. Kearns, canonical learning-theory treatment; bound plus controlled experiments.
- Reasoning: fair. Says itself that the constants are meaningless and only the qualitative shape counts.
- Interests: none.
- Weigh: the setting is holdout for model selection then refit; it says nothing about the variance of a reported score. Our use: choosing a prior strength on new-patch games.

## Findings

- [stats] When the target is simple relative to the sample, the held-out fraction barely matters (a wide flat bowl). Abstract, Section 6 ^f1
  > it appears that any choice of between 0:10 and 0:50 yields nearly optimal generalization error.
- [stats] The more complex the target relative to the sample, the more the choice matters and the smaller the best held-out share. Abstract ^f2
  > The importance of choosing optimally increases, and the optimal value for decreases, as the target function
- [stats] One fixed held-out share, about 10% in their experiments, was near optimal across all complexities tried. Section 6 ^f3
  > that performs nearly optimally for the entire range of s examined
- [stats] (inferred) For us: a patch offset model with one or two knobs (a shrinkage strength) is "simple", so where we draw the train-eval line among new-patch games matters little for the fitted model; the larger cost of a small eval set is the noise in the score itself. ^f4

## Read

- Whole paper.

## Not read

- Proofs in section 4.
