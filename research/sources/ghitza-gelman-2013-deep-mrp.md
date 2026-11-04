---
title: 'Ghitza and Gelman 2013: Deep interactions with MRP, election turnout and voting patterns among small electoral subgroups'
url: http://www.stat.columbia.edu/~gelman/research/published/misterp.pdf
kind: paper
commit:
for: [thin-cell-ranges]
looked: 2026-11-04
depth: docs (abstract, statistical methods, computation, graphical checking, turnout adjustment, discussion)
relevance: medium
grade: A/fair
description: American Journal of Political Science 2013 (Columbia); multilevel regression and poststratification for cells crossed by income x ethnicity x state (+ region), each interaction batch with its own Gaussian scale, binomial cells, fitted by glmer, adjusted to known totals by a logit shift
---
# Ghitza and Gelman 2013: Deep interactions with MRP, election turnout and voting patterns among small electoral subgroups

Why: thin-cell-ranges sub-question: how MRP handles deep interaction cells (our champion
x champion x bracket x region) with a structured prior per interaction, and whether it
says anything about per-cell ranges.

## Assessment

- Evidence: A. Widely cited AJPS paper by Gelman (a recognised expert) and Ghitza;
  basis of the mrp R package and later MRP practice.
- Reasoning: fair. Explains the model build-up and the checks; no simulation or
  coverage study, uses point estimates of variances as an approximation to full Bayes.
- Interests: own method and package.
- Weigh: the structure transfers directly (batches of interaction terms, each with its
  own scale, binomial cells); the Gaussian priors and the variance point estimates are
  conveniences, not claims about tails. Per-cell intervals are not studied.

## Findings

- [stats/eb] The cell model is binomial with a logit sum of main effects and every
  two- and three-way interaction; each batch of coefficients gets its own normal scale
  sigma_S with a weak inverse chi-squared hyperprior. Statistical methods ^f1
  > where each batch of coefficients has its own scale parameter
  > Because the binomial distribution has an internally specified variance, it is possible to estimate all the variance components, up to and including the three-way interactions.
- [stats/eb] Deep cells grow fast: even 5 incomes x 4 ethnicities x 51 states is
  1,020 cells, and raw cell estimates were too noisy to show structure despite over
  15,000 respondents. Introduction, graphical checking ^f2
  > Even this simple example totals 5 × 4 × 51 = 1,020 cells, making the task nontrivial.
  > raw estimates are noisy and insufficient to reveal any clear structure, despite a sample size exceeding 15,000.
- [stats/eb] A coarser nested grouping (region, a function of state) is added as its
  own varying intercept with its own interactions, to catch effects too weak per state;
  no state x region term since region is determined by state. Statistical methods ^f3
  > we can add region as an additional predictor to capture effects that can be found for large areas of the country but perhaps do not have enough data to be captured by the state-level groups that are already in the model.
- [stats/eb] A predictor can enter both as a linear term and as a categorical batch, so
  the fit is partially pooled towards linearity. Computation ^f4
  > Including both in the same model allows a nonlinear fit that partially pools toward linearity
- [stats/eb] Fitted by approximate marginal maximum likelihood (glmer), taken as an
  approximation to full Bayes, which they would prefer. Computation ^f5
  > we have been using the approximate marginal maximum likelihood estimates obtained using the glmer() program in R
- [stats/eb] Deciding whether a deeper interaction is needed: compare the residual
  cell-level variance with the binomial sampling variance; much larger means add the
  three-way term (it was not needed here). Computation ^f6
  > If the residual variance is much higher than would be expected from the sampling model, this implies that three-way interactions should be included.
- [stats/eb] Missing interactions were caught by readers of published maps and by
  plots of fitted cells against raw data, not by coefficient checks. Graphical checking ^f7
  > politically savvy readers noted problems in some of the state/income categories which could be traced back to interactions between ethnicity, income, and state that had not been included in the earlier versions of our model.
- [stats/eb] Benchmarking: a constant logit shift per state makes cell turnout add up
  to the known state total. Data sources, turnout ^f8
  > This process simply applies a constant logistic adjustment
- [stats/eb] They read MRP output as smoothed data and recommend comparing it with raw
  summaries at each stage. Discussion ^f9
  > Given that our model is necessarily imperfect, we can interpret our estimates as smoothed versions of the data.
- [stats/eb] Checked, not there: per-cell interval coverage, uncertainty from the
  variance estimates, and non-Gaussian or sparse priors on interaction terms; error
  bars are only quoted (about 3% s.e. per curve point). ^f10
- [stats/eb] (inferred) For us: one batch (with its own scale or mixture) per pair kind
  (lane matchup, duo, cross-lane), plus coarser nested batches (pair x bracket, pair x
  region) as deviations from the pooled pair term, is the MRP pattern; f6 is a cheap
  test for whether a bracket x pair batch is needed at all: residual variance of the
  pair cells against binomial variance. ^f11
- [stats/eb] (inferred) MRP's Gaussian batches have the same blind spot as our current
  prior: nothing in the paper addresses a few large interaction cells among many null
  ones; swapping each batch's normal for a spike-and-slab mixture keeps the structure
  and fixes the tail. ^f12

## Read

- Abstract, introduction, Statistical methods (notation, poststratification, model
  build-up, survey weights, computation), graphical checking opening, turnout
  adjustment, discussion.

## Not read

- Data sources detail and the substantive 2004/2008 results (figures 3-6).
