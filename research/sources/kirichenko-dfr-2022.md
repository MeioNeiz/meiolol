---
title: 'Kirichenko, Izmailov, Wilson 2022: Last Layer Re-Training is Sufficient for Robustness to Spurious Correlations'
url: https://arxiv.org/pdf/2204.02937
kind: paper
commit: 
for: [patch-shift-nets]
looked: 2026-10-23
depth: listed (sections 1-5, 6 method and results, 8, appendix F summary)
relevance: medium
grade: B/fair
description: Kirichenko, Izmailov, Wilson (NYU, ICLR 2023); Deep Feature Reweighting: keep an ERM-trained feature extractor and refit only the last layer as l1 logistic regression on a small held-out reweighting set
---
# Kirichenko, Izmailov, Wilson 2022: Last Layer Re-Training (DFR)

Why: is refitting only the output layer on newest-patch games enough, and how should
that refit be done?

## Assessment

- Evidence: B. ICLR 2023, NYU (Wilson group); 4 standard spurious-correlation
  benchmarks (Waterbirds, CelebA, MultiNLI, CivilComments) plus ImageNet background
  and texture tests; 5 runs; code released.
- Reasoning: fair. Clear mechanism (features are there, weights are wrong), ablations
  in appendices; the shift studied is a reweighting of existing features, not a
  change in what one input means.
- Interests: none known.
- Weigh: the shift type differs from ours. A patch changes what a champion's
  embedding should be (an input-level change, see [[lee-surgical-ft-2022#^f2]]),
  whereas DFR fixes how the head weighs features already learnt. Trust the recipe
  details (held-out data, strong l1, averaging refits); don't expect head-only
  refits to capture one champion's buff.

## Findings

- [method/dynamics] Claim tested: nets trained by plain ERM still learn the core
  features; the fault is in the last layer's weights, so refitting only that layer
  matches state-of-the-art group-robustness methods at far lower cost. Abstract ^f1
  > simple last layer retraining can match or outperform state-of-the-art approaches on spurious correlation benchmarks, but with profoundly lower complexity and computational expenses
- [method/dynamics] Their view: the problem is in the weights given to features, not
  the features. Section 8 ^f2
  > The issue of spurious correlations is not in the features extracted by the models (though the representations learned by ERM can be improved (e.g., Hermann & Lampinen, 2020; Pezeshki et al., 2021)), but in the weights assigned to these features.
- [method/dynamics] Refitting the last layer on held-out data beat refitting it on
  the same training data the extractor saw. Section 3 ^f3
  > re-using train data for last layer retraining as done in Menon et al. (2020) is suboptimal while retraining the last layer on held-out data achieves significantly better performance
- [method/dynamics] Recipe: the reweighting set is small relative to the feature
  count, so l1 logistic regression; one hyperparameter (penalty), tuned on half the
  held-out set and refit on all of it; 10 refits on random balanced subsets with
  weights averaged. Section 6 ^f4
  > the size of the reweighting set D̂ is small relative to the number of features produced by the feature extractor. For this reason, we use ℓ1 -regularization to allow the model to learn sparse solutions and drop irrelevant features.
  > we train logistic regression 10 times using different random balanced subsets of the data and average the weights of the learned models
- [method/dynamics] Regularisation and multiple refits matter for the result
  (appendix C ablations). Appendix F ^f5
  > we also show that regularization and multiple re-runs of last layer retraining are important for strong performance with DFR
- [method/dynamics] Cost: embeddings are extracted once, then the refit is minutes
  even on 1.2M points, and needs no early stopping. Section 8 ^f6
  > does not require early stopping or other highly problem-specific tuning
- [method/dynamics] Checked, not there: no test where the shift is a change in what
  a few inputs mean (only spurious reweighting and background or texture reliance),
  and no comparison with retraining the whole net on pooled data. ^f7
- [method/dynamics] (inferred) For us: a head-only refit on newest-patch games is the
  cheapest baseline and suits a meta shift (how much a comp feature matters), but a
  champion's buff lives in its embedding, so head-only can't express it unless the
  set net's features already separate that champion. If we try it, fit on newest-patch
  games held out from the body's training, with a strong penalty. ^f8

## Read

- Abstract, 1-3, 4 summary, 5, 6 (DFR results), 8, appendix F summary

## Not read

- Section 7 ImageNet details, appendix C ablation tables, B.3 ColorMNIST
