---
title: 'Janzing, Minorics, Bloebaum 2020: Feature relevance quantification in explainable AI: a causal problem'
url: https://arxiv.org/pdf/1910.13413
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-3, conclusion; experiments skimmed)
relevance: medium
grade: B/strong
description: AISTATS 2020 (arXiv 1910.13413 v2, Amazon Tübingen); argues SHAP should drop features by interventional (marginal) expectations, because the model's inputs cause its output; observational conditionals credit features the model ignores
---
# Janzing, Minorics, Bloebaum 2020: Feature relevance quantification in explainable AI: a causal problem

Why: the case for interventional (marginal) SHAP, the opposite side of
[[chen-2020-true-to-model]] and [[covert-2020-sage]]'s conditional default.

## Assessment

- Evidence: B. AISTATS 2020, causality group (Janzing, Schölkopf circle); argument by
  causal reasoning and small examples; experiments on linear models (Gaussian n=3 and
  n=10, one UCI dataset) with known attribution.
- Reasoning: strong within its scope. Explicit that the causality meant is that of the
  algorithm's inputs, not the real world.
- Interests: none; disagrees with the SHAP paper's theory.
- Weigh: right for "what does this model use"; silent on extrapolation (marginal
  sampling evaluates impossible rows, [[hooker-2021-permutation-extrapolation]],
  [[kumar-2020-shapley-problems#^f1]]). Not about global importance or intervals.

## Findings

- [method] Claim: dropping a feature should average it over its unconditional
  (marginal) distribution, not the conditional; SHAP's practical approximation is
  therefore the right quantity and "improving" it towards conditionals is a mistake.
  Abstract ^f1
  > We conclude that unconditional rather than conditional expectations provide the right notion of dropping features in contradiction to the theoretical justification of the software package SHAP.
- [method] The causality is that of the algorithm: the inputs cause the output; real
  world causal relations between features are explicitly out of scope. Section 3 ^f2
  > we consider the inputs of an algorithm as causes of the output
  > we are not talking about the causal relation between any features in the real world outside the computer
- [method] With f(x1, x2) = x1 and x1, x2 perfectly dependent, conditional Shapley gives
  the unused x2 non-zero credit (fails Sensitivity); interventional gives zero.
  Section 3, Example 1 and Lemma 1 ^f3
  > Obviously, the feature X2 is irrelevant.
- [method] SHAP's tree explainer was changed to the interventional form after this
  work. Section 3, footnote 3 ^f4
  > Note that TreeExplainer in SHAP has meanwhile been changed accordingly.
- [method] (inferred) For us: interventional SHAP answers "which inputs does this GBDT
  read", a model-audit question. "How much does gold lead matter to winning" is a
  question about games, where Janzing's argument does not apply and the off-manifold
  rows it needs (gold +5k with towers -3 at minute 12) are exactly the extrapolation
  problem. Use interventional TreeSHAP only for debugging the model, summed by group. ^f5

## Read

- Sections 1-3 and the conclusion; Section 4 experiments skimmed.

## Not read

- Section 4 details (kernel conditional estimator, SHAPR comparison histograms).
