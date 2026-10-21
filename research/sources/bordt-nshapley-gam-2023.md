---
title: 'Bordt, von Luxburg 2023: From Shapley values to generalized additive models and back'
url: https://arxiv.org/pdf/2209.04012
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-8)
relevance: high
grade: A/strong
description: AISTATS 2023 (Tübingen); n-Shapley values, Shapley-Taylor and Faith-Shap of order n recover a GAM of order n exactly; every value function defines a functional decomposition (the Shapley-GAM); a degree-of-interaction measure; 3-way effects estimable with enough samples, 7-way only detectable
---
# Bordt, von Luxburg 2023: From Shapley values to generalized additive models and back

Why: can a trained draft net be turned back into readable main, pair and triple terms,
and what do Shapley interaction indices mean when it can.

## Assessment

- Evidence: A. AISTATS 2023, theorems with proofs, public package (nshap); von
  Luxburg is a recognised learning theorist. Experiments are small (low-dimensional
  tabular sets, a checkerboard), no accuracy benchmark.
- Reasoning: strong. States the condition (value function choice, independence for the
  observational one), shows where Shapley values lose information.
- Interests: none known; own package.
- Weigh: trust the theory; the estimation study is one synthetic function. Exact
  computation needs every subset, fine for our 10 seats (1,024 subsets).

## Findings

- [method/interpret] n-Shapley values give attributions to every group of up to n
  features; order 1 is plain Shapley, order 2 Shapley interaction values, order d the
  full decomposition. Abstract ^f1
  > n-Shapley Values, a parametric family of local post-hoc explanation algorithms that explain individual predictions with interaction terms up to order n.
- [method/interpret] Recovery: if the model is a GAM of order n, n-Shapley, Shapley-Taylor
  and Faith-Shap of order n all equal its component functions, under interventional SHAP
  (any dependence) or observational SHAP with independent features. Section 6, Theorem 8 ^f2
  > n-Shapley Values, as well as the Shapley Taylor- and Faith-Shap interaction indices of order n, recover a representation of f as a GAM.
- [method/interpret] With the observational value function the independence assumption
  is needed; interventional works without it. Section 6 ^f3
  > the independence assumption in part (a) of Theorem 8 is indeed necessary
- [method/interpret] Plain Shapley values spread every higher-order term evenly over its
  members, so one cannot tell mains from interactions, and a feature in several
  opposite-sign interactions can score zero. Section 5.1 ^f4
  > it is impossible to tell from individual Shapley Values whether the model consists of main effects or complex variable interactions.
  > a feature can have zero attribution although it appears in multiple interaction effects with different signs.
- [method/interpret] Every subset-compliant value function defines a unique functional
  decomposition of any model (the Shapley-GAM), and back; the decomposition depends on
  the value function chosen. Section 5.2 ^f5
  > Taken together, Theorem 4 and Theorem 7 establish a bijection between subset-compliant value functions and functional decompositions of f .
- [method/interpret] Degree of interaction of a model: mean over data of the
  |component|-weighted interaction order; models of similar accuracy differ widely (kNN
  very high, GAM 1). Section 7 ^f6
  > We suggest to measure the extent of variable interaction that is present in a given classifier with the following quantity
  > there is a large amount of variation in between the different classifier.
- [stats] Estimation: with too few samples for the effect size, a high-order effect shows
  up as spurious lower-order effects; a 3-way checkerboard was estimated precisely with
  enough samples, a 7-way only detected. Section 8, Figure 4 ^f7
  > if the number of samples is small in relation to the magnitude of the interaction effect, then the estimation results in spurious lower-order effects.
  > For k = 7, the presence of the higher-order interaction effect can be reliably detected, but not precisely estimated given reasonably many samples.
- [method/interpret] Exact computation evaluates the value function on every subset;
  package nshap computes n-Shapley, Shapley-Taylor and Faith-Shap. Section 8 ^f8
  > we take the trivial approach and simply evaluate the value function for all possible subsets S ⊂ [d]
- [method/interpret] (inferred) For us d = 10 seats: 1,024 value-function calls per
  draft, each a batch of the set net over background drafts with the other seats
  swapped in, so the exact Shapley-GAM of our net (every main, 45 pairs, 120 triples
  per draft) is a few GPU seconds per thousand drafts. Averaging |component| by order
  gives how much of the net's lean is mains, pairs and triples (^f6), the direct test
  of whether 3-way terms exist in what the net learnt. Swapping in seats from other
  drafts makes impossible drafts (duplicate champions, off-role picks), the
  extrapolation problem of [[hooker-2021-permutation-extrapolation]]; restrict the
  background to drafts where the swapped champion is legal (no duplicate, same role). ^f9
- [method/interpret] Checked, not there: no uncertainty of components across model
  seeds or data resamples, no false discovery control, no categorical inputs. ^f10

## Read

- Abstract, 1-8 in full; Figure 4.

## Not read

- Appendix (proofs, checkerboard figures for every order k, plotting method).
