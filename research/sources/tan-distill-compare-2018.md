---
title: 'Tan, Caruana, Hooker, Lou 2018: Distill-and-Compare, auditing black-box models using transparent model distillation'
url: https://arxiv.org/pdf/1710.06169
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (1-3.5)
relevance: medium
grade: B/fair
description: AIES 2018 paper; distils black-box risk scores into an iGAM (EBM precursor) mimic model and compares it with an iGAM fitted to real outcomes, with bootstrap confidence intervals per feature
---
# Tan, Caruana, Hooker, Lou 2018: Distill-and-Compare, auditing black-box models using transparent model distillation

Why: the paired design (student on teacher scores vs same model class on real
outcomes) is a direct test of whether a teacher learnt something the labels alone
don't show; and the loss and scale used for a binary risk.

## Assessment

- Evidence: B. Four public risk-score datasets (COMPAS under 7k rows to
  Stop-and-Frisk at 126k), error bars on fidelity and AUC, one case with a known
  generating formula.
- Reasoning: fair. Explicit about calibration and noise; the reasons offered for
  differences are hypotheses, as the authors say.
- Interests: none beyond the authors' iGAM.
- Weigh: the method (same class, same rows, compare per-feature curves with CIs) is
  the useful part; accuracy numbers are about auditing, not distillation gains.

## Findings

- [method] Mimic model trained by mean squared error between teacher score and
  student, on unlabelled inputs run through the teacher. Section 2.1 ^f1
  > We train the mimic model to minimize mean squared error between the teacher and student
- [method] Scores are first mapped to the logit scale and calibrated (a monotone
  transform, like isotonic regression) so mimic and outcome models are comparable.
  Section 2.3.2 ^f2
  > We select this scale to be logit probabilities (since the outcome model’s outputs are already on this scale)
- [method] [stats] Compare per feature: difference of the two models' shape functions
  with bootstrap-of-little-bags confidence intervals; train both on the same sample to
  remove sample noise. Section 2.3.3 ^f3
  > To avoid data sample-specific effects, we train the mimic and outcome models on the same data sample.
- [method] [stats] The mimic is tighter than the outcome model where outcomes are
  sparse and noisy (ages over 70): soft scores carry less noise than labels. ^f4
  > For example, for ages greater than 70, the outcome model has much wider confidence intervals than the mimic model.
- [method] Fidelity: iGAM with pairs was about as faithful as a random forest on three
  of four scores (Lending Club RMSE 2.52 vs 2.48; COMPAS 2.00 vs 2.02); random forests
  won clearly only on Chicago Police (14.0 vs 16.5). Table 2 ^f5
  > For the risk score mimic models, random forests are competitive for Lending Club and Chicago Police.
- [method] More teacher-labelled inputs helped little when the student was limited
  by missing features (COMPAS: +3,000 rows took RMSE 2.0 to 1.98). Section 3.5 ^f6
  > Adding them to the training (not testing) data for the mimic model and retraining the mimic model, we find marginal improvement in the mimic model’s fidelity (from RMSE 2.0 to 1.98).
- [method] (inferred) Distill-and-compare is our validation step: fit the same
  additive model with shrinkage once on teacher logits and once on win labels; where
  the two champion or pair curves differ beyond their bootstrap CIs, the teacher has
  learnt something (or invented it), and those are the effects to check in `meiolol
  eval`. ^f7
- [method] (inferred) ^f4 is the rare-pair argument in small: where a pair has few
  games, the label-fitted term is all noise and shrinks to zero, while the teacher's
  score still carries the pair's composition through features the teacher shares
  with other games. ^f8

## Read

- Abstract, sections 1-3.5, Table 2.

## Not read

- Section 3.4 statistical test for missing features; appendix A CI method.
