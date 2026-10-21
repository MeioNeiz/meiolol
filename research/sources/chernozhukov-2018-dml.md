---
title: Double/Debiased Machine Learning for Treatment and Structural Parameters (Chernozhukov, Chetverikov, Demirer, Duflo, Hansen, Newey, Robins; Econometrics Journal 2018)
url: https://arxiv.org/pdf/1608.00060v6
kind: paper
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: docs (abstract, section 1, section 5.1 interactive model, empirical 401(k) example)
relevance: high
grade: A/strong
description: The canonical DML paper: estimate one low-dimensional effect with ML-fitted nuisance functions, using Neyman-orthogonal scores (residual on residual, or AIPW) and K-fold cross-fitting
---
# Double/Debiased ML (Chernozhukov et al. 2018)

Why: the standard tool for an effect estimate (a champion, a matchup, mastery) when the
confounders (the rest of the draft, ranks, patch) are high-dimensional; what does it fix
and what not?

## Assessment

- Evidence: A. Canonical reference (tens of thousands of citations), theory plus three
  empirical examples; implemented in DoubleML and EconML.
- Reasoning: strong; explains why naive plug-in fails and what each ingredient buys.
- Interests: none.
- Weigh: DML removes regularisation and overfitting bias given the confounders are
  observed; it does nothing for unobserved ones (skill on the champion, what the picker
  knew), which are our main problem.

## Findings

- [method/causal] [stats] Plugging an ML fit of the confounders into the estimate of an
  effect gives a biased, slower than root-N estimate; two ingredients fix it:
  Neyman-orthogonal scores and cross-fitting. ^f1
  > both regularization bias and overfitting in estimating η0 cause a heavy bias in estimators of θ0
  > (1) using Neyman-orthogonal moments/scores that have reduced sensitivity with respect to nuisance parameters to estimate θ0 , and (2) making use of cross-fitting
- [method/causal] Partially linear model: Y = D theta + g(X) + U and D = m(X) + V; the
  second equation tracks confounding (how the treatment depends on controls). ^f2
  > The second equation keeps track of confounding, namely the dependence of the treatment variable on controls.
- [method/causal] The orthogonal recipe partials X out of the treatment (V = D - m(X)),
  i.e. regress outcome residuals on treatment residuals, any ML learner for m and g. ^f3
  > partialling out the effect of X from D to obtain the orthogonalized regressor V = D − m0 (X)
- [method/causal] Cross-fitting (fit nuisances on other folds, average over folds and
  repeated splits) is a practical device, not just a proof trick; 5 folds gave smaller
  standard errors than 2 in their examples. ^f4
  > its use here is not simply as a device to make proofs elementary (which it does), but as a practical method to allow us to overcome the overfitting/high-complexity phenomena
- [method/causal] [stats] Without unconfoundedness the same estimates are only
  "average predictive effects": DML is no answer to unobserved confounding. ^f5
  > Without unconfoundedness/conditional exogeneity, these quantities measure association
- [method/causal] Extreme propensities are trimmed (0.01 and 0.99) in the interactive
  (AIPW) model to limit weight blow-ups. ^f6
  > we trim the propensity scores at 0.01 and 0.99
- [method/causal] (inferred) For us: treatment D = "this champion in this seat" or the
  player's log mastery on it, X = the other nine picks, ranks, patch, side, region,
  outcome Y = win (linear probability or orthogonal logistic score). The propensity
  m(X) is a pick model: how likely this champion is given the rest of the draft, so
  counter-pick response is partly absorbed when the enemy laner is in X. The unobserved
  part (picker skill, who picked last) remains; pair DML with the user's own mastery as
  an observed proxy and with natural experiments for the rest. ^f7

## Read

- Abstract; section 1 (motivation, regularisation bias, cross-fitting); 5.1 note on
  unconfoundedness; 401(k) example set-up.

## Not read

- Sections 3-4 theory; IV and LATE sections in detail (IV for us is speculative).
