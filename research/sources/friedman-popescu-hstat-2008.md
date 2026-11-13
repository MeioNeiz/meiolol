---
title: 'Friedman, Popescu 2008: Predictive learning via rule ensembles (section 8, interaction effects)'
url: https://arxiv.org/pdf/0811.1679
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (section 8)
relevance: high
grade: A/strong
description: Annals of Applied Statistics 2008; section 8 defines the H-statistic (pair, one-vs-rest, three-way) from centred partial dependence, warns of spurious interactions under collinearity, and gets the null by refitting the full model on data simulated from an additive fit
---
# Friedman, Popescu 2008: Predictive learning via rule ensembles (section 8, interaction effects)

Why: how the H-statistic is defined, how its null distribution is obtained and what the
authors themselves say about where it misleads.

## Assessment

- Evidence: A. The defining paper, Annals of Applied Statistics, Friedman (Stanford);
  the statistic ships in gbm, pre, iml and PiML. Section 8 is definitions and
  procedure, no error-rate study.
- Reasoning: strong. Separates interaction in the model from interaction in the
  target, names collinearity and sampling noise as sources of false interactions, says
  the normalised statistic is not importance and offers another denominator.
- Interests: own method (RuleFit); the collinearity remedy works only for trees.
- Weigh: trust the definitions and the null recipe. Nothing here measures false
  positive rate or power; the null costs a full refit per replicate and needs an
  additive version of the model.

## Findings

- [method/interpret] Interaction is defined on the function: the effect of changing one
  variable depends on the other; for categorical variables by finite differences. No
  interaction means the function splits into a part without x_j plus a part without
  x_k. Section 8 ^f1
  > or by an analogous expression for categorical variables involving finite differences
- [method/interpret] Built on partial dependence: the model averaged over the data
  values of all other variables, estimated with one model call per data row per
  evaluation point; all functions centred to mean zero. Section 8.1, eq. 39-40 ^f2
  > Partial dependence functions were used in Friedman (2001) to graphically examine the dependence of predictive models on low cardinality subsets of the variables, accounting for the averaged effects of the other variables.
  > In this section all partial dependence functions as well as the predictive model F (x) (25) are considered to be centered to have a mean value of zero.
- [method/interpret] H^2_jk: over the data rows, the squared gap between the two-way
  partial dependence and the sum of the two one-way ones, divided by the sum of squares
  of the two-way partial dependence. Zero without interaction, larger for stronger.
  Section 8.1, eq. 44 ^f3
  > exhibits no interaction between xj and xk and a correspondingly larger value for a stronger interaction effect between them
- [method/interpret] H^2_j (one variable against all others): squared gap between the
  model and one-way partial dependence plus partial dependence on everything else,
  over the sum of squares of the model. Used first to screen variables, then H_jk for
  the partners. Section 8.1, eq. 45 ^f4
  > This quantity will differ from zero to the extent that xj interacts with one or more other variables.
  > Note that only those variables that are deemed globally relevant via (28), (29) and (35) need be considered for interaction effects.
- [method/interpret] H^2_jkl tests a three-way interaction as the part of the three-way
  partial dependence not explained by its pairs and mains; higher orders follow the same
  pattern. Section 8.1, eq. 46 ^f5
  > Analogous statistics testing for even higher order interactions can be derived, if desired.
- [method/interpret] The authors say the normalised pair statistic measures presence,
  not importance: an interaction can be highly significant and matter little. Dividing by
  the whole model's sum of squares (the eq. 45 denominator) instead tracks importance.
  Section 8.1 ^f6
  > It is possible for an interaction effect to be highly significant (see Section 8.3) but not very influential when compared to the other effects in the model.
  > Replacing the denominators in (44) and (46) with that in (45) will cause the resulting statistics to more closely reflect the importance of the corresponding interaction effects to the overall model F (x).
- [method/interpret] Spurious interactions: an accurate model can hold interactions the
  target lacks when predictors are collinear, since an additive effect of one variable
  can be fitted as an interaction with a correlated one; low and higher order then
  can't be told apart. Section 8.2 ^f7
  > These spurious interactions can occur when there is a high degree of collinearity among some (or all) of the predictor variables in the training data
  > it is not possible to easily distinguish between low and higher order interactions among subsets of variables that are highly correlated with each other.
- [method/interpret] Their remedy for collinearity is a tree-growing penalty on new
  split variables along a path, so it does not apply to a net. Section 8.2, 8.4 ^f8
  > The strategy for discouraging spurious interactions outlined in Section 8.2 can only be used with tree based methods however.
- [stats] The statistic is not zero under no interaction: sampling noise puts apparent
  interactions into the fitted model, and predictor associations other than collinearity
  can too, so a reference distribution is needed. Section 8.3 ^f9
  > Sampling fluctuations can introduce apparent interactions in the estimated model F (x).
  > one must have an idea of their value in the absence of such effects
- [stats] Null by parametric bootstrap: fit an additive model F_A (their trees limited
  to 2 terminal nodes), make artificial data sets with the same predictors and responses
  from F_A (regression: plus permuted residuals), refit the full model on each with the
  identical procedure, recompute the statistics; their spread is the reference. Cost: a
  full training run and a full H computation per replicate. Section 8.3 ^f10
  > The idea is to repeatedly compute these statistics on a series of artificial data sets generated from the training data
  > is obtained by applying the identical procedure (modeling parameters, etc.) used to obtain the predictive model F (x) on the original training data
- [stats] For classification the artificial labels are Bernoulli draws with the additive
  model's probability, so the null carries the real label noise and the real joint
  distribution of the predictors. Section 8.3, eq. 48-49 ^f11
  > where bi is a Bernoulli random variable generated with
  > It has the same predictor variable joint distribution as the original training data.
- [method/interpret] Model-agnostic in principle: any black box works, given some way to
  fit the additive null model. Section 8.4 ^f12
  > Thus, this approach can be used with “black-box” prediction models derived by any method providing a way to estimate FA (x)
- [method/interpret] Checked, not there (section 8): no closed-form null, no number of
  bootstrap replicates, no multiple-testing correction over pairs, no false positive
  or power study, nothing on many-level categoricals or on how many rows the partial
  dependence estimates need. ^f13
- [method/interpret] (inferred) For our 10 seats H^2_jk is one number per seat pair (45
  of them), "top and jungle interact", not a champion pair. Naming champion pairs needs
  the numerator's cell value PD_jk(a,b) - PD_j(a) - PD_k(b), which is the pair term of
  the marginal (interventional) decomposition we already get from the exact Möbius
  terms ([[bordt-nshapley-gam-2023#^f9]]); H adds only a normalisation and the null
  recipe. The recipe is the useful part: train the same net on labels drawn from the
  mains-only logistic model (^f11) and measure how much pair mass it learns from a
  near-coin-flip outcome with no pairs in it. Each replicate is a full training run.
  Partial dependence swaps seats independently, so it averages over illegal drafts
  (duplicates, off-role), the collinearity case of ^f7 with no remedy for nets (^f8). ^f14

## Read

- Section 8 (8.1 to 8.4) in full.

## Not read

- Sections 1-7 (RuleFit itself, importance measures): not about interactions.
- Section 9 (illustrations): shows the null distribution in use on artificial and Boston
  data, probably with the number of replicates and how far above the null real
  interactions sit; read if we run the bootstrap null.
