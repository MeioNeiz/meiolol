---
title: 'Lundstrom, Razaviyayn 2023: Distributing synergy functions: unifying game-theoretic interaction methods for machine-learning explainability'
url: https://arxiv.org/pdf/2305.03100.pdf
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (abstract, 3.2-3.4, 4, 6)
relevance: medium
grade: B/fair
description: arXiv 2023 (Lundstrom, Razaviyayn); the synergy function is the Möbius transform against a baseline, extended to continuous inputs, and each attribution or order-k interaction method is characterised by how it hands a synergy larger than k down to smaller groups: Shapley equally to members, Shapley-Taylor equally to the size-k subsets, recursive Shapley to all subgroups; no best method
---
# Lundstrom, Razaviyayn 2023: Distributing synergy functions

Why: only the part that says how each index distributes a Möbius synergy of order
above k.

## Assessment

- Evidence: B. arXiv v3 (May 2023), theory paper with proofs; the binary-feature
  rules restate known results (Harsanyi, Grabisch, Sundararajan). No experiments.
- Reasoning: fair. Clear rules per method and an honest "no best method" conclusion;
  Faith-Shap and k-SII get no distribution rule; main weight is on gradient methods.
- Interests: none known; proposes its own gradient method (Sum of Powers).
- Weigh: trust the distribution rules for Shapley and Shapley-Taylor; for Faith-Shap
  use the closed form in [[tsai-faithshap-2023#^f7]].

## Findings

- [method/interpret] The synergy function is the Möbius transform of the model over
  "feature at its value or at the baseline", the continuous-input form of the Harsanyi
  dividend; methods are told apart by how they distribute synergies. Abstract,
  Section 3.2 ^f1
  > We identify how various methods are characterized by their policy of distributing synergies.
  > The primary precursor to the synergy function is the Harsanyi dividend [Har63], which is like the Möbius transform and is formulated for discrete-input settings.
- [method/interpret] Shapley value: each synergy of a set goes in equal parts to its
  members. Section 4, eq. 7 ^f2
  > This means the Shapley value distributes the function gain from ΦS equally among all i ∈ S.
- [method/interpret] Shapley-Taylor of order k: a synergy of size up to k stays on its
  own set; a larger one is split equally over all its size-k subsets, nothing to
  smaller ones ("top-distributing"). Section 4, eq. 9 ^f3
  > The Shapley-Taylor distributes each synergy function of S to its group, unless is too large (|S| > k), in which case it distributes the synergy equally among all subsets of S of size k.
  > This results in Shapley-Taylor emphasising interactions between features of size k, which may be an advantage or disadvantage, depending on the goal of the interaction.
- [method/interpret] Recursive Shapley (Shapley of Shapley, the binary analogue of
  integrated Hessians) spreads a synergy over all its subgroups, also when the synergy
  is small enough to be reported itself, so a pure triple shows up as pairs. Section 4,
  eq. 10 ^f4
  > This formulation, however, has the disadvantage of distributing a portion of synergy functions for groups sized ≤ k to subgroups.
  > recursively Shapley reports that a synergy function Φ{1,2,3} (x) also has interactions for subgroup {1, 2}.
- [method/interpret] The whole construction rests on a baseline that means "feature
  absent"; where a model has none, baseline game-theoretic interactions may not fit.
  Section 3.2 ^f5
  > The critical observation is that a feature being at its baseline value indicates the feature is not present.
  > in which case game-theoretic baseline attributions and interactions may be ill-suited as explanation tools.
- [method/interpret] No best method: top-distributing suits a search for strong
  interactions of exactly size k, spreading suits a reading of all orders up to k.
  Section 6 ^f6
  > top-distributed methods may be preferable when explicitly searching for strong interactions of size k, while an iterative approach may be preferable when seeking to emphasizing all interactions up to size k.
  > In the authors’ opinion, the possibility of the existence of one “best” method is improbable
- [method/interpret] Checked, not there: no distribution rule for Faith-Shap, k-SII /
  n-Shapley or the Banzhaf family (Faith-Shap is only said to equal the Möbius
  transform at k = n); no marginal or conditional value function, baseline only; no
  experiments. ^f7

## Read

- Abstract, 3.2-3.4, 4, 6.

## Not read

- 2 (axiom list), 5 (gradient methods, integrated Hessians, Sum of Powers), appendices.
