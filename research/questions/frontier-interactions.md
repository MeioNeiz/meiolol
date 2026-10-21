---
status: active
priority: soon
area: stats
parent: frontier-experiments
tags: [method, method/interpret, stats, draft]
description: How do we recover readable main, pair and higher-order effects (why a champion wins in a comp) from an accurate black-box model, and which interaction-detection and additive-plus-interaction methods hold up?
---
# How do we recover readable main, pair and higher-order effects (why a champion wins in a comp) from an accurate black-box model, and which interaction-detection and additive-plus-interaction methods hold up?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]]

## Answer

Our draft model has only 10 seats, so the best route skips approximate detectors.
Compute the exact functional decomposition of the trained net over seats: Möbius
(Shapley-GAM) terms for every seat, pair and triple, from 1,024 coalitions per draft
(C3). Shapley-type indices of order n recover an order-n additive model exactly under an
interventional value function. Plain SHAP spreads every interaction evenly over its
members and hides it (C1). What a "pair effect" means is fixed only by the value function
and weighting: here, what an absent seat is, best taken as the average over legal
replacement champions in that role weighted by pick rate. This is the same choice as
purification's data weight, and it can flip signs (C2). Averaging the decomposition over
real drafts gives a global main, pair and triple table, and the share of the net's lean
at each order. A discrete four-corner swap is the model-agnostic pair test. Integrated
Hessians needs smooth nets and continuous inputs, so use it only on profile features
(C11).

Trust is the hard part, not computation. Off-the-shelf pair scores mostly flag two
individually strong champions. Permutation p-values with BH do not control false
discoveries; knockoff copies do, even crude permuted ones (C4). A single accurate net can
rank planted interactions near chance, equally good models disagree, and NID reports
linked pairs as triples (C5). Every detector was validated on clean, continuous synthetic
data, never on a near-coin-flip outcome or 170-level categoricals (C6). So any pair or
triple we name needs knockoff seats, planted effects and agreement across seeds,
resamples and the shrunk logistic model.

What to expect: black box first, then refit a sparse additive model with only the
selected interactions, is the standard pipeline. The best order varies by data, and
higher orders lose on held-out data where trends are low order (C7). Interactions cost
about 16x the data of mains and low-power hits overstate about 3x (C9). In team games no
3-way effect has ever been measured beyond pairs: Honor of Kings 3-5-way role terms
added nothing, MOBA GBDTs did no better than pairwise models, NBA trio work has no
held-out test. With too little data a real 3-way effect shows up as spurious lower-order
terms (C8). Champion-level triples are out of reach at 1.4M games (a few dozen games
each); only kit-group or class triples can be tested (C12). Neural GAMs (NODE-GA2M, NBM,
SIAN) beat EBM by a few percent on continuous data, but they target-encode or one-hot
the categoricals. They add nothing at champion-identity level over our shrunk role-pair
blocks, and fit our profile features better (C10). Set-model explanation as such: 3
searches found nothing specific; seat-level Möbius covers it.

## Claims

- C1: Shapley interaction indices of order n (n-Shapley/k-SII, Shapley-Taylor, Faith-Shap) recover an order-n GAM exactly under interventional SHAP; plain Shapley values spread interactions evenly, so mains and interactions can't be told apart; pairwise indices are far more faithful than SHAP. for: [[bordt-nshapley-gam-2023#^f2]], [[bordt-nshapley-gam-2023#^f4]], [[muschalik-shapiq-2024#^f3]]
- C2: A decomposition into mains and interactions is defined only by the value function or weighting chosen; mass moves between orders with identical predictions; the data weighting changes sizes and sometimes signs; neural GA2Ms purify before display. for: [[bordt-nshapley-gam-2023#^f5]], [[lengerich-2020-purification#^f1]], [[lengerich-2020-purification#^f6]], [[lengerich-2020-purification#^f7]], [[chang-nodegam-2022#^f6]]
- C3: Exact computation over every subset is the standard for small player counts (precomputed up to 16 players); 10 seats need 1,024 coalitions. for: [[bordt-nshapley-gam-2023#^f8]], [[muschalik-shapiq-2024#^f2]]
- C4: Off-the-shelf interaction scores mostly reflect two individually important features; permutation p-values with BH or BY failed to control FDR; knockoff-based Diamond controlled it, also with permuted (invalid) knockoffs at lower power, and is conservative. for: [[chen-diamond-fdr-interactions-2024#^f2]], [[chen-diamond-fdr-interactions-2024#^f3]], [[chen-diamond-fdr-interactions-2024#^f4]], [[chen-diamond-fdr-interactions-2024#^f5]]
- C5: Interactions read from one trained model are fragile: an accurate MLP ranked planted interactions at 56% AUC, equally accurate models differ in interactions, linked pairs get reported as triples, correlated inputs cause spurious ones, and weak true pairs look like chance. for: [[li-fis-rashomon-2024#^f1]], [[li-fis-rashomon-2024#^f3]], [[li-fis-rashomon-2024#^f4]], [[tsang-nid-2018#^f6]], [[lou-ga2m-2013#^f6]]
- C6: Interaction detectors were validated on clean synthetic continuous data (noise-free or SNR 1, 20-30k rows), not near-chance binary outcomes or high-cardinality categoricals. for: [[tsang-nid-2018#^f7]], [[chen-diamond-fdr-interactions-2024#^f7]], [[chen-diamond-fdr-interactions-2024#^f8]], [[tsang-archipelago-2020#^f7]], [[janizek-integrated-hessians-2021#^f6]], [[lim-hastie-glinternet-2015#^f5]]
- C7: Detect in a black box, select a sparse set of interactions with heredity, refit an additive model; the best order differs by dataset (1 on Appliances where each added order hurt, 2-3 on Bike, above 5 only on Higgs and Year). for: [[enouen-sian-2022#^f1]], [[enouen-sian-2022#^f4]], [[enouen-sian-2022#^f5]], [[enouen-sian-2022#^f6]], [[tsang-nid-2018#^f4]], [[chang-nodegam-2022#^f2]]
- C8: No 3-way effect beyond pairs has been measured in team games: Honor of Kings 3-5-way role terms added nothing, MOBA GBDTs no better than pairwise, NBA trio methods untested out of sample and explicit trio terms untenable; with too few samples a real k-way effect appears as spurious lower-order terms. for: [[hok-team-composition-2019#^f6]], [[chen-avatar-embedding-2018#^f6]], [[josephs-hypergraph-apm-2024#^f2]], [[josephs-hypergraph-apm-2024#^f5]], [[bordt-nshapley-gam-2023#^f7]]
- C9: Interactions need about 16x the data of mains; significant low-power estimates overstate about 3x; FAST needed about 10^6 samples for 4,950 candidate pairs. for: [[gelman-interactions-16x#^f1]], [[gelman-interactions-16x#^f3]], [[lou-ga2m-2013#^f5]]
- C10: Neural GAMs scale and beat EBM by a few percent on large continuous sets, but categoricals are target-encoded or one-hot, and glinternet selects whole categorical pairs; none models identity-level champion pairs better than per-block shrunk pair terms. for: [[chang-nodegam-2022#^f2]], [[chang-nodegam-2022#^f5]], [[radenovic-nbm-2022#^f2]], [[radenovic-nbm-2022#^f4]], [[lim-hastie-glinternet-2015#^f2]]
- C11: A discrete second difference (both swapped, each swapped, neither) detects a pair in any black box in O(p^2) calls; Hessian methods see nothing in ReLU nets unless smoothed and need continuous inputs. for: [[tsang-archipelago-2020#^f3]], [[tsang-archipelago-2020#^f5]], [[janizek-integrated-hessians-2021#^f3]], [[janizek-integrated-hessians-2021#^f4]]
- C12 (inferred): For us: exact seat-level Möbius decomposition of the set net with a legal-replacement value function, averaged to a global table and purified under the seat-weighted data; knockoff seats and planted pairs for FDR and power; keep a pair only if it holds across seeds, resamples and the logistic fit, then refit it as a shrunk term and judge by paired held-out log loss; test 3-way only at kit-group level. from: C1, C2, C3, C4, C5, C7, C8, C9

## Disagreements

- Archipelago (B) reports Shapley-Taylor, integrated Hessians and NID near 0.5 AUC on
  its functions; Janizek (B) reports integrated Hessians beating the others. Each
  benchmark suits its own method, so neither result transfers. Planted pairs on our own
  drafts would settle which score to use.
- NODE-GA2M over EBM-GA2M (3.6% relative, paper) vs package defaults reported lower
  (search summary only, not read). Not decision-relevant for categorical seats.

## Open

- Value function for an absent seat: role pick-rate replacement vs same-class
  replacement vs a learnt "average champion" embedding; it fixes what every pair means
- Knockoffs for drafts: a dummy seat drawn from the role's pick distribution ignores
  within-draft dependence (no duplicates, comp tendencies); Diamond's permuted-copy
  result suggests FDR holds at lost power, untested on categorical seats
- Whether the DeepSets residual net holds any within-team pair at all beyond what the
  shipped pair blocks have (its gain may be all comp-trait x enemy terms)
- Power for 3-way at kit-group level at 1.4M games: needs a planted semi-synthetic run
- Leads: Hiabu et al. 2023 glex functional decomposition; GAMI-Net; exact Möbius for
  GNNs (2501.16944); distributing synergy functions (2305.03100)
