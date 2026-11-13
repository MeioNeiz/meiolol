---
status: answered
priority: soon
area: stats
parent: frontier-experiments
tags: [method, method/interpret, stats, draft]
description: How do we recover readable main, pair and higher-order effects (why a champion wins in a comp) from an accurate black-box model, and which interaction-detection and additive-plus-interaction methods hold up?
---
# How do we recover readable main, pair and higher-order effects (why a champion wins in a comp) from an accurate black-box model, and which interaction-detection and additive-plus-interaction methods hold up?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]]

## Answer

Ranked, for 10 seats of ~170 champions near a coin flip (C20):

1. Name champion pairs from the direct fit: the shrunk additive-plus-pairs model fitted
   to results (v2 with pair parents), purified before display. In our planted check the
   direct cell was at least as good as a net's term from 50 games up, and the net
   invented pairs in empty blocks that its seeds agreed on (C19). Interactions cost about
   16x the data of mains and low-power hits overstate about 3x (C9).
2. Read the black box by its exact functional decomposition over seats: Möbius terms of
   all 1,024 coalitions per draft under the marginal value function (absent seats filled
   from other real drafts, legal, never the present champion). It is unique, equals the
   interventional Shapley-GAM, matches partial dependence, and was exact on a planted
   truth (C1, C3, C16, C19). Use it for the share of each order and for what the net adds
   to the additive model, not for naming cells. With the terms exact, a Shapley index is
   only a way to fold higher orders into pairs: report the Möbius pair term and the
   full effect, and Faith-Shap order 2 only if order 3+ is not small (C14, C15).
3. Distil the black box into the sparse additive-plus-pairs form and compare term by
   term with the label fit ([[distil-explainable]]); black box first, then a sparse
   refit, is the standard pipeline, and the best order varies by data (C7).
4. Guards on anything named from a net: an empty reference (knockoff seats), a planted
   twin (Friedman's additive-null retrain) and seed agreement, all three (C4, C5, C13,
   C19). Detectors were never validated on near-chance outcomes or 170-level
   categoricals (C6).

Not worth running: the H-statistic (one number per seat pair, its numerator is the
purified pair term we already have, inflated where effects are flat, no null short of
retraining: C13); EBM/FAST as a pair cross-check (pair terms cut nominal levels in index
order; fine for mains only: C18); NAM, NODE-GA2M, NBM, GAMI-Net (categoricals one-hot or
target-encoded, nothing at champion level over shrunk role-pair cells; they suit profile
features: C10, C18); seat-masked training as the main reading (it describes how picks go
together, not what the model does; one contrast run at most: C17); integrated Hessians
(continuous inputs only: C11); plain SHAP (hides interactions: C1).

What to expect: no 3-way effect beyond pairs has been measured in a team game, and a
real one with too little data shows as spurious lower-order terms (C8). Our planted 2 pp
class triple was not learnt at 1.2M games (C19). Champion-level triples are out of reach;
only kit-group triples can be tested (C12). First experiment: C1 in
docs/plan/lab-frontier.md (order spectrum of the teacher, declared rules).

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
- C13: Friedman's H-statistic is not a usable detector here: normalised H measures presence, not importance, and inflates where a pair's joint effect is flat; the unnormalised form removes that but has no null or threshold; both rest on partial dependence, so dependent inputs give false pairs with no remedy for nets; its only calibrated null is retraining the full model on labels drawn from an additive fit. for: [[friedman-popescu-hstat-2008#^f6]], [[friedman-popescu-hstat-2008#^f7]], [[friedman-popescu-hstat-2008#^f10]], [[inglis-vivid-unnormalised-h-2022#^f5]], [[inglis-vivid-unnormalised-h-2022#^f6]], [[molnar-iml-hstatistic#^f5]]
- C14: Every order-2 Shapley-type index is a fixed linear map of the exact Möbius terms and differs only in where mass above order 2 goes: Shapley-Taylor puts all of it on pairs and can flip a pair's sign, Faith-Shap is the unique efficient least-squares order-2 fit and moves mains the opposite way. With Möbius terms exact, the index is a reporting choice, not an estimate. for: [[tsai-faithshap-2023#^f3]], [[tsai-faithshap-2023#^f5]], [[tsai-faithshap-2023#^f7]], [[tsai-faithshap-2023#^f10]], [[lundstrom-synergy-functions-2023#^f3]]
- C15: Pure (Möbius, all others absent), partial (Shapley share) and full (all others present) effects answer different questions, and a pure-to-full gap signals higher orders. Marginal filling breaks dependence and evaluates unseen combinations; conditional filling credits a feature with its correlates (a noise feature gets the same pure effect at correlation 0.9). No source names a winner or tests categorical inputs. for: [[fumagalli-unifying-fanova-games-2025#^f3]], [[fumagalli-unifying-fanova-games-2025#^f5]], [[fumagalli-unifying-fanova-games-2025#^f6]], [[fumagalli-unifying-fanova-games-2025#^f9]], [[fumagalli-unifying-fanova-games-2025#^f12]]
- C16: The marginal identification gives one global decomposition: the Möbius inverse of the model averaged over the absent features' joint marginal. It is the only one that matches partial dependence and splits evenly into interventional SHAP; the functional ANOVA constraint that purification uses is a different identification (observational SHAP). Its price is evaluating the model off the data support. for: [[hiabu-glex-2023#^f2]], [[hiabu-glex-2023#^f3]], [[hiabu-glex-2023#^f4]], [[hiabu-glex-2023#^f5]], [[hiabu-glex-2023#^f8]], [[hiabu-glex-2023#^f10]]
- C17: Training with masked inputs yields the conditional decomposition, which describes the data's statistics, not the model's mechanism: a feature absent from the formula gets a main term and correlated inputs get redundancy pair terms. A masked GAM lost no accuracy on one dataset; no black-box ablation exists. On categoricals a replacement equal to the present value removes nothing. for: [[enouen-instashap-2025#^f2]], [[enouen-instashap-2025#^f6]], [[enouen-instashap-2025#^f17]], [[enouen-instashap-2025#^f20]]
- C18: EBM treats nominal features properly only in mains (one bin per level, rare levels pooled, sorted by gradient each step); FAST and pair boosting cut categories in index order, so a champion x champion pair term is label-order blocks, not identity cells; no purification or heredity by default. GAMI-Net builds heredity and a marginal clarity penalty into the fit but one-hots categoricals and was tested to ~20k rows. for: [[interpretml-ebm-code#^f2]], [[interpretml-ebm-code#^f7]], [[interpretml-ebm-code#^f13]], [[interpretml-ebm-code#^f28]], [[yang-gaminet-2021#^f1]], [[yang-gaminet-2021#^f4]], [[yang-gaminet-2021#^f11]]
- C19: On our drafts with planted labels (1.21M fit games): the exact reading returns a known truth; a net that learnt pairs shows 0.3-0.5% of its power above order 2 where none is planted; a net at the mains fit's loss has only noise to read; a hidden 2 pp class triple was not learnt; direct shrunk cells beat the net's pair terms from 50 games up; the net puts 0.2-0.3 pp pairs into empty blocks and its seeds agree on them. for: [[meiolol-mobius-plant-c0#^f1]], [[meiolol-mobius-plant-c0#^f2]], [[meiolol-mobius-plant-c0#^f3]], [[meiolol-mobius-plant-c0#^f4]], [[meiolol-mobius-plant-c0#^f5]], [[meiolol-mobius-plant-c0#^f6]]
- C20 (inferred): Ranking for us: (1) direct shrunk additive-plus-pairs fit names the pairs; (2) exact Möbius terms under the marginal value function read the black box (order shares, what the net adds); (3) distillation into the additive form ships it; (4) knockoff block, planted twin and seeds guard every name. H-statistic, EBM/FAST pairs, neural GAMs and masked training are not worth running here. from: C1, C3, C7, C9, C13, C14, C16, C17, C18, C19

## Disagreements

- Archipelago (B) reports Shapley-Taylor, integrated Hessians and NID near 0.5 AUC on
  its functions; Janizek (B) reports integrated Hessians beating the others. Each
  benchmark suits its own method, so neither result transfers. Planted pairs on our own
  drafts would settle which score to use.
- NODE-GA2M over EBM-GA2M (3.6% relative, paper) vs package defaults reported lower
  (search summary only, not read). Not decision-relevant for categorical seats.
- Purification (functional ANOVA, data-weighted: Lengerich, A) and the marginal
  identification (Hiabu, B) are different constraints and give different tables under
  dependent picks. We read the net with the marginal one and purify shipped tables with
  seat weights; C1 reports both for the additive model to size the gap.

## Open

- Marginal against conditional filling: sources name no winner (C15). We take marginal
  (what the model does); the gap to a seat-masked net would measure how much draft
  dependence matters, unmeasured
- Whether the set net on v2 holds anything above order 2 (comp traits x enemy): C1
- Knockoff seats for drafts ignore within-draft dependence; Diamond's permuted-copy result
  suggests FDR holds at lost power, untested on categorical seats
- Power for 3-way terms at kit-group level when the kit is a net input: C4
- Leads: Hooker 2007 generalised fANOVA; iLOCO intervals (2502.06661); kernel interaction
  trick (1905.06501); exact Möbius for GNNs (2501.16944); ALE (1612.08468)
