---
title: 'Tsang, Cheng, Liu 2018: Detecting statistical interactions from neural network weights (NID)'
url: https://arxiv.org/pdf/1705.04977
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-5.4)
relevance: medium
grade: B/fair
description: ICLR 2018 (USC); Neural Interaction Detection ranks interactions of any order from an MLP's first-layer weights times aggregated output weights; MLP-M adds univariate nets for mains; pairwise AUC 0.92 on 10 noise-free synthetic functions; confuses interlinked pairs with triples
---
# Tsang, Cheng, Liu 2018: Detecting statistical interactions from neural network weights (NID)

Why: can a trained draft net tell us which seat pairs or triples it uses, cheaply,
without testing every candidate.

## Assessment

- Evidence: B. ICLR 2018, widely cited, code public; tested on 10 synthetic functions
  (30k points, mostly noise-free, continuous features) and 4 real sets with no ground
  truth. Nothing near a coin-flip label.
- Reasoning: fair. Clear mechanism (interactions only form at shared hidden units),
  honest limitations; the averaging function was picked on the same test suite.
- Interests: authors' method.
- Weigh: trust the mechanism; the accuracy figures are for clean synthetic signals far
  stronger than ours. Needs an MLP over seat inputs; our set net pools within a team, so
  within-team seats are not separate first-layer inputs.

## Findings

- [method/interpret] Interactions in a feedforward net are created only at hidden units
  that share inputs; NID reads candidate interactions from first-layer weights times
  each hidden unit's aggregated outgoing weight. Abstract, Section 3 ^f1
  > interactions between input features are created by the non-additive effect of nonlinear activation functions, and that interacting paths are encoded in weight matrices.
- [method/interpret] Definition used: a set I interacts if f cannot be written as a sum
  of functions each missing one member; a d-way interaction implies all its (d-1)-way
  subsets interact. Section 3 ^f2
  > a d-way interaction can only exist if all its corresponding (d − 1)-interactions exist
- [method/interpret] A plain MLP models main effects as spurious interactions; MLP-M adds
  a small univariate net per feature, trained with L1 on the MLP part, to soak up mains.
  Section 4.1 ^f3
  > The univariate networks are intended to discourage the modeling of main effects away from the standard MLP, which can create spurious interactions using the main effects.
- [method/interpret] Cut-off: add the top-ranked interactions one by one as small nets in
  a GAM until validation performance plateaus. Section 4.3 ^f4
  > We gradually add top-ranked interactions to the GAM, increasing K, until GAM performance on a validation set plateaus.
- [method/interpret] Pairwise detection AUC averaged 0.92 for NID against 0.87 Additive
  Groves, 0.76 RuleFit, 0.72 ANOVA, 0.70 hierarchical lasso, on 10 synthetic functions.
  Table 2 ^f5
  > *Note: The high average AUC of NID, MLP is heavily influenced by F6 .
- [method/interpret] Limitation: interlinked pairs (x1x2 + x1x3 + x2x3) are often reported
  as one 3-way interaction; correlated features cause spurious or missed interactions.
  Section 5.4 ^f6
  > the interlinked pairwise interactions are often confused for single higher-order interactions.
  > it sometimes detects spurious interactions or misses interactions as a result of correlations between features
- [method/interpret] Checked, not there: no false discovery control or null distribution,
  no categorical or set inputs, no noisy binary outcome with effects near our size. ^f7
- [method/interpret] (inferred) For us NID is a cheap screen at most: rank seat pairs and
  triples from a big MLP over the 10 champion-role seats, then test each candidate as a
  shrunk term on held-out games; ^f6 says any "triple" it reports must be checked against
  the three pairs it contains before it is believed. ^f8

## Read

- Abstract, 1-5.4 (method, synthetic suite, pairwise and higher-order results,
  limitations).

## Not read

- Appendices (proofs, real-data heat maps, cut-off details).
