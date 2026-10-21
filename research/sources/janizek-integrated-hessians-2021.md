---
title: 'Janizek, Sturmfels, Lee 2021: Explaining explanations: axiomatic feature interactions for deep networks (Integrated Hessians)'
url: https://arxiv.org/pdf/2002.04138
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-5.2)
relevance: medium
grade: B/fair
description: JMLR 2021 (UW, Su-In Lee lab); Integrated Hessians, integrated gradients applied to itself, gives pairwise interaction values that sum to f(x) - f(baseline); ReLU nets have zero Hessians so it swaps in SoftPlus at explanation time; scales to many features on GPU; tested on clean synthetic data
---
# Janizek, Sturmfels, Lee 2021: Integrated Hessians

Why: a gradient-based pair attribution for a trained net that sums to the prediction,
and whether it suits embedding inputs like our champion seats.

## Assessment

- Evidence: B. JMLR 2021, Su-In Lee lab (SHAP co-authors' group), code public; synthetic
  benchmarks (5-10 Gaussian features, a net with 0.99 correlation to the label) plus
  sanity checks; no noisy outcome.
- Reasoning: fair. Axioms stated and proved; the ReLU problem is a real, useful catch.
- Interests: authors' method.
- Weigh: needs continuous inputs and a path to a baseline; for one-hot or embedding
  seats the path runs through non-existent "half champions", so attributions answer a
  question about the net's interior, not about swapping champions.

## Findings

- [method/interpret] Pair values Gamma_ij satisfy interaction completeness: they sum to
  the model output at x minus at the baseline, so their scale is in output units.
  Section 2 ^f1
  > the sum of the Γi,j (x) terms adds up to the difference between the output of f at x and at the baseline x0 .
- [method/interpret] The self term is feature i's main effect after its interactions are
  taken away. Section 2 ^f2
  > it is the main effect of feature i after interactions with all other features have been subtracted away.
- [method/interpret] ReLU networks are piecewise linear with zero second derivatives, so
  Hessian-based interaction methods find nothing; replace ReLU with SoftPlus at
  explanation time, no retraining. Section 3 ^f3
  > Previous second-order approaches (based on the Hessian) fail to detect any interaction in ReLU-based networks.
  > We note that no re-training is necessary for this approach.
- [method/interpret] Cost: other methods need at least O(d^2) forward passes; Hessians
  back-propagate in parallel on a GPU, so it scales better at many features; a
  Monte Carlo Shapley interaction index could not finish at 500 features. Section 5.1 ^f4
  > other methods require at least O(d2 ) separate forward passes of the model to compute the interactions
- [method/interpret] On simulated pair interactions (10 Gaussian features) it found the
  largest interactions faster than Shapley interaction (sampled), contextual
  decomposition, NID and the input Hessian under remove-and-retrain, and passed
  model and data randomisation sanity checks. Section 5.2 ^f5
  > our method outperforms all existing methods on all interaction types.
  > our method passed both sanity checks
- [method/interpret] Checked, not there: categorical inputs, uncertainty or a null, a
  global (data-level) pair table rather than per-sample values. ^f6
- [method/interpret] (inferred) For us d is 10 seats, so O(d^2) forward passes is 45
  swaps per draft and costs nothing; the GPU advantage does not apply and the
  discrete-swap methods ([[tsang-archipelago-2020#^f3]], [[bordt-nshapley-gam-2023#^f9]])
  answer the question we care about (this champion instead of another). Use IH only
  on continuous profile inputs (damage share, tankiness) of the set net. ^f7

## Read

- Abstract, 1-3, 5.1-5.2.

## Not read

- 6 (applications: NLP, drug combinations), appendices (axiom proofs, other benchmarks).
