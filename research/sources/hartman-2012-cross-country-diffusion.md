---
title: 'Hartman, Mallick, Sudhir, Talukdar 2012: Investigating cross-country influence dynamics in new product diffusions'
url: https://hartman.byu.edu/docs/files/HartmanMallickSudhirTalukdar_CCDiff.pdf
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-06
depth: docs (abstract, introduction, sections 2.1, 4, 5.1-5.2)
relevance: medium
grade: B/fair
description: Working paper version (UConn, Texas A&M, Yale, Buffalo; 2012) of a hierarchical Bayes Bass model over 7 durables in 31 countries, adding other countries' adoption weighted by a chosen proximity matrix (tourism, trade, culture, distance); out-of-sample MSPE vs a plain per-country Bass model
---
# Hartman et al. 2012: cross-country influence dynamics in new product diffusions

Why: context-aware-models, day-0 sub-question: when one market's outcome feeds another's
forecast, how is the cross-market weight built and how much does it help.

## Assessment

- Evidence: B. Established marketing authors (Sudhir, Talukdar), 7 products x 31
  countries, out-of-sample forecasts 1-3 years beyond the sample. Working paper copy
  on an author's site; a journal version not checked.
- Reasoning: fair. Compares 4 proximity measures and 16 combinations; improvements
  are relative MSPE against a plain Bass model, with no error bars in what I read.
- Interests: authors' own models.
- Weigh: the ranking of proximity measures (geography weakest) is the useful lesson;
  the 40-69% figures are against a model with no cross-country term at all.

## Findings

- [method/dynamics] Older "learning" models use the launch lag: the lead country's
  early diffusion drives the lag country's later diffusion, one way and pairwise;
  "mixing" models (Putsis et al. 1997) let all countries influence each other at once.
  Introduction ^f1
  > these models use the new product introduction “lag periods” to model the effect of the early diffusion of a new product in one country (the lead country) on the subsequent diffusion of the product in another country (the lag country).
- [method/dynamics] Their model adds to each country's Bass hazard a term in other
  countries' adoption, weighted by a normalised proximity a_ij, with a per-country
  responsiveness r_i or s_i; all country parameters are partially pooled
  (hierarchical, by country and by product). Sections 2.1, 4 ^f2
  > In estimating these models, we use a hierarchical structure to borrow strength from the other estimates in the same country or with the same product.
- [method/dynamics] Out-of-sample (1-3 years ahead) MSPE: cross-country word-of-mouth
  alone improves on the plain Bass model by 57%, the non-personal signal alone 40%,
  both 69%. Abstract ^f3
  > Wordof-mouth signals improve prediction by 58%, whereas non-personal communication signals improve predictions by 40%. Together, they improve prediction by 69%.
- [method/dynamics] Which proximity weights matter: trade and tourism flows best; plain
  geographic distance gives the weakest (still positive) improvement. Section 5.1 ^f4
  > it serves as the weakest measure of bilateral proximity in capturing cross-country influences from either type of signal.
- [method/dynamics] A later launch speeds within-country word-of-mouth (introductory
  lag has a positive effect on q), as in Takada and Jain 1991. Section 5.2 ^f5
  > Introductory lag has a significant positive effect on the covariates for the parameter (q) of the within-country product-specific word-of-mouth influence.
- [method/dynamics] (inferred) For us: the transfer weight from early platforms to
  EUW1 on day 0 should be per source region and built from how alike the regions
  moved on past patches (our M11 correlations play the role of trade and tourism
  flows), not one "early platforms" term; the abstract's 58% vs the body's 57% is a
  rounding mismatch in the paper. ^f6
- [method/dynamics] Checked, not there: the proximity weights are fixed covariates,
  not learnt from the outcome data; no comparison with a learnt free weight matrix. ^f7

## Read

- Abstract, introduction, model section 2.1, estimation 4, results 5.1 and part of 5.2.

## Not read

- Table 3 numbers per proximity variant (layout garbled); posterior covariate table.
