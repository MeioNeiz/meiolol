---
title: 'Chen, Dobriban, Lee 2020: A Group-Theoretic Framework for Data Augmentation'
url: https://arxiv.org/abs/1907.10905
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 1 contributions, 4.1 lemma)
relevance: medium
grade: A/strong
description: JMLR 2020 (Wharton) theory of data augmentation as averaging over a symmetry group's orbits: variance reduction under exact invariance, bias under approximate invariance, constrained models can beat augmentation
---
# Chen, Dobriban, Lee 2020: A Group-Theoretic Framework for Data Augmentation

Why: whether team-swap (mirror the game, flip side and label) and role-order
augmentation help a win model, versus building the symmetry into the model.

## Assessment

- Evidence: A. JMLR 2020, well cited, by statisticians (Dobriban); proofs plus worked
  examples.
- Reasoning: strong. States conditions, the bias under approximate invariance, and
  when augmentation is worse than constraining the model.
- Interests: none known.
- Weigh: theory; no LoL data. Trust the conditions: exact vs approximate symmetry.

## Findings

- [method] [stats] Augmentation is averaging over the orbits of a symmetry group that
  keeps the data distribution (approximately) invariant, and it reduces variance.
  Abstract ^f1
  > We show data augmentation is equivalent to an averaging operation over the orbits of a certain group that keeps the data distribution approximately invariant. We prove that it leads to variance reduction.
- [method] Gains are largest with limited data. Section 1 ^f2
  > Data augmentation leads to increased performance, especially with limited data.
- [method] [stats] Under only approximate invariance, augmentation adds bias as it
  cuts variance, so it may not help; the trade-off depends on the distance between
  the data and its transformed copy. Section 1, item 6 ^f3
  > while the orbit averaging operation reduces variance, a certain level of bias is created because of the non-exact-invariance.
  > This tradeoff suggests that in practice where exact invariance does not hold, data augmentation may not always be beneficial
- [method] [stats] Augmented maximum likelihood cannot always match a model where the
  invariance is built in by constraint. Section 1, item 4 ^f4
  > As a result, the augmented MLE cannot always be as efficient as the “constrained MLE”, where the invariance is achieved by constrained optimization.
- [method] (inferred) Team swap with the side flag flipped is an exact symmetry; a
  model of the form f(blue) - f(red) + side term already has it built in, so
  augmentation adds nothing there. It helps for models that don't (a raw MLP over 10
  slots). Swapping without flipping side is approximate (side win rate differs) and
  adds bias (f3). ^f5

## Read

- Abstract, 1 (contributions), 4.1 opening

## Not read

- 4.2-7 proofs, examples, approximate-invariance theory in detail
