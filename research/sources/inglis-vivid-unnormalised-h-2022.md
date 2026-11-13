---
title: 'Inglis, Parnell, Hurley 2022: Visualizing variable importance and variable interaction effects in machine learning models'
url: https://arxiv.org/pdf/2108.04310
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (section 2.2, section 5 discussion, appendix)
relevance: high
grade: B/fair
description: JCGS 2022 (Maynooth; R package vivid); uses the square root of the mean numerator of Friedman's H^2 because the normalised statistic showed many strong false interactions among noise variables on the Friedman benchmark; correlated predictors still give a false pair
---
# Inglis, Parnell, Hurley 2022: Visualizing variable importance and variable interaction effects in machine learning models

Why: evidence for the H-statistic's false positives under weak effects, and whether the
unnormalised version fixes them.

## Assessment

- Evidence: B. Published in the Journal of Computational and Graphical Statistics, with
  a CRAN package (vivid). The evidence on H is one simulated data set (1,000 rows, 10
  uniform inputs), one random forest, shown as heatmaps: no repeated runs, no false
  positive rate, no numbers.
- Reasoning: fair. Names the cause of each failure (denominator near zero, biased
  partial dependence) and admits the fix leaves the correlation problem.
- Interests: a visualisation paper; the unnormalised H is what their package plots.
- Weigh: trust the direction (normalised H lights up noise pairs; unnormalised does
  not; correlation still fools both). Sizes and rates are not measured. Signal there is
  strong and continuous, far from our case.

## Findings

- [method/interpret] Small-denominator failure: when the pair's two-way partial
  dependence is flat, noise in the numerator gives a high H. Section 2.2 ^f1
  > When the denominator in Equation 2 is small, the partial dependence function for variables j and k is flat, and small fluctuations in the numerator can yield spuriously high H-values.
- [method/interpret] Biased partial dependence also inflates H: models whose one-way
  partial dependence shrinks towards the mean (tree fits can't predict outside the
  training range), and correlated predictors. Section 2.2, appendix ^f2
  > Biased partial dependence curves will also lead to inflated H. This occurs in some machine learning approaches which exhibit regression to the mean in their oneway partial dependencies.
  > where predictions cannot lie outside the range of training set responses
- [method/interpret] Their fix: the square root of the mean numerator of H^2, no
  denominator. On the scale of the response; fewer spurious pairs; does not cure
  correlated predictors. Section 2.2, eq. 3 ^f3
  > This reduces the identification of spurious interactions and provides results that are on the same scale as the response (for regression). It does not, however, remove the possibility that some large H-values arise from correlated predictor variables.
- [method/interpret] For a binary classifier they compute partial dependence and H on
  the logit scale. Section 2.2 ^f4
  > using the logit scale for both the partial dependence and in calculation of the H-statistic when fitting a classification model with a binary response
- [method/interpret] Evidence: Friedman benchmark (one true pair x1:x2, three more
  active inputs, five noise inputs), 1,000 rows, random forest. Normalised H found the
  true pair but also many strong pairs among the noise inputs; with unnormalised H
  those vanished. Appendix, Figure 10 (a), (b) ^f5
  > we simulate 1,000 observations and fit a random forest.
  > However, in (a) there are numerous spurious strong interactions among the noise variables. In (b) using un-normalized H these spurious strong interactions disappear.
  > The culprit here is the denominator in Equation 2
- [method/interpret] Correlation still fools the unnormalised version: making x5
  correlate about 0.92 with x4 (both purely additive) produced a moderate x4:x5
  interaction. Appendix, Figure 10 (c) ^f6
  > thus introducing a strong correlation (≈ 0.92) between x4 and x5
  > In (c) (un-normalized H) a moderate spurious interaction between the correlated variables x4 and x5 is detected
- [method/interpret] On real data (college applications) the highest H values sat on
  highly correlated variables with similar marginal effects and were judged spurious
  from the bivariate plots. Section 3, Figure 4 ^f7
  > suggesting that the the high H-values between these variables are likely to be spurious
- [method/interpret] Cost: O(n^2) predictions per pair. A 14 x 14 matrix on a GBM took
  about 16 s on 30 sampled rows; a 17-predictor random forest about 79 s on 20 rows
  (laptop). Section 2.2, section 5 ^f8
  > the 14 × 14 H-matrix for the GBM fit in Figure 6 computed on 30 randomly selected observations took approximately 16 seconds
  > taking approximately 79 seconds, even though here we used just 20 randomly selected observations
- [stats] Sampling rows to save time raises the variance of the partial dependence and
  of H; they still ran on 20-30 rows. Section 2.2 ^f9
  > Sampling from the training set will reduce the time, though at a cost of increasing the variance of the partial dependence estimates and the H-statistic.
- [method/interpret] Untested suggestions: build the same measure on ALE functions
  (made to counter partial dependence bias), or use Hooker's or Greenwell's measures;
  whether those avoid the problems is left open. Section 5 ^f10
  > Another option might be to replace the partial dependence f in Equation 3 with the corresponding ALE function, giving a new interaction measure.
  > whether these measures avoid the issues identified with the use of H
- [method/interpret] Checked, not there: no null distribution, test or threshold for the
  unnormalised H; no repeated simulations or error rates; no weak-signal or near-chance
  outcome; no many-level categorical inputs (factors appear only in the plots). ^f11
- [method/interpret] (inferred) For us the unnormalised form on the logit scale (^f3,
  ^f4) is the right one: it is in log-odds, so directly comparable with our shrunk pair
  blocks, and it can't blow up where a seat pair or champion pair has a flat joint
  effect, which near a coin flip is most of them. It is then just the root mean square
  of the purified pair term, with no test attached (^f11), and seat dependence (no
  duplicates, counter picks) is the correlation case it does not fix (^f6). ^f12

## Read

- Section 2.2 (partial dependence and H), the H paragraphs of section 3 (Figure 4) and
  section 5, the appendix with Figure 10's caption.

## Not read

- Sections 2.3-4 (heatmap, network, zenplot displays, case studies): visualisation
  design, not about whether H is right.
- Apley and Zhu 2020 (ALE), cited as the source on partial dependence bias under
  correlation: lead.
