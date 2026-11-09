---
title: 'van Everdingen, Aghina 2003: Forecasting the international diffusion of innovations, an adaptive estimation approach'
url: https://repub.eur.nl/pub/1093/ERS%202003%20073%20MKT.pdf
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, introduction, results, tables 4-6, figure 6)
relevance: medium
grade: C/strong
description: Erasmus ERIM working paper; Bass diffusion across 15 EU countries with a Putsis mixing parameter for cross-country influence, estimated by an augmented Kalman filter; ablates the cross-country weight against country-alone and one-market fits
---
# van Everdingen, Aghina 2003: Forecasting the international diffusion of innovations

Why: context-aware-models, day-0 sub-question: how a lagging market's forecast borrows
from others, how the transfer weight is set, and how much it helps.

## Assessment

- Evidence: C. Working paper (a version later in a marketing journal, not checked);
  two innovations (home Internet, mobile phones) x 15 EU countries, yearly data, 172
  one-step forecasts. Small sample, no significance tests.
- Reasoning: strong. Sweeps the cross-country weight from "one market" to "each
  country alone" and splits the gain into its two sources (adaptive updating vs the
  international term), and says which mattered more.
- Interests: none beyond their own method.
- Weigh: the sweep shape (an interior optimum, both ends worse) is the useful result;
  the size of the international gain is small next to the adaptive one.

## Findings

- [method/dynamics] Cross-country influence is one Bernoulli mixing weight Phi: 0
  treats the EU as one market, 1 as fully separate countries; in between, borders
  matter but processes influence each other. Results section ^f1
  > When F equals zero, the European Union is modeled as one country without borders that influence the diffusion process.
- [method/dynamics] Fixing Phi from 0 to 1, forecast error is lowest at 0.7, rises
  for isolated countries (1) and rises steeply for one pooled market (0); the best value
  matched Putsis et al.'s 0.72 for PCs. Figure 6 ^f2
  > When the borders are considered to be non-existent (F=0) the forecasting error increases dramatically.
  > The MAPE’s are lowest for F=0.7, a value which is close to the value for Φ found by Putsis et al. (1997) for the diffusion of personal computers (PCs), namely Φ=0.72.
- [method/dynamics] MAPE, Internet, 1/2/3 years ahead: full model 8/14/12%, same
  model with the cross-country term off (Phi=1) 9/16/16%, classic per-country Bass
  fit 14/27/39%; mobile phones 7/15/23%, 8/17/25%, 13/24/32%. Table 5 ^f3
  > The biggest contribution to the better performance is, however, made by the adaptive estimation technique. We see only minor improvements in the forecasting errors for the IA approach with the international dimension switched on as compared to the IA method with Φ=1.
- [method/dynamics] Countries are matched on size, penetration ceiling and launch time
  before pooling (Dekimpe et al. 1998), so a late country's start borrows from
  earlier ones in proportion. Conclusions ^f4
  > we apply a sample-matching procedure by matching the samples from the different countries on three dimensions, i.e. (1) the size of the country, (2) the penetration ceiling, and (3) the time of introduction of the innovation.
- [method/dynamics] The Kalman filter starts from a prior and updates each country's
  parameters as observations arrive; results are robust to the ceiling prior but
  sensitive to the speed prior q (q +25% raised 3-step MAPE from 17.6 to 40.2).
  Table 6 ^f5
  > The results are the most sensitive for the initial estimate of parameter q.
- [method/dynamics] Earlier work: lag countries diffuse faster than the lead country
  (Takada and Jain 1991); Ganesh et al. 1997 model a one-way lead-to-lag learning
  effect. Section 2 ^f6
  > Takada and Jain (1991) found faster innovation diffusion in the so-called lag countries
- [method/dynamics] (inferred) For us: the gain from borrowing other regions was
  small next to the gain from updating a prior well as data arrive, which fits our
  null result for one "early platforms" level term; the transferable lesson is a
  single partial-pooling weight swept on held-out patches, with both ends (EUW1 alone,
  world pooled) as baselines. ^f7
- [method/dynamics] Checked, not there: the weight Phi is not estimated per pair of
  countries or per product, it is fixed or swept; no lead-time-dependent weight. ^f8

## Read

- Abstract, introduction, results and conclusions; tables 4-6 and figure 6 via
  pdftotext.

## Not read

- Appendix on the AKF(C-D) equations and the initial estimate of Phi.
