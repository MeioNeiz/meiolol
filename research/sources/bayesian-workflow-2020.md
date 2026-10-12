---
title: 'Bayesian Workflow (Gelman, Vehtari, Simpson et al., 2020)'
url: https://arxiv.org/pdf/2011.01808
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (sections 2.1-2.2, 3.4, 5.2, 6.2 opening, 7, 8, 10.6, 12.2-12.4)
relevance: high
grade: A/strong
description: Long arXiv paper (2020) by the Stan team on iterative model building: start from templates, expand modules in response to checks, compare a sequence of models, and the overfitting risk of data-driven expansion
---
# Bayesian Workflow (Gelman, Vehtari, Simpson et al., 2020)

Why: how do experienced modellers decide the next model change, how do they compare a
sequence of models, and what do they say about overfitting from that iteration?

## Assessment

- Evidence: A. Canonical reference by recognised experts (Gelman, Vehtari, Carpenter,
  Bürkner and others behind Stan, loo, brms); draws on many applied projects (election
  forecasting, pharmacology, golf).
- Reasoning: strong. Explains why to iterate, gives worked examples, and has a whole
  section (12.3) on the cost of iterating: double dipping and forking paths.
- Interests: authors' own tools (Stan, loo, projpred) are recommended throughout.
- Weigh: trust the workflow advice; it is about Bayesian models with a human in the
  loop, not automated search, and gives no numbers on how much criticism-led
  expansion beats alternatives. Our models are shrunk additive groups, close enough to
  its multilevel examples for the advice to port.

## Findings

- [method] Start from a template: adapt a model from a similar problem, which also
  tells you which directions of model space are likely to give useful elaborations.
  `2.1` ^f1
  > by looking at the results from the model template we know in which direction of the model space there are likely to be useful elaborations or simplifications.
- [method] Models are built from modules treated as placeholders to replace (normal to
  long tails, linear to splines, add measurement error, tighten priors); name modules,
  not whole models. `2.2` ^f2
  > A Bayesian model is built from modules which can often be viewed as placeholders to be replaced as necessary.
- [method] [lab] Expansion is triggered by something specific: new data, a failure of
  the model on existing data, or computational trouble; their election model was
  expanded after a named failure (swing-state correlations). `7` ^f3
  > Model expansion can come in response to new data, failures of models fit to existing data, or computational struggles with existing fitting procedures.
- [method] [stats] Adding parameters is relaxing a prior that was concentrated at zero,
  so not all new terms can be allowed a big effect at once. `7.2` ^f4
  > when more parameters are added, it can be necessary to assume that not all of them can have a big effect in the model at the same time. One way to see this is to consider the addition of a parameter as a relaxation of a prior distribution that was previously concentrated at zero.
- [stats] As a model grows on the same data, priors on all parameters need to get
  tighter, or the information budget is spread too thin. `7.3` ^f5
  > Often as the model becomes more complex, all of the priors need to become tighter.
- [method] [lab] Models form a partial order (a topology); the aim is to navigate among
  neighbours, not average over all; the Automatic Statistician searches such a space
  using inference and model criticism. `7.4` ^f6
  > Our interest here is not in averaging over models but in navigating among them
  > which searches through models in specified but open-ended classes (for example, time series models and linear regression models), using inference and model criticism to explore the model and data space.
- [method] [stats] Grouping a predictive check by a covariate not in the model exposes
  misfit the marginal check hides: one subgroup falls systematically outside the
  replications. `figure 14` ^f7
  > The same model and data but with the check grouped by a covariate that was not included in the model but in fact influenced the response.
- [method] [stats] Cross-validation diagnostics worth running: calibration of held-out
  predictions, which observations or groups are hardest to predict, and influence;
  importance-sampling LOO avoids refitting. `6.2` ^f8
  > identifying which observations or groups of observations are most difficult to predict,
- [lab] [stats] Keep the old models: the sequence is for understanding how inference
  for the quantity of interest changes with each expansion, not for picking or
  averaging. `8.1` ^f9
  > the extra “workflow” part is that we still keep the old model, not for the purpose of averaging but for the purpose of understanding what we are doing.
- [stats] Fitting many models raises researcher degrees of freedom: overfitting if a
  single best is picked. `8.1` ^f10
  > we also have to be concerned with researcher degrees of freedom (Simmons et al., 2011), most directly from overfitting if a single best model is picked
- [stats] With non-negligible uncertainty in a cross-validation comparison, do not just
  take the best CV model; with many similar candidates, selecting by minimum CV error
  overfits. `8.2, 8.3` ^f11
  > if there is non-negligible uncertainty in the comparison (Sivula et al., 2020), we should not simply choose the single model with the best cross validation results
  > If we have many models making similar predictions, selecting one of these models based on minimizing cross validation error would lead to overfitting and suboptimal model choices
- [stats] [method] Alternative to fitting each candidate: fit one expanded model with
  all candidates and use projection predictive selection of submodels, which avoids the
  overfitting of searching a big space. `8.3` ^f12
  > the projection predictive approach avoids it by examining only the projected submodels based on the expanded model’s predictions and not fitting each model independently to the data.
- [lab] Fail fast: little work exists on wasting as little time as possible on models
  that will be abandoned; they think methods should be judged on it. `3.4` ^f13
  > There is a large literature on approximate algorithms to fit the desired model fast, but little on algorithms designed to waste as little time as possible on the models that we will ultimately abandon.
- [method] Debug a failing model from both ends: strip it down until it works, and
  build up from a simple model until the problem appears. `5.2` ^f14
  > stripping it down until you get something that works; and from the other direction starting with a simple and well-understood model and gradually adding features until the problem appears.
- [method] Bigger data need bigger models: the golf model's second expansion added an
  error term with no domain meaning, to absorb unexplained variation. `10.6` ^f15
  > This is an example of the general principle that bigger data need bigger models.
- [stats] [lab] Iterating on discrepancies double-dips the data; they avoid the worst
  of it by not searching for the best-fitting model, and by embedding candidates in a
  larger model instead of selecting among many. `12.3` ^f16
  > model improvement is conditioned on discrepancy between the currently considered model and the data, and thus at least some aspects of the data are used more than once.
  > when we might be selecting among a large set of possible models, we instead embed these in a larger model, perform predictive model averaging, or use all of the models simultaneously
- [method] Building from a simple model lets you stop when the model seems good enough,
  which saves effort. `12.2` ^f17
  > it can be efficient in human time to start from a simpler model and stop when the model seems to be sufficiently good.
- [lab] Checked, not there: no power or minimum detectable effect reasoning for a
  model change, no way to rank candidate expansions before fitting them. ^f18

## Read

- 2.1-2.2, 3.4, 5.2, 6.2 opening and figure 14, 7 (all), 8 (all), 10.6, 12.2-12.4.

## Not read

- 2.3-2.5, 3.1-3.3, 4 (fake data, SBC), 5.3-5.10, 6.1, 6.3-6.4, 9, 10.1-10.5, 11, 12.1,
  12.5-12.6: computation, priors, software practice; 4.1 fake-data simulation might
  matter for checking the harness detects a planted effect.
