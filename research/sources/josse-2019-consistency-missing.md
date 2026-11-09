---
title: 'Josse et al. 2019/2024: On the consistency of supervised learning with missing values'
url: https://arxiv.org/pdf/1902.06931
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: skimmed (abstract, 1, 3 pattern decomposition, 4 remarks, 5 setup, 6)
relevance: high
grade: A/strong
description: Josse, Chen, Prost, Varoquaux, Scornet (INRIA; arXiv v5 2024, Statistical Papers); Bayes consistency of imputation for prediction, the 2^d pattern-submodel view, missing indicators, and trees (MIA)
---
# Josse et al. 2019/2024: On the consistency of supervised learning with missing values

Why: the canonical prediction-side treatment of missing features; what is consistent when
mastery is missing in training and at prediction, and when must the mask be a feature?

## Assessment

- Evidence: A. Widely cited reference on missing values in supervised learning (Josse,
  Varoquaux, Scornet), five arXiv versions to 2024, proofs plus simulations.
- Reasoning: strong. Separates inference from prediction, states assumptions (MAR,
  asymptotic, universally consistent learner) and where results fail (linear models).
- Interests: none.
- Weigh: the constant-imputation result needs a flexible learner; for our GLM-like model
  the linear caveat (^f4) matters more than the headline.

## Findings

- [method] [stats] Prediction with missing values is a mixture of 2^d pattern submodels,
  one per missingness pattern, which grows exponentially. Section 3 ^f1
  > which grows exponentially with the number of variables.
- [method] Constant imputation before learning is consistent when missing values are not
  informative, unlike in inference where mean imputation is frowned on. Abstract ^f2
  > A striking result is that the widely-used method of imputing with a constant prior to learning is consistent when missing values are not informative.
- [method] Train and test must use the same imputation model; constant imputation is
  consistent only with a powerful non-linear learner. Section 6 ^f3
  > To train and test on data with missing values, the same imputation model should be used. Constant imputation is consistent, if used in conjunction with a powerful, non-linear learning model
- [method] For a linear model the pattern submodels are not linear in general, so one
  linear model on imputed data does not reach the Bayes loss. Section 4 ^f4
  > One can show that the 2d submodels are not linear in general and consequently, using a single linear model on imputed data does not yield the Bayes loss
- [method] When missingness is related to the target, imputation does not suffice: add
  the missingness indicators as features. Section 6 ^f5
  > When missingness is related to the prediction target, imputation does not suffice and it is useful to add the missingness indicators as features
- [method] [stats] Patterns that differ between training and test are a distribution
  shift needing dedicated methods. Remark 1 ^f6
  > If this is not the case, we are in presence of a distributional shift, which should be tackled with dedicated methods
- [method/tabular] In trees, Missing Incorporated in Attribute (MIA) is the most
  versatile, handling informative and non-informative missingness. Section 6 ^f7
  > Missing Incorporated in Attribute (MIA, Twala et al. 2008, see Remark 2 in Appendix B.3), which works by optimizing jointly the split and the handling of the missing values is the most versatile
- [method] (inferred) For us: mastery coverage rising from 1 in 15 to 1 in 3 full games is
  exactly the train/test pattern shift of ^f6, so a per-seat indicator alone learns an
  old-data mix; the indicator effect should be allowed to vary with time or region, or
  scored on recent games only. ^f8

## Read

- Abstract, introduction, Section 3 (pattern decomposition, Remark 1), Section 4 linear
  caveat, simulation missingness designs, Section 6.

## Not read

- Proofs, Appendix B (trees, MIA analysis), simulation figures in detail.
