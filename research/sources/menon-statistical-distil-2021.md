---
title: 'Menon, Rawat, Reddi, Kim, Kumar 2021: A statistical perspective on distillation (Why distillation helps)'
url: https://arxiv.org/pdf/2005.10419
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (abstract, 1, 3 discussion, 5.1)
relevance: high
grade: B/strong
description: Google Research (ICML 2021; arXiv 2005.10419 "Why distillation helps") theory and experiments; a teacher helps by estimating the Bayes class-probabilities, cutting the variance of the student's risk; bias-variance tradeoff for imperfect teachers
---
# Menon, Rawat, Reddi, Kim, Kumar 2021: A statistical perspective on distillation

Why: when do soft targets help a student, especially on a binary outcome with noisy
labels, and what makes a good teacher for that (accuracy vs calibration)?

## Assessment

- Evidence: B. Peer-reviewed theory (Google Research) with synthetic experiments where
  the true probabilities are known (100 trials per point) and image benchmarks.
- Reasoning: strong. Formal statement (Bayes-distilled risk has lower variance, equal
  iff labels are deterministic), explicit bias-variance tradeoff, says the bound is
  loose.
- Interests: none.
- Weigh: trust the direction (noisier labels, bigger gain; calibration matters more than
  accuracy). The binary synthetic case is logistic regression, close to our student.

## Findings

- [stats] A good teacher estimates the true (Bayes) class-probabilities; distilling
  them gives an unbiased student risk with lower variance than one-hot labels.
  Section 3 ^f1
  > For discriminative predictors and non-deterministic labels, however, the Bayes-distilled risk can have significantly lower variance.
- [stats] The variance gain vanishes only when labels are deterministic; the noisier
  the label, the larger it is. Section 3 ^f2
  > the two risks trivially agree when f is non-discriminative (attaining equal loss on all labels), or when a label is inherently deterministic (the class-probability is concentrated on one label).
- [stats] Experiment, binary logistic regression with known p*: Bayes-distilled beats
  one-hot fits at finite N, the gap closing as N grows. Section 5.1 ^f3
  > This in line with our intuition that distillation effectively augments each training sample: when N is large to begin with, the marginal gain of such augmentation is minimal.
- [stats] The harder (more overlapping, noisier) the classes, the larger the gain from
  distillation. Section 5.1, Figure 2(b) ^f4
  > Consequently, the gains of distillation over the one-hot encoding are greater for this setting, in line with our guarantee on the lower-variance Bayes-distilled risk aiding generalisation (Proposition 2).
- [stats] [method] Teacher accuracy is not enough: what matters is how close its
  probabilities are to p* in mean square; overconfident accurate teachers give worse
  students. Section 3 ^f5
  > Our result thus potentially illuminates why more accurate teachers may lead to poorer students, as has been noted empirically [Müller et al., 2019]
- [stats] Distorting teacher probabilities while keeping its accuracy fixed
  progressively removed the student's gain. Section 5.1 ^f6
  > We assess this by artificially distorting the teacher probabilities so as to perfectly preserve teacher accuracy, while degrading their approximation to p∗ .
- [stats] Teacher variance across training samples is a penalty: high-capacity teachers
  lower bias but vary more between fits. Section 3 ^f7
  > High-capacity teachers may yield vastly different predictions when trained on fresh samples. This variability incurs a penalty in the third term in Proposition 3.
- [stats] (inferred) Our setting is the favourable extreme of ^f2 and ^f4: draft
  explains only a few points of win rate, so the label is close to a coin flip and
  one-hot win/loss has nearly maximal variance; a calibrated teacher probability is
  worth many games per game. ^f8
- [stats] (inferred) ^f5 and ^f7 say how to pick the teacher: by held-out log loss and
  calibration, not accuracy, and as a seed average (which cuts teacher variance). Check
  calibration of the seed-ensemble mean before distilling. ^f9

## Read

- Abstract, section 1, section 3 (Lemma 1 discussion, Proposition 3 discussion), 5.1.

## Not read

- Section 4 double distillation (multiclass retrieval); 5.2-5.3 image experiments.
