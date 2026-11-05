---
title: 'Kale, Nguyen, Kay, Hullman 2019: Hypothetical Outcome Plots Help Untrained Observers Judge Trends in Ambiguous Data'
url: https://mucollective.northwestern.edu/files/2018-HOPsTrends-InfoVis.pdf
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-05
depth: listed (abstract, intro, E1 results, E2 results, discussion, conclusion)
relevance: medium
grade: B/strong
description: IEEE TVCG (InfoVis 2018): on an NYT jobs-report task, untrained MTurk users judge the underlying trend from noisier data with animated draws (HOPs) than with error bars or static line ensembles
---
# Kale, Nguyen, Kay, Hullman 2019: Hypothetical Outcome Plots Help Untrained Observers Judge Trends

Why: do animated draws beat error bars for lay readers on a realistic news-style
judgement? (Hullman et al 2015 is in [[hullman-hops-2015]]; this is the follow-up.)

## Assessment

- Evidence: B. IEEE TVCG paper, preregistered (OSF), psychometric functions fit per
  user over many trials; but small samples (E1 about 50 within-subjects after
  exclusions from 62 MTurk Masters), one task.
- Reasoning: strong. Ties to vision science, isolates animation from sampling in E2,
  reports null and attenuated results, says when not to show uncertainty.
- Interests: Kay and Hullman's lab proposed HOPs.
- Weigh: a time-series trend task, not single-number ranges; take the direction (draws
  beat summary bars) more than the size. Later work ([[kale-effect-size-strategies-2020]])
  found HOPs no better than intervals for "A beats B".

## Findings

- [ux/uncertainty] With HOPs users identified the underlying trend from less evidence
  than with error bars (lower just-noticeable differences). 4.2.1 ^f1
  > We found that JNDs were lower in the HOPs condition (Fig. 6, left) than in the error bars condition
  > participants could successfully discriminate the underlying trend in the job market for more ambiguous stimuli when using HOPs as a decision aid.
- [ux/uncertainty] Sampling-style displays beat summary statistics for decisions, in
  line with frequency-format research. 6.1 ^f2
  > This suggests that sampling-oriented presentations of uncertainty lead to better comprehension of uncertainty for the purpose of perceptual decision-making than summary statistical representations of uncertainty.
- [ux/charts] Animation itself helps at 400 ms a frame (vs the same lines drawn static),
  but the benefit fades at 100 ms a frame. 6.1 ^f3
  > We find that participants in the regular HOPs condition (400 ms per sample) are more consistently sensitive to the underlying trend in samples from a noisy time series than participants in the line ensembles condition. However, this effect is attenuated for fast HOPs (100 ms per sample).
- [ux/uncertainty] Error bars are easily misread, perhaps because readers take them as
  the probability of the estimate; gradient and violin plots are also hard for many.
  1 Introduction ^f4
  > error bars encoding confidence intervals or standard errors are easily misunderstood [6, 31]
  > the nuances of statistical abstractions make it hard for many people to interpret probability density plots like gradient plots and violin plots.
- [ux/uncertainty] When the task is reading a point estimate, a direct mark may be
  better; HOPs lose to error bars for estimating a central value; hiding uncertainty
  risks false security. 6.2 ^f5
  > If uncertainty is unlikely to aid interpretation (e.g., when reading a point estimate), a direct encoding of central tendency might be preferred.
  > However, failing to show uncertainty may lead to a false sense of security in visualized outcomes
- [ux/uncertainty] Checked, not there: no effect of display on how well confidence
  tracked accuracy. 6.1 ^f6
  > the efficacy of participants’ confidence monitoring was not systematically impacted by visualization conditions.
- [ux/charts] (inferred) Animation suits a detail page for one question, not a dense
  table; for meio.lol tables a static encoding (fade, words) remains the choice. ^f7

## Read

- Abstract, introduction, Experiment 1 and 2 results, discussion, conclusion.

## Not read

- News survey (section 3) in detail; model specification.
