---
title: 'Chang, Caruana, Goldenberg 2022: NODE-GAM: neural generalized additive model for interpretable deep learning'
url: https://arxiv.org/pdf/2106.01613
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1-4.1)
relevance: medium
grade: B/fair
description: ICLR 2022 (Toronto, Vector, Microsoft Research, Caruana); differentiable oblivious-tree GAM and GA2M trained on GPU; on 6 sets over 500k rows NODE-GA2M beat EBM-GA2M by 3.6% on average, full NODE beat all GAMs on Higgs and Year; categoricals target-encoded; GA2M terms purified (Lengerich) before display
---
# Chang, Caruana, Goldenberg 2022: NODE-GAM

Why: is a GPU-trained GA2M a better way to get readable pair terms at 1.4M games than
a shrunk logistic or EBM, and how does it treat high-cardinality categoricals.

## Assessment

- Evidence: B. ICLR 2022, Caruana co-author, package nodegam on PyPI; 6 medium and 6
  large public benchmarks. Package docs report lower numbers than the paper with
  default settings (seen in search, not read).
- Reasoning: fair. Honest that GAMs trail full models on some sets; std across seeds on
  a single split for the large sets.
- Interests: authors' method against EBM (Caruana's own).
- Weigh: gains over EBM are a few percent relative error on continuous-feature sets;
  categoricals are target-encoded, which loses champion identity in pair terms.

## Findings

- [method/interpret] NODE-GAM and NODE-GA2M: differentiable tree ensembles constrained to
  one or two features per tree, trained on GPU with mini-batches; scale better than
  other GAMs on large data. Abstract ^f1
  > we propose a neural GAM (NODE-GAM) and neural GA2 M (NODEGA2 M) that scale well and perform better than other GAMs on large datasets
- [method/interpret] On the six large sets (over 500k rows), NODE-GA2M beat EBM-GA2M by up
  to 7.3% (Higgs), 3.6% on average; full NODE beat every GAM and GA2M on Higgs and Year,
  pointing to higher-order interactions there. Section 4.1 ^f2
  > NODE-GA2 M outperforms EBM-GA2 M up to 7.3% in Higgs and average relative improvement of 3.6%.
  > NODE outperforms all GAMs and GA2 Ms substantially on Higgs and Year, suggesting both datasets might have important higher-order feature interactions.
- [method/interpret] On medium sets all GAMs performed similarly and NODE-GA2M slightly beat
  full-complexity models. Section 4.1 ^f3
  > In summary, all GAMs perform similarly. NODE-GA2 M is similar to EBM-GA2 M, and slightly outperforms full-complexity models.
- [method/interpret] Scaling: spline GAMs ran out of memory on 5 of 6 large sets, EBM
  could not run on the 2k-feature set (32 CPUs, 120 GB). Section 4.1 ^f4
  > Spline goes out of memory on 5 out of 6 datasets and EBM also can not be run on dataset Epsilon with 2k features
- [method/interpret] Categorical features are target-encoded and all features
  quantile-transformed to Gaussian. Section 3 ^f5
  > We follow Popov et al. (2019) to do target encoding for categorical features
- [method/interpret] GA2M terms have many equivalent representations; they purify
  (Lengerich) before showing graphs, pushing interaction mass into mains. Section 3 ^f6
  > To solve this ambiguity, we adopt "purification" (Lengerich et al., 2020) that pushes interaction effects into main effects if possible.
- [method/interpret] Main effects can be read from any GAM by differencing two inputs
  that differ in one feature only, centred on the data mean. Section 3 ^f7
  > the difference f (x2 ) − f (x1 ) is equal to fj (x2j ) − fj (x1j ).
- [method/interpret] (inferred) For us, target encoding turns a champion seat into its win
  rate, so a NODE-GA2M pair surface would be "strong champion with strong ally", not
  "Yasuo with Malphite"; the identity-level pair table we want needs embedding or
  one-hot pair terms (our shrunk role-pair blocks). NODE-GA2M fits our profile features
  (damage share, tankiness), where comp terms live, not champion ids. ^f8

## Read

- Abstract, 1-3, 4.1 and Table 2 caption.

## Not read

- 4.2-4.3 (shape graph case studies, self-supervised pretraining), supplements.
