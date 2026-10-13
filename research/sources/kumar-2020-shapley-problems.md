---
title: 'Kumar, Venkatasubramanian, Scheidegger, Friedler 2020: Problems with Shapley-value-based explanations as feature importance measures'
url: https://arxiv.org/pdf/2002.11097
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-3, 5; 4 skimmed)
relevance: medium
grade: B/strong
description: ICML 2020 (arXiv 2002.11097 v2); critique of Shapley feature attribution, both conditional and interventional value functions, redundant features changing attributions, additivity on non-additive models, and fit with human explanation goals
---
# Kumar, Venkatasubramanian, Scheidegger, Friedler 2020: Problems with Shapley-value-based explanations as feature importance measures

Why: what goes wrong with SHAP on correlated features, whichever flavour we pick.

## Assessment

- Evidence: B. ICML 2020, peer reviewed; argument by small formal examples, no
  simulations or data.
- Reasoning: strong. Each problem is a worked example; they credit proposed fixes
  (conditional estimators, asymmetric Shapley) and say what each costs.
- Interests: critics of the method (fairness auditing angle).
- Weigh: trust the examples (they are math). The conclusion "ill-suited in general"
  is broader than the examples; for a global, grouped, pre-declared feature set most of
  the problems shrink, which they do not test.

## Findings

- [method] Interventional value functions evaluate the model on out-of-distribution
  rows, so attributions depend on how the model extrapolates; Slack et al. exploited
  this to hide discrimination from KernelSHAP. Section 3.1.2 ^f1
  > Methods which use an interventional value function fundamentally rely on evaluating a model on out-of-distribution samples
  > By manipulating the model’s behavior on unfamiliar parts of the feature space, they can twist the explanations on the familiar part to their will.
- [method] Conditional value functions need extra modelling of the data for any model
  besides trees, and TreeSHAP's leaf-based estimate cannot credit variables the trees
  do not split on. Section 3.1.1 ^f2
  > For arbitrary types of models, estimating the conditional expectations requires a substantial amount of additional modeling of relationships in the data which are not necessarily captured by the model that one is trying to explain.
  > It is not, however, set up to attribute influence to variables without an interventional effect, as the trees contain no information about the distribution of variables not in the model.
- [method] Under conditional Shapley, adding a redundant copy of a feature changes
  every feature's attribution: the answer depends on which features are declared
  players. Section 3.1.1 ^f3
  > The relative apparent importances of A and B thus depend on whether C is considered to be a third feature, even though the two functions are effectively the same.
  > It is not obvious whether two statistically related features should be considered as separate “players” in the cooperative game, yet this choice has an impact on the output of these additive explanation models.
- [method] Causal fix (asymmetric Shapley, Frye et al.): order causal ancestors before
  descendants so a redundant descendant gets zero; results are sensitive to how much
  causal knowledge is assumed. Section 3.1.1 ^f4
  > orderings which place causal ancestors before their descendants
  > the sensitivity of the game theoretic approach to the amount of prior knowledge about the relative agency of each feature
- [method] Shapley on non-additive models: for a product of independent zero-centred
  features every feature gets f(x)/d whatever its size, so attributions say little about
  interactions. Section 3.2 ^f5
  > Then the Shapley value for every feature i is d1 f (x), regardless of the value xi .
- [method] Authors' conclusion: Shapley is ill-suited as a general solution; prefer
  approaches built for the specific use case. Section 5 ^f6
  > our work shows that in fact this framework is ill-suited as a general solution to the problem of quantifying feature importance
- [method] (inferred) For us: if gold lead, gold per minute and kill lead are all
  players, each gets a slice and "economy" looks smaller next to dragons than if gold
  were one feature (^f3). Fix the players as a pre-declared list of groups (economy,
  towers, dragons, barons and heralds, levels and XP, draft prior) and attribute to
  groups, not raw columns; never compare shares across runs with different feature
  lists. ^f7
- [method] (inferred) A natural causal order exists in League (kills and CS produce gold,
  gold and XP produce towers and dragons), so an asymmetric ordering could assign
  credit "upstream"; but the order is a choice and changes the answer (^f4), so report
  symmetric group shares and treat any ordered split as a separate, labelled view. ^f8

## Read

- Sections 1-3 and 5 fully; Section 4 (human-centric: contrastive explanations,
  actionability) skimmed.

## Not read

- Section 4 detail; Frye et al. 2019 (asymmetric Shapley) itself.
