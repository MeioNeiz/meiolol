---
title: 'Fumagalli, Muschalik, Hüllermeier, Hammer, Herbinger 2025: Unifying feature-based explanations with functional ANOVA and cooperative game theory'
url: https://arxiv.org/pdf/2412.17152.pdf
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (abstract, 1-7, appendix B, C.2, E.1 index entries)
relevance: high
grade: B/strong
description: AISTATS 2025 (Bielefeld, LMU; the shapiq group); every feature explanation is fixed by two choices, how absent features are filled (baseline, marginal or conditional fANOVA) and how much higher-order mass a term carries (pure = Möbius, partial = Shapley-type, full = co-Möbius); maps SHAP variants, Shapley-GAM, k-SII, Faith-Shap, PDP, Sobol, H-statistic onto that grid; poses the choice as four questions without recommending one
---
# Fumagalli et al. 2025: Unifying feature-based explanations with fANOVA and game theory

Why: how the value function (absent seat = baseline, marginal or conditional) and the
kind of effect (pure, partial, full) change what a reported main or pair effect means.

## Assessment

- Evidence: B. AISTATS 2025, theorems with proofs, code public; authors wrote shapiq
  and SHAP-IQ. Experiments are illustrations: a 4-feature Gaussian with a known
  function, California housing, one IMDB sentence.
- Reasoning: strong. Each choice is defined, tied to the Möbius transform and shown on
  a worked example; limits listed. The practitioner guide stops at questions.
- Interests: none beyond their own framework and package.
- Weigh: trust the taxonomy and the Möbius identities. All examples are continuous
  features; categorical features are ordinal-encoded in the appendix, so nothing
  speaks to a 170-level seat. No advice on which cell to report.

## Findings

- [method/interpret] Three functional decompositions, by how features outside S are
  integrated out: at a fixed baseline point (b), over their joint marginal ignoring S
  (m), or over their distribution given S (c). Section 1, 3.1 ^f1
  > This choice corresponds to the marginalization of features using either a baseline (b), the marginal (m), or the conditional (c) distribution and yields an increasing influence of feature distributions.
- [method/interpret] For one instance the Möbius term of the game is the fANOVA
  component at that point: the part of the prediction owed to S jointly and to no
  subgroup. Section 2.3, Corollary 1, Section 3.4 ^f2
  > we can view the MT m(S) as the fANOVA effect fS evaluated at x0
  > m(S) is the pure additive contribution obtained by the interaction of S, which cannot be attributed to any subgroup of S.
- [method/interpret] Three kinds of effect: pure (all other features absent; for an
  interaction the Möbius term), full (all other features present; the co-Möbius term,
  the sum of every Möbius term containing S), partial (Shapley value or a Shapley
  interaction index: a weighted share of the higher terms). Section 3.4, Table 2 ^f3
  > we propose feature influence in absence of all remaining features as the pure effect
  > the pure interaction equals the isolated effect m(S), whereas the full effect is the sum over all effects that involve all features in S.
  > the partial effect captures a share of these higher-order effects with an index-specific weight
- [method/interpret] For a single feature: pure is the main effect only, full adds every
  interaction it is in, the Shapley value splits each interaction equally over its
  members. Section 3.4 ^f4
  > the pure effect captures the main effect m(i), whereas the full effect additionally includes all effects that involve feature i, while the partial effect (SV) distributes the higher-order effects equally among involved features.
- [method/interpret] Marginal filling breaks the dependence between present and absent
  features, so the model is evaluated at unseen combinations; with independent
  features conditional and marginal agree. Section 3.1, Theorem 2 ^f5
  > Using the joint marginal distribution of the remaining features breaks the feature dependencies between features in S and −S, which yields evaluations of F in sparsely sampled or unseen regions of the input space
  > For independent features, c-fANOVA equals m-fANOVA
- [method/interpret] Conditional filling mixes in the effects of correlated features:
  even a linear model's main effect is distorted, and at correlation 0.9 every
  feature, a pure-noise one included, gets the same high pure effect while full
  effects shrink. Baseline is untouched by dependence; marginal moves mainly the pure
  effects. Section 3.1, 5.1, Figure 2 ^f6
  > For c-fANOVA, this effect is distorted by the cross-correlation with the second feature.
  > for ρ = 0.9 all features including the noise feature result in equally high pure effects. In contrast, full effects are small
  > While b-fANOVA explanations are not affected by feature dependencies, m-fANOVA uses the joint marginal distribution, which particularly influences pure feature effects.
- [method/interpret] Where known methods sit: interventional Shapley-GAM and k-SII are
  pure and partial effects of the marginal decomposition, observational ones of the
  conditional; Faith-Shap and Shapley-Taylor are partial interaction effects, defined
  on a baseline but usable with any value function; Shapley-Taylor's top order takes
  all higher mass, Faith-Shap spreads it over every reported term. Section 4.1,
  Appendix E.1 ^f7
  > use pure and partial effects of m-fANOVA, whereas obs. Shapley-GAM and k-SVs rely on pure and partial effects of c-fANOVA.
  > The highest-order interactions (order = k) thereby capture all higher-order interactions (order > k).
  > it distributes higher-order interactions on all interactions that are computed.
- [method/interpret] Global version: the sensitivity game is the variance of the
  restricted prediction; with independent features its Möbius term is the variance of
  the fANOVA component. Sobol indices are pure and full joint effects, the
  H-statistic a pure interaction effect, Hooker's superset measure the full one.
  Dependence adds covariance terms. Section 3.2, Theorem 3, Section 4.2 ^f8
  > For independent features, the MT of the sensitivity game is the variance of the fANOVA effect
  > Friedman and Popescu (2008) proposed the H-statistic, which corresponds to the pure interaction effect.
- [method/interpret] A gap between pure and full effects signals higher-order terms:
  California housing's MedianIncome has almost no pure main effect but a large full
  one; in an IMDB sentence "but" is negative pure, positive partial and full.
  Section 5.2 ^f9
  > While MedianIncome (MI) shows almost no main (individual pure) effect, it has a strong full individual effect due to higher-order interactions
  > the comparison between pure, partial, and full clearly shows the presence of feature interactions
- [method/interpret] The plain Shapley interaction index is not recommended for local
  explanation since it does not sum to the prediction; the efficient order-k indices
  (k-SII, Shapley-Taylor, Faith-Shap) differ only in the weight each gives the higher
  Möbius terms, are the Shapley value at k = 1 and the Möbius transform at k = d.
  Appendix C.2 ^f10
  > these indices are not optimal, since they do not sum to the overall payout (model prediction), referred to as efficiency
  > These SIs differ by their choice of axioms, and it was shown that they differently summarize higher-order interactions
- [method/interpret] Cost: baseline needs one model call per coalition, marginal and
  conditional need estimated expectations; pure and full terms need few game values,
  partial ones all of them. Section 4.3 ^f11
  > a single model call suffices for b-fANOVA, whereas m- and c-fANOVA rely on approximations of expectations
  > Partial effects are the most computationally expensive
- [method/interpret] The guide is four questions (local or global; individual, joint or
  interaction; baseline, marginal or conditional; pure, partial or full), with no
  recommendation. An order-k index is a restricted fANOVA, and how well it describes
  the model is left open; retraining on feature subsets is named as a fourth value
  function. Section 4.3, Appendix B ^f12
  > (3) Imputation method: Should the feature distribution not (baseline), partially (marginal ), or fully (conditional ) be captured by the explanation?
  > In future work, it would be interesting to understand how well such a low-complexity decomposition describes the model.
  > Less prominent examples include re-training of models
- [method/interpret] Checked, not there: which index or cell to prefer; categorical
  features (ordinal-encoded or treated as numeric); how to average local pair terms
  into a global table other than the variance and risk games; uncertainty across model
  seeds; legality constraints on imputed values. ^f13
- [method/interpret] (inferred) For a draft, the grid reads: baseline = absent seats
  set to one reference (a mask or mean-champion embedding), one net call per
  coalition; marginal = absent seats drawn from role pick rates regardless of the
  seats shown, which makes drafts nobody plays (duplicates, no counter-pick link);
  conditional = expected win given only the seats shown, which is what a net trained
  on masked drafts outputs, and which credits a champion with whatever tends to be
  picked beside it (^f6). Marginal answers "what does this pair do", conditional
  "what does seeing this pair tell us". ^f14
- [method/interpret] (inferred) Pure pair = the pair's Möbius term (pair in an
  otherwise absent, i.e. average, draft); full pair = second difference with the other
  eight seats as drafted, which is the four-corner swap test of
  [[tsang-archipelago-2020#^f3]] and carries every triple and higher term containing
  the pair; partial = an average of that contrast over contexts. With all 1,024
  values exact all three cost nothing extra, and full minus pure per pair is the
  higher-order mass through that pair (^f9). ^f15

## Read

- Abstract, 1-7 in full; Appendix B, C.2; E.1 entries for k-SVs, Shapley-Taylor,
  Faith-SHAP.

## Not read

- Appendix A (proofs), D (worked Gaussian derivations), E.1.2-E.2 (gradient,
  sensitivity and risk method tables), F-G (setup, further figures).
