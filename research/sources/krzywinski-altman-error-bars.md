---
title: 'Krzywinski and Altman 2013: Points of Significance, Error bars'
url: https://fortinlab.bio.uci.edu/resources/POS_Error_bars.pdf
kind: article
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: listed (whole two-page column)
relevance: medium
grade: A/fair
description: Nature Methods 2013 column on what s.d., s.e.m. and confidence-interval bars mean and how readers misread them
---
# Krzywinski and Altman 2013: Points of Significance, Error bars

Why: the spread band on a matchup curve: should it show how games vary (percentiles,
s.d.) or how sure we are of the mean (CI)? Players misread both.

## Assessment

- Evidence: A. Nature Methods "Points of Significance" column, widely used teaching
  reference; Altman is a senior statistician.
- Reasoning: fair. Short, clear, cites a survey of misreading.
- Interests: none.
- Weigh: about scientific figures, but the distinction maps directly to our two bands.

## Findings

- [stats] [ux] Readers misjudge error bars: asked for the separation needed for P = 0.05,
  only 22% were within a factor of 2. ^f1
  > only 22% of respondents were within a factor of 2
- [stats] [ux] s.d. bars show the spread of the population and predict the range of new
  samples; they are not the error in the mean. ^f2
  > Error bars based on s.d. inform us about the spread of the population and are therefore useful as predictors of the range of new samples.
  > be ready to help your reader understand that the s.d. bars reflect the variation of the data and not the error in your measurement.
- [stats] s.e.m. = s.d. / sqrt(n) shows uncertainty in the mean and shrinks with n. ^f3
  > Unlike s.d. bars, error bars based on the s.e.m. reflect the uncertainty in the mean and its dependency on the sample size
- [stats] 95% CI is about 2 s.e.m. for n > 15; a CI is more intuitive than s.e.m. ^f4
  > 95% CI ≈ 2 × s.e.m. (n > 15).
  > CIs are a more intuitive measure of uncertainty and are popular in the medical literature.
- [stats] [ux] Always state which bar type is shown. ^f5
  > The first step in avoiding misinterpretation is to be clear about which measure of uncertainty is being represented by the error bar.
- [stats] [ux] (inferred) For players the useful band is the game-to-game spread
  ("in half of games you'll be between X and Y gold at 10"), i.e. percentiles of the
  observed diffs, labelled as such; the uncertainty of the mean belongs in n, the
  grey-out and a thin CI line or text, not as the main band. Two bands of different
  meaning on one chart will be misread. ^f6

## Read

- Whole column
