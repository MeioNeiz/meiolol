---
title: 'Fletcher Mercaldo and Blume 2020: Missing data and prediction, the pattern submodel'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC7868046/
kind: paper
commit: 
for: [context-aware-models]
looked: 2026-11-06
depth: skimmed (summary, 1.4, 3.2-3.4, 4.2, 5.1, 6)
relevance: high
grade: B/fair
description: Biostatistics 21(2) 2020 (Vanderbilt); fit one submodel per missingness pattern on that pattern's data only; shows it minimises expected prediction loss under any mechanism and equals the limit of multiple imputation with missingness indicators (MIMI); simulations and SUPPORT re-analysis
---
# Fletcher Mercaldo and Blume 2020: Missing data and prediction, the pattern submodel

Why: the alternative to one model with imputation plus indicators: a model per pattern
(for us: per set of seats with known mastery), and when it beats imputation.

## Assessment

- Evidence: B. Peer reviewed, a proof for squared error within a model class, simulations
  over five mechanisms, a real data set (SUPPORT, 9103 patients, 23 patterns).
- Reasoning: fair. States the class restriction and the small-pattern problem; the real
  data gain only appears after they inject an MNAR effect by hand.
- Interests: authors' own method.
- Weigh: the clean result is the equivalence with MIMI (indicators plus their
  interactions): pattern submodels are the unpooled end, MIMI with shrinkage the pooled
  one. On real SUPPORT data all methods tied.

## Findings

- [method] Pattern submodels: one submodel per missing-data pattern fitted on that
  pattern's data, usable both to build and to apply the predictor. Summary ^f1
  > a set of submodels for every missing data pattern that are fit using only data from that pattern
- [method] [stats] Expected loss is minimised when each pattern's loss is minimised, so PS
  keeps its accuracy when data are not MAR. Summary ^f2
  > we show that the expected loss of a forecasting algorithm is minimized when each pattern-specific loss is minimized.
- [method] PS predictions equal the limit of multiple imputation with missingness
  indicators (MIMI): indicators and their interactions with the observed covariates.
  Summary ^f3
  > predictions from the PS approach are equivalent to the limiting predictions for a MI procedure that is dependent on missingness indicators (the MIMI model).
- [method] Gains depend on mechanism and effect size; under MAR multiple imputation ties
  at more compute. Summary ^f4
  > The degree of improvement is highly dependent on the missingness mechanism and the effect size of missing predictors. When the data are MAR, MI can yield comparable forecasting performance but generally requires a larger computational cost.
- [method] On real SUPPORT data all methods tied; only after injecting an MNAR-Y effect
  (+25 SPS when pafi missing) did PS/MIMI cut prediction error about 50% vs MI and 40% vs
  complete-case submodels. Section 5.1 ^f5
  > For the original SUPPORT data, all methods performed similarly both across and within patterns.
  > approximately a 50% reduction in PE for PS/MIMI compared with MI, and a 40% reduction in PE for PS/MIMI compared with CCS.
- [method] Logistic version: Brier and log score equal across methods on real data; with
  induced MNAR-Y, PS with relaxed lasso and MIMI scored best, the lasso helping in rare
  patterns. Section 5.1 ^f6
  > It seems as though the PS Relaxed Lasso potentially has an advantage over PS in the patterns with lower membership
- [method] Many patterns: fit only observed or important patterns, or use the MIMI model to
  decide how to borrow strength across patterns. Section 3.3 ^f7
  > an examination of the MIMI model during the model construction stage can indicate how best to borrow strength over the patterns
- [method] Mean imputation plus indicator biases coefficients, but with conditional mean
  imputation it is unbiased wherever complete-case estimation is. Section 3.4 ^f8
  > when conditional mean imputation is used to impute missing predictors, the missing-indicator method will yield unbiased parameter estimates in the same scenarios where complete case estimation is unbiased
- [method] (inferred) For us: 2^10 seat patterns is too many for separate submodels; the
  usable form is MIMI-like: per-seat mastery imputed from observed covariates, a per-seat
  indicator, and indicator x covariate interactions shrunk (ridge) toward zero, the
  pooled end of the PS-MIMI line. ^f9

## Read

- Summary, introduction 1.4, methods 3.2-3.4, simulation results 4.2, SUPPORT 5.1, 6.

## Not read

- Supplement (Shmueli example, imputation bias tables), the pattern-size rule of thumb
  (its threshold was a formula lost in the text extraction).
