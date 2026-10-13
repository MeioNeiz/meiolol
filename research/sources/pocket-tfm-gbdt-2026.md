---
title: 'Tanna et al. 2026: Pocket foundation models, distilling TFMs into CPU-ready gradient-boosted trees'
url: https://arxiv.org/pdf/2605.18654
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: skimmed (abstract, 1, 3, 4.2)
relevance: medium
grade: C/fair
description: Lexsi Labs arXiv preprint (May 2026); distils tabular foundation models into XGBoost or CatBoost students with out-of-fold teacher labels on 153 classification datasets; AUC retention, speedups, when distillation fails
---
# Tanna et al. 2026: Pocket foundation models, distilling TFMs into CPU-ready gradient-boosted trees

Why: recent, large-benchmark numbers on GPU teacher to CPU GBDT student: accuracy kept,
and the out-of-fold labelling rule.

## Assessment

- Evidence: C. Preprint, vendor lab (their TabTune library), single seed, but 153
  datasets with a Wilcoxon test. Median dataset only 3,196 rows.
- Reasoning: fair. Reports where distillation fails and why; the per-sample
  temperature and weighting scheme is ad hoc.
- Interests: Lexsi Labs promotes TabTune; teachers are others' TFMs.
- Weigh: trust the OOF rule (it matches [[ba-caruana-deep-2014#^f5]]) and the
  "no better teacher, no gain" pattern; discount exact AUC figures.

## Findings

- [method] [stats] TabICLv2 teacher distilled into XGBoost kept 96.5% of teacher AUC
  (0.882 macro mean) at 1.9 ms on CPU, 38x to 860x faster. Abstract ^f1
  > distilling TabICLv2 into XGBoost gives 0.882 macro-mean AUC (96.5% of teacher AUC) at 1.9 ms on CPU
- [method] Teacher labels must be out-of-fold: a teacher scoring its own training rows
  gives near one-hot targets, and the student then does worse than on hard labels.
  Section 1 ^f2
  > It is simple but critical: skip it and ICL distillation produces students that are worse than hard-label training.
- [method] K in {3, 5, 10} folds made no difference to student AUC. Section 3 ^f3
  > K ∈ {3, 5, 10} produced indistinguishable downstream AUC on a held-out probe of 20 datasets.
- [method] Averaging several teachers helps MLP students but adds under 0.001 AUC for
  tree students. Abstract ^f4
  > multi-teacher averaging helps MLP students (+0.006, p=0.003) but adds less than 0.001 for tree students
- [method] Where the teacher is worse than a tuned GBDT, distillation makes the student
  worse still. Abstract ^f5
  > on high-dimensional tasks where the teacher itself trails CatBoost, distillation makes things worse rather than better.
- [method] Student gains over CatBoost are small on average (+0.011 AUC with 21 features
  or fewer, +0.001 above). Section 4.2 ^f6
  > On high-dimensional tasks, distillation is effectively a coin flip against a well-tuned CatBoost, and a slower one at that.
- [method] (inferred) For us OOF means: each seed net in the teacher ensemble is trained
  on k-1 folds and labels the held-out fold, so every real game gets a teacher logit
  from nets that never saw its result. Our nets are not in-context learners, but they
  do memorise at 230k games, so the same rule applies, more weakly. ^f7
- [method] (inferred) ^f5 is the go/no-go test: distil only if the teacher ensemble
  beats a well-shrunk additive model fitted to labels on held-out log loss in `meiolol
  eval`; otherwise the student inherits the teacher's errors. ^f8

## Read

- Abstract, section 1, section 3 (OOF, Algorithm 1), section 4.2.

## Not read

- Section 4.3-5 teacher selection and student families; appendix.
