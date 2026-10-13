---
title: 'Lou, Caruana, Gehrke, Hooker 2013: Accurate intelligible models with pairwise interactions (GA2M, FAST)'
url: https://www.cs.cornell.edu/~yinlou/papers/lou-kdd13.pdf
kind: paper
commit: 
for: [distil-explainable]
looked: 2026-10-13
depth: docs (abstract, 1, 4, 5.1-5.2)
relevance: high
grade: A/fair
description: KDD 2013 paper behind EBM (InterpretML); GAM plus a few pairwise terms, mains shaped first and pairs fitted on residuals, FAST ranking of all pairs; nearly matches random forests on 10+ datasets
---
# Lou, Caruana, Gehrke, Hooker 2013: Accurate intelligible models with pairwise interactions

Why: the reference student shape for us (mains + selected pairs), how pairs are chosen
and fitted, and when pair detection fails for lack of data.

## Assessment

- Evidence: A. The basis of EBM (InterpretML, Microsoft), widely used; 10+ public
  datasets, 80/20 splits, synthetic pair-recovery tests. Not a distillation paper:
  GA2M is fitted to labels here.
- Reasoning: fair. Clear algorithm and cost argument; the bin-count tradeoff is
  explained; no error bars on the main tables.
- Interests: authors' own method.
- Weigh: trust the two-stage fit and the sample-size warning for pair detection; the
  "near random forest" accuracy is for low-noise UCI tasks.

## Findings

- [method] GA2M: univariate terms plus a small number of pairwise terms, each
  visualisable. Abstract ^f1
  > consist of univariate terms and a small number of pairwise interaction terms.
- [method] [stats] Adding shaped pairs nearly closes the gap to random forests, and
  sometimes beats them. Section 5.1.2 ^f2
  > GA2 M FAST substantially closes the accuracy gap between unintelligible full-complexity models such as random forests and GAMs.
- [method] Fit order: shape main effects first, then detect and fit pairs on the
  residual (two-stage; top-K pairs by FAST in one go on large data). Section 4.2 ^f3
  > fit a model using the pairs in S on the residual R, where K is chosen according to computing power.
- [method] Mains first means pair terms hold only what mains could not explain, which
  keeps main-effect plots stable. Section 4 ^f4
  > Since we start with shaping individual features and always detect interactions on the residual
- [method] [stats] Pair detection needs far more samples than candidate pairs; with
  4950 pairs FAST needed about 10^6 samples for average precision over 0.7. Section 5.2 ^f5
  > FAST needs large sample sizes (106 or greater) to achieve average precision above 0.7, and as expected performs poorly when there are fewer samples than pairs of features.
- [stats] Weak true interactions and chance interactions look alike near the detection
  threshold. Section 5.2.1 ^f6
  > some false interactions such as (x1 , x7 ) can have signal as strong as that of weak true interactions such as (x8 , x10 ).
- [method] Rank terms for display by the standard deviation of each term's
  contribution, sqrt(E[f_u^2]). Section 4.2.3 ^f7
  > We use E[fu2 ], the standard deviation of fu (since E[fu ] = 0), as the weight for term u.
- [method] (inferred) Our student is a GA2M over categorical inputs: mains are
  champion-role terms, pairs are ally and enemy role-pair cells. ^f5 says that at 230k
  noisy games most of the ~10^5-10^6 pair cells are below detection; distilling from
  teacher logits (lower-variance targets) and synthetic drafts is what makes fitting
  them possible at all, and shrinkage should still take most cells to zero. ^f8
- [method] (inferred) Use ^f3/^f4 ordering in the distilled fit too: fit champion-role
  mains to the teacher logit, then pair terms on the residual with heavier shrinkage,
  so a champion's displayed strength does not change when pairs are added. ^f9
- [method] (inferred) ^f7 gives the "what matters in this draft" ranking for the app:
  per draft, list the terms with the largest contributions. ^f10

## Read

- Abstract, section 1, section 4 (algorithm, two-stage, diagnostics), 5.1-5.2.

## Not read

- FAST derivation details (section 4.1); section 5.3 timing; tables (extraction).
