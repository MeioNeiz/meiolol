---
title: 'Müller, Kornblith, Hinton 2019: When Does Label Smoothing Help?'
url: https://arxiv.org/abs/1906.02629
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3 calibration)
relevance: low
grade: A/fair
description: NeurIPS 2019 Google Brain paper on label smoothing for multi-class nets: better generalisation and calibration, worse distillation
---
# Müller, Kornblith, Hinton 2019: When Does Label Smoothing Help?

Why: whether label smoothing is a useful regulariser for a noisy binary outcome
(win/loss) whose predictions sit near 0.5.

## Assessment

- Evidence: A. NeurIPS 2019, Hinton's group, much cited.
- Reasoning: fair. Clear experiments on image classification and translation; all
  multi-class, high-confidence settings.
- Interests: none known.
- Weigh: the mechanism (stop over-confidence) targets a problem a 0.55-AUC win model
  barely has.

## Findings

- [method] Label smoothing mixes hard targets with the uniform distribution; it
  prevents over-confidence and improves generalisation and calibration of multi-class
  networks. Abstract ^f1
  > Smoothing the labels in this way prevents the network from becoming over-confident
  > in addition to improving generalization, label smoothing improves model calibration which can significantly improve beam-search.
- [method] Label smoothing calibrates about as well as post-hoc temperature scaling.
  Section 3 ^f2
  > label smoothing also reduces ECE and can be used to calibrate a network without the need for temperature scaling.
- [method] Cost: a teacher trained with label smoothing distils much worse into a
  student. Abstract ^f3
  > if a teacher network is trained with label smoothing, knowledge distillation into a student network is much less effective.
- [method] Checked, not there: no binary or low-signal tasks, nothing on noisy labels
  or data size. ^f4
- [method] (inferred) For a win model whose predictions sit within a few points of
  50%, over-confidence is not the failure mode; L2 or early stopping plus post-hoc
  calibration address the same thing with one less knob. ^f5

## Read

- Abstract, 1, 3 (implicit calibration)

## Not read

- 2 penultimate layer visualisation, 4 distillation experiments
