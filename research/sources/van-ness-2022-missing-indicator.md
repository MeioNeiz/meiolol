---
title: 'Van Ness et al. 2022: The missing indicator method, from low to high dimensions'
url: https://arxiv.org/pdf/2211.09259
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: skimmed (abstract, 1, 3 theory statements, 4, 6, 7, conclusion)
relevance: high
grade: B/fair
description: Stanford (Udell) KDD 2023 paper; theory for the best linear predictor with mean imputation plus missing indicators, Selective MIM, experiments on synthetic, OpenML and MIMIC-III data with linear, MLP and XGBoost
---
# Van Ness et al. 2022: The missing indicator method, from low to high dimensions

Why: is mean imputation plus a missing indicator enough for a GLM-like model when the
missingness is informative (our pre-game mastery)?

## Assessment

- Evidence: B. KDD paper (Udell group); proofs for linear best predictors, 20 seeds per
  experiment, real missingness in MIMIC-III; results shown as bar charts, few numbers.
- Reasoning: fair. States where MIM hurts (high dimensions) and offers a fix.
- Interests: authors' own SMIM.
- Weigh: the linear theory is asymptotic; with few features (ten seats, one mastery each)
  we are in the low-dimensional case where they find no harm.

## Findings

- [method] MIM with mean imputation helps when missingness is informative and provably
  does not hurt linear models asymptotically when it is not. Abstract ^f1
  > we show empirically and theoretically that MIM improves performance for informative missing values, and we prove that MIM does not hurt linear models asymptotically for uninformative missing values.
- [method] [stats] Under self-masking, the best linear predictor's indicator coefficient
  encodes how the outcome differs when the feature is missing. Section 3 ^f2
  > the form of 𝜸𝑀𝐼
  > directly accounts for the informative missingness in each feature,
- [method] The risk: many uninformative indicators in high dimensions overfit; Selective
  MIM keeps only indicators whose missingness is related to Y. Abstract ^f3
  > for high-dimensional data sets with many uninformative indicators, MIM can induce model overfitting and thus test performance.
- [method] SMIM's test is simple: chi-squared of Y against each indicator (t-test for
  continuous Y), Benjamini-Hochberg at FDR 0.1. Section 4 ^f4
  > Specifically, for feature 𝑗, SMIM tests whether 𝑅 𝑗 and 𝑌 are
- [method] On MIMIC-III (17 variables, real missingness) MIM and SMIM improved logistic
  regression and MLP on all 3 tasks and harmed none. Section 6 ^f5
  > improve performance for logistic regression and MLP models on all 3 tasks
- [method] Recommendation: MIM as a standard preprocessing step for low-dimensional data
  when prediction is the goal. Section 6 ^f6
  > MIM should be a standard preprocessing tool for supervised learning on low-dimensional real-world data sets, should predictive performance be prioritized.
- [method/tabular] Tree models gain less from MIM than linear models and neural nets
  (trees already split on the imputed value). Section 7 ^f7
  > Tree-based models in general benefit less from MIM than linear models and neural networks, particularly when using mean imputation.
- [method] Mean imputation plus MIM is a cheap alternative to state-of-the-art imputers.
  Conclusion ^f8
  > We show that using MIM in conjunction with mean imputation is an effective and efficient alternative
- [method] Checked, not there: missingness that drifts over time or differs between
  training and deployment; numbers in text (gains are in figures only). ^f9

## Read

- Abstract, introduction, Theorem 3.2 discussion, SMIM (4), MIMIC (6), takeaways (7),
  conclusion.

## Not read

- Proofs (Appendix A), OpenML per-dataset figures, imputer comparisons (GC, MF).
