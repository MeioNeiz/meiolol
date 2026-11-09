---
title: 'McGough et al. 2020: Nowcasting by Bayesian Smoothing (NobBS)'
url: https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1007735
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, results, discussion, methods)
relevance: medium
grade: B/strong
description: PLOS Comp Bio 2020 paper and R package nowcasting counts still filling from reporting delays (chain ladder plus a random walk on the true count), tested against Höhle and an der Heiden 2014 on dengue and US ILI
---
# McGough et al. 2020: Nowcasting by Bayesian Smoothing (NobBS)

Why: our newest days are still filling as late games arrive; how do nowcasting methods
estimate the complete count (and later the complete rate) from a reporting triangle, and
what did they gain over the Höhle-an der Heiden (HH) benchmark?

## Assessment

- Evidence: B. Peer reviewed, 989 weekly dengue nowcasts and 170 ILI nowcasts, a
  published R package on CRAN; Lipsitch and Johansson are established in the field.
- Reasoning: strong. Takes apart which model piece helps, tests a simulated time-varying
  delay, and lists its own failures (outlier weeks, short windows).
- Interests: authors of the method compared to one benchmark.
- Weigh: it nowcasts counts, not rates; the delay is assumed the same for every case in
  a window, so late arrivals that differ from early ones (our leaky rank) are not
  modelled. Trust the structure (reporting triangle, chain ladder, smooth prior on the
  latest periods); the gains are for epidemic counts.

## Findings

- [stats] Nowcasting: estimate the complete count for a period from a series known to be
  incomplete because of reporting delays; the approach comes from insurance claims
  (chain ladder). Abstract, Introduction ^f1
  > Nowcast approaches attempt to estimate the complete case counts for a given reporting date, using a time series of case reports that is known to be incomplete due to reporting delays.
- [stats] Model: counts n(t,d) for period t and delay d are Poisson or negative binomial
  with log mean alpha_t + beta_d (alpha the true signal, beta a Dirichlet delay vector);
  a first-order random walk on alpha_t ties each period to the last. Methods ^f2
  > This model is an adaptation of the general chain ladder model, proposed in the actuarial literature as an approach to nowcast the number of claims at time _t_ with delay _d_
  > We therefore model _α__t_ as a first-order random walk
- [stats] [stats/scoring] Dengue (989 weeks): NobBS rRMSE 0.464, mean score 0.274, 95% PI
  coverage 0.85; HH rRMSE 1.24, score 0.161, coverage 0.90, and HH made nowcasts in only
  55% of weeks. Results, Table 1 ^f3
  > NobBS approach achieved relatively smooth and accurate tracking of the dengue time series (rRMSE = 0.464, average score = 0.274)
  > The 95% PI coverage was 0.85
- [stats/scoring] ILI (stable delays): HH had the better point estimate (rRMSE 0.062 vs
  0.074) but its 95% intervals covered 0% of weeks against NobBS's 100%; scores 0.017
  vs 0.218. Results, Table 1 ^f4
  > resulting in both higher scores (NobBS average score = 0.218 vs. HH average score = 0.017) and 100% coverage by the 95% prediction intervals compared to 0% coverage for the HH
- [stats] Simulated time-varying delays (faster reporting in busy weeks): NobBS rRMSE
  0.302 vs HH 0.621; the random walk on the true count, not the delay model, carries
  the gain. Results ^f5
  > NobBS outperformed the HH in terms of confidence (NobBS average score = 0.06 vs. HH average score ≈ 0), point estimates (NobBS rRMSE = 0.302 vs. HH rRMSE = 0.621)
- [stats] Accuracy rises with the share reported at delay 0: fewer cases left to
  predict. Discussion ^f6
  > When a larger proportion of cases were reported with no delay, as was the case for ILI compared to dengue, the point estimate accuracy was higher.
- [stats] Checked, not there: the delay probability is the same for every case and
  period in the window; changes in delay are only followed by shortening the window
  (more volatile) or by HH's prespecified change points. Discussion ^f7
  > the estimated probability of a case occurring with delay = _d_ is assumed to apply to all reporting weeks in the moving window
- [stats] Window trade-off: short windows track delay changes but make the random-walk
  variance volatile, which overshot after sudden jumps. Discussion ^f8
  > In our experiments, the combination of shorter moving windows with rapid changes in cases reported produced large estimated variances, which often decreased the accuracy of nowcasts.
- [stats] (inferred) For meiolol: games per (day, store-lag bucket) is a reporting
  triangle; a chain ladder gives each recent day's expected final count, so a day's
  stats can be shown with its fill fraction or reweighted. It does not fix the rank
  leak: that needs the outcome-dependent part modelled per lag (see Keogh, Höhle-style
  covariate delays). ^f9

## Read

- Abstract, Results (Table 1 text, time-varying simulation), Discussion, Methods model.

## Not read

- Supplementary tables S2-S5 (window sizes, constant vs time-varying numbers).
