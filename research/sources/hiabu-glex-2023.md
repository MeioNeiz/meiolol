---
title: 'Hiabu, Meyer, Wright 2023: Unifying local and global model explanations by functional decomposition of low dimensional structures'
url: https://arxiv.org/pdf/2208.06151
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (abstract, 1-4, appendix E-F)
relevance: high
grade: B/strong
description: AISTATS 2023 (Copenhagen, Heidelberg, BIPS Bremen); the marginal identification constraint makes a main + pair + ... decomposition of any fitted model unique, equal to partial dependence and to interventional SHAP split evenly; exact only for low-order models (xgboost, planted forest; R package glex); dropping a feature's components removes it post hoc
---
# Hiabu, Meyer, Wright 2023: Unifying local and global model explanations by functional decomposition of low dimensional structures

Why: which constraint makes a global main, pair and triple table of a fitted model
unique when inputs are dependent, what it agrees with (SHAP, partial dependence), and
what it costs.

## Assessment

- Evidence: B. AISTATS 2023, theorems with proofs (the solution is a Möbius inverse,
  so the maths is old and safe), R package glex. Experiments are illustrations: one
  toy function, bike sharing, adult; xgboost and random planted forest only. No
  accuracy or recovery benchmark, no neural net, no categorical features.
- Reasoning: strong. States the constraint, proves uniqueness, shows a worked example
  under correlation, and lists limits (causal assumption, estimation of components).
- Interests: own package and own model class (random planted forest).
- Weigh: trust the identities (constraint = partial dependence = interventional SHAP
  split evenly). The constraint integrates absent features over their marginal, so it
  evaluates the model off the data support; the paper says so and offers no fix. Its
  algorithm is for trees; for our net the same quantities come from brute force.

## Findings

- [method/interpret] A decomposition into mains, pairs and higher terms means nothing
  until a constraint fixes it: mass can move between terms with the sum unchanged.
  Section 2.1 ^f1
  > without suitable identification constraints, it is possible to change components on the right without altering the left hand side.
- [method/interpret] Marginal identification: for every feature set S, the terms that
  touch S integrate to zero over the marginal density of X_S (the joint marginal of the
  set, not a product of single marginals, and not conditional on the rest). Exactly one
  decomposition satisfies it, whatever decomposition one starts from. Section 2.1,
  Theorem 2.2 ^f2
  > The next theorem states existence and uniqueness of a decomposition that satisfies the identification constraint (2) and describes the solution explicitly.
  > where p̂S is some estimator of the density pS of XS .
- [method/interpret] The solution is the Möbius inverse (Harsanyi dividend) of the
  marginal expectations: each term is an alternating sum over subsets of the model
  averaged over the absent features' marginal. Remark 2.3 ^f3
  > Theorem 2.2, given Lemma 2.1, is a special case of a more general result in combinatorics where the solution is known as Möbius inverse (Rota, 1964).
- [method/interpret] Under this constraint the interventional SHAP value of a feature
  is its main term plus each interaction term containing it divided by the term's
  size. Corollary 2.7 ^f4
  > the interventional SHAP values are weighted averages of the corresponding components, where an interaction component is equally split to all involved features
- [method/interpret] Under this constraint a feature's partial dependence plot is the
  intercept plus its main term, and the partial dependence of a set is the sum of all
  terms inside it; no other constraint has this property. Abstract, Section 2.3, 2.6 ^f5
  > With our proposed identification, a feature’s partial dependence plot corresponds to the main effect term plus the intercept.
  > The marginal identification (2) is new and the only identification that corresponds to partial dependence plots.
- [method/interpret] The full decomposition equals interaction SHAP of order q, the
  highest interaction order in the model, and is global: a term depends only on its own
  features' values. Section 1 ^f6
  > We show that the proposed explanation is identical to qinteraction SHAP (Tsai et al., 2022), where q corresponds to the maximal order of interaction present in the model to be analyzed.
  > two observations which have a set of feature values in common receive the same explanation for main and interaction effects involving exclusively those features.
- [method/interpret] With correlated features a main effect and an interaction can
  cancel inside one SHAP value: for x1 + x2 + 2 x1 x2 with correlation 0.3 a point gets
  SHAP 0 for a feature that clearly matters; the decomposition shows +0.4 and -0.4.
  Section 1.1 ^f7
  > the main effect contribution and interaction contribution cancel each other out.
  > Local explanations that do not explicitly specify all interactions cannot lead to meaningful interpretations in the presence of correlated features.
- [method/interpret] Interventional SHAP, and so this decomposition, depends on what
  the model does where there is no data; staying on the support instead credits a
  feature with no effect for its correlated neighbour. The paper accepts the first.
  Section 1.1 ^f8
  > This is because SHAP values are constructed by extrapolating outside the support of the data.
  > a feature that has zero effect on the model output can still be assigned a value stemming from a correlated feature
- [method/interpret] (inferred) Under dependence the terms are neither centred nor
  orthogonal on the data. In Example 2.6 the intercept is 2 corr, each main is x minus
  2 corr and the pair term is 2 x1 x2 plus 2 corr, so on real data the mains average
  -2 corr and the pair term +4 corr: correlation between features shows up as offsets
  in the terms. Variance shares by order therefore do not add up; a share-by-order
  number needs mean absolute size (^f12) or purification under the data weight
  ([[lengerich-2020-purification#^f4]]). ^f9
- [method/interpret] The functional ANOVA constraint (the one purification uses) is a
  different identification: it matches observational SHAP, not interventional. Section
  1.2, 2.6 ^f10
  > a functional ANOVA constraint leads to observational SHAP (Herren and Hahn, 2022).
  > These authors considered a different constraint called (generalized) functional ANOVA decomposition.
- [method/interpret] Cost: the number of terms and marginal integrals grows
  exponentially with interaction order, so exact computation needs a model that is a
  sum of low-order pieces (each tree touches few features); a depth-limited tree
  ensemble needs 10 marginals where the naive route needs 31. Section 1, 2.1 ^f11
  > since the number of components grows exponentially with increasing q, exact calculation is only feasible if q is sufficiently small.
  > For estimators without this property, calculating the entire decomposition is computationally infeasible for high dimensional input.
- [method/interpret] Importance per term: mean absolute value of each term, so mains
  and interactions of each order get their own bar and do not cancel as they do inside
  mean absolute SHAP. Section 2.5, 3.2 ^f12
  > contributions from various interactions and main effects can cancel each other out, which may not be desirable.
  > x2 and x4 have only interaction effects but no main effects
- [method/interpret] Post-hoc removal: dropping every term that contains feature U
  gives the model averaged over U's marginal, which is the do-operator answer if U
  causes the other features and nothing causes U. In the simulation refitting without
  the feature changed nothing (the correlated feature carried it); dropping terms
  removed the direct effect and kept the indirect one. Section 2.4, 3.3 ^f13
  > by dropping all components that include features in U
  > Because of the high correlation between sex and hours, the effects of sex cannot be removed by not considering the feature in the model.
- [method/interpret] The removal reading rests on an assumed causal graph. Section 4 ^f14
  > This causal structure might be quite realistic in many fairness considerations, but the true causal structure is generally unknown.
- [stats] Open by their own account: a model that predicts well need not estimate its
  separate terms well. Section 4 ^f15
  > it is not clear if a method that estimates m well is also a good estimator for a selection of components mS .
- [method/interpret] Implementation: xgboost (one recursion per tree, branches of an
  absent feature weighted by training coverage) and random planted forest (terms on a
  grid, marginal from cell counts); 2-way runtime about that of xgboost's TreeSHAP.
  3-way terms are shown on bike sharing. Appendix E, F, Section 3.1 ^f16
  > our runtime is similar to that of the TreeSHAP implementation included in the xgboost library
  > In the bottom row, the 3-way interactions show that interactions between the hour of the day and the temperature are stronger on non working days than on working days.
- [method/interpret] Checked, not there: neural nets or any sampled approximation for
  models that are not sums of low-order pieces; categorical features with many levels;
  uncertainty of a term over seeds or resamples; any test that recovered terms match
  planted ones beyond the two-feature toy; a remedy for the off-support evaluation. ^f17
- [method/interpret] (inferred) For our set net over 10 seats: the marginal
  identification is the Möbius decomposition [[bordt-nshapley-gam-2023#^f5]] with the
  interventional value function, and ^f2 says what "absent" must be for it: absent
  seats take the values a random background draft has in those seats, jointly, and
  independent of the present seats. Then the global table is partial dependence
  differences (^f5): pair cell (seat i = a, seat j = b) = PD_ij(a, b) - PD_i(a) -
  PD_j(b) + mean, one number per cell, the same for every draft. Cost is brute force:
  cells x background drafts forward passes (45 seat pairs x 170^2 cells x a few
  thousand backgrounds is about 10^9 to 10^10, a GPU job; champion triples, 120 x
  170^3 cells, only for cells with data). The price is ^f8: forcing a and b into random
  drafts makes drafts that never occur (duplicates, counter-picks undone), so a cell
  partly reports the net's extrapolation; restrict backgrounds to legal drafts and
  compare with a masked-input value function ([[enouen-instashap-2025]]). ^f18

## Read

- Abstract, 1, 2, 3.1-3.3, 4 in full; appendix A (value function), E (algorithms 1-3,
  density estimator), F (runtime text).

## Not read

- Appendix C-D (proofs, SHAP written out for a general decomposition), G (random
  planted forest figures), Figure 6 runtime numbers (figure only).
