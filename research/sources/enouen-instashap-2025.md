---
title: 'Enouen, Liu 2025: InstaSHAP: Interpretable additive models explain Shapley values instantly'
url: https://arxiv.org/pdf/2502.14177
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (abstract, 1-8, appendix A.1, D, E.1, F.3)
relevance: high
grade: B/fair
description: ICLR 2025 (USC); with masked (conditional) removal, SHAP is exactly the order-1 functional ANOVA and Faith-SHAP-k the order-k one, for any input correlation; a GAM trained with Shapley-kernel masks on its terms comes out purified; SHAP is trustworthy only where a GAM matches the black box; correlation makes redundant "interactions"
---
# Enouen, Liu 2025: InstaSHAP: Interpretable additive models explain Shapley values instantly

Why: does training with random feature masking (so the model itself gives the value of
any coalition) yield a faithful main + interaction decomposition, what does it mean
under dependent inputs, and what does it cost in accuracy.

## Assessment

- Evidence: B. ICLR 2025, theorems with proofs in a long appendix; same first author
  as SIAN ([[enouen-sian-2022]]). Experiments are thin: a 2-feature and a 10-feature
  synthetic, two tabular sets with one number each, one image set, MIMIC with 5 models;
  no seeds or intervals elsewhere, no recovery test against planted terms beyond the
  synthetics.
- Reasoning: fair. Clear on why conditional removal, on synergy versus redundancy and
  on what SHAP can't show. Less clear on cost: no ablation of masked against unmasked
  training of the black box, and the "train a GAM to check SHAP" test is argued, not
  measured.
- Interests: own method (InstaSHAP) against FastSHAP; argues for interpretable models
  over post-hoc explanation.
- Weigh: trust the correspondence (masked value function = conditional functional
  ANOVA = what SHAP divides up) and the worked example. The accuracy claims are small
  samples. Note the opposite choice to [[hiabu-glex-2023]]: conditional, not marginal.

## Findings

- [method/interpret] Three ways to remove a feature: a fixed baseline, the marginal
  (interventional) and the conditional (observational). Under independence conditional
  equals marginal; the paper treats the other two as simplifications of the
  conditional. Section 2.1, Appendix A.1 ^f1
  > replacing the feature with a reference value (baseline), integrating over the marginal distribution of the feature (marginal), or integrating over the conditional distribution of the feature (conditional).
  > The first assumption of feature independence implies the equivalence of the conditional value and the marginal value.
- [method/interpret] Baseline and marginal removal describe the model's algebra and
  evaluate it off the data; for the algebra, the Bordt and von Luxburg correspondence
  already holds. This paper is about the conditional case. Section 2.1 ^f2
  > significantly overemphasize the algebraic structure of the model instead of the statistical structure.
  > If one is exclusively interested in the algebraic dependencies of their ML model, the correspondence highlighted herein has already been established in Bordt & von Luxburg (2023).
- [method/interpret] Marginal removal answers what causes the model's output to
  change, not what causes the outcome. Appendix A.1 ^f3
  > only considering the engineer-level causality of ‘causing the model’ to change its predictions.
- [method/interpret] The functional ANOVA terms are the Möbius sums of the conditional
  expectations of the model given each subset; the Shapley value of a feature is each
  term containing it divided by the term's size. Section 2.3, Eq. 10, 13 ^f4
  > This specific choice using conditional projection is often called the ‘Sobol-Hoeffding’ decomposition.
  > Intuitively, the value which is ascribed to each feature interaction S is uniformly divided amongst each of its constituents
- [stats] With correlated inputs the variance no longer splits over terms; a term's
  covariance with the output can be negative, which mixes synergy (the set tells more
  than its parts) with redundancy (the parts share information). Section 2.3 ^f5
  > Unfortunately, this variational formulation for additive models breaks down for the case of correlated input variables.
  > conflating the synergistic effects between a set of features S and the redundant effects of shared information amongst the same set of features S.
- [method/interpret] Worked example f = x + xy with correlation rho: under conditional
  removal y gets a main term (rho y + rho y^2 - rho) though it has none in the formula,
  and the pair term shrinks as rho grows; past |rho| = 1/2 the pair term alone is
  negatively related to the target. Appendix D.1 ^f6
  > the interaction term alone is no longer positively correlated with the function we are trying to learn.
  > The redundant information from knowing x or y outweighs the synergistic information from knowing x and y.
- [method/interpret] SHAP is exact only when the function has no interaction terms in
  this decomposition; otherwise it hides them, synergy and redundancy alike. Theorem 1 ^f7
  > if and only if H is completely free of feature interactions
  > SHAP cannot distinguish synergistic feature interactions nor can it distinguish redundant feature interactions.
- [method/interpret] The same holds one level up: an order-k interaction index is exact
  only without terms above order k, and blurs those into lower ones. Theorem 2 ^f8
  > even indices measuring feature interactions will still be forced to blur out the higher-order interactions
- [method/interpret] With any input correlation, the functions an order-k GAM can
  write are strictly more than those with a conditional ANOVA of order k. Theorem 3, 4 ^f9
  > This inclusion is strict in the other direction as soon as there is a feature correlation in the input data.
- [method/interpret] (inferred) ^f9 read for us: a model that is purely additive in
  its inputs still has non-zero pair terms under conditional (masked) removal when the
  inputs are correlated, because knowing one input predicts the other's contribution;
  these are redundancy terms, usually of opposite sign to the mains. So a pair table
  from a masked model is not evidence of a pair mechanism in the net. ^f10
- [method/interpret] Test offered: train a GAM on the same data; if it matches the
  black box, SHAP can be trusted there, if not, SHAP is hiding interactions. Section
  3.3 ^f11
  > a practitioner may evaluate the trustworthiness of SHAP on a given dataset by simply training a GAM model on the same dataset.
  > if a GAM cannot match the same accuracy as the blackbox model, this means that the practitioner needs to be wary about trusting SHAP values on this dataset.
- [method/interpret] InstaSHAP: fit an order-k GAM to the masked model's output with
  masks drawn from the Shapley kernel, each term switched on only when all its
  features are unmasked. The terms then come out purified and SHAP is a sum of table
  lookups. Section 5, Eq. 20, Appendix E.1 ^f12
  > second we add the masking on each additive component of the GAM to only be included if all features of that component are unmasked in S.
  > It follows that we may easily calculate downstream explanations of interest like the SHAP value because of the automatic purification of such effects.
- [method/interpret] The coalition values come from a surrogate trained with masked
  inputs (MSE or KL projection), which estimates the conditional expectation; the image
  net was fine-tuned on that masked objective. Appendix A.1, D.4 ^f13
  > This can be done implicitly via the training of a masked surrogate predictor using the projection equations for mean-squared error or for KL divergence as used within this work
  > For our main CNN we train a ResNet-50 model (He et al., 2016) on the masked surrogate objective
- [method/interpret] Classification is explained on the logit. Appendix D.4 ^f14
  > all of our explanations are done on the logits or log-probabilites of the output prediction.
- [stats] Tabular results: bike sharing error 17.4% for GAM-1, 6.59% for an MLP, 6.23%
  for a GAM with 20 chosen terms up to order 3; tree cover accuracy 72.4%, 80.4%, and
  82.2% for a GAM with 50 terms up to order 5. Terms picked SIAN-style with
  Archipelago. Section 6.2, 6.3, Appendix D.3 ^f15
  > we select 20 tuples of size three or less to train a GAM-3 model which achieves 6.23% R2 error
  > we are able to train a GAM-5 on 50 tuples to achieve 82.2% accuracy.
- [stats] Images (CUB birds): ResNet 65.0% fine accuracy, patch GAM-1 33.2%, 2x2 and
  3x3 patch GAMs 45.8% and 46.8%; the gap is read as SHAP oversimplifying. Section 7 ^f16
  > at least 20 percentage points of accuracy are being completely thrown away when using the simplification of SHAP.
- [stats] Masked training did not cost the GAM accuracy on MIMIC (5 models each:
  vanilla mean 91.1%, InstaSHAP 91.3%) and its shape functions varied less across the
  ensemble. Appendix F.3 ^f17
  > The vanilla GAM models achieve accuracies of 91.0%, 91.5%, 90.6%, 91.1%, and 91.2% for an average accuracy of 91.1%.
  > Generally, the InstaSHAP models have a more consistent interpretation of the dataset and achieve tighter confidence intervals than the typical training procedure.
- [method/interpret] On synthetic 10-feature data InstaSHAP approximated the true
  Shapley values with lower error than FastSHAP. Section 6.1, Figure 3 ^f18
  > the approximation results consistently showing InstaSHAP has a better inductive bias than FastSHAP for learning the Shapley values.
- [method/interpret] (claim) Hooker's hierarchical-orthogonality decomposition is the
  main alternative; they set it aside as hard to compute beyond a few dimensions and
  hard to read. Appendix A.1 ^f19
  > Amongst its limitations, beyond a lack of intuitive meaning behind its prescribed functions, the most severe is seemingly its computational intractability.
- [method/interpret] Categorical inputs: a replacement that happens to equal the
  present value removes nothing, so effects get masked out. Appendix B.4 ^f20
  > when using categorical input variables it is easy to mask out bivariate and even higher-order effects.
- [method/interpret] Checked, not there: accuracy of a black box trained with input
  masking against the same net trained without (no ablation); how well a masked net's
  coalition outputs match true conditional expectations; high-cardinality categoricals
  (tree cover has 1 categorical feature); near-chance outcomes; false discovery control
  or seed stability of interaction terms. ^f21
- [method/interpret] (inferred) For our set net: seat masking makes the net output
  E[win | seats shown], the conditional value function, in one forward pass per
  coalition and with no impossible drafts. Its Möbius terms then answer "what does
  knowing this seat tell us", counter-pick and duo selection included: a seat with no
  effect in the net gets a main through what it reveals about other seats (^f6), and
  additive mains produce redundancy pair terms (^f10). Marginal replacement
  ([[hiabu-glex-2023#^f2]]) answers "what does the net do with this seat" (^f2, ^f3) and
  pays in off-support drafts. They agree only if seats are independent (^f1), so the
  gap between the two tables measures how much draft dependence matters. With pick-rate
  replacement the swapped-in champion equals the present one at its pick rate, which
  shrinks every term by that share (^f20): draw replacements excluding the present
  champion or rescale. ^f22

## Read

- Abstract, 1-8 in full; Appendix A.1 (removal methods, Hooker), B.4, D.1-D.4
  (experiments), E.1-E.2 (purified loss), F.3 (MIMIC); Theorem 6 statement.

## Not read

- Appendix A.2-A.3 (interaction index tables), B.1-B.3, C (proofs of Theorems 1-5),
  E.3 onward (variational solution under correlation, frontier selection), F.1-F.2
  (extra figures).
