---
title: 'Zaheer et al. 2017: Deep Sets'
url: https://arxiv.org/abs/1703.06114
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, sections 1-3, 4.1.2)
relevance: medium
grade: A/fair
description: NeurIPS 2017 paper (CMU, Smola, Salakhutdinov) proving permutation-invariant set functions decompose as rho(sum phi(x)), and the DeepSets architecture built on it
---
# Zaheer et al. 2017: Deep Sets

Why: a team of five champions is a set (order within a team is arbitrary once role is
part of the element); what the canonical architecture for set inputs is and what it
costs.

## Assessment

- Evidence: A. Canonical set-learning paper, NeurIPS 2017, very widely cited and
  used as the baseline in later set work.
- Reasoning: fair. Clean theorem; experiments are varied but not about noisy tabular
  labels or data-size curves.
- Interests: authors' own method.
- Weigh: trust the structural result; it says nothing about sample efficiency on a
  binary noisy label like ours.

## Findings

- [method] Any permutation-invariant function of a set from a countable universe
  (e.g. champions) can be written as rho(sum of phi(x)): embed each element, sum,
  then apply a network. Theorem 2 ^f1
  > is a valid set function, i.e., invariant to the permutation of instances in X, iff it can be decomposed in the form
- [method] DeepSets architecture: transform each element independently, add the
  representations, then process the sum with a normal network; optional conditioning
  on extra information. Section 3 ^f2
  > The representations φ(xm ) are added up and the output is processed using the ρ network in the same manner as in any deep network
- [method] Treating a set as a sequence (LSTM, GRU) generalised worse than DeepSets
  with similar parameter counts; trained on 100k sets. Section 4.1.2 ^f3
  > Training is done on tasks of length 10 at most, while at test time we use examples of length up to 100. The accuracy, i.e. exact equality after rounding, is shown in Fig. 2. DeepSets generalize much better.
- [method] (inferred) A logistic model on summed champion one-hots is already a
  DeepSets with linear phi and rho; the gain from a deep version comes only from the
  non-linear rho, i.e. learning team-level composition effects (damage mix, frontline)
  from the summed embedding. ^f4

## Read

- Abstract, 1, 2 (Theorem 2, equivariance), 3 architecture, 4.1.2 sum of digits

## Not read

- Point clouds, set expansion, anomaly detection experiments; appendix proofs
