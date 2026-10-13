---
title: 'Stanton, Izmailov, Kirichenko, Alemi, Wilson 2021: Does knowledge distillation really work?'
url: https://arxiv.org/pdf/2106.05945
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: skimmed (abstract, 1, 3, 7)
relevance: medium
grade: B/strong
description: NeurIPS 2021 NYU/Google paper separating fidelity (student matches teacher) from generalisation; students of ensembles generalise better yet match their teachers poorly, mainly because the distillation optimisation is hard
---
# Stanton, Izmailov, Kirichenko, Alemi, Wilson 2021: Does knowledge distillation really work?

Why: the critic's question: does a distilled student explain its teacher (fidelity),
or just itself?

## Assessment

- Evidence: B. Careful image experiments (CIFAR-100, ResNets, ensembles of 3-5),
  several seeds, many ablations; deep-net students only.
- Reasoning: strong. Defines fidelity and generalisation separately and tests
  identifiability (more data) vs optimisation hypotheses.
- Interests: none.
- Weigh: the deep-net optimisation failure does not carry over to a convex student
  (ridge on logits has one optimum); the fidelity-vs-generalisation distinction does.

## Findings

- [method] Students often differ a lot from their teacher's predictions, even when
  they have the capacity to match. Abstract ^f1
  > there often remains a surprisingly large discrepancy between the predictive distributions of the teacher and the student, even in cases when the student has the capacity to perfectly match the teacher.
- [method] Fidelity and generalisation are different things to measure. Section 1 ^f2
  > We will distinguish between fidelity, the ability of a student to match a teacher’s predictions, and generalization, the performance of a student in predicting unseen, in-distribution data.
- [method] When the teacher is an ensemble that is clearly better than the student,
  higher fidelity does mean better generalisation. Section 1 ^f3
  > However, when the teacher is a large model (e.g. a deep ensemble) improvements in fidelity translate into improvements in generalization
- [method] The main cause of low fidelity is optimisation, not too little data. Abstract ^f4
  > We identify difficulties in optimization as a key reason for why the student is unable to match the teacher.
- [method] [stats] In ensemble distillation the highest-fidelity student is always the
  best calibrated. Section 7 ^f5
  > Student fidelity is correlated with calibration when distilling ensembles: although the highest-fidelity student is not always the most accurate, it is always the best calibrated.
- [method] More distillation data helps the student identify the teacher's function but
  makes optimisation harder. Section 7 ^f6
  > Enlarging the distillation dataset beyond the teacher training data makes it easier for the student to identify the correct solution, but also makes an already difficult optimization problem harder.
- [method] (inferred) For us, report both: fidelity (student logit vs teacher logit,
  RMSE or R^2 on held-out drafts) and generalisation (log loss on held-out games), since
  the additive student is only "explaining the teacher" to the extent fidelity is high.
  The non-additive remainder (teacher minus student) is what the explanation leaves out. ^f7
- [method] (inferred) ^f4 is a deep-net problem: an additive student fitted by
  penalised least squares is convex, so its fidelity gap is pure capacity (what the
  teacher does that is not additive in our terms), which makes the gap meaningful. ^f8

## Read

- Abstract, section 1, section 3 metrics, section 7 discussion.

## Not read

- Sections 4-6 experiments in detail; appendix.
