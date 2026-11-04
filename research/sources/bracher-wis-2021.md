---
title: 'Bracher, Ray, Gneiting, Reich 2021: Evaluating epidemic forecasts in an interval format'
url: https://arxiv.org/pdf/2005.12881v3
kind: paper
commit: 
for: [forecast-judging]
looked: 2026-11-04
depth: listed (sections 1-6 and appendix A; arXiv v3, January 2021)
relevance: high
grade: A/fair
description: PLOS Comp Biol 2021 note (arXiv v3) defining the weighted interval score used by the COVID-19 Forecast Hub, with IS at alpha 0.2 worked examples, the width and penalty decomposition, and PIT for binned counts
---
# Bracher, Ray, Gneiting, Reich 2021: Evaluating epidemic forecasts in an interval format

Why: the multi-level interval case: if we score more than the 80% range (point plus
50% and 80%, say), how should levels be weighted, and how do IS at alpha 0.2, WIS,
CRPS and log score compare in practice?

## Assessment

- Evidence: A. Peer reviewed (PLOS Comp Biol 2021), Gneiting a co-author; the WIS
  became the scoring standard of the US and European COVID-19 Forecast Hubs; M4 and
  M5 used related scores.
- Reasoning: fair to strong. Clear worked examples and a 26 model comparison on
  FluSight data; testing guidance is brief and admits no settled answer for
  dependent forecasts.
- Interests: written to justify the Forecast Hub's chosen metric (authors run it).
- Weigh: trust definitions, decomposition and the score comparison. The case for
  distance-sensitive over log score is argued for low-predictability settings.

## Findings

- [stats/scoring] They use the interval score at alpha = 0.2 (80% interval) as a worked
  example; IS is flat inside the interval and has slope 2/alpha outside it.
  Section 2.2, Fig 1 ^f1
  > The interval score ISα is a piecewise linear function which is constant inside the respective prediction interval and has slope ±2/α outside of it.
- [stats/scoring] IS has three readable parts: width (sharpness), a penalty for falling
  below the lower end and one for exceeding the upper end, each proportional to the
  distance and growing with the nominal level. Section 2.2 ^f2
  > The width u − l of the central (1 − α) PI, which describes the sharpness of F .
  > The penalty is proportional to the distance between y and the lower end l of the interval
- [stats/scoring] WIS = (1/(K + 1/2)) (w0 |y - m| + sum_k w_k IS_alpha_k), proper for any
  non-negative weights; with w_k = alpha_k / 2 and w0 = 1/2 it approximates CRPS, is in
  the units of the data, and equals absolute error with only the median. Section 2.2 ^f3
  > it is proper for any set of non-negative (un-normalized) weights
  > the score can be interpreted heuristically as a measure of distance between the predictive distribution and the true observation, where the units are those of the absolute error
  > in the case K = 0 where only the predictive median is used, WISα0 (F, y) is equal to the absolute error
- [stats/scoring] IS can be written from two quantile (pinball) scores:
  IS_alpha = (QS_alpha/2 + QS_1-alpha/2) / alpha, and it is the only proper interval
  score invariant under translation. Appendix A ^f4
  > this is the only available proper interval score that is invariant under translation
- [stats/scoring] Aggregate proper scores by sum or average (keeps propriety);
  inspect strata separately, since high-variance strata can dominate averages.
  Section 2.3 ^f5
  > The natural way of aggregating proper scores is via their sum or average [3], as this ensures that propriety is maintained.
  > Scores for longer time horizons often tend to show larger variability and can dominate average scores.
- [stats/scoring] Testing differences: Diebold-Mariano is the most used test, but has
  no widely accepted extension for dependence across many series or locations.
  Section 2.3 ^f6
  > the most commonly used being the Diebold-Mariano test [22]. However, this test does not have a widely accepted extension to account for dependencies between multiple forecasts made for different time-series or locations.
- [stats/scoring] IS at 0.2 alone has a plateau (no credit for where inside the 80%
  range the outcome lands) and punishes large misses hard while ignoring small
  differences; WIS spreads the penalty more smoothly. Sections 3.1, 4.1 ^f7
  > for the IS0.2 in the middle right panel there is a plateau as it does not distinguish between values falling into the 80% PI
  > the former strongly punishes larger discrepancies between forecasts and observations while ignoring smaller differences
- [stats/scoring] The log score is local and favours the wider of two forecasts on a
  far tail outcome; WIS is distance-sensitive and favours the one whose quantiles are
  closer (y = 190: logS prefers F, WIS 103.9 vs 87.8 prefers G). Section 3.2 ^f8
  > This behaviour of the WIS is referred to as sensitivity to distance [3]. In contrast, the logS is a local score which ignores distance.
- [stats/scoring] Log score degenerates to minus infinity at zero mass; FluSight
  truncated it at -10, which makes it improper. Section 2.1 ^f9
  > we note that when this truncation is performed, the score is no longer proper
- [stats/scoring] Decomposing mean IS or WIS into width and over/under penalties gives
  a readable bar chart of why one model wins (KCDE vs SARIMA: similar widths, SARIMA
  penalised more for misses). Section 4.1 ^f10
  > The decomposition of the WIS into the average width of PIs and average penalty for observations outside the various PIs
  > while KCDE and SARIMA issued forecasts of similar sharpness (average widths of PIs, blue bars), SARIMA is more strongly penalized for PIs not covering the observations
- [stats/scoring] Both FluSight models were conservative: 80% intervals covered 88% and
  100%; PIT histograms showed inverse-U (too wide). Sections 4.1, 4.2 ^f11
  > Both methods are somewhat conservative, with 80% PIs covering 88% (SARIMA) and 100% of the observations (KCDE).
- [stats/scoring] PIT shapes: L shaped means forecasts biased low, J shaped biased high,
  U underdispersed, inverse-U overdispersed; they used Czado's non-randomised PIT for
  binned counts. Section 4.2 ^f12
  > L-shaped PIT histograms indicate a downward bias of forecasts, while a J shape indicates an upward bias.
  > we employed the non-randomized correction suggested in [13]
- [stats/scoring] Over 26 FluSight models, WIS (11 levels) and CRPS agree almost
  perfectly; interval scores agree only moderately with the log score, which harshly
  punishes two models that were too sharp with light tails; all scores agree on the
  top three. Section 4.3 ^f13
  > Agreement between the WIS and CRPS is almost perfect
  > Agreement between the interval-based score and the logS is mediocre
  > Interestingly, all scores agree that the three best models are LANL DBMplus, Protea Cheetah and Protea Springbok.
- [stats/scoring] Point forecasts: score the median with absolute error, on the same
  scale as WIS; AE, CRPS and WIS are dominated by large targets, which they defend
  over relative errors like MAPE. Section 5 ^f14
  > This implies that teams should report the predictive median as a point forecast [32].
  > Using the absolute error in combination with WIS is appealing as both can be reported on the same scale
  > Relative measures like the MAPE would treat both the same.
- [stats/scoring] In low-predictability settings they prefer distance-sensitive scores
  (CRPS, WIS) to the log score, which is not robust and needs tail assumptions.
  Section 6 ^f15
  > distance-sensitive scores like the CRPS or WIS are an attractive option
- [stats/scoring] (inferred) If Meio exposes only a point and an 80% range, the WIS with
  K = 1 is (1/1.5)(0.5 |y - m| + 0.1 IS_0.2), which combines the point estimate and the
  range in one proper number on the data's scale; with only the range, IS_0.2 alone
  ignores the point. ^f16
- [stats/scoring] (inferred) The width plus penalty decomposition answers the gate's
  two halves directly: Meio vs patch should show smaller width bars without larger
  penalty bars; Meio vs 30 days should show smaller penalties (better accuracy). ^f17

## Read

- Sections 1-6 and Appendix A of arXiv v3 (text of figures garbled, captions read).

## Not read

- PLOS published version (same content assumed); references [33]-[38] on non-central
  interval scoring.
