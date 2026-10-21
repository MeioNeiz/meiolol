---
title: 'Tsang, Rambhatla, Liu 2020: How does this interaction affect me? Interpretable attribution for feature interactions (Archipelago)'
url: https://arxiv.org/pdf/2006.10965
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-4.2, results skimmed)
relevance: medium
grade: B/fair
description: NeurIPS 2020 (USC); ArchDetect finds pairs per instance by a discrete mixed second difference (target vs baseline value of each feature) in O(p^2) model calls, merges overlapping pairs into disjoint sets; ArchAttribute scores a set as f(target set on baseline) - f(baseline); argues non-additivity (STI, IH) is not an attribution
---
# Tsang, Rambhatla, Liu 2020: Archipelago

Why: per-draft explanation of which seat pairs a trained net uses, with a cheap
model-agnostic test that works on categorical swaps.

## Assessment

- Evidence: B. NeurIPS 2020; code public; evaluated on synthetic functions built for its
  own contexts, and on human annotation labels (sentiment, images). No noisy tabular
  outcome, no false discovery control.
- Reasoning: fair. Clear axioms and assumptions (disjoint sets, no mixed higher-order
  target-baseline interactions); the synthetic comparison is tailored to its contexts.
- Interests: authors' method against STI, IH, NID (their own earlier method).
- Weigh: the discrete second difference is the useful idea; the "baselines fail"
  table is on functions designed to show it.

## Findings

- [method/interpret] Separates two things other indices mix: whether features interact
  (non-additivity) and what the interaction contributes to the prediction. Section 1 ^f1
  > One of the core issues is that an interaction’s importance is not the same as its attribution.
- [method/interpret] ArchAttribute: a set's attribution is the model with that set at the
  instance's values and everything else at a neutral baseline, minus the model at the
  baseline. Section 3.1 ^f2
  > φ(I) = f (x?I + x0\I ) − f (x0 ).
- [method/interpret] ArchDetect: a pair interacts if the four-corner second difference
  (both at target, each alone, both at baseline) is non-zero; with two values per feature
  any deviation from additivity shows as a non-zero corner sum. Section 4.1 ^f3
  > a non-zero value of (3) identifies a non-additive interaction by the definition of statistical interaction
- [method/interpret] Contexts used: the rest of the features at the instance and at the
  baseline, averaged; interactions needing a mix of more than 3 target and baseline
  features are assumed away. Section 4.2.1 ^f4
  > The remaining interactions specifically require a mix of > 3 target and baseline features. This case is unlikely and is excluded
- [method/interpret] Higher order: overlapping detected pairs are merged into disjoint
  sets, using that a k-way interaction implies all its pairs interact; O(p^2) calls.
  Section 4.2.2 ^f5
  > ArchDetect looks at the union of overlapping pairwise interactions to obtain disjoint feature sets.
- [method/interpret] On its four synthetic functions other detectors (ANOVA, IH, NID,
  Shapley interaction index, Shapley-Taylor) scored near 0.5 AUC on three where the
  interaction holds only in the chosen contexts; ArchDetect 1.0. Section 4, table (b) ^f6
  > The baseline methods fail to detect interactions suited for the desired contexts in §4.2.1.
- [method/interpret] Checked, not there: no uncertainty, null or false discovery rate; no
  noisy label; per-instance only, no global pair table. ^f7
- [method/interpret] (inferred) For a draft, "target vs baseline" is "this champion vs a
  typical one in the role": the four-corner swap (both picks, either replaced, both
  replaced) on the net's logit is exactly a per-draft synergy or counter estimate, and
  averaging it over many real drafts with the same pair gives a global pair table from
  any black box. The baseline champion choice changes the answer (as the weight does in
  [[lengerich-2020-purification#^f6]]); averaging over replacement champions drawn by
  role pick rate is the interventional (Shapley-GAM) version of it
  ([[bordt-nshapley-gam-2023#^f5]]). ^f8

## Read

- Abstract, 1, 3.1, 4.1-4.2, synthetic results table, recommendation example.

## Not read

- 5.2-5.4 in detail (sentiment and image evaluations), appendices.
