---
title: 'Yang et al. 2010: Common SNPs explain a large proportion of the heritability for human height'
url: https://pmc.ncbi.nlm.nih.gov/articles/PMC3232052/
kind: paper
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (abstract, main text)
relevance: high
grade: A/strong
description: Nature Genetics 2010 (GCTA/GREML); estimates the variance explained by all 295k SNPs together as random effects (45%) without predicting, against 5% from significant hits
---
# Yang et al. 2010: Common SNPs explain a large proportion of the heritability for human height

Why: a mature way to estimate how much outcome variance a whole feature set can explain
without building the predictor: the analogue of "how much can any draft model explain".

## Assessment

- Evidence: A. One of the most cited papers in statistical genetics; the method (GCTA,
  GREML) is used in thousands of studies and validated by simulation on real genotypes.
- Reasoning: strong. Tests explanations, ancestry and relatedness confounding.
- Interests: none known.
- Weigh: the estimate is for additive effects of the given features; anything
  non-additive in those features is outside it (as our pair terms would need their own
  random effect).

## Findings

- [method/ceiling] [stats] Variance explained by all features at once, treated as random
  effects, estimated by REML: 45% of height variance from 295k SNPs on 3,925 people.
  Abstract ^f1
  > We show that 45% of variance can be explained by considering all SNPs simultaneously.
- [method/ceiling] [stats] Individually significant hits explained about 5%; the gap
  was effects too small to detect one by one. Abstract, main text ^f2
  > most of the heritability is not missing but has not previously been detected because the individual effects are too small to pass stringent significance tests.
  > a nearly tenfold increase relative to the 5% explained by published and validated individual SNPs.
- [method/ceiling] [stats] The estimate does not test any single feature; it sums the
  variance of all of them, unbiased in total. Main text ^f3
  > does not attempt to test the significance of individual SNPs but provides an unbiased estimate of the variance explained by the SNPs in total.
- [method/ceiling] [stats] Equivalent form via a relationship matrix between pairs of
  subjects computed from the features. Main text ^f4
  > we show how this can be conveniently implemented with a mathematically equivalent model that uses the SNPs to calculate the genomic relationship between pairs of subjects
- [method/ceiling] [stats] Features that only tag the causes (imperfect LD) cap the
  estimate below the true heritability (45% vs 80%). Main text ^f5
  > Our estimate of 45% is still less than the 80% of phenotypic variance due to additive genetic effects
- [method/ceiling] (inferred) For us: a draft "heritability", the variance of the true
  win logit explained by champion-role effects (one random-effect block), ally and enemy
  role-pair effects (two more blocks), as a REML or Haseman-Elston variance-component
  fit on game outcomes, with a kernel = shared champion-roles between two games. The sum
  of the blocks is the ceiling of any model built on those terms, measured without
  fitting one; a third block (trios or the comp) shows whether higher order adds
  anything. ^f6

## Read

- Abstract and main text.

## Not read

- Online methods and supplementary note (REML details, liability scale for binary
  traits): needed before implementing.
