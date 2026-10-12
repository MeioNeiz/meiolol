---
title: 'Rendle 2010: Factorization Machines'
url: https://www.ismll.uni-hildesheim.de/pub/pdfs/Rendle2010FM.pdf
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, sections I-III)
relevance: high
grade: A/fair
description: The original factorization machine paper (ICDM 2010): pairwise interactions via dot products of per-feature latent vectors, linear time, built for sparse data
---
# Rendle 2010: Factorization Machines

Why: our pair (synergy, counter) terms don't help yet at 90k games; FMs are the standard
way to estimate pairwise interactions from sparse one-hot data.

## Assessment

- Evidence: A. The canonical FM paper, thousands of citations; FMs and their
  descendants (FFM, DeepFM) are standard in CTR prediction.
- Reasoning: fair. Clear mechanism and complexity proof; experiments are small (Netflix
  rating, ECML tag task), no ablation on data size.
- Interests: author's own model.
- Weigh: trust the mechanism (sharing strength across pairs) and cost; the benefit at
  our data size and label noise is for us to measure.

## Findings

- [method] An FM models every pairwise interaction with factorized parameters, so it
  can estimate interactions even under heavy sparsity where per-pair weights fail.
  Abstract ^f1
  > In contrast to SVMs, FMs model all interactions between variables using factorized parameters. Thus they are able to estimate interactions even in problems with huge sparsity
- [method] Why it works: factorizing breaks the independence of pair weights, so data
  on one pair informs related pairs, even pairs never seen together. Section III.A.3 ^f2
  > they break the independence of the interaction parameters by factorizing them. In general this means that the data for one interaction helps also to estimate the parameters for related interactions.
- [method] Cost: the model equation is linear in features and latent size, O(kn), and
  parameters are linear in n; scales to 100M training rows (Netflix). Section I ^f3
  > We show that the model equation of FMs can be computed in linear time and that it depends only on a linear number of parameters.
  > We show that FMs scale to large datasets like Netflix with 100 millions of training instances.
- [method] [stats] Sparse data calls for a small latent size k: restricting
  expressiveness generalises better. Section III.A.2 (text split by column layout, no
  verbatim quote) ^f4
- [method] (inferred) For a draft, one-hot (champion, role, side) features with k
  small would give every champion pair (ally synergy and enemy counter) a dot-product
  weight from 170 x k parameters per field instead of ~29k free pair weights, which is
  the regime where our free pair terms don't help yet. ^f5

## Read

- Abstract, sections I to III (model, expressiveness, sparsity, computation)

## Not read

- Section IV learning (SGD details), V relation to SVMs and MF, experiments
