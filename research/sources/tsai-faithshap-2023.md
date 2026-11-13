---
title: 'Tsai, Yeh, Ravikumar 2023: Faith-Shap: the faithful Shapley interaction index'
url: https://arxiv.org/pdf/2203.00870.pdf
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (abstract, 1-6, 7 skimmed, 8-10)
relevance: high
grade: A/strong
description: JMLR 2023 (CMU); Faith-Shap is the order-l weighted least-squares fit of the coalition game under the Shapley kernel, exact at the empty and full coalition, the only such fit with linearity, symmetry, dummy and efficiency; closed form in Möbius terms; contrasts with Shapley interaction (not efficient) and Shapley-Taylor (lower orders read at the empty set, all higher mass on the top order)
---
# Tsai, Yeh, Ravikumar 2023: Faith-Shap: the faithful Shapley interaction index

Why: with every coalition of a 10-seat draft computable, which order-2 index should be
the reported pair effect, and what does each index do with triple and higher mass.

## Assessment

- Evidence: A. JMLR 2023 (arXiv v3 read), CMU (Ravikumar); theorems with proofs,
  closed form checked against Grabisch's earlier Banzhaf results; the index is in
  shapiq and nshap. Experiments are thin: two symmetric toy games, 50 IMDB sentences,
  one tabular set, all about estimation cost, none measuring fit on a real model.
- Reasoning: strong. States each rival's axioms and what they cost, gives the weights
  that follow from each axiom; the toy games are chosen to favour the method.
- Interests: authors' own index, compared against rivals.
- Weigh: trust the definitions, uniqueness and closed form. "More intuitive" rests on
  toy games where the target is near an order-2 function. k-SII / n-Shapley came later
  and is not compared; no word on the value function or on noisy games.

## Findings

- [method/interpret] The four Shapley axioms (linearity, symmetry, dummy, efficiency),
  extended to interactions, do not pin down one index above order 1; every index adds
  something. Abstract, Section 3 ^f1
  > the natural set of axioms for the original Shapley values, extended to the context of interactions, no longer specify a unique interaction index.
- [method/interpret] Shapley interaction index (Grabisch, Roubens; unique by a
  recursive axiom): not efficient, since the singleton Shapley values already sum to
  the whole prediction, and blind to the chosen top order. Section 3, 5 ^f2
  > A critical caveat of the resulting Shapley interaction value is that it no longer satisfies the interaction efficiency axiom
  > simply summing the contributions to singleton sets (i.e. the classical individual attribution Shapley values) is already equal to v([d]) − v(Ø)
  > they are not cognizant of the maximum interaction order, and hence we cannot compute Shapley values that differ with varying maximum interaction orders.
- [method/interpret] Shapley-Taylor (efficient, unique by the interaction distribution
  axiom): every term below the top order is the discrete derivative at the empty
  coalition (the Möbius term), and all mass above the top order goes to top-order
  terms. Section 3 eq. 7, Section 5 ^f3
  > distributing higher-order interactions to the topmost interaction indices at the expense of impoverished lower-order interactions.
  > This impoverishes lower-order interactions, which in turn hurts the meaningfulness of both lower and highest-order interactions
- [method/interpret] Faith-interaction indices: the order-l terms that minimise a
  weighted squared error between v(S) and the sum of terms inside S, over all
  coalitions S. Symmetry holds only if the weight depends on coalition size alone.
  Section 4, eq. 9, Proposition 14 ^f4
  > Faith-Interaction indices E satisfy the interaction symmetry axiom if and only if the weighting functions are permutation invariant
  > the overall set of interaction indices optimally approximates the behavior of the underlying value function.
- [method/interpret] Faith-Shap: the one faith index with linearity, symmetry, dummy
  and efficiency. Its weights are the Shapley kernel on coalition size, infinite at the
  empty and full coalition, so the fit is exact there and least squares elsewhere;
  order 1 is the Shapley value (Kernel SHAP). Theorem 19, Proposition 18, Section 9 ^f5
  > There is a unique Faith-Interaction index that satisfies the interaction linearity, symmetry, dummy, and efficiency axioms
  > Faith-Interaction indices satisfy the interaction efficiency axiom if and only if the weighting functions satisfy µ(Ø) = µ([d]) = ∞.
  > Kernel SHAP [28] can be viewed as first-order Faith-Shap.
- [method/interpret] Faith-Banzhaf: uniform weight on all coalitions, the plain best
  squared-error order-l polynomial of the game; generalised 2-efficiency in place of
  efficiency, so terms need not sum to the prediction and the empty-set term is a free
  intercept (−0.24 in the toy game where v(Ø) = 0); top-order terms equal the Banzhaf
  interaction index. Theorem 17, Section 7.2.3, Table 2 ^f6
  > there is a unique Faith-Interaction index that satisfies the interaction linearity, symmetry, dummy, and generalized 2-efficiency axioms
  > Faith-Banzhaf interaction indices can in turn be related to such a function approximation
- [method/interpret] Closed form (eq. 16): a Faith-Shap term is the set's own Möbius
  term plus a signed, size-weighted sum of the Möbius terms of every superset larger
  than l. So Faith-Shap is a fixed linear map of the exact Möbius terms. Theorem 19 ^f7
  > where a(v, ·) is the Möbius transform of v(·). Moreover, its highest-order interaction terms can be expressed as a weighted average of discrete derivatives
- [method/interpret] (inferred) From eq. 16 at l = 2, checked by solving the weighted
  fit for d = 10: a lone triple Möbius term a puts +a/2 on each of its 3 pairs and
  −a/6 on each of its 3 mains; a lone 4-way term +0.3a on each of 6 pairs and −0.2a on
  each of 4 mains. Faith-Banzhaf: triple +a/2 per pair, −a/4 per main, +a/8 on the
  intercept. Shapley-Taylor: a/3 (triple) or a/6 (4-way) per pair, mains untouched.
  2-SII (our arithmetic from the n-Shapley recursion, not quoted): triple +a/2 and
  −a/6, same as Faith-Shap; 4-way +a/3 and −a/4. With no Möbius term above order l
  all of them equal the Möbius terms ([[bordt-nshapley-gam-2023#^f2]]). So an order-2
  index differs from the Möbius pair term by exactly the triple-and-higher mass, and
  every index but Shapley-Taylor also moves mains the opposite way. ^f8
- [method/interpret] The top-order Faith-Shap term is a probability-weighted average
  of the set's discrete derivative over every context of other players (a
  Beta(l, l) weight on the share present; the Shapley interaction index uses a uniform
  one). Section 7, Propositions 21, 22 ^f9
  > the top level of the Faithful Shapley Interaction index captures the interactions of features in S in the presence of all subsets T ⊆ [d]\S.
- [method/interpret] Toy game (11 players, each adds 1, each pair loses p, nothing
  alone): at order 2 Faith-Shap gives mains 0.95 and pairs −0.091 (p = 0.1);
  Shapley-Taylor gives mains 0 and pairs +0.1, the wrong sign, and all zeros at
  p = 0.2; the Shapley interaction index gives mains 0.5 and pairs 0. Section 5.1,
  Table 2 ^f10
  > our Faith-Shap accurately captures individual contribution and pairwise interaction effects by assigning 0.95/0.95 and −0.091/ − 0.191 for order 1 and 2
  > For p = 0.2, the Shapley Taylor index is uniformly zero for any order.
  > We can see that our Faith-Shap/Faith-Banzhaf are (almost) faithful to all orders except for |S| = 1.
- [method/interpret] (inferred) The same toy game shows what raw Möbius terms mean:
  Shapley-Taylor's lower orders are the Möbius terms, so the Möbius main there is 0
  (a player alone, all others absent). A Möbius main or pair is the effect with every
  other player at the absent value, not an average over contexts. On drafts, with
  absent filled by an average legal replacement, that is "this champion or pair in an
  otherwise average draft"; the Faith or SII top-order term is the same contrast
  averaged over how much of the real draft is present (^f9). ^f11
- [stats] Estimation by sampled weighted regression reached a squared error under
  0.001 in 887 model evaluations (IMDB, 15 words) against 2,781 for Shapley-Taylor by
  permutation sampling; irrelevant when all 2^d coalitions are computed. Section 8.1, Table 4 ^f12
  > Shapley Taylor 2781.2 7368.3
  > Faith-Shap 887.4 893.7
  > we see that Faith-Shap can be estimated more accurately and uses fewer model evaluations
- [method/interpret] Checked, not there: no measured faithfulness (R² or weighted
  error) of the indices on a real model, only curves on two toy games and qualitative
  BERT word pairs; no comparison with k-SII / n-Shapley; nothing on how absent
  features are filled (the BERT run deletes words; the tabular baseline is not
  discussed); nothing on noise in v, model seeds or categorical players. ^f13
- [method/interpret] (inferred) For 10 seats: the Shapley kernel puts most weight on
  coalitions of size 1 and 9, so order-2 Faith-Shap is the pairwise surrogate that
  best matches "one seat known" and "one seat unknown" views of the draft and is exact
  for the full draft; Faith-Banzhaf fits all 1,024 coalitions equally but its terms do
  not sum to the prediction. Since the fit error of either is computable exactly per
  draft, report it (share of coalition variance left over) beside any order-2 table. ^f14

## Read

- Abstract, 1-6 in full; 7 (cardinal indices, multilinear view) skimmed; 8-10.

## Not read

- Appendix (proofs, weight family of Theorem 16, top-15 interaction tables against
  integrated Hessians and Archipelago, synthetic sparse functions).
