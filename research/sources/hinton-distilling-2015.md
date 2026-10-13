---
title: 'Hinton, Vinyals, Dean 2015: Distilling the knowledge in a neural network'
url: https://arxiv.org/pdf/1503.02531
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (1-4, 6)
relevance: high
grade: A/fair
description: Google 2015 paper that named distillation; soft targets at a raised softmax temperature, logit matching as its high-temperature limit, a 10-seed speech ensemble distilled into one net, soft targets as a regulariser on 3% of data
---
# Hinton, Vinyals, Dean 2015: Distilling the knowledge in a neural network

Why: the standard loss (temperature KL plus a hard-label term), how much of a seed
ensemble's gain one student keeps, and why soft targets help with little data.

## Assessment

- Evidence: A. The canonical reference; MNIST and an 85M-parameter Android speech model
  on 700M frames; one run per cell, no error bars.
- Reasoning: fair. Derives logit matching as a limit; mechanisms are argued, and the 3%
  experiment tests the "soft targets carry information" claim directly.
- Interests: Google production system.
- Weigh: trust the loss family and the seed-ensemble result; the classes are many
  (14,000), so "dark knowledge" in tiny probabilities does not exist for a binary
  outcome.

## Findings

- [method] Ensemble teacher: average the members' predictive distributions
  (arithmetic or geometric mean) as soft targets. Section 1 ^f1
  > When the cumbersome model is a large ensemble of simpler models, we can use an arithmetic or geometric mean of their individual predictive distributions as the soft targets.
- [method] [stats] Soft targets give more information per case and less gradient
  variance, so the student needs less data. Section 1 ^f2
  > When the soft targets have high entropy, they provide much more information per training case than hard targets and much less variance in the gradient between training cases
- [method] Loss: cross-entropy to soft targets at temperature T, plus a small
  hard-label term; scale soft gradients by T^2. Section 2 ^f3
  > Since the magnitudes of the gradients produced by the soft targets scale as 1/T 2 it is important to multiply them by T 2 when using both hard and soft targets.
- [method] At high temperature distillation equals squared-error logit matching (Ba and
  Caruana's loss). Section 2.1 ^f4
  > So in the high temperature limit, distillation is equivalent to minimizing 1/2(zi − vi )2 , provided the logits are zero-meaned separately for each transfer case.
- [method] A small term toward the true labels helps: the student errs toward the
  right answer. Section 1 ^f5
  > Typically, the small model cannot exactly match the soft targets and erring in the direction of the correct answer turns out to be helpful.
- [method] [stats] Ten seeds of one architecture (no data variation needed) gave frame
  accuracy 58.9% to 61.1%; one distilled net reached 60.8%, over 80% of the gain.
  Table 1, section 4.1 ^f6
  > More than 80% of the improvement in frame classification accuracy achieved by using an ensemble of 10 models is transferred to the distilled model
- [method] Seed diversity alone was enough for the ensemble; varying training data did
  not change results. Section 4.1 ^f7
  > The models are randomly initialized with different initial parameter values and we find that this creates sufficient diversity in the trained models to allow the averaged predictions of the ensemble to significantly outperform the individual models.
- [method] [stats] Soft targets as regulariser: on 3% of the data, hard targets
  overfit (44.5% with early stopping) while soft targets from a full-data model reached
  57% (full data 58.9%) without early stopping. Section 6 ^f8
  > This shows that soft targets are a very effective way of communicating the regularities discovered by a model trained on all of the data to another model.
- [method] (inferred) For a binary outcome the softmax over two classes is a sigmoid of
  one logit, and temperature only rescales that logit; there are no tiny off-class
  probabilities to reveal, so the useful choice reduces to probability-space
  cross-entropy (T=1) vs logit L2 (T large). With teacher win probabilities in 0.35-0.70
  the sigmoid is nearly linear there and the two give almost the same fit; logit L2
  makes the student a plain weighted least-squares problem. ^f9
- [method] (inferred) ^f8 is the rare-pair case: a pair with 30 games is our "3% of
  data". The teacher, having learnt from every game the two champions played, gives each
  of those 30 games a soft target, and synthetic drafts containing the pair add more;
  the label-fitted pair term would be mostly noise. ^f10

## Read

- Sections 1-2.1, 4 (speech), 6.

## Not read

- Section 3 MNIST details; section 5 specialists (multi-class only).
