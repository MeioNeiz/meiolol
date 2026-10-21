---
title: 'Li, Wang, Deng, Barnard 2024: Exploring the cloud of feature interaction scores in a Rashomon set'
url: https://arxiv.org/pdf/2305.10181
kind: paper
commit: 
for: [frontier-interactions]
looked: 2026-10-21
depth: docs (abstract, 1, 4.1, 5)
relevance: medium
grade: B/fair
description: ICLR 2024 (ANU); interaction scores taken from one trained model are not trustworthy because equally accurate models differ in their interactions; computes the range of each pair's score over the Rashomon set (models within epsilon of the best loss); an MLP detecting interactions at 56% AUC on a planted function
---
# Li, Wang, Deng, Barnard 2024: FIS in a Rashomon set

Why: the critic's question, whether interactions read off one accurate net describe the
data or that net.

## Assessment

- Evidence: B. ICLR 2024; synthetic functions, COMPAS, one image task; small models.
- Reasoning: fair. The core argument (equally accurate models with different
  interactions) is shown with exact examples; the sampling of the Rashomon set is a
  greedy heuristic.
- Interests: authors' method.
- Weigh: trust the warning; the practical check for us is seed and resample spread of
  every pair score, not their sampler.

## Findings

- [method/interpret] A well-trained model need not keep the true interactions, and
  several equally good models differ in interaction strength, so one model's
  interactions may not be trustworthy. Abstract ^f1
  > a well-trained predictive model may not preserve the true feature interactions and there exist multiple well-performing predictive models that differ in feature interaction strengths.
- [method/interpret] Example: a model with no interactions and a deep net with
  interactions can have the same performance. Section 1 ^f2
  > a well-performing linear model with no feature interaction might be modelled using a deep neural network with the same model performance but with feature interaction.
- [method/interpret] On data from a planted function, an MLP trained in the NID setting
  ranked the true pair interactions at only 56% AUC; other models within the loss
  tolerance covered the true interactions. Section 4.1 ^f3
  > the MLP achieves an interaction detection accuracy of 56%.
- [method/interpret] Conclusion: interactions can vary a lot across models of similar
  performance, so report them over a set of good models. Section 5 ^f4
  > we highlight that feature interaction can vary significantly across models with similar performance.
- [method/interpret] Checked, not there: seeds or data resamples as the model set,
  categorical inputs, noisy outcomes. ^f5
- [method/interpret] (inferred) For us the Rashomon set is cheap and natural: our net
  already needs 10-seed ensembles, so every pair or triple score should be reported
  per seed and per 90% resample, kept only if its sign and size hold across them, and
  checked against the shrunk logistic's own pair term (a different model class of
  near-equal loss). ^f6

## Read

- Abstract, 1, 4.1, 5.

## Not read

- 2-3 (FIS definition, MLP characterisation, sampling algorithm), 4.2-4.3, appendix.
